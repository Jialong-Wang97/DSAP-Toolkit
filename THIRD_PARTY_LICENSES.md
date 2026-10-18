# Third-party license audit

Audit date: 2026-10-19. This is an evidence register, not a replacement license.
All existing copyright notices and license files are preserved unchanged.
Local records establish the following; unverified provenance remains a blocker.

Local runtime metadata was inventoried separately: 37 Python distribution metadata records across the CAVE and territory runtime locations, with discovered license-file paths, are recorded in `reports/open_source_audit/runtime_license_inventory.json`. This local-only list is not a complete or validated SBOM and does not clear redistribution of bundled binaries.

| Component / files | Classification and evidence | License / release decision |
|---|---|---|
| Root `dsap_*.m`, ROI/lifecycle helpers, `AutoAIF/`, `src/geometry/` | Project-specific implementation, provisionally original; no complete authorship chain supplied | Owner/institution and copied portions must be confirmed before granting a license |
| Core perfusion code, including `modelfree_deconvolution_corrected.m` | User explicitly confirmed on 2026-10-19 that the core uses Su's code: classify as adapted third-party code, not original | Exact historical repository/revision and file mapping still required. Su's current perfDSA GitHub license includes Commons Clause; older GitLab perfusionDSA license was not retrievable in this audit. Do not assume the current license retrospectively settles the imported version |
| `centered_temporal_gaussian_filter.m`, `gausswin.m` | Numerical helper provenance requires individual review | Do not infer independent authorship from formulas or MATLAB parity; determine which portions belong to the Su-derived implementation |
| `third_party/CAVE_DSA/` | Direct vendored dependency; local README records upstream revision `c3b0c215db4029368c9499a12417178014d58d6f` | Local `LICENSE_Modified MIT License for Non-Commercial Use.md` contains MIT text plus Commons Clause; not ordinary MIT. Preserve full original terms; no blanket relicensing |
| `scripts/cave_trial.py`, `scripts/cave_worker.py`, MATLAB CAVE bridge | DSAP integration plus adapted upstream preprocessing/inference; documented CPU initial-state and streaming changes | Treat adapted portions as third-party-derived; document exact upstream/local diff before redistribution |
| `third_party/CAVE_DSA/unet/convgru.py`, `convlstm.py` | Upstream headers acknowledge ConvLSTM_pytorch, UNet-Zoo and a gist | Transitive provenance/license chain not yet cleared; upstream CAVE license alone does not resolve all copied portions |
| CAVE AV `.pt` weights and duplicates | Separate third-party pretrained artifacts; model hash recorded by adapter | Verify model-specific distribution grant from author/Zenodo; do not infer permission from source alone; excluded |
| `third_party/vessel_tortuosity_vti/*.m` | Direct third-party dependency; local PROVENANCE states unmodified from `61f9c647205ec6de3c3e766bb1cacc8b73d340ab` | GitHub header allows non-commercial use/redistribution. `LICENSE` preserves that statement. File Exchange BSD-3-Clause retained separately; cannot assume it overrides this source |
| VTI `arc_length.m` | Upstream adaptation attributed to John D'Errico, preserved by DSAP | Local `LICENSE_arclength.txt` is BSD-2-Clause; retain attribution and conditions; retain provenance of the upstream adaptation |
| `src/geometry/callOriginalVTI.m` | DSAP wrapper invoking original VTI; separate from original implementation | Wrapper ownership pending; calling wrapper does not change VTI conditions |
| `src/geometry/extractOrderedVesselPath.m`, geometry/curvature helpers | Uses MATLAB `bwskel` and project geometry code; candidate original integration | MathWorks toolbox is a proprietary runtime dependency, not redistributable project source; confirm provenance of helpers |
| `vascular_segmentation/` adapter and `model/` | autoTICI-derived preprocessing/inference, public network conversion to TorchScript; local record points to autoTICI `7c5ddb0516800f1e4445c6fcc07d78060b7bf7a9` and model revision `bce0e33ce00b99a42f2c3b5668ee84849d2d0542` | Local `model/LICENSE_model.txt` has Commons Clause; README records non-commercial-mit model card. Conversion does not remove restrictions. Model card could not be independently retrieved during this audit; preserve pending status |
| `third_party/nnunet-angio-infer-main/` | Separate downloaded third-party tree, optional/experimental role needs confirmation | Local LICENSE is Apache-2.0; verify version, notices, per-file exceptions and whether actually needed. ZIP is not release source |
| `vascular_segmentation/runtime/dynamic_network_architectures*` | Third-party model-conversion dependency | Local LICENCE is Apache-2.0 while metadata says `private`; reconcile metadata and embedded timm-derived code/notice chain before bundling |
| `timeslice_realm_reader/` | Project reader plus direct Realm dependency | Realm package 12.14.2 metadata says Apache-2.0; complete node/native dependency notices not yet verified. Reader ownership and TIMESlice integration rights remain distinct from database content rights |
| `.venv_cave/`, `cave_runtime/`, `.local_deps/`, `.model_deps/`, `scipy_deps/`, Node runtime and all node_modules | Installed third-party dependencies, binaries and transitive packages | Not a single-license artifact. Exclude bundled runtimes; create a pinned dependency/SBOM record and verify notices before any binary distribution |
| `perfusiondsa-master/` | Present but empty on inspection | Directory name does not establish a source or license. Ask owner about historical imported perfusion implementation |

