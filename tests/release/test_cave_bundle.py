"""One real CAVE job on the shipped synthetic input; no perfusion claim.
Copyright (C) 2026 王嘉龙. SPDX-License-Identifier: GPL-3.0-only
"""
from pathlib import Path
import importlib
import json
import os
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
assert Path(sys.prefix).resolve() == (ROOT / '.venv_cave').resolve()
for name in ['torch', 'numpy', 'scipy', 'skimage', 'pydicom', 'PIL']:
    module = importlib.import_module(name)
    assert Path(module.__file__).resolve().is_relative_to((ROOT / '.venv_cave').resolve()), name
import numpy as np
import pydicom
from scipy.io import loadmat

source = ROOT / 'outputs/synthetic_example/SYNTHETIC_DSA.dcm'
ds = pydicom.dcmread(source)
assert str(ds.PatientName) == 'SYNTHETIC^PHANTOM'
assert ds.BitsStored == 16 and 32768 < ds.pixel_array.max() < 65536
job = ROOT / 'outputs' / 'cave_release_test' / uuid.uuid4().hex
job.mkdir(parents=True)
(job / 'request.json').write_text(json.dumps({
    'source_file': str(source), 'image_size': [ds.Rows, ds.Columns], 'polarity': 'dark'}))
subprocess.run([sys.executable, str(ROOT / 'scripts/cave_worker.py'), '--job', str(job),
                '--cache', str(job / 'cache'), '--parent-pid', str(os.getpid())], check=True, timeout=900)
result = loadmat(job / 'result.mat', simplify_cells=True)
meta = json.loads(result['metadata_json'])
assert meta['complete'] and not meta['cache_hit'] and meta['model_frame_count'] >= 2
assert meta['model_sha256'] == 'c90b7e066e32039cf61352993a9c57784caac6aa1fdb042dc4801df6dc729651'
for name in ['artery_mask', 'vein_mask']:
    mask = result[name]
    assert mask.shape == (128, 128) and np.isin(mask, [0, 1]).all()
print(json.dumps({'status': 'CAVE_INSTALL_AND_INFERENCE_PASS', 'cache_hit': meta['cache_hit'],
                  'model_frames': meta['model_frame_count'], 'perfusion_completed': False}))
