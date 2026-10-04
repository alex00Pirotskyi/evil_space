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
    tester.view.physicalSize = const Size(390, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    list.controller!.jumpTo(list.controller!.position.maxScrollExtent / 2);
    await tester.pump();
    final offset = list.controller!.offset;
    expect(offset, greaterThan(0));
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
      duration: preparedViewDuration);
    var firstBuilds = 0;
    var secondBuilds = 0;
    await tester.pumpWidget(MaterialApp(home: PreparedViewLayers(controller: controller,
      first: Builder(builder: (_) { firstBuilds++; return const Text('home'); }),
      second: Builder(builder: (_) { secondBuilds++; return const Text('menu'); }))));
    final firstBefore = firstBuilds;
    final secondBefore = secondBuilds;
    unawaited(controller.forward());
    for (var i = 0; i < 34; i++) {
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

  testWidgets('both directions overlap fades with a small fall and rise', (tester) async {
    final controller = AnimationController(vsync: tester,
      duration: preparedViewDuration);
    await tester.pumpWidget(MaterialApp(home: PreparedViewLayers(controller: controller,
      first: const Text('home'), second: const Text('menu'))));
    final home = find.text('home', skipOffstage: false);
    final menu = find.text('menu', skipOffstage: false);
    final restingTop = tester.getTopLeft(home).dy;
    expect(tester.getTopLeft(menu).dy, closeTo(restingTop + 8, 0.01));
    double opacity(Finder content) => tester.widget<FadeTransition>(
      find.ancestor(of: content, matching: find.byType(FadeTransition)).first).opacity.value;
    unawaited(controller.forward());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 225));
    expect(opacity(home), closeTo(0.5, 0.03));
    expect(opacity(menu), closeTo(0.5, 0.03));
    expect(tester.getTopLeft(home).dy, closeTo(restingTop + 4, 0.2));
    expect(tester.getTopLeft(menu).dy, closeTo(restingTop + 4, 0.2));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(menu).dy, restingTop);
    unawaited(controller.reverse());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 225));
    expect(opacity(home), closeTo(0.5, 0.03));
    expect(opacity(menu), closeTo(0.5, 0.03));
    expect(tester.getTopLeft(home).dy, closeTo(restingTop + 4, 0.2));
    expect(tester.getTopLeft(menu).dy, closeTo(restingTop + 4, 0.2));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(home).dy, restingTop);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('payment rise keeps bars anchored and QR settles before scanning', (tester) async {
    tester.view.physicalSize = const Size(390, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = PreparationApi()..paymentGate = Completer();
    await tester.pumpWidget(MaterialApp(home: MenuScreen(api: api,
      localization: LocalizationController(), onBack: () {})));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('menu-item-cola')));
    final header = find.byKey(const ValueKey('menu-app-bar'));
    final pay = find.byKey(const ValueKey('menu-pay-bar'), skipOffstage: false);
    final menu = find.byKey(const ValueKey('menu-list'), skipOffstage: false);
    final headerBounds = tester.getRect(header);
    final payBounds = tester.getRect(pay);
    final menuTop = tester.getTopLeft(menu).dy;
    await tester.tap(find.byKey(const ValueKey('menu-pay')));
    await tester.pumpAndSettle();
    api.paymentGate!.complete(api.current!);
    for (var i = 0; i < 10; i++) {
      await tester.pump();
      if (tester.widget<QrTransition>(find.byType(QrTransition)).paymentQr != null) break;
    }
    await tester.pump();
    final qr = tester.widget<QrTransition>(find.byType(QrTransition));
    expect(qr.paymentQr, isNotNull);
    final slot = find.byKey(qr.slotKey, skipOffstage: false);
    await tester.pump(const Duration(milliseconds: 225));
    final risingQrTop = tester.getTopLeft(slot).dy;
    expect(tester.getRect(header), headerBounds);
    expect(tester.getRect(pay), payBounds);
    expect(tester.getTopLeft(menu).dy, closeTo(menuTop + 4, 0.2));
    final returnMenu = find.byKey(const ValueKey('checkout-menu'));
    expect(tester.getRect(returnMenu).top, payBounds.top);
    expect(tester.getRect(returnMenu).height, payBounds.height);
    await tester.pumpAndSettle();
    final settledQrBounds = tester.getRect(slot);
    expect(risingQrTop, closeTo(settledQrBounds.top + 4, 0.2));
    await tester.pump(const Duration(seconds: 5));
    expect(tester.getRect(slot), settledQrBounds);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.tap(returnMenu);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 225));
    expect(tester.getRect(header), headerBounds);
    expect(tester.getRect(pay), payBounds);
    expect(tester.getTopLeft(menu).dy, closeTo(menuTop + 4, 0.2));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(menu).dy, menuTop);
    expect(find.text('Cola × 1'), findsOneWidget);
    expect(api.creates, hasLength(1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed preparation retries the same payment token inline', (tester) async {
    final api = PreparationApi()..failCreate = true;
    await tester.pumpWidget(MaterialApp(home: MenuScreen(api: api,
      localization: LocalizationController(), onBack: () {})));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('menu-item-cola')));
    await tapVisible(tester, find.byKey(const ValueKey('menu-pay')));
    expect(find.byKey(const ValueKey('menu-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('menu-payment-view')), findsNothing);
    expect(find.text('Network error'), findsOneWidget);
    final token = api.creates.single;
    api.failCreate = false;
    await tapVisible(tester, find.byKey(const ValueKey('prepare-payment-retry')));
    expect(api.creates, [token, token]);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('direct menu entry keeps its header during loading and fades in', (tester) async {
    final api = PreparationApi()..menuGate = Completer();
    final localization = LocalizationController();
    final router = EvilSpaceRouterDelegate(localization: localization, menuApi: api);
    final provider = PlatformRouteInformationProvider(initialRouteInformation:
      RouteInformation(uri: Uri.parse('/menu')));
    await tester.pumpWidget(MaterialApp.router(routerDelegate: router,
      routeInformationProvider: provider,
      routeInformationParser: const EvilSpaceRouteParser()));
    await tester.pumpAndSettle();
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('RU'), findsOneWidget);
    expect(find.text('VI'), findsOneWidget);
    expect(find.text('PAY: 0 VND'), findsOneWidget);
    expect(find.text('01  /  COWORKING'), findsNothing);
    final header = tester.getRect(find.byKey(const ValueKey('menu-app-bar')));
    api.menuGate!.complete(await api.catalog());
    await tester.pumpAndSettle();
    expect(find.byType(MenuScreen), findsOneWidget);
    expect(tester.getRect(find.byKey(const ValueKey('menu-app-bar'))), header);
    expect(api.menuRequests, 1);
    expect(api.creates, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
    router.dispose();
    localization.dispose();
  });

  testWidgets('hidden payment pauses polling and resumes when revisited', (tester) async {
    final api = PreparationApi();
    final localization = LocalizationController();
    final router = EvilSpaceRouterDelegate(localization: localization, menuApi: api);
    await tester.pumpWidget(MaterialApp.router(routerDelegate: router,
      routeInformationParser: const EvilSpaceRouteParser()));
    await tester.pumpAndSettle();
    router.navigate(AppRoute.menu);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('menu-item-cola')));
    await tapVisible(tester, find.byKey(const ValueKey('menu-pay')));
    router.navigate(AppRoute.home);
    await tester.pumpAndSettle();
    final before = api.statusRequests;
    await tester.pump(const Duration(seconds: 10));
    expect(api.statusRequests, before);
    router.navigate(AppRoute.menu);
    await tester.pumpAndSettle();
    expect(api.statusRequests, greaterThan(before));
    expect(api.creates, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    localization.dispose();
  });

  testWidgets('reduced motion reveals ready payment without animation frames', (tester) async {
    final api = PreparationApi();
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
      child: MenuScreen(api: api, localization: LocalizationController(), onBack: () {}))));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('menu-item-cola')));
    await tapVisible(tester, find.byKey(const ValueKey('menu-pay')));
    expect(find.byKey(const ValueKey('menu-list')), findsNothing);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
