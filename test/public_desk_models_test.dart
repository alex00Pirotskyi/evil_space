import 'package:flutter_test/flutter_test.dart';

import 'package:evil_space/public_desk_models.dart';

void main() {
  const date = '2026-09-01';

  group('DeskBookingProfile', () {
    test('accepts phone and Telegram contacts with a service date', () {
      expect(
        const DeskBookingProfile(
          name: 'Alex',
          contactType: 'phone',
          contactValue: '+84 123 456',
          serviceDate: date,
        ).valid,
        isTrue,
      );
      expect(
        const DeskBookingProfile(
          name: 'Alex',
          contactType: 'telegram',
          contactValue: '@alex',
          serviceDate: date,
        ).valid,
        isTrue,
      );
    });

    test('rejects missing identity, bad contact type, or bad date', () {
      expect(
        const DeskBookingProfile(
          name: ' ',
          contactType: 'telegram',
          contactValue: '@alex',
          serviceDate: date,
        ).valid,
        isFalse,
      );
      expect(
        const DeskBookingProfile(
          name: 'Alex',
          contactType: 'email',
          contactValue: 'alex@example.com',
          serviceDate: date,
        ).valid,
        isFalse,
      );
      expect(
        const DeskBookingProfile(
          name: 'Alex',
          contactType: 'phone',
          contactValue: '+84 123',
          serviceDate: 'tomorrow',
        ).valid,
        isFalse,
      );
    });
  });

  group('DeskBookingState', () {
    const token = '12345678901234567890123456789012';

    test('round-trips accepted booking date and locked amount', () {
      final state = DeskBookingState.fromJson(
        const {
          'token': token,
          'status': 'accepted',
          'serviceDate': date,
          'amountVnd': 200000,
        },
      );

      expect(state.valid, isTrue);
      expect(state.accepted, isTrue);
      expect(state.serviceDate, date);
      expect(state.amountVnd, 200000);
      final restored = DeskBookingState.fromJson(state.toJson());
      expect(restored.status, 'accepted');
      expect(restored.serviceDate, date);
      expect(restored.amountVnd, 200000);
    });

    test('round-trips Telegram connection metadata', () {
      final state = DeskBookingState.fromJson(
        const {
          'token': token,
          'status': 'pending',
          'serviceDate': date,
          'amountVnd': 100000,
          'telegramLinkUrl':
              'https://t.me/CoworkingEvilAdminBot?start=c_test',
          'telegramLinked': false,
        },
      );

      expect(state.canConnectTelegram, isTrue);
      final linked = DeskBookingState.fromJson({
        ...state.toJson(),
        'telegramLinked': true,
      });
      expect(linked.telegramLinked, isTrue);
      expect(linked.canConnectTelegram, isFalse);
    });

    test('accepts declined and cancelled terminal states', () {
      const declined = DeskBookingState(
        token: token,
        status: 'declined',
        serviceDate: date,
        amountVnd: 200000,
      );
      const cancelled = DeskBookingState(
        token: token,
        status: 'cancelled',
        serviceDate: date,
        amountVnd: 200000,
      );

      expect(declined.valid, isTrue);
      expect(declined.finished, isTrue);
      expect(cancelled.valid, isTrue);
      expect(cancelled.finished, isTrue);
    });

    test('rejects short tokens, unknown statuses, bad dates and zero prices', () {
      expect(
        const DeskBookingState(
          token: 'short',
          status: 'pending',
          serviceDate: date,
          amountVnd: 200000,
        ).valid,
        isFalse,
      );
      expect(
        const DeskBookingState(
          token: token,
          status: 'mystery',
          serviceDate: date,
          amountVnd: 200000,
        ).valid,
        isFalse,
      );
      expect(
        const DeskBookingState(
          token: token,
          status: 'pending',
          serviceDate: 'tomorrow',
          amountVnd: 200000,
        ).valid,
        isFalse,
      );
      expect(
        const DeskBookingState(
          token: token,
          status: 'pending',
          serviceDate: date,
          amountVnd: 0,
        ).valid,
        isFalse,
      );
    });
  });
}
