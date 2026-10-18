# File-level review of the two native perfusion blockers

Date: 2026-10-19. Scope: the unchanged native perfusion core and CAVE bridge only.
This supersedes the earlier blanket quarantine of all helpers/adapters.
No optional VTI, territory, or Legacy component is a native release gate.

## Exact core finding

**The remaining rights-clearance hold is `modelfree_deconvolution_corrected.m`.**
The hold is specifically the license grant for the *Su-added portions* of the
2023 MATLAB snapshot incorporated into the current adapted file. It is not a
claim that the earlier GPL code is forbidden to redistribute.

| File / code portion | Origin / modification evidence | Terms / disposition |
|---|---|---|
| liob `modelfree_deconvolution.m` | Official revision `67ca5c1f85e8912119b267e7aeb56085068ae90a`, commit author `liob`; README credits Winther et al. and cites Sourbron / Zoellner | Original repository GPLv3 LICENSE verified. Redistributable under its conditions; no per-file copyright line was present to copy. Do not invent copyright holder names from paper author lists. |
| Su `modelfree_deconvolution.m` | GitLab revision `2adaa974e4e46e9e4ef2535ba515ed49329706bc`, author Ruisheng Su, 2023-04-27; header explicitly links liob | Copied Volterra kernel, TSVD and inverse/IRF framework; GPL lineage is clear. Separate grant covering Su's additions is not located in the inspected three-file snapshot. **UNRESOLVED for those additions.** |
| DSAP `modelfree_deconvolution_corrected.m` | Project creation recorded 2026-08-30, subsequent performance/cancellation updates 2026-09-05/06; maintainer confirms Su origin | Modified third-party core. Do not call it wholly original. Remains excluded until the above grant is evidenced; no algorithm replacement. |
| `centered_temporal_gaussian_filter.m` | Project addition recorded 2026-08-30; later bounded-memory/cancellation modifications recorded | Original DSAP helper under maintainer's GPL-3.0-only authorization; included unchanged apart from license comment. |
| `detect_aif_onset.m` | Project addition recorded 2026-08-30 | Original DSAP helper, GPL-3.0-only; included. Called by the surrounding workflow, not directly by deconvolution. |
| `gausswin.m` | Small project-local Gaussian-window implementation, not a copied toolbox file. Neither inspected liob nor Su repository supplies this helper; original creation turn was not recovered | Treat as project-local implementation under maintainer's original-code authorization; include GPL-3.0-only. Same function name does not make it MathWorks source. No assertion of exact toolbox numerical equivalence is made. |
| `dsap_task_control.m` | DSAP cancellation/control integration | Original GPL-3.0-only; already included. |

### GPL → Su → DSAP changes, without changing current math

- **Earlier GPL implementation:** Volterra AIF kernel, SVD threshold relative
  to largest singular value, truncated pseudoinverse, IRF scaling by `1/dt`,
  maximum/integral of IRF and MTT ratio. Earlier code also has MRI baseline,
  hematocrit and absolute-unit conversion paths.
- **Su snapshot:** removes baseline and hematocrit transformations from the
  active deconvolution path; substitutes causal Gaussian smoothing; changes
  the output interface to CBF/CBV/Tmax/MTT/data/IRFs; reshapes DSA 2D maps;
  uses epsilon `1e-9`; returns a one-origin Tmax. Those are observed code
  differences, not a claim that every mathematical expression is copyrightable.
- **DSAP changes:** validated argument parsing, logical AIF mask checks,
  centered temporal Gaussian filtering, zero-origin Tmax, full-volume and
  bounded-memory execution branches, optional IRF allocation and cancellation.
  Creation/update history confirms these occurred in this project. The
  current scientific body has not been rewritten during release preparation.

### Direct dependency closure

`modelfree_deconvolution_corrected` directly needs
`centered_temporal_gaussian_filter` → project `gausswin`, plus
`dsap_task_control`. Remaining calls are MATLAB built-ins (`inputParser`,
`mean`, `svd`, `diag`, `reshape`, `max`, `sum`, etc.). Native surrounding
preprocessing also uses `detect_aif_onset`, `dsap_resample_uniform`,
`dsap_estimate_baseline_noise`, and `dsap_classify_signal_quality`, already
present or now restored. No hidden proprietary deconvolution library is called.

