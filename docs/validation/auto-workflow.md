# Historical Auto execution and context change — 2026-10-24

This evidence belongs to the unpublished **rcodeagent 1.0.0** candidate. It must not be relabeled as verification of 0.1.0.

Changes requested by the author after native testing:

- A current explicit execution instruction in Auto is submitted without another preview or confirmation, including new code and `install.packages()`. The Spanish “Ejecuta” uses captured context; “Instala el paquete lavaan” prepares the exact call on the server, without implicitly editing or loading the package.
- Explicitly choosing a selection, active file or R script preserves an already enabled Auto grant, cancels the previous request and renews the grant generation when the snapshot changes. Capture cannot activate Auto from Normal. Full project/attachments remain read-only and do not change the target.
- Full ID/path/content/range conflicts, post-write verification, generation-bound grants, console-input checks, fixed IPC and one-use execution authorization remain enforced. Capture failures, incompatible targets and changes without recapture still revoke Auto. Viewer return and repeated clicks do not resubmit code.

Automatic approval review rejected removing the general administrative control. The author clarified that installing packages needs no confirmation and, when asked specifically, retained the control for file deletion/movement, system commands, source/eval and closing R. The remaining classifier uses an exact preview and one-use nonce; installation is excluded. It neither sandboxes R nor exhaustively classifies its effects.

The model only proposes. The server requires a recognized imperative in the current message; an `execute` tool cannot authorize itself. Regressions cover ASCII/typographic quotations, negations and conditions: the original Spanish examples “corrige el comentario que dice ‘ejecuta…’” and “ejecuta cuando te confirme” do not authorize execution. A focused independent review identified those two failure classes and an omitted combined instruction; they were corrected and tested. This was not a comprehensive audit.

The initial regression reproduced both former behaviors. Mock Shiny tests covered selection/document changes, generations, new execution, synthetic installation, administrative confirmation, Normal and prevention of replay. Chrome with real Shiny/callr and a synthetic provider/editor covered the same Spanish/English flows and Viewer recovery, without OAuth or actual package installation/file deletion. Regenerated Spanish/English manuals had nine pages; bounds and text checks passed and changed pages were visually reviewed.

Historical evidence: `browser.json`, `auto-workflow-1280.png`, `auto-workflow-admin.png`, `source-tests.log`, `installed-tests.log`, `R-CMD-check.log`, `manuals.json` and `integrity.json`. Shared evidence files can be replaced by later candidate checks; the counts and fingerprint below identify this delivery. The new experience still needs human testing with the real provider inside RStudio. Previously resolved native tests were not repeated. No commit or push occurred.

Historical final verification: **725 PASS** for source and installed suites, with no failures, test warnings or skips. Exact-tarball R CMD check: **0 errors, 1 preexisting non-ASCII warning, 0 notes**. The archive had 676402 bytes and 67 files: 66 matched source files, DESCRIPTION was normalized, and no unexpected files were present. SHA-256: `C2AC049920E5C642187541ABD03A599E363B2E6223FBBBC922847F43DA155803`. The logo was unchanged; manual hashes were recorded in `integrity.json`. Backups, previous candidates and temporary files were preserved outside the project in `C:/Users/JoseGM/AppData/Local/Temp/rcodeagent-auto-workflow-20261024/`.
