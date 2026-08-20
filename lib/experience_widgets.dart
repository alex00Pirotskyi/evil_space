import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:evil_space/pixel_emoji.dart';

class ReadablePixelText extends StatefulWidget {
  const ReadablePixelText({
    super.key,
    required this.text,
    required this.maxWidth,
    this.fontSize = 22,
    this.pixelSize = 2,
    this.color = Colors.white,
    this.hoverColor = Colors.white,
    this.fontWeight = FontWeight.w700,
    this.textAlign = TextAlign.left,
    this.maxLines,
    this.letterSpacing = 1.0,
    this.onTap,
    this.semanticLabel,
    this.header = false,
  });

  final String text;
  final double maxWidth;
  final double fontSize;
  final double pixelSize;
  final Color color;
  final Color hoverColor;
  final FontWeight fontWeight;
  final TextAlign textAlign;
  final int? maxLines;
  final double letterSpacing;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool header;

  @override
  State<ReadablePixelText> createState() => _ReadablePixelTextState();
}

class _ReadablePixelTextState extends State<ReadablePixelText> {
  _RasterizedPixelText? _raster;
  int _generation = 0;
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _highlighted => _hovered || _focused || _pressed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _requestRaster();
  }

  @override
  void didUpdateWidget(covariant ReadablePixelText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.maxWidth != widget.maxWidth ||
        oldWidget.fontSize != widget.fontSize ||
        oldWidget.pixelSize != widget.pixelSize ||
        oldWidget.fontWeight != widget.fontWeight ||
        oldWidget.textAlign != widget.textAlign ||
        oldWidget.maxLines != widget.maxLines ||
        oldWidget.letterSpacing != widget.letterSpacing) {
      _requestRaster();
    }
  }

  @override
  void dispose() {
    _generation++;
    _raster?.image.dispose();
    super.dispose();
  }

  Future<void> _requestRaster() async {
    final generation = ++_generation;
    final direction = Directionality.of(context);
    final scaledFontSize = MediaQuery.textScalerOf(context).scale(widget.fontSize);
    final raster = await _PixelTextRasterizer.rasterize(
      text: widget.text,
      maxWidth: widget.maxWidth,
      fontSize: scaledFontSize,
      pixelSize: widget.pixelSize,
      fontWeight: widget.fontWeight,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      letterSpacing: widget.letterSpacing,
      textDirection: direction,
    );

    if (!mounted || generation != _generation) {
      raster.image.dispose();
      return;
    }

    final previous = _raster;
    setState(() => _raster = raster);
    previous?.image.dispose();
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
    final color = _highlighted ? widget.hoverColor : widget.color;
    final raster = _raster;

    Widget child;
    if (raster == null) {
      child = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: Text(
          widget.text,
          maxLines: widget.maxLines,
          textAlign: widget.textAlign,
          style: TextStyle(
            color: color,
            fontFamily: 'monospace',
            fontWeight: widget.fontWeight,
            fontSize: widget.fontSize,
            letterSpacing: widget.letterSpacing,
            height: 1.15,
          ),
        ),
      );
    } else {
      child = SizedBox(
        width: raster.size.width,
        height: raster.size.height,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _RasterPixelTextPainter(
              image: raster.image,
              color: color,
              pixelSize: widget.pixelSize,
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
        child: Align(alignment: Alignment.centerLeft, child: child),
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

class _PixelTextRasterizer {
  _PixelTextRasterizer._();

  static Future<_RasterizedPixelText> rasterize({
    required String text,
    required double maxWidth,
    required double fontSize,
    required double pixelSize,
    required FontWeight fontWeight,
    required TextAlign textAlign,
    required int? maxLines,
    required double letterSpacing,
    required TextDirection textDirection,
  }) async {
    final safePixelSize = pixelSize.clamp(1.0, 4.0).toDouble();
    final lowFontSize = fontSize / safePixelSize;
    final lowMaxWidth = (maxWidth / safePixelSize) - 4;

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'monospace',
          fontFamilyFallback: const ['Arial', 'sans-serif'],
          fontWeight: fontWeight,
          fontSize: lowFontSize,
          letterSpacing: letterSpacing / safePixelSize,
          height: 1.15,
        ),
      ),
      textAlign: textAlign,
      textDirection: textDirection,
      maxLines: maxLines,
      textWidthBasis: TextWidthBasis.longestLine,
    )..layout(maxWidth: lowMaxWidth.clamp(1.0, double.infinity).toDouble());

    const padding = 2.0;
    final imageWidth = (painter.width + (padding * 2))
        .ceil()
        .clamp(1, 4096)
        .toInt();
    final imageHeight = (painter.height + (padding * 2))
        .ceil()
        .clamp(1, 4096)
        .toInt();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Offset(padding, padding));
    final picture = recorder.endRecording();
    final image = await picture.toImage(imageWidth, imageHeight);
    picture.dispose();

    return _RasterizedPixelText(
      image: image,
      size: Size(
        imageWidth * safePixelSize,
        imageHeight * safePixelSize,
      ),
    );
  }
}

