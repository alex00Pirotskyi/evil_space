import 'package:flutter/material.dart';

class BrandPalette {
  BrandPalette._();

  static const Color paper = Color(0xFFF2F0E8);
  static const Color paperDeep = Color(0xFFE7E4DA);
  static const Color paperLift = Color(0xFFF8F6EF);
  static const Color ink = Color(0xFF1C1C1A);
  static const Color inkMuted = Color(0xFF6F6D66);
  static const Color inkFaint = Color(0xFFAAA79D);
  static const Color rule = Color(0xFFC9C6BC);
}

class BrandPaper extends StatelessWidget {
  const BrandPaper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BrandPalette.paper,
      child: child,
    );
  }
}
