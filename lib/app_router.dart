import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:evil_space/admin_portal.dart';
import 'package:evil_space/app_route.dart';
import 'package:evil_space/app_shell.dart';
import 'package:evil_space/localization.dart';

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
  EvilSpaceRouterDelegate({required this.localization}) {
    localization.addListener(_handleLocalizationChanged);
  }

  final LocalizationController localization;
  AppRoute _currentRoute = AppRoute.home;

  AppRoute get currentRoute => _currentRoute;

  void navigate(AppRoute route) {
    if (_currentRoute == route) {
      return;
    }
    _currentRoute = route;
    notifyListeners();
  }

  void _handleLocalizationChanged() {
    notifyListeners();
  }

  @override
  AppRoute get currentConfiguration => _currentRoute;

  @override
  Widget build(BuildContext context) {
    final Page<void> activePage;

    if (_currentRoute == AppRoute.admin) {
      activePage = MaterialPage<void>(
        key: const ValueKey('admin'),
        name: AppRoute.admin.path,
        child: AdminPortal(onExit: () => navigate(AppRoute.home)),
      );
    } else {
      final publicRoute =
          _currentRoute == AppRoute.qr ? AppRoute.qr : AppRoute.home;
      activePage = MaterialPage<void>(
        key: ValueKey('public-${publicRoute.path}'),
        name: publicRoute.path,
        child: DailyScreen(
          currentRoute: publicRoute,
          localization: localization,
          onNavigate: navigate,
        ),
      );
    }

    return Navigator(
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
  Future<bool> popRoute() {
    if (_currentRoute == AppRoute.home) {
      return SynchronousFuture(false);
    }
    navigate(AppRoute.home);
    return SynchronousFuture(true);
  }

  @override
  void dispose() {
    localization.removeListener(_handleLocalizationChanged);
    super.dispose();
  }
}
