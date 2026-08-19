import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:evil_space/config.dart';
import 'package:evil_space/pixel_glyphs.dart';

class GridPainter extends CustomPainter {
  GridPainter({required this.gridSize});

  final double gridSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (gridSize <= 0) {
      return;
    }

    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.0;

    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.gridSize != gridSize;
  }
}

class MatrixPainter extends CustomPainter {
  MatrixPainter({
    required this.precalculatedPath,
    required this.color,
    required this.isHighlighted,
  });

  final Path precalculatedPath;
  final Color color;
  final bool isHighlighted;

  @override
  void paint(Canvas canvas, Size size) {
    if (precalculatedPath.getBounds().isEmpty) {
      return;
    }

    final fillPaint = Paint()..color = color;
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    if (isHighlighted) {
      final glowPaint = Paint()
        ..color = const Color(0xCCFFFFFF)
        ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawPath(precalculatedPath, glowPaint);
    }

    canvas.drawPath(precalculatedPath, fillPaint);
    canvas.drawPath(precalculatedPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant MatrixPainter oldDelegate) {
    return oldDelegate.precalculatedPath != precalculatedPath ||
        oldDelegate.color != color ||
        oldDelegate.isHighlighted != isHighlighted;
  }
}

class _PixelGeometry {
  const _PixelGeometry({
    required this.path,
    required this.size,
  });

  final Path path;
  final Size size;
}

class PixelTextLayout {
  PixelTextLayout._();

  static const int _spaceCells = 3;
  static const int _letterSpacingCells = 1;

  static int measureLineCells(String text) {
    if (text.isEmpty) {
      return 0;
    }

    int width = 0;
    for (int index = 0; index < text.length; index++) {
      final char = text[index];
      if (char == ' ') {
        width += _spaceCells;
        continue;
      }

      final glyph = PixelGlyphResolver.resolve(char);
      width += glyph?.width ?? _spaceCells;

      final bool hasNext = index < text.length - 1;
      if (hasNext && text[index + 1] != ' ') {
        width += _letterSpacingCells;
      }
    }
    return width;
  }

  static String wrapToWidth({
    required String text,
    required double maxWidth,
    required double gridSize,
  }) {
    if (text.isEmpty || maxWidth <= 0 || gridSize <= 0) {
      return text;
    }

    final maxCells = math.max(4, (maxWidth / gridSize).floor()).toInt();
    final output = <String>[];

    for (final paragraph in text.split('\n')) {
      if (paragraph.trim().isEmpty) {
        output.add('');
        continue;
      }

      final words = paragraph.trim().split(RegExp(r'\s+'));
      String current = '';

      for (final word in words) {
        if (measureLineCells(word) > maxCells) {
          if (current.isNotEmpty) {
            output.add(current);
            current = '';
          }
          output.addAll(_breakWord(word, maxCells));
          continue;
        }

        final candidate = current.isEmpty ? word : '$current $word';
        if (measureLineCells(candidate) <= maxCells) {
          current = candidate;
        } else {
          output.add(current);
          current = word;
        }
      }

      if (current.isNotEmpty) {
        output.add(current);
      }
    }

    return output.join('\n');
  }

  static List<String> _breakWord(String word, int maxCells) {
    final lines = <String>[];
    String current = '';

    for (int index = 0; index < word.length; index++) {
      final candidate = '$current${word[index]}';
      if (current.isNotEmpty && measureLineCells(candidate) > maxCells) {
        lines.add(current);
        current = word[index];
      } else {
        current = candidate;
      }
    }

    if (current.isNotEmpty) {
      lines.add(current);
    }
    return lines;
  }
}

class _PixelStringGeometryBuilder {
  _PixelStringGeometryBuilder._();

