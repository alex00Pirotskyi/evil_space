import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:evil_space/config.dart';

class Rgb565 {
  Rgb565._();

  static int pack(int red, int green, int blue) {
    final r = (red.clamp(0, 255).toInt() >> 3) & 0x1F;
    final g = (green.clamp(0, 255).toInt() >> 2) & 0x3F;
    final b = (blue.clamp(0, 255).toInt() >> 3) & 0x1F;
    return (r << 11) | (g << 5) | b;
  }

  static int red8(int value) {
    final channel = (value >> 11) & 0x1F;
    return (channel << 3) | (channel >> 2);
  }

  static int green8(int value) {
    final channel = (value >> 5) & 0x3F;
    return (channel << 2) | (channel >> 4);
  }

  static int blue8(int value) {
    final channel = value & 0x1F;
    return (channel << 3) | (channel >> 2);
  }

  static int lerp(int from, int to, double t) {
    final clamped = t.clamp(0.0, 1.0);

    final fromR = (from >> 11) & 0x1F;
    final fromG = (from >> 5) & 0x3F;
    final fromB = from & 0x1F;

    final toR = (to >> 11) & 0x1F;
    final toG = (to >> 5) & 0x3F;
    final toB = to & 0x1F;

    final red = (fromR + ((toR - fromR) * clamped)).round();
    final green = (fromG + ((toG - fromG) * clamped)).round();
    final blue = (fromB + ((toB - fromB) * clamped)).round();

    return (red << 11) | (green << 5) | blue;
  }

  static Color toColor(int value) {
    return Color.fromARGB(
      255,
      red8(value),
      green8(value),
      blue8(value),
    );
  }
}

class Rgb565Frame {
  const Rgb565Frame({
    required this.columns,
    required this.rows,
    required this.pixels,
    this.source,
  });

  final int columns;
  final int rows;
  final Uint16List pixels;
  final String? source;

  factory Rgb565Frame.demo({
    required int columns,
    required int rows,
    required int variant,
  }) {
    final pixels = Uint16List(columns * rows);

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < columns; x++) {
        final nx = columns <= 1 ? 0.0 : x / (columns - 1);
        final ny = rows <= 1 ? 0.0 : y / (rows - 1);
        final wave = (math.sin((nx * math.pi * 4) + variant) + 1) * 0.5;

        final red = switch (variant % 3) {
          0 => (40 + (215 * nx)).round(),
          1 => (30 + (150 * wave)).round(),
          _ => (25 + (190 * ny)).round(),
        };
        final green = switch (variant % 3) {
          0 => (25 + (120 * ny)).round(),
          1 => (40 + (210 * nx)).round(),
          _ => (35 + (180 * wave)).round(),
        };
        final blue = switch (variant % 3) {
          0 => (60 + (180 * wave)).round(),
          1 => (45 + (170 * ny)).round(),
          _ => (60 + (190 * (1 - nx))).round(),
        };

        pixels[(y * columns) + x] = Rgb565.pack(red, green, blue);
      }
    }

    return Rgb565Frame(
      columns: columns,
      rows: rows,
      pixels: pixels,
      source: 'demo:$variant',
    );
  }
}

class PixelAssetCatalog {
  PixelAssetCatalog._();

  static const Set<String> _imageExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
    '.gif',
    '.bmp',
  };

  static Future<List<String>> discover(
    AssetBundle bundle, {
    String directory = 'assets/slideshow/',
  }) async {
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    final assets = manifest.listAssets().where((asset) {
      if (!asset.startsWith(directory)) {
        return false;
      }
      final lower = asset.toLowerCase();
      return _imageExtensions.any(lower.endsWith);
    }).toList()
      ..sort();
    return assets;
  }
}

class PixelFrameDecoder {
  PixelFrameDecoder._();

  static Future<Rgb565Frame> decodeAsset({
    required AssetBundle bundle,
    required String assetPath,
    required int columns,
    required int rows,
  }) async {
    final buffer = await bundle.loadBuffer(assetPath);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? decodedImage;
    ui.Image? sampledImage;
    ui.Picture? picture;

    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);

      final coverScale = math.max(
        columns / descriptor.width,
        rows / descriptor.height,
      );
      final decodeScale = math.min(1.0, coverScale);
      final decodeWidth = math
          .max(
            1,
            (descriptor.width * decodeScale).round(),
          )
          .toInt();
      final decodeHeight = math
          .max(
            1,
            (descriptor.height * decodeScale).round(),
          )
          .toInt();

      codec = await descriptor.instantiateCodec(
        targetWidth: decodeWidth,
        targetHeight: decodeHeight,
      );

      final frameInfo = await codec.getNextFrame();
      decodedImage = frameInfo.image;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final sourceRect = _coverSourceRect(
        imageWidth: decodedImage.width.toDouble(),
        imageHeight: decodedImage.height.toDouble(),
        targetAspectRatio: columns / rows,
      );
      final targetRect = ui.Rect.fromLTWH(
        0,
        0,
        columns.toDouble(),
        rows.toDouble(),
      );
      final paint = ui.Paint()..filterQuality = ui.FilterQuality.low;

