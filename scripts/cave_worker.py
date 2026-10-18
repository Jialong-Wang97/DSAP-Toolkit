# Copyright (C) 2026 王嘉龙. SPDX-License-Identifier: GPL-3.0-only
"""One cancellable, local-only inference job launched by MATLAB (no shell)."""
from __future__ import annotations

import argparse
import ctypes
import hashlib
from importlib.metadata import version
import json
import os
from pathlib import Path
import threading
import time
import traceback


def atomic_json(path, data):
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    temporary.replace(path)


def watch_parent(parent_pid, cancel_file):
    """A killed MATLAB process must not leave a CPU-heavy worker running."""
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.OpenProcess.argtypes = [ctypes.c_ulong, ctypes.c_int, ctypes.c_ulong]
    kernel.OpenProcess.restype = ctypes.c_void_p
    kernel.WaitForSingleObject.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
    kernel.WaitForSingleObject.restype = ctypes.c_ulong
    handle = kernel.OpenProcess(0x00100000, False, parent_pid)
    if not handle:
        raise RuntimeError("Cannot monitor the MATLAB parent process")

    def monitor():
        while True:
            if cancel_file.exists() or kernel.WaitForSingleObject(handle, 0) == 0:
                os._exit(130)
            time.sleep(0.25)
    threading.Thread(target=monitor, daemon=True).start()


def pipeline_signature(root):
    files = [Path(__file__), root / "scripts/cave_trial.py"]
    files += sorted((root / "third_party/CAVE_DSA/unet").glob("*.py"))
    digest = hashlib.sha256()
    for file in files:
        digest.update(file.name.encode())
        digest.update(file.read_bytes())
    return digest.hexdigest()


