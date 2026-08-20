# Evil Space

A web-first Flutter landing page for Evil Space coworking in Nha Trang.

The product is intentionally small. A visitor should be able to open the site on
a phone and quickly answer five questions:

1. What does Evil Space look like?
2. How many tables are occupied today?
3. What are the prices?
4. What is new today?
5. How do I contact Evil Space?

## Experience

The page is one vertically scrollable landing experience. The background is a
continuous slideshow of real Evil Space photos rendered as a higher-resolution
RGB565 pixel field. Foreground text uses a separate high-resolution pixel-text
renderer so the typography remains readable on small screens.

The only foreground sections are:

- hero + today's occupancy
- prices
- announcements
- contact

Header links simply scroll to those sections. `/qr` opens the same page and
scrolls to contact. Legacy URLs resolve to the main landing page rather than
exposing the retired floor-map, booking, gallery, office, or studio workflows.

## Photos

Put real Evil Space images in:

```text
assets/slideshow/
```

Supported image formats are discovered through Flutter's `AssetManifest`. At
runtime each image is cover-cropped to the viewport grid, converted to RGB565,
and rendered with crisp small pixel cells. Images transition with one restrained
runway pixel morph.

Use alphabetical filenames to control order:

```text
01_front.jpg
02_workspace.jpg
03_desks.jpg
04_studio.jpg
05_evening.jpg
```

If there are no photos yet, the app shows generated demo RGB565 frames instead
of a broken background.

## Content

Daily content is intentionally kept in one small file:

```text
assets/content/status.json
```

It contains:

- total tables
- occupied tables
- static prices
- multilingual announcements (EN/RU/VI)

This keeps normal website updates out of the Dart UI code.

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

`.github/workflows/web-ci.yml` requires:

- `flutter analyze`
- `flutter test`
- `flutter build web --release`
