# Kuphanda

## 1.2.0 — 5 November 2026

A number and a code, instead of a password nobody remembers.

### Signing in

- **Phone sign-in with a WhatsApp code.** `POST /auth/otp/start` sends a
  six-digit code through Meta's WhatsApp Cloud API; `POST /auth/otp/verify`
  exchanges it for a session. Malawian numbers are accepted as typed —
  `099 123 4567`, `0991234567`, `265991234567` or `+265991234567` — and stored
  in one E.164 form so a number cannot become two accounts.
- **Sign-up from a phone.** A number that is on no account can create one: the
  account exists only after the code comes back, so nobody can block a number by
  typing it. Name is required; email is not.
- **Linking, for accounts that already exist.** Every account made before this
  release has an email and no number. Profile → *Add a WhatsApp number* verifies
  one from inside the session, which is the only safe way to attach a number to
  an account that was never matched against it.
- **Email and Google are untouched.** The login screen leads with the phone, but
  "Sign in with email" and "Continue with Google" are exactly where they were.
  An account with no verified number can still get in the old way, which matters
  when WhatsApp is down, the phone is flat, or the number has changed hands.
- **Codes are not secrets we keep.** Only a password hash of each code is
  stored; one code per send, ten minutes, five guesses, one send a minute and
  five an hour per number. The code is never in an API response, in any
  environment.
- **An unconfigured server says so.** With no WhatsApp credentials the endpoint
  answers 503 `OTP_CHANNEL_UNAVAILABLE` instead of accepting a request and
  sending nothing, and `/api/v1/health` reports `whatsapp_otp.configured`.

### Why Meta directly, not a provider

Kuphanda owns its own WhatsApp Business Account. A business provider in the
middle would hold the message log, add a per-message margin and add a second
failure mode, and Mithenga's own send-code endpoint exists to sign people into
Mithenga, not to be an API for another product. The transport sits behind
`App\Contracts\OtpSender`, so a provider can be added later without touching the
sign-in flow.

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
- **The subscription page no longer hangs.** A server with no published plans
  rendered an empty list as an endless spinner; it now says prices are not on
  sale yet and offers a retry. The cause — library:sync seeded documents but
  not prices — is fixed with it.
- **Web boots.** The project had no web scaffold; it now builds, and startup
  picks a localStorage store instead of the native file one, which used to throw
  before the first frame and leave a blank page. PDF download is not wired for
  the browser yet.
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

### Scope

Android, web and Windows. iOS is out of scope by design, not by omission.

### Known limits

- Push notifications are implemented and tested, but a real device delivery
  needs `FIREBASE_CREDENTIALS` on the host; `/api/v1/health` reports
  `push.configured` so the silence has a cause attached to it.
- Payments run against PayChangu's test mode, which is deliberate until the
  checkout has been exercised end to end.




