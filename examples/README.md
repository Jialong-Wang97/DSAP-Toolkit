# Synthetic software-workflow example

Run from the project root in MATLAB R2024b with Image Processing Toolbox:

```matlab
setup_DSAPI;
result = run_synthetic_example;
fig = dsap_start;
```

1. The example creates a 128 × 128 × 40 multiframe DICOM using only generated
   shapes and time curves; no clinical image/header/mask is used.
2. It reads the generated DICOM and calculates original vessel geometry from
   the generated ordered centerline. VTI is explicitly disabled in this example.
3. Inspect `outputs/synthetic_example/geometry_metrics.csv`,
   `synthetic_geometry.mat`, and `synthetic_centerline.png`.
4. In the DSAP GUI select `outputs/synthetic_example/SYNTHETIC_DSA.dcm` to verify
   native DICOM import. Metadata identifies it as SYNTHETIC, not a patient.
5. Perfusion is currently blocked by missing external core/CAVE adapters.
   Clicking analysis must report this, not produce fabricated perfusion maps.

The generated input is the example dataset; no binary download is needed.
Outputs are generated locally and ignored by Git. This partial workflow is not
a clinical phantom validation and is not the requested completed reviewer
perfusion demonstration. The release checklist records that distinction.

To repeat the packaging smoke test in a fresh checkout:

```matlab
addpath(fullfile(pwd,'tests','release'));
test_reviewer_package;
```

The test resets MATLAB's path, starts and closes the GUI, imports the generated
DICOM, exports geometry and verifies clear missing-dependency diagnostics.
Run it in a fresh MATLAB session without unsaved work.
