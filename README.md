# Evil Space

Web-first Flutter site for Evil Space coworking in Nha Trang.

The UI intentionally uses a custom pixel renderer instead of normal text for the
brand experience. The web app still exposes semantic labels for accessibility,
real browser routes, and static SEO metadata in `web/index.html`.

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

Cloudflare assets are served from `build/web` using `wrangler.toml`.

## Routes

- `/`
- `/feed`
- `/desks`
- `/office`
- `/studio`
- `/gallery`
- `/contact`
- `/qr`

Browser back/forward and deep links are handled by Flutter's Router API with path
URL strategy.

## Localization

The pixel UI supports English, Russian, and Vietnamese. The default language is
selected from the browser locale, with an EN / RU / VI switcher in the header.

Vietnamese tone marks are composed by the pixel glyph renderer, so translated
strings can use proper Vietnamese spelling rather than ASCII approximations.

## RGB565 pixel slideshow

Put images directly in:

```text
assets/slideshow/
```

The directory is declared once in `pubspec.yaml`; the app discovers supported
image files through Flutter's `AssetManifest`.

For each screen size the slideshow:

1. calculates a pixel grid from the viewport;
2. decodes and cover-crops each source image;
3. converts the sampled pixels to 16-bit RGB565;
4. renders the frame as crisp pixel cells;
5. transitions to the next frame with a directional runway plus deterministic
   pixel jitter.

If the directory has no images, a generated RGB565 demo sequence is shown so the
gallery remains functional.

Images are ordered alphabetically. Use filenames such as `01_front.jpg`,
`02_desks.jpg`, and `03_studio.jpg` to control the sequence.

## CI

`.github/workflows/web-ci.yml` runs on pushes and pull requests and requires:

- `flutter analyze`
- `flutter test`
- `flutter build web --release`
