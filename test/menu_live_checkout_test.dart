import 'dart:async';

import 'package:evil_space/localization.dart';
import 'package:evil_space/app_route.dart';
import 'package:evil_space/app_router.dart';
import 'package:evil_space/menu_api.dart';
import 'package:evil_space/menu_screen.dart';
import 'package:evil_space/qr_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

class CheckoutApi extends MenuApi {
  final creates = <String>[];
  final updates = <List<MenuCartRequestLine>>[];
  final updateTokens = <String>[];
  final statusTokens = <String>[];
  String? canonicalToken;
  bool missingSession = false;
  bool failCreate = false;
  final cancellations = <String>[];
  MenuOrderPayment? current;
  Completer<MenuOrderPayment>? delayedUpdate;
  Completer<List<PromoPreview>>? delayedPromos;
  Completer<void>? delayedCancel;
  bool failCancel = false;
  bool paidDuringCancel = false;
  int statusRequests = 0;
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
    if (failCreate) {
      throw const MenuApiException('Network error', statusCode: 500);
    }
    missingSession = false;
    return current = payment(canonicalToken ?? paymentToken, cart, promoGrantId);
  }

  @override
  Future<MenuOrderPayment> updateCartOrder(
    String token,
    List<MenuCartRequestLine> cart, {
    int? promoGrantId,
  }) async {
    updates.add(cart);
    updateTokens.add(token);
    if (missingSession || token != current?.token) {
      throw const MenuApiException('Payment session not found.', statusCode: 404);
    }
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
  Future<MenuOrderStatus> orderStatus(String token) async {
    statusRequests++;
    statusTokens.add(token);
    if (missingSession || token != current?.token) {
      throw const MenuApiException('Order not found.', statusCode: 404);
    }
    return MenuOrderStatus.fromJson({
      'status': status,
      'orderCode': current?.orderCode,
      'amountVnd': current?.amountVnd,
      'originalAmountVnd': current?.originalAmountVnd,
      'paymentMessage': current?.paymentMessage,
      'promoGrantId': current?.promoGrantId,
      'promoDiscountVnd': current?.promoDiscountVnd,
    });
  }

  @override
  Future<void> cancelCartOrder(String token) async {
    cancellations.add(token);
    if (missingSession || token != current?.token) {
      throw const MenuApiException('Payment session not found.', statusCode: 404);
    }
    if (paidDuringCancel) {
      status = 'paid';
      throw const MenuApiException('Already paid', statusCode: 409);
    }
    if (failCancel) {
      throw const MenuApiException('Network error', statusCode: 500);
    }
    if (delayedCancel != null) await delayedCancel!.future;
    status = 'cancelled';
  }
}

