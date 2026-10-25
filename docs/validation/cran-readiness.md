# CRAN preparation - rcodeagent 0.1.0

Preparation date: October 25, 2026. This is a local submission candidate; no
submission, commit or push has been made.

The author requested version 0.1.0 without a prerelease designation. The current
interface, README, manuals and textual project documentation now use that version
without the earlier public prerelease label. Retained screenshots of previous
builds remain historical evidence and are excluded from the CRAN source archive.

## Policy-oriented changes

- Functional English DESCRIPTION and installed help, quoted external software
  names, explicit service/IDE requirements and examples guarded for interactive
  RStudio sessions.
- ASCII R source with Unicode escapes. Parsed expressions were checked for exact
  equality before and after encoding conversion, preserving interface messages.
- Unit tests no longer bind real callback ports. testthat requires version 3.2.1
  for the mocked object bindings used by the suite.
- tools/release.ps1 supports a full --as-cran check, including PDF and HTML help.
  The CI configuration includes Windows, Linux and macOS release checks plus
  development/previous R versions. Configuration is not evidence of a remote run.
  The workflow YAML parsed successfully with all six matrix configurations.

## Final verification

The exact archive is `dist/rcodeagent_0.1.0.tar.gz`, 681753 bytes, SHA-256
`9722E46A057AF4726A4B6072258B0EC067415462BE06272975312E85D28F5FD0`.
Its 72 files contain 71 byte-identical source-comparable files plus R-normalized
DESCRIPTION, with no unexpected files or unsafe paths. Author/Maintainer fields
identify only Jose Gamarra-Moncayo; the UTF-8 spelling is retained in the package.

| Environment | Command | Errors | Warnings | Notes | Installed tests |
| --- | --- | ---: | ---: | ---: | ---: |
| Windows 11, R 4.6.1 (ucrt) | R CMD check --as-cran | 0 | 0 | 1 | 827 PASS |
| Ubuntu 24.04, R 4.6.1 | R CMD check --as-cran | 0 | 0 | 1 | 827 PASS |
| Ubuntu 24.04, R-devel 2026-10-18 r90707 | R CMD check --as-cran | 0 | 0 | 1 | 827 PASS |

The only NOTE in each final run is **New submission**. PDF and HTML manuals,
examples, installation, declared dependencies and documentation checks passed;
no tests or Suggests were disabled. The source suite also passed 827 checks with
no failures, warnings or skips. See [exact check-log fingerprints](cran-checks.json),
[Windows log](cran-windows-r-release.log), [Linux release log](cran-linux-r-release.log)
and [R-devel log](cran-linux-r-devel.log). `tools/cran_manifest.py` checks completed
logs, test results, package version, archive/source equality and before/after
container archive hashes before generating the manifest.

Linux checks ran in isolated Rocker containers limited to two CPUs and 4 GB each,
with only their disposable QA folder mounted. Image digests were
`rocker/r2u@sha256:dc2a96c3b368969635c25c177c64514ba8e37cf2259dd3584de7c33520191d92`
and `rocker/drd@sha256:b93e95ba34f191b988d8ada18453475ed41f6417c76ee34f828b720c07210fcc`.
The release PDF check used standard `times,hyper` fonts because Inconsolata was
absent; it did not omit PDF generation. R-devel generated the PDF with its default
configuration. Both environments included Pandoc and HTML Tidy in their final runs.
The two task-owned containers were removed after verification; their bind-mounted
logs, archive copies and setup records remain under ignored `.local/cran-prep/`.

The current UI shows 0.1.0 without a prerelease label; synthetic browser checks
passed at desktop and narrow widths. Both nine-page user manuals passed text,
replacement-character and bounds checks; changed pages were visually reviewed.
Secret-pattern scanning of Git candidates found no matches; this is not an
exhaustive security audit. The existing classifier repair and execution controls
remain covered by the suite.

## Failed attempts retained and resolved

An earlier Linux candidate failed one locale-dependent assertion: it expected a
Spanish target label without selecting Spanish. The final fixtures now isolate
preferences per test and select Spanish explicitly in that case. Linux checks
also identified missing Pandoc/Tidy in the initial container setup; the tools
were installed and complete checks repeated. R-devel dependency setup initially
lacked libuv headers; installing them allowed the unchanged CRAN dependencies to
build. These environment failures were not counted as package passes.

A concurrent source checkout run timed out in native-IPC fixtures with a
12-second child-startup budget while other checks/dependency compilation were
active. Without changing IPC checks or timing thresholds, a focused run passed
32 checks and a full sequential rerun passed 827. The unsuccessful and final
logs are retained under ignored `.local/cran-prep/`. Run source IPC verification
without competing dependency builds when diagnosing such startup failures.

The official CRAN current package list, CRAN Archive and Bioconductor software
index were checked on October 25, 2026 without finding a case-insensitive name
conflict. All declared dependencies were available at the required versions;
see [repository audit](cran-repository-audit.json).

## Scope and submission notes

No real account, model request or user credential was used in this preparation.
Native RStudio/provider lifecycle and operating-system credential-store workflows
remain separate from automated R package checks. Review generated code and
results. The maintainer must retain rights to all supplied assets and ensure the
public maintainer email can receive CRAN correspondence. CRAN's editorial team
decides acceptance; automated checks do not guarantee it.

Primary requirements: [CRAN policies](https://cran.r-project.org/web/packages/policies.html),
[submission checklist](https://cran.r-project.org/web/packages/submission_checklist.html)
and [Writing R Extensions](https://cran.r-project.org/doc/manuals/r-release/R-exts.html).
