import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:evil_space/app_router.dart';
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
  static const Color _paper = Color(0xFFF2F0E8);
  static const Color _ink = Color(0xFF171715);

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
        brightness: Brightness.light,
        scaffoldBackgroundColor: _paper,
        colorScheme: const ColorScheme.light(
          surface: _paper,
          onSurface: _ink,
          primary: _ink,
          onPrimary: _paper,
        ),
        splashFactory: NoSplash.splashFactory,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: _ink,
          selectionColor: Color(0x5577736A),
          selectionHandleColor: _ink,
        ),
      ),
      routerDelegate: _routerDelegate,
      routeInformationParser: const EvilSpaceRouteParser(),
    );
  }
}
