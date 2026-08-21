import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:evil_space/app_route.dart';
import 'package:evil_space/app_router.dart';
import 'package:evil_space/coworking_model.dart';
import 'package:evil_space/localization.dart';

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
      expect(parser.restoreRouteInformation(AppRoute.home).uri.path, '/');
      expect(parser.restoreRouteInformation(AppRoute.qr).uri.path, '/qr');
    });
  });

  group('localization', () {
    test('contains the daily product copy in all supported languages', () {
      final localization = LocalizationController(AppLanguage.en);
      expect(localization.t('brand_daily'), 'EVIL SPACE / DAILY');
      expect(localization.t('feature_big_desks'), 'BIG DESKS');
      expect(localization.t('visit_title'), 'VISITING?');

      localization.setLanguage(AppLanguage.ru);
      expect(localization.t('nav_prices'), 'ЦЕНЫ');
      expect(localization.t('feature_fast_wifi'), 'БЫСТРЫЙ WI-FI');

      localization.setLanguage(AppLanguage.vi);
      expect(localization.t('nav_prices'), 'BẢNG GIÁ');
      expect(localization.t('feature_good_chairs'), 'GHẾ TỐT');
      expect(localization.t('contact_map'), 'MỞ BẢN ĐỒ');

      localization.dispose();
    });

    test('falls back to the key when no translation exists', () {
      final localization = LocalizationController();
      expect(localization.t('prices_title'), 'PRICE LIST');
      expect(localization.t('missing_key'), 'missing_key');
      localization.dispose();
    });
  });

  group('site content', () {
    test('parses occupancy, prices, and multilingual announcements', () {
      final content = SiteContent.fromJson({
        'status': {
          'updated': '2026-08-21',
          'total': 12,
          'occupied': 5,
        },
        'prices': [
          {'label_key': 'price_day_pass', 'price': '250K'},
        ],
        'announcements': [
          {
            'date': '21 AUG',
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
      expect(content.status.updated, '2026-08-21');
      expect(content.prices.single.price, '250K');
      expect(content.announcements.single.textFor('ru'), 'ПРИВЕТ');
      expect(content.announcements.single.textFor('vi'), 'XIN CHÀO');
    });

    test('normalizes malformed occupancy into safe bounds', () {
      final content = SiteContent.fromJson({
        'status': {
          'total': -4,
          'occupied': 5000,
        },
      });

      expect(content.status.total, 1);
      expect(content.status.occupied, 1);
      expect(content.status.free, 0);
    });

    test('uses safe demo data when sections are empty', () {
      final content = SiteContent.fromJson(const {});
      expect(content.status.total, greaterThan(0));
      expect(content.prices, isNotEmpty);
      expect(content.announcements, isNotEmpty);
    });
  });
}
