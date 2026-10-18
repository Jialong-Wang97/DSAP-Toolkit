# Git / GitHub operation log

Date: 2026-10-19 (Asia/Tokyo).

| Operation actually executed | Result |
|---|---|
| `Get-Location` | Confirmed current project root is DSAP (full local path intentionally omitted from public document) |
| `git --version` | `git version 2.53.0.windows.3` |
| `gh --version` | Command not found |
| `git rev-parse --show-toplevel` | Not a Git repository, including parent directories |
| Check common GitHub CLI installation locations | No executable found at checked locations |

The table above records the initial audit phase. After the user installed CLI and completed browser authorization, preparation resumed as below. No tag, Release, public-visibility change, force push or history rewrite is authorized or performed.

## Authenticated continuation

- `gh --version`: 2.102.0. Current app PATH did not refresh, so the installed executable was invoked by its path.
- `gh auth status`: sandbox initially reported invalid credentials; a normal-user read-only check confirmed active Jialong-Wang97 keyring authentication. No token value was extracted or stored in this project.
- `gh api user --jq '{login: .login, id: .id, name: .name}'`: confirmed account ID 344414816, no profile display name.
- `gh repo view Jialong-Wang97/DSAP-Toolkit --json nameWithOwner,visibility,url`: repository did not exist.
- `git init -b main`: succeeded in the confirmed DSAP directory, after authentication.
- Git reported ownership mismatch. Subsequent operations use command-scoped `safe.directory` for this exact workspace, not a global wildcard or ownership changes.
- `git status --short --untracked-files=all`: exactly 12 preparation documents/placeholders eligible.
- `git check-ignore` on application source, current ROI JSON, local audit inventory and model weights: all ignored.
- Local `user.name=Jialong-Wang97` and `user.email=344414816+Jialong-Wang97@users.noreply.github.com` set using the verified account. Initial sandbox config writes were denied; authorized normal-user writes succeeded. Global identity unchanged.

The first private upload contains only the 12 reviewed preparation files. It is an intermediate documentation checkpoint, not completion of the runnable source release. Source/model/license/privacy blockers remain open.

## First private checkpoint — completed

- `git add -- <12 explicit approved paths>`: no wildcard staging and no forced additions.
- `git diff --cached --check` and `git diff --cached --stat`: passed; LF/CRLF informational warnings only. A separate check verified exactly 12 staged UTF-8 text files, each below 1 MiB, and no absolute-drive-path/common-token signature.
- `git commit -m "docs: prepare private DSAP release audit"`: initial commit `00c92f707b69c8f5311ff259512d8b9532691de7`.
- `gh repo create Jialong-Wang97/DSAP-Toolkit --private --source=. --remote=origin --description <private preparation description>`: succeeded without automatic push.
- `gh repo view ... --json nameWithOwner,visibility,url` and `git remote -v`: verified expected owner, URL and PRIVATE visibility before push.
- First push attempt waited on inherited credential handling and was interrupted. Retry used command-scoped empty credential helper plus the authenticated `gh auth git-credential` helper, with terminal prompts disabled; no credentials were embedded in URLs or files.
- `git push -u origin main`: succeeded, main tracks origin/main.
- `git clone -- <private HTTPS URL> <new temporary directory>`: succeeded with the gh helper. Local-only clone location is recorded under ignored reports.
- Clone `git rev-parse HEAD`, `git ls-files`, `git status --porcelain`: matched initial commit, exact 12 documents, clean tree.
- Remote `gh repo view --json visibility,url,defaultBranchRef`: PRIVATE, main.
- `gh api repos/Jialong-Wang97/DSAP-Toolkit/readme` with HTML Accept header: rendered README retrieved; title/headings checked. Clone text/size/path/token checks passed; no executable workflow run because source is absent.
- The subsequent status-document update is committed and pushed normally, without amend or force; local verification evidence is stored only in ignored reports. The final response identifies its commit.

Non-Git checks: completed recursive inventory and bounded text scanning; read two MAT resource structures; generated a local Python runtime license-metadata inventory; checked new documentation for absolute drive paths/common GitHub token formats. Three slower preliminary inventory runs were interrupted and replaced by the completed scan documented in OPEN_SOURCE_AUDIT.md; none altered project source or Git state.

## Remaining source-release procedure

GPL assessment follow-up (2026-10-19): user accepted commercial use and requested GPL compatibility evaluation. Read-only source inspection confirmed in-process VTI calls, external Python CAVE/territory workers and the normal workflow's CAVE requirement. GNU aggregation guidance and File Exchange license/version information were reviewed. Only assessment documents, the unsent inquiry draft and status records change; no algorithm or third-party license is modified. The documentation update uses explicit staging, diff checks, a normal commit and push to the verified PRIVATE remote. No public visibility or formal Release command is issued while blockers remain.

