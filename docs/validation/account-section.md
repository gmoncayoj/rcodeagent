# Account section display

Local UI verification for rcodeagent 0.1.0, October 24, 2026.

The author requested removal of the duplicate green sign-in label. The disconnected Account section now contains only Sign in with ChatGPT and Use another account. A connected session shows the authenticated account email and Disconnect. The email clears when disconnected or when model loading fails, so a retained local identity is not presented as a current connection.

The empty email output stays reactive even while hidden: `suspendWhenHidden = FALSE` prevents Shiny from suspending the update that must make it visible after sign-in. Email text wraps within the sidebar and uses normal text rendering. OAuth, model eligibility and execution permissions are unchanged.

A real local Shiny/browser fixture with synthetic authentication verified initial disconnection, sign-in, signout and sign-in as a second synthetic account. It checked the absence of the removed label, exactly two visible disconnected actions, connected email, removal of the old email and the new account email at desktop and narrow widths. No page errors occurred. See [result](account-section.json), [disconnected screenshot](account-disconnected.png), [connected screenshot](account-connected.png) and [second account at narrow width](account-second-560.png). Screenshots were visually reviewed; no real credentials or accounts were used.

Package checks and the current archive identity are recorded in [GitHub readiness](github-readiness.md).
