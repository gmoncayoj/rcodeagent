# rcodeagent 0.1.0

- Simplify the Account section to the two sign-in actions when disconnected and the authenticated email with Disconnect when connected; remove the duplicate green sign-in label.

- Identify connection HTTP failures by stage (OAuth exchange, identity keys or model catalog), status, recognized provider code and safe request ID. Omit response bodies and remove terminal formatting from connection notices. These diagnostics do not establish ChatGPT Free eligibility.

- Close cancelled OAuth sign-in notices after five seconds and translate them into the selected interface language. Other connection errors remain visible.
- Offer Use another account after disconnecting, starting a fresh account registration without previous identity hints and preserving token-free client mappings separately.

## Distribution preparation (2026-10-24)

- The author selected 0.1.0 as the current package and product version, replacing the unpublished 1.0.0 designation.
- Project documentation is in English, with a separate Spanish manual and necessary Spanish UI translations and examples.
- English is the default interface language when no valid preference is saved; an existing English or Spanish choice is preserved. Interface language does not determine the AI conversation language.
- Administrative confirmation now inspects function-default arguments, including nested formals, before submission. Ordinary explicitly requested code and package installation retain their existing permissions. Verification is tracked in `docs/validation/github-readiness.md`; earlier candidate results remain historical evidence.

## Auto workflow (2026-10-24)

- A current explicit instruction submits execution without a second confirmation, including new code and package installation. Target, console and additional administrative-operation controls remain enforced.
- Explicit selection or document recapture preserves an enabled Auto grant, renews its generation and cancels the previous request.
- Quoted, negated and conditional instructions do not authorize execution.

## Graphite theme (2026-10-24)

- Graphite background and dark gray panels follow the approved proposal, preserving the HD logo, layout and functional accents.
- Chat, code blocks, menus, About and notices use consistent neutral surfaces.

The distribution incorporates the accepted 0.5.7 implementation and subsequent changes:

- Native Background Job assistant in RStudio Viewer with a responsive console.
- Temporary Viewer recovery for 30 minutes, restoring the conversation, read-only attachments, model, effort, synced draft, selected target and prior Auto state after target revalidation.
- Normal generates and revises code only in chat; explicit Auto edits the chosen target, with conflict detection and cancellable workers.
- Native ChatGPT OAuth, streamed responses and Markdown rendering.
- Viewer admission validates the local host, origin and a private per-Job capability before initializing or restoring the chat.
- OAuth refresh validates replacement tokens and plan scope, invalidates terminal sessions, serializes rotation across processes and preserves encrypted storage on interrupted replacement. Disconnect attempts remote revocation and reports unconfirmed outcomes.
- Exact server patches and final ID/path/full-content checks protect edits. Classified administrative execution requires an exact preview and one-use confirmation; grants are not recovered after Viewer detach. Ordinary explicitly requested code and package installation do not require that additional confirmation.
- Intentional Auto edits may clear the selected context, including the last line of an unsaved document, while preserving target, range, syntax and conflict checks. Normal never writes. Empty new-script and execution proposals remain invalid. Worker failures show the root message without terminal color escapes.
- Spanish/English interface, local histories and HTML/JSON/Markdown/PDF exports.
- Spanish and English PDF manuals, standard package-root layout and GitHub check workflow.
- Author and maintainer: José Gamarra-Moncayo. About reads the installed package version.
- Licensed under GPL (>= 3), as specified by the author.

See `docs/validation/github-readiness.md` for current readiness, `docs/validation/auto-workflow.md` for historical workflow verification and `docs/validation/1.0.0.md` for earlier repair evidence.

## Historical Normal/Auto change (2026-10-19)

- Normal generated and revised code only in chat; Auto edited the chosen target.
- Auto submitted code to the main console only on explicit request. At that time, new code required one-use confirmation; the approved 2026-10-24 workflow above supersedes that requirement for ordinary code.
- Lines and ranges were validated without silent expansion. Submissions were one-use and were not replayed on Viewer return.
- Pending console input blocked submission. The user accepted native RStudio queueing.
- Results stayed in RStudio. A submission acknowledgment did not certify successful evaluation.

## Auto notice (2026-10-23)

- The notice appears only on Auto activation, without duplication during menu synchronization. It reuses one identifier and closes automatically after five seconds.
