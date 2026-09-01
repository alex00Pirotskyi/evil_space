import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:evil_space/app_route.dart';
import 'package:evil_space/app_router.dart';
import 'package:evil_space/localization.dart';

void main() {
  testWidgets('admin route isolates text fields from public selection layer', (
    tester,
  ) async {
    final localization = LocalizationController(AppLanguage.en);
    final router = EvilSpaceRouterDelegate(localization: localization);

    await tester.pumpWidget(
      MaterialApp.router(
        routerDelegate: router,
        routeInformationParser: const EvilSpaceRouteParser(),
      ),
    );
    await tester.pumpAndSettle();

    router.navigate(AppRoute.admin);
    await tester.pumpAndSettle();

    expect(find.byType(SelectionArea), findsNothing);
    expect(find.byType(TextField), findsNWidgets(2));

    final passwordField = find.byType(TextField).at(1);
    await tester.tap(passwordField);
    await tester.enterText(passwordField, 'abcd');
    await tester.pump();

    final editable = tester.widget<EditableText>(
      find.descendant(of: passwordField, matching: find.byType(EditableText)),
    );
    expect(editable.controller.text, 'abcd');

    router.dispose();
    localization.dispose();
  });
}
