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
    return MenuOrderPayment.fromJson({
      'token': paymentToken,
      'orderCode': 'ABC234',
      'paymentMessage': 'EVIL ABC234',
      'amountVnd': 85000,
      'originalAmountVnd': 85000,
      'status': 'pending',
      'qrPayload': 'test-qr',
      'expiresAt': 2000000000,
    });
  }

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
      await tapVisible(tester, find.text('SETTINGS'));
      Finder dialogText(String text) =>
          find.descendant(of: find.byType(Dialog), matching: find.text(text));

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

  for (final (language, settings, add, viewCart) in [
    (AppLanguage.en, 'SETTINGS', 'ADD TO CART', 'VIEW CART'),
    (AppLanguage.ru, 'НАСТРОИТЬ', 'В КОРЗИНУ', 'ОТКРЫТЬ КОРЗИНУ'),
    (AppLanguage.vi, 'TÙY CHỈNH', 'THÊM VÀO GIỎ', 'XEM GIỎ HÀNG'),
  ]) {
    testWidgets(
      'same settings button adds different drinks in ${language.code}',
      (tester) async {
        final api = OptionsApi();
        await openMenu(tester, api, language);
        await tapVisible(tester, find.text(settings));
        await tapVisible(tester, find.text('With milk'));
        await tapVisible(tester, find.text(add));
        expect(find.widgetWithText(FilledButton, settings), findsOneWidget);
        expect(find.byIcon(Icons.tune), findsNothing);

        await tapVisible(tester, find.text(settings));
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
        expect(find.widgetWithText(FilledButton, settings), findsOneWidget);
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
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