void expectPayDisabled(WidgetTester tester) {
  final button = find.byKey(const ValueKey('menu-pay'));
  expect(button, findsOneWidget);
  expect(tester.widget<TextButton>(button).onPressed, isNull);
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pumpAndSettle();
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
  await tester.tap(find.byKey(const ValueKey('menu-pay')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('site router lets payment handle back before leaving the menu', (tester) async {
    final localization = LocalizationController();
    final api = CheckoutApi();
    final delegate = EvilSpaceRouterDelegate(localization: localization, menuApi: api);
    await tester.pumpWidget(MaterialApp.router(routerDelegate: delegate,
      routeInformationParser: const EvilSpaceRouteParser()));
    await tester.pumpAndSettle();
    delegate.navigate(AppRoute.menu);
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(navigator.push<void>(MaterialPageRoute(builder: (_) => MenuScreen(
      localization: localization, onBack: () {}, api: api))));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Cola'));
    await tapVisible(tester, find.byKey(const ValueKey('menu-pay')));
    expect(await delegate.popRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(delegate.currentRoute, AppRoute.menu);
    expect(find.byKey(const ValueKey('menu-payment-view')), findsNothing);
    expect(find.text('Cola × 1'), findsOneWidget);
    expect(api.cancellations, isEmpty);
    expect(await delegate.popRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(await delegate.popRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(delegate.currentRoute, AppRoute.home);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    delegate.dispose();
    localization.dispose();
  });

  testWidgets('PAY layers preserve the header, scroll and cart without hidden sessions', (tester) async {
    final api = CheckoutApi();
    tester.view.physicalSize = const Size(320, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: MenuScreen(api: api,
      localization: LocalizationController(), onBack: () {})));
    await tester.pumpAndSettle();
    expect(api.creates, isEmpty);
    await tapVisible(tester, find.byKey(const ValueKey('menu-item-cola')));
    final header = tester.getRect(find.byKey(const ValueKey('menu-app-bar')));
    final pay = tester.getRect(find.byKey(const ValueKey('menu-pay')));
    expect(pay.top, header.bottom);
    expect(pay.width, 320);
    final list = tester.widget<ListView>(find.byKey(const ValueKey('menu-list')));
    list.controller!.jumpTo(60);
    await tester.pump();
    final position = list.controller!.offset;
    await tester.tap(find.byKey(const ValueKey('menu-pay')));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final payment = find.byKey(const ValueKey('menu-payment-view'));
    final opacity = tester.widget<FadeTransition>(find.ancestor(of: payment,
      matching: find.byType(FadeTransition)).first).opacity.value;
    expect(opacity, greaterThan(0));
    expect(opacity, lessThan(1));
    final hiddenMenu = find.byKey(const ValueKey('menu-item-cola'));
    await tester.tap(hiddenMenu, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('menu-list')), findsNothing);
    expect(tester.getRect(find.byKey(const ValueKey('menu-app-bar'))), header);
    expect(api.creates, hasLength(1));
    expect(api.updates, isEmpty);
    await tapVisible(tester, find.byKey(const ValueKey('checkout-menu')));
    expect(find.text('Cola × 1'), findsOneWidget);
    expect(list.controller!.offset, position);
    expect(find.byKey(const ValueKey('menu-payment-view')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('language can change in payment without creating another session', (tester) async {
    final api = CheckoutApi();
    await openCart(tester, api);
    await tester.tap(find.text('RU'));
    await tester.pump();
    expect(find.text('МЕНЮ'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(api.creates, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'opening cart shows QR immediately; slow promos do not block it',
    (tester) async {
      final api = CheckoutApi()..delayedPromos = Completer();
      await openCart(tester, api);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byKey(const ValueKey('menu-payment-view')), findsOneWidget);
      final sheetBounds = tester.getRect(find.byKey(const ValueKey('menu-payment-view')));
      expect(sheetBounds.bottom, closeTo(844, 1));
      expect(sheetBounds.right, closeTo(390, 1));
      expect(sheetBounds.left, 0);
      expect(sheetBounds.top, tester.getRect(find.byKey(const ValueKey('menu-app-bar'))).bottom);
      expect(find.byKey(const ValueKey('menu-curtain')), findsNothing);
      expect(api.creates, hasLength(1));
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Create payment'), findsNothing);
      expect(find.text('PAY 30,000 VND'), findsOneWidget);
      api.delayedPromos!.complete([]);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('server token is used for updates, status, reopen and cancellation', (
    tester,
  ) async {
    final api = CheckoutApi()..canonicalToken = 'server-canonical-token';
    await openCart(tester, api);
    expect(api.creates.single, isNot(api.canonicalToken));
    await tapVisible(tester, find.byIcon(Icons.add));
    expect(api.updateTokens, [api.canonicalToken]);
    await tester.pump(const Duration(seconds: 2));
    expect(api.statusTokens, everyElement(api.canonicalToken));
    await tapVisible(tester, find.byKey(const ValueKey('checkout-menu')));
    expect(find.text('PAY: 60,000 VND'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('menu-pay')));
    expect(api.creates, hasLength(1));
    expect(api.updateTokens, everyElement(api.canonicalToken));
    await tapVisible(tester, find.text('REMOVE'));
    expect(api.cancellations, [api.canonicalToken]);
    expect(find.byKey(const ValueKey('menu-payment-view')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('missing session recovers once using the same idempotency token', (
    tester,
  ) async {
    final api = CheckoutApi();
    await openCart(tester, api);
    final token = api.creates.single;
    api.missingSession = true;
    await tapVisible(tester, find.byIcon(Icons.add));
    expect(api.creates, [token, token]);
    expect(api.current!.amountVnd, 60000);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Payment session not found.'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('missing cached session is restored when reopening the curtain', (
    tester,
  ) async {
    final api = CheckoutApi();
    await openCart(tester, api);
    final token = api.creates.single;
    await tapVisible(tester, find.byKey(const ValueKey('checkout-menu')));
    api.missingSession = true;
    await tapVisible(tester, find.byKey(const ValueKey('menu-pay')));
    expect(api.creates, [token, token]);
    expect(api.updateTokens, isEmpty);
    expect(find.byType(QrImageView), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed session recovery offers retry without a create loop', (
    tester,
  ) async {
    final api = CheckoutApi();
    await openCart(tester, api);
    final token = api.creates.single;
    api.missingSession = true;
    api.failCreate = true;
    await tapVisible(tester, find.byIcon(Icons.add));
    expect(api.creates, [token, token]);
    expect(find.text('Network error'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    await tester.pump(const Duration(seconds: 20));
    expect(api.creates, hasLength(2));
    api.failCreate = false;
    await tapVisible(tester, find.text('RETRY'));
    expect(api.creates, [token, token, token]);
    expect(find.byType(QrImageView), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('swipe left on PAY opens payment; swipe right saves the cart', (
    tester,
  ) async {
    final api = CheckoutApi();
    await openCart(tester, api);
    final reference = api.current!.paymentMessage;
    await tapVisible(tester, find.byKey(const ValueKey('checkout-menu')));
    final pay = find.byKey(const ValueKey('menu-pay'));
    expect(find.text('PAY: 30,000 VND'), findsOneWidget);
    expect(tester.widget<TextButton>(pay).onPressed, isNotNull);
    await tester.drag(find.byKey(const ValueKey('menu-pay-bar')), const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('menu-payment-view')), findsOneWidget);
    await tester.drag(find.byKey(const ValueKey('checkout-menu')), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('menu-payment-view')), findsNothing);
    expect(find.text('PAY: 30,000 VND'), findsOneWidget);
    expect(api.cancellations, isEmpty);
    await tapVisible(tester, pay);
    expect(api.creates, hasLength(1));
    expect(api.current!.paymentMessage, reference);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('swipe right waits for a cart update before allowing dismissal', (
    tester,
  ) async {
    final api = CheckoutApi();
    await openCart(tester, api);
    api.delayedUpdate = Completer();
    await tapVisible(tester, find.byIcon(Icons.add));
    await tester.drag(find.byKey(const ValueKey('checkout-menu')), const Offset(500, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('menu-payment-view')), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    api.delayedUpdate!.complete(api.payment(api.creates.single, api.updates.last, null));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const ValueKey('checkout-menu')), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('menu-payment-view')), findsNothing);
    expect(find.text('PAY: 60,000 VND'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

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
      expect(api.updates.single.single.quantity, 2);
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('RETRY'), findsNothing);
      expect(api.updates, hasLength(1));
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
      expect(tester.widget<QrTransition>(find.byType(QrTransition)).paymentQr, isNull);
      expect(find.text('Pay cash at counter'), findsOneWidget);
      await tapVisible(tester, find.text('PAY BY QR INSTEAD'));
      expect(find.byType(QrImageView), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('checkout-menu')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('PAY: 20,000 VND'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('menu-pay')));
      await tester.pumpAndSettle();
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
    final surface = find.byKey(const ValueKey('menu-item-surface-cola'), skipOffstage: false);
    final selectedColor = tester.widget<Material>(surface).color!;
    expect(selectedColor, isNot(Colors.transparent));
    expect(selectedColor.a, lessThan(0.12));
    await tapVisible(tester, find.text('REMOVE'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(api.cancellations, [api.creates.single]);
    expect(api.statusRequests, 0);
    expect(find.byKey(const ValueKey('menu-payment-view')), findsNothing);
    expectPayDisabled(tester);
    expect(tester.widget<Material>(surface).color, Colors.transparent);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('minus on quantity one cancels the empty cart', (tester) async {
    final api = CheckoutApi();
    await openCart(tester, api);
    await tapVisible(tester, find.byIcon(Icons.remove));
    expect(api.cancellations, [api.creates.single]);
    expect(find.byKey(const ValueKey('menu-payment-view')), findsNothing);
    expectPayDisabled(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('slow cancellation has no deadline and no follow-up status call', (
    tester,
  ) async {
    final api = CheckoutApi()..delayedCancel = Completer();
    await openCart(tester, api);
    await tapVisible(tester, find.text('REMOVE'));
    await tester.pump(const Duration(seconds: 20));
    expect(find.byKey(const ValueKey('menu-payment-view')), findsOneWidget);
    expect(find.text('RETRY'), findsNothing);
    expect(api.cancellations, hasLength(1));
    api.delayedCancel!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('menu-payment-view')), findsNothing);
    expect(api.statusRequests, 0);
    expectPayDisabled(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed cancellation stays open and retries the same payment', (
    tester,
  ) async {
    final api = CheckoutApi();
    await openCart(tester, api);
    api.failCancel = true;
    await tapVisible(tester, find.text('REMOVE'));
    expect(find.byKey(const ValueKey('menu-payment-view')), findsOneWidget);
    expect(find.text('Network error'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byKey(const ValueKey('menu-payment-view')), findsOneWidget);
    api.failCancel = false;
    await tapVisible(tester, find.text('RETRY'));
    expect(api.cancellations, [api.creates.single, api.creates.single]);
    expect(find.byKey(const ValueKey('menu-payment-view')), findsNothing);
    expectPayDisabled(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('payment confirmation during deletion preserves the paid cart', (
    tester,
  ) async {
    final api = CheckoutApi();
    await openCart(tester, api);
    api.paidDuringCancel = true;
    await tapVisible(tester, find.text('REMOVE'));
    expect(find.text('✓ PAYMENT CONFIRMED'), findsOneWidget);
    expect(find.text('Cola'), findsOneWidget);
    expect(find.text('Cola × 1'), findsNothing);
    expect(find.text('Cola × 1', skipOffstage: false), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(api.statusRequests, 1);
    final remove = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'REMOVE'),
    );
    expect(remove.onPressed, isNull);
    await tapVisible(tester, find.byKey(const ValueKey('checkout-menu')));
    expectPayDisabled(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('deletion uses item identity after another row is removed', (
    tester,
  ) async {
    final api = CheckoutApi();
    await openCart(tester, api);
    await tapVisible(tester, find.byKey(const ValueKey('checkout-menu')));
    await tapVisible(tester, find.text('Coffee'));
    await tapVisible(tester, find.byKey(const ValueKey('menu-pay')));
    final buttons = find.widgetWithText(TextButton, 'REMOVE');
    api.delayedUpdate = Completer();
    final removeCola = tester.widget<TextButton>(buttons.first).onPressed!;
    final removeCoffee = tester.widget<TextButton>(buttons.last).onPressed!;
    removeCola();
    // The request starts in the same turn; closing cannot leave a delayed edit.
    expect(api.updates.last.single.itemId, 'coffee');
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byKey(const ValueKey('menu-payment-view')), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    api.delayedUpdate!.complete(
      api.payment(api.creates.single, api.updates.last, null),
    );
    await tester.pump();
    expect(find.text('PAY 45,000 VND'), findsOneWidget);
    removeCola(); // A stale callback cannot remove the remaining row.
    expect(api.cancellations, isEmpty);
    removeCoffee();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(api.cancellations, [api.creates.single]);
    expect(find.byKey(const ValueKey('menu-payment-view')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('system back closes the sheet and preserves the selected cart', (
    tester,
  ) async {
    final api = CheckoutApi();
    await openCart(tester, api);
    final reference = api.current!.paymentMessage;
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('menu-payment-view')), findsNothing);
    expect(find.byKey(const ValueKey('menu-pay')), findsOneWidget);
    expect(
      tester.widget<Material>(
        find.byKey(const ValueKey('menu-item-surface-cola')),
      ).color,
      isNot(Colors.transparent),
    );
    await tapVisible(tester, find.byKey(const ValueKey('menu-pay')));
    expect(api.creates, hasLength(1));
    expect(api.current!.paymentMessage, reference);
    expect(find.byType(QrImageView), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tapping anywhere on a menu row adds to the same pending cart', (
    tester,
  ) async {
    final api = CheckoutApi();
    await openCart(tester, api);
    final reference = api.current!.paymentMessage;
    await tapVisible(tester, find.byKey(const ValueKey('checkout-menu')));
    final row = find.byKey(const ValueKey('menu-item-cola'));
    final bounds = tester.getRect(row);
    expect(bounds.width, greaterThan(200));
    expect(bounds.height, greaterThanOrEqualTo(72));
    expect(find.text('ADD'), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.remove), findsNothing);
    await tester.tapAt(Offset(bounds.right - 8, bounds.center.dy));
    await tester.pump();
    expect(find.text('PAY: 60,000 VND'), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('menu-pay')));
    expect(api.creates, hasLength(1));
    expect(api.updates.last.single.quantity, 2);
    expect(api.current!.paymentMessage, reference);
    expect(find.text('PAY 60,000 VND'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('menu counter and right 30 percent REMOVE reduce exactly one unit', (tester) async {
    final api = CheckoutApi();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: MenuScreen(
      localization: LocalizationController(AppLanguage.en), onBack: () {}, api: api)));
    await tester.pumpAndSettle();
    final add = find.byKey(const ValueKey('menu-item-cola'));
    await tapVisible(tester, add);
    await tapVisible(tester, add);
    expect(find.text('Cola × 2'), findsOneWidget);
    final remove = find.byKey(const ValueKey('menu-remove-cola'));
    expect(tester.getSize(add).width / tester.getSize(remove).width, closeTo(7 / 3, 0.01));
    expect(tester.getRect(remove).left, closeTo(tester.getRect(add).right, 0.01));
    final rail = tester.getRect(find.byKey(const ValueKey('menu-pay-bar')));
    expect(rail.right, closeTo(390, 1));
    expect(rail.left, 0);
    expect(rail.width, 390);
    expect(rail.height, 56);
    expect(rail.top, tester.getRect(find.byKey(const ValueKey('menu-app-bar'))).bottom);
    await tapVisible(tester, remove);
    expect(find.text('Cola × 1'), findsOneWidget);
    expect(find.text('PAY: 30,000 VND'), findsOneWidget);
    await tapVisible(tester, remove);
    expect(find.text('Cola'), findsOneWidget);
    expect(remove, findsNothing);
    expectPayDisabled(tester);
    expect(api.creates, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('menu REMOVE preserves canonical session and promo then cancels last unit', (tester) async {
    final api = CheckoutApi()..canonicalToken = 'canonical-menu-removal';
    await openCart(tester, api);
    await tapVisible(tester, find.byIcon(Icons.add));
    await tapVisible(tester, find.text('SAVE10'));
    await tapVisible(tester, find.byKey(const ValueKey('checkout-menu')));
    await tapVisible(tester, find.byKey(const ValueKey('menu-remove-cola')));
    await tester.pumpAndSettle();
    expect(find.text('Cola × 1'), findsOneWidget);
    expect(find.text('PAY: 20,000 VND'), findsOneWidget);
    expect(api.updateTokens, everyElement(api.canonicalToken));
    expect(api.updates.last.single.quantity, 1);
    expect(api.creates, hasLength(1));
    await tapVisible(tester, find.byKey(const ValueKey('menu-remove-cola')));
    await tester.pumpAndSettle();
    expect(api.cancellations, [api.canonicalToken]);
    expectPayDisabled(tester);
    expect(find.text('Cola'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('menu REMOVE cannot discard a failed cancellation', (tester) async {
    final api = CheckoutApi();
    await openCart(tester, api);
    await tapVisible(tester, find.byKey(const ValueKey('checkout-menu')));
    api.failCancel = true;
    await tapVisible(tester, find.byKey(const ValueKey('menu-remove-cola')));
    await tester.drag(find.byKey(const ValueKey('checkout-menu')), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('menu-payment-view')), findsOneWidget);
    expect(find.text('Network error'), findsOneWidget);
    api.failCancel = false;
    await tapVisible(tester, find.text('RETRY'));
    await tester.pumpAndSettle();
    expectPayDisabled(tester);
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
