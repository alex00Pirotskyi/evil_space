import 'package:flutter_test/flutter_test.dart';

import 'package:evil_space/main.dart';

void main() {
  testWidgets('first visit shows the homepage and keeps the language switch', (tester) async {
    await tester.pumpWidget(const EvilSpaceApp());
    await tester.pumpAndSettle();

    expect(find.text('CHOOSE LANGUAGE'), findsNothing);
    expect(find.text('SIMPLE PRICES'), findsOneWidget);
    expect(find.text('RU'), findsOneWidget);

    await tester.tap(find.text('RU'));
    await tester.pumpAndSettle();

    expect(find.text('CHOOSE LANGUAGE'), findsNothing);
    expect(find.text('ПРОСТЫЕ ЦЕНЫ'), findsOneWidget);
  });
}
