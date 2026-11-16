import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'brand_surface.dart';
import 'prepared_view_layers.dart';

/// One encoding per confirmed payload; shared by the morph and final QR view.
class PaymentQrData {
  PaymentQrData(this.payload)
      : code = QrCode.fromData(data: payload,
          errorCorrectLevel: QrErrorCorrectLevel.L) {
    final image = QrImage(code);
    matrix = QrMatrix(image.moduleCount, Float32List.fromList([
      for (var row = 0; row < image.moduleCount; row++)
        for (var col = 0; col < image.moduleCount; col++)
          image.isDark(row, col) ? 1 : 0,
    ]));
  }
  final String payload;
  final QrCode code;
  late final QrMatrix matrix;
}

class QrMatrix {
  const QrMatrix(this.count, this.cells);
  final int count;
  final Float32List cells;

  /// Decorative only: no bank details, order reference or payment payload.
  factory QrMatrix.preview(String fingerprint) {
    var seed = 2166136261;
    for (final unit in fingerprint.codeUnits) {
      seed = ((seed ^ unit) * 16777619) & 0xffffffff;
    }
    const count = 37;
    final cells = Float32List(count * count);
    for (var i = 0; i < cells.length; i++) {
      seed ^= (seed << 13) & 0xffffffff;
      seed ^= seed >> 17;
      seed ^= (seed << 5) & 0xffffffff;
      seed &= 0xffffffff;
      cells[i] = (seed & 1).toDouble();
    }
    for (final origin in [(0, 0), (0, count - 7), (count - 7, 0)]) {
      for (var row = -1; row <= 7; row++) {
        for (var col = -1; col <= 7; col++) {
          final y = origin.$1 + row;
          final x = origin.$2 + col;
          if (x < 0 || y < 0 || x >= count || y >= count) continue;
          final dark = row >= 0 && row <= 6 && col >= 0 && col <= 6 &&
            (row == 0 || row == 6 || col == 0 || col == 6 ||
              row >= 2 && row <= 4 && col >= 2 && col <= 4);
          cells[y * count + x] = dark ? 1 : 0;
        }
      }
    }
    return QrMatrix(count, cells);
  }
}

class QrTransition extends StatefulWidget {
  const QrTransition({super.key, required this.fingerprint,
    required this.reveal, required this.slotKey, this.paymentQr,
    this.slotMotionPixels = 0});
  final String fingerprint;
  final AnimationController reveal;
  final GlobalKey slotKey;
  final PaymentQrData? paymentQr;
  final double slotMotionPixels;

  @override
  State<QrTransition> createState() => _QrTransitionState();
}

class _QrTransitionState extends State<QrTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _morph;
  late QrMatrix _from;
  late QrMatrix _to;
  late List<_CellPath> _paths;
  @override
  void initState() {
    super.initState();
    _morph = AnimationController(vsync: this, value: 1,
      duration: const Duration(milliseconds: 450));
    _from = _to = widget.paymentQr?.matrix ?? QrMatrix.preview(widget.fingerprint);
    _paths = _groupPaths(_from, _to);
  }

  @override
  void didUpdateWidget(covariant QrTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paymentQr?.payload == widget.paymentQr?.payload &&
        (widget.paymentQr != null || oldWidget.fingerprint == widget.fingerprint)) return;
    final next = widget.paymentQr?.matrix ?? QrMatrix.preview(widget.fingerprint);
    final progress = Curves.easeInOutCubic.transform(_morph.value);
    final captured = Float32List(next.cells.length);
    // Capture the visible frame when retargeting; rapid taps never queue morphs.
    for (var row = 0; row < next.count; row++) {
      for (var col = 0; col < next.count; col++) {
        final y = (row * _to.count / next.count).floor();
        final x = (col * _to.count / next.count).floor();
        final index = y * _to.count + x;
        captured[row * next.count + col] =
          _from.cells[index] * (1 - progress) + _to.cells[index] * progress;
      }
    }
    _from = QrMatrix(next.count, captured);
    _to = next;
    _paths = _groupPaths(_from, _to);
    if (MediaQuery.disableAnimationsOf(context) || !TickerMode.of(context) || widget.reveal.isCompleted) {
      _morph.value = 1;
    } else {
      _morph.duration = widget.paymentQr == null
        ? const Duration(milliseconds: 500) : const Duration(milliseconds: 420);
      _morph.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _morph.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: _QrTransitionPainter(
      paths: _paths, count: _to.count, morph: _morph,
      reveal: widget.reveal, hasPayment: widget.paymentQr != null)));
}

