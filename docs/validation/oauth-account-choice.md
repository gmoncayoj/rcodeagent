# OAuth cancellation and account choice

Local correction for rcodeagent 0.1.0, October 24, 2026.

## Report and cause

The author reported that cancelling browser authorization left a permanent notification, and reconnecting after disconnecting still presented the previous account. OAuth completion errors used an indefinite notification. Reconnection intentionally reused the previous account's issued client registration and email hint; there was no separate action for registering another account. Plugin disconnection does not sign out of the browser's OpenAI session.

## Changes

- A callback with validated state and `error=access_denied` signals a distinct cancellation condition. Its notification uses the selected UI language and closes after five seconds. Other errors, including invalid state, remain visible.
- When disconnected, **Sign in with ChatGPT** reconnects the last registration; **Use another account** starts dynamic registration without the old client ID, subject, email or ID-token hints. A connected account must be disconnected first. Identity/nonce/PKCE/scope validation remains required before saving new credentials or loading models.
- Previous client/account mappings are preserved in separate local registration files. They contain only client ID, subject and email, never credentials. A client ID cannot be reassigned to a different subject. The current UI is not a multi-account session manager: only one account's renewable credentials are active locally.

This follows OpenAI's [registration guidance](https://developers.openai.com/siwc/token-sharing-open-source/sign-in) and [account-switching guidance](https://developers.openai.com/siwc/token-sharing-open-source/profiles-and-sessions). The provider controls its browser account chooser and consent screen; users must verify the displayed identity before approval.

## Verification and limits

Regression tests cover cancellation, translation, duration, persistent errors and invalid state; another-account request parameters, ordinary reconnection and refusal while connected; separate token-free registration records and subject mismatch rejection.

A real local Shiny/browser session with synthetic OAuth callbacks verified both buttons and automatic dismissal in English and Spanish, at desktop and narrow widths. See [result](oauth-account-choice.json), [English screenshot](oauth-cancellation-en.png) and [Spanish screenshot](oauth-cancellation-es-560.png). Both updated nine-page manuals passed text/bounds checks and visual review of the changed page.

No real account, browser sign-in, token revocation or provider request was performed by this verification. Switching actual accounts on OpenAI's page and ChatGPT Free inference remain unverified. Final archive identity and package checks are recorded in [GitHub readiness](github-readiness.md).
