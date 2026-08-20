import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:evil_space/app_route.dart';
import 'package:evil_space/app_router.dart';
import 'package:evil_space/coworking_model.dart';
import 'package:evil_space/eink_image.dart';
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
    test('contains Russian and Vietnamese e-paper landing copy', () {
      final localization = LocalizationController(AppLanguage.ru);
      expect(localization.t('nav_photos'), 'ФОТО');
      expect(localization.t('occupied'), 'СТОЛОВ ЗАНЯТО');

      localization.setLanguage(AppLanguage.vi);
      expect(localization.t('nav_photos'), 'HÌNH ẢNH');
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

  group('e-ink image pipeline', () {
    test('converts a contrast image into a bounded four-tone frame', () {
      const columns = 8;
      const rows = 4;
      final rgba = Uint8List(columns * rows * 4);

      for (int y = 0; y < rows; y++) {
        for (int x = 0; x < columns; x++) {
          final offset = ((y * columns) + x) * 4;
          final value = x < 2
              ? 5
              : x < 4
                  ? 85
                  : x < 6
                      ? 175
                      : 250;
          rgba[offset] = value;
          rgba[offset + 1] = value;
          rgba[offset + 2] = value;
          rgba[offset + 3] = 255;
        }
      }

      final frame = EInkProcessor.processRgba(
        rgba: rgba,
        columns: columns,
        rows: rows,
      );

      expect(frame.columns, columns);
      expect(frame.rows, rows);
      expect(frame.levels.length, columns * rows);
      expect(frame.levels.every((level) => level <= 3), isTrue);
      expect(frame.levels.contains(0), isTrue);
      expect(frame.levels.contains(3), isTrue);
    });

    test('Atkinson diffusion creates intermediate ink structure', () {
      const columns = 12;
      const rows = 8;
      final rgba = Uint8List(columns * rows * 4);

      for (int y = 0; y < rows; y++) {
        for (int x = 0; x < columns; x++) {
          final offset = ((y * columns) + x) * 4;
          final value = ((x / (columns - 1)) * 255).round();
          rgba[offset] = value;
          rgba[offset + 1] = value;
          rgba[offset + 2] = value;
          rgba[offset + 3] = 255;
        }
      }

      final frame = EInkProcessor.processRgba(
        rgba: rgba,
        columns: columns,
        rows: rows,
      );
      final distinct = frame.levels.toSet();

      expect(distinct.length, greaterThanOrEqualTo(3));
      expect(distinct.contains(0), isTrue);
      expect(distinct.contains(3), isTrue);
    });

    test('demo fallback remains monochrome and four-level', () {
      final frame = EInkFrame.demo(columns: 40, rows: 24, variant: 1);
      expect(frame.levels.every((level) => level <= 3), isTrue);
      expect(frame.levels.toSet().length, greaterThan(1));
    });
  });
}
