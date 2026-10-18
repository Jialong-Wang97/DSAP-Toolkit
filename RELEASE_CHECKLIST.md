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
- [x] Created `Jialong-Wang97/DSAP-Toolkit` as PRIVATE, verified visibility before push, pushed the 12-document checkpoint, then rechecked PRIVATE.
- [x] Cloned initial commit `00c92f707b69c8f5311ff259512d8b9532691de7` into a fresh temporary directory; exactly 12 tracked text files and clean working tree. No application/data/model files were uploaded.
- [x] GitHub README rendered-HTML check passed for title/headings. This does not imply application installation passed.
- [x] Confirmed title: Digital Subtraction Angiography Perfusion Imaging (DSA-PI); author: 王嘉龙. Git commit identity uses the verified GitHub account.
- [ ] Confirm copyright authority, including any institutional/employment/collaboration rights; affiliation has not been supplied and is not inferred.
- [ ] Resolve newly identified core license compatibility: Su's MATLAB file explicitly references a GPLv3 upstream, whose corresponding kernel/SVD code matches. A blanket non-commercial license is not an established compatible route. See `docs/CORE_LICENSE_REVIEW.md` and the unsent permission inquiry draft.
- [ ] Resolve CAVE transitive borrowed code, VTI non-commercial license and model redistribution rights. Choose project license only for cleared code.
- [ ] Review flagged source/documents, binary MAT templates/contracts, configuration, data-derived calibration and model metadata. Automated string checks cannot certify absence of PHI; no clinical media have been cleared.
- [ ] Finalize a runnable reviewed source manifest. Current whitelist deliberately permits only release-preparation documents, not the application.
- [ ] Deliver reproducible dependency/model setup with verified versions, hashes, notices and authorized acquisition. Existing setup only rebinds a prepopulated venv.
- [x] Updated CITATION.cff title, author and verified private repository URL; no invented affiliation, ORCID, DOI, version or release date.
- [x] Validated CITATION.cff against official CFF 1.2.0 JSON schema using YAML parsing and JSON Schema format checks; local evidence in ignored audit reports.
- [ ] Supply synthetic basic-workflow fixture and expected behavior; current examples folder contains only a placeholder.
- [ ] Complete the actual source release commit after its blockers are resolved. Git initialization, first documentation commit, PRIVATE creation and documentation push are complete.
- [ ] Check the eventual runnable source tree for completeness, data/PHI/secrets and retained third-party notices. Current remote was checked only against the approved documentation manifest.
- [ ] Perform real clean-clone test from GitHub into a new directory: clone → independently setup → launch → synthetic basic workflow. No shared local runtime links, no hidden developer paths. Record commands, versions, outcomes and failures.
- [x] User explicitly authorized switching to Public after checks pass. This permission persists; do not request it again. Visibility remains PRIVATE because substantive checks have not passed. A formal Release still requires separate authorization.

## Test status and scope

Remote inspection: **PASS for the 12-document checkpoint only** — [PRIVATE repository](https://github.com/Jialong-Wang97/DSAP-Toolkit); source completeness and license clearance remain blocked.
Clean-clone: **clone PASS; setup BLOCKED; launch/basic workflow NOT RUN**. Application source, independent dependency setup and synthetic fixture are not yet distributed. A document clone is not the requested full software acceptance test.
Local MATLAB full workflow: **NOT RUN for this release task**; existing local environment results are not substitute evidence.
Scientific algorithm/performance revalidation: **not requested and not performed**.

New-document check: the initial 12-file checkpoint passed targeted checks; the follow-up adds two license review documents. These limited checks are not general PHI certification. Citation title/author are confirmed and official CFF 1.2.0 schema validation passed. All 184 candidate source hashes remained unchanged during this review.

Only release-sensitive behavior should be tested when prerequisites are available.
Do not mark missing tests as passed merely because the old local installation works.
