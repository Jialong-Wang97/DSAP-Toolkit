# Adapted CAVE integration; not licensed by the DSAP GPL grant.
# Upstream CAVE: Copyright (c) [2024] [Ruisheng Su].
# DSAP modifications: Copyright (C) 2026 王嘉龙.
# This file retains the upstream modified MIT + Commons Clause conditions.
# See ../licenses/CAVE_ADAPTER_LICENSE.txt for the complete unmodified notice.
# Sources: CAVE_DSA predict.py, evaluate.py and unet/temporal_unet_model.py,
# revision c3b0c215db4029368c9499a12417178014d58d6f.
# Modifications: input validation, streamed inference, portable hidden state,
# weight verification and DSAP I/O; original scientific behavior is retained.
"""Local-only CAVE trial; never edits source DICOM or DSAP analysis results.

Uses upstream TemporalUNet/ConvGRU weights and sigmoid decoding from evaluate.py.
Streaming evaluates the same per-frame encoder and recurrent cells without
retaining the whole sequence's feature maps. A parity test checks this path.
"""
from __future__ import annotations

import argparse
import hashlib
from importlib.metadata import version
import json
from pathlib import Path
import sys
import time

import numpy as np
from PIL import Image
from scipy.interpolate import interp1d
from scipy.io import loadmat
from skimage.transform import resize

ROOT = Path(__file__).resolve().parents[1]
UPSTREAM = ROOT / "third_party/CAVE_DSA"
MODELS = {
    "vessel": ("sequence_vessel_sigmoid_image512_ConvGRU_devoted-pine-1024.pt",
               "35bd5018a1ad6cc96f95ef903edec972497256e84102d228a9a5e3ee374add19"),
    "av": ("sequence_av_sigmoid_image512_ConvGRU_logical-star-1097.pt",
           "c90b7e066e32039cf61352993a9c57784caac6aa1fdb042dc4801df6dc729651"),
}


