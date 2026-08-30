import 'package:flutter_test/flutter_test.dart';

import 'package:evil_space/public_desk_models.dart';

void main() {
  group('DeskBookingProfile', () {
    test('accepts phone and Telegram contacts', () {
      expect(
        const DeskBookingProfile(
          name: 'Alex',
          contactType: 'phone',
          contactValue: '+84 123 456',
        ).valid,
        isTrue,
      );
      expect(
        const DeskBookingProfile(
          name: 'Alex',
          contactType: 'telegram',
          contactValue: '@alex',
        ).valid,
        isTrue,
      );
    });

    test('rejects missing identity or unsupported contact types', () {
      expect(
        const DeskBookingProfile(
          name: ' ',
          contactType: 'telegram',
          contactValue: '@alex',
        ).valid,
        isFalse,
      );
      expect(
        const DeskBookingProfile(
          name: 'Alex',
          contactType: 'email',
          contactValue: 'alex@example.com',
        ).valid,
        isFalse,
      );
    });
  });

  group('DeskBookingState', () {
    const token = '12345678901234567890123456789012';

    test('round-trips accepted booking state', () {
      final state = DeskBookingState.fromJson(
        const {
          'token': token,
          'status': 'accepted',
        },
      );

      expect(state.valid, isTrue);
      expect(state.accepted, isTrue);
      expect(state.pending, isFalse);
      expect(DeskBookingState.fromJson(state.toJson()).status, 'accepted');
    });

    test('round-trips Telegram connection metadata', () {
      final state = DeskBookingState.fromJson(
        const {
          'token': token,
          'status': 'pending',
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
      const declined = DeskBookingState(token: token, status: 'declined');
      const cancelled = DeskBookingState(token: token, status: 'cancelled');

      expect(declined.valid, isTrue);
      expect(declined.declined, isTrue);
      expect(declined.finished, isTrue);
      expect(cancelled.valid, isTrue);
      expect(cancelled.cancelled, isTrue);
      expect(cancelled.finished, isTrue);
    });

    test('rejects short tokens and unknown statuses', () {
      expect(
        const DeskBookingState(token: 'short', status: 'pending').valid,
        isFalse,
      );
      expect(
        const DeskBookingState(token: token, status: 'mystery').valid,
        isFalse,
      );
    });
  });
}
