import 'dart:ui' show PointerDeviceKind;

import 'package:evil_space/localization.dart';
import 'package:evil_space/menu_api.dart';
import 'package:evil_space/menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class OptionsApi extends MenuApi {
  List<MenuCartRequestLine>? ordered;

  @override
  Future<MenuCatalog> menu() async => MenuCatalog.fromJson({
    'groups': [
      {
        'id': 'coffee',
        'name': 'Coffee',
        'items': [
          {
            'id': 'americano',
            'name': 'Americano',
            'priceVnd': 30000,
            'options': [
              {
                'id': 'milk',
                'type': 'single',
                'name': 'Milk',
                'required': true,
                'default': 'none',
                'values': [
                  {'id': 'none', 'name': 'Without milk'},
                  {'id': 'milk', 'name': 'With milk', 'priceDeltaVnd': 5000},
                ],
              },
              {
                'id': 'shots',
                'type': 'dots',
                'name': 'Shots',
                'min': 1,
                'max': 3,
                'default': 2,
                'pricePerStepVnd': 10000,
              },
              {
                'id': 'extras',
                'type': 'multiple',
                'name': 'Extras',
                'values': [
                  {'id': 'honey', 'name': 'Honey', 'priceDeltaVnd': 2000},
                ],
              },
            ],
          },
        ],
      },
    ],
  });

  @override
  Future<MenuOrderPayment> createCartOrder(
    List<MenuCartRequestLine> cart, {
    int? promoGrantId,
    String? paymentToken,
  }) async {
    ordered = cart;
    final subtotal = cart.fold(0, (sum, line) => sum + line.quantity *
        (30000 + ((line.options['shots'] as int? ?? 2) - 1) * 10000 +
            (line.options['milk'] == 'milk' ? 5000 : 0)));
    return MenuOrderPayment.fromJson({
      'token': paymentToken,
      'orderCode': 'ABC234',
      'paymentMessage': 'EVIL ABC234',
      'amountVnd': subtotal,
      'originalAmountVnd': subtotal,
      'status': 'pending',
      'qrPayload': 'test-qr',
      'expiresAt': 2000000000,
    });
  }

  @override
  Future<MenuOrderPayment> updateCartOrder(
    String token,
    List<MenuCartRequestLine> cart, {
    int? promoGrantId,
  }) => createCartOrder(cart, paymentToken: token, promoGrantId: promoGrantId);

  @override
  Future<List<PromoPreview>> eligiblePromos(
    List<MenuCartRequestLine> cart, {
    String? paymentToken,
  }) async => [];
}

