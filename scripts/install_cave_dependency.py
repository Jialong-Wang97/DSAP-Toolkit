"""Obtain pinned official CAVE assets, never developer files or patient data.

Copyright (C) 2026 王嘉龙. SPDX-License-Identifier: GPL-3.0-only
Run with an independently installed Python 3.12 x64 on Windows.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import urllib.request
import urllib.parse
import venv

ROOT = Path(__file__).resolve().parents[1]
REVISION = "c3b0c215db4029368c9499a12417178014d58d6f"
WEIGHT = "sequence_av_sigmoid_image512_ConvGRU_logical-star-1097.pt"
WEIGHT_SHA = "c90b7e066e32039cf61352993a9c57784caac6aa1fdb042dc4801df6dc729651"
WEIGHT_SIZE = 332731061


def download(url, destination, sha256, size=None):
    if destination.exists():
        with destination.open("rb") as stream:
            actual = hashlib.file_digest(stream, "sha256").hexdigest()
        if actual != sha256:
            raise RuntimeError(f"Existing file has a different hash; not overwriting: {destination}")
        print(f"Verified existing {destination.relative_to(ROOT)}", flush=True)
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    partial = destination.with_suffix(destination.suffix + ".download")
    digest = hashlib.sha256()
    count = 0
    req = urllib.request.Request(url, headers={"User-Agent": "DSAPI-dependency-setup"})
    with urllib.request.urlopen(req, timeout=60) as response, partial.open("wb") as stream:
        while block := response.read(1024 * 1024):
            stream.write(block); digest.update(block); count += len(block)
            if count % (32 * 1024 * 1024) == 0:
                print(f"Downloaded {count // (1024 * 1024)} MiB", flush=True)
    if digest.hexdigest() != sha256 or (size is not None and count != size):
        raise RuntimeError(f"Download verification failed; untrusted partial retained at {partial}")
    partial.replace(destination)
    print(f"Verified {destination.relative_to(ROOT)}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--accept-cave-terms", action="store_true",
                        help="Confirm that you have read licenses/CAVE_ADAPTER_LICENSE.txt and the official model terms.")
    parser.add_argument("--assets-only", action="store_true", help="Fetch source/weight only; do not create a Python environment.")
    args = parser.parse_args()
    if not args.accept_cave_terms:
        parser.error("Read licenses/CAVE_ADAPTER_LICENSE.txt and THIRD_PARTY.md before passing --accept-cave-terms.")
    if sys.platform != "win32" or sys.version_info[:2] != (3, 12):
        parser.error("This installer supports Windows with Python 3.12 x64 only.")
    source = ROOT / "third_party" / "CAVE_DSA"
    manifest = json.loads((ROOT / "scripts" / "cave_source_manifest.json").read_text())
    for item in manifest:
        url = f"https://raw.githubusercontent.com/RuishengSu/CAVE_DSA/{REVISION}/" + urllib.parse.quote(item["path"])
        download(url, source / item["path"], item["sha256"])
    download(f"https://zenodo.org/records/15641964/files/{WEIGHT}?download=1",
             source / "checkpoints" / WEIGHT, WEIGHT_SHA, WEIGHT_SIZE)
    if not args.assets_only:
        environment = ROOT / ".venv_cave"
        if environment.exists():
            raise RuntimeError("A .venv_cave already exists. Keep it intact; use a fresh checkout for this installer.")
        venv.EnvBuilder(with_pip=True, system_site_packages=False).create(environment)
        python = environment / "Scripts" / "python.exe"
        subprocess.run([str(python), "-m", "pip", "install", "--no-cache-dir", "-r",
                        str(ROOT / "scripts" / "requirements-cave.txt")], check=True)
        probe = subprocess.run([str(python), str(ROOT / "scripts" / "dsap_environment_probe.py")], check=True, capture_output=True, text=True)
        print(probe.stdout)
        if not json.loads(probe.stdout)["Passed"]:
            raise RuntimeError("CAVE environment probe failed; see the reported file/package mismatch.")
    print("CAVE dependency preparation complete. This does not resolve the Su-derived perfusion core license.")


if __name__ == "__main__":
    main()
