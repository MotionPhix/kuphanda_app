# Kuphanda

An online-first document platform for Malawian secondary schools, with offline
reading as a supplementary feature. The library supplies and versions the
catalogue; students browse it online, subscribe or buy individual documents
through PayChangu, and may download what they are entitled to for reading
without a connection.

Two folders:

| Folder | What it is |
| --- | --- |
| `phanda_app/` | Flutter app (Android, iOS, Windows). |
| `phanda_api/` | Laravel API: accounts, catalogue, entitlements, PayChangu, offline sync. |

## Application identifiers

The app ships under **`com.ultrashots.kuphanda`** on both Android
(`applicationId`/`namespace`) and iOS (`PRODUCT_BUNDLE_IDENTIFIER`).

Naming rule: `com.<developer>.<product>` — reverse-domain of the studio that owns
and publishes the build, followed by the product name. The segment is lowercase,
has no hyphens or underscores, and is never `example`. It is permanent once the
first release is published, so it is chosen before the first store upload.

| Thing | Value |
| --- | --- |
| Android application ID / namespace | `com.ultrashots.kuphanda` |
| iOS bundle identifier | `com.ultrashots.kuphanda` |
| Firebase project | `kuphanda-app` |
| Firebase Android app | `com.ultrashots.kuphanda` |

## Access model

Documents carry an `access_tier`: `free`, `daily`, `weekly`, `monthly` or
`school`. Subscriptions grant a tier for a period; a single-document purchase
grants only that document.

Seeded plans (Malawi kwacha):

| Plan | Tier | Price | Duration |
| --- | --- | --- | --- |
| Day pass | daily | MWK 500 | 1 day |
| Weekly pass | weekly | MWK 1,500 | 7 days |
| Monthly pass | monthly | MWK 4,500 | 30 days |
| Term pass | school | MWK 12,000 | 120 days |

Free documents are readable without an account. Everything else requires a
signed-in user with an active subscription, a purchase, or a school licence.
The server checks entitlement on every catalogue response, offline mark and
file download — the app's lock badges are only a reflection of that decision.

## Payment flow

1. `POST /api/v1/billing/checkout` with `plan_id` or `document_id` creates a
   pending subscription/purchase and asks PayChangu for a checkout URL.
2. The app opens the URL in the device browser.
3. PayChangu redirects to `GET /api/v1/billing/callback/{tx_ref}` and sends a
   signed webhook to `POST /api/v1/webhooks/paychangu`.
4. The webhook signature is checked (HMAC-SHA256), then the transaction is
   re-verified with PayChangu before entitlement is granted. Activation is
   idempotent, so webhook and polling cannot double-grant.
5. The app polls `GET /api/v1/billing/payments/{tx_ref}` after the learner says
   they have paid, then refreshes the catalogue and offline marks.
6. The pending reference is stored on the device, so closing the payment sheet
   or the app does not lose it. It is re-checked when the app resumes or the
   subscription screen opens, and cleared once confirmed.

Relevant environment variables (see `phanda_api/.env.example`):

```dotenv
APP_URL=https://your-api.example
PAYCHANGU_BASE_URL=https://api.paychangu.com
PAYCHANGU_SECRET_KEY=...
PAYCHANGU_WEBHOOK_SECRET=...
PAYCHANGU_CURRENCY=MWK
GOOGLE_CLIENT_ID=...apps.googleusercontent.com
```

### Google sign-in

The API verifies Google ID tokens against the tokeninfo endpoint, including the
audience and `email_verified`, then links by `google_id` or by verified email.
Linking fills blank profile fields only; names the learner has confirmed are
never overwritten.

1. Create a Web OAuth client and put its ID in `GOOGLE_CLIENT_ID`.
2. Create an Android OAuth client for the app package
   (`com.ultrashots.kuphanda`) and the signing certificate's SHA-1, then add
   `google-services.json` to `android/app/` (do not commit it).
3. Build the app with the same web client ID:
   `--dart-define=GOOGLE_SERVER_CLIENT_ID=...apps.googleusercontent.com`.

Confirmed names and school are saved to the account with PATCH /api/v1/me.
Offline edits stay on the device and are retried on the next save.

Onboarding asks for first and last name separately and offers
**Continue with Google** to prefill them; both stay editable.

Students cannot create classes. The role is chosen at setup, and the
create-class actions are hidden (and guarded) for students; only teachers see
them.

Without keys, checkout returns a clear 502 and no access is granted. Webhooks
must be sent over HTTPS with the `Signature` header.

## Offline reading

- Offline access is explicit: the learner taps **Download for offline reading**,
  which first creates a server-side mark, then downloads the current file.
- Files are versioned (`document_versions`). Each version has a SHA-256 checksum,
  byte size and page count; the app verifies both before replacing a working
  copy. A failed download never destroys the previous version.
- `GET /api/v1/library/offline` and `/library/sync?since=` return the current
  version and an `is_entitled` flag for every mark. The app updates files whose
  version is behind, removes files whose mark disappeared, and removes files
  whose entitlement expired.
- Removing a download deletes the local copy and the server mark. Offline,
  removal is queued and retried on the next sync.
