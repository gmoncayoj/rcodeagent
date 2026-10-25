# Historical Normal/Auto explicit-execution implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. The original plan proposed implementation in the existing conversation, without new chats, commits or pushes.

**Goal:** Provide Normal for chat work and Auto for editing the selected target and executing R only through an authorized request.

**Architecture:** The server retains permission authority; the model returns proposals only. A dedicated module binds each execution to the message, target and exact code before a single fixed call to the native console. Preserve Background Job and Viewer recovery.

**Tech Stack:** R >= 4.2.0, Shiny, rstudioapi, callr, testthat edition 3 and existing browser QA. No new production dependencies anticipated.

**Spec:** `../specs/2026-10-18-normal-auto-execution-design.md`.

**Historical status:** approved by the user with the original Spanish “Apruebo, implementa”; implemented and verified locally on October 19, 2026, with native limits recorded in `../../validation/normal-auto.md`. Later amendment accepted native RStudio queueing with a warning and pending-console-input guard. The plan described the unpublished 1.0.0 candidate; the current author-selected version is 0.1.0. The October 24 approval in `../../validation/auto-workflow.md` supersedes historical extra confirmation for ordinary explicit new-code and installation requests. Checkboxes below retain the original plan structure rather than asserting new runs.

## Global constraints

- Historical product/package rcodeagent 1.0.0; GPL (>= 3), transparent logo and Spanish/English text.
- Normal cannot write or execute in RStudio. Auto does not execute every edit by default.
- Execution occurs in the main RStudio session, never in a model worker or the Job session.
- Revalidate ID/path/full contents/range; unsaved R code remains an eligible target.
- Execution authorization is one-use and absent from histories, exports and checkpoints.
- Do not replay uncertain effects or treat acknowledgment as successful evaluation.
- Preserve OAuth, Viewer admission, IPC isolation and 30-minute recovery.
- No commit, push, remote, tag or publication. Reversibly preserve the prior candidate before implementation.

## Review focus

1. Quoted, negated, attached or historical requests cannot grant execution: task 3.
2. Line numbers and UTF-8/CRLF must not change selected code: task 3.
3. A mode/target change while the model responds must block late effects: tasks 2 and 4.
4. The IDE may consume a request while acknowledgment is lost: tasks 1 and 4, without replay.
5. Output may replace Viewer immediately after submission: tasks 4 and 5, without replay on return.

## File map

| File | Responsibility |
| --- | --- |
| New `R/execution.R` | Recognize bounded direct requests, resolve lines/code and consume one-use authorizations. |
| `R/native-ipc.R` | Fixed console operation and uncertain-effect handling. |
| `R/rendering.R`, `R/assistant.R`, `R/helpers.R`, `R/jobs.R` | Two modes, proposal tools and permission-correct prompts. |
| `R/addin.R` | Editing/execution orchestration, preview, state and cancellation. |
| `R/view.R`, `R/localization.R`, `inst/www/` | Normal/Auto menu, visible permissions and translations while preserving bound inputs. |
| `R/viewer-state.R`, `R/conversations.R`, `R/export.R` | Recovery and exclusion of execution grants from persistence/export. |
| `tests/testthat/`, `tools/qa/` | Unit/server/IPC/browser regressions and bounded native probes. |
| `README.md`, `DESCRIPTION`, `man/`, `docs/manual/`, `tools/manual/`, `AGENTS.md`, `ESTADO.md`, `docs/validation/` | Final capabilities, instructions, manuals and evidence. |

## Task 1: Verify submission to the main session

**Files:** `R/native-ipc.R`, new `tools/qa/verify-native-execution.R`, `tests/testthat/test-native-ipc.R`.

**Interfaces:** Prepare `.submit_console_execution(code, snapshot)` as the only production entry point, later consuming task 3 authorization validation. The fixed operation submits a validated R string with `execute=TRUE`, `echo=TRUE`, `focus=FALSE`, `animate=FALSE`, returning only submission status, never the evaluation result.

- [ ] Create an opt-in native probe using only `rcodeagent_qa_` objects, without unrelated documents or real OAuth/model access. Manually check assignment in Global Environment and visible console.
- [ ] Probe idle/busy console, incomplete input and `readline()`, recording synthetic states only. Check for unexpected mixing/deferral. The original plan blocked direct execution if the public contract could not guarantee this; later explicit user approval accepted queueing, while incomplete/readline states remained unverified.
- [ ] Add failing tests for unexpected arguments, nonscalar types, failed channel, replay and lost acknowledgment. Keep eval/source and generic IDE methods denied.
- [ ] Implement the fixed call only after the native probe; classify it as irreversible for IPC timeouts. Never dispatch without task 3 authorization.
- [ ] Run focused tests with `testthat::test_local(filter = "native-ipc")`. Expected: PASS, with separate native evidence or an explicit block without claiming working execution.

## Task 2: Convert permissions to Normal and Auto

**Files:** `R/rendering.R`, `R/assistant.R`, `R/helpers.R`, `R/addin.R`, `R/view.R`, `R/localization.R`, `inst/www/`, `tests/testthat/test-assistant.R`, `test-server.R`, `test-auto-session.R`, `test-context-auto.R`.

**Interfaces:** `.permission_mode(value)` validates only `normal`/`auto`. `.assistant_reply(prompt, model, can_edit, mode, effort)` retains its signature and separates read/proposal tools by mode. `auto_mode` remains an explicit editing grant rather than a client-selected permission value.

