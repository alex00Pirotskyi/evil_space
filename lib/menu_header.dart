import 'package:flutter/material.dart';

import 'brand_logo.dart';
import 'brand_surface.dart';
import 'language_icon.dart';
import 'localization.dart';

const _headerOverlay = WidgetStateProperty<Color>.fromMap({
  WidgetState.disabled: Colors.transparent,
  WidgetState.pressed: Color(0x2E1C1C1A),
  WidgetState.hovered: Color(0x1F1C1C1A),
  WidgetState.focused: Color(0x2E1C1C1A),
  WidgetState.any: Colors.transparent,
});

/// Shared by the cold-start shell and the prepared menu/payment views.
class MenuHeader extends StatelessWidget {
  const MenuHeader({super.key, required this.localization,
    required this.onBack, this.payment = false});
  final LocalizationController localization;
  final VoidCallback onBack;
  final bool payment;

  TextStyle _type(double size) => TextStyle(fontFamily: 'Courier New',
    fontFamilyFallback: const ['monospace'], fontSize: size,
    fontWeight: FontWeight.w700, letterSpacing: 0.7, color: BrandPalette.ink);

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: localization,
    builder: (context, _) {
      final label = switch (localization.language) {
        AppLanguage.en => payment ? 'MENU' : 'BACK',
        AppLanguage.ru => payment ? 'МЕНЮ' : 'НАЗАД',
        AppLanguage.vi => payment ? 'THỰC ĐƠN' : 'QUAY LẠI',
      };
      return Container(key: const ValueKey('menu-app-bar'), height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: BrandPalette.ink))),
        child: Row(children: [
          const Expanded(child: Align(alignment: Alignment.centerLeft,
            child: EvilCoworkingLogo(width: 108))),
          const LanguageIcon(),
          const SizedBox(width: 6),
          for (final language in AppLanguage.values)
            TextButton(onPressed: () => localization.setLanguage(language),
              style: TextButton.styleFrom(foregroundColor: BrandPalette.ink,
                minimumSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                shape: const RoundedRectangleBorder(),
                side: localization.language == language
                  ? const BorderSide(color: BrandPalette.ink) : BorderSide.none)
                  .copyWith(overlayColor: _headerOverlay),
              child: Text(language.code.toUpperCase(), style: _type(9))),
          const SizedBox(width: 8),
          if (MediaQuery.sizeOf(context).width < 480)
            IconButton(tooltip: label, onPressed: onBack,
              style: const ButtonStyle(overlayColor: _headerOverlay),
              icon: const Icon(Icons.arrow_back, size: 18))
          else
            TextButton.icon(onPressed: onBack,
              style: const ButtonStyle(overlayColor: _headerOverlay),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(label, style: _type(10))),
        ]));
    });
}
