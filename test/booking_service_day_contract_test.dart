import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking service day migration and backend contract stay wired', () {
    final migration = File('migrations/0008_booking_service_day.sql').readAsStringSync();
    final entry = File('worker/entry.js').readAsStringSync();
    final telegram = File('worker/telegram.js').readAsStringSync();
    expect(migration, contains('service_day'));
    expect(migration, contains('amount_vnd'));
    expect(entry, contains('todayPrice: dayPassAmount(today, now)'));
    expect(entry, contains('tomorrowPrice: dayPassAmount(tomorrow, now)'));
    expect(entry, contains('serviceDayFromDateKey(body.serviceDate)'));
    expect(telegram, contains('visitTimestampForServiceDay'));
    expect(telegram, contains('service_day, amount_vnd'));
  });

  test('public UI exposes joined today and tomorrow booking choices', () {
    final shell = File('lib/app_shell.dart').readAsStringSync();
    final localization = File('lib/localization.dart').readAsStringSync();
    expect(shell, contains("widget.localization.t('booking_today')"));
    expect(shell, contains("widget.localization.t('booking_tomorrow')"));
    expect(shell, contains("widget.localization.t('half_day_note')"));
    expect(shell, contains('_bookingFor(todayDate)'));
    expect(shell, contains('_bookingFor(tomorrowDate)'));
    expect(localization, contains("'price_half_day': 'HALF DAY · AFTER 16:00'"));
    expect(localization, contains("'price_half_day': 'ПОЛДНЯ · ПОСЛЕ 16:00'"));
    expect(localization, contains("'price_half_day': 'NỬA NGÀY · SAU 16:00'"));
  });

  test('admin acknowledgement includes service day and locked amount', () {
    final models = File('lib/admin_api_models.dart').readAsStringSync();
    final screen = File('lib/admin_screen.dart').readAsStringSync();
    expect(models, contains('required this.serviceDay'));
    expect(models, contains('required this.amountVnd'));
    expect(screen, contains('_bookingDayLabel(booking)'));
    expect(screen, contains('_money(booking.amountVnd)'));
    expect(screen, contains("t('ПРИНЯТО', 'ACCEPTED')"));
  });

  test('old created-at midnight expiry is removed from active booking paths', () {
    final entry = File('worker/entry.js').readAsStringSync();
    final telegram = File('worker/telegram.js').readAsStringSync();
    expect(entry, contains('serviceDay < today || serviceDay >= end'));
    expect(telegram, contains('isBookableServiceDay(serviceDay, now)'));
    expect(telegram, contains("service_day = ?"));
  });
}
