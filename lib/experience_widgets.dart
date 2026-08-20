import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:evil_space/led_wall.dart';
import 'package:evil_space/pixel_emoji.dart';

class LedMatrixText extends StatefulWidget {
  const LedMatrixText({
    super.key,
    required this.text,
    required this.maxWidth,
    required this.ledPitch,
    this.fontSize = 24,
    this.color = const Color(0xFFE6E6E6),
    this.hoverColor = Colors.white,
    this.fontWeight = FontWeight.w700,
    this.textAlign = TextAlign.left,
    this.maxLines,
    this.letterSpacing = 0.7,
    this.onTap,
    this.semanticLabel,
    this.header = false,
    this.glow = false,
    this.glowOnHover = true,
  });

  final String text;
  final double maxWidth;
  final double ledPitch;
  final double fontSize;
  final Color color;
  final Color hoverColor;
  final FontWeight fontWeight;
  final TextAlign textAlign;
  final int? maxLines;
  final double letterSpacing;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool header;
  final bool glow;
  final bool glowOnHover;

  @override
  State<LedMatrixText> createState() => _LedMatrixTextState();
}

class _LedMatrixTextState extends State<LedMatrixText> {
  LedTextMask? _mask;
  int _generation = 0;
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _highlighted => _hovered || _focused || _pressed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _requestMask();
  }

  @override
  void didUpdateWidget(covariant LedMatrixText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.maxWidth != widget.maxWidth ||
        oldWidget.ledPitch != widget.ledPitch ||
        oldWidget.fontSize != widget.fontSize ||
        oldWidget.fontWeight != widget.fontWeight ||
        oldWidget.textAlign != widget.textAlign ||
        oldWidget.maxLines != widget.maxLines ||
        oldWidget.letterSpacing != widget.letterSpacing) {
      _requestMask();
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _requestMask() async {
    final generation = ++_generation;
    final direction = Directionality.of(context);
    final scaledFontSize = MediaQuery.textScalerOf(context).scale(widget.fontSize);
    final mask = await LedTextMaskBuilder.build(
      text: widget.text,
      maxWidth: widget.maxWidth,
      fontSize: scaledFontSize,
      ledPitch: widget.ledPitch,
      fontWeight: widget.fontWeight,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      letterSpacing: widget.letterSpacing,
      textDirection: direction,
    );

    if (!mounted || generation != _generation) {
      return;
    }
    setState(() => _mask = mask);
  }

  void _setInteraction({
    bool? hovered,
    bool? focused,
    bool? pressed,
  }) {
    if (!mounted) {
      return;
    }
    setState(() {
      _hovered = hovered ?? _hovered;
      _focused = focused ?? _focused;
      _pressed = pressed ?? _pressed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mask = _mask;
    final activeColor = _highlighted ? widget.hoverColor : widget.color;
    final useGlow = widget.glow || (_highlighted && widget.glowOnHover);

    Widget child;
    if (mask == null) {
      child = SizedBox(
        width: math.min(widget.maxWidth, math.max(1, widget.fontSize * 5)),
        height: widget.fontSize * 1.2,
      );
    } else {
      child = SizedBox(
        width: mask.size.width,
        height: mask.size.height,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _LedTextPainter(
              mask: mask,
              color: activeColor,
              glow: useGlow,
            ),
          ),
        ),
      );
    }

    if (widget.onTap != null) {
      child = ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: kMinInteractiveDimension,
          minWidth: kMinInteractiveDimension,
        ),
        child: Align(
          alignment: widget.textAlign == TextAlign.right
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: child,
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
      label: widget.semanticLabel ?? widget.text.replaceAll('\n', ' '),
      button: widget.onTap != null,
      header: widget.header,
      child: child,
    );
  }
}

class LedTextMaskBuilder {
  LedTextMaskBuilder._();

