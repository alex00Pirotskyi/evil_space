import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:evil_space/admin_portal.dart';

void main() {
  testWidgets('admin portal exposes sign in and owner approval request', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AdminPortal(onExit: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('STAFF ACCESS'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('NEW ADMIN? REQUEST ACCESS'), findsOneWidget);

    await tester.tap(find.text('NEW ADMIN? REQUEST ACCESS'));
    await tester.pump();

    expect(find.text('Request admin access.'), findsOneWidget);
    expect(find.text('SEND APPROVAL REQUEST'), findsOneWidget);
  });
}
