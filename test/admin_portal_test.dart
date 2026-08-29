import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:evil_space/admin_portal.dart';

void main() {
  testWidgets('admin portal defaults to Russian and can switch to English', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AdminPortal(onExit: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('Вход'), findsOneWidget);
    expect(find.text('ВОЙТИ'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));

    final requestAccess = find.text('НОВЫЙ АДМИН? ЗАПРОСИТЬ ДОСТУП');
    expect(requestAccess, findsOneWidget);
    await tester.tap(requestAccess);
    await tester.pump();

    expect(find.text('Новый администратор'), findsOneWidget);
    expect(find.text('ОТПРАВИТЬ ЗАПРОС'), findsOneWidget);

    await tester.tap(find.text('EN'));
    await tester.pump();

    expect(find.text('New administrator'), findsOneWidget);
    expect(find.text('REQUEST ACCESS'), findsOneWidget);
  });
}
