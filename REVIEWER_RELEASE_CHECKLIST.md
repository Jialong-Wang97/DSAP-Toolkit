# Reviewer release checklist

**NOT READY FOR REVIEWER RELEASE**

Current candidate: v0.1.0 Research Preview preparation, not a published release.
Checked items refer to the tested original-source subset, not full perfusion. Unchecked items remain blockers. Privacy/secret checkmarks record the bounded scans described below, not a guarantee for future contributions.

## Repository

- [x] Final clean repository / remote revision verified
- [x] Final tracked content and history scan: no PHI
- [x] Final tracked content and history scan: no secrets
- [x] Final source scan: no personal absolute paths
- [x] Restricted/uncertain upstream code and all models excluded by exact allowlist
- [x] Private visibility retained; no public/release command authorized by current instruction

## Documentation

- [x] README written for first-time MATLAB users, with limitations prominent
- [x] Installation tested from clean clone
- [x] Quick start tested from clean clone
- [x] Citation included; no invented DOI
- [x] Third-party licenses and installation limits documented in THIRD_PARTY.md

## Reproducibility

- [x] Clean clone successful
- [x] Basic MATLAB setup successful
- [x] GUI launch successful
- [x] Synthetic example loaded
- [ ] Full minimum perfusion analysis completed
- [ ] Full perfusion result generated
- [x] Partial original geometry CSV/MAT/PNG example passed
- [x] Download ZIP path checked independently

## Dependencies

| Dependency | Bundled | License | Status | Installation method |
|---|---|---|---|---|
| MATLAB R2024b + Image Processing Toolbox + JVM | No | MathWorks proprietary | PASS on test host | User's MathWorks installation |
| Su-derived perfusion core / associated helpers | No | Earlier GPLv3 lineage; exact adapted rights UNRESOLVED | BLOCKER | Exact compatible authorized files in root; no verified public installer |
| CAVE source / weights | No | Modified MIT + Commons Clause | External; clean clone absent | Pinned official source under third_party/CAVE_DSA; official AV checkpoint in checkpoints/ |
| DSAP CAVE worker/preprocessing adapters | No | Adaptation clearance UNRESOLVED | BLOCKER | Exact compatible scripts/cave_worker.py and cave_trial.py still need authorized delivery |
| Python 3.12 / torch 2.6 CPU / scientific packages | No | Respective upstream licenses | Full install UNTESTED | Fresh .venv_cave; see THIRD_PARTY.md; not needed by partial example |
| VTI | No | Pinned non-commercial header; embedded BSD arc_length | Optional missing; NaN/diagnostic verified | Pinned files and notices in third_party/vessel_tortuosity_vti/ |
| ACA/MCA model + inference adapter | No | Commons Clause model; adapter UNRESOLVED | Optional unavailable | Official source/checkpoint; compatible vascular_segmentation bundle pending |
| Node / Realm / TIMESlice validation resources | No | MIT / Apache-2.0; private contract not redistributable as generic evidence | Optional unavailable | External runtime/readers and independently validated contract |
| Original DSAP centerline / curvature | Yes | GPL-3.0-only | PASS on synthetic example | Included src/geometry; MATLAB toolbox used for skeleton operations |

THIRD_PARTY.md supplies exact pinned versions, authors, URLs, filenames and limitations.

## Actual blockers

1. **UNRESOLVED:** exact Su-derived `modelfree_deconvolution_corrected.m` and
   associated helper provenance/distribution. Earlier GPL lineage is evidence,
   not a confirmed installable identical DSAP source package.
2. **UNRESOLVED:** delivery rights and reproducible installation of the required
   DSAP CAVE adapter/preprocessing files; official CAVE source/weights alone
   do not supply the exact interface. Full Python dependency install is untested.
3. Consequently no clean-clone ROI → AIF → perfusion → CBF/CBV/MTT/Tmax export
   has passed. Synthetic import/geometry success cannot check this item.
4. Public access and formal release are explicitly withheld pending the
   maintainer's later permission. Optional territory/VTI/Legacy gaps are
   documented separately and need not block a future native perfusion release.

Required next evidence: authorize/preserve the exact third-party core and
adapted CAVE bundle under their actual terms, provide reproducible acquisition,
then run the unchanged scientific pipeline on the synthetic example and record
its limitations. No scientific algorithm replacement is proposed.

## Acceptance evidence — 2026-10-19

- Tested source commit: `df05c1d59d084cfa7e69fdee8bfbf5c0b70afb04`.
- Authenticated GitHub clone into a new temporary directory: PASS.
- Independently downloaded GitHub ZIP, extracted into another new directory:
  all 194 files byte-identical to Git blobs; no Git metadata needed: PASS.
- Both fresh directories, separate MATLAB processes, default MATLAB path reset:
  setup → GUI launch → synthetic multiframe DICOM import → original geometry
  analysis → CSV/MAT/PNG export: PASS. The test host has an existing licensed
  MATLAB R2024b installation; this is not a fresh operating-system installation.
- No link/copy to developer data, runtime, models or private contract was used.
  Clone working tree remains clean; generated outputs are ignored.
- Synthetic geometry output: length 109.298456832881 mm, chord
  105.463725508364 mm, distance metric 1.03636066624835. These are software
  fixture outputs, not scientific/clinical validation reference values.
- Full perfusion: NOT RUN; blocked. No CBF/CBV/MTT/Tmax output is claimed.
- Missing core/CAVE/territory/Legacy errors and optional VTI NaN state: PASS.
- All 234 reachable historical text blobs at the tested commit scanned for
  personal absolute paths, common secret patterns, long clinical UID literals
  and binary content: no hits. Current exact allowlist excludes all clinical
  files, models, third-party source and runtimes. Largest blob: 100,300 bytes.
- Source SHA256 inventory, official CFF 1.2.0 schema, candidate-relative Markdown
  links, and GitHub README HTML checks: PASS. External upstream links were
  inspected where accessible; GitLab live browse failed in this session, so
  full live external-link availability is not claimed. Historical pinned
  provenance evidence is retained.
- No scientific gold/performance suite was rerun. Six pre-existing whitespace
  warnings in first-time-added stable source were recorded; no algorithm files
  were reformatted to conceal them.
- Post-test changes are documentation/status only. No tag, Public change or
  formal GitHub Release has been created.
