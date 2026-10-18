# Open-source audit — reviewer candidate

## A. Eligible files

Original-source candidates are enumerated by relative path and SHA256 in
SOURCE_MANIFEST.json. Documentation, standard GPLv3 license text and purely
synthetic example generators are included. Only explicit reviewed paths are
allowed by .gitignore. Final staged/remote scans are recorded in the checklist.

## B. Not for upload

All clinical/cohort data, DICOM files, real images/masks, Realm databases,
private templates/calibration/orientation evidence, outputs/results/reports,
logs/autosave/cache, venv/runtime/node_modules, compiled files and model weights.
No files were deleted locally. No git force-add or history rewrite is used.

## C. Human / rights confirmation required

Su-derived core and associated helpers; adapted CAVE preprocessing/worker;
territory adapter/config/checkpoint; private validation contracts. UNRESOLVED
items are not represented as original source or as installed dependencies.
Historical fixture/review scripts and cohort research scripts remain excluded.

## D. Third-party code and licenses

THIRD_PARTY.md is the current table. Original MATLAB wrappers are distinguished
from excluded modified third-party code and direct external dependencies.
No upstream license or copyright notice has been deleted or changed.

## E. Copyright risks

Public download alone is not evidence of redistribution permission. CAVE and
territory assets have Commons Clause terms; pinned VTI carries non-commercial
wording. Su's exact adaptation chain remains unresolved despite earlier GPLv3
source evidence. Excluding these assets does not itself make the complete
application reviewer-ready. Rights clearance is still required for delivery.

## F. Patient privacy risks

The original inventory covered 122,595 files (~40.13 GiB), with 492 bounded text
files scanned outside excluded runtime/artifact trees. Inventory is triage,
not proof of clinical de-identification. Private evidence remains local.
Publication uses a small explicit UTF-8 text-only source/document allowlist.
Synthetic inputs use generated pixels and explicit SYNTHETIC metadata, never
real patient headers. Runtime DICOM field names in source are not patient data;
real results may carry PHI and must remain excluded from Git. Future screenshots
and data require separate review. Final scans are bounded evidence, not a
mathematical guarantee that arbitrary future contributions contain no PHI.

## Large files

Original inventory found 75 files over 50 MiB, 30 over 100 MiB. All excluded.
No model distribution via LFS or Releases is planned until rights are clear.
The candidate consists of small text files; generated example data stays local.
