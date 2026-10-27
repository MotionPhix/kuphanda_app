# Kuphanda

An offline-first document library and study manager for Malawian secondary
schools, covering Forms 1–4 and the JCE and MSCE examinations.

This repository contains two folders:

| Folder | What it is |
| --- | --- |
| `phanda_app/` | Flutter application (Android, iOS, Windows). The learner-facing product. |
| `phanda_api/` | Laravel API for accounts and, eventually, library sync. Currently the API kit with Sanctum auth only. |

## phanda_app

```bash
cd phanda_app
flutter pub get
flutter run -d windows      # or an Android/iOS device
flutter analyze
flutter build windows --debug
```

Requires Flutter 3.35+ (developed against Flutter 3.47 / Dart 3.13).

### What is implemented

- Onboarding with form, exam target and subject selection; the profile is
  device-local and there is no login wall.
- Library of roughly 140 catalogue records across 14 subjects, Forms 1–4:
  past papers, marking schemes, study notes, syllabi and guides.
- Search, subject/form/type filters, availability filters and sorting.
- Document detail with metadata, ratings, bookmarks, notes and related reading.
- Two readers: a PDF reader (`pdfx`) for attached files, and a structured
  study-guide reader built from 15 topics / 37 subtopics.
- Document management: import PDFs, attach them to catalogue records, edit
  metadata, remove files, track storage. Files stay in the app's private folder.
- Classes: join by six-character code, create a class, set reading with due
  dates, mark assignments done, see assignment progress.
- Progress: pages read, minutes studied, streaks, weekly goal and per-subject
  progress, all computed locally.
- Responsive layout (bottom navigation on phones, rail on tablet/desktop),
  light and dark themes.

### Data and copyright

Catalogue records are sample metadata. Only two Kuphanda-authored PDFs ship
with the app (`phanda_app/assets/samples/`). No MANEB papers or textbooks are
bundled; the learner or school attaches files they are allowed to use.

### Not implemented yet

- API client, authentication and cloud sync against `phanda_api`.
- Local notifications or reminders.
- Automated tests (`phanda_app/test/` is empty).
- Android build verification: the local Android SDK licences are not accepted,
  so only Windows has been built and run.

## phanda_api

The Laravel API kit (`grazulex/laravel-api-kit`) with Sanctum. It currently
exposes registration, login, logout, password reset and `GET /api/v1/me`.
Library, class and progress endpoints still need to be designed and added
before `phanda_app` can sync.

```bash
cd phanda_api
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate
php artisan serve
```

Never commit `phanda_api/.env`; it holds the application key and database
credentials. Dependencies (`vendor/`) and build output are ignored.
