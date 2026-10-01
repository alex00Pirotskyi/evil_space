import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:evil_space/admin_api.dart';
import 'package:evil_space/admin_screen.dart';
import 'package:evil_space/admin_api_models.dart';

class BookingAdminApi extends AdminApi {
  bool cancelled = false;
  final cancelledIds = <int>[];
  @override
  Future<OperationsSnapshot> operations() async => OperationsSnapshot.fromJson({
    'booking_requests': [if (!cancelled) {
      'id': 42, 'name': 'Accepted guest', 'contact_type': 'phone',
      'contact_value': '+84901234567', 'status': 'accepted',
      'service_day': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'amount_vnd': 200000, 'handled_by_email': 'automatic',
    }],
  });
  @override
  Future<OperationsSnapshot> cancelBooking(int id) async {
    cancelledIds.add(id);
    cancelled = true;
    return operations();
  }
}

void main() {
  testWidgets('accepted bookings can be cancelled from the admin dashboard', (tester) async {
    final api = BookingAdminApi();
    await tester.pumpWidget(MaterialApp(home: AdminScreen(api: api,
      onExit: () {}, onManageAdmins: () {})));
    await tester.pumpAndSettle();
    expect(find.text('Accepted guest'), findsOneWidget);
    final cancel = find.text('ОТМЕНИТЬ');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(api.cancelledIds, [42]);
    expect(find.text('Accepted guest'), findsNothing);
    expect(find.text('БРОНЬ ОТМЕНЕНА'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('add customer remains available while dashboard data is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminScreen(
          api: AdminApi(),
          onExit: () {},
          onManageAdmins: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final addCustomer = find.text('ДОБАВИТЬ КЛИЕНТА');
    expect(addCustomer, findsOneWidget);

    await tester.tap(addCustomer);
    await tester.pumpAndSettle();

    expect(find.text('ДНЕВНОЙ ПРОПУСК'), findsOneWidget);
    expect(find.text('МЕСЯЧНЫЙ ПРОПУСК'), findsOneWidget);
  });
}
