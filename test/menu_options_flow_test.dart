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
  // The menu's checkout button keeps spinning behind the open cart dialog.
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
    'configuration has one updating price including default options',
    (tester) async {
      await openMenu(tester, OptionsApi());
      await tapVisible(tester, find.text('Americano'));
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tester.getRect(find.byType(BottomSheet)).bottom, closeTo(844, 1));
      Finder dialogText(String text) =>
          find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

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
        expect(find.text('Americano'), findsOneWidget);
        expect(
          tester.widget<Material>(
            find.byKey(const ValueKey('menu-item-surface-americano')),
          ).color,
          isNot(Colors.transparent),
        );
        expect(find.widgetWithText(FilledButton, 'Americano'), findsNothing);
        expect(find.byIcon(Icons.tune), findsNothing);

        await tapVisible(tester, find.text('Americano'));
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
        expect(find.text('Americano'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Americano'), findsNothing);
        await tapVisible(tester, find.text(viewCart));
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
