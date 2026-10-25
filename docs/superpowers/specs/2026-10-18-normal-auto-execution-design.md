# Historical Normal/Auto execution design

Date: October 18, 2026. Status: **user-approved; implemented and verified locally; complete native verification pending**.

This is the approved historical design for the unpublished 1.0.0 candidate. The current author-selected package version is 0.1.0. The approved October 24 workflow in `../../validation/auto-workflow.md` supersedes the extra confirmation requirement below for ordinary explicitly requested code and package installation. Preserve this document as design history rather than applying superseded requirements to current behavior.

## Objective and scope

Simplify rcodeagent to two modes. Normal reads authorized context, discusses, explains, plans and generates/revises code in chat. Auto adds editing of the selected R target and execution in the main RStudio session when explicitly requested.

The historical design retained rcodeagent 1.0.0, GPL (>= 3), the transparent logo, OAuth, Background Job, Viewer and 30-minute recovery. It did not modify the IDE or use external-browser chat. No commit, push or publication was authorized.

## Alternatives considered

1. **Recommended: request-bound execution through the native console.** Retains the actual working session and ordinary RStudio workflow. Requires separate authorization, submission and result states.
2. Execute in an isolated worker. Easier cancellation/capture, but libraries and objects would live in another session, failing the requested use case.
3. Add a generic evaluation bridge with complete environment capture. Unnecessarily expands access and is outside this design.

## Modes and permissions

| Capability | Normal | Auto |
| --- | --- | --- |
| Read shared context and attachments | Yes | Yes |
| Generate/revise code in chat | Yes | Yes |
| Modify the selected target | No | Yes, as requested |
| Execute code in the main session | No | Only with request-specific authorization |
| Automatically execute every edit | No | No |

The proposed Spanish menu text was:

- **Normal:** “Solo lecturas y consultas, sin modificar ni ejecutar código en RStudio”.
- **Auto:** “Modifica el código en el destino elegido. Ejecuta código solo si se lo pides explícitamente”.

Normal is the initial value. Editor, Plan and Ask disappear from the menu. Users request planning through the message. Normal's iterative code generation/review remains in chat with manual copying. No apply/create/execute buttons may bypass Normal. The proposed Spanish permission message was: “El modo Normal no autoriza modificar ni ejecutar código en RStudio. Activa Auto o copia y ejecuta el código manualmente”.

The server checks permission before work and immediately before each effect. Prohibited model proposals are rejected regardless of prompt instructions. The model proposes actions; it does not grant permission.

## Expected behavior

Original Spanish request examples are retained to document the supported recognizer forms.

| Auto request | Historical proposed result |
| --- | --- |
| “Escribe library(lavaan) en el script” | Insert the call into the target without executing it. |
| “Carga/activa la librería lavaan” | Add `library(lavaan)` to the target, without duplication if it is already a standalone expression, and submit exactly that call. |
| “Ejecuta library(lavaan), sin agregarlo al script” | Execute that call without editing the script. |
| “Ejecuta la línea 32” | Submit only complete code on that captured-document line. |
| “Ejecuta las líneas 32 a 40” | Submit only the requested range if it contains complete expressions. |
| “Ejecuta la selección” | Use the captured range displayed as target, not a later selection. |
| “Corrige este bloque” | Edit only. |
| “Corrige este bloque y ejecútalo” | Edit, verify the result and show the exact block for execution confirmation. This confirmation rule was later superseded for ordinary explicit requests. |

The Spanish “Activar lavaan” means loading an installed package, not installing it. Installation needs a separate request. Missing objects/packages are diagnosed in the console; the model must not invent data or install dependencies on its own initiative.

## Execution authorization

Auto grants editing rather than permanent execution permission. Each execution binds to the current request, Viewer owner, target ID, path, full contents, range and exact submitted text. Authorization is consumed once before attempting submission.

For direct requests in the table, a server recognizer supports complete Spanish/English imperatives with bounded scope: named package, literal `library()` call, numeric line/range or captured selection. Finding an execution word inside unrelated text is insufficient. Negations, quoted examples, attachment/history instructions and model text do not grant execution.

Under this historical design, requests generating new code, executing a full script or using ambiguous scope required an exact preview and one-use “Run this code” confirmation. A changed target, code, mode or request expired that confirmation. Supported unambiguous direct requests did not require the additional step. The October 24 approval later removed this step for ordinary explicitly requested new code and installation.

