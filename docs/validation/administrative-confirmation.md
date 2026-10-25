# Administrative-confirmation repair — 0.1.0

## Outcome

**Fixed and locally verified.** The narrow fix is in `R/execution.R`; regression tests are in `tests/testthat/test-execution-formals.R`. It restores the retained administrative preview/confirmation boundary without changing ordinary explicitly requested execution or package-installation permissions.

## Cause and shared boundary

The classifier previously discarded every non-call AST node. Function formals are pairlists, so administrative calls within their defaults were skipped. Both direct context/line/selection requests and authorized model execution proposals consume the same classifier in `R/addin.R`; a false result allowed submission without the additional exact review.

The classifier now recursively visits pairlist elements before the existing non-call leaf check. It never evaluates the parsed expressions. Existing sensitive-call classification, namespace/computed-call handling, Auto generations, target checks, one-use execution grants, nonce validation and native IPC remain unchanged.

## Evidence

- Before the patch, six default-argument classifier cases failed and the model-proposal server fixture submitted before confirmation. The strings were only parsed/classified; destructive operations were never evaluated.
- After the patch, **149 focused execution checks passed**. Coverage includes direct and namespaced calls, nested defaults/functions, lambda shorthand, missing formals, safe functions, ordinary installation and sensitive installation arguments.
- Server fixtures verify zero submissions before review, rejection of forged or revoked nonces, exact code submitted once with the current nonce and rejection of replay. Both model proposals and direct context execution are covered.
- Independent pre-patch boundary investigation and one fresh candidate review completed. The reviewer found no concrete surviving bypass/regression in scope and independently passed 12 administrative variants and 9 compatibility controls.
- Full source and exact installed-archive suites each passed **827 checks, 0 failures/warnings/skips**. The current exact-candidate CRAN-style checks are recorded in [CRAN readiness](cran-readiness.md); the original non-ASCII source warning has been eliminated. Candidate integrity is recorded in `integrity.json`.

The original sealed security scan remains unchanged. This repair does not claim an exhaustive audit, a sandbox for arbitrary R, native RStudio reproduction of every path, real-provider validation or Linux/macOS compatibility.
