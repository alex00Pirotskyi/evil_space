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

class BrandPaper extends StatefulWidget {
  const BrandPaper({super.key, required this.child});

  final Widget child;

  @override
  State<BrandPaper> createState() => _BrandPaperState();
}

class _BrandPaperState extends State<BrandPaper> {
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0);

  @override
  void dispose() {
    _scrollOffset.dispose();
    super.dispose();
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.depth == 0 && notification.metrics.axis == Axis.vertical) {
      final nextOffset = notification.metrics.pixels;
      if (_scrollOffset.value != nextOffset) {
        _scrollOffset.value = nextOffset;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScroll,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: ValueListenableBuilder<double>(
                  valueListenable: _scrollOffset,
                  builder: (context, scrollOffset, _) => CustomPaint(
                    painter: BrandPaperPainter(scrollOffset: scrollOffset),
                  ),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class BrandPaperPainter extends CustomPainter {
  const BrandPaperPainter({this.scrollOffset = 0});

  final double scrollOffset;

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
    final firstFiber = (scrollOffset / 46).floor() - 1;
    final lastFiber = ((scrollOffset + size.height) / 46).ceil() + 1;
    for (var row = firstFiber; row <= lastFiber; row++) {
      final worldY = (row * 46.0) + (_unit(row, 41) * 15.0);
      final y = worldY - scrollOffset;
      final drift = (_unit(row, 73) - 0.5) * 7.0;
      canvas.drawLine(
        Offset(-22, y),
        Offset(size.width + 22, y + drift),
        row.isEven ? fiberLight : fiberDark,
      );
    }

    final fleckLight = Paint()..color = const Color(0x24FFFFFF);
    final fleckDark = Paint()..color = const Color(0x121C1C1A);
    final firstFleckRow = (scrollOffset / 70).floor() - 1;
    final lastFleckRow = ((scrollOffset + size.height) / 70).ceil() + 1;
    final cols = (size.width / 76).ceil() + 1;
    for (var row = firstFleckRow; row <= lastFleckRow; row++) {
      for (var col = 0; col < cols; col++) {
        final seed = (row * 131) + (col * 17);
        final x = (col * 76.0) + (_unit(seed, 11) * 38.0);
        final worldY = (row * 70.0) + (_unit(seed, 53) * 34.0);
        final y = worldY - scrollOffset;
        final radius = 0.32 + (_unit(seed, 97) * 0.52);
        canvas.drawCircle(
          Offset(x, y),
          radius,
          seed % 3 == 0 ? fleckLight : fleckDark,
        );
      }
    }
  }

  double _unit(int value, int salt) {
    final hashed = ((value + 1) * 1103515245 + salt * 12345) & 0x7fffffff;
    return (hashed % 10000) / 10000.0;
  }

  @override
  bool shouldRepaint(covariant BrandPaperPainter oldDelegate) =>
      oldDelegate.scrollOffset != scrollOffset;
}
