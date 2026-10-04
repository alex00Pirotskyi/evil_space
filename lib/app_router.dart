import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:evil_space/admin_menu_portal.dart' deferred as admin_menu_portal;
import 'package:evil_space/admin_portal.dart' deferred as admin_portal;
import 'package:evil_space/app_route.dart';
import 'package:evil_space/app_shell.dart';
import 'package:evil_space/localization.dart';
import 'package:evil_space/menu_api.dart';
import 'package:evil_space/menu_screen.dart' deferred as menu_screen;
import 'package:evil_space/public_telegram_connector.dart';
import 'package:evil_space/prepared_view_layers.dart';
import 'package:evil_space/menu_header.dart';
import 'package:evil_space/brand_surface.dart';

class EvilSpaceRouteParser extends RouteInformationParser<AppRoute> {
  const EvilSpaceRouteParser();

  @override
  Future<AppRoute> parseRouteInformation(RouteInformation routeInformation) {
    return SynchronousFuture(AppRoute.fromUri(routeInformation.uri));
  }

  @override
  RouteInformation restoreRouteInformation(AppRoute configuration) {
    return RouteInformation(uri: Uri(path: configuration.path));
  }
}

class EvilSpaceRouterDelegate extends RouterDelegate<AppRoute>
    with ChangeNotifier {
  EvilSpaceRouterDelegate({required this.localization, this.menuApi});

  final LocalizationController localization;
  final MenuApi? menuApi;
  AppRoute _currentRoute = AppRoute.home;
  final _navigatorKey = GlobalKey<NavigatorState>();

  AppRoute get currentRoute => _currentRoute;

  void navigate(AppRoute route) {
    if (_currentRoute == route) return;
    _currentRoute = route;
    notifyListeners();
  }

  @override
  AppRoute get currentConfiguration => _currentRoute;

  @override
  Widget build(BuildContext context) {
    final Page<void> activePage;

    if (_currentRoute == AppRoute.adminMenu) {
      activePage = MaterialPage<void>(
        key: const ValueKey('admin-menu'),
        name: AppRoute.adminMenu.path,
        child: _DeferredAdminMenuPortal(
          onBackToAdmin: () => navigate(AppRoute.admin),
          onExit: () => navigate(AppRoute.home),
        ),
      );
    } else if (_currentRoute == AppRoute.admin) {
      activePage = MaterialPage<void>(
        key: const ValueKey('admin'),
        name: AppRoute.admin.path,
        child: _AdminWithMenuButton(
          onOpenMenu: () => navigate(AppRoute.adminMenu),
          child: _DeferredAdminPortal(
            onExit: () => navigate(AppRoute.home),
            languageCode: localization.language.code,
          ),
        ),
      );
    } else {
      activePage = MaterialPage<void>(
        key: const ValueKey('public-shell'),
        name: _currentRoute.path,
        child: _PublicViews(
          route: _currentRoute,
          localization: localization,
          onNavigate: navigate,
          api: menuApi,
        ),
      );
    }

    return Navigator(
      key: _navigatorKey,
      pages: [activePage],
      onDidRemovePage: (_) {},
    );
  }

  @override
  Future<void> setNewRoutePath(AppRoute configuration) {
    _currentRoute = configuration;
    return SynchronousFuture<void>(null);
  }

  @override
  Future<bool> popRoute() async {
    // Let checkout, configuration and other in-page back handlers finish first.
    if (await _navigatorKey.currentState?.maybePop() ?? false) return true;
    if (_currentRoute == AppRoute.home) {
      return false;
    }
    if (_currentRoute == AppRoute.adminMenu) {
      navigate(AppRoute.admin);
      return true;
    }
    navigate(AppRoute.home);
    return true;
  }
}

class _PublicWithMenuButton extends StatefulWidget {
  const _PublicWithMenuButton({
    required this.localization,
    required this.onOpenMenu,
    required this.child,
    this.preparing = false,
    this.failed = false,
  });

  final LocalizationController localization;
  final VoidCallback onOpenMenu;
  final Widget child;
  final bool preparing;
  final bool failed;

  @override
  State<_PublicWithMenuButton> createState() => _PublicWithMenuButtonState();
}

