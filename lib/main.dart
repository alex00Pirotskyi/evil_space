import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:evil_space/app_router.dart';
import 'package:evil_space/chunked_eink_asset_bundle.dart';
import 'package:evil_space/eink_image.dart';
import 'package:evil_space/localization.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  runApp(
    DefaultAssetBundle(
      bundle: ChunkedEInkAssetBundle(rootBundle),
      child: const EvilSpaceApp(),
    ),
  );
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
      title: 'Evil Space Coworking',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: EInkPalette.paper,
        colorScheme: const ColorScheme.light(
          surface: EInkPalette.paper,
          onSurface: EInkPalette.ink,
          primary: EInkPalette.ink,
          onPrimary: EInkPalette.paper,
        ),
        splashFactory: NoSplash.splashFactory,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: EInkPalette.ink,
          selectionColor: Color(0x5577736A),
          selectionHandleColor: EInkPalette.ink,
        ),
      ),
      routerDelegate: _routerDelegate,
      routeInformationParser: const EvilSpaceRouteParser(),
    );
  }
}