## Primary sources and local evidence

- [CAVE repository](https://github.com/RuishengSu/CAVE_DSA), local license and `README_CAVE_TRIAL.md` (local research record, not approved for publication).
- [Su perfDSA current license](https://github.com/RuishengSu/perfDSA/blob/master/LICENSE_Modified%20MIT%20License%20for%20Non-Commercial%20Use.md) contains Commons Clause. [Earlier perfusionDSA project](https://gitlab.com/radiology/igit/q-maestro/perfusiondsa) is a separate historical-source candidate, not yet established as the exact imported revision.
- [VTI repository](https://github.com/maz369/Vessel-Tortuosity-Index-VTI-), local `PROVENANCE.json`, three retained license files, `THIRD_PARTY_NOTICES.md`.
- [autoTICI repository](https://github.com/RuishengSu/autoTICI), [model source](https://huggingface.co/RuishengSu/autoTICI/blob/main/models/region_segmentation/segmentation_model.pth), local model license/provenance.
- CAVE borrowed-code headers refer to [ConvLSTM_pytorch](https://github.com/ndrplz/ConvLSTM_pytorch), [UNet-Zoo](https://github.com/shreyaspadhy/UNet-Zoo), and [the original gist](https://gist.github.com/halochou/acbd669af86ecb8f988325084ba7a749). Their relevant historical versions and licenses still require verification.

## Required before clearing source for publication

Confirm actual revisions with hashes and compare vendored files to those revisions; preserve original notices and provide modification records. Obtain authority for project code and separate model rights. Resolve conflicting/missing licenses rather than copying a more permissive license from a different release. Generate a versioned inventory of only dependencies that will actually be distributed. No third-party component is removed or relicensed by this audit.

## Cross-chat provenance check

At the user's request, the chat “DSAP自动识别MCA ROI方案” was read. It identifies *Direct vascular territory segmentation on cerebral digital subtraction angiography* as the requested method, with MinIP → PlainConvUNet/nnU-Net-style inference → native masks → manual review. The chat “优化 Native ROI Editor UX” was also inspected for integration context. These are development records, not grants of copyright permission. Local `vascular_segmentation/README.md` and `model/provenance.json` identify the actual autoTICI-hosted pretrained artifact and TorchScript conversion. Thus the current territory feature is a deep-learning module, not atlas registration merely because the host repository is called autoTICI. See [the paper](https://arxiv.org/abs/2508.13821).
