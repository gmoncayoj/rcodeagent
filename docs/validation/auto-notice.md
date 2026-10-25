# Historical Auto notice correction — 2026-10-23

This record concerns the unpublished **rcodeagent 1.0.0** candidate, GPL (>= 3). It is not verification of the current 0.1.0 candidate. The logo and artifact changed on October 24; see [logo-hd.md](logo-hd.md). The fingerprint below belongs to the historical notice delivery. Shared integrity files and logs may describe a later candidate.

The user requested one Auto notice that disappears automatically after five seconds, replacing overlapping notices.

## Cause and change

The shield sent `auto_requested`; the server synchronized the menu radio and subsequently received `mode`. Both events called `set_auto(TRUE)` and displayed notices with fresh identifiers and a ten-second duration.

The notice is now emitted only on an actual OFF-to-ON transition. It reuses `rcodeagent-auto-notice` with `duration = 5`, so reactivation cannot stack another identifier. Spanish/English text remains available. Permissions, Auto generations, execution, Viewer recovery, logo and manuals were unchanged by this correction.

## Historical verification

- The new server regression failed before the correction, reproducing two notices, a ten-second duration and unstable identifiers. It checks activation, the mirrored menu event and genuine reactivation.
- Complete source suite: **694 passing checks**, with no failures, errors, warnings or skips. `source-tests.log`.
- Real browser with Shiny/workers and synthetic provider/editor: one notice after the mirrored event and automatic dismissal with a five-second timer. Normal/Auto and Viewer recovery still passed in Spanish/English at 1280/560 px without JavaScript errors. `browser.json` includes `auto_notice_single` and `auto_notice_auto_dismiss_5s`.
- The archive and sources were compared in `integrity.json`; the logo and both manuals retained their hashes. This historical candidate remained 1.0.0.
- Installed package: **694 passing checks**. Exact-archive R CMD check: **0 errors, 1 preexisting non-ASCII warning, 0 notes**. `installed-tests.log` and `R-CMD-check.log`.

Historical tarball: `dist/rcodeagent_1.0.0.tar.gz`, 951 905 bytes, SHA-256 `BD582EEFD850E0D8903F59F426F348AD4C18C2F85B4062421B2EABC0AC2A9F1D`. It contained 67 files: 66 matched the sources byte for byte, and DESCRIPTION was normalized by R packaging.

No real accounts or documents were used. Notice behavior was checked in Chrome with the same Shiny client; this was not a new native RStudio Viewer test. The limits recorded in `normal-auto.md` remain applicable.

No commit, push or publication occurred. The previous candidate and temporary files were retained in `C:/Users/JoseGM/AppData/Local/Temp/rcodeagent-auto-notice-20261023-01a14259/`. At that delivery, `dist/` held only its then-current archive.
