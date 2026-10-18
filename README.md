# Digital Subtraction Angiography Perfusion Imaging (DSA-PI)

MATLAB software for research on digital subtraction angiography perfusion,
developed by **王嘉龙**. The established DSAP function names and `DSAP-Toolkit`
repository name are retained.

**Research Preview preparation — NOT READY FOR REVIEWER RELEASE.**
This candidate now includes original source, setup checks and a fully synthetic
example. The example can exercise GUI import and original geometry/export.
**It cannot yet run the full perfusion workflow:** the exact Su-derived core still lacks the specific licensing evidence
described in [file-level review](docs/PERFUSION_BLOCKER_FILE_REVIEW.md).
The project helpers and CAVE adapters are now included with their correct terms.
Do not mistake a successful partial smoke test for CBF/CBV/MTT/Tmax validation.
See [release checklist](REVIEWER_RELEASE_CHECKLIST.md).

## Main features and current availability

The existing implementation provides DICOM selection, native ROI editing,
manual AIF, reviewed ROI Snapshot, result viewers, CSV/MAT/figure exports,
rule-based ROI suggestions, vascular geometry and batch helpers. Full perfusion
uses the external Su-derived TSVD core and CAVE artery/vein segmentation.
VTI, TIMESlice import and ACA/MCA model prediction have additional dependencies.
These capabilities are implemented, but their absence from a clean installation
is explicitly reported; no substitute scientific algorithm is used.

| Workflow | This candidate |
|---|---|
| Setup, open workspace, import synthetic multiframe DICOM | Included; tested as recorded in checklist |
| Original centerline geometry and curvature; export geometry | Included |
| ROI/AIF workflow followed by perfusion and CBF/CBV/MTT/Tmax | Blocked on exact Su-derived core permission; CAVE installation is separate |
| VTI | Optional external; otherwise marked uncomputed |
| ACA/MCA prediction / Legacy import | Optional external; unavailable until separately configured |

## System requirements

- Windows x64; MATLAB **R2024b Update 2** recommended. Other systems/releases are unvalidated.
- **Image Processing Toolbox** for DICOM/image handling. MATLAB's JVM must be enabled.
- MATLAB and its toolboxes must be obtained under the user's own license.
- No Python or GPU is needed for the included partial synthetic example.
- Complete CAVE/territory analysis uses Python **3.12 x64**, **PyTorch 2.6.0 CPU**
  and external packages/models. CPU is supported by the existing integration;
  a GPU is not mandatory. See [THIRD_PARTY.md](THIRD_PARTY.md).
- Use a writable extracted project directory. Outputs can contain sensitive
  source metadata when processing your own data; they are excluded from Git.

## Download and installation

The repository is currently **Private** during preparation. Anonymous download
is not available until the maintainer explicitly approves Public visibility.
Once public, use GitHub **Code → Download ZIP**, extract the archive, or:

```sh
git clone https://github.com/Jialong-Wang97/DSAP-Toolkit.git
```

Open MATLAB, use its Current Folder browser to select the extracted/cloned
project root (the folder containing `setup_DSAPI.m`), then run:

```matlab
report = setup_DSAPI;
fig = dsap_start;
```

Setup only adds project-relative paths for this MATLAB session and checks the
environment. It does not alter user preferences, install software or download
models. `BasicReady` describes the included MATLAB subset;
`FullWorkflowReady=false` is intentional while release blockers remain.
Run setup again in each new MATLAB session. Do not use the developer's old
bundled-runtime launch scripts for this source candidate.

## Quick start: the included synthetic example

```matlab
setup_DSAPI;
result = run_synthetic_example;
fig = dsap_start;
```

In the workspace choose the file `outputs/synthetic_example/SYNTHETIC_DSA.dcm`.
The synthetic example is provided only to verify software execution and is not a clinical validation dataset.

It is generated from mathematical shapes/time curves, not a real patient or
anonymized clinical image. The command above reads it and runs the unchanged
original geometry module on its generated centerline, then exports results.
See [examples/README.md](examples/README.md) for steps and limitations.