      canvas.drawImageRect(
        decodedImage,
        sourceRect,
        targetRect,
        paint,
      );

      picture = recorder.endRecording();
      sampledImage = await picture.toImage(columns, rows);
      final data = await sampledImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (data == null) {
        throw StateError('Could not read pixels from $assetPath');
      }

      final rgba = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final pixels = Uint16List(columns * rows);
      const background = 0x22;

      for (int index = 0; index < pixels.length; index++) {
        final offset = index * 4;
        final alpha = rgba[offset + 3];
        final inverseAlpha = 255 - alpha;

        final red =
            ((rgba[offset] * alpha) + (background * inverseAlpha)) ~/ 255;
        final green =
            ((rgba[offset + 1] * alpha) + (background * inverseAlpha)) ~/ 255;
        final blue =
            ((rgba[offset + 2] * alpha) + (background * inverseAlpha)) ~/ 255;

        pixels[index] = Rgb565.pack(red, green, blue);
      }

      return Rgb565Frame(
        columns: columns,
        rows: rows,
        pixels: pixels,
        source: assetPath,
      );
    } finally {
      sampledImage?.dispose();
      picture?.dispose();
      decodedImage?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  static ui.Rect _coverSourceRect({
    required double imageWidth,
    required double imageHeight,
    required double targetAspectRatio,
  }) {
    final sourceAspectRatio = imageWidth / imageHeight;

    if (sourceAspectRatio > targetAspectRatio) {
      final cropWidth = imageHeight * targetAspectRatio;
      return ui.Rect.fromLTWH(
        (imageWidth - cropWidth) / 2,
        0,
        cropWidth,
        imageHeight,
      );
    }

    final cropHeight = imageWidth / targetAspectRatio;
    return ui.Rect.fromLTWH(
      0,
      (imageHeight - cropHeight) / 2,
      imageWidth,
      cropHeight,
    );
  }
}

class PixelAssetSlideshow extends StatefulWidget {
  const PixelAssetSlideshow({
    super.key,
    this.assetDirectory = 'assets/slideshow/',
    this.holdDuration = const Duration(milliseconds: slideshowHoldMs),
    this.transitionDuration =
        const Duration(milliseconds: slideshowTransitionMs),
    this.pixelCellSize = 10,
    this.semanticsLabel = 'RGB565 pixel image slideshow',
  });

  final String assetDirectory;
  final Duration holdDuration;
  final Duration transitionDuration;
  final double pixelCellSize;
  final String semanticsLabel;

  @override
  State<PixelAssetSlideshow> createState() => _PixelAssetSlideshowState();
}