class _PublicWithMenuButtonState extends State<_PublicWithMenuButton> {
  @override
  void initState() {
    super.initState();
    widget.localization.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant _PublicWithMenuButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localization != widget.localization) {
      oldWidget.localization.removeListener(_refresh);
      widget.localization.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.localization.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  String get _label {
    if (widget.failed) return switch (widget.localization.language) {
      AppLanguage.en => 'RETRY MENU', AppLanguage.ru => 'ПОВТОРИТЬ',
      AppLanguage.vi => 'THỬ LẠI',
    };
    switch (widget.localization.language) {
      case AppLanguage.ru:
        return 'МЕНЮ';
      case AppLanguage.vi:
        return 'THỰC ĐƠN';
      case AppLanguage.en:
        return 'MENU';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        Positioned(
          right: 14,
          bottom: 14,
          child: SafeArea(
            child: FloatingActionButton.extended(
              heroTag: 'public-menu',
              onPressed: widget.onOpenMenu,
              backgroundColor: const Color(0xFF1C1C1A),
              foregroundColor: const Color(0xFFF8F6EE),
              shape: const RoundedRectangleBorder(),
              icon: Icon(widget.failed ? Icons.refresh : widget.preparing
                  ? Icons.close : Icons.restaurant_menu, size: 18),
              label: Text(
                widget.preparing ? '$_label…' : _label,
                style: const TextStyle(
                  fontFamily: 'Courier New',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminWithMenuButton extends StatelessWidget {
  const _AdminWithMenuButton({required this.onOpenMenu, required this.child});

  final VoidCallback onOpenMenu;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          left: 14,
          bottom: 14,
          child: SafeArea(
            child: FloatingActionButton.extended(
              heroTag: 'admin-menu',
              onPressed: onOpenMenu,
              backgroundColor: const Color(0xFF1C1C1A),
              foregroundColor: const Color(0xFFF8F6EE),
              shape: const RoundedRectangleBorder(),
              icon: const Icon(Icons.restaurant_menu, size: 18),
              label: const Text(
                'MENU',
                style: TextStyle(
                  fontFamily: 'Courier New',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Keep the initial homepage frame independent of the deferred menu download.
class _PublicViews extends StatefulWidget {
  const _PublicViews({required this.route, required this.localization,
    required this.onNavigate, this.api});
  final AppRoute route;
  final LocalizationController localization;
  final ValueChanged<AppRoute> onNavigate;
  final MenuApi? api;
  @override
  State<_PublicViews> createState() => _PublicViewsState();
}

class _PublicViewsState extends State<_PublicViews>
    with SingleTickerProviderStateMixin {
  late final AnimationController _transition;
  late final MenuApi _api;
  MenuCatalog? _catalog;
  bool _preparing = false;
  bool _failed = false;
  bool _ready = false;
  late final bool _directMenu;
  bool _initialReveal = false;
  AppRoute _homeRoute = AppRoute.home;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? MenuApi();
    _directMenu = widget.route == AppRoute.menu;
    _initialReveal = _directMenu;
    _transition = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 400));
    _transition.addStatusListener((status) {
      if (status == AnimationStatus.completed && _initialReveal && mounted) {
        setState(() => _initialReveal = false);
      }
    });
    if (widget.route == AppRoute.qr) _homeRoute = AppRoute.qr;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_prepare());
    });
  }

  Future<void> _prepare() async {
    if (_preparing || _ready) return;
    setState(() { _preparing = true; _failed = false; });
    try {
      final prepared = await Future.wait<Object>([
        menu_screen.loadLibrary().then<Object>((_) => true), _api.menu(),
      ]);
      final catalog = prepared[1] as MenuCatalog;
      if (!mounted) return;
      setState(() { _catalog = catalog; });
      // The hidden page receives a layout pass before it can be revealed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() { _ready = true; _preparing = false; });
        _navigateView();
      });
    } catch (_) {
      if (mounted) setState(() { _failed = true; _preparing = false; });
    }
  }

  void _navigateView() {
    final showMenu = widget.route == AppRoute.menu && _ready;
    if (MediaQuery.disableAnimationsOf(context)) {
      _transition.value = showMenu ? 1 : 0;
    } else if (showMenu) {
      unawaited(_transition.forward());
    } else {
      unawaited(_transition.reverse());
    }
  }

  @override
  void didUpdateWidget(covariant _PublicViews oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.route != AppRoute.menu) {
      _homeRoute = widget.route;
      _initialReveal = false;
    }
    if (oldWidget.route != widget.route) _navigateView();
  }

  @override
  void dispose() {
    _transition.dispose();
    super.dispose();
  }

  void _menuAction() {
    if (_failed) {
      unawaited(_prepare());
      widget.onNavigate(AppRoute.menu);
      return;
    }
    widget.onNavigate(widget.route == AppRoute.menu && !_ready
      ? AppRoute.home : AppRoute.menu);
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.route == AppRoute.menu && !_ready;
    return ColoredBox(color: const Color(0xFFF2F0E8),
      child: PreparedViewLayers(controller: _transition,
        first: _PublicWithMenuButton(localization: widget.localization,
          onOpenMenu: _menuAction, preparing: pending && !_failed,
          failed: _failed,
          child: _initialReveal && widget.route == AppRoute.menu
            ? _MenuPreparationShell(localization: widget.localization,
                failed: _failed, onRetry: _menuAction,
                onBack: () => widget.onNavigate(AppRoute.home))
            : PublicTelegramConnector(localization: widget.localization,
            child: DailyScreen(currentRoute: _homeRoute,
              isActive: widget.route != AppRoute.menu || !_ready,
              localization: widget.localization, onNavigate: widget.onNavigate))),
        second: _catalog == null ? null : menu_screen.MenuScreen(
          key: const ValueKey('prepared-menu'), api: _api, initialMenu: _catalog,
          isActive: widget.route == AppRoute.menu && _ready,
          localization: widget.localization,
          onBack: () => widget.onNavigate(AppRoute.home))));
  }
}


class _MenuPreparationShell extends StatelessWidget {
  const _MenuPreparationShell({required this.localization,
    required this.failed, required this.onRetry, required this.onBack});
  final LocalizationController localization;
  final bool failed;
  final VoidCallback onRetry;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Material(color: BrandPalette.paper,
    child: ListenableBuilder(listenable: localization,
    builder: (context, _) => SafeArea(child: Column(children: [
      MenuHeader(localization: localization, onBack: onBack),
      SizedBox(height: 56, width: double.infinity,
        child: ColoredBox(color: BrandPalette.paperDeep,
          child: Center(child: Text('${switch (localization.language) {
            AppLanguage.en => 'PAY', AppLanguage.ru => 'ОПЛАТИТЬ',
            AppLanguage.vi => 'THANH TOÁN',
          }}: 0 VND', style: const TextStyle(fontFamily: 'Courier New',
            fontSize: 14, fontWeight: FontWeight.w700,
            letterSpacing: 0.7, color: BrandPalette.inkMuted))))),
      if (failed) TextButton(onPressed: onRetry,
        child: Text(switch (localization.language) {
          AppLanguage.ru => 'ПОВТОРИТЬ', AppLanguage.vi => 'THỬ LẠI',
          AppLanguage.en => 'RETRY MENU',
        })),
    ]))));

}

class _DeferredAdminPortal extends StatefulWidget {
  const _DeferredAdminPortal({
    required this.onExit,
    required this.languageCode,
  });

  final VoidCallback onExit;
  final String languageCode;

  @override
  State<_DeferredAdminPortal> createState() => _DeferredAdminPortalState();
}

class _DeferredAdminPortalState extends State<_DeferredAdminPortal> {
  late Future<void> _loader = admin_portal.loadLibrary();

  void _retry() {
    setState(() => _loader = admin_portal.loadLibrary());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loader,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.error == null) {
          return admin_portal.AdminPortal(
            onExit: widget.onExit,
            initialLanguageCode: widget.languageCode,
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF2F0E8),
            body: Center(
              child: OutlinedButton(
                onPressed: _retry,
                child: const Text('RETRY ADMIN'),
              ),
            ),
          );
        }

        return const Scaffold(
          backgroundColor: Color(0xFFF2F0E8),
          body: Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }
}

class _DeferredAdminMenuPortal extends StatefulWidget {
  const _DeferredAdminMenuPortal({
    required this.onBackToAdmin,
    required this.onExit,
  });

  final VoidCallback onBackToAdmin;
  final VoidCallback onExit;

  @override
  State<_DeferredAdminMenuPortal> createState() =>
      _DeferredAdminMenuPortalState();
}

class _DeferredAdminMenuPortalState extends State<_DeferredAdminMenuPortal> {
  late Future<void> _loader = admin_menu_portal.loadLibrary();

  void _retry() {
    setState(() => _loader = admin_menu_portal.loadLibrary());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loader,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.error == null) {
          return admin_menu_portal.AdminMenuPortal(
            onBackToAdmin: widget.onBackToAdmin,
            onExit: widget.onExit,
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF2F0E8),
            body: Center(
              child: OutlinedButton(
                onPressed: _retry,
                child: const Text('RETRY MENU ADMIN'),
              ),
            ),
          );
        }
        return const Scaffold(
          backgroundColor: Color(0xFFF2F0E8),
          body: Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }
}