def run_job(request, job, cache):
    # Heavy imports occur after the parent/cancel monitor starts.
    import numpy as np
    import pydicom
    from scipy.io import loadmat, savemat
    from skimage.transform import resize
    from cave_trial import ROOT, MODELS, sha256, preprocess_pixels, load_net, stream_logits

    def progress(stage, fraction=0):
        atomic_json(job / "progress.json", {"stage": stage, "fraction": fraction})

    source = Path(request["source_file"])
    if request["polarity"] != "dark":
        raise ValueError("CAVE 当前仅验证了暗血管输入；亮血管输入请明确选择旧 DCA 方法。")
    progress("检查影像与缓存", 0.02)
    source_hash = sha256(source)
    signature = pipeline_signature(ROOT)
    model_name, model_hash = MODELS["av"]
    # Check actual weights even on a cache hit, so corrupted/replaced weights
    # cannot be silently presented as the verified official model.
    model_path = ROOT / "third_party/CAVE_DSA/checkpoints" / model_name
    if sha256(model_path) != model_hash:
        raise ValueError("CAVE 动静脉权重缺失或校验失败；没有改用其他模型。")
    key_data = {"source_sha256": source_hash, "pipeline_sha256": signature,
                "model_sha256": model_hash, "threshold": 0.5, "polarity": "dark",
                "versions": {name: version(name) for name in ["torch", "numpy", "scipy", "scikit-image", "pydicom"]}}
    key = hashlib.sha256(json.dumps(key_data, sort_keys=True).encode()).hexdigest()
    cache.mkdir(parents=True, exist_ok=True)
    cached = cache / (key + ".mat")
    payload = None
    if cached.exists():
        try:
            candidate = loadmat(cached, simplify_cells=True)
            candidate_meta = json.loads(candidate["metadata_json"])
            if candidate_meta["cache_key"] != key or not candidate_meta["complete"]:
                raise ValueError("Cache provenance mismatch")
            for name in ["artery_mask", "vein_mask"]:
                mask = candidate[name]
                if mask.shape != tuple(request["image_size"]) or not np.isin(mask, [0, 1]).all():
                    raise ValueError("Cache geometry mismatch")
            mask_hash=hashlib.sha256(candidate["artery_mask"].astype(np.uint8).tobytes()+
                                    candidate["vein_mask"].astype(np.uint8).tobytes()).hexdigest()
            if candidate_meta["mask_sha256"] != mask_hash:
                raise ValueError("Cache mask checksum mismatch")
            if sha256(source) != source_hash:
                raise ValueError("Source changed during cache lookup")
            payload = {name: candidate[name] for name in ["artery_mask", "vein_mask"]}
            meta = candidate_meta
            meta["cache_hit"] = True
        except (ValueError, KeyError, OSError, TypeError):
            # Invalid cache is ignored; verified model inference is required.
            payload = None
    if payload is None:
        progress("读取原始 DSA（分割时间轴独立于灌注时间轴）", 0.08)
        ds = pydicom.dcmread(source)
        pixels = ds.pixel_array
        if list(pixels.shape[1:]) != request["image_size"]:
            raise ValueError("DICOM 尺寸与当前 MATLAB 分析不一致。")
        if "FrameTimeVector" in ds:
            times = np.cumsum(np.asarray(ds.FrameTimeVector, dtype=float))
            timing = "cumulative FrameTimeVector"
        elif "FrameTime" in ds and float(ds.FrameTime) > 0:
            times = np.arange(len(pixels)) * float(ds.FrameTime)
            timing = "FrameTime"
        else:
            raise ValueError("CAVE 缺少有效 DICOM 时间信息；未猜测帧率。")
        images, grid = preprocess_pixels(pixels, times, int(ds.BitsStored))
        del pixels
        progress("载入 CAVE 动静脉模型", 0.15)
        import torch
        torch.set_num_threads(4)
        torch.backends.cudnn.benchmark = False
        torch.backends.cudnn.allow_tf32 = False
        torch.backends.cuda.matmul.allow_tf32 = False
        device = "cuda" if torch.cuda.is_available() else "cpu"
        net, details = load_net("av", device)
        started = time.perf_counter()
        logits = stream_logits(net, images, device, on_frame=lambda n, total:
                               progress(f"CAVE 推理 {n}/{total}（{device.upper()}）", 0.2 + 0.7*n/total))
        probability = torch.sigmoid(logits)[0].cpu().numpy()
        if probability.shape != (2, 512, 512) or not np.isfinite(probability).all():
            raise ValueError("CAVE 输出无效，未生成排除掩膜。")
        masks = [resize(p >= 0.5, tuple(request["image_size"]), order=0,
                        anti_aliasing=False, preserve_range=True).astype(np.uint8) for p in probability]
        payload = {"artery_mask": masks[0], "vein_mask": masks[1]}
        meta = dict(key_data, cache_key=key, cache_hit=False, complete=True,
                    model=details, method="CAVE-AV-union", device=device,
                    inference_seconds=time.perf_counter()-started,
                    native_frame_count=len(times), model_frame_count=len(grid),
                    segmentation_times_ms=grid.tolist(), time_source=timing,
                    centerline_used=False, postprocessing="none; threshold512 then nearest-neighbour",
                    spatial_context="full native image; manual scope applied in MATLAB")
        meta["mask_sha256"]=hashlib.sha256(masks[0].tobytes()+masks[1].tobytes()).hexdigest()
        if sha256(source) != source_hash:
            raise ValueError("原始影像在推理期间发生改变，结果未发布。")
        cache_tmp = cache / (key + f".{os.getpid()}.tmp")
        savemat(cache_tmp, dict(payload, metadata_json=json.dumps(meta)), appendmat=False, do_compression=True)
        cache_tmp.replace(cached)
    progress("导出血管掩膜", 0.96)
    result_tmp = job / "result.tmp"
    savemat(result_tmp, dict(payload, metadata_json=json.dumps(meta)), appendmat=False, do_compression=True)
    result_tmp.replace(job / "result.mat")
    atomic_json(job / "done.json", {"complete": True, "cache_hit": meta["cache_hit"]})
    progress("CAVE 已完成", 1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--job", type=Path, required=True)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--parent-pid", type=int, required=True)
    args = parser.parse_args()
    try:
        watch_parent(args.parent_pid, args.job / "cancel.request")
        request = json.loads((args.job / "request.json").read_text(encoding="utf-8-sig"))
        run_job(request, args.job, args.cache)
    except Exception as error:
        atomic_json(args.job / "error.json", {"message": str(error), "traceback": traceback.format_exc()})
        raise


if __name__ == "__main__":
    main()
