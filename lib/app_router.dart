import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:evil_space/admin_portal.dart' deferred as admin_portal;
import 'package:evil_space/app_route.dart';
import 'package:evil_space/app_shell.dart';
import 'package:evil_space/localization.dart';
import 'package:evil_space/public_telegram_connector.dart';

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
  EvilSpaceRouterDelegate({required this.localization});

  final LocalizationController localization;
  AppRoute _currentRoute = AppRoute.home;

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

    if (_currentRoute == AppRoute.admin) {
      activePage = MaterialPage<void>(
        key: const ValueKey('admin'),
        name: AppRoute.admin.path,
        child: _DeferredAdminPortal(
          onExit: () => navigate(AppRoute.home),
          languageCode: localization.language.code,
        ),
      );
    } else {
      final publicRoute =
          _currentRoute == AppRoute.qr ? AppRoute.qr : AppRoute.home;
      activePage = MaterialPage<void>(
        key: ValueKey('public-${publicRoute.path}'),
        name: publicRoute.path,
        child: PublicTelegramConnector(
          localization: localization,
          child: DailyScreen(
            currentRoute: publicRoute,
            localization: localization,
            onNavigate: navigate,
          ),
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
