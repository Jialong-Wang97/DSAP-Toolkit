# DSA-PI GPL distribution assessment

Date: 2026-10-19. Decision recorded: the maintainer accepts commercial use and requests assessment of a GPL route. The earlier requirement for a blanket non-commercial restriction is superseded for code the maintainer can license. Third-party conditions are unchanged. Public visibility is already authorized once substantive checks pass.

**Result: a GPL route is plausible for a properly cleared core, but the current complete application is not cleared as a single GPL distribution.** This is an engineering assessment based on inspected code and license texts, not a definitive legal opinion about the scope of a combined work.

## Component decisions

| Component | Actual integration and terms | GPL route / current status |
|---|---|---|
| DSA-PI original code | MATLAB UI, ROI/state/save helpers and integration; only confirmed original portions can be licensed by the maintainer | Candidate GPL-3.0 distribution with source, attribution and modification records. No additional general non-commercial restriction. No top-level license grant has yet been made because file-level scope is unresolved |
| Perfusion core | User-confirmed Su adaptation; Su's older MATLAB file explicitly cites the GPLv3 liob source and shares code; no separate license found in the inspected Su GitLab tree | Preserve GPL upstream attribution. Clarify rights for Su-specific contributions or establish a supported licensing chain. User acceptance of GPL resolves their own policy conflict but does not supply Su's permission or prove an original archive |
| CAVE | `dsap_cave_full_field.m` launches `scripts/cave_worker.py` via ProcessBuilder; requests/status use JSON and masks use MAT. Worker imports CAVE classes through the DSAP adapter. CAVE code has MIT text plus Commons Clause | Do not label CAVE GPL or promise unrestricted commercial use of CAVE. A separately distributed external segmentation application is a candidate boundary, but file/process separation alone is not conclusive. Need distribution/interface review or compatible permission before clearing the combined offering |
| VTI | `computeVesselGeometry.m` → `callOriginalVTI.m` → upstream MATLAB functions in the same MATLAB session. `UseVTI` defaults to true. Current GitHub source states non-commercial applications | Do not include this pinned version as a GPL-compatible library. Possible remedies: independently verify the BSD-licensed File Exchange release and its per-file notices, obtain compatible permission, or omit VTI from the publication scope. None has been silently applied |
| VTI absence | Existing wrapper already returns an unavailable warning when files are absent; other geometry metrics can remain available | A publication without VTI may be technically possible without changing its algorithm, but it would lack the VTI metric and must be described and tested as such. It is not evidence that the current full bundle is cleared |
| ACA/MCA territory module | Separate Python process, image MAT/JSON input and native masks output; TorchScript model is derived from the author checkpoint. Local source/model terms include Commons Clause | Keep model and applicable adapter terms separate. Do not convert the checkpoint's license by converting its file format. Optional external acquisition is a candidate distribution approach, not an automatic compatibility ruling |
| Arc length / other permissive dependencies | Separate BSD-2-Clause, BSD-3-Clause and Apache-2.0 notices exist in relevant components | Generally suitable candidates with notices preserved, subject to checking the actual included versions and copied subcomponents. A permissive subcomponent does not override a restrictive parent component |
| MATLAB and toolboxes | Proprietary execution environment installed independently by users | Do not bundle or license MathWorks products as DSA-PI source. The runtime requirement remains; no claim of a standalone unrestricted binary distribution |

## Why the current GUI cannot be called a complete GPL-only package

`dsap_prepare_analysis.m` invokes CAVE preparation, and `run_interactive_perfusion_remove_large_vessels.m` explicitly rejects a non-CAVE VesselMethod. The normal workflow later calls `segment_large_vessels_cave`. Consequently, excluding CAVE code and weights without providing a working authorized dependency path does not produce the existing complete application. No missing dependency may be disguised by fake masks or undocumented fallback.

GNU's aggregation guidance permits genuinely separate programs to retain separate licenses. It considers both communication mechanisms and semantics; a subprocess is evidence to assess, not a universal exemption. Here CAVE/territory communicate through image/mask files, while VTI uses direct in-process calls. These must be assessed separately; neither “everything is GPL” nor “everything is prohibited” follows automatically.

## Recommended order

1. Pursue **GPL for cleared DSA-PI/core source**, with preserved upstream notices and confirmed rights for Su contributions. Do not transplant the newer Python perfDSA license onto the old MATLAB file.
2. Prefer **a verified BSD VTI release** if its actual numerical files and notices can be verified. The official page currently routes download through MathWorks sign-in; no authentication bypass was attempted. A license text alone is insufficient to declare the local GitHub copy BSD.
3. Prepare **separately identified CAVE and territory components** with their original terms and authorized acquisition, and resolve whether the proposed distribution is an aggregate or needs additional permission. Merely splitting folders or repositories does not settle this.
4. After the distribution scope is settled, create exact source/license manifests and the corresponding installation path; run the requested new-clone setup → launch → synthetic basic workflow before Public visibility.

If compatible permission or a supported independent-component route cannot be established for the full package, a narrower GPL core release is a possible alternative. It would not be the current complete GUI product and must not be substituted silently for the user's requested software release. Directory reorganization, feature removal or algorithm replacement requires a separate implementation decision; none was performed by this assessment.

## Required evidence, not repeated approvals

- Public-release consent: **already obtained**.
- Maintainer acceptance of commercial use/GPL assessment: **already obtained**.
- Su/core rights chain: **unresolved**.
- Actual BSD VTI artifact or compatible grant: **unresolved**.
- CAVE/territory combined-distribution scope and license obligations: **unresolved**.
- Runnable source/privacy manifest and clean-clone acceptance: **not complete**.

No GPL-3.0-only versus GPL-3.0-or-later choice is inferred solely from a file containing the GPLv3 text. The final SPDX expression must match the actual rights and grant language. No original license text, stable source, ROI Snapshot, save lifecycle or performance path was modified.

## References

- [GPLv3, including sections 5, 7 and 10](https://www.gnu.org/licenses/gpl-3.0.html)
- [GNU FAQ: aggregates versus combined programs](https://www.gnu.org/licenses/gpl-faq.html#MereAggregation)
- [GNU license list: Commons Clause](https://www.gnu.org/licenses/license-list.html#comclause)
- [VTI File Exchange 1.0.2](https://www.mathworks.com/matlabcentral/fileexchange/72986-vessel-tortuosity-index-vti)
- [Pinned core provenance and hashes](CORE_LICENSE_REVIEW.md)

GNU pages were successfully retrieved using normal HTTPS after the web reader timed out; copies remain in ignored local audit evidence. File Exchange's public page and retained local license text were inspected, but no authenticated source download or numerical substitution was performed.