class _CellPath {
  _CellPath(this.from, this.to);
  final double from;
  final double to;
  final Path path = Path();
}

List<_CellPath> _groupPaths(QrMatrix from, QrMatrix to) {
  // At most 66 cached paths, rather than thousands of draw calls or widgets.
  final groups = <int, _CellPath>{};
  for (var i = 0; i < to.cells.length; i++) {
    final start = (from.cells[i] * 32).round();
    final end = to.cells[i].round();
    if (start == 0 && end == 0) continue;
    final key = start * 2 + end;
    final group = groups.putIfAbsent(key, () => _CellPath(start / 32, end.toDouble()));
    group.path.addRect(Rect.fromLTWH((i % to.count).toDouble(),
      (i ~/ to.count).toDouble(), 1, 1));
  }
  return groups.values.toList(growable: false);
}

/// A single fixed scan position shared by the ambient and confirmed QR.
///
/// Tablet checkout uses a centered 1060px content area and 5:4 columns.
/// This rectangle is independent of the reveal animation value.
Rect qrBackdropRect(Size size) {
  final side = math.min(300.0, math.min(size.width * 0.9,
    math.max(180.0, size.height + 68 - 208)));
  var centerX = size.width / 2;
  if (size.width >= 1024) {
    final sheetWidth = math.min(size.width, 1060.0);
    final panelWidth = math.max(0.0, sheetWidth - 44 - 28) * 5 / 9;
    centerX = (size.width - sheetWidth) / 2 + 22 + panelWidth / 2;
  }
  return Rect.fromLTWH(centerX - side / 2, 136, side, side);
}

class _QrTransitionPainter extends CustomPainter {
  _QrTransitionPainter({required this.paths, required this.count,
    required this.morph, required this.reveal, required this.hasPayment,
    })
      : super(repaint: Listenable.merge([morph, reveal]));
  final List<_CellPath> paths;
  final int count;
  final Animation<double> morph;
  final Animation<double> reveal;
  final bool hasPayment;

  @override
  void paint(Canvas canvas, Size size) {
    if (reveal.value >= 1) return; // Final real QR owns painting.
    final transition = preparedViewCurve.transform(reveal.value);

    // No interpolation to a new QR position: only contrast and cells evolve.
    final rect = qrBackdropRect(size);
    final handoff = const Interval(0.85, 1, curve: Curves.easeInOut)
      .transform(reveal.value);
    const menuContrast = 0.12;
    final opacity = hasPayment
      ? (menuContrast + (1 - menuContrast) * transition) * (1 - handoff)
      : menuContrast * (1 - transition);
    final paint = Paint()..isAntiAlias = false;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (hasPayment && transition > 0) {
      paint.color = Colors.white.withValues(alpha: transition * (1 - handoff));
      canvas.drawRect(rect, paint);
    }
    final unit = rect.width / (count + 8);
    canvas.translate(rect.left + 4 * unit, rect.top + 4 * unit);
    canvas.scale(unit);
    final progress = Curves.easeInOutCubic.transform(morph.value);
    for (final group in paths) {
      final alpha = (group.from * (1 - progress) + group.to * progress) * opacity;
      if (alpha <= 0) continue;
      paint.color = BrandPalette.ink.withValues(alpha: alpha);
      canvas.drawPath(group.path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _QrTransitionPainter oldDelegate) =>
      oldDelegate.paths != paths || oldDelegate.hasPayment != hasPayment ||
      oldDelegate.reveal != reveal;
}