### What precisely would clear the remaining hold?

One attributable statement or repository license from Ruisheng Su confirming
that his changes to the 2023 MATLAB `modelfree_deconvolution.m` are available
under GPLv3 (or compatible terms), or an equivalent previously supplied license
for that exact source. The earlier author's GPL permission does not itself
document Su's intent for his additions. The fact that a derivative should
comply with GPL is not used as a substitute for that missing evidence.
The current core can then be included with the original header references,
GPL notice and explicit Su/DSAP modification record; no numerical change is needed.

## CAVE file-by-file result

| File / resource | Origin | Terms / disposition |
|---|---|---|
| `scripts/cave_worker.py` | Added by DSAP integration on 2026-09-07: parent watchdog, cancellation, cache keys, JSON jobs, DICOM timing, result MAT files | Original glue code, GPL-3.0-only; included. Merely invoking CAVE is not a reason to withhold original glue. |
| `scripts/cave_trial.py` | Added in DSAP's CAVE trial on 2026-09-07; `preprocess_pixels` adapts official `predict.py`; streaming follows the official TemporalUNet/ConvGRU layout and decoding | Modified third-party adapter, **not** under the DSAP GPL grant. Included with Ruisheng Su attribution and complete upstream modified MIT + Commons Clause notice. A case-specific plot title was generalized; preprocessing/inference AST unchanged. |
| `scripts/dsap_environment_probe.py` | DSAP deployment checks | Original GPL-3.0-only; included. Checks imports, versions and actual weight hash. |
| `dsap_cave_full_field.m`, `segment_large_vessels_cave.m`, `dsap_apply_cave_corrections.m` | DSAP MATLAB job/result/mask interface | Original GPL-3.0-only; already included. |
| Official `unet/*.py` | Ruisheng Su's CAVE repository; internal headers also credit other recurrent-network projects | External download at fixed revision; original files/headers retained byte-for-byte. No upstream implementation bundled or relabeled. |
| AV checkpoint | Official CAVE / Zenodo distribution | External download, exact SHA256 and size required; no checkpoint redistributed in this repository. |

The actual CAVE license permits copying, modifying and distributing, subject
to retention of its notice and Commons Clause's defined sale restriction.
It is not a blanket ban on free redistribution. Adapted CAVE code is not
represented as unrestricted GPL or OSI open source. Original workers and the
external CAVE program retain their distinct terms; this review does not grant
commercial rights absent from the upstream license.

`scripts/install_cave_dependency.py` supplies the exact official source paths,
revision, hashes, AV weight URL and a fresh project-local Python environment.
It refuses to overwrite mismatched existing assets and does not copy any
developer runtime. An explicit terms flag precedes downloads. `cave_trial.py`
is now in the package, so users are no longer told to find an unavailable
DSAP adapter in the upstream repository. Installation testing is recorded
separately; file-level distribution clearance is not a runtime pass.

## Evidence sources

- [Earlier GPL source](https://github.com/liob/non-parametric_deconvolution/tree/67ca5c1f85e8912119b267e7aeb56085068ae90a)
- [Su MATLAB snapshot](https://gitlab.com/radiology/igit/q-maestro/perfusiondsa/-/tree/2adaa974e4e46e9e4ef2535ba515ed49329706bc)
- [CAVE fixed source](https://github.com/RuishengSu/CAVE_DSA/tree/c3b0c215db4029368c9499a12417178014d58d6f)
- [Original CAVE license](https://github.com/RuishengSu/CAVE_DSA/blob/c3b0c215db4029368c9499a12417178014d58d6f/LICENSE_Modified%20MIT%20License%20for%20Non-Commercial%20Use.md)
- [Official model record](https://zenodo.org/records/15641964)

Local authoring-history evidence was inspected without publishing conversation
contents, clinical paths or images. An initial Windows HTTPS request to GitLab
returned EOF; the subsequent standard Python HTTPS request succeeded and
confirmed exactly the three MATLAB files in the pinned snapshot, with no
LICENSE or README. The response is retained in the private audit record.
