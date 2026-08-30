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
    test('round-trips accepted booking state', () {
      final state = DeskBookingState.fromJson(
        const {
          'token': '12345678901234567890123456789012',
          'status': 'accepted',
        },
      );

      expect(state.valid, isTrue);
      expect(state.accepted, isTrue);
      expect(state.pending, isFalse);
      expect(DeskBookingState.fromJson(state.toJson()).status, 'accepted');
    });

    test('rejects short tokens and unknown statuses', () {
      expect(
        const DeskBookingState(token: 'short', status: 'pending').valid,
        isFalse,
      );
      expect(
        const DeskBookingState(
          token: '12345678901234567890123456789012',
          status: 'cancelled',
        ).valid,
        isFalse,
      );
    });
  });
}
