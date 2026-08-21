import 'package:flutter/material.dart';

class BrandPalette {
  BrandPalette._();

  static const Color brown = Color(0xFF352822);
  static const Color brownDeep = Color(0xFF2B1F1A);
  static const Color brownLift = Color(0xFF3D2E27);
  static const Color cream = Color(0xFFE7D2C0);
  static const Color creamMuted = Color(0xFFBFA795);
  static const Color creamFaint = Color(0xFF80685A);
}

class BrandPaper extends StatelessWidget {
  const BrandPaper({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: const BrandPaperPainter(),
        child: child,
      ),
    );
  }
}

class BrandPaperPainter extends CustomPainter {
  const BrandPaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final rect = Offset.zero & size;

    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF30221D),
          BrandPalette.brown,
          Color(0xFF3A2A23),
          Color(0xFF31231E),
        ],
        stops: [0.0, 0.34, 0.72, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    _paintBloom(
      canvas,
      size,
      center: Offset(size.width * 0.84, size.height * 0.10),
      radius: size.width * 0.72,
      inner: const Color(0x2A4A372D),
      outer: const Color(0x002B1F1A),
    );
    _paintBloom(
      canvas,
      size,
      center: Offset(size.width * 0.10, size.height * 0.42),
      radius: size.width * 0.90,
      inner: const Color(0x18241613),
      outer: const Color(0x003D2E27),
    );
    _paintBloom(
      canvas,
      size,
      center: Offset(size.width * 0.80, size.height * 0.72),
      radius: size.width * 0.88,
      inner: const Color(0x203F3028),
      outer: const Color(0x002B1F1A),
    );
    _paintBloom(
      canvas,
      size,
      center: Offset(size.width * 0.22, size.height * 0.92),
      radius: size.width * 0.74,
      inner: const Color(0x18271915),
      outer: const Color(0x003D2E27),
    );

    final bandPaint = Paint()..color = const Color(0x071C110E);
    final bandCount = (size.height / 430).ceil();
    for (var i = 0; i < bandCount; i++) {
      final y = (i * 430.0) + (_unit(i, 17) * 120.0);
      final height = 18.0 + (_unit(i, 29) * 28.0);
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, height),
        bandPaint,
      );
    }

    final fiberLight = Paint()
      ..color = const Color(0x0DE7D2C0)
      ..strokeWidth = 0.55;
    final fiberDark = Paint()
      ..color = const Color(0x10160E0B)
      ..strokeWidth = 0.7;

    final fiberCount = (size.height / 54).ceil();
    for (var i = 0; i < fiberCount; i++) {
      final y = (i * 54.0) + (_unit(i, 41) * 19.0);
      final drift = (_unit(i, 73) - 0.5) * 10.0;
      final paint = i.isEven ? fiberLight : fiberDark;
      canvas.drawLine(
        Offset(-22, y),
        Offset(size.width + 22, y + drift),
        paint,
      );
    }

    final fleckLight = Paint()..color = const Color(0x10E7D2C0);
    final fleckDark = Paint()..color = const Color(0x14160E0B);
    final rows = (size.height / 76).ceil();
    final cols = (size.width / 88).ceil();

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final seed = (row * 131) + (col * 17);
        final x = (col * 88.0) + (_unit(seed, 11) * 44.0);
        final y = (row * 76.0) + (_unit(seed, 53) * 38.0);
        final radius = 0.45 + (_unit(seed, 97) * 0.8);
        canvas.drawCircle(
          Offset(x, y),
          radius,
          (seed % 3 == 0) ? fleckLight : fleckDark,
        );
      }
    }

    final edgePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0x25201512),
          Color(0x001A100D),
          Color(0x001A100D),
          Color(0x25201512),
        ],
        stops: [0.0, 0.08, 0.92, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, edgePaint);
  }

  void _paintBloom(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double radius,
    required Color inner,
    required Color outer,
  }) {
    final shaderRect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [inner, outer],
      ).createShader(shaderRect);
    canvas.drawCircle(center, radius, paint);
  }

  double _unit(int value, int salt) {
    final hashed = ((value + 1) * 1103515245 + salt * 12345) & 0x7fffffff;
    return (hashed % 10000) / 10000.0;
  }

  @override
  bool shouldRepaint(covariant BrandPaperPainter oldDelegate) => false;
}
