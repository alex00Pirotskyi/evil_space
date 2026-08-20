import 'dart:math' as math;

import 'package:flutter/material.dart';

class LedWallGeometry {
  LedWallGeometry._();

  static double safePitch(double pitch) => pitch.clamp(3.0, 10.0).toDouble();

  static double inset(double pitch) {
    final safe = safePitch(pitch);
    return (safe * 0.13).clamp(0.45, 1.15).toDouble();
  }

  static double radius(double pitch) {
    final safe = safePitch(pitch);
    return (safe * 0.16).clamp(0.45, 1.35).toDouble();
  }

  static int columnsFor(double width, double pitch, {int minimum = 1}) {
    if (!width.isFinite || width <= 0) {
      return minimum;
    }
    return math.max(minimum, (width / safePitch(pitch)).round()).toInt();
  }

  static int rowsFor(double height, double pitch, {int minimum = 1}) {
    if (!height.isFinite || height <= 0) {
      return minimum;
    }
    return math.max(minimum, (height / safePitch(pitch)).round()).toInt();
  }

  static Rect ledRect({
    required int column,
    required int row,
    required double cellWidth,
    required double cellHeight,
  }) {
    final pitch = math.min(cellWidth, cellHeight);
    final gap = inset(pitch);
    return Rect.fromLTWH(
      (column * cellWidth) + gap,
      (row * cellHeight) + gap,
      math.max(0.5, cellWidth - (gap * 2)),
      math.max(0.5, cellHeight - (gap * 2)),
    );
  }

  static double snap(double value, double pitch) {
    final safe = safePitch(pitch);
    return (value / safe).round() * safe;
  }
}

class LedWallPainter {
  LedWallPainter._();

  static void drawLed(
    Canvas canvas,
    Rect rect,
    Color color, {
    bool glow = false,
    double glowSigma = 2.2,
  }) {
    final radius = Radius.circular(
      (math.min(rect.width, rect.height) * 0.16).clamp(0.4, 1.4).toDouble(),
    );

    if (glow) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.72)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowSigma);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), glowPaint);
    }

    final paint = Paint()
      ..isAntiAlias = false
      ..color = color;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
  }
}
