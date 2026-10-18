> Historical assessment. Current scope/status is in ../THIRD_PARTY.md and ../REVIEWER_RELEASE_CHECKLIST.md. The latest user instruction requires renewed explicit permission before Public visibility or a formal Release. Earlier authorization statements below are superseded.

# Core perfusion provenance and publication decision

Date: 2026-10-19. Project: Digital Subtraction Angiography Perfusion Imaging (DSA-PI), author 王嘉龙.

The maintainer has authorized eventual Public visibility after checks pass. The initial non-commercial preference was subsequently superseded by explicit acceptance of commercial use and evaluation of a GPL route. Permission to change GitHub visibility does not supply missing third-party license rights. No visibility change has been made. Current component assessment: [GPL_DISTRIBUTION_PLAN.md](GPL_DISTRIBUTION_PLAN.md).

## Newly located evidence

1. The maintainer confirmed the core uses Su's code, but cannot recall the original download/archive.
2. Su's public GitLab project contains `modelfree_deconvolution.m`, `main_swine_perfusion.m`, and `introduce_injection_delay.m`. Its observed master commit is `2adaa974e4e46e9e4ef2535ba515ed49329706bc` (2023). The inspected tree has no separate LICENSE file.
3. Su's MATLAB deconvolution header explicitly links to `liob/non-parametric_deconvolution`.
4. That upstream repository's pinned commit `67ca5c1f85e8912119b267e7aeb56085068ae90a` contains GNU GPL version 3. License history identifies the LICENSE in its initial 2019 commit `9bfe6dd25e00da2ab04ebc93f81749858cb03598`.
5. Comparing nonempty code lines after removing comments and whitespace found 47 matching lines between Su's 60-line code sequence and upstream's 80-line sequence. In particular, their Volterra kernel and truncated-SVD inverse statements match. This is provenance evidence, not a legal determination about copyrightable expression or proof of the maintainer's exact download.
6. DSA-PI's current core retains the same kernel structure and related TSVD computation, with its documented filtering/time-axis/block-processing changes. Its existing 100-line file was not edited during this review.

| Inspected artifact | SHA256 |
|---|---|
| Su MATLAB source downloaded from pinned project's master | `eab7ba1280fecc8f6171ad5f5cd2d878bbeb80c571e9f2bcbb519a1e68f53edd` |
| liob MATLAB source at pinned revision | `e6862b4edffb1eacb96df50a8b1baa1267bd0de01488d3a0adc788a4133ce620` |
| Current DSA-PI `modelfree_deconvolution_corrected.m` | `17a65108625b8ee87a57a84f2501fa43d2d5920e5f07a7352decf54ca6319540` |

## Why “non-commercial” alone is insufficient

GPLv3 grants distribution rights subject to its conditions and does not allow an added general ban on commercial use. Section 10 prohibits further restrictions on granted rights. Therefore the potentially GPL-derived core cannot simply be relabeled with a new non-commercial license. A paper citation or the current perfDSA repository's separate Commons Clause license does not establish permission for this older MATLAB implementation.

This finding does **not** mean that DSA-PI can never be published, nor establish that every DSAP file is GPL. It identifies a concrete compatibility question requiring a supported licensing route. CAVE's Commons Clause and the pinned VTI non-commercial condition also need to be considered before treating a combined distribution as GPL-compatible. Separate folders or subprocesses alone are not a proven resolution of the relevant legal scope.

## Decision history

- Keeping a blanket non-commercial restriction would require applicable additional rights. The maintainer did **not** choose this route.
- The maintainer **chose to accept commercial use and evaluate GPL distribution**. The remaining work is rights-chain and component compatibility assessment, not another request to accept commercial use. Su's permission can only cover rights Su can grant; earlier upstream rights and any separate permissions must remain accounted for.

The draft in `PERMISSION_REQUEST_DRAFT.md` is ready for the maintainer to review. It has not been sent to anyone. No replacement scientific implementation, core refactor, or license rewrite is proposed or performed here.

## Sources

- [Su MATLAB source at fixed commit](https://gitlab.com/radiology/igit/q-maestro/perfusiondsa/-/blob/2adaa974e4e46e9e4ef2535ba515ed49329706bc/modelfree_deconvolution.m)
- [Earlier MATLAB source at fixed commit](https://github.com/liob/non-parametric_deconvolution/blob/67ca5c1f85e8912119b267e7aeb56085068ae90a/modelfree_deconvolution.m)
- [Upstream GPLv3 license at fixed commit](https://github.com/liob/non-parametric_deconvolution/blob/67ca5c1f85e8912119b267e7aeb56085068ae90a/LICENSE)
- [Initial upstream LICENSE history](https://github.com/liob/non-parametric_deconvolution/commit/9bfe6dd25e00da2ab04ebc93f81749858cb03598)

Raw fetched source, comparison metrics and the candidate-file hash manifest stay in ignored local audit reports. No raw source was added to Git by this review.
