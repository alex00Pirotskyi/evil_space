import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:evil_space/admin_screen.dart';
import 'package:evil_space/app_route.dart';
import 'package:evil_space/app_router.dart';
import 'package:evil_space/coworking_model.dart';
import 'package:evil_space/localization.dart';
import 'package:evil_space/main.dart';
import 'package:evil_space/menu_screen.dart';

void main() {
  group('routing', () {
    const parser = EvilSpaceRouteParser();

    test(
      'keeps home and qr public and recognizes the admin boundary',
      () async {
        expect(AppRoute.fromUri(Uri.parse('/')), AppRoute.home);
        expect(AppRoute.fromUri(Uri.parse('/qr')), AppRoute.qr);
        expect(AppRoute.fromUri(Uri.parse('/admin')), AppRoute.admin);
        expect(
          AppRoute.fromUri(Uri.parse('/admin/auth/callback')),
          AppRoute.admin,
        );

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
      },
    );

    test('restores canonical browser paths', () {
      expect(parser.restoreRouteInformation(AppRoute.home).uri.path, '/');
      expect(parser.restoreRouteInformation(AppRoute.qr).uri.path, '/qr');
      expect(parser.restoreRouteInformation(AppRoute.admin).uri.path, '/admin');
    });

    testWidgets('public app boots with an overlay for selectable content', (
      tester,
    ) async {
      await tester.pumpWidget(const EvilSpaceApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SelectionArea), findsOneWidget);
      expect(find.byType(Overlay), findsWidgets);
    });

    testWidgets('the café amenity opens the existing menu', (tester) async {
      await tester.pumpWidget(const EvilSpaceApp());
      await tester.pumpAndSettle();

      expect(find.text('01  /  COWORKING'), findsOneWidget);
      expect(find.text('02  /  CAFÉ'), findsOneWidget);
      await tester.ensureVisible(find.text('VIEW MENU'));
      await tester.tap(find.text('VIEW MENU'));
      await tester.pumpAndSettle();

      expect(find.byType(MenuScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('localization', () {
    test('contains the daily product copy in all supported languages', () {
      final localization = LocalizationController(AppLanguage.en);
      expect(localization.t('brand_daily'), 'EVIL SPACE / DAILY');
      expect(localization.t('prices_title'), 'SIMPLE PRICES');
      expect(localization.t('price_locker'), 'PERSONAL LOCKER');
      expect(localization.t('amenity_cafe_zone'), 'CAFÉ');
      expect(localization.t('visit_title'), 'FIND EVIL SPACE');

      localization.setLanguage(AppLanguage.ru);
      expect(localization.t('price_month'), 'ОДИН МЕСЯЦ');
      expect(localization.t('price_locker'), 'ЛИЧНЫЙ ШКАФЧИК');
      expect(localization.t('amenity_menu'), 'ОТКРЫТЬ МЕНЮ');
      expect(localization.t('opening_studio'), 'ПОДКАСТ / СТУДИЯ');

      localization.setLanguage(AppLanguage.vi);
      expect(localization.t('prices_title'), 'BẢNG GIÁ');
      expect(localization.t('price_locker'), 'TỦ CÁ NHÂN');
      expect(localization.t('amenity_menu'), 'XEM THỰC ĐƠN');
      expect(localization.t('opening_lecture'), 'PHÒNG HỘI THẢO');
      expect(localization.t('contact_map'), 'ẢNH & ĐÁNH GIÁ');

      localization.dispose();
    });

    test('falls back to the key when no translation exists', () {
      final localization = LocalizationController();
      expect(localization.t('prices_title'), 'SIMPLE PRICES');
      expect(localization.t('missing_key'), 'missing_key');
      localization.dispose();
    });
  });

  group('site content', () {
    test('parses booking prices, openings, and announcements', () {
      final content = SiteContent.fromJson({
        'status': {'updated': '2026-08-21', 'todayPrice': 150000, 'tomorrowPrice': 200000},
        'prices': [
          {'label_key': 'price_day_pass', 'price': '200K'},
        ],
        'announcements': [
          {
            'date': '21 AUG',
            'text': {'en': 'HELLO', 'ru': 'ПРИВЕТ', 'vi': 'XIN CHÀO'},
          },
        ],
        'openings': [
          {
            'label_key': 'opening_studio',
            'opening_date': '2026-10-20',
            'is_open': false,
          },
        ],
      });

      expect(content.status.todayPrice, 150000);
      expect(content.status.tomorrowPrice, 200000);
      expect(content.status.updated, '2026-08-21');
      expect(content.prices.single.price, '200K');
      expect(content.announcements.single.textFor('ru'), 'ПРИВЕТ');
      expect(content.announcements.single.textFor('vi'), 'XIN CHÀO');
      expect(content.openings.single.labelKey, 'opening_studio');
      expect(content.openings.single.openingDate, '2026-10-20');
      expect(content.openings.single.isOpen, isFalse);
    });

    test('uses safe demo data when sections are empty', () {
      final content = SiteContent.fromJson(const {});
      expect(content.status.todayPrice, greaterThan(0));
      expect(content.prices, isNotEmpty);
      expect(content.announcements, isNotEmpty);
      expect(content.openings, isNotEmpty);
      expect(
        content.prices.map((price) => price.price),
        orderedEquals(['200K VND', '2.5 MLN VND', '1 MLN VND / MONTH']),
      );
    });
  });

  test('admin preview is opt-in and locked in normal builds', () {
    expect(AdminBuildConfig.previewEnabled, isFalse);
  });
}
