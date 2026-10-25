# Repository readiness review - updated 2026-10-25

Publication update: the author explicitly authorized the initial commit and push
to https://github.com/gmoncayoj/rcodeagent on October 25, 2026. Independence and
trademark notices were added to the README before publication. The no-commit,
no-remote and no-publication statements in the preparation record below describe
its prepublication snapshot, not a continuing prohibition. The initial remote
was verified empty. CRAN submission and release creation are separate actions.

**Current status:** the repository is organized for local preparation. The author selected **rcodeagent 0.1.0**, replacing the unpublished 1.0.0 designation, and requested English project documentation. **The administrative-confirmation finding is repaired and locally verified in 0.1.0.** Source/installed suites, the exact archive and both manuals passed the checks recorded below. Earlier counts and hashes remain historical evidence. This is a local 0.1.0 candidate with the native/provider/platform limits stated below; no commit, push, remote or release is authorized.

## Structure and cleanup

The root is the R package `rcodeagent`, GPL (>= 3). Preserve `R/`, `inst/`, `man/`, `tests/`, reproducible tools, manuals and sanitized evidence. Approved historical designs in `docs/proposals/` and plans in `docs/superpowers/` provide context; they are not temporary files.

`dist/` is ignored local archive output. `.local/publication/` holds disposable candidate manifests, tests, queries and diagnostics. The earlier review found no other unnecessary temporary root files and removed no sources, approved images, manuals or prior evidence.

The October 25 final GitHub preflight removed two byte-identical log aliases:
`R-CMD-check.log` and `installed-tests.log`. Their complete contents remain in
`cran-windows-r-release.log` and `cran-windows-r-release-tests.log`, respectively.
It also removed 30 stale temporary files or empty directories under ignored
`.local/`; source files, distinct validation results and historical references
were retained. The final candidate contains no byte-identical duplicate files.

Expanded `.gitignore` and `.Rbuildignore` cover environment variants, private keys, temporary copies, caches and local editor/agent state. The historical review passed 25 exclusion checks without creating test credentials. Manuals, retained evidence and `AGENTS.md` remain public candidates. Do not bypass exclusions with `git add -f`.

## Authorship

The earlier review confirmed effective Git author/committer identity `Jose Gamarra <gamarramoncayoj@gmail.com>`. `DESCRIPTION` and R-normalized archive Author/Maintainer fields named only José Gamarra-Moncayo. Both reviewed PDFs had the same Author, ReportLab as Producer and an unspecified Creator. No AI agents were authors or coauthors.

The October 25 preflight aligned the local Git name with the complete package
author name. Both effective author and committer now resolve to
`José Gamarra-Moncayo <gamarramoncayoj@gmail.com>`. The repository still has no
commits, staged changes or remotes. No author/committer environment overrides,
active hooks or commit template were present. Copyright notices in the standard
GNU license text are preserved; they do not attribute package authorship.

The final preflight results are recorded in [github-preflight.json](github-preflight.json).
The reviewed CRAN archive and manual hashes are unchanged after this cleanup.

There were no HEAD, commits, staged files or remotes; no active hooks, configured commit template or AI attribution trailers were found in candidate files. Technical mentions of ChatGPT/OpenAI/Codex describe integration, not GitHub authorship. Recheck identity and the exact message before any future authorized commit; this inspected state cannot guarantee future tool behavior.

## Historical unpublished 1.0.0 verification

- Source suite: **725 PASS, 0 FAIL, 0 WARN, 0 SKIP**, R 4.6.1/Windows, synthetic provider/editor and local workers. Disposable record: `.local/publication/source-tests-isolated.log`.
- Historical archive SHA-256: `C2AC049920E5C642187541ABD03A599E363B2E6223FBBBC922847F43DA155803`, matching the then-current `integrity.json`. It contained 67 files: 66 matched sources and DESCRIPTION was normalized, with no unexpected files or unsafe paths in that comparison. This review did not regenerate or replace that archive.
- `R CMD check --no-manual --no-vignettes` of that exact archive: **0 errors, 1 preexisting non-ASCII warning, 0 notes**. Installed tests also returned 725 PASS, 0 FAIL/WARN/SKIP. Records: `.local/publication/archive-check-final.log` and `.local/publication/check-final/rcodeagent.Rcheck/`. Access to installed libraries was restored; Suggests and tests were not disabled.
- Secret-pattern scanning and contextual review identified no real credentials in candidate contents. No credentials were used and no provider authentication occurred. This does not cover every possible secret or information hidden in pixels/binary containers.
- OSV queried on October 24, 2026 for 58 runtime/test CRAN dependencies at installed versions: no matching advisories, no pending pagination or missing dependencies; positive control passed. Evidence: `dependencies-osv-2026-10-24.json`. System libraries, vendored code, the IDE and Python generators were outside scope.
- Static review covered execution, OAuth, storage, Viewer, IPC, permissions, rendering, history/export, tools and selected tests. **One medium-severity finding** was confirmed in the administrative-confirmation classifier. The detailed report and nondestructive probe remain outside Git in private Codex Security storage.

The first source attempt failed because sandbox temporary paths denied file renaming. The full suite passed with TEMP/TMP inside the project; no product regression was suppressed. The initial sandboxed archive check also failed to recognize installed libraries and is not the final result.

## Current 0.1.0 verification

