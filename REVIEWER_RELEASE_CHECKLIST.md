# Reviewer release checklist

**NOT READY FOR REVIEWER RELEASE**

Current candidate: v0.1.0 Research Preview preparation, not a published release.
Validation is in progress; unchecked items must not be represented as passed.

## Repository

- [ ] Final clean repository / remote revision verified
- [ ] Final tracked content and history scan: no PHI
- [ ] Final tracked content and history scan: no secrets
- [ ] Final source scan: no personal absolute paths
- [x] Restricted/uncertain upstream code and all models excluded by exact allowlist
- [x] Private visibility retained; no public/release command authorized by current instruction

## Documentation

- [x] README written for first-time MATLAB users, with limitations prominent
- [ ] Installation tested from clean clone
- [ ] Quick start tested from clean clone
- [x] Citation included; no invented DOI
- [x] Third-party licenses and installation limits documented in THIRD_PARTY.md

## Reproducibility

- [ ] Clean clone successful
- [ ] Basic MATLAB setup successful
- [ ] GUI launch successful
- [ ] Synthetic example loaded
- [ ] Full minimum perfusion analysis completed
- [ ] Full perfusion result generated
- [ ] Partial original geometry CSV/MAT/PNG example passed
- [ ] Download ZIP path checked independently

## Dependencies

See THIRD_PARTY.md for each dependency's name, Bundled status, License, Status,
exact version/source and Installation method. The included original centerline
and curvature functions use MATLAB; optional VTI is a separate unbundled module.

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
