import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:evil_space/app_route.dart';
import 'package:evil_space/app_router.dart';
import 'package:evil_space/localization.dart';
import 'package:evil_space/pixel_glyphs.dart';
import 'package:evil_space/pixel_image_slideshow.dart';
import 'package:evil_space/pixeltools.dart';

void main() {
  group('routing', () {
    const parser = EvilSpaceRouteParser();

    test('maps public web paths to app routes', () async {
      expect(AppRoute.fromUri(Uri.parse('/')), AppRoute.home);
      expect(AppRoute.fromUri(Uri.parse('/feed')), AppRoute.feed);
      expect(AppRoute.fromUri(Uri.parse('/desk')), AppRoute.desks);
      expect(AppRoute.fromUri(Uri.parse('/desks/')), AppRoute.desks);
      expect(AppRoute.fromUri(Uri.parse('/office')), AppRoute.office);
      expect(AppRoute.fromUri(Uri.parse('/studio')), AppRoute.studio);
      expect(AppRoute.fromUri(Uri.parse('/gallery')), AppRoute.gallery);
      expect(AppRoute.fromUri(Uri.parse('/contact')), AppRoute.contact);
      expect(AppRoute.fromUri(Uri.parse('/qr')), AppRoute.qr);
      expect(AppRoute.fromUri(Uri.parse('/unknown')), AppRoute.home);

      final parsed = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/gallery')),
      );
      expect(parsed, AppRoute.gallery);
    });

    test('restores canonical browser paths', () {
      expect(
        parser.restoreRouteInformation(AppRoute.desks).uri.path,
        '/desks',
      );
      expect(
        parser.restoreRouteInformation(AppRoute.qr).uri.path,
        '/qr',
      );
    });
  });

  group('localization', () {
    test('contains real Russian and Vietnamese translations', () {
      final localization = LocalizationController(AppLanguage.ru);
      expect(localization.t('menu_contact'), 'КОНТАКТЫ');

      localization.setLanguage(AppLanguage.vi);
      expect(localization.t('menu_contact'), 'LIÊN HỆ');
      expect(localization.t('desk_day'), 'VÉ NGÀY');

      localization.dispose();
    });

    test('falls back to English for unknown keys', () {
      final localization = LocalizationController();
      expect(localization.t('menu_gallery'), 'PIXEL GALLERY');
      expect(localization.t('missing_key'), 'missing_key');
      localization.dispose();
    });
  });

  group('pixel text', () {
    test('supports Vietnamese tone glyphs', () {
      final glyph = PixelGlyphResolver.resolve('Ắ');
      expect(glyph, isNotNull);
      expect(glyph!.tone, PixelTone.acute);
      expect(glyph.width, greaterThan(0));
    });

    test('wraps long pixel text to a measured width', () {
      final wrapped = PixelTextLayout.wrapToWidth(
        text: 'DEDICATED DESKS AND PRIVATE OFFICES',
        maxWidth: 120,
        gridSize: 4,
      );
      expect(wrapped.contains('\n'), isTrue);
    });
  });

  group('RGB565', () {
    test('packs and expands 16-bit RGB channels', () {
      final red = Rgb565.pack(255, 0, 0);
      expect(Rgb565.red8(red), 255);
      expect(Rgb565.green8(red), 0);
      expect(Rgb565.blue8(red), 0);

      final white = Rgb565.pack(255, 255, 255);
      expect(Rgb565.red8(white), 255);
      expect(Rgb565.green8(white), 255);
      expect(Rgb565.blue8(white), 255);
    });

    test('interpolates between RGB565 colors', () {
      final black = Rgb565.pack(0, 0, 0);
      final white = Rgb565.pack(255, 255, 255);
      final middle = Rgb565.lerp(black, white, 0.5);

      expect(Rgb565.red8(middle), inInclusiveRange(120, 136));
      expect(Rgb565.green8(middle), inInclusiveRange(120, 136));
      expect(Rgb565.blue8(middle), inInclusiveRange(120, 136));
    });
  });
}
