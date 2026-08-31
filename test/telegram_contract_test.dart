import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Telegram backend contract', () {
    late String migration;
    late String languageMigration;
    late String serviceDayMigration;
    late String entry;
    late String worker;
    late String telegram;
    late String bookingRules;
    late String setup;

    setUpAll(() {
      migration = File(
        'migrations/0006_telegram_admin_client.sql',
      ).readAsStringSync();
      languageMigration = File(
        'migrations/0007_telegram_languages.sql',
      ).readAsStringSync();
      serviceDayMigration = File(
        'migrations/0008_booking_service_day.sql',
      ).readAsStringSync();
      entry = File('worker/entry.js').readAsStringSync();
      worker = File('worker/index.js').readAsStringSync();
      telegram = File('worker/telegram.js').readAsStringSync();
      bookingRules = File('worker/booking_rules.js').readAsStringSync();
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

    test('booking service day and locked amount are persisted', () {
      expect(serviceDayMigration, contains('service_day'));
      expect(serviceDayMigration, contains('amount_vnd'));
      expect(
        serviceDayMigration,
        contains('idx_booking_requests_service_day_status'),
      );
      expect(entry, contains('serviceDayFromDateKey(body.serviceDate)'));
      expect(telegram, contains('serviceDayFromCompactDate'));
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

    test('booking prices come from the shared Nha Trang rules', () {
      expect(bookingRules, contains('export const DAY_PASS_VND = 200000;'));
      expect(bookingRules, contains('export const HALF_DAY_VND = 100000;'));
      expect(bookingRules, contains('export const MONTH_PASS_VND = 2500000;'));
      expect(
        worker,
        contains('dayPassAmount(serviceDayForOffset(0, now), now)'),
      );
      expect(
        telegram,
        contains('dayPassAmount(serviceDayForOffset(0, now), now)'),
      );
      expect(worker, isNot(contains('250K VND')));
      expect(telegram, isNot(contains('250K VND')));
    });

    test('one-tap TG booking uses verified identity, absolute date and language', () {
      expect(telegram, contains("payload.startsWith('book_')"));
      expect(telegram, contains('telegramBookingIdentity(user)'));
      expect(telegram, contains('serviceDayFromCompactDate'));
      expect(telegram, contains("contact_type, contact_value"));
      expect(
        telegram,
        contains("VALUES (?, 'telegram', ?, 'new', ?, ?, ?, ?)"),
      );
      expect(telegram, contains('notifyAdminsNewBooking(env, created.id)'));
    });

    test('future accepted bookings use their service day for occupancy and income', () {
      expect(telegram, contains('visitTimestampForServiceDay'));
      expect(telegram, contains('serviceStart, serviceEnd'));
      expect(telegram, contains('claimed.amount_vnd'));
      expect(telegram, contains('No desks are left for this day.'));
    });

    test('admin Telegram acknowledgement includes date and locked price', () {
      expect(telegram, contains('bookingDayKind(serviceDay, nowSeconds())'));
      expect(telegram, contains('formatLocalDate(serviceDay)'));
      expect(telegram, contains('formatMoney(booking.amount_vnd)'));
      expect(telegram, contains("tr(lang, 'by')"));
    });

    test('customer cancellation requires a second explicit tap', () {
      expect(
        telegram,
        contains(
          "if (data.startsWith('cc:') || data.startsWith('cf:') || data.startsWith('ck:') || data.startsWith('cw:'))",
        ),
      );
      expect(telegram, contains('sendCustomerCancelConfirmation'));
      expect(telegram, contains(r'callback_data: `cf:${bookingId}`'));
      expect(telegram, contains(r'callback_data: `ck:${bookingId}`'));

      final ask = telegram.indexOf("if (data.startsWith('cc:')) {");
      final confirm = telegram.indexOf("if (data.startsWith('cf:')) {", ask);
      expect(ask, greaterThanOrEqualTo(0));
      expect(confirm, greaterThan(ask));
      expect(
        telegram.substring(ask, confirm),
        isNot(contains('cancelBookingRecord')),
      );

      final wifi = telegram.indexOf(
        "if (booking.status !== 'accepted')",
        confirm,
      );
      expect(wifi, greaterThan(confirm));
      final confirmedCancel = telegram.substring(confirm, wifi);
      expect(
        confirmedCancel,
        contains("cancelBookingRecord(env, booking, 'telegram')"),
      );
      expect(
        confirmedCancel,
        contains("notifyBookingOutcome(env, cancelled.id, 'cancelled')"),
      );
      expect(
        confirmedCancel,
        isNot(contains('sendCustomerCancelled(env, chatId, lang)')),
      );
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
        'worker/booking_rules.js',
        'worker/telegram_test.mjs',
        'worker/booking_rules_test.mjs',
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
      expect(shell, contains('CoworkingEvilAdminBot?start=book_'));
      expect(shell, contains('_compactServiceDate(serviceDate)'));
      expect(shell, contains('booking_tg_button'));
      expect(shell, contains("contactType: 'phone'"));
      expect(shell, contains('serviceDate: widget.serviceDate'));
      expect(shell, isNot(contains('_contactTypeButton')));
      expect(shell, isNot(contains("String _type = 'telegram'")));
    });

    test('public UI supports today and tomorrow independently', () {
      final shell = File('lib/app_shell.dart').readAsStringSync();
      expect(shell, contains("widget.localization.t('booking_today')"));
      expect(shell, contains("widget.localization.t('booking_tomorrow')"));
      expect(shell, contains('_bookingFor(todayDate)'));
      expect(shell, contains('_bookingFor(tomorrowDate)'));
      expect(shell, contains('booking_connect_telegram'));
      expect(shell, contains('booking_telegram_connected'));
      expect(shell, contains('booking_declined'));
      expect(shell, contains('booking_cancelled'));
      expect(shell, contains('booking_again'));
    });

    test('admin UI exposes accept, decline, day, date and exact amount', () {
      final screen = File('lib/admin_screen.dart').readAsStringSync();
      final api = File('lib/admin_api_web.dart').readAsStringSync();
      expect(screen, contains('_declineBooking'));
      expect(screen, contains("t('ОТКЛОНИТЬ', 'DECLINE')"));
      expect(screen, contains('_bookingDayLabel(booking)'));
      expect(screen, contains('_money(booking.amountVnd)'));
      expect(screen, contains('booking.handledByEmail'));
      expect(api, contains("'/api/admin/booking/decline'"));
    });

    test('admin displays full-day and half-day prices', () {
      final screen = File('lib/admin_screen.dart').readAsStringSync();
      expect(screen, contains("'200K VND'"));
      expect(screen, contains("'100K VND'"));
      expect(screen, isNot(contains("'250K VND'")));
    });

    test('public pricing includes half day and monthly personal locker', () {
      final content = File('assets/content/status.json').readAsStringSync();
      final localization = File('lib/localization.dart').readAsStringSync();
      expect(content, contains('"price_half_day"'));
      expect(content, contains('"100K VND"'));
      expect(content, contains('"price_locker"'));
      expect(content, contains('"1 MLN VND / MONTH"'));
      expect(
        localization,
        contains("'price_half_day': 'HALF DAY · AFTER 16:00'"),
      );
      expect(localization, contains("'price_locker': 'PERSONAL LOCKER'"));
      expect(localization, contains("'price_locker': 'ЛИЧНЫЙ ШКАФЧИК'"));
      expect(localization, contains("'price_locker': 'TỦ CÁ NHÂN'"));
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
