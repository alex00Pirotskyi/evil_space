import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:evil_space/app_route.dart';
import 'package:evil_space/app_router.dart';
import 'package:evil_space/coworking_model.dart';
import 'package:evil_space/localization.dart';
import 'package:evil_space/pixel_background.dart';
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
      expect(AppRoute.fromUri(Uri.parse('/map')), AppRoute.map);
      expect(AppRoute.fromUri(Uri.parse('/floor-map')), AppRoute.map);
      expect(AppRoute.fromUri(Uri.parse('/book')), AppRoute.book);
      expect(AppRoute.fromUri(Uri.parse('/visit')), AppRoute.book);
      expect(AppRoute.fromUri(Uri.parse('/gallery')), AppRoute.gallery);
      expect(AppRoute.fromUri(Uri.parse('/contact')), AppRoute.contact);
      expect(AppRoute.fromUri(Uri.parse('/qr')), AppRoute.qr);
      expect(AppRoute.fromUri(Uri.parse('/unknown')), AppRoute.home);

      final parsed = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/map')),
      );
      expect(parsed, AppRoute.map);
    });

    test('restores canonical browser paths', () {
      expect(
        parser.restoreRouteInformation(AppRoute.desks).uri.path,
        '/desks',
      );
      expect(
        parser.restoreRouteInformation(AppRoute.map).uri.path,
        '/map',
      );
      expect(
        parser.restoreRouteInformation(AppRoute.book).uri.path,
        '/book',
      );
    });
  });

  group('localization', () {
    test('contains Russian and Vietnamese product translations', () {
      final localization = LocalizationController(AppLanguage.ru);
      expect(localization.t('menu_contact'), 'КОНТАКТЫ');
      expect(localization.t('menu_map'), 'КАРТА ЗАЛА');

      localization.setLanguage(AppLanguage.vi);
      expect(localization.t('menu_contact'), 'LIÊN HỆ');
      expect(localization.t('desk_day'), 'VÉ NGÀY');
      expect(localization.t('cta_work_here'), 'LÀM VIỆC Ở ĐÂY HÔM NAY');

      localization.dispose();
    });

    test('falls back to the key when no translation exists', () {
      final localization = LocalizationController();
      expect(localization.t('menu_gallery'), 'PIXEL GALLERY');
      expect(localization.t('missing_key'), 'missing_key');
      localization.dispose();
    });
  });

  group('coworking model', () {
    test('parses live desk availability', () {
      final status = CoworkingStatus.fromJson({
        'updated': 'NOW',
        'desks': [
          {'id': 'a', 'label': 'A', 'zone': 'WINDOW', 'state': 'available'},
          {'id': 'b', 'label': 'B', 'zone': 'QUIET', 'state': 'occupied'},
        ],
      });

      expect(status.total, 2);
      expect(status.available, 1);
      expect(status.deskById('a')?.state, DeskState.available);
    });

    test('pricing calculator chooses the cheapest useful product', () {
      expect(PricingCalculator.forDays(1).bestKey, 'desk_day');
      expect(PricingCalculator.forDays(5).bestKey, 'desk_week');
      expect(PricingCalculator.forDays(30).bestKey, 'desk_hot');
      expect(PricingCalculator.compactVnd(3200000), '3.2M');
    });
  });

  group('background scenes', () {
    test('maps business routes to page-aware photo pools', () {
      expect(
        PixelBackgroundScene.fromRoute(AppRoute.desks),
        PixelBackgroundScene.desks,
      );
      expect(
        PixelBackgroundScene.fromRoute(AppRoute.map),
        PixelBackgroundScene.desks,
      );
      expect(
        PixelBackgroundScene.fromRoute(AppRoute.book),
        PixelBackgroundScene.desks,
      );
      expect(
        PixelBackgroundScene.fromRoute(AppRoute.contact),
        PixelBackgroundScene.contact,
      );
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