  static _PixelGeometry build(String word, double gridSize) {
    final path = Path();
    final lines = word.split('\n');
    double y = 0;
    double maxWidth = 0;

    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      final glyphs = <PixelGlyph?>[];

      int topRows = 0;
      int bottomRows = 0;
      int baseRows = 5;

      for (int index = 0; index < line.length; index++) {
        final char = line[index];
        final glyph = char == ' ' ? null : PixelGlyphResolver.resolve(char);
        glyphs.add(glyph);
        if (glyph != null) {
          topRows = math.max(topRows, glyph.topRows).toInt();
          bottomRows = math.max(bottomRows, glyph.bottomRows).toInt();
          baseRows = math.max(baseRows, glyph.height).toInt();
        }
      }

      double x = 0;
      for (int index = 0; index < line.length; index++) {
        final char = line[index];
        final glyph = glyphs[index];

        if (char == ' ') {
          x += gridSize * 3;
          continue;
        }

        if (glyph == null) {
          x += gridSize * 3;
        } else {
          _drawGlyph(
            path: path,
            glyph: glyph,
            x: x,
            lineY: y,
            lineTopRows: topRows,
            gridSize: gridSize,
          );
          x += glyph.width * gridSize;
        }

        final bool hasNext = index < line.length - 1;
        if (hasNext && line[index + 1] != ' ') {
          x += gridSize;
        }
      }

      maxWidth = math.max(maxWidth, x).toDouble();
      final lineHeight = (topRows + baseRows + bottomRows) * gridSize;
      y += lineHeight;

      if (lineIndex < lines.length - 1) {
        y += gridSize * 2;
      }
    }

    return _PixelGeometry(
      path: path,
      size: Size(maxWidth, math.max(gridSize, y).toDouble()),
    );
  }

  static void _drawGlyph({
    required Path path,
    required PixelGlyph glyph,
    required double x,
    required double lineY,
    required int lineTopRows,
    required double gridSize,
  }) {
    final baseY = lineY + (lineTopRows * gridSize);

    for (int row = 0; row < glyph.matrix.length; row++) {
      for (int column = 0; column < glyph.matrix[row].length; column++) {
        if (glyph.matrix[row][column] == 1) {
          path.addRect(
            Rect.fromLTWH(
              x + (column * gridSize),
              baseY + (row * gridSize),
              gridSize,
              gridSize,
            ),
          );
        }
      }
    }

    if (glyph.tone == PixelTone.none) {
      return;
    }

    final center = glyph.width ~/ 2;

    if (glyph.tone == PixelTone.dot) {
      path.addRect(
        Rect.fromLTWH(
          x + (center * gridSize),
          baseY + (glyph.height * gridSize),
          gridSize,
          gridSize,
        ),
      );
      return;
    }

    final accentY = lineY + ((lineTopRows - glyph.topRows) * gridSize);
    final accentCells = _accentCells(glyph.tone, glyph.width, center);
    for (final cell in accentCells) {
      path.addRect(
        Rect.fromLTWH(
          x + (cell.$1 * gridSize),
          accentY + (cell.$2 * gridSize),
          gridSize,
          gridSize,
        ),
      );
    }
  }

  static List<(int, int)> _accentCells(
    PixelTone tone,
    int width,
    int center,
  ) {
    final left = math.max(0, center - 1).toInt();
    final right = math.min(width - 1, center + 1).toInt();

    switch (tone) {
      case PixelTone.acute:
        return [(right, 0), (center, 1)];
      case PixelTone.grave:
        return [(left, 0), (center, 1)];
      case PixelTone.hook:
        return [(center, 0), (right, 0), (center, 1)];
      case PixelTone.tilde:
        return [(left, 0), (center, 1), (right, 0)];
      case PixelTone.dot:
      case PixelTone.none:
        return const [];
    }
  }
}

class HoverablePixelBlock extends StatefulWidget {
  const HoverablePixelBlock({
    super.key,
    required this.matrix,
    required this.gridSize,
    this.onTap,
    this.semanticLabel,
    this.color = const Color(0xFFDDDDDD),
  });

  final List<List<int>> matrix;
  final double gridSize;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Color color;

  @override
  State<HoverablePixelBlock> createState() => _HoverablePixelBlockState();
}

class _HoverablePixelBlockState extends State<HoverablePixelBlock> {
  late Path _path;
  Timer? _fadeTimer;
  double _opacity = 0;
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _highlighted => _hovered || _focused || _pressed;

