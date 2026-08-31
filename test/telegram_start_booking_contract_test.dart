import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Telegram booking start creates or restores booking without cancelling', () {
    final telegram = File('worker/telegram.js').readAsStringSync();

    final start = telegram.indexOf("if (payload.startsWith('book_')) {");
    final startEnd = telegram.indexOf('\n  }', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(startEnd, greaterThan(start));
    expect(
      telegram.substring(start, startEnd),
      contains('bookViaTelegram(env, user, chatId, payload.slice(5))'),
    );
    expect(
      telegram.substring(start, startEnd),
      isNot(contains('cancelBookingRecord')),
    );

    final book = telegram.indexOf('async function bookViaTelegram');
    final identity = telegram.indexOf('function telegramBookingIdentity', book);
    expect(book, greaterThanOrEqualTo(0));
    expect(identity, greaterThan(book));
    final bookingFlow = telegram.substring(book, identity);
    expect(bookingFlow, contains("VALUES (?, 'telegram', ?, 'new', ?, ?)"));
    expect(bookingFlow, contains('sendCustomerPending'));
    expect(bookingFlow, isNot(contains('cancelBookingRecord')));
  });
}
