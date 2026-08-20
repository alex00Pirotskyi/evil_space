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

The public site is one vertically scrollable electronic-paper page. It is styled
like a Kindle / printed monochrome publication rather than a conventional web
app: warm paper, black ink, editorial typography, thin rules, and very little
visual chrome.

The visible sections are:

- hero + today's occupancy
- live e-paper photo plate
- prices
- announcements
- contact

Header links scroll to those sections. `/qr` opens the same page and scrolls to
contact. Legacy URLs resolve to the main landing page.

## Live e-paper photos

Put real Evil Space images directly in:

```text
assets/slideshow/
```

Supported images are discovered through Flutter's `AssetManifest`. There is no
per-image Dart configuration.

At runtime each image goes through the e-paper pipeline:

1. decode close to the required display resolution;
2. center cover-crop to the photo plate;
3. convert RGB to perceptual luminance;
4. calculate image histogram and stretch useful black/white range;
5. apply a restrained contrast curve;
6. apply local 3x3 unsharp contrast to preserve edges and furniture detail;
7. quantize to four electronic-ink tones;
8. diffuse quantization error with an Atkinson-style kernel;
9. render the resulting monochrome frame on warm paper.

The initial image is not faded in. It develops across the paper with a slightly
irregular print/refresh frontier. Subsequent images refresh the same way with a
small temporary ghosting band, closer to an e-reader refresh than a slideshow
crossfade.

Only the current and nearby frames are cached, so adding many photos does not
require decoding the whole asset folder into memory at startup.

Alphabetical file names control order:

```text
01_front.jpg
02_workspace.jpg
03_desks.jpg
04_studio.jpg
05_evening.jpg
```

If the photo directory is empty, a monochrome generated fallback is used instead
of a broken image or colorful placeholder.

## Content

Daily content lives in:

```text
assets/content/status.json
```

It contains:

- total tables
- occupied tables
- static prices
- multilingual announcements (EN/RU/VI)

This keeps normal website maintenance out of the Dart layout code.

## Localization

The landing page supports:

- English
- Russian
- Vietnamese

Browser locale selects the initial language and the header exposes EN / RU / VI
switches.

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