  @override
  void initState() {
    super.initState();
    _buildPath();
    _fadeTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() => _opacity = 1);
      }
    });
  }

  @override
  void didUpdateWidget(covariant HoverablePixelBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gridSize != widget.gridSize ||
        oldWidget.matrix != widget.matrix) {
      _buildPath();
    }
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    super.dispose();
  }

  void _buildPath() {
    _path = Path();
    for (int row = 0; row < widget.matrix.length; row++) {
      for (int column = 0; column < widget.matrix[row].length; column++) {
        if (widget.matrix[row][column] == 1) {
          _path.addRect(
            Rect.fromLTWH(
              column * widget.gridSize,
              row * widget.gridSize,
              widget.gridSize,
              widget.gridSize,
            ),
          );
        }
      }
    }
  }

  void _setInteraction({
    bool? hovered,
    bool? focused,
    bool? pressed,
  }) {
    setState(() {
      _hovered = hovered ?? _hovered;
      _focused = focused ?? _focused;
      _pressed = pressed ?? _pressed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.matrix.isEmpty
        ? widget.gridSize
        : widget.matrix.first.length * widget.gridSize;
    final height = widget.matrix.length * widget.gridSize;

    final paint = RepaintBoundary(
      child: CustomPaint(
        size: Size(width, height),
        painter: MatrixPainter(
          precalculatedPath: _path,
          color: _highlighted ? Colors.white : widget.color,
          isHighlighted: _highlighted,
        ),
      ),
    );

    Widget child = paint;
    if (widget.onTap != null) {
      child = ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: kMinInteractiveDimension,
          minHeight: kMinInteractiveDimension,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: paint,
        ),
      );
      child = InkWell(
        onTap: widget.onTap,
        onHover: (value) => _setInteraction(hovered: value),
        onFocusChange: (value) => _setInteraction(focused: value),
        onHighlightChanged: (value) => _setInteraction(pressed: value),
        splashFactory: NoSplash.splashFactory,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: child,
      );
    }

    return Semantics(
      label: widget.semanticLabel,
      button: widget.onTap != null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: bootFadeMs),
        opacity: _opacity,
        child: child,
      ),
    );
  }
}

class HoverablePixelString extends StatefulWidget {
  const HoverablePixelString({
    super.key,
    required this.word,
    required this.gridSize,
    this.onTap,
    this.bootDelay = Duration.zero,
    this.isInstant = false,
    this.semanticLabel,
    this.color = const Color(0xFFDDDDDD),
    this.hoverColor = Colors.white,
  });

  final String word;
  final double gridSize;
  final VoidCallback? onTap;
  final Duration bootDelay;
  final bool isInstant;
  final String? semanticLabel;
  final Color color;
  final Color hoverColor;

  @override
  State<HoverablePixelString> createState() => _HoverablePixelStringState();
}

class _HoverablePixelStringState extends State<HoverablePixelString> {
  late _PixelGeometry _geometry;
  Timer? _fadeTimer;
  double _opacity = 0;
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _highlighted => _hovered || _focused || _pressed;

  @override
  void initState() {
    super.initState();
    _rebuildGeometry();
    _scheduleFade();
  }

  @override
  void didUpdateWidget(covariant HoverablePixelString oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word != widget.word ||
        oldWidget.gridSize != widget.gridSize) {
      _rebuildGeometry();
    }
    if (oldWidget.isInstant != widget.isInstant ||
        oldWidget.bootDelay != widget.bootDelay) {
      _scheduleFade();
    }
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    super.dispose();
  }

  void _scheduleFade() {
    _fadeTimer?.cancel();
    if (widget.isInstant) {
      _opacity = 1;
      return;
    }

    _opacity = 0;
    _fadeTimer = Timer(widget.bootDelay, () {
      if (mounted) {
        setState(() => _opacity = 1);
      }
    });
  }

  void _rebuildGeometry() {
    _geometry = _PixelStringGeometryBuilder.build(
      widget.word,
      widget.gridSize,
    );
  }

  void _setInteraction({
    bool? hovered,
    bool? focused,
    bool? pressed,
  }) {
    setState(() {
      _hovered = hovered ?? _hovered;
      _focused = focused ?? _focused;
      _pressed = pressed ?? _pressed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final paint = RepaintBoundary(
      child: CustomPaint(
        size: _geometry.size,
        painter: MatrixPainter(
          precalculatedPath: _geometry.path,
          color: _highlighted ? widget.hoverColor : widget.color,
          isHighlighted: _highlighted,
        ),
      ),
    );

    Widget child = paint;
    if (widget.onTap != null) {
      child = ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: kMinInteractiveDimension,
          minHeight: kMinInteractiveDimension,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: paint,
        ),
      );
      child = InkWell(
        onTap: widget.onTap,
        onHover: (value) => _setInteraction(hovered: value),
        onFocusChange: (value) => _setInteraction(focused: value),
        onHighlightChanged: (value) => _setInteraction(pressed: value),
        splashFactory: NoSplash.splashFactory,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: child,
      );
    }

    return Semantics(
      label: widget.semanticLabel ?? widget.word.replaceAll('\n', ' '),
      button: widget.onTap != null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: bootFadeMs),
        opacity: _opacity,
        child: child,
      ),
    );
  }
}