**Starting perfusion currently reports a missing dependency.** This is an
unfinished release requirement, not a successful minimum perfusion analysis.
CAVE setup is documented in [THIRD_PARTY.md](THIRD_PARTY.md). Once the exact authorized core is delivered, the intended workflow is:
select DSA → verify direction/polarity/time → vascular preparation → review
AIF, tissue ROI and cranial limits → confirm ROI Snapshot → calculate perfusion
→ inspect curves/maps → save core results → export.

## Inputs, outputs and parameter meaning

Input: native grayscale multiframe DSA DICOM with usable timing; internal data
typically use `[time,row,column]`. CAVE integration is validated locally for
dark-vessel input only. Arbitrary MAT import and arbitrary projections are not
promised. Legacy needs matching external database, masks and verified orientation.

The included example exports `geometry_metrics.csv`, `synthetic_geometry.mat`
and `synthetic_centerline.png` under `outputs/synthetic_example/`.
Complete configured DSAP additionally saves MAT results, ROI metrics/coverage,
TIC/IRF tables, perfusion maps and review records under `interactive_results/`
and related output directories. These complete-analysis outputs are **not**
generated by this candidate's partial example.

| Parameter in the existing external core | Definition | Limit |
|---|---|---|
| CBF | Maximum IRF over time | Relative flow; not calibrated clinical absolute flow |
| CBV | `dt * sum(IRF)` | Relative volume |
| MTT | `CBV / (CBF + 1e-9)` | Depends on numerical validity |
| Tmax | `dt * (peak index - 1)` | Zero-origin delay in seconds |

## AIF, ROI, large vessels and automation

Manual AIF and tissue ROI remain subject to explicit review and Snapshot
confirmation. Rule-based reference-frame/AIF/cranial-limit suggestions are
engineering heuristics. Lumen AutoAIF uses CAVE/centerline preparation; it does
not guarantee anatomical ICA segment localization. The existing conservative
uncalibrated suggestion default is unchanged when private calibration is absent.

CAVE's artery/vein union (sigmoid threshold 0.5) is reviewed for exclusion from
tissue analysis; it can include small vessels too. Geometry does not establish
segmentation accuracy. Optional territory predictions require label/side review.
Batch helpers and automatic suggestions do not replace quality control.

## Known limitations and screenshots

DSA is a 2D projection affected by overlap, motion, injection, timing and AIF/ROI
choices. Synthetic software tests do not establish clinical accuracy, CAVE
performance on synthetic images, or calibrated perfusion values. Full reviewer
reproducibility is still blocked as listed above. No clinical data, model
weights, local runtime, private calibration or orientation contract is shipped.
`docs/screenshots/` reserves space for reviewed synthetic screenshots; none are
claimed to exist yet. No formal version/tag/Release has been published.

## Third-party dependencies

[THIRD_PARTY.md](THIRD_PARTY.md) lists each component, original terms, inclusion
status, pinned source and installation location. Unknown rights are marked
**UNRESOLVED**. Obtaining upstream code alone is not advertised as installing a
compatible DSAP adapter. Do not rename functions or convert models to bypass terms.

## Citation and references

Use [CITATION.cff](CITATION.cff): 王嘉龙, *Digital Subtraction Angiography
Perfusion Imaging (DSA-PI)*. No paper DOI or release DOI is invented.
Also cite the third-party methods you actually use:

- [Su perfusionDSA](https://gitlab.com/radiology/igit/q-maestro/perfusiondsa) and
  [earlier deconvolution implementation](https://github.com/liob/non-parametric_deconvolution).
- [CAVE source and paper reference](https://github.com/RuishengSu/CAVE_DSA).
- [Khansari et al., VTI](https://doi.org/10.1364/BOE.8.003796).
- [autoTICI territory source](https://github.com/RuishengSu/autoTICI).

## License

DSAP original source code is licensed under GPL-3.0.

Third-party dependencies are not covered by the DSAP GPL license and remain subject to their respective licenses.

Certain optional or required third-party components may need to be obtained separately.

The grant is GPL version 3 only for original code; see [LICENSE](LICENSE) and
the exact original-source inventory [SOURCE_MANIFEST.json](SOURCE_MANIFEST.json).

## Research Use Only

This software is intended for research purposes and is not intended for clinical diagnosis or treatment decisions.
