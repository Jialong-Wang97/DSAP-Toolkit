# Release checklist

**NOT READY FOR PUBLIC RELEASE**

Date: 2026-10-19. This is a blocked preparation checkpoint, not a completed GitHub delivery.

## Completed locally

- [x] Inspected project layout and CLI availability without staging or committing.
- [x] Preserved all pre-existing algorithms, ROI Snapshot, save/lifecycle and performance code.
- [x] Prepared requested documentation, safe placeholders and local audit inventory tooling.
- [x] Applied a temporary documentation-only .gitignore allowlist; no source deleted.
- [x] Identified restricted third-party licensing and existing installation portability gaps.
- [x] Kept raw audit evidence and patient-associated paths out of public documentation.

## Blocking issues

- [x] GitHub CLI 2.102.0 installed; accessed through its installation path because the current app PATH is stale.
- [x] User completed browser authorization; normal-user `gh auth status` verifies Jialong-Wang97 using Windows keyring. Sandbox-only authentication failure was not a real login failure.
- [x] Initialized local Git on main and verified the documentation-only allowlist. Source/data/model paths remain ignored.
- [ ] Confirm official DSAP expansion, author/institution, Git commit identity and copyright authority.
- [ ] Resolve core algorithm provenance, CAVE transitive borrowed code, VTI non-commercial license and model redistribution rights. Choose project license only for cleared code.
- [ ] Review flagged source/documents, binary MAT templates/contracts, configuration, data-derived calibration and model metadata. Automated string checks cannot certify absence of PHI; no clinical media have been cleared.
- [ ] Finalize a runnable reviewed source manifest. Current whitelist deliberately permits only release-preparation documents, not the application.
- [ ] Deliver reproducible dependency/model setup with verified versions, hashes, notices and authorized acquisition. Existing setup only rebinds a prepopulated venv.
- [ ] Complete CITATION.cff authors and validate CFF schema; current file is explicitly a draft.
- [ ] Supply synthetic basic-workflow fixture and expected behavior; current examples folder contains only a placeholder.
- [ ] Initialize Git, inspect staged content, first commit, create PRIVATE repository and push after all upload blockers are resolved.
- [ ] Check remote visibility, tracked-file completeness, no data/PHI/secrets, README rendering and retained third-party notices.
- [ ] Perform real clean-clone test from GitHub into a new directory: clone → independently setup → launch → synthetic basic workflow. No shared local runtime links, no hidden developer paths. Record commands, versions, outcomes and failures.
- [ ] Obtain explicit approval for any eventual switch to public; formal Release requires separate explicit approval.

## Test status and scope

Remote inspection: **NOT RUN — repository not created**.
Clean-clone test: **NOT RUN — GitHub CLI/authentication, source manifest and setup unresolved**.
Local MATLAB full workflow: **NOT RUN for this release task**; existing local environment results are not substitute evidence.
Scientific algorithm/performance revalidation: **not requested and not performed**.

New-document check: **PASS** for existence of the 12 allowlisted preparation files and targeted absolute-drive-path/common GitHub-token checks. Git has now been initialized. This limited check is not general PHI certification. CFF schema readiness remains blocked by missing authors.

Only release-sensitive behavior should be tested when prerequisites are available.
Do not mark missing tests as passed merely because the old local installation works.
