import 'dart:async';

import 'package:evil_space/localization.dart';
import 'package:evil_space/menu_api.dart';
import 'package:evil_space/menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

class CheckoutApi extends MenuApi {
  final creates = <String>[];
  final updates = <List<MenuCartRequestLine>>[];
  final cancellations = <String>[];
  MenuOrderPayment? current;
  Completer<MenuOrderPayment>? delayedUpdate;
  Completer<List<PromoPreview>>? delayedPromos;
  bool failUpdate = false;
  bool paidDuringUpdate = false;
  String status = 'pending';

  @override
  Future<MenuCatalog> menu() async => MenuCatalog.fromJson({
    'groups': [
      {
        'id': 'drinks',
        'name': 'Drinks',
        'items': [
          {'id': 'cola', 'name': 'Cola', 'priceVnd': 30000},
          {'id': 'coffee', 'name': 'Coffee', 'priceVnd': 45000},
        ],
      },
    ],
  });

  MenuOrderPayment payment(
    String token,
    List<MenuCartRequestLine> cart,
    int? grant,
  ) {
    final subtotal = cart.fold(
      0,
      (sum, line) =>
          sum + line.quantity * (line.itemId == 'cola' ? 30000 : 45000),
    );
    return MenuOrderPayment.fromJson({
      'token': token,
      'orderCode': 'ABC234',
      'paymentMessage': 'EVIL ABC234',
      'amountVnd': subtotal - (grant == null ? 0 : 10000),
      'originalAmountVnd': subtotal,
      'promoGrantId': grant,
      'promoDiscountVnd': grant == null ? 0 : 10000,
      'promoName': grant == null ? null : 'SAVE10',
      'status': 'pending',
      'qrPayload': 'qr:$subtotal:$grant',
      'expiresAt': 2000000000,
      'items': cart
          .map(
            (line) => {
              'itemId': line.itemId,
              'quantity': line.quantity,
              'unitPriceVnd': line.itemId == 'cola' ? 30000 : 45000,
            },
          )
          .toList(),
    });
  }

  @override
  Future<MenuOrderPayment> createCartOrder(
    List<MenuCartRequestLine> cart, {
    int? promoGrantId,
    String? paymentToken,
  }) async {
    creates.add(paymentToken!);
    return current = payment(paymentToken, cart, promoGrantId);
  }

  @override
  Future<MenuOrderPayment> updateCartOrder(
    String token,
    List<MenuCartRequestLine> cart, {
    int? promoGrantId,
  }) async {
    updates.add(cart);
    if (paidDuringUpdate) {
      status = 'paid';
      throw const MenuApiException('Inactive', statusCode: 409);
    }
    if (failUpdate) {
      throw const MenuApiException('Network error', statusCode: 500);
    }
    if (delayedUpdate != null) return current = await delayedUpdate!.future;
    return current = payment(token, cart, promoGrantId);
  }

  @override
  Future<List<PromoPreview>> eligiblePromos(
    List<MenuCartRequestLine> cart, {
    String? paymentToken,
  }) async {
    if (delayedPromos != null) return delayedPromos!.future;
    return [
      PromoPreview.fromJson({
        'grantId': 1,
        'name': 'SAVE10',
        'discountVnd': 10000,
        'remainingUses': 1,
      }),
    ];
  }

  @override
  Future<MenuOrderStatus> orderStatus(String token) async =>
      MenuOrderStatus.fromJson({
        'status': status,
        'orderCode': current?.orderCode,
        'amountVnd': current?.amountVnd,
        'originalAmountVnd': current?.originalAmountVnd,
        'paymentMessage': current?.paymentMessage,
        'promoGrantId': current?.promoGrantId,
        'promoDiscountVnd': current?.promoDiscountVnd,
      });