def sha256(path):
    with open(path, "rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def preprocess_pixels(pixels, times_ms, bits, target=512):
    """Official dark-vessel preprocessing, with explicit input validation."""
    seq = np.asarray(pixels)
    times = np.asarray(times_ms, dtype=np.float64)
    if seq.ndim != 3 or len(seq) < 3 or times.shape != (len(seq),):
        raise ValueError("A multi-frame DSA and one timestamp per frame are required")
    if not np.isfinite(times).all() or np.any(np.diff(times) < 0):
        raise ValueError("Nonfinite or decreasing frame times; cannot infer timing")
    if seq.min() < 0 or not (2**(bits - 1) < seq.max() < 2**bits):
        raise ValueError("Pixel range differs from the upstream unsigned-DICOM assumption")
    keep = np.r_[True, np.diff(times) != 0]
    seq, times = seq[keep], times[keep]
    if len(seq) <= 2:
        raise ValueError("Too few distinct time points")
    # Match upstream: remove the first frame, then sample at 1000 ms.
    seq, times = seq[1:], times[1:]
    grid = np.arange(times[0], times[-1], 1000.0)
    if len(grid) < 2:
        raise ValueError("Sequence too short for the upstream 1 fps input")
    sampled = interp1d(times, seq, axis=0)(grid)
    while len(sampled) > 20:
        if sampled[0].sum() >= sampled[-1].sum():
            sampled, grid = sampled[1:], grid[1:]
        else:
            sampled, grid = sampled[:-1], grid[:-1]
    scaled = 255 * (sampled.astype(np.float32) / (2**bits - 1))
    img = resize(scaled[:, None], (len(scaled), 1, target, target),
                 anti_aliasing=False, preserve_range=True) / 255
    return np.ascontiguousarray(img, dtype=np.float32), grid


def read_case(folder):
    import pydicom
    mat_path = folder / "interactive_perfusion_results.mat"
    saved = loadmat(mat_path, simplify_cells=True, variable_names=[
        "source_file", "settings", "partition", "cranial_limit_mask",
        "large_vessel_mask", "reference_image", "vessel_model"])
    if saved["settings"]["ContrastPolarity"] != "dark":
        raise ValueError("This trial requires confirmed dark vessels; no guessed inversion")
    if not saved["partition"]["Confirmed"]:
        raise ValueError("The saved partition is not confirmed")
    if any("Centerline" in key for key in saved["vessel_model"]):
        raise ValueError("Choose a saved analysis from after centerline removal")
    dicom_path = Path(saved["source_file"])
    before = {str(p): sha256(p) for p in (mat_path, dicom_path)}
    ds = pydicom.dcmread(dicom_path)
    pixels = ds.pixel_array
    if "FrameTimeVector" in ds:
        times_ms = np.cumsum(np.asarray(ds.FrameTimeVector, dtype=float))
        time_source = "cumulative FrameTimeVector"
    elif "FrameTime" in ds:
        times_ms = np.arange(len(pixels)) * float(ds.FrameTime)
        time_source = "FrameTime"
    else:
        raise ValueError("DICOM frame timing missing; no guessed frame rate")
    scope = np.asarray(saved["partition"]["OuterMask"], bool)
    scope &= np.asarray(saved["cranial_limit_mask"], bool)
    if scope.shape != pixels.shape[1:]:
        raise ValueError("Saved geometry does not match native DICOM dimensions")
    metadata = {
        "source_file": str(dicom_path), "saved_analysis": str(folder),
        "input_hashes": before, "original_shape": list(pixels.shape),
        "bits_stored": int(ds.BitsStored), "time_source": time_source,
        "native_frame_times_ms": times_ms.tolist(),
        "photometric_interpretation": str(ds.PhotometricInterpretation),
        "scope_pixels": int(scope.sum()), "no_patient_upload": True,
        "active_dsap_modified": False, "centerline_used": False,
        "scope_definition": "saved confirmed outer partition AND manual cranial limits",
    }
    return saved, pixels, times_ms, scope, metadata


def stream_logits(net, images, device, verbose=False, on_frame=None):
    import torch
    encoders = [net.inc, net.down1, net.down2, net.down3, net.down4]
    rnns = [net.rnn_inc, net.rnn1, net.rnn2, net.rnn3, net.rnn4]
    states = [None] * 5
    features = [None] * 5
    with torch.inference_mode():
        for frame_index, frame in enumerate(images):
            if on_frame is not None:
                on_frame(frame_index, len(images))
            x = torch.as_tensor(frame[None], device=device, dtype=torch.float32)
            for scale, (encoder, rnn) in enumerate(zip(encoders, rnns)):
                x = encoder(x)
                if states[scale] is None:
                    states[scale] = [x.new_zeros((1, c.hidden_dim, *x.shape[-2:]))
                                     for c in rnn.cell_list]
                recurrent = x
                for layer, cell in enumerate(rnn.cell_list):
                    recurrent = cell(recurrent, states[scale][layer])
                    states[scale][layer] = recurrent
                features[scale] = recurrent
            if verbose:
                print(f"inference frame {frame_index + 1}/{len(images)}", flush=True)
        if on_frame is not None:
            on_frame(len(images), len(images))
        x = net.up1(features[4], features[3])
        x = net.up2(x, features[2])
        x = net.up3(x, features[1])
        x = net.up4(x, features[0])
        return net.outc(x)


def load_net(kind, device):
    import torch
    sys.path.insert(0, str(UPSTREAM))
    from unet import TemporalUNet, ConvGRU
    filename, expected = MODELS[kind]
    path = UPSTREAM / "checkpoints" / filename
    mirror = ROOT / "third_party/CAVE_weights" / filename
    if path.stat().st_size < 1024 and mirror.exists():
        path = mirror
    ranged = ROOT / "third_party/CAVE_weights/ranged" / filename
    if ranged.exists():
        path = ranged
    verified = ROOT / "third_party/CAVE_weights/ranged/verified" / filename
    if verified.exists():
        path = verified
    if sha256(path) != expected:
        raise ValueError(f"Model hash mismatch/incomplete Git LFS download: {filename}")
    # Never enable arbitrary pickle execution for downloaded checkpoints.
    weights = torch.load(path, map_location="cpu", weights_only=True)
    classes = weights["outc.conv.weight"].shape[0]
    if classes != (1 if kind == "vessel" else 2):
        raise ValueError("Checkpoint label count differs from its declared model type")
    kernel = tuple(weights["rnn_inc.cell_list.0.update_gate.weight"].shape[-2:])
    layers = len([k for k in weights if k.startswith("rnn_inc.cell_list.")
                  and k.endswith("update_gate.weight")])
    net = TemporalUNet(ConvGRU, 1, classes, bilinear=True,
                      kernel_size=kernel, num_layers=layers)
    net.load_state_dict(weights, strict=True)
    net.eval().to(device)
    portable_hidden_state(net)
    return net, {"filename": filename, "sha256": expected,
                 "kernel": list(kernel), "layers": layers, "classes": classes}


def portable_hidden_state(net):
    """Replace only upstream's hard-coded .cuda() zero allocation, not math."""
    from types import MethodType
    def init_hidden(cell, batch, height, width):
        return cell.update_gate.weight.new_zeros(batch, cell.hidden_dim, height, width)
    for module in net.modules():
        if type(module).__name__ == "ConvGRUCell":
            module.init_hidden = MethodType(init_hidden, module)


def parity_check(net, device):
    import torch
    rng = np.random.default_rng(47)
    small = rng.random((3, 1, 64, 64), dtype=np.float32)
    # Upstream full-sequence forward, with device-portable zero allocation.
    with torch.inference_mode():
        original = net(torch.as_tensor(small[None], device=device))
        streamed = stream_logits(net, small, device)
    error = float((original - streamed).abs().max())
    if not torch.allclose(original, streamed, atol=2e-4, rtol=2e-4):
        raise AssertionError(f"Streaming/upstream parity failed: {error}")
    return error


def save_mask(path, mask):
    Image.fromarray(np.uint8(mask) * 255).save(path)


def overlay(gray, mask, color, alpha=0.65):
    rgb = np.repeat(np.clip(gray, 0, 1)[..., None], 3, axis=2)
    rgb[mask] = (1 - alpha) * rgb[mask] + alpha * np.asarray(color)
    return rgb


def render(folder, saved, scope, results, metadata):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    plt.rcParams["font.sans-serif"] = ["Microsoft YaHei", "SimHei", "DejaVu Sans"]
    plt.rcParams["axes.unicode_minus"] = False
    base = np.asarray(saved["reference_image"], float)
    old = np.asarray(saved["large_vessel_mask"], bool) & scope
    if "vessel" in results:
        vessel = results["vessel"][0] & scope
        metadata["displayed_vessel_source"] = "dedicated vessel checkpoint"
    else:
        vessel = np.any(results["av"], axis=0) & scope
        metadata["displayed_vessel_source"] = "artery OR vein from AV checkpoint"
        save_mask(folder / "av_union_intracranial_mask.png", vessel)
    save_mask(folder / "existing_large_vessel_mask.png", old)
    save_mask(folder / "comparison_scope.png", scope)
    Image.fromarray(np.uint8(np.clip(base, 0, 1) * 255)).save(folder / "original_mip.png")
    panels = [(np.repeat(base[..., None], 3, 2), "原始最大增强投影"),
              (overlay(base, old, [1, 0.48, 0.08]), "现有大血管排除区域（橙色）"),
              (overlay(base, vessel, [0, 0.9, 1]),
               "CAVE 血管（青色，尚未筛选粗细）" if "vessel" in results
               else "CAVE 动静脉并集（青色，未筛选粗细）")]
    fig, axes = plt.subplots(1, 3, figsize=(16, 6.4))
    for ax, (pic, title) in zip(axes, panels):
        ax.imshow(pic)
        ax.contour(scope, levels=[0.5], colors=["#ffe16b"], linewidths=0.55)
        ax.set_title(title, fontsize=12)
        ax.axis("off")
    fig.suptitle("CAVE · 相同原图、相同手动范围 · 独立模型试验", fontsize=15)
    fig.text(0.5, 0.04, "黄色边界：已确认分析范围；不是人工血管标注。两种方法目标不同，不能将差异直接判定为对错。",
             ha="center", fontsize=11)
    fig.tight_layout(rect=[0, 0.08, 1, 0.94])
    fig.savefig(folder / "comparison.png", dpi=150)
    plt.close(fig)
    metadata["mask_counts"] = {"existing_large_vessels": int(old.sum()),
                               "cave_all_vessels_in_scope": int(vessel.sum()),
                               "intersection_not_accuracy": int((old & vessel).sum())}
    Image.fromarray(np.uint8(overlay(base, vessel, [0, 0.9, 1]) * 255)).save(folder / "cave_overlay.png")
    if "av" in results:
        artery, vein = results["av"] & scope[None]
        rgb = overlay(base, artery, [1, 0.12, 0.12])
        rgb[vein] = rgb[vein] * 0.35 + np.array([0.1, 0.4, 1]) * 0.65
        rgb[artery & vein] = [0.8, 0.2, 0.85]
        fig, ax = plt.subplots(figsize=(9, 9))
        ax.imshow(rgb)
        ax.set_title("CAVE 动静脉模型：红=动脉，蓝=静脉，紫=投影重叠\n仅作模型候选标签，尚未经人工确认")
        ax.axis("off")
        fig.tight_layout()
        fig.savefig(folder / "artery_vein_overlay.png", dpi=140)
        plt.close(fig)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--analysis", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--models", nargs="+", choices=MODELS, default=["av"])
    args = parser.parse_args()
    # A fresh directory prevents silent replacement of any prior results.
    args.output.mkdir(parents=True, exist_ok=False)
    saved, pixels, times, scope, metadata = read_case(args.analysis)
    images, grid = preprocess_pixels(pixels, times, metadata["bits_stored"])
    metadata.update({"segmentation_grid_ms": grid.tolist(),
                     "upstream_repository": "https://github.com/RuishengSu/CAVE_DSA",
                     "upstream_commit": "c3b0c215db4029368c9499a12417178014d58d6f",
                     "model_input_shape": list(images.shape),
                     "preprocessing": "upstream dark native pixels; first frame dropped; linear 1 fps; max20; resize512",
                     "decoder": "sigmoid(logits)>=0.5 as upstream evaluate.py",
                     "resizing": "threshold at 512 then nearest-neighbour to native resolution",
                     "inference_scope": "full image for trained context; outputs clipped to saved manual scope",
                     "postprocessing": "none; no smoothing, width filter, or centerline"})
    import torch
    device = "cuda" if torch.cuda.is_available() else "cpu"
    torch.set_num_threads(4)
    torch.backends.cudnn.benchmark = False
    torch.backends.cudnn.allow_tf32 = False
    torch.backends.cuda.matmul.allow_tf32 = False
    metadata["device"] = torch.cuda.get_device_name(0) if device == "cuda" else "CPU"
    metadata["hidden_state_adaptation"] = "zero initialization uses model device instead of hard-coded CUDA"
    metadata["torch_version"] = torch.__version__
    metadata["package_versions"] = {name: version(name) for name in
                                    ["numpy", "scipy", "scikit-image", "pydicom", "matplotlib", "Pillow"]}
    metadata["models"] = {}
    results = {}
    print(f"Preprocessed {len(pixels)} native frames to {len(images)} model frames; {device}", flush=True)
    for kind in args.models:
        net, details = load_net(kind, device)
        print(f"Model loaded and SHA256 checked: {kind}", flush=True)
        details["streaming_parity_max_abs_error"] = parity_check(net, device)
        if device == "cuda":
            torch.cuda.empty_cache()
            torch.cuda.reset_peak_memory_stats()
        started = time.perf_counter()
        logits = stream_logits(net, images, device, verbose=True)
        prob = torch.sigmoid(logits)[0].cpu().numpy()
        if device == "cuda":
            torch.cuda.synchronize()
        details["inference_seconds"] = time.perf_counter() - started
        details["peak_gpu_memory_mb"] = torch.cuda.max_memory_allocated() / 1024**2 if device == "cuda" else None
        np.save(args.output / f"{kind}_probability_512.npy", prob)
        masks = np.stack([resize(p >= 0.5, scope.shape, order=0,
                                 preserve_range=True, anti_aliasing=False).astype(bool) for p in prob])
        results[kind] = masks
        for i, mask in enumerate(masks):
            save_mask(args.output / f"{kind}_{i}_full_mask.png", mask)
            save_mask(args.output / f"{kind}_{i}_intracranial_mask.png", mask & scope)
        metadata["models"][kind] = details
        del net, logits
        if device == "cuda":
            torch.cuda.empty_cache()
    render(args.output, saved, scope, results, metadata)
    for path, expected in metadata["input_hashes"].items():
        if sha256(path) != expected:
            raise AssertionError(f"Original input changed during trial: {path}")
    metadata["original_inputs_unchanged"] = True
    metadata["completed"] = True
    (args.output / "metadata.json").write_text(json.dumps(metadata, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(metadata["models"], indent=2), flush=True)
    print(f"CAVE_TRIAL_PASS {args.output.resolve()}", flush=True)


if __name__ == "__main__":
    main()