Future<void> openMenu(
  WidgetTester tester,
  OptionsApi api, [
  AppLanguage language = AppLanguage.en,
]) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: MenuScreen(
        localization: LocalizationController(language),
        onBack: () {},
        api: api,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('desktop curtain moves its background and keeps actions inside the panel', (tester) async {
    await openMenu(tester, OptionsApi());
    tester.view.physicalSize = const Size(1920, 1080);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('menu-item-americano')));
    final panel = find.byKey(const ValueKey('menu-curtain'));
    final surface = find.byKey(const ValueKey('menu-curtain-surface'));
    final initial = tester.getRect(panel);
    expect(initial.width, 560);
    expect(initial.right, 1920);
    expect(tester.getRect(surface), initial);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('menu-curtain-handle'))),
      kind: PointerDeviceKind.mouse);
    await gesture.moveBy(const Offset(45, 0));
    await tester.pump();
    final moved = tester.getRect(panel);
    expect(moved.left, greaterThan(initial.left));
    expect(tester.getRect(surface), moved);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(surface), initial);
    final action = tester.getRect(find.widgetWithText(FilledButton, 'ADD TO CART'));
    expect(action.left, greaterThan(initial.left));
    expect(action.right, lessThan(initial.right));
    expect(tester.takeException(), isNull);
    await tapVisible(tester, find.text('CANCEL'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'configuration has one updating price including default options',
    (tester) async {
      await openMenu(tester, OptionsApi());
      await tapVisible(tester, find.text('Americano'));
      expect(find.byType(Dialog), findsNothing);
      expect(find.byKey(const ValueKey('menu-curtain')), findsOneWidget);
      expect(tester.getRect(find.byKey(const ValueKey('menu-curtain'))).bottom, closeTo(844, 1));
      Finder dialogText(String text) =>
          find.descendant(of: find.byKey(const ValueKey('menu-curtain')), matching: find.text(text));

      expect(dialogText('40,000 VND'), findsOneWidget);
      expect(dialogText('30,000 VND'), findsNothing);
      expect(dialogText('TOTAL'), findsNothing);
      await tapVisible(tester, dialogText('With milk'));
      expect(dialogText('45,000 VND'), findsOneWidget);
      expect(dialogText('40,000 VND'), findsNothing);
      await tapVisible(tester, dialogText('Honey'));
      expect(dialogText('47,000 VND'), findsOneWidget);
      expect(dialogText('45,000 VND'), findsNothing);
      await tapVisible(tester, dialogText('Without milk'));
      expect(dialogText('42,000 VND'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mouse drag expands and dismisses configuration without adding', (
    tester,
  ) async {
    final api = OptionsApi();
    await openMenu(tester, api);
    await tapVisible(tester, find.text('Americano'));
    final initialWidth = tester.getSize(find.byKey(const ValueKey('menu-curtain'))).width;
    final handle = find.byKey(const ValueKey('menu-curtain-handle'));
    await tester.drag(handle, const Offset(-130, 0), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('menu-curtain'))).width, greaterThan(initialWidth + 20));
    await tester.drag(handle, const Offset(600, 0), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('menu-curtain')), findsNothing);
    expect(tester.widget<TextButton>(find.byKey(const ValueKey('menu-pay'))).onPressed, isNull);
    expect(api.ordered, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('configuration accepts only one result during its exit animation', (tester) async {
    await openMenu(tester, OptionsApi());
    await tapVisible(tester, find.text('Americano'));
    final add = find.text('ADD TO CART');
    await tester.tap(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.byType(MenuScreen), findsOneWidget);
    expect(find.text('Americano × 1'), findsOneWidget);
    expect(find.text('PAY: 40,000 VND'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('menu removal chooses a configuration and subtracts one unit', (tester) async {
    final api = OptionsApi();
    await openMenu(tester, api);
    await tapVisible(tester, find.byKey(const ValueKey('menu-item-americano')));
    await tapVisible(tester, find.text('With milk'));
    await tapVisible(tester, find.text('ADD TO CART'));
    await tapVisible(tester, find.byKey(const ValueKey('menu-item-americano')));
    await tapVisible(tester, find.text('ADD TO CART'));
    expect(find.text('Americano × 2'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('menu-remove-americano')));
    expect(find.text('Remove one drink'), findsOneWidget);
    final selected = find.text('Americano · With milk · Shots 2/3 × 1');
    await tester.tap(selected);
    await tester.tap(selected);
    await tester.pumpAndSettle();
    expect(find.text('Americano × 1'), findsOneWidget);
    expect(find.text('PAY: 40,000 VND'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('menu-pay')));
    expect(api.ordered, hasLength(1));
    expect(api.ordered!.single.options['milk'], 'none');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final (language, add, viewCart) in [
    (AppLanguage.en, 'ADD TO CART', 'PAY'),
    (AppLanguage.ru, 'В КОРЗИНУ', 'ОПЛАТИТЬ'),
    (AppLanguage.vi, 'THÊM VÀO GIỎ', 'THANH TOÁN'),
  ]) {
    testWidgets(
      'tapping the drink name adds different configurations in ${language.code}',
      (tester) async {
        final api = OptionsApi();
        await openMenu(tester, api, language);
        await tapVisible(tester, find.text('Americano'));
        await tapVisible(tester, find.text('With milk'));
        await tapVisible(tester, find.text(add));
        expect(find.text('Americano × 1'), findsOneWidget);
        expect(
          tester.widget<Material>(
            find.byKey(const ValueKey('menu-item-surface-americano')),
          ).color,
          isNot(Colors.transparent),
        );
        expect(find.widgetWithText(FilledButton, 'Americano'), findsNothing);
        expect(find.byIcon(Icons.tune), findsNothing);

        await tapVisible(tester, find.byKey(const ValueKey('menu-item-americano')));
        // Each new drink starts from menu defaults, not the previous drink.
        expect(
          tester
              .widget<RadioListTile<String>>(
                find.widgetWithText(RadioListTile<String>, 'Without milk'),
              )
              .groupValue,
          'none',
        );
        await tapVisible(tester, find.text(add));
        expect(find.text('Americano × 2'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Americano'), findsNothing);
        expect(find.text('$viewCart: 85,000 VND'), findsOneWidget);
        await tapVisible(tester, find.byKey(const ValueKey('menu-pay')));
        expect(api.ordered, hasLength(2));
        expect(api.ordered!.map((line) => line.quantity), [1, 1]);
        expect(api.ordered!.map((line) => line.options['milk']), [
          'milk',
          'none',
        ]);
        expect(find.text('Americano · With milk · Shots 2/3'), findsOneWidget);
        expect(
          find.text('Americano · Without milk · Shots 2/3'),
          findsOneWidget,
        );
        if (language == AppLanguage.en) {
          await tapVisible(tester, find.text('REMOVE').first);
          expect(api.ordered, hasLength(1));
          expect(api.ordered!.single.options['milk'], 'none');
          expect(find.text('Americano · With milk · Shots 2/3'), findsNothing);
          expect(find.text('Americano · Without milk · Shots 2/3'), findsOneWidget);
          expect(find.text('PAY 40,000 VND'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
