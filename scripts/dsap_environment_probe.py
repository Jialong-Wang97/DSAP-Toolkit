"""Import/version/resource checks only. Never read DICOM or run CAVE inference."""
from __future__ import annotations

import hashlib
import importlib
from importlib.metadata import version
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
    "torch": ("torch", "2.6.0"),
    "numpy": ("numpy", "2.5.1"),
    "scipy": ("scipy", "1.18.0"),
    "scikit-image": ("skimage", "0.26.0"),
    "pydicom": ("pydicom", "3.0.2"),
    "Pillow": ("PIL", "12.3.0"),
    "pylibjpeg": ("pylibjpeg", "2.1.0"),
    "pylibjpeg-libjpeg": ("libjpeg", "2.4.0"),
}


def main():
    result = dict(Passed=True, Python=sys.version, Executable=sys.executable,
                  BasePrefix=sys.base_prefix, Packages={}, Errors=[], Model={})
    if sys.version_info[:2] != (3, 12) or struct.calcsize("P") != 8:
        result["Errors"].append("Requires Python 3.12 x64 (validated base: 3.12.14).")
    for name, (module, expected) in EXPECTED.items():
        try:
            loaded = importlib.import_module(module)
            actual = version(name)
            entry = dict(Version=actual, Expected=expected, Path=loaded.__file__)
            if actual.split("+")[0] != expected:
                result["Errors"].append(f"{name}: {actual}; validated version is {expected}.")
            result["Packages"][name] = entry
        except Exception as error:
            result["Errors"].append(f"{name}: {type(error).__name__}: {error}")
    try:
        import torch
        result["TorchRuntime"] = str(torch.__version__)
        result["TorchCUDABuild"] = torch.version.cuda
        if torch.version.cuda is not None:
            result["Errors"].append("Validated deployment uses PyTorch 2.6.0 CPU; CUDA build needs separate validation.")
    except Exception:
        pass  # The import failure is already recorded above.
    try:
        sys.path.insert(0, str(ROOT / "scripts"))
        sys.path.insert(0, str(ROOT / "third_party/CAVE_DSA"))
        from unet import TemporalUNet, ConvGRU  # noqa: F401; class imports, no model creation
        from cave_trial import MODELS
        filename, expected = MODELS["av"]
        # Check both the worker's canonical path and load_net's selected path.
        # Worker validates canonical weights even on a cache hit.
        canonical = ROOT / "third_party/CAVE_DSA/checkpoints" / filename
        paths = [canonical]
        selected = canonical
        mirror = ROOT / "third_party/CAVE_weights" / filename
        if canonical.stat().st_size < 1024 and mirror.exists():
            selected = mirror
        for directory in ["third_party/CAVE_weights/ranged", "third_party/CAVE_weights/ranged/verified"]:
            candidate = ROOT / directory / filename
            if candidate.exists():
                selected = candidate
        if selected != canonical:
            paths.append(selected)
        checks = []
        for path in paths:
            with path.open("rb") as stream:
                actual = hashlib.file_digest(stream, "sha256").hexdigest()
            checks.append(dict(Path=str(path), SHA256=actual, Passed=actual == expected))
            if actual != expected:
                result["Errors"].append(f"CAVE model hash mismatch: {path}")
        result["Model"] = dict(Filename=filename, ExpectedSHA256=expected,
                               Checks=checks, Passed=all(item["Passed"] for item in checks))
    except Exception as error:
        result["Errors"].append(f"CAVE code/model: {type(error).__name__}: {error}")
    result["Passed"] = not result["Errors"]
    print(json.dumps(result, ensure_ascii=True))


if __name__ == "__main__":
    main()