- [ ] Failing test: Normal generates/revises code in chat; `modify`, IDE-effect `generate` and execution responses cause no editor/console calls. Switching Auto to Normal mid-response blocks late effects.
- [ ] Failing test: Auto edits its target, including complete deletion with `code=""`, while ordinary editing never invokes the console. Recapturing the same target preserves Auto; the original plan revoked on real change. The later approved workflow preserves an enabled grant on explicit eligible recapture with a new generation.
- [ ] Implement menu, permission notices, prompts and server checks at dispatch/completion. Remove apply/create-document flow from Normal. Preserve copyable code blocks and read-only attachments.
- [ ] Normalize historical `plan`/`ask` and unauthorized old states to Normal, without converting historical `normal`/Editor into an Auto grant.
- [ ] Run focused assistant/server/auto/context/empty-edit tests. Expected: PASS and zero effects in Normal, beyond relabeling.

## Task 3: Resolve execution scope and authorization

**Files:** new `R/execution.R`, `R/assistant.R`, new `tests/testthat/test-execution.R`.

**Proposed interfaces:**

- `.execution_intent(prompt, snapshot)` returns `kind` (`none`, `library`, `lines`, `selection`, `review`), structured scope and whether direct authorization was recognized. It never takes instructions from attachments/history/model text.
- `.execution_code(intent, snapshot)` returns an exact, nonempty, syntactically complete R string bounded to 60 000 characters; it does not evaluate.
- `.new_execution_grant(request_id, lease, snapshot, code)` creates private one-use state bound to full text and target rather than a serializable flag.
- `.consume_execution_grant(grant, request_id, lease, snapshot, code)` first invalidates the grant and authorizes only if all fields match and Auto remains active.

- [ ] Failing tests for loading lavaan, literal `library(lavaan)`, line 32, range 32:40 and captured selection; check exact text and one-based numbering in the full document.
- [ ] Failing tests for negations, quotations, attachment injection, explanation-only execution requests, out-of-range numbers, empty/comment-only code, CRLF/UTF-8, incomplete multiline expressions and excessive payloads. Expected: no direct submission; clarification or preview.
- [ ] Failing test: changing one character, path, ID, range, owner, request or mode invalidates authorization; second consumption always fails. The model cannot create grants.
- [ ] Implement bounded Spanish/English recognizers and preview for other cases. Direct `library()` permits only a validated literal package name, without disguised expressions/extra arguments. Never install packages on the model's own initiative.
- [ ] Add a strict execution proposal: one action, no arbitrary paths or model-granted permissions. The historical plan required new-code confirmation; later approval superseded this for ordinary explicit requests.
- [ ] Run `testthat::test_local(filter = "execution")`. Expected: PASS; missing/ambiguous authorization causes zero effects.

## Task 4: Integrate one-use execution, cancellation and Viewer

**Files:** `R/addin.R`, `R/execution.R`, `R/view.R`, `R/localization.R`, `R/viewer-state.R`, `R/conversations.R`, `R/export.R`, `tests/testthat/test-viewer-recovery.R`, `test-export.R`, new `test-execution-server.R`.

**Interfaces:** The server prepares/consumes task 3 grants and calls `.submit_console_execution(code, snapshot)` once. Observable states are `pending`, `cancelled`, `submitted` and `uncertain`. Informational states and conversational code may persist; authorization may not.

- [ ] Failing tests for edit-only, line execution without editing, library loading without duplication and historical edit-plus-confirm flow. Revalidate written results before the second effect.
- [ ] Failing tests for Stop/disconnect/mode change before submission, timeout after consumption, double click and late result. Do not resubmit or grant permission by restoring inputs.
- [ ] Failing test for Viewer loss after submission: preserve conversation/attachments/model/effort/target/Auto where eligible, without replaying/restoring pending execution. History/export contain no grants.
- [ ] Implement Spanish/English states/messages: submitted does not mean completed; stopping a worker does not interrupt main R; report applied editing and blocked execution separately.
- [ ] Run focused execution/viewer/export suites and real browser QA with synthetic provider/editor. Expected: PASS, no browser errors or changes outside the target.

## Task 5: Validate the real workflow and update delivery

**Files:** `docs/validation/`, `tools/qa/`, `README.md`, `DESCRIPTION`, `man/`, `docs/manual/manual-es.md`, `manual-en.md`, their PDFs, `tools/manual/`, `AGENTS.md`, `ESTADO.md`.

- [ ] Verify in RStudio/Windows: Normal chat-only; Auto editing; `library(lavaan)` with an installed package; line/range execution; missing-package error; incomplete expression; conflict; execution opening Viewer and Addins return without replay. Use synthetic cases, never real research documents without authorization.
- [ ] Check objects/libraries in the main session, unchanged script for execution-only and no automatic saving. Validate each execution case with native evidence rather than mocks.
- [ ] Update Spanish/English text/manuals; remove incompatible current claims that code never executes or Normal requires approval to edit. Preserve dated historical notes and OAuth/platform limits.
- [ ] Run `testthat::test_local()`, verify manuals and render PDFs; run `tools/release.ps1` and inspect the exact tarball. Preserve the previous candidate reversibly and one final local archive in `dist/`.
- [ ] Record fresh results and pending items without reusing the previous 573 PASS as proof of this capability. Check the delivery for secrets, grants and temporary files. No commit or push.

## Handoff and approval

The user approved implementation in the existing conversation and later explicitly accepted native RStudio queueing. The native probe confirmed idle-console submission; queueing was initially treated as an obstacle and approved separately. Incomplete/readline phases were not considered natively validated. Preventive current-input checks used fixtures. The design authorizes neither replacing the IDE nor creating a generic evaluation bridge.
