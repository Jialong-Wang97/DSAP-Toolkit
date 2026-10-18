# Third-party dependencies

Status: reviewer preparation, 2026-10-19. No third-party implementation, model,
runtime or private validation resource is bundled in this candidate. This is
a conservative distribution decision, not a claim that all redistribution is
forbidden. Original DSAP MATLAB wrappers are included; they are not the upstream
implementations. Do not remove upstream notices when installing dependencies.

| Component / author | Use | Bundled | Original terms / classification | Installation |
|---|---|---|---|---|
| Su perfusionDSA, derived from liob/non-parametric_deconvolution | Required TSVD perfusion | No | **C: UNRESOLVED** for the exact adapted DSAP file. Earlier upstream is GPLv3; Su snapshot has no separate license. | See Core below; no confirmed public source for the exact compatible adapter. |
| CAVE / Ruisheng Su et al. | Required artery/vein segmentation in the current perfusion workflow | No | **B: external**; modified MIT with Commons Clause / non-commercial wording; not DSAP GPL. Adapter clearance remains **C: UNRESOLVED**. | Pinned source and official weights below; obtaining these alone does not install the DSAP adapter. |
| VTI / Maz M. Khansari; arc_length credits John D’Errico | Optional tortuosity index | No | **B: external**; pinned GitHub source has non-commercial permission. Embedded arc_length has BSD-2-Clause notice. File Exchange advertises BSD-3-Clause but archive identity has not been verified. | Install pinned `.m` files and notices under `third_party/vessel_tortuosity_vti/`. Other geometry works without VTI. |
| autoTICI territory model / Ruisheng Su et al. | Optional ACA/MCA prediction | No | **B: external** source/model with Commons Clause terms; exact DSAP adaptation **C: UNRESOLVED** | Official model below; compatible inference/config bundle not yet distributable. Do not rename or convert to bypass terms. |
| MATLAB / MathWorks; Image Processing Toolbox | Required GUI, DICOM and image operations | No | **B: external**, proprietary user license | Install MATLAB R2024b Update 2 with Image Processing Toolbox via MathWorks. JVM required. |
| Python / Python Software Foundation; PyTorch and scientific packages | CAVE/territory runtime | No | **B: external**; PSF, PyTorch BSD-style and respective package licenses | Python 3.12 x64, torch 2.6.0 CPU; use upstream distributions, not a copied developer venv. See Runtime below. |
| Node.js / Realm | Optional TIMESlice integration | No | **B: external**, Node MIT and Realm package Apache-2.0; native/transitive notices separate | Node 24.19 and Realm 12.14.2; reader and case-specific orientation validation resources remain **C: UNRESOLVED**. Legacy is unavailable in this candidate. |
| DSAP centerline and curvature routines | Geometry / AutoAIF support | Yes, original wrappers and routines | DSAP original GPL-3.0; MATLAB `bwskel` remains a toolbox dependency | Included in `src/geometry/` and `AutoAIF/`; no VTI formula is copied into these routines. |

## Core — actual blocking dependency

Provenance: [Su snapshot](https://gitlab.com/radiology/igit/q-maestro/perfusiondsa/-/tree/2adaa974e4e46e9e4ef2535ba515ed49329706bc)
and [earlier GPLv3 upstream](https://github.com/liob/non-parametric_deconvolution/tree/67ca5c1f85e8912119b267e7aeb56085068ae90a).
The required DSAP function is `modelfree_deconvolution_corrected.m` in the project
root. It is modified third-party code, not original DSAP code. Associated
`centered_temporal_gaussian_filter.m`, `gausswin.m`, and `detect_aif_onset.m` are
also held out pending provenance confirmation. **Do not rename an upstream
function and assume numerical/interface equivalence.** The maintainer must
clear and supply the exact compatible files with their original attribution
before a reviewer can complete perfusion. No replacement algorithm is supplied.

## CAVE — independently obtainable parts

Official [CAVE source](https://github.com/RuishengSu/CAVE_DSA), revision
`c3b0c215db4029368c9499a12417178014d58d6f`, belongs at `third_party/CAVE_DSA/`.
Use the upstream Git LFS instructions or [official Zenodo record](https://zenodo.org/records/15641964).
Required AV weight: `third_party/CAVE_DSA/checkpoints/sequence_av_sigmoid_image512_ConvGRU_logical-star-1097.pt`.
SHA256: `c90b7e066e32039cf61352993a9c57784caac6aa1fdb042dc4801df6dc729651`.
Preserve the upstream license and dependency notices. A Git LFS pointer is not a weight file.

DSAP also requires `scripts/cave_worker.py` and `scripts/cave_trial.py`. These
contain DSAP-specific integration / adapted preprocessing and are not supplied
by simply cloning CAVE. Their distribution clearance and reproducible install
are **UNRESOLVED**. This prevents full reviewer workflow acceptance today.

## VTI — optional

[Official source](https://github.com/maz369/Vessel-Tortuosity-Index-VTI-/tree/61f9c647205ec6de3c3e766bb1cacc8b73d340ab).
Download revision `61f9c647205ec6de3c3e766bb1cacc8b73d340ab` under its original terms.
Place `vessel_tortousity_index.m`, `arc_length.m`, `sd_theta.m`,
`mean_distance_measure.m`, `num_critical_pts.m` and original notices together in
`third_party/vessel_tortuosity_vti/`. If absent, VTI is NaN/invalid with an explicit
warning; other original geometry metrics remain available.

## Territory — optional

[autoTICI source](https://github.com/RuishengSu/autoTICI/tree/7c5ddb0516800f1e4445c6fcc07d78060b7bf7a9),
[official checkpoint](https://huggingface.co/RuishengSu/autoTICI/blob/bce0e33ce00b99a42f2c3b5668ee84849d2d0542/models/region_segmentation/segmentation_model.pth).
Original checkpoint SHA256: `e920f4d8ce0a92cadfd293c2f6f4f9125cad32e8e0532cc67eb3e9a2917a4ffe`.
The existing DSAP interface expects `vascular_segmentation/inference.py`,
`vascular_segmentation/config.yaml` (JSON syntax), and the model specified by
`model_path`, resolved relative to that config. The development installation
uses `model/territory_model.ts`; no such converted model is distributed here.
The original checkpoint is not a drop-in replacement for that interface.
Compatible adapter/config/model delivery remains **UNRESOLVED**. No automatic
download or conversion is performed.

## Runtime

No Python is needed for the included synthetic geometry example. CAVE/territory
need Python 3.12 x64 and a freshly created project-local `.venv_cave/` (Windows
executables under `Scripts/`), torch 2.6.0 CPU, NumPy, SciPy, scikit-image,
pydicom, Pillow and pylibjpeg decoding packages. GPU is not required by the
existing DSAP CPU integration. A validated public package lock / install path
for the complete adapters remains pending; no command is advertised as a
working full installer yet. `setup_DSAPI` checks file availability and Python
imports when the external interpreter exists; it does not silently install
dependencies or accept their licenses.

Legacy reader paths are `timeslice_realm_reader/`, `cave_runtime/node.exe` and
`contracts/TIMESlice_Legacy_Orientation_Contract_v1.mat`. The contract contains
private validation provenance and must not be shared as a generic template.
Legacy is optional, and does not block the native synthetic import.
