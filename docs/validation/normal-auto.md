# Historical Normal/Auto implementation verification

Later Auto-notice correction: [auto-notice.md](auto-notice.md), October 23, 2026. Later graphical change: [dark-theme.md](dark-theme.md), October 24, followed by [auto-workflow.md](auto-workflow.md). Counts and hashes below belong to the October 19 unpublished **1.0.0** candidate. Shared logs and `integrity.json` may describe subsequent deliveries. They are not verification of the current 0.1.0 candidate.

Local rcodeagent 1.0.0 delivery, GPL (>= 3), updated October 19, 2026. The user approved implementation and subsequently accepted native RStudio queueing explicitly. No commit, push, remote, tag or publication occurred.

## Historical behavior

Normal generated and revised code exclusively in chat. Server checks blocked editor and console actions, including obsolete apply/create buttons. Auto required explicit target permission; editing did not imply execution. A bounded direct instruction resolved a package, line/range or selection from the captured document. New, ambiguous or classified administrative code required confirmation of an exact preview bound to a one-use authorization. The October 24 workflow later removed this additional confirmation for ordinary explicitly requested code and package installation.

Selections and text outside the range were preserved. Before writing, the complete expected result was computed; post-write recapture had to match ID, path and full contents. An unrelated change could not be adopted as an authorized result. Columns were handled as UTF-16 units and checked against selected text; inconsistent ranges failed closed. Lines were not silently expanded or executed when surrounding syntax prevented boundary validation.

The server bound workers to a grant generation: Auto → Normal → Auto could not revive a former authorization. An old nonce, another request or Viewer return could not repeat execution. Grants and nonces were absent from histories, exports and checkpoints. Viewer admission checks and model-worker IPC isolation remained.

The console used the fixed public `sendToConsole` operation, checking only current console input and revalidating the target before submission. Console output and the Environment were not automatically read for the model. Acknowledgment meant submission rather than successful evaluation. The user accepted queueing; Chat Stop and Close could not withdraw submitted code. The input check was not atomic and did not detect every busy/readline state. R was not sandboxed; code ran with the user's session permissions.

## Historical local evidence

- **Complete source suite:** 688 checks, 0 failures/errors/warnings/skips. `source-tests.log`.
- **Exact archive:** installed into a temporary library, with 688 passing installed checks; R CMD check returned 0 errors, 1 non-ASCII warning, 0 notes. `installed-tests.log`, `R-CMD-check.log`. The existing portability warning was not hidden or presented as a warning-free result.
- **Real Shiny UI and callr workers, synthetic provider/editor:** Normal chat-only; Auto editing; explicit line execution without editing; library loading without duplication; new-code confirmation; Viewer return without replay; Auto ON/OFF recovery; conflict revocation; cancellation of pending requests. Spanish/English, 1280/560 px, no JavaScript errors. `browser.json`, `normal-auto-*` screenshots and `execution-review-1280-es.png`. The Browser plugin was unavailable; installed Playwright and Chrome used loopback only.
- **PDF manuals:** Spanish/English, nine pages each; rendered pages visually reviewed, without out-of-bounds text or replacement characters. Three synthetic examples per language executed and checked. `manuals.json`, `manual-examples.log`.
- **Integrity:** `integrity.json` recorded exact-tarball hash, source matching, logo and manuals. The then-current transparent logo was unchanged. `source-files.sha256` identified verified files.

Historical final tarball: `dist/rcodeagent_1.0.0.tar.gz`, 951 457 bytes, SHA-256 `0165CE634FE3F73DAE9299E9853337B9CDED204C036520063EC80A0ED51FEA8E`. It contained 66 files: 65 matched source files byte for byte; DESCRIPTION had R packaging normalization. No unexpected files were present.

## Review and repairs

A partial independent review identified three issues before packaging:

1. Reactivating Auto could revive effects from a request dispatched under a revoked grant. A grant generation and editing/execution round-trip regression were added.
2. A syntax error outside the range could conceal expression boundaries and permit execution of an internal line. Boundary validation now fails closed and allows a distinct request for an explicit selection.
3. Post-write capture was adopted without comparison to the exact expected result. The complete document is now calculated and compared before preparing a second effect. A conflict revokes Auto, retains actual state and reports that execution was neither prepared nor submitted.

Each failure was reproduced before repair; regressions passed. Checks were added for UTF-16 ranges, text outside selections, quoted library names and execution messages localized at creation. The independent review stopped at the agent usage limit after these observations; self-review continued. No final independent verdict or new comprehensive security audit was obtained.

## Native evidence and limits

The user ran the public probe from a Background Job and observed `rcodeagent_qa_execution <- "idle"` in the main session. The user reported queueing and explicitly approved, in the original Spanish, “Sí, aceptar la cola nativa de RStudio”. Incomplete-input/readline phases showed assignments before their inputs opened and therefore did not validate those states.

The complete new Auto UI flow with a real provider inside RStudio still needed testing, including native console guards and new post-write checks. Browser substitutes did not establish real OAuth inference, account renewal/revocation, full native Viewer behavior or Linux/macOS support. Earlier native editing evidence remained in `native-history.md`; it was neither repeated nor represented as proof of these operations.

## Preparation and recovery

The repository had no commits. Work remained in the approved folder with a reversible previous-candidate copy; no commit was created to enable worktrees. Commit-based helpers were replaced by a local steps/results record. The previous archive, source files and temporary output were preserved in `C:/Users/JoseGM/AppData/Local/Temp/rcodeagent-normal-auto-20261019-01a14259/`. Its `normal-auto/before/` subfolder held the initial copy; `normal-auto/progress.md` held progress. The previous tarball SHA-256 was `0444F070223F9B1E241BA0D0725DDA8D24A3C04CCD87A4620D28A9F0CB6C7B4C`.

The first R CMD check attempt could not find dependencies that Rscript could load. It was repeated with the libraries visible to Rscript declared to the checker. `tools/release.ps1` retained that portable mechanism without personal paths. Dependency checks were not disabled and the package was not installed into the normal library.

At that time, Engram writes were blocked because the hook could not confirm the host session. No alternate identity was invented or registered. State and decisions were also recorded in `ESTADO.md` and this document. This is historical context, not a claim about current Engram availability.
