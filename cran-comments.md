## Submission

This is the first CRAN submission of rcodeagent, version 0.1.0.

The package provides a coding assistant in the RStudio Viewer, with explicit
controls for sharing context, editing the selected R document and submitting
code to the native console. Interactive use requires RStudio Desktop and a
browser. Model requests require Internet access, an operating-system credential
store and an eligible ChatGPT Plus or Pro account under the service's terms.

Examples are conditional on an interactive RStudio session. Automated tests use
synthetic credentials, mocked provider responses and temporary storage. They do
not open a real browser, contact the model provider or require a paid account.
Unit tests of callback setup mock localhost listeners; local worker and IPC
tests retain their protocol and cancellation checks.

## Check results

Checked the same source archive with R CMD check --as-cran, including PDF and
HTML manuals, on:

- Windows 11, R 4.6.1 (ucrt).
- Ubuntu 24.04, R 4.6.1.
- Ubuntu 24.04, R-devel (2026-10-18 r90707).

All three runs returned 0 errors, 0 warnings and 1 NOTE: New submission.
Each installed-package suite passed 827 checks, with no failures, warnings or
skips. The final sequential source suite also passed 827 checks.

The source archive is rcodeagent_0.1.0.tar.gz.
SHA-256: 9722E46A057AF4726A4B6072258B0EC067415462BE06272975312E85D28F5FD0

The earlier non-ASCII R-source warning was removed by using Unicode escapes,
with parsed-expression equivalence verified. Tests use isolated temporary
preferences and explicit language choices; they do not read user preferences.

The CRAN incoming NOTE for a new submission is expected. No submission to CRAN
has been made by the preparation tools.