  static Future<LedTextMask> build({
    required String text,
    required double maxWidth,
    required double fontSize,
    required double ledPitch,
    required FontWeight fontWeight,
    required TextAlign textAlign,
    required int? maxLines,
    required double letterSpacing,
    required TextDirection textDirection,
  }) async {
    final pitch = LedWallGeometry.safePitch(ledPitch);
    final safeWidth = maxWidth.clamp(pitch * 6, 4096.0).toDouble();
    final padding = math.max(3.0, pitch * 1.4).toDouble();

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'monospace',
          fontFamilyFallback: const ['Arial', 'sans-serif'],
          fontWeight: fontWeight,
          fontSize: fontSize,
          letterSpacing: letterSpacing,
          height: 1.06,
        ),
      ),
      textAlign: textAlign,
      textDirection: textDirection,
      maxLines: maxLines,
      textWidthBasis: TextWidthBasis.longestLine,
    )..layout(maxWidth: safeWidth);

    final imageWidth = math.max(1, (painter.width + (padding * 2)).ceil()).toInt();
    final imageHeight = math.max(1, (painter.height + (padding * 2)).ceil()).toInt();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, Offset(padding, padding));
    final picture = recorder.endRecording();
    final image = await picture.toImage(imageWidth, imageHeight);
    picture.dispose();

    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (data == null) {
      throw StateError('Could not rasterize LED glyph mask');
    }

    final rgba = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final columns = math.max(1, (imageWidth / pitch).ceil()).toInt();
    final rows = math.max(1, (imageHeight / pitch).ceil()).toInt();
    final rawCells = Uint8List(columns * rows);

    int minColumn = columns;
    int minRow = rows;
    int maxColumn = -1;
    int maxRow = -1;

    for (int row = 0; row < rows; row++) {
      final y0 = (row * pitch).floor().clamp(0, imageHeight - 1).toInt();
      final y1 = math.min(imageHeight, ((row + 1) * pitch).ceil()).toInt();
      for (int column = 0; column < columns; column++) {
        final x0 = (column * pitch).floor().clamp(0, imageWidth - 1).toInt();
        final x1 = math.min(imageWidth, ((column + 1) * pitch).ceil()).toInt();

        int alphaTotal = 0;
        int alphaPeak = 0;
        int samples = 0;
        for (int y = y0; y < y1; y++) {
          for (int x = x0; x < x1; x++) {
            final alpha = rgba[((y * imageWidth) + x) * 4 + 3];
            alphaTotal += alpha;
            alphaPeak = math.max(alphaPeak, alpha);
            samples++;
          }
        }

        final average = samples == 0 ? 0 : alphaTotal ~/ samples;
        final active = alphaPeak >= 210 || average >= 58;
        if (!active) {
          continue;
        }

        rawCells[(row * columns) + column] = 1;
        minColumn = math.min(minColumn, column);
        minRow = math.min(minRow, row);
        maxColumn = math.max(maxColumn, column);
        maxRow = math.max(maxRow, row);
      }
    }

    if (maxColumn < minColumn || maxRow < minRow) {
      return LedTextMask(
        columns: 1,
        rows: 1,
        pitch: pitch,
        cells: Uint8List(1),
      );
    }

    minColumn = math.max(0, minColumn - 1);
    minRow = math.max(0, minRow - 1);
    maxColumn = math.min(columns - 1, maxColumn + 1);
    maxRow = math.min(rows - 1, maxRow + 1);

    final trimmedColumns = (maxColumn - minColumn) + 1;
    final trimmedRows = (maxRow - minRow) + 1;
    final cells = Uint8List(trimmedColumns * trimmedRows);

    for (int row = 0; row < trimmedRows; row++) {
      for (int column = 0; column < trimmedColumns; column++) {
        cells[(row * trimmedColumns) + column] = rawCells[
            ((row + minRow) * columns) + (column + minColumn)];
      }
    }

    return LedTextMask(
      columns: trimmedColumns,
      rows: trimmedRows,
      pitch: pitch,
      cells: cells,
    );
  }
}

class LedTextMask {
  const LedTextMask({
    required this.columns,
    required this.rows,
    required this.pitch,
    required this.cells,
  });

  final int columns;
  final int rows;
  final double pitch;
  final Uint8List cells;

  Size get size => Size(columns * pitch, rows * pitch);

  int get activeCells {
    int count = 0;
    for (final cell in cells) {
      if (cell != 0) {
        count++;
      }
    }
    return count;
  }
}

class _LedTextPainter extends CustomPainter {
  const _LedTextPainter({
    required this.mask,
    required this.color,
    required this.glow,
  });

