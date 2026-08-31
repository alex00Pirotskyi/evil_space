import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Telegram backend contract', () {
    late String migration;
    late String languageMigration;
    late String entry;
    late String worker;
    late String telegram;
    late String setup;

    setUpAll(() {
      migration = File(
        'migrations/0006_telegram_admin_client.sql',
      ).readAsStringSync();
      languageMigration = File(
        'migrations/0007_telegram_languages.sql',
      ).readAsStringSync();
      entry = File('worker/entry.js').readAsStringSync();
      worker = File('worker/index.js').readAsStringSync();
      telegram = File('worker/telegram.js').readAsStringSync();
      setup = File('tool/telegram_setup.dart').readAsStringSync();
    });

    test('migration contains admin, customer, session and audit state', () {
      for (final table in const [
        'admin_telegram_links',
        'admin_telegram_link_tokens',
        'customer_telegram_links',
        'customer_telegram_link_tokens',
        'telegram_admin_sessions',
        'telegram_booking_messages',
        'operation_audit',
      ]) {
        expect(migration, contains(table), reason: 'missing $table');
      }
    });

    test('Telegram language is persisted for admin and customer links', () {
      expect(languageMigration, contains('admin_telegram_links'));
      expect(languageMigration, contains('admin_telegram_link_tokens'));
      expect(languageMigration, contains('customer_telegram_links'));
      expect(languageMigration, contains('customer_telegram_link_tokens'));
      expect(languageMigration, contains("IN ('en', 'ru', 'vi')"));
      expect(telegram, contains('normalizeLanguage'));
      expect(telegram, contains("case 'language':"));
      expect(telegram, contains("callback_data: 'm:language'"));
    });

    test('Worker exposes secure Telegram and booking action routes', () {
      expect(entry, contains("'/api/telegram/webhook'"));
      expect(entry, contains("'/api/admin/telegram/link'"));
      expect(entry, contains("'/api/admin/telegram/preferences'"));
      expect(entry, contains("'/api/admin/booking/accept'"));
      expect(entry, contains("'/api/admin/booking/decline'"));
      expect(entry, contains('ctx.waitUntil(notifyAdminsNewBooking'));
      expect(telegram, contains('X-Telegram-Bot-Api-Secret-Token'));
      expect(telegram, contains('TELEGRAM_WEBHOOK_SECRET'));
    });

    test('operational day pass price is 200K everywhere', () {
      expect(worker, contains('const DAY_PASS_VND = 200000;'));
      expect(worker, isNot(contains('const DAY_PASS_VND = 250000;')));
      expect(telegram, contains('const DAY_PASS_VND = 200000;'));
      expect(telegram, contains("'200K VND'"));
      expect(telegram, isNot(contains('const DAY_PASS_VND = 250000;')));
      expect(telegram, isNot(contains("'250K VND'")));
      expect(worker, contains('const MONTH_PASS_VND = 2500000;'));
      expect(telegram, contains('const MONTH_PASS_VND = 2500000;'));
    });

    test('one-tap TG booking uses Telegram identity and website language', () {
      expect(telegram, contains("payload.startsWith('book_')"));
      expect(telegram, contains('telegramBookingIdentity(user)'));
      expect(telegram, contains("contact_type, contact_value"));
      expect(telegram, contains("VALUES (?, 'telegram', ?, 'new', ?, ?)"));
      expect(telegram, contains('notifyAdminsNewBooking(env, created.id)'));
    });

    test('Wi-Fi and bot credentials are runtime secrets, never constants', () {
      expect(telegram, contains('env.TELEGRAM_BOT_TOKEN'));
      expect(telegram, contains('env.WIFI_PASSWORD'));
      expect(telegram, isNot(contains('const WIFI_PASSWORD =')));
      expect(setup, contains("'TELEGRAM_BOT_TOKEN'"));
      expect(setup, contains("'TELEGRAM_WEBHOOK_SECRET'"));
      expect(setup, contains("'WIFI_PASSWORD'"));
      expect(setup, contains("'setWebhook'"));
    });

    test('tracked integration sources contain no literal Telegram bot token', () {
      final tokenPattern = RegExp(r'\b\d{6,12}:[A-Za-z0-9_-]{30,}\b');
      final files = <String>[
        'worker/entry.js',
        'worker/index.js',
        'worker/telegram.js',
        'worker/telegram_test.mjs',
        'tool/release.dart',
        'tool/telegram_setup.dart',
        'wrangler.toml',
        'lib/admin_portal.dart',
        'lib/admin_api_web.dart',
        'lib/public_desk_web.dart',
      ];

      for (final path in files) {
        final text = File(path).readAsStringSync();
        expect(
          tokenPattern.hasMatch(text),
          isFalse,
          reason: 'possible Telegram bot token committed in $path',
        );
      }
    });
  });

  group('Telegram Flutter contract', () {
    test('public booking is TG one-tap or name plus phone only', () {
      final shell = File('lib/app_shell.dart').readAsStringSync();
      expect(
        shell,
        contains('CoworkingEvilAdminBot?start=book_'),
      );
      expect(shell, contains('booking_tg_button'));
      expect(shell, contains("contactType: 'phone'"));
      expect(shell, isNot(contains('_contactTypeButton')));
      expect(shell, isNot(contains("String _type = 'telegram'")));
    });

    test('public UI supports legacy connect and terminal states', () {
      final shell = File('lib/app_shell.dart').readAsStringSync();
      expect(shell, contains('booking_connect_telegram'));
      expect(shell, contains('booking_telegram_connected'));
      expect(shell, contains('booking_declined'));
      expect(shell, contains('booking_cancelled'));
      expect(shell, contains('booking_again'));
    });

    test('admin UI exposes both accept and decline', () {
      final screen = File('lib/admin_screen.dart').readAsStringSync();
      final api = File('lib/admin_api_web.dart').readAsStringSync();
      expect(screen, contains('_declineBooking'));
      expect(screen, contains("t('ОТКЛОНИТЬ', 'DECLINE')"));
      expect(api, contains("'/api/admin/booking/decline'"));
    });

    test('admin Telegram pairing receives the selected web language', () {
      final router = File('lib/app_router.dart').readAsStringSync();
      final portal = File('lib/admin_portal.dart').readAsStringSync();
      final api = File('lib/admin_api_web.dart').readAsStringSync();
      expect(router, contains('languageCode: localization.language.code'));
      expect(portal, contains('initialLanguageCode'));
      expect(portal, contains('createTelegramLink(widget.languageCode)'));
      expect(api, contains("body: {'language': languageCode}"));
    });
  });
}
