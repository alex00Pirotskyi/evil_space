import 'package:flutter/material.dart';

import 'brand_surface.dart';

/// A quiet visual cue for the adjacent language buttons.
class LanguageIcon extends StatelessWidget {
  const LanguageIcon({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: SizedBox(
      width: 22,
      height: 18,
      child: CustomPaint(painter: _LanguageIconPainter()),
    ),
  );
}

class _LanguageIconPainter extends CustomPainter {
  const _LanguageIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 20);
    final pen = Paint()
      ..color = BrandPalette.inkMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final bubbles = Path()
      ..moveTo(8.5, 11)
      ..lineTo(6, 11)
      ..lineTo(3.5, 14)
      ..lineTo(3.5, 11)
      ..lineTo(3, 11)
      ..quadraticBezierTo(1, 11, 1, 9)
      ..lineTo(1, 3)
      ..quadraticBezierTo(1, 1, 3, 1)
      ..lineTo(12, 1)
      ..quadraticBezierTo(14, 1, 14, 3)
      ..lineTo(14, 5)
      ..moveTo(16, 7)
      ..lineTo(21, 7)
      ..quadraticBezierTo(23, 7, 23, 9)
      ..lineTo(23, 15)
      ..quadraticBezierTo(23, 17, 21, 17)
      ..lineTo(21, 19)
      ..lineTo(18.5, 17)
      ..lineTo(12, 17)
      ..quadraticBezierTo(10, 17, 10, 15)
      ..lineTo(10, 9)
      ..quadraticBezierTo(10, 7, 12, 7);
    canvas.drawPath(bubbles, pen);

    final letters = Path()
      // Latin A.
      ..moveTo(5, 8.5)
      ..lineTo(7.5, 3.5)
      ..lineTo(10, 8.5)
      ..moveTo(6, 6.5)
      ..lineTo(9, 6.5)
      // Japanese hiragana, drawn as strokes to avoid a font dependency.
      ..moveTo(13, 10)
      ..lineTo(19, 10)
      ..moveTo(15, 9)
      ..cubicTo(14.4, 11, 14.6, 13, 15.3, 14.5)
      ..moveTo(18, 11)
      ..cubicTo(17.2, 13.5, 14.3, 15.5, 13.3, 14.2)
      ..cubicTo(11.5, 11.8, 19, 10.4, 19.3, 13.2)
      ..cubicTo(19.5, 14.4, 18.7, 15, 17.7, 15);
    canvas.drawPath(letters, pen);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LanguageIconPainter oldDelegate) => false;
}
