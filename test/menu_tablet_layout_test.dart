import 'package:evil_space/localization.dart';
import 'package:evil_space/menu_api.dart';
import 'package:evil_space/menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'menu_live_checkout_test.dart' show CheckoutApi;

MenuCatalog twoGroupCatalog() => MenuCatalog.fromJson({
  'groups': [
    {
      'id': 'coffee',
      'name': 'Coffee',
      'items': [
        {'id': 'cola', 'name': 'Cola', 'priceVnd': 30000},
      ],
    },
    {
      'id': 'tea',
      'name': 'Tea',
      'items': [
        {'id': 'coffee', 'name': 'Latte', 'priceVnd': 45000,
         'description': 'Slow brewed with milk'},
      ],
    },
  ],
});

Future<void> mountMenu(WidgetTester tester, CheckoutApi api,
    {required Size size}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: MenuScreen(
    api: api,
    initialMenu: twoGroupCatalog(),
    localization: LocalizationController(),
    onBack: () {},
  )));
  await tester.pumpAndSettle();
}

int gridColumns(WidgetTester tester, String group) {
  final grid = tester.widget<GridView>(
    find.byKey(ValueKey('menu-product-grid-$group')));
  return (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
      .crossAxisCount;
}

void main() {
  testWidgets('phone stays an editorial menu with a full-width pay bar',
      (tester) async {
    await mountMenu(tester, CheckoutApi(), size: const Size(390, 844));
    expect(find.byKey(const ValueKey('menu-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-grid-list')), findsNothing);
    expect(find.byKey(const ValueKey('menu-cart-sidebar')), findsNothing);
    expect(tester.getSize(find.byKey(const ValueKey('menu-pay'))).width, 390);
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait tablet has 2-column grid and sticky category navigation',
      (tester) async {
    final api = CheckoutApi();
    await mountMenu(tester, api, size: const Size(834, 1112));
    expect(find.byKey(const ValueKey('menu-grid-list')), findsOneWidget);
    expect(gridColumns(tester, 'coffee'), 2);
    expect(find.byKey(const ValueKey('menu-cart-sidebar')), findsNothing);
    expect(find.byKey(const ValueKey('menu-category-coffee')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('menu-category-tea')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-grid-item-cola')));
    await tester.pump();
    expect(find.text('PAY: 30,000 VND'), findsOneWidget);
    expect(api.creates, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('landscape tablet has persistent cart, quantity controls, QR left',
      (tester) async {
    final api = CheckoutApi();
    await mountMenu(tester, api, size: const Size(1194, 834));
    final cart = find.byKey(const ValueKey('menu-cart-sidebar'));
    expect(cart, findsOneWidget);
    expect(gridColumns(tester, 'coffee'), 2);
    expect(find.byKey(const ValueKey('menu-pay-bar')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('menu-grid-item-cola')));
    await tester.pump();
    expect(find.byKey(const ValueKey('menu-cart-lines')), findsOneWidget);
    expect(find.text('PAY: 30,000 VND'), findsOneWidget);
    await tester.tap(find.descendant(of: cart, matching: find.byIcon(Icons.add)).first);
    await tester.pump();
    expect(find.text('PAY: 60,000 VND'), findsOneWidget);
    await tester.tap(find.descendant(of: cart, matching: find.byIcon(Icons.remove)).first);
    await tester.pump();
    expect(find.text('PAY: 30,000 VND'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('menu-pay')));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    final realQr = tester.getRect(find.byType(QrImageView));
    expect(realQr.center.dx, lessThan(1194 / 2));
    expect(find.byKey(const ValueKey('menu-payment-view')), findsOneWidget);
    await tester.tap(find.text('PAY CASH'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('YOUR CART'), findsOneWidget);
    await tester.tap(find.text('PAY BY QR INSTEAD'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('checkout-menu')));
    await tester.pumpAndSettle();
    expect(cart, findsOneWidget);
    expect(find.text('PAY: 30,000 VND'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('large landscape tablet uses 3 product columns',
      (tester) async {
    await mountMenu(tester, CheckoutApi(), size: const Size(1366, 900));
    expect(find.byKey(const ValueKey('menu-cart-sidebar')), findsOneWidget);
    expect(gridColumns(tester, 'tea'), 3);
    expect(find.byKey(const ValueKey('menu-category-tea')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
