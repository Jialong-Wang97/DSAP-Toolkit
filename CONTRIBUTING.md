# Contributing

Publication is pending. Follow the current private review process until a repository is available.

Never include patient images, DICOM metadata, names, identifiers, dates of birth, clinical spreadsheets, database dumps, original paths, access tokens, local configuration, or private output in issues, pull requests, screenshots or fixtures. Use synthetic examples; removing a filename or DICOM header alone does not remove burned-in text or linked identifiers.

Describe the change, reproduction steps using synthetic data, affected behavior and targeted validation. Keep the perfusion algorithms, ROI Snapshot semantics, save lifecycle and performance paths unchanged for documentation/packaging changes. Propose directory moves before performing them.

For imported or adapted code, provide upstream URL, exact revision, original file paths, license text, preserved attribution, and a description of modifications. Identify model and dataset licenses separately. Do not claim third-party code as original or remove notices.

Use only tests relevant to the change. Release validation must use a new clone and independently installed dependencies, with no junctions to the developer's runtime or patient dataset. Do not submit broad generated test outputs.

Inspect staged filenames and diffs before committing. Never force-add ignored clinical files. Maintainers must confirm authority to contribute and the eventual project license before accepting external code under that license.