class _PixelAssetSlideshowState extends State<PixelAssetSlideshow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _transition;
  final List<String> _assetPaths = [];

  List<Rgb565Frame> _frames = const [];
  Timer? _holdTimer;
  int _currentIndex = 0;
  int _nextIndex = 0;
  int _transitionSeed = 0;
  int _loadGeneration = 0;
  int _requestedColumns = 0;
  int _requestedRows = 0;
  bool _catalogLoaded = false;

  @override
  void initState() {
    super.initState();
    _transition = AnimationController(
      vsync: this,
      duration: widget.transitionDuration,
    );
    _transition.addStatusListener(_handleTransitionStatus);
  }

  @override
  void didUpdateWidget(covariant PixelAssetSlideshow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transitionDuration != widget.transitionDuration) {
      _transition.duration = widget.transitionDuration;
    }
    if (oldWidget.assetDirectory != widget.assetDirectory) {
      _catalogLoaded = false;
      _assetPaths.clear();
      _requestReload();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _transition
      ..removeStatusListener(_handleTransitionStatus)
      ..dispose();
    super.dispose();
  }

  void _handleTransitionStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) {
      return;
    }

    setState(() {
      _currentIndex = _nextIndex;
      _nextIndex = _currentIndex;
      _transition.reset();
    });
    _scheduleNext();
  }

  void _scheduleNext() {
    _holdTimer?.cancel();
    if (!mounted || _frames.length < 2) {
      return;
    }

    _holdTimer = Timer(widget.holdDuration, _beginTransition);
  }

  void _beginTransition() {
    if (!mounted || _frames.length < 2 || _transition.isAnimating) {
      return;
    }

    setState(() {
      _nextIndex = (_currentIndex + 1) % _frames.length;
      _transitionSeed++;
    });
    _transition.forward(from: 0);
  }

  void _requestSize(int columns, int rows) {
    if (columns == _requestedColumns && rows == _requestedRows) {
      return;
    }

    _requestedColumns = columns;
    _requestedRows = rows;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadFrames(columns, rows);
      }
    });
  }

  void _requestReload() {
    if (_requestedColumns <= 0 || _requestedRows <= 0) {
      return;
    }
    final columns = _requestedColumns;
    final rows = _requestedRows;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadFrames(columns, rows);
      }
    });
  }

  Future<void> _loadFrames(int columns, int rows) async {
    final generation = ++_loadGeneration;
    final bundle = DefaultAssetBundle.of(context);

    _holdTimer?.cancel();
    _transition.stop();

    if (!_catalogLoaded) {
      final discovered = await PixelAssetCatalog.discover(
        bundle,
        directory: widget.assetDirectory,
      );
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      _assetPaths
        ..clear()
        ..addAll(discovered);
      _catalogLoaded = true;
    }

    final loadedFrames = <Rgb565Frame>[];
    for (final assetPath in _assetPaths) {
      try {
        loadedFrames.add(
          await PixelFrameDecoder.decodeAsset(
            bundle: bundle,
            assetPath: assetPath,
            columns: columns,
            rows: rows,
          ),
        );
      } catch (error, stackTrace) {
        debugPrint('Pixel slideshow skipped $assetPath: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      if (!mounted || generation != _loadGeneration) {
        return;
      }
    }

    if (loadedFrames.isEmpty) {
      loadedFrames.addAll([
        Rgb565Frame.demo(columns: columns, rows: rows, variant: 0),
        Rgb565Frame.demo(columns: columns, rows: rows, variant: 1),
        Rgb565Frame.demo(columns: columns, rows: rows, variant: 2),
      ]);
    }

    if (!mounted || generation != _loadGeneration) {
      return;
    }

    setState(() {
      _frames = loadedFrames;
      _currentIndex = 0;
      _nextIndex = 0;
      _transitionSeed = 0;
      _transition.reset();
    });
    _scheduleNext();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticsLabel,
      image: true,
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            if (!width.isFinite ||
                !height.isFinite ||
                width <= 0 ||
                height <= 0) {
              return const SizedBox.shrink();
            }

            final cellSize = math.max(4.0, widget.pixelCellSize);
            final columns = math.max(16, (width / cellSize).round()).toInt();
            final rows = math.max(9, (height / cellSize).round()).toInt();
            _requestSize(columns, rows);

            if (_frames.isEmpty ||
                _frames.first.columns != columns ||
                _frames.first.rows != rows) {
              return const ColoredBox(color: Color(0xFF222222));
            }

            return RepaintBoundary(
              child: CustomPaint(
                size: Size(width, height),
                painter: _Rgb565SlideshowPainter(
                  from: _frames[_currentIndex],
                  to: _frames[_nextIndex],
                  progress: _transition,
                  seed: _transitionSeed,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Rgb565SlideshowPainter extends CustomPainter {
  _Rgb565SlideshowPainter({
    required this.from,
    required this.to,
    required this.progress,
    required this.seed,
  }) : super(repaint: progress);

  final Rgb565Frame from;
  final Rgb565Frame to;
  final Animation<double> progress;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final columns = from.columns;
    final rows = from.rows;
    if (columns <= 0 || rows <= 0 || to.pixels.length != from.pixels.length) {
      return;
    }

    final cellWidth = size.width / columns;
    final cellHeight = size.height / rows;
    final paint = Paint()..style = PaintingStyle.fill;
    final rawProgress = progress.value;

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < columns; x++) {
        final index = (y * columns) + x;
        final localProgress = _runwayProgress(
          x: x,
          y: y,
          columns: columns,
          rows: rows,
          progress: rawProgress,
          seed: seed,
        );
        final value = localProgress <= 0
            ? from.pixels[index]
            : localProgress >= 1
                ? to.pixels[index]
                : Rgb565.lerp(
                    from.pixels[index],
                    to.pixels[index],
                    _smoothStep(localProgress),
                  );

        paint.color = Rgb565.toColor(value);
        canvas.drawRect(
          Rect.fromLTWH(
            x * cellWidth,
            y * cellHeight,
            cellWidth + 0.5,
            cellHeight + 0.5,
          ),
          paint,
        );
      }
    }
  }

  double _runwayProgress({
    required int x,
    required int y,
    required int columns,
    required int rows,
    required double progress,
    required int seed,
  }) {
    final maxX = math.max(1, columns - 1).toInt();
    final maxY = math.max(1, rows - 1).toInt();
    final direction = seed & 3;

    final dx = direction == 0 || direction == 1 ? x : maxX - x;
    final dy = direction == 0 || direction == 2 ? y : maxY - y;

    final diagonal = ((dx / maxX) + (dy / maxY)) * 0.5;
    final noise = (_hash01(x, y, seed) - 0.5) * 0.16;
    final threshold = (diagonal * 0.82 + noise).clamp(0.0, 0.88);
    const edgeWidth = 0.12;

    return ((progress - threshold) / edgeWidth).clamp(0.0, 1.0);
  }

  double _hash01(int x, int y, int seed) {
    int hash = x * 374761393 + y * 668265263 + seed * 2147483647;
    hash = (hash ^ (hash >> 13)) * 1274126177;
    hash ^= hash >> 16;
    return (hash & 0x7FFFFFFF) / 0x7FFFFFFF;
  }

  double _smoothStep(double value) {
    return value * value * (3 - (2 * value));
  }

  @override
  bool shouldRepaint(covariant _Rgb565SlideshowPainter oldDelegate) {
    return oldDelegate.from != from ||
        oldDelegate.to != to ||
        oldDelegate.seed != seed;
  }
}