class _RasterizedPixelText {
  const _RasterizedPixelText({
    required this.image,
    required this.size,
  });

  final ui.Image image;
  final Size size;
}

class _RasterPixelTextPainter extends CustomPainter {
  const _RasterPixelTextPainter({
    required this.image,
    required this.color,
    required this.pixelSize,
  });

  final ui.Image image;
  final Color color;
  final double pixelSize;

  @override
  void paint(Canvas canvas, Size size) {
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final destination = Offset.zero & size;

    final shadowPaint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none
      ..colorFilter = const ColorFilter.mode(
        Color(0xCC000000),
        BlendMode.srcIn,
      );
    canvas.drawImageRect(
      image,
      source,
      destination.shift(Offset(pixelSize, pixelSize)),
      shadowPaint,
    );

    final paint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none
      ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn);
    canvas.drawImageRect(image, source, destination, paint);
  }

  @override
  bool shouldRepaint(covariant _RasterPixelTextPainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.color != color ||
        oldDelegate.pixelSize != pixelSize;
  }
}

class PixelDevilLogo extends StatefulWidget {
  const PixelDevilLogo({
    super.key,
    required this.pixelSize,
    required this.onTap,
  });

  final double pixelSize;
  final VoidCallback onTap;

  @override
  State<PixelDevilLogo> createState() => _PixelDevilLogoState();
}

class _PixelDevilLogoState extends State<PixelDevilLogo> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final matrix = Pixelemoji.devilUnframed;
    final width = matrix.first.length * widget.pixelSize;
    final height = matrix.length * widget.pixelSize;

    return Semantics(
      button: true,
      label: 'Evil Space home',
      child: InkWell(
        onTap: widget.onTap,
        onHover: (value) => setState(() => _hovered = value),
        splashFactory: NoSplash.splashFactory,
        hoverColor: Colors.transparent,
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
              painter: _PixelMatrixPainter(
                matrix: matrix,
                pixelSize: widget.pixelSize,
                color: _hovered ? Colors.white : const Color(0xFFE8E8E8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PixelMatrixPainter extends CustomPainter {
  const _PixelMatrixPainter({
    required this.matrix,
    required this.pixelSize,
    required this.color,
  });

  final List<List<int>> matrix;
  final double pixelSize;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;
    for (int row = 0; row < matrix.length; row++) {
      for (int column = 0; column < matrix[row].length; column++) {
        if (matrix[row][column] == 1) {
          canvas.drawRect(
            Rect.fromLTWH(
              column * pixelSize,
              row * pixelSize,
              pixelSize,
              pixelSize,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PixelMatrixPainter oldDelegate) {
    return oldDelegate.matrix != matrix ||
        oldDelegate.pixelSize != pixelSize ||
        oldDelegate.color != color;
  }
}