No word filter makes R a sandbox. Code has the user's R session permissions and may modify objects, files or connections. Historically, identified administrative/destructive actions, including installation, deletion, system commands and session termination/restart, required review/confirmation instead of direct submission. The later approved workflow explicitly excludes installation from that additional classifier. Preview does not provide sandboxing.

## Editing, lines and conflicts

Revalidate target ID/path/full contents before editing or execution. A conflict blocks the action and revokes Auto while retaining code as a chat proposal. Unsaved R documents and captured ranges remain supported.

Line numbers are one-based within the complete document. Out-of-range lines, empty lines and comments alone produce an explanation without execution. A line inside a multiline expression is not silently expanded: request a complete range. `parse()` checks syntax without evaluation; it does not prove safety or statistical correctness.

For edit-and-execute, finish editing first. Recapture and compare the written result before preparing execution. If the second phase fails, report that editing succeeded but execution was not submitted; do not automatically revert the applied edit. Execution does not save files.

## RStudio integration and results

Public [sendToConsole documentation](https://rstudio.github.io/rstudioapi/reference/sendToConsole.html) supports code submission with an execution request. The [public rstudioapi code](https://github.com/rstudio/rstudioapi/blob/main/R/stubs.R) delegates to the IDE without a final-value capture contract. Therefore results, errors and plots remain in the usual RStudio panels. This scope excludes automatic Environment reading, full console-history capture and sending those data to the model.

Add one fixed native operation with `execute = TRUE`, `echo = TRUE`, `focus = FALSE` and `animate = FALSE`, reachable only after authorization validation. Model workers retain no IPC variables. The control channel enables no eval/source, arbitrary IDE command or generic endpoint.

Chat distinguishes pending authorization, cancellation before submission, submitted to console and unconfirmed submission requiring console inspection. An IDE acknowledgment must not be reported as successful evaluation. There are no automatic execute/read-errors/retry loops.

**Approved implementation amendment:** a native probe confirmed assignment in the main session with an idle console. The user reported queueing and explicitly approved, in the original Spanish, “Sí, aceptar la cola nativa de RStudio”. Queueing is accepted and explained before/after submission: Chat Stop cannot withdraw submitted code. Only current console input is inspected through `getConsoleEditorContext`; pending text or unverifiable state blocks submission. This preventive check is non-atomic and does not detect every busy/readline state. Human incomplete-input/readline probe phases showed assignment before input opened and did not validate those states or the complete Auto interface.

## Cancellation and Viewer recovery

Before submission, Stop, switching to Normal, disconnection or target changes cancel pending authorization. After submission, stopping a worker does not interrupt main-session R; direct the user to the console's native interruption control. Do not promise rollback of effects.

Every operation has a one-use identifier. Timeout or uncertain IPC response blocks new submissions and revokes Auto until a valid channel is recovered. Never resubmit automatically. Viewer return, history opening or message resubmission cannot reuse previous authorization.

When code opens results in Viewer, preserve chat and mode according to existing recovery rules. Submitted/unconfirmed status may reappear, but pending authorized execution must not. Submitted code remains under RStudio control; closing the Addin cannot guarantee stopping it.

## Documentation and verification

Update menu, messages, capability descriptions in About, README, help, Spanish/English manuals/PDFs, relevant metadata, AGENTS, ESTADO and validation records. The original instruction was to retain 1.0.0 unless the author requested otherwise; the author has now selected 0.1.0. Normalize historical Editor/Plan/Ask states to Normal; no history grants Auto or execution. Same-Job in-memory recovery uses a new schema and explicit validation.

Test server permissions, malformed/out-of-scope responses, negations/quoted instructions, conflicts, lines/multiline expressions, one-use execution, cancellation, uncertain submission and Viewer return. Separate synthetic provider/editor tests from native Windows evidence. Preserve Linux/macOS and real OAuth limits until specific evidence exists.

Associated plan: `../plans/2026-10-18-normal-auto-execution.md`. The user approved both documents with the original Spanish “Apruebo, implementa”. Later queueing acceptance amended the initial requirement. Final historical evidence and limits are in `../../validation/normal-auto.md`.