Follow-up network result: pre-push visibility checks through both GraphQL (`gh repo view`) and REST (`gh api repos/Jialong-Wang97/DSAP-Toolkit`) failed with EOF. The assessment is committed locally; this follow-up is not pushed until remote visibility can be rechecked. Prior successful checks showed PRIVATE, but no fresh remote verification is claimed.

Public-release continuation (2026-10-19): the user explicitly authorized Public visibility after checks pass. Read-only GitLab/GitHub source and license history checks located the GPLv3 provenance issue described in `docs/CORE_LICENSE_REVIEW.md`. Original application source was not modified. Only the evidence note, unsent permission draft and related status documents are eligible for the follow-up documentation commit. No `gh repo edit --visibility public` or Release command was run; consent is recorded and will not be requested again.

Follow-up verification: `git diff --check`; GitHub `repo view --json visibility,url` confirmed PRIVATE; official CFF 1.2.0 schema validation passed using dependencies installed only into ignored audit reports; all 184 source candidate SHA256 values were unchanged. Documentation follow-up uses explicit-path staging, `git diff --cached --check`, a normal commit and normal push. Source, model files, downloaded upstream code, validation dependencies and clinical data remain excluded.

Metadata follow-up (2026-10-19): user confirmed DSA-PI's formal title and author 王嘉龙, and could not recall the original Su source archive. Documentation/CITATION only are updated; repository name, visibility, source quarantine and existing algorithms are unchanged. The update uses explicit-path staging, staged diff checks and a normal new commit/push after PRIVATE verification; no history rewriting.

1. Authentication and the private documentation checkpoint are complete. Never supply a password/token to the assistant.
2. Reconfirm root, CLI authentication, existing private remote and source release manifest. Do not recreate or change repository visibility.
3. Complete source/privacy review and dependency preparation; replace temporary documentation-only quarantine with exact reviewed source exceptions. Do not force-add ignored files.
4. Inspect ignored/untracked paths, stage explicit approved source paths, review staged names/diff and large blobs, then create a new source commit. Do not rewrite initial documentation history.
5. Verify existing repository owner/URL and PRIVATE visibility, then push the reviewed source commit.
6. Inspect remote tree and commit, verify PRIVATE, scan tracked content again, review README rendering and license completeness. Clone to a fresh directory and run the documented setup/launch/synthetic basic workflow.

Do not change visibility or create a formal release without explicit user approval.

## Reviewer-source preparation — current instruction

The latest request supersedes earlier Public consent: remain PRIVATE and do
not create a formal Release until the user explicitly permits it again.
Read-only `git status`, `git diff --check`, `git check-ignore`, `git ls-files`
and REST `gh api repos/Jialong-Wang97/DSAP-Toolkit` were run; the fresh REST
response confirmed PRIVATE/main. The temporary EOF issue has cleared.
Only exact reviewed text paths are staged; source guards do not change science,
ROI Snapshot or save/lifecycle implementations. Publication of the missing
third-party core/adapters is not claimed. Follow-up commands/results below
record the normal source commit, private push and fresh-clone validation.

### Commands completed for the reviewer source candidate

1. `git add -- <explicit reviewed path list>`; `git ls-files` compared exactly
   with the 194-file allowlist. No `git add .` / force-add used.
2. `git diff --cached --check`: six existing whitespace warnings in previously
   untracked stable source (five EOF blank lines and one trailing-whitespace
   line). Kept source unchanged; no scientific patch was made for formatting.
3. Normal commit `df05c1d` (source/setup/example/docs), followed by normal
   `git push origin main`; remote advanced from `f57d6e9` through the prior
   local assessment commit `e146d30` to `df05c1d`.
4. Fresh `git clone` from the verified PRIVATE remote; `git rev-parse HEAD`
   matched `df05c1d`; no developer-directory checkout was used for the tests.
5. `git rev-list --objects --all` / `git cat-file`: 234 reachable blobs scanned;
   no common secret/personal-path/clinical-UID or binary-content hits.
6. `gh api .../readme` obtained actual rendered HTML. Initial unsupported
   `--output` option was corrected to PowerShell file redirection; no remote
   write resulted from that failed read-only invocation.
7. `gh api .../zipball/<commit>` downloaded the real GitHub ZIP; exact content
   parity and independent extracted-folder MATLAB test passed.
8. Both MATLAB tests exited 0 with PARTIAL_REVIEWER_SMOKE_PASS, and explicitly
   FULL_PERFUSION_WORKFLOW_NOT_TESTED. No unrelated scientific tests were run.
9. `git status --short` in the clean clone: empty after generated-output tests.
   Read-only per-command safe.directory was used where local ownership required
   it; no global Git trust setting was changed.

The follow-up evidence update uses explicit documentation-only staging, normal
commit/push, and final PRIVATE/remote-HEAD/status checks. No visibility mutation,
tag, Release, force push or history rewrite is part of this work.