- Progress, notes and bookmarks survive file removal.

## API endpoints

Authenticated (Sanctum bearer token):

```
GET    /api/v1/subjects
GET    /api/v1/documents?q=&subject=&form=&kind=
GET    /api/v1/documents/{id}
GET    /api/v1/plans
GET    /api/v1/billing/status
POST   /api/v1/billing/checkout        {plan_id} | {document_id}
GET    /api/v1/billing/payments        receipts (subscriptions + purchases)
GET    /api/v1/billing/payments/{tx_ref}  payment status / verification
GET    /api/v1/library/offline
POST   /api/v1/library/offline         {document_id}
DELETE /api/v1/library/offline/{id}
GET    /api/v1/library/offline/{id}/download
POST   /api/v1/library/offline/{id}/ack {version}
GET    /api/v1/library/sync?since=
```

Public: `GET /billing/callback/{tx_ref}`, `POST /webhooks/paychangu`.

Downloads support `If-None-Match` / `ETag` (`X-Document-Checksum`), so a client
can confirm its copy is current without re-downloading.

## Running locally

API:

```bash
cd phanda_api
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate --seed      # seeds subjects, documents, plans and files
php artisan serve
```

App (desktop default points at `127.0.0.1:8000`):

```bash
cd phanda_app
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Android emulator: `--dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1`.

Physical Android device over USB (no LAN or firewall changes):

```bash
adb reverse tcp:8001 tcp:8001
php artisan serve --port=8001
flutter run -d <device> --dart-define=API_BASE_URL=http://localhost:8001/api/v1
```

### Device testing through Herd + ngrok

Herd serves the API at `https://phanda_api.test`. A physical phone cannot resolve
that host, so the same site is exposed through ngrok on a stable free URL and the
app is built against it:

```bash
flutter build apk --release --target-platform android-arm64 \
  --dart-define=API_BASE_URL=https://zap-petticoat-slept.ngrok-free.dev/api/v1 \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=239327365893-1725f6in8f6nnmc85836eqhrets9hfes.apps.googleusercontent.com
```

Two requirements make this work:

- `ApiClient` sends `ngrok-skip-browser-warning: true`. Without it ngrok answers
  the first request from an unknown client with an HTML interstitial instead of
  JSON. Every other host ignores the header.
- `TRUSTED_PROXIES=*` in `phanda_api/.env` makes Laravel honour
  `X-Forwarded-Proto`, so generated download URLs are `https://…` rather than
  `http://…`. Leave it empty outside a tunnel: it trusts client-supplied headers.

`android/app/src/main/res/xml/network_security_config.xml` allows cleartext only
for `10.0.2.2` and `localhost`. All other hosts, including production, require
HTTPS.

## Publishing content

The library team owns the catalogue; students never upload material. Publish a
new immutable version from a PDF on the server:

```bash
php artisan library:publish sample-howto /srv/library/quick-start-v3.pdf \
  --pages=6 --notes="Adds the revision planner"
```

The command validates the PDF, hashes it, and stores it through **Spatie Media
Library** on the private `local` disk (`media` table plus the file under
`storage/app/private/{media-id}/`). It then bumps `latest_version`. Existing
readers keep their old copy until the app syncs; the next sync offers the
update. Files are limited to 50 MB.

`document_versions` keeps the version number, checksum, page count and a
`media_id`; Media Library owns the bytes. Versions published before the move are
imported with:

```bash
php artisan library:media-backfill
```

Set `MEDIA_DISK=local` (the default) so PDFs stay private; downloads are
streamed by the authenticated endpoint and never served from `/storage`.

To withdraw a document:

```bash
php artisan library:unpublish sample-howto
```

It disappears from the catalogue and `is_entitled` becomes false for every
offline mark, so clients delete downloaded copies on the next sync. Versions are
kept, so publishing again restores access without learners re-marking anything.

## Tests and builds

```bash
cd phanda_api && php artisan test        # 61 tests
cd phanda_app && flutter analyze         # no issues
cd phanda_app && flutter test            # 24 tests
cd phanda_app && flutter build windows --debug
```

The API suite covers entitlement, expired subscriptions, single-document
purchases, webhook signature rejection, download headers, conditional requests
and offline tombstones. Flutter tests cover sync planning (download, update,
expiry removal, bundled-file protection) and API client parsing/error mapping.

## What is not built yet

- An admin publishing UI. Files are managed by the library team through the
  database and storage (seeded for now); there is no upload form.
- Push notifications for new versions or assignments.
- A live PayChangu payment and webhook. A test-mode payment has been completed
  end to end; production needs live keys and a public HTTPS webhook plus
  `PAYCHANGU_WEBHOOK_SECRET`.
- iOS build verification. Android has been built and run on both an emulator and
  a physical phone; iOS has not been opened in Xcode.
- The bundled “How to use Kuphanda” guide is now v3 and matches the online-first
  model; refresh it with `library:publish` whenever the flow changes.

Catalogue records are sample metadata. Only two Kuphanda-authored PDFs ship as
files (`phanda_api/database/seeders/files/`). No MANEB papers or textbooks are
bundled; the library team must publish files it has the right to distribute.
