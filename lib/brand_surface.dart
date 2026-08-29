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
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: const BrandPaperPainter()),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class BrandPaperPainter extends CustomPainter {
  const BrandPaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = BrandPalette.paper);

    final fiberLight = Paint()
      ..color = const Color(0x16FFFFFF)
      ..strokeWidth = 0.6;
    final fiberDark = Paint()
      ..color = const Color(0x0D1C1C1A)
      ..strokeWidth = 0.55;
    final fiberCount = (size.height / 46).ceil();
    for (var i = 0; i < fiberCount; i++) {
      final y = (i * 46.0) + (_unit(i, 41) * 15.0);
      final drift = (_unit(i, 73) - 0.5) * 7.0;
      canvas.drawLine(
        Offset(-22, y),
        Offset(size.width + 22, y + drift),
        i.isEven ? fiberLight : fiberDark,
      );
    }

    final fleckLight = Paint()..color = const Color(0x24FFFFFF);
    final fleckDark = Paint()..color = const Color(0x121C1C1A);
    final rows = (size.height / 70).ceil();
    final cols = (size.width / 76).ceil();
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final seed = (row * 131) + (col * 17);
        final x = (col * 76.0) + (_unit(seed, 11) * 38.0);
        final y = (row * 70.0) + (_unit(seed, 53) * 34.0);
        final radius = 0.32 + (_unit(seed, 97) * 0.52);
        canvas.drawCircle(
          Offset(x, y),
          radius,
          seed % 3 == 0 ? fleckLight : fleckDark,
        );
      }
    }

    final edge = Paint()
      ..color = const Color(0x101C1C1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(rect.deflate(0.5), edge);
  }

  double _unit(int value, int salt) {
    final hashed = ((value + 1) * 1103515245 + salt * 12345) & 0x7fffffff;
    return (hashed % 10000) / 10000.0;
  }

  @override
  bool shouldRepaint(covariant BrandPaperPainter oldDelegate) => false;
}
