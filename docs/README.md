# Documentation

## Start here

- [Current CRAN preparation](validation/cran-readiness.md)

- [English user manual](manual/rcodeagent-0.1.0-Manual-EN.pdf)
- [Spanish user manual](manual/rcodeagent-0.1.0-Manual-ES.pdf)
- [Current 0.1.0 verification and publication limits](validation/github-readiness.md)
- [Administrative-confirmation repair](validation/administrative-confirmation.md)
- [English interface default](validation/english-default.md)
- [OAuth cancellation and account choice](validation/oauth-account-choice.md)
- [Free-account connection attempt and diagnostics](validation/free-account-connection.md)
- [Account section display](validation/account-section.md)

## Evidence and reference material

`validation/` contains retained test results, candidate fingerprints and screenshots. The current candidate is identified by `validation/integrity.json`; version-specific or dated reports explicitly marked historical describe earlier unpublished candidates, not new runs of 0.1.0.

`manual/` contains the current PDF manuals and their editable English/Spanish sources. `proposals/` preserves approved visual references. `superpowers/` preserves the earlier design and implementation plan; later recorded decisions supersede the original behavior where stated.

Disposable diagnostics and retired local artifacts live under ignored `.local/`. The current local source archive lives under ignored `dist/`; those directories are not part of the GitHub source tree.

The final cleanup removed duplicate generic log aliases. Historical mentions of
`R-CMD-check.log` and `installed-tests.log` refer to earlier shared filenames;
the current Windows results are retained as `cran-windows-r-release.log` and
`cran-windows-r-release-tests.log`. Current platform results and hashes are in
`validation/cran-checks.json`.
