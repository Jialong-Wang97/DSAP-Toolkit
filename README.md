# DSAP Toolkit

**Digital Subtraction Angiography Perfusion Imaging (DSA-PI)**

## Overview

DSAP is a MATLAB toolkit for digital subtraction angiography (DSA) perfusion
research in neurointervention and stroke. It brings DSA browsing, tissue ROI
and arterial input function (AIF) selection, perfusion result review, vessel
geometry analysis, and export into an interactive workspace.

Start with the [synthetic example](#quick-start) to open the GUI and generate
geometry results. For perfusion analysis, install the additional components
listed under [Requirements](#requirements).

## Main Features

- **DSA browsing:** select and view grayscale multiframe DICOM sequences.
- **ROI and AIF editing:** draw and edit tissue ROIs, select an AIF, and confirm
  the analysis selections with an ROI Snapshot.
- **Perfusion analysis interfaces:** calculate and view CBF, CBV, MTT and Tmax
  using the external perfusion core and CAVE environment.
- **Vessel analysis:** review CAVE vessel masks for exclusion from tissue
  analysis; calculate centerline length and curvature with the included
  geometry routines.
- **Selection assistance:** reference-frame, AIF and cranial-limit suggestions;
  lumen AutoAIF uses prepared vessel masks and centerlines. Review suggestions
  before confirming the analysis.
- **Results and export:** inspect parameter maps and time curves, save MAT
  results, and export CSV tables and figures.

## Requirements

### Required for the GUI and synthetic example

- Windows x64 with MATLAB **R2024b Update 2** (tested environment).
- **Image Processing Toolbox** and MATLAB's JVM enabled.
- A writable project directory for generated files.

### Required for perfusion analysis

- The compatible `modelfree_deconvolution_corrected.m` core in the project root.
  This file is not included, and a compatible public download is not currently
  provided. The included geometry example runs without it.
- Official **CAVE source and AV weights**. DSAP's CAVE adapters are included.
- **Python 3.12 x64**, **PyTorch 2.6.0 CPU** and the packages installed by the
  CAVE setup script. A GPU is not required for this CPU configuration.

See [THIRD_PARTY.md](THIRD_PARTY.md) for component locations and installation.

### Optional extensions

- **VTI:** additional vessel tortuosity index.
- **ACA/MCA territory prediction:** requires a compatible model and inference bundle.
- **TIMESlice / Legacy import:** requires the reader, Node/Realm runtime and
  matching orientation resources.

These extensions are separate from native DICOM import and the geometry example.

## Installation

Download **Code → Download ZIP** from the repository and extract it, or clone:

```sh
git clone https://github.com/Jialong-Wang97/DSAP-Toolkit.git
```

In MATLAB, set **Current Folder** to the project root containing
`setup_DSAPI.m`, then run:

```matlab
report = setup_DSAPI;
fig = dsap_start;
```

`setup_DSAPI` adds project paths for the current MATLAB session and prints
component checks. Run it once in each new session. `dsap_start` opens the GUI.
External components are installed separately using [THIRD_PARTY.md](THIRD_PARTY.md).

## Quick Start

From the project root in MATLAB:

```matlab
setup_DSAPI;
result = run_synthetic_example;
fig = dsap_start;
```

1. In the GUI, select `outputs/synthetic_example/SYNTHETIC_DSA.dcm`.
2. Browse the generated DSA sequence.
3. Open `outputs/synthetic_example/` to view the geometry CSV, MAT and PNG files.

This example generates the input, reads the DICOM, and calculates geometry
from a generated centerline. For step-by-step details, see
[examples/README.md](examples/README.md).

## Typical Workflow

With the perfusion dependencies installed:

```text
Load DSA
  → Check timing, image polarity and orientation
  → Prepare and review vessel masks
  → Select tissue ROIs, AIF and cranial limits
  → Confirm ROI Snapshot
  → Run perfusion analysis
  → Review CBF / CBV / MTT / Tmax and time curves
  → Save and export results
```

Use grayscale multiframe DSA DICOM with usable frame timing. The current CAVE
integration uses dark-vessel input. Review the vessel mask and its exclusion
from tissue analysis, then confirm the ROI/AIF selections before calculation.

## Example Data

The example generator creates a **128 × 128 × 40** multiframe DICOM from
mathematical shapes and time curves. It uses no patient images and requires
no separate dataset download. Files are generated under
`outputs/synthetic_example/`.

The synthetic example is provided only to verify software execution and is not a clinical validation dataset.

The example runs DICOM import and geometry export; it does not run perfusion
or generate CBF/CBV/MTT/Tmax maps.

## Outputs

### Synthetic example

| File | Contents |
|---|---|
| `SYNTHETIC_DSA.dcm` | Generated multiframe DSA sequence |
| `geometry_metrics.csv` | Centerline length, chord length and distance metric |
| `synthetic_geometry.mat` | Geometry result structure |
| `synthetic_centerline.png` | Centerline plot |

### Perfusion analysis

After completing an analysis, save the core results and use the export controls
for tables and figures. Results are stored in the analysis output folder under
`interactive_results/` and related export directories.

| File | Contents |
|---|---|
| `interactive_perfusion_results.mat` | Saved analysis result |
| `ROI_perfusion_parameters.csv` | ROI perfusion parameters |
| `original_TIC_curves.csv` | Original AIF and tissue time-intensity curves |
| `resampled_filtered_TIC_IRF_curves.csv` | Processed curves and impulse response functions |
| `perfusion_maps.png` | CBF, CBV, MTT and Tmax figure |
| `AIF_ROI_overlay.png` | AIF and ROI overlay |

| Parameter | Meaning in DSAP |
|---|---|
| CBF | Relative flow, calculated from the peak impulse response |
| CBV | Relative volume, calculated from the impulse response integral |
| MTT | Mean transit time, calculated as CBV divided by CBF with a numerical stabilizer |
| Tmax | Time to the impulse response peak, in seconds |

CBF and CBV are relative measures rather than calibrated absolute clinical values.

## Citation

Please cite **王嘉龙, Digital Subtraction Angiography Perfusion Imaging
(DSA-PI)** using [CITATION.cff](CITATION.cff). Also cite the methods used in your
analysis; source and reference links are in [THIRD_PARTY.md](THIRD_PARTY.md).

## License

DSAP original source code is licensed under GPL-3.0.

Third-party dependencies are not covered by the DSAP GPL license and remain subject to their respective licenses.

Certain optional or required third-party components may need to be obtained separately.

See [LICENSE](LICENSE) and [THIRD_PARTY.md](THIRD_PARTY.md).

## Research Use Only

This software is intended for research purposes and is not intended for clinical diagnosis or treatment decisions.

## Issues / Support

Report problems through [GitHub Issues](https://github.com/Jialong-Wang97/DSAP-Toolkit/issues).
Include your MATLAB version, relevant setup messages, steps to reproduce and
error text. Use synthetic examples and remove patient information and credentials
from attachments.
