import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Telegram backend contract', () {
    late String migration;
    late String entry;
    late String telegram;
    late String setup;

    setUpAll(() {
      migration = File('migrations/0006_telegram_admin_client.sql').readAsStringSync();
      entry = File('worker/entry.js').readAsStringSync();
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
    test('public UI supports connect, terminal states and rebooking', () {
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
  });
}
