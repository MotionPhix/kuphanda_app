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

Relevant environment variables (see `phanda_api/.env.example`):

```dotenv
APP_URL=https://your-api.example
PAYCHANGU_BASE_URL=https://api.paychangu.com
PAYCHANGU_SECRET_KEY=...
PAYCHANGU_WEBHOOK_SECRET=...
PAYCHANGU_CURRENCY=MWK
```

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
GET    /api/v1/billing/payments/{tx_ref}
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

For an Android emulator use `http://10.0.2.2:8000/api/v1`; for a physical device
use the machine's LAN address and add it to the Android network security config.

## Publishing content

The library team owns the catalogue; students never upload material. Publish a
new immutable version from a PDF on the server:

```bash
php artisan library:publish sample-howto /srv/library/quick-start-v3.pdf \
  --pages=6 --notes="Adds the revision planner"
```

The command validates the PDF, hashes it, stores it under
`storage/app/private/library/documents/{id}/`, and bumps `latest_version`.
Existing readers keep their old copy until the app syncs; the next sync offers
the update. Files are limited to 50 MB.

To withdraw a document:

```bash
php artisan library:unpublish sample-howto
```

It disappears from the catalogue and `is_entitled` becomes false for every
offline mark, so clients delete downloaded copies on the next sync. Versions are
kept, so publishing again restores access without learners re-marking anything.

## Tests and builds

```bash
cd phanda_api && php artisan test        # 50 tests
cd phanda_app && flutter analyze         # no issues
cd phanda_app && flutter test            # 14 tests
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
- A production PayChangu account. The gateway is implemented against the
  documented endpoints, but live keys and a public HTTPS webhook are required.
- Android/iOS build verification. Only Windows has been built and run here; the
  local Android SDK licences are not accepted.

Catalogue records are sample metadata. Only two Kuphanda-authored PDFs ship as
files (`phanda_api/database/seeders/files/`). No MANEB papers or textbooks are
bundled; the library team must publish files it has the right to distribute.
