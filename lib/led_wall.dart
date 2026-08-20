import 'dart:math' as math;

import 'package:flutter/material.dart';

class LedWallGeometry {
  LedWallGeometry._();

  static double safePitch(double pitch) => pitch.clamp(2.0, 12.0).toDouble();

  static double emitterRadius(double pitch) {
    final safe = safePitch(pitch);
    return (safe * 0.34).clamp(0.75, 3.7).toDouble();
  }

  static double socketRadius(double pitch) {
    final safe = safePitch(pitch);
    return (safe * 0.46).clamp(1.0, 5.0).toDouble();
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

  static Offset cellCenter({
    required int column,
    required int row,
    required double cellWidth,
    required double cellHeight,
  }) {
    return Offset(
      (column + 0.5) * cellWidth,
      (row + 0.5) * cellHeight,
    );
  }

  static double snap(double value, double pitch) {
    final safe = safePitch(pitch);
    return (value / safe).round() * safe;
  }
}

class LedWallPainter {
  LedWallPainter._();

  static void drawEmitter(
    Canvas canvas, {
    required Offset center,
    required double pitch,
    required Color color,
    bool socket = false,
    bool glow = false,
    double glowStrength = 0.55,
  }) {
    final safePitch = LedWallGeometry.safePitch(pitch);
    final emitterRadius = LedWallGeometry.emitterRadius(safePitch);

    if (socket) {
      final socketPaint = Paint()
        ..isAntiAlias = true
        ..color = const Color(0xF2000000);
      canvas.drawCircle(
        center,
        LedWallGeometry.socketRadius(safePitch),
        socketPaint,
      );
    }

    if (glow) {
      final glowPaint = Paint()
        ..isAntiAlias = true
        ..color = color.withValues(alpha: glowStrength.clamp(0.0, 1.0))
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(1.4, safePitch * 0.72),
        );
      canvas.drawCircle(center, emitterRadius * 1.18, glowPaint);
    }

    final emitterPaint = Paint()
      ..isAntiAlias = true
      ..color = color;
    canvas.drawCircle(center, emitterRadius, emitterPaint);

    final corePaint = Paint()
      ..isAntiAlias = true
      ..color = Color.fromARGB(
        (color.a * 0.22).round(),
        255,
        255,
        255,
      );
    canvas.drawCircle(
      center.translate(-emitterRadius * 0.20, -emitterRadius * 0.20),
      math.max(0.35, emitterRadius * 0.23),
      corePaint,
    );
  }
}
