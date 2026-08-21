# Evil Space Daily

A deliberately small web-first Flutter site for Evil Space coworking in Nha Trang.

The product behaves like a one-page electronic-paper bulletin, not a conventional coworking website. It should answer the useful questions immediately:

1. How many desks are free?
2. What matters about working here?
3. What does it cost?
4. What is new today?
5. How do I visit or contact Evil Space?

## Product direction

The visual identity is Kindle / printed e-paper: warm paper, black ink, serif editorial typography, monospace metadata, thin rules, and almost no chrome.

The page is intentionally still. There is one short e-ink refresh on initial load and when language changes; there are no carousels, looping animations, parallax effects, or runtime image processing.

Real photos are kept out of the core website. Visitors can open Instagram to see the space and Google Maps for directions. Those platforms own the image hosting and gallery problem.

## Page structure

- publication header: `EVIL SPACE / DAILY`, date, issue number, language
- live desk availability and day-pass CTA
- four work essentials: big desks, good chairs, fast Wi-Fi, cold AC
- price list
- today's short bulletin
- visit/contact links
- `PAGE 1 OF 1` footer

`/qr` opens the same page and scrolls directly to the visit/contact section. Legacy URLs resolve to the main page.

## Content

Normal daily maintenance lives in:

```text
assets/content/status.json
```

It contains:

- total desks
- occupied desks
- last update date
- prices
- multilingual announcements (EN/RU/VI)

The UI remains usable with safe fallback data if that file is missing or malformed.

## Localization

The public page supports:

- English
- Russian
- Vietnamese

Browser locale selects the initial language. EN / RU / VI controls remain visible in the publication header.

## Repository shape

The active application is intentionally compact:

```text
lib/
  app_route.dart
  app_router.dart
  app_shell.dart
  coworking_model.dart
  localization.dart
  main.dart
```

Historical pixel-wall, LED-wall, slideshow, image dithering, and image-processing experiments are not part of the production tree.

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

`.github/workflows/web-ci.yml` runs on `main` and `agent/**` branches and requires:

- `flutter analyze`
- `flutter test`
- `flutter build web --release`
