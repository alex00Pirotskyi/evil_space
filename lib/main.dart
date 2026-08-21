import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:evil_space/app_router.dart';
import 'package:evil_space/brand_surface.dart';
import 'package:evil_space/localization.dart';

void main() {
  usePathUrlStrategy();
  runApp(const EvilSpaceApp());
}

class EvilSpaceApp extends StatefulWidget {
  const EvilSpaceApp({super.key});

  @override
  State<EvilSpaceApp> createState() => _EvilSpaceAppState();
}

class _EvilSpaceAppState extends State<EvilSpaceApp> {
  late final LocalizationController _localization;
  late final EvilSpaceRouterDelegate _routerDelegate;

  @override
  void initState() {
    super.initState();
    _localization = LocalizationController.fromPlatform();
    _routerDelegate = EvilSpaceRouterDelegate(localization: _localization);
  }

  @override
  void dispose() {
    _routerDelegate.dispose();
    _localization.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Evil Space Daily',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: BrandPalette.brown,
        colorScheme: const ColorScheme.dark(
          surface: BrandPalette.brown,
          onSurface: BrandPalette.cream,
          primary: BrandPalette.cream,
          onPrimary: BrandPalette.brown,
        ),
        splashFactory: NoSplash.splashFactory,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: BrandPalette.cream,
          selectionColor: Color(0x6680685A),
          selectionHandleColor: BrandPalette.cream,
        ),
      ),
      routerDelegate: _routerDelegate,
      routeInformationParser: const EvilSpaceRouteParser(),
    );
  }
}
