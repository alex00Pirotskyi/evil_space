import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:evil_space/app_router.dart';
import 'package:evil_space/brand_surface.dart';
import 'package:evil_space/persistent_localization.dart';

void main() {
  usePathUrlStrategy();
  runApp(const EvilSpaceApp());
  if (kIsWeb) {
    // Expose the same visible Flutter text to browsers and screen readers.
    SemanticsBinding.instance.ensureSemantics();
  }
}

class EvilSpaceApp extends StatefulWidget {
  const EvilSpaceApp({super.key});

  @override
  State<EvilSpaceApp> createState() => _EvilSpaceAppState();
}

class _EvilSpaceAppState extends State<EvilSpaceApp> {
  late final PersistentLocalizationController _localization;
  late final EvilSpaceRouterDelegate _routerDelegate;
  late final ThemeData _theme;

  @override
  void initState() {
    super.initState();
    _localization = PersistentLocalizationController.fromPlatform();
    _routerDelegate = EvilSpaceRouterDelegate(localization: _localization);
    _theme = ThemeData(
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
    );
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
      title: 'Evil Space | Coworking Space in Nha Trang',
      theme: _theme,
      routerDelegate: _routerDelegate,
      routeInformationParser: const EvilSpaceRouteParser(),
    );
  }
}
