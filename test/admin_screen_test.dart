import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:evil_space/admin_api.dart';
import 'package:evil_space/admin_screen.dart';

void main() {
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