  final LedTextMask mask;
  final Color color;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    for (int row = 0; row < mask.rows; row++) {
      for (int column = 0; column < mask.columns; column++) {
        if (mask.cells[(row * mask.columns) + column] == 0) {
          continue;
        }

        final center = LedWallGeometry.cellCenter(
          column: column,
          row: row,
          cellWidth: mask.pitch,
          cellHeight: mask.pitch,
        );
        LedWallPainter.drawEmitter(
          canvas,
          center: center,
          pitch: mask.pitch,
          color: color,
          socket: true,
          glow: glow,
          glowStrength: glow ? 0.72 : 0,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LedTextPainter oldDelegate) {
    return oldDelegate.mask != mask ||
        oldDelegate.color != color ||
        oldDelegate.glow != glow;
  }
}

class LedDevilLogo extends StatefulWidget {
  const LedDevilLogo({
    super.key,
    required this.ledPitch,
    required this.onTap,
  });

  final double ledPitch;
  final VoidCallback onTap;

  @override
  State<LedDevilLogo> createState() => _LedDevilLogoState();
}

class _LedDevilLogoState extends State<LedDevilLogo> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _highlighted => _hovered || _focused || _pressed;

  @override
  Widget build(BuildContext context) {
    final matrix = Pixelemoji.devilUnframed;
    final pitch = LedWallGeometry.safePitch(widget.ledPitch);
    final width = matrix.first.length * pitch;
    final height = matrix.length * pitch;

    return Semantics(
      button: true,
      label: 'Evil Space home',
      child: InkWell(
        onTap: widget.onTap,
        onHover: (value) => setState(() => _hovered = value),
        onFocusChange: (value) => setState(() => _focused = value),
        onHighlightChanged: (value) => setState(() => _pressed = value),
        splashFactory: NoSplash.splashFactory,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: kMinInteractiveDimension,
            minHeight: kMinInteractiveDimension,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: CustomPaint(
              size: Size(width, height),
              painter: _LedMatrixPainter(
                matrix: matrix,
                pitch: pitch,
                color: _highlighted
                    ? Colors.white
                    : const Color(0xFFE6E6E6),
                glow: _highlighted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LedMatrixPainter extends CustomPainter {
  const _LedMatrixPainter({
    required this.matrix,
    required this.pitch,
    required this.color,
    required this.glow,
  });

  final List<List<int>> matrix;
  final double pitch;
  final Color color;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    for (int row = 0; row < matrix.length; row++) {
      for (int column = 0; column < matrix[row].length; column++) {
        if (matrix[row][column] == 0) {
          continue;
        }

        LedWallPainter.drawEmitter(
          canvas,
          center: LedWallGeometry.cellCenter(
            column: column,
            row: row,
            cellWidth: pitch,
            cellHeight: pitch,
          ),
          pitch: pitch,
          color: color,
          socket: true,
          glow: glow,
          glowStrength: 0.76,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LedMatrixPainter oldDelegate) {
    return oldDelegate.matrix != matrix ||
        oldDelegate.pitch != pitch ||
        oldDelegate.color != color ||
        oldDelegate.glow != glow;
  }
}

class LedOccupancyStrip extends StatelessWidget {
  const LedOccupancyStrip({
    super.key,
    required this.total,
    required this.occupied,
    required this.pitch,
  });

  final int total;
  final int occupied;
  final double pitch;

  @override
  Widget build(BuildContext context) {
    final safeTotal = total.clamp(1, 30);
    final safeOccupied = occupied.clamp(0, safeTotal);
    final cellPitch = LedWallGeometry.safePitch(pitch);

    return Semantics(
      label: '$safeOccupied of $safeTotal occupied',
      child: SizedBox(
        width: safeTotal * cellPitch,
        height: cellPitch * 1.3,
        child: CustomPaint(
          painter: _LedOccupancyPainter(
            total: safeTotal,
            occupied: safeOccupied,
            pitch: cellPitch,
          ),
        ),
      ),
    );
  }
}

class _LedOccupancyPainter extends CustomPainter {
  const _LedOccupancyPainter({
    required this.total,
    required this.occupied,
    required this.pitch,
  });

  final int total;
  final int occupied;
  final double pitch;

  @override
  void paint(Canvas canvas, Size size) {
    for (int index = 0; index < total; index++) {
      final isOccupied = index < occupied;
      LedWallPainter.drawEmitter(
        canvas,
        center: Offset((index + 0.5) * pitch, pitch * 0.65),
        pitch: pitch,
        color: isOccupied
            ? Colors.white
            : const Color(0xFF545454),
        socket: true,
        glow: isOccupied,
        glowStrength: isOccupied ? 0.34 : 0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LedOccupancyPainter oldDelegate) {
    return oldDelegate.total != total ||
        oldDelegate.occupied != occupied ||
        oldDelegate.pitch != pitch;
  }
}
