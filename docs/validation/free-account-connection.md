# Free-account connection attempt and safe diagnostics

Recorded on October 24, 2026 for rcodeagent 0.1.0.

## Observed result

The author attempted a real connection with a ChatGPT Free account. OpenAI's browser page first reported an internal processing error. After a retry, the plugin displayed a generic HTTP 400 Bad Request, including terminal formatting, and did not complete the connection. The screenshots do not establish which HTTP operation failed or identify a provider error code. The account was not verified for model inference.

The author then supplied OpenAI's [Sign in with ChatGPT quickstart](https://developers.openai.com/siwc/quickstart), whose open-source integration row explicitly identifies eligible Plus and Pro users for model requests. The README and manuals now require an eligible Plus or Pro subscription and do not support Free model usage in rcodeagent. Earlier broad availability wording was not sufficient to establish Free inference eligibility. Identity sign-in and authorization to consume models are distinct. Free ineligibility is a plausible explanation for this attempt, but OpenAI's [error guidance](https://developers.openai.com/siwc/token-sharing-open-source/errors-and-recovery) requires the actual response code to distinguish the precise cause of a generic 400.

## Diagnostic correction

Connection requests now distinguish OAuth token exchange, identity verification keys and model catalog retrieval. A rejected HTTP request produces a bounded diagnostic containing the stage, status, a recognized provider code when present, a validated request ID when present, and the response shape. Raw response text, error descriptions, parameters, credentials and request objects are not copied into that diagnostic. Unknown provider codes are omitted. Connection notices remove terminal formatting and use the selected UI language. No authorization code is automatically resent.

The callback page now explicitly says that receiving authorization does not yet confirm a connection. Identity signature, nonce, state, scope and account-binding checks remain in place. Redirects are not followed for these connection requests.

## Verification and remaining work

Mocked HTTP tests cover nested and string errors, `detail` bodies, malformed/non-JSON payloads, synthetic secret exclusion, stage attribution, translation, ANSI removal and refusal to save credentials or retry a rejected exchange. A local Shiny/browser fixture verifies readable English/Spanish errors with no synthetic secret or page-error leakage. See [result](connection-diagnostics.json), [English screenshot](connection-error-en.png) and [Spanish screenshot](connection-error-es.png).

These changes improve diagnosis; they do not repair or establish the precise cause of the author's actual provider rejection. Further Free-account retries are not required. Test with an eligible Plus or Pro account; if that connection fails, preserve the resulting stage, code and request ID for investigation. Do not share tokens, callback URLs or credential files. Current package checks and archive identity are in [GitHub readiness](github-readiness.md).
