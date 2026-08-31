import 'package:flutter_test/flutter_test.dart';

import 'package:evil_space/main.dart';

void main() {
  testWidgets('first visit requires a language choice', (tester) async {
    await tester.pumpWidget(const EvilSpaceApp());
    await tester.pumpAndSettle();

    expect(find.text('CHOOSE LANGUAGE'), findsOneWidget);
    expect(find.text('РУССКИЙ'), findsOneWidget);

    await tester.tap(find.text('РУССКИЙ'));
    await tester.pumpAndSettle();

    expect(find.text('CHOOSE LANGUAGE'), findsNothing);
    expect(find.text('ТРИ ПРОСТЫЕ ЦЕНЫ'), findsOneWidget);
  });
}