  @override
  Future<void> cancelCartOrder(String token) async {
    cancellations.add(token);
    status = 'cancelled';
  }
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> openCart(
  WidgetTester tester,
  CheckoutApi api, {
  AppLanguage language = AppLanguage.en,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: MenuScreen(
        api: api,
        localization: LocalizationController(language),
        onBack: () {},
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('Cola'));
  await tester.pump();
  final view = language == AppLanguage.ru
      ? 'ОТКРЫТЬ КОРЗИНУ'
      : language == AppLanguage.vi
      ? 'XEM GIỎ HÀNG'
      : 'VIEW CART';
  await tester.tap(find.text(view));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

void main() {
  testWidgets(
    'opening cart shows QR immediately; slow promos do not block it',
    (tester) async {
      final api = CheckoutApi()..delayedPromos = Completer();
      await openCart(tester, api);
      expect(api.creates, hasLength(1));
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Create payment'), findsNothing);
      expect(find.text('PAY 30,000 VND'), findsOneWidget);
      api.delayedPromos!.complete([]);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'quantity edits hide old QR immediately and update same reference',
    (tester) async {
      final api = CheckoutApi();
      await openCart(tester, api);
      final token = api.current!.token;
      api.delayedUpdate = Completer();
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pump();
      expect(find.byType(QrImageView), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      expect(api.updates.last.single.quantity, 2);
      api.delayedUpdate!.complete(api.payment(token, api.updates.last, null));
      await tester.pump();
      await tester.pump();
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('PAY 60,000 VND'), findsOneWidget);
      expect(api.creates, hasLength(1));
      expect(api.current!.paymentMessage, 'EVIL ABC234');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'promo edits and cash mode stay in the same cart; reopen keeps session',
    (tester) async {
      final api = CheckoutApi();
      await openCart(tester, api);
      await tapVisible(tester, find.text('SAVE10'));
      await tester.pump();
      expect(api.current!.amountVnd, 20000);
      await tapVisible(tester, find.text('PAY CASH'));
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Pay cash at counter'), findsOneWidget);
      await tapVisible(tester, find.text('PAY BY QR INSTEAD'));
      expect(find.byType(QrImageView), findsOneWidget);
      await tapVisible(tester, find.text('CLOSE'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('VIEW CART'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(api.creates, hasLength(1));
      expect(api.current!.promoGrantId, 1);
      expect(find.byType(QrImageView), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed update hides QR and offers retry without creating another order',
    (tester) async {
      final api = CheckoutApi();
      await openCart(tester, api);
      api.failUpdate = true;
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Network error'), findsOneWidget);
      api.failUpdate = false;
      await tapVisible(tester, find.text('RETRY'));
      expect(find.byType(QrImageView), findsOneWidget);
      expect(api.creates, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'staff confirmation during update shows paid state and locks editing',
    (tester) async {
      final api = CheckoutApi();
      await openCart(tester, api);
      api.paidDuringUpdate = true;
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('✓ PAYMENT CONFIRMED'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byIcon(Icons.add).last,
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('removing the last item cancels session and returns to menu', (
    tester,
  ) async {
    final api = CheckoutApi();
    await openCart(tester, api);
    await tapVisible(tester, find.text('REMOVE'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.cancellations, [api.creates.single]);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('VIEW CART'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tapping anywhere on a menu row adds to the same pending cart', (
    tester,
  ) async {
    final api = CheckoutApi();
    await openCart(tester, api);
    final reference = api.current!.paymentMessage;
    await tapVisible(tester, find.text('CLOSE'));
    final row = find.byKey(const ValueKey('menu-item-cola'));
    final bounds = tester.getRect(row);
    expect(bounds.width, greaterThan(300));
    expect(bounds.height, greaterThanOrEqualTo(72));
    expect(find.text('ADD'), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.remove), findsNothing);
    await tester.tapAt(Offset(bounds.right - 8, bounds.center.dy));
    await tester.pump();
    await tapVisible(tester, find.text('VIEW CART'));
    expect(api.creates, hasLength(1));
    expect(api.updates.last.single.quantity, 2);
    expect(api.current!.paymentMessage, reference);
    expect(find.text('PAY 60,000 VND'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final language in [AppLanguage.ru, AppLanguage.vi]) {
    testWidgets(
      'live checkout is localized in ${language.code} at mobile width',
      (tester) async {
        await openCart(tester, CheckoutApi(), language: language, width: 360);
        expect(find.byType(QrImageView), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
