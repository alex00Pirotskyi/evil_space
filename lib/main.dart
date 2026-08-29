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
    return AnimatedBuilder(
      animation: _localization,
      builder: (context, _) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Evil Space Daily',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: BrandPalette.paper,
          colorScheme: const ColorScheme.light(
            surface: BrandPalette.paper,
            onSurface: BrandPalette.ink,
            primary: BrandPalette.ink,
            onPrimary: BrandPalette.paperLift,
            outline: BrandPalette.ink,
            outlineVariant: BrandPalette.rule,
          ),
          splashFactory: NoSplash.splashFactory,
          focusColor: BrandPalette.inkFaint,
          highlightColor: Colors.transparent,
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: BrandPalette.ink,
            selectionColor: Color(0x55AAA79D),
            selectionHandleColor: BrandPalette.ink,
          ),
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: BrandPalette.ink,
            contentTextStyle: TextStyle(color: BrandPalette.paperLift),
          ),
        ),
        routerDelegate: _routerDelegate,
        routeInformationParser: const EvilSpaceRouteParser(),
      ),
    );
  }
}
