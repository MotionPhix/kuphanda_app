# Kuphanda

## 1.1.0 — 5 November 2026

The library stops being a demo and the app stops assuming a small font.

### The library

- **Every listed document can be opened.** Twelve records carried a title, a
  page count and a price with nothing behind them. The catalogue now holds
  documents that are readable: nine authored papers and guides, two published
  PDFs, two transcribed exam papers and fourteen curriculum guides.
- **The catalogue rule is enforced, not hoped for.** `GET /api/v1/documents`
  filters on the same readiness test the publisher uses, so a row with no
  blocks, no file and no bundled guide cannot be listed even if inserted
  directly.
- **`library:add`** creates a document and its first version from a PDF, so the
  library team no longer edits a seeder to publish a paper.
- **`library:sync`** brings any server up to the
  shipped catalogue and prunes what older versions left behind, without
  touching a record a learner bought or was assigned.
- Search matches subject, tags and exam year, not just the words in a title.

### The app

- **Release signing.** The APK is signed with a dedicated upload key; the debug
  key is now only a fallback for checkouts without key material.
- **Google sign-in works.** The release certificate's SHA-1 and SHA-256 are
  registered with the Firebase Android app, and the API verifies the ID token
  against the Web client.
- **Large text.** At 1.3× the system font, a dozen separate rows overflowed their
  cards — truncated action labels, pills reading "days to …", a bottom nav label
  split across two lines, and a class report that pushed its code out of the
  card. All fixed, with twelve tests that fail on any layout error and name the
  widget.
- **Honest fallback.** When the server cannot be reached the library says it is
  showing the copy saved on the phone, instead of silently showing fewer
  documents.

### Operations

- `GET /api/v1/health` reports the catalogue counts, whether Google sign-in and
  push are configured, the mail transport, and — after a deploy through
  `deploy/update.sh` — the commit the running code was checked out at.
- `deploy/update.sh` updates an existing install in one command, including the
  two `.env` values a deploy cannot infer.
- `deploy.sh` no longer points the mailer at an unreachable sandbox, which cost
  every sign-up 23 seconds and then a 500.

### Known limits

- Push notifications are implemented and tested, but a real device delivery
  needs `FIREBASE_CREDENTIALS` on the host; `/api/v1/health` reports
  `push.configured` so the silence has a cause attached to it.
- iOS is unbuilt; there is no macOS host in this environment.
- Payments run against PayChangu's test mode until live keys are added.

