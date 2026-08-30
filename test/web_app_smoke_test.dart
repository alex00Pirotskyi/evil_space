import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:evil_space/app_route.dart';
import 'package:evil_space/app_shell.dart';
import 'package:evil_space/localization.dart';

void main() {
  testWidgets('public web booking flow opens the contact form', (tester) async {
    final localization = LocalizationController(AppLanguage.en);
    addTearDown(localization.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: DailyScreen(
          currentRoute: AppRoute.home,
          localization: localization,
          onNavigate: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GET A DESK TODAY'), findsOneWidget);
    await tester.tap(find.text('GET A DESK TODAY'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.byType(TextField)), findsNWidgets(2));
    expect(
      find.descendant(of: dialog, matching: find.text('TELEGRAM')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('PHONE')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('SEND REQUEST')),
      findsOneWidget,
    );

    await tester.tap(find.descendant(of: dialog, matching: find.text('PHONE')));
    await tester.pump();
    expect(
      find.descendant(of: dialog, matching: find.text('PHONE')),
      findsOneWidget,
    );
  });
}
