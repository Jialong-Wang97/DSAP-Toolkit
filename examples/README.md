# Synthetic Example

Generate a DSA sequence, open it in DSAP, and export vessel geometry results.

## Requirements

Use MATLAB R2024b with Image Processing Toolbox on Windows x64, with the JVM
enabled. This example uses the included MATLAB routines; Python, CAVE and VTI
are not needed.

## Run

Set MATLAB's Current Folder to the project root, then run:

```matlab
setup_DSAPI;
result = run_synthetic_example;
fig = dsap_start;
```

The command creates a 128 × 128 × 40 multiframe DICOM, reads it, calculates
geometry from a generated ordered centerline, and exports the results.

## Open in the GUI

1. In the DSAP workspace, select `outputs/synthetic_example/SYNTHETIC_DSA.dcm`.
2. Browse the sequence to view the generated vessel and tissue signals.
3. Open the output directory to inspect the geometry results below.

## Output Files

All files are written to `outputs/synthetic_example/` by default.

| File | Contents |
|---|---|
| `SYNTHETIC_DSA.dcm` | Generated DSA sequence, labelled SYNTHETIC |
| `geometry_metrics.csv` | Length, chord length and distance metric |
| `synthetic_geometry.mat` | Geometry result structure |
| `synthetic_centerline.png` | Generated centerline plot |

To repeat the example in a different output folder:

```matlab
result = run_synthetic_example(fullfile(pwd, 'outputs', 'synthetic_example_2'));
```

Running again with the same output folder regenerates the example files there.
Generated outputs are ignored by Git.

## Example Scope

All images and time curves are generated mathematically, without patient data.
The synthetic example is provided only to verify software execution and is not a clinical validation dataset.

The example performs DICOM import and geometry export. Perfusion analysis uses
additional components described in [THIRD_PARTY.md](../THIRD_PARTY.md); this
example does not calculate CBF, CBV, MTT or Tmax. VTI is disabled in the example.

## Developer Check

To run the packaging smoke test in a fresh MATLAB session without unsaved work:

```matlab
addpath(fullfile(pwd, 'tests', 'release'));
test_reviewer_package;
```

The test resets MATLAB's path, opens and closes the GUI, reads the generated
DICOM, checks geometry exports, and checks missing-dependency messages.
