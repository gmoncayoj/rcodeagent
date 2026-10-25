# English interface default

Validated locally on October 24, 2026 for rcodeagent 0.1.0.

`R/preferences.R` defaults to English when no valid saved preference exists. Valid saved English and Spanish choices remain unchanged. The setting translates only product UI; it does not translate user messages, model responses or prompts.

The preference tests cover the fallback, saved choices, initial rendered configuration and server language selection. The Auto-notice regression identifies the notice by its stable ID so it remains independent of translation.

A real local Shiny session with synthetic provider/editor data started in English, preserved a Spanish draft unchanged, saved a switch to Spanish and retained Spanish after reload. No page errors were observed. See [machine-readable result](english-default.json), [desktop screenshot](english-default-1280.png) and [narrow screenshot](english-default-560.png). No real account, editor or user preference was modified.

Both nine-page manuals were regenerated, checked for text bounds and replacement characters, and the changed language pages were visually reviewed. Final package checks and archive identity are recorded in [GitHub readiness](github-readiness.md).
