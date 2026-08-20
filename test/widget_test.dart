import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:evil_space/app_route.dart';
import 'package:evil_space/app_router.dart';
import 'package:evil_space/coworking_model.dart';
import 'package:evil_space/experience_widgets.dart';
import 'package:evil_space/led_wall.dart';
import 'package:evil_space/localization.dart';
import 'package:evil_space/pixel_image_slideshow.dart';

void main() {
  group('routing', () {
    const parser = EvilSpaceRouteParser();

    test('keeps only home and qr as public experiences', () async {
      expect(AppRoute.fromUri(Uri.parse('/')), AppRoute.home);
      expect(AppRoute.fromUri(Uri.parse('/qr')), AppRoute.qr);

      for (final legacyPath in [
        '/feed',
        '/desks',
        '/office',
        '/studio',
        '/map',
        '/book',
        '/gallery',
        '/contact',
        '/anything',
      ]) {
        expect(AppRoute.fromUri(Uri.parse(legacyPath)), AppRoute.home);
      }

      final parsed = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse('/qr')),
      );
      expect(parsed, AppRoute.qr);
    });

    test('restores canonical browser paths', () {
      expect(
        parser.restoreRouteInformation(AppRoute.home).uri.path,
        '/',
      );
      expect(
        parser.restoreRouteInformation(AppRoute.qr).uri.path,
        '/qr',
      );
    });
  });

  group('localization', () {
    test('contains readable Russian and Vietnamese landing copy', () {
      final localization = LocalizationController(AppLanguage.ru);
      expect(localization.t('nav_contact'), 'КОНТАКТЫ');
      expect(localization.t('occupied'), 'СТОЛОВ ЗАНЯТО');

      localization.setLanguage(AppLanguage.vi);
      expect(localization.t('nav_contact'), 'LIÊN HỆ');
      expect(localization.t('price_day_pass'), 'VÉ NGÀY');
      expect(localization.t('occupied'), 'BÀN ĐANG ĐƯỢC DÙNG');

      localization.dispose();
    });

    test('falls back to the key when no translation exists', () {
      final localization = LocalizationController();
      expect(localization.t('prices_title'), 'PRICES');
      expect(localization.t('missing_key'), 'missing_key');
      localization.dispose();
    });
  });

  group('site content', () {
    test('parses occupancy, prices, and multilingual announcements', () {
      final content = SiteContent.fromJson({
        'status': {
          'updated': 'NOW',
          'total': 12,
          'occupied': 5,
        },
        'prices': [
          {'label_key': 'price_day_pass', 'price': '250K'},
        ],
        'announcements': [
          {
            'date': '20 AUG',
            'text': {
              'en': 'HELLO',
              'ru': 'ПРИВЕТ',
              'vi': 'XIN CHÀO',
            },
          },
        ],
      });

      expect(content.status.total, 12);
      expect(content.status.occupied, 5);
      expect(content.status.free, 7);
      expect(content.prices.single.price, '250K');
      expect(content.announcements.single.textFor('ru'), 'ПРИВЕТ');
      expect(content.announcements.single.textFor('vi'), 'XIN CHÀO');
    });

    test('uses safe demo data when sections are empty', () {
      final content = SiteContent.fromJson(const {});
      expect(content.status.total, greaterThan(0));
      expect(content.prices, isNotEmpty);
      expect(content.announcements, isNotEmpty);
    });
  });

  group('RGB LED wall', () {
    test('keeps a visible black gap around each LED package', () {
      final rect = LedWallGeometry.ledRect(
        column: 2,
        row: 3,
        cellWidth: 5,
        cellHeight: 5,
      );

      expect(rect.left, greaterThan(10));
      expect(rect.top, greaterThan(15));
      expect(rect.width, lessThan(5));
      expect(rect.height, lessThan(5));
    });

    testWidgets('turns Unicode text into an LED-cell glyph mask', (tester) async {
      final english = await LedTextMaskBuilder.build(
        text: 'EVIL SPACE',
        maxWidth: 320,
        fontSize: 32,
        ledPitch: 4,
        fontWeight: FontWeight.w800,
        textAlign: TextAlign.left,
        maxLines: 1,
        letterSpacing: 1,
        textDirection: TextDirection.ltr,
      );
      final russian = await LedTextMaskBuilder.build(
        text: 'КОНТАКТЫ',
        maxWidth: 320,
        fontSize: 30,
        ledPitch: 4,
        fontWeight: FontWeight.w800,
        textAlign: TextAlign.left,
        maxLines: 1,
        letterSpacing: 1,
        textDirection: TextDirection.ltr,
      );
      final vietnamese = await LedTextMaskBuilder.build(
        text: 'LIÊN HỆ',
        maxWidth: 320,
        fontSize: 30,
        ledPitch: 4,
        fontWeight: FontWeight.w800,
        textAlign: TextAlign.left,
        maxLines: 1,
        letterSpacing: 1,
        textDirection: TextDirection.ltr,
      );

      expect(english.activeCells, greaterThan(10));
      expect(russian.activeCells, greaterThan(10));
      expect(vietnamese.activeCells, greaterThan(10));
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
