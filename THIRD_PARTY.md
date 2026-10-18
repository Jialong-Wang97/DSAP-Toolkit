# Third-Party Dependencies

Use this guide to install components for perfusion analysis and optional
extensions. Paths below are relative to the DSAP project root. Keep the
original licenses and copyright notices with installed components.

## Components

| Component / author | Use | Included | Original license | Installation |
|---|---|---|---|---|
| MATLAB and Image Processing Toolbox / MathWorks | GUI, DICOM and image processing | No | MathWorks proprietary license | Install MATLAB R2024b Update 2 with Image Processing Toolbox and JVM enabled. |
| Su perfusionDSA, based on liob/non-parametric_deconvolution | Perfusion deconvolution | Core: no; DSAP helpers: yes | Earlier upstream: GPLv3; no separate license in the Su snapshot; exact adapted file's terms remain unconfirmed | See Perfusion Core. |
| CAVE / Ruisheng Su et al. | Artery/vein segmentation for perfusion | Official source/weights: no; DSAP adapters: yes | Modified MIT + Commons Clause; see bundled adapter license | See CAVE Installation. |
| Python / Python Software Foundation; PyTorch and scientific packages | CAVE runtime | No | PSF, PyTorch BSD-style and individual package licenses | Installed into `.venv_cave` by the CAVE setup script, using Python 3.12. |
| VTI / Maz M. Khansari; arc_length credits John D'Errico | Optional tortuosity index | No | Pinned source: non-commercial permission; embedded arc_length: BSD-2-Clause | See VTI. |
| autoTICI / Ruisheng Su et al. | Optional ACA/MCA territory prediction | No | Upstream source/model includes Commons Clause terms | See Territory Prediction. |
| Node.js / Realm | Optional TIMESlice / Legacy import | No | Node: MIT; Realm: Apache-2.0, plus package notices | See TIMESlice / Legacy. |

DSAP's centerline and curvature routines are included in `src/geometry/` and
`AutoAIF/` under the DSAP GPL-3.0 license. They use MATLAB toolbox functions.

## Perfusion Core

Full perfusion analysis requires the compatible
`modelfree_deconvolution_corrected.m` in the project root. This file is not
included, and a compatible public download is not currently provided.
Downloading the upstream project alone does not supply this DSAP-specific file.

The associated DSAP helpers `centered_temporal_gaussian_filter.m`, `gausswin.m`
and `detect_aif_onset.m` are included. The GUI and synthetic geometry example
run without the external core.

Source references:

- [Su perfusionDSA](https://gitlab.com/radiology/igit/q-maestro/perfusiondsa/-/tree/2adaa974e4e46e9e4ef2535ba515ed49329706bc).
- [Earlier GPLv3 deconvolution implementation](https://github.com/liob/non-parametric_deconvolution/tree/67ca5c1f85e8912119b267e7aeb56085068ae90a).

## CAVE Installation

DSAP includes the interface files:

- `scripts/cave_worker.py`: DSAP glue code, GPL-3.0-only.
- `scripts/cave_trial.py`: adapted CAVE preprocessing/inference code, covered by
  [the original modified MIT + Commons Clause terms](licenses/CAVE_ADAPTER_LICENSE.txt).

### Install source, weights and Python packages

Install Python **3.12 x64**. Read the adapter license above and the asset terms
on the official [CAVE project](https://github.com/RuishengSu/CAVE_DSA) and
[Zenodo record](https://zenodo.org/records/15641964), then run from the project
root in PowerShell:

```powershell
py -3.12 scripts/install_cave_dependency.py --accept-cave-terms
```

If the Python launcher is unavailable, use your Python 3.12 executable with
the same script and arguments. The installer downloads the pinned source and
weights, checks SHA256, creates `.venv_cave`, installs packages and runs an
environment probe. Model download requires an internet connection.

The runtime uses **PyTorch 2.6.0 CPU**, NumPy, SciPy, scikit-image, pydicom,
Pillow and pylibjpeg packages. Versions are listed in
[scripts/requirements-cave.txt](scripts/requirements-cave.txt). This configuration
runs on CPU; a GPU is not required. Use `--assets-only` to download source and
weights without creating the Python environment.

After installation, run `setup_DSAPI` in MATLAB to inspect the component checks.
The CAVE installer installs CAVE components; the perfusion core is separate.

### File locations

| Item | Location |
|---|---|
| Official CAVE source | `third_party/CAVE_DSA/` |
| AV checkpoint | `third_party/CAVE_DSA/checkpoints/sequence_av_sigmoid_image512_ConvGRU_logical-star-1097.pt` |
| Python environment | `.venv_cave/` |
| Windows Python executable | `.venv_cave/Scripts/python.exe` |

Pinned source revision: `c3b0c215db4029368c9499a12417178014d58d6f`.
Checkpoint SHA256: `c90b7e066e32039cf61352993a9c57784caac6aa1fdb042dc4801df6dc729651`.
For manual acquisition, use the official project's Git LFS instructions or the
Zenodo record above and place the complete weight file at the listed location.
Keep the upstream license and source headers alongside the installed files.

## VTI — Optional

Download the [VTI source](https://github.com/maz369/Vessel-Tortuosity-Index-VTI-/tree/61f9c647205ec6de3c3e766bb1cacc8b73d340ab)
at revision `61f9c647205ec6de3c3e766bb1cacc8b73d340ab`. Place these files and their
original notices together under `third_party/vessel_tortuosity_vti/`:

- `vessel_tortousity_index.m`
- `arc_length.m`
- `sd_theta.m`
- `mean_distance_measure.m`
- `num_critical_pts.m`

Without this component, VTI is reported as NaN/invalid; other geometry metrics
remain available. Method reference:
[Khansari et al., VTI](https://doi.org/10.1364/BOE.8.003796).

## Territory Prediction — Optional

Sources: [autoTICI](https://github.com/RuishengSu/autoTICI/tree/7c5ddb0516800f1e4445c6fcc07d78060b7bf7a9)
and its [official checkpoint](https://huggingface.co/RuishengSu/autoTICI/blob/bce0e33ce00b99a42f2c3b5668ee84849d2d0542/models/region_segmentation/segmentation_model.pth).
Checkpoint SHA256: `e920f4d8ce0a92cadfd293c2f6f4f9125cad32e8e0532cc67eb3e9a2917a4ffe`.

The DSAP interface expects `vascular_segmentation/inference.py`,
`vascular_segmentation/config.yaml` (JSON syntax), and a model selected by
`model_path`, resolved relative to the config file. A compatible inference,
configuration and model bundle is not currently provided. The official
checkpoint alone does not enable this interface.

## TIMESlice / Legacy — Optional

This integration uses Node **24.19**, Realm **12.14.2**, a matching reader and
orientation resources. The interface expects:

- `timeslice_realm_reader/export_cave_current_rois.js`
- `cave_runtime/node.exe`
- `contracts/TIMESlice_Legacy_Orientation_Contract_v1.mat`

These resources are not included. Use native DICOM import for the included
workflow and synthetic example.