- Source suite and installed archive suite: **827 PASS, 0 FAIL, 0 WARN, 0 SKIP** each. A new regression file covers function defaults, nested/namespaced calls, lambda syntax, absent formals, ordinary defaults, installation compatibility, exact nonce confirmation and invalidation/replay. The reproducer failed before the patch; 149 focused execution checks passed afterward. An independent candidate reviewer found no concrete remaining bypass/regression in scope. See [repair evidence](administrative-confirmation.md).
- `R CMD check --as-cran` on the exact `dist/rcodeagent_0.1.0.tar.gz` candidate in Windows and Linux R-release: **0 errors, 0 warnings, 1 expected New submission NOTE**. PDF and HTML manuals are included. Current CRAN evidence and further platform results are in [CRAN readiness](cran-readiness.md). Tests and Suggests remained enabled. A separate local installation checked metadata, registration, UI assets and a real local worker without OAuth. Current logs: `source-tests.log`, `cran-windows-r-release-tests.log`, `cran-windows-r-release.log`; all three platforms are indexed in `cran-checks.json`.
- Tarball SHA-256: `9722E46A057AF4726A4B6072258B0EC067415462BE06272975312E85D28F5FD0`; 681753 bytes, 72 files. All 71 source-comparable files match; DESCRIPTION is normalized. No unexpected files or unsafe archive paths. Current hashes are in `integrity.json` and `source-files.sha256`.
- English and Spanish PDFs use 0.1.0 in filenames, titles, headers and footers, and identify only José Gamarra-Moncayo as author. Both have nine pages, zero out-of-bounds words and zero replacement characters; all pages were rendered and visually checked. Manual R snippets parse and the synthetic examples are checked separately.
- Documentation is English, including GitHub issue labels and installed help. Intentional exceptions: the Spanish manual, original Spanish UI/command examples and quotations, and unmodified historical screenshots/log data. The GPL license and third-party notices remain unchanged. Current version tooling reads DESCRIPTION; dependency versions and historical candidate facts were not relabeled.
- The old 1.0.0 archive and PDFs were moved reversibly into ignored `.local/archive/1.0.0/` with their hashes preserved. `dist/` contains only the current candidate. The HD logo retains its recorded hash.
- Current candidate inspection found no embedded secret patterns and confirmed human package/tarball author metadata; Git remains without HEAD, staging, remote or publication. The dated OSV results above remain limited to those queried dependency versions.

Engram is external development tooling. On **2026-10-24**, the real host startup/resume hook supplied the registered runtime identity. A fresh attributed `mem_save` created observation **105**; a subsequent `mem_get_observation` confirmed the exact verification marker, project and host-confirmed session identity. **The real attributed write/read check passed for this chat**, closing the restart follow-up. Earlier ten doctor checks and isolated native/startup-wrapper tests remain supporting diagnostics. No live identity was invented or manually selected, and no system upgrade or hook configuration change was needed. Diagnostic output is ignored under `.local/engram-repair/`.

Real OAuth/inference/renewal/revocation, native compatibility of the Viewer admission control and actual Windows/Linux/macOS CI remain unverified. The configured workflow uses `contents: read`, has no publishing step and uses major action tags; it had not run on a remote for this project. No exhaustive audit or security certification is claimed.

## First commit and push criteria

The administrative repair, local candidate checks and Engram attribution follow-up are complete within their recorded scopes. Inspect the definitive manifest and preserve visible verification limits before publication. The author must authorize commit/remote/push creation and check identity, message and absence of automatic attribution trailers. None of these publication operations occurred during this review.

## Approved README

The current local evidence supports sharing the source as a local 0.1.0 candidate with the recorded limitations visible. It does not establish a stable release or universal platform/provider support. GitHub CI can run after the first authorized push; real-provider lifecycle and native/cross-platform verification remain follow-up work.

On October 24, 2026, the author approved the English README with the existing centered logo and version label, source-folder installation and a missing-value mean example. The example was evaluated locally: the unadjusted mean is NA and the valid-score mean is 16.25. The approved text now replaces the root README; its previous contents and the rendered preview are retained under ignored `.local/readme-proposal/`. No remote URL or install-from-GitHub identity was invented. `docs/README.md` indexes current manuals, validation and historical reference material without moving or deleting retained evidence.

The README states that English/Spanish selection affects only the plugin interface, independently of the language used with the AI. Current model-usage requirements follow OpenAI's [Sign in with ChatGPT quickstart](https://developers.openai.com/siwc/quickstart): an eligible Plus or Pro subscription is required, including for the open-source integration. Free model usage is not supported by rcodeagent. Earlier broad availability wording was corrected after the author identified this explicit requirement. Identity sign-in alone does not authorize inference; service-issued permissions and account-specific models remain necessary. A reported Free connection attempt failed; its generic HTTP 400 does not identify the precise rejection cause.

The interface now defaults to English when no valid saved choice exists. Valid saved Spanish/English choices are preserved. Preference/server/rendering regressions and a local Shiny browser check verified English startup, Spanish persistence after reload and unchanged user-language text. See [English-default evidence](english-default.md). Both manuals and the current 0.1.0 archive include the change.

OAuth cancellation/account-choice correction: validated access-denied callbacks now produce a localized five-second notification; other errors remain visible. After disconnection, Use another account starts a new registration without prior identity hints; normal sign-in retains reconnection. Client/account metadata is preserved separately without tokens. Regression tests and synthetic browser checks passed; actual provider account switching remains unverified. See [OAuth correction evidence](oauth-account-choice.md).

The reported Free-account connection failed; its exact rejection cause is unconfirmed. Connection errors now distinguish OAuth exchange, identity keys and model catalog, remove ANSI formatting and omit raw provider payloads/credentials. Synthetic HTTP and browser checks verify safe diagnostics, not a repair of actual provider eligibility. See [Free attempt and diagnostics](free-account-connection.md).

The Account section now shows only the two sign-in actions while disconnected and the authenticated email with Disconnect while connected. The duplicate green label was removed; hidden email output remains reactive and clears on disconnection. Browser checks covered sign-in, signout and a second synthetic account at desktop/narrow widths. See [Account section evidence](account-section.md).
