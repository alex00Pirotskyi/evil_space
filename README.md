# Evil Space Daily

A deliberately small, web-first Flutter product for Evil Space coworking in Nha Trang.

The public page behaves like a single sheet of warm electronic paper. It answers only the questions a visitor needs: whether a desk is free, what it costs, what opens next, and how to reach the space. Operations live behind a separate `/admin` boundary.

## Public experience

- custom Evil Space logo and black-on-paper visual system
- current desk availability with a clearly dated update
- exactly two prices: `250K VND` for one day and `2.5 MLN VND` for one month
- podcast/studio room and lecture room opening on 20 October
- one short daily note
- a monochrome location plate with separate Google Maps directions and photos/reviews links
- Instagram, Zalo, and phone contact actions
- English, Russian, and Vietnamese

The core website intentionally hosts no photo gallery. Real photos remain on Instagram and Google Maps, where visitors already expect current images and reviews.

`/qr` opens the same public page and scrolls directly to the location/contact section. Legacy public URLs resolve to `/`.

## Admin foundation

`/admin` is a separate operational surface for:

- today's desk and task overview
- customer passes
- payment status and verification
- purchase requests and bought state
- staff notifications across approved devices

The route is locked by default. It does not accept a local password and does not trust SharedPreferences or LocalStorage for authorization. A compile-time sample-data preview exists only for design review:

```bash
flutter run -d chrome --dart-define=EVIL_SPACE_ADMIN_PREVIEW=true
```

The production data contract is in `supabase/migrations/202608290001_admin_foundation.sql`. It includes Postgres row-level security, role management, audit logging, Realtime publication, notification records, and device registrations. The FCM fan-out Edge Function is in `supabase/functions/push-notifications/`.

See [Admin activation](docs/admin-setup.md) for the project setup and security checklist.

## Content

Until the Supabase public-state adapter is connected, day-to-day public content lives in:

```text
assets/content/status.json
```

The UI uses safe fallback data if that asset is missing or malformed.

## Project shape

```text
lib/
  admin_screen.dart
  app_route.dart
  app_router.dart
  app_shell.dart
  brand_logo.dart
  brand_surface.dart
  coworking_model.dart
  localization.dart
  main.dart

supabase/
  functions/push-notifications/
  migrations/
```

## Local development

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Production build:

```bash
flutter build web --release
```

Cloudflare serves `build/web` using `wrangler.toml`.

## CI

`.github/workflows/web-ci.yml` runs on pull requests to `main` and requires dependency lock verification, static analysis, tests, and a release web build with Flutter 3.44.7.
