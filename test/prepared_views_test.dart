import 'dart:async';

import 'package:evil_space/app_route.dart';
import 'package:evil_space/app_router.dart';
import 'package:evil_space/brand_surface.dart';
import 'package:evil_space/localization.dart';
import 'package:evil_space/menu_api.dart';
import 'package:evil_space/menu_screen.dart';
import 'package:evil_space/prepared_view_layers.dart';
import 'package:evil_space/qr_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'menu_live_checkout_test.dart' show CheckoutApi, tapVisible, expectPayDisabled;

class PreparationApi extends CheckoutApi {
  int menuRequests = 0;
  Completer<MenuCatalog>? menuGate;
  Completer<MenuOrderPayment>? paymentGate;
  bool failMenu = false;

  @override
  Future<MenuCatalog> menu() async {
    menuRequests++;
    if (failMenu) throw const MenuApiException('Unavailable', statusCode: 500);
    return menuGate == null ? super.menu() : menuGate!.future;
  }

  Future<MenuCatalog> catalog() => super.menu();

  @override
  Future<MenuOrderPayment> createCartOrder(List<MenuCartRequestLine> cart,
      {int? promoGrantId, String? paymentToken}) async {
    final result = await super.createCartOrder(cart,
      promoGrantId: promoGrantId, paymentToken: paymentToken);
    return paymentGate == null ? result : paymentGate!.future;
  }
}

void main() {
  test('preview is deterministic; confirmed matrix preserves every QR cell', () {
    final first = QrMatrix.preview('cola:1');
    expect(QrMatrix.preview('cola:1').cells, orderedEquals(first.cells));
    expect(QrMatrix.preview('cola:2').cells, isNot(orderedEquals(first.cells)));
    final qr = PaymentQrData('confirmed:80000:EVIL ABC234');
    final image = QrImage(qr.code);
    for (var y = 0; y < image.moduleCount; y++) {
      for (var x = 0; x < image.moduleCount; x++) {
        expect(qr.matrix.cells[y * image.moduleCount + x], image.isDark(y, x) ? 1 : 0);
      }
    }
  });

  testWidgets('preload is shared; early navigation waits; menu retains state', (tester) async {
    final api = PreparationApi()..menuGate = Completer();
    final localization = LocalizationController();
    final router = EvilSpaceRouterDelegate(localization: localization, menuApi: api);
    await tester.pumpWidget(MaterialApp.router(routerDelegate: router,
      routeInformationParser: const EvilSpaceRouteParser()));
    await tester.pumpAndSettle();
    expect(api.menuRequests, 1);
    router.navigate(AppRoute.menu);
    await tester.pumpAndSettle();
    router.navigate(AppRoute.menu);
    await tester.pump();
    expect(find.text('01  /  COWORKING'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(api.menuRequests, 1);
    router.navigate(AppRoute.home);
    await tester.pump();
    api.menuGate!.complete(await api.catalog());
    await tester.pumpAndSettle();
    expect(find.byType(MenuScreen), findsNothing);
    expect(find.byType(MenuScreen, skipOffstage: false), findsOneWidget);
    expect(api.creates, isEmpty);
    router.navigate(AppRoute.menu);
    await tester.pumpAndSettle();
    final menuState = tester.state(find.byType(MenuScreen));
    await tapVisible(tester, find.byKey(const ValueKey('menu-item-cola')));
    final list = tester.widget<ListView>(find.byKey(const ValueKey('menu-list')));
    final offset = list.controller!.offset;
    router.navigate(AppRoute.home);
    await tester.pumpAndSettle();
    router.navigate(AppRoute.menu);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(MenuScreen)), same(menuState));
    expect(find.text('Cola × 1'), findsOneWidget);
    expect(list.controller!.offset, offset);
    expect(api.menuRequests, 1);
    expect(api.creates, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    localization.dispose();
  });

  testWidgets('PAY stays fixed; matrix updates leave no idle animation or hidden orders', (tester) async {
    final api = PreparationApi();
    await tester.pumpWidget(MaterialApp(home: MenuScreen(api: api,
      localization: LocalizationController(), onBack: () {})));
    await tester.pumpAndSettle();
    expectPayDisabled(tester);
    final pay = find.byKey(const ValueKey('menu-pay-bar'));
    final emptyBounds = tester.getRect(pay);
    Material surface() => tester.widget<Material>(find.ancestor(of: pay,
      matching: find.byType(Material)).first);
    expect(surface().color, BrandPalette.paperDeep);
    final before = tester.widget<QrTransition>(find.byType(QrTransition)).fingerprint;
    await tester.tap(find.byKey(const ValueKey('menu-item-cola')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 175));
    expect(surface().color, isNot(BrandPalette.paperDeep));
    expect(surface().color, isNot(BrandPalette.ink));
    await tester.tap(find.byKey(const ValueKey('menu-item-cola')));
    await tester.pumpAndSettle();
    expect(tester.getRect(pay), emptyBounds);
    expect(surface().color, BrandPalette.ink);
    expect(tester.widget<QrTransition>(find.byType(QrTransition)).fingerprint, isNot(before));
    expect(find.text('PAY: 60,000 VND'), findsOneWidget);
    expect(api.creates, isEmpty);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(api.statusRequests, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('slow payment stays on menu; repeated PAY creates one session', (tester) async {
    final api = PreparationApi()..paymentGate = Completer();
    await tester.pumpWidget(MaterialApp(home: MenuScreen(api: api,
      localization: LocalizationController(), onBack: () {})));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('menu-item-cola')));
    final pay = find.byKey(const ValueKey('menu-pay'));
    await tester.tap(pay);
    await tester.pumpAndSettle();
    await tester.tap(pay);
    await tester.pump(const Duration(seconds: 20));
    expect(api.creates, hasLength(1));
    expect(find.byKey(const ValueKey('menu-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-payment-view')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    api.paymentGate!.complete(api.current!);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('menu-list')), findsNothing);
    expect(find.byType(QrImageView), findsOneWidget);
    final code = tester.widget<QrImageView>(find.byType(QrImageView));
    final qr = tester.widget<QrTransition>(find.byType(QrTransition)).paymentQr!;
    expect(code.padding.left, code.size! * 4 / (qr.matrix.count + 8));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('transition frames do not rebuild either prepared page', (tester) async {
    final controller = AnimationController(vsync: tester,
      duration: const Duration(milliseconds: 400));
    var firstBuilds = 0;
    var secondBuilds = 0;
    await tester.pumpWidget(MaterialApp(home: PreparedViewLayers(controller: controller,
      first: Builder(builder: (_) { firstBuilds++; return const Text('home'); }),
      second: Builder(builder: (_) { secondBuilds++; return const Text('menu'); }))));
    final firstBefore = firstBuilds;
    final secondBefore = secondBuilds;
    unawaited(controller.forward());
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(firstBuilds, firstBefore);
    expect(secondBuilds, secondBefore);
    expect(find.text('home'), findsNothing);
    expect(find.text('menu'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
