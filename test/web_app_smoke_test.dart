import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:evil_space/app_route.dart';
import 'package:evil_space/app_shell.dart';
import 'package:evil_space/localization.dart';

void main() {
  testWidgets('public booking offers one-tap TG or name plus phone', (
    tester,
  ) async {
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

    expect(find.text('TODAY'), findsOneWidget);
    await tester.tap(find.text('TODAY'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.byType(TextField)),
      findsNWidgets(2),
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.text('TG · BOOK WITH TELEGRAM'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('NAME')),
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
    expect(
      find.descendant(of: dialog, matching: find.text('TELEGRAM')),
      findsNothing,
    );
  });
}
