import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:evil_space/app_router.dart';
import 'package:evil_space/brand_surface.dart';
import 'package:evil_space/localization.dart';
import 'package:evil_space/persistent_localization.dart';

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
      title: 'Evil Space Daily',
      theme: _theme,
      builder: (context, child) => ListenableBuilder(
        listenable: _localization,
        child: child ?? const SizedBox.shrink(),
        builder: (context, child) => _FirstVisitLanguageGate(
          localization: _localization,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      routerDelegate: _routerDelegate,
      routeInformationParser: const EvilSpaceRouteParser(),
    );
  }
}

class _FirstVisitLanguageGate extends StatelessWidget {
  const _FirstVisitLanguageGate({
    required this.localization,
    required this.child,
  });

  final PersistentLocalizationController localization;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (localization.hasSavedLanguage) return child;

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        const ModalBarrier(
          dismissible: false,
          color: Color(0x99000000),
        ),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Material(
                color: BrandPalette.paper,
                shape: const RoundedRectangleBorder(
                  side: BorderSide(color: BrandPalette.ink, width: 1.5),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'CHOOSE LANGUAGE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: BrandPalette.ink,
                            fontFamily: 'Georgia',
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'ВЫБЕРИТЕ ЯЗЫК  ·  CHỌN NGÔN NGỮ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: BrandPalette.inkMuted,
                            fontFamily: 'Courier New',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _languageButton('ENGLISH', AppLanguage.en),
                        const SizedBox(height: 9),
                        _languageButton('РУССКИЙ', AppLanguage.ru),
                        const SizedBox(height: 9),
                        _languageButton('TIẾNG VIỆT', AppLanguage.vi),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _languageButton(String label, AppLanguage language) {
    return OutlinedButton(
      onPressed: () => localization.setLanguage(language),
      style: OutlinedButton.styleFrom(
        foregroundColor: BrandPalette.ink,
        backgroundColor: BrandPalette.paperLift,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: BrandPalette.ink),
        shape: const RoundedRectangleBorder(),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: BrandPalette.ink,
          fontFamily: 'Courier New',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
