import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EInkPalette {
  EInkPalette._();

  static const Color paper = Color(0xFFF2F0E8);
  static const Color lightInk = Color(0xFFC8C4B9);
  static const Color midInk = Color(0xFF77736A);
  static const Color ink = Color(0xFF171715);

  static Color forLevel(int level) {
    return switch (level) {
      0 => paper,
      1 => lightInk,
      2 => midInk,
      _ => ink,
    };
  }
}

class EInkFrame {
  const EInkFrame({
    required this.columns,
    required this.rows,
    required this.levels,
    this.source,
  });

  final int columns;
  final int rows;
  final Uint8List levels;
  final String? source;

  factory EInkFrame.demo({
    required int columns,
    required int rows,
    required int variant,
  }) {
    final levels = Uint8List(columns * rows);
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < columns; x++) {
        final nx = columns <= 1 ? 0.0 : x / (columns - 1);
        final ny = rows <= 1 ? 0.0 : y / (rows - 1);
        final wave = math.sin((nx * math.pi * 3.0) + (variant * 0.8));
        final band = math.cos((ny * math.pi * 2.0) - (variant * 0.55));
        final value = 0.62 + (wave * 0.12) + (band * 0.08) - (ny * 0.13);
        final threshold = ((x * 17 + y * 29 + variant * 43) & 15) / 15.0;
        final level = value > 0.78
            ? 0
            : value > 0.58
                ? (threshold > 0.72 ? 2 : 1)
                : value > 0.36
                    ? (threshold > 0.55 ? 3 : 2)
                    : 3;
        levels[(y * columns) + x] = level;
      }
    }
    return EInkFrame(
      columns: columns,
      rows: rows,
      levels: levels,
      source: 'demo:$variant',
    );
  }
}

class EInkProcessor {
  EInkProcessor._();

  static EInkFrame processRgba({
    required Uint8List rgba,
    required int columns,
    required int rows,
    String? source,
  }) {
    final count = columns * rows;
    if (rgba.length < count * 4) {
      throw ArgumentError('RGBA buffer is smaller than the requested frame');
    }

    final histogram = Uint32List(256);
    final luminance = Float64List(count);

    for (int index = 0; index < count; index++) {
      final offset = index * 4;
      final alpha = rgba[offset + 3] / 255.0;
      final red = (rgba[offset] * alpha) + (242 * (1 - alpha));
      final green = (rgba[offset + 1] * alpha) + (240 * (1 - alpha));
      final blue = (rgba[offset + 2] * alpha) + (232 * (1 - alpha));
      final value = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue);
      luminance[index] = value;
      histogram[value.round().clamp(0, 255)]++;
    }

    final low = _histogramPercentile(histogram, count, 0.025);
    final high = _histogramPercentile(histogram, count, 0.975);
    final span = math.max(24.0, (high - low).toDouble());

    final normalized = Float64List(count);
    for (int index = 0; index < count; index++) {
      var value = ((luminance[index] - low) / span).clamp(0.0, 1.0);
      value = ((value - 0.5) * 1.18 + 0.5).clamp(0.0, 1.0);
      value = math.pow(value, 0.93).toDouble();
      normalized[index] = value * 255.0;
    }

    final sharpened = Float64List(count);
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < columns; x++) {
        double neighborhood = 0;
        int samples = 0;
        for (int dy = -1; dy <= 1; dy++) {
          final yy = y + dy;
          if (yy < 0 || yy >= rows) {
            continue;
          }
          for (int dx = -1; dx <= 1; dx++) {
            final xx = x + dx;
            if (xx < 0 || xx >= columns) {
              continue;
            }
            neighborhood += normalized[(yy * columns) + xx];
            samples++;
          }
        }
        final index = (y * columns) + x;
        final average = samples == 0 ? normalized[index] : neighborhood / samples;
        sharpened[index] = (normalized[index] +
                ((normalized[index] - average) * 0.48))
            .clamp(0.0, 255.0);
      }
    }

    final working = Float64List.fromList(sharpened);
    final levels = Uint8List(count);

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < columns; x++) {
        final index = (y * columns) + x;
        final oldValue = working[index].clamp(0.0, 255.0);
        final quantized = _nearestPaperTone(oldValue);
        levels[index] = quantized.$1;
        final error = oldValue - quantized.$2;
        final share = error / 8.0;

        _addError(working, columns, rows, x + 1, y, share);
        _addError(working, columns, rows, x + 2, y, share);
        _addError(working, columns, rows, x - 1, y + 1, share);
        _addError(working, columns, rows, x, y + 1, share);
        _addError(working, columns, rows, x + 1, y + 1, share);
        _addError(working, columns, rows, x, y + 2, share);
      }
    }

    return EInkFrame(
      columns: columns,
      rows: rows,
      levels: levels,
      source: source,
    );
  }

  static int _histogramPercentile(
    Uint32List histogram,
    int total,
    double percentile,
  ) {
    final target = (total * percentile).round();
    int seen = 0;
    for (int value = 0; value < histogram.length; value++) {
      seen += histogram[value];
      if (seen >= target) {
        return value;
      }
    }
    return 255;
  }

  static (int, double) _nearestPaperTone(double value) {
    if (value >= 216) {
      return (0, 242.0);
    }
    if (value >= 142) {
      return (1, 188.0);
    }
    if (value >= 66) {
      return (2, 103.0);
    }
    return (3, 20.0);
  }

  static void _addError(
    Float64List values,
    int columns,
    int rows,
    int x,
    int y,
    double error,
  ) {
    if (x < 0 || y < 0 || x >= columns || y >= rows) {
      return;
    }
    final index = (y * columns) + x;
    values[index] = (values[index] + error).clamp(0.0, 255.0);
  }
}

class EInkFrameDecoder {
  EInkFrameDecoder._();

  static Future<EInkFrame> decodeAsset({
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

    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final coverScale = math.max(
        columns / descriptor.width,
        rows / descriptor.height,
      );
      final decodeWidth = math.max(columns, (descriptor.width * coverScale).ceil());
      final decodeHeight = math.max(rows, (descriptor.height * coverScale).ceil());

      codec = await descriptor.instantiateCodec(
        targetWidth: decodeWidth,
        targetHeight: decodeHeight,
      );
      final frame = await codec.getNextFrame();
      decodedImage = frame.image;

      final sourceAspect = decodedImage.width / decodedImage.height;
      final targetAspect = columns / rows;
      Rect sourceRect;
      if (sourceAspect > targetAspect) {
        final sourceWidth = decodedImage.height * targetAspect;
        final left = (decodedImage.width - sourceWidth) / 2;
        sourceRect = Rect.fromLTWH(
          left,
          0,
          sourceWidth,
          decodedImage.height.toDouble(),
        );
      } else {
        final sourceHeight = decodedImage.width / targetAspect;
        final top = (decodedImage.height - sourceHeight) / 2;
        sourceRect = Rect.fromLTWH(
          0,
          top,
          decodedImage.width.toDouble(),
          sourceHeight,
        );
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        decodedImage,
        sourceRect,
        Rect.fromLTWH(0, 0, columns.toDouble(), rows.toDouble()),
        Paint()..filterQuality = FilterQuality.medium,
      );
      final picture = recorder.endRecording();
      sampledImage = await picture.toImage(columns, rows);
      picture.dispose();

      final byteData = await sampledImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) {
        throw StateError('Unable to read pixels from $assetPath');
      }

      return EInkProcessor.processRgba(
        rgba: byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
        columns: columns,
        rows: rows,
        source: assetPath,
      );
    } finally {
      sampledImage?.dispose();
      decodedImage?.dispose();
      codec?.dispose();
      descriptor?.dispose();
    }
  }
}

class EInkAssetCatalog {
  EInkAssetCatalog._();

  static const Set<String> _extensions = {
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
      return _extensions.any(lower.endsWith);
    }).toList()
      ..sort();
    return assets;
  }
}

class _RenderableEInkFrame {
  _RenderableEInkFrame(this.frame) : paths = _buildPaths(frame);

  final EInkFrame frame;
  final List<Path> paths;

  static List<Path> _buildPaths(EInkFrame frame) {
    final paths = List<Path>.generate(4, (_) => Path());
    for (int y = 0; y < frame.rows; y++) {
      for (int x = 0; x < frame.columns; x++) {
        final level = frame.levels[(y * frame.columns) + x];
        if (level == 0) {
          continue;
        }
        paths[level].addRect(
          Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
        );
      }
    }
    return paths;
  }
}

class EInkImageSlideshow extends StatefulWidget {
  const EInkImageSlideshow({
    super.key,
    this.assetDirectory = 'assets/slideshow/',
    this.sampleSize = 2.0,
    this.holdDuration = const Duration(milliseconds: 6500),
    this.transitionDuration = const Duration(milliseconds: 1250),
    this.reducedMotion = false,
  });

  final String assetDirectory;
  final double sampleSize;
  final Duration holdDuration;
  final Duration transitionDuration;
  final bool reducedMotion;

  @override
  State<EInkImageSlideshow> createState() => _EInkImageSlideshowState();
}

class _EInkImageSlideshowState extends State<EInkImageSlideshow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _holdTimer;
  List<String> _assets = const [];
  final Map<int, _RenderableEInkFrame> _cache = {};

  _RenderableEInkFrame? _current;
  _RenderableEInkFrame? _next;
  int _currentIndex = 0;
  int _nextIndex = 0;
  int _columns = 0;
  int _rows = 0;
  int _generation = 0;
  int _transitionSeed = 0;
  bool _initialReveal = true;
  bool _loading = false;

  int get _frameCount => _assets.isEmpty ? 3 : _assets.length;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _effectiveTransitionDuration,
    )..addStatusListener(_handleStatus);
  }

  Duration get _effectiveTransitionDuration => widget.reducedMotion
      ? const Duration(milliseconds: 180)
      : widget.transitionDuration;

  @override
  void didUpdateWidget(covariant EInkImageSlideshow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transitionDuration != widget.transitionDuration ||
        oldWidget.reducedMotion != widget.reducedMotion) {
      _controller.duration = _effectiveTransitionDuration;
    }
    if (oldWidget.assetDirectory != widget.assetDirectory ||
        oldWidget.sampleSize != widget.sampleSize) {
      _requestReload();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller
      ..removeStatusListener(_handleStatus)
      ..dispose();
    super.dispose();
  }

  void _requestSize(int columns, int rows) {
    if (columns == _columns && rows == _rows) {
      return;
    }
    _columns = columns;
    _rows = rows;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _load(columns, rows);
      }
    });
  }

  void _requestReload() {
    if (_columns <= 0 || _rows <= 0) {
      return;
    }
    final columns = _columns;
    final rows = _rows;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _load(columns, rows);
      }
    });
  }

  Future<void> _load(int columns, int rows) async {
    final generation = ++_generation;
    _holdTimer?.cancel();
    _controller.stop();
    _loading = true;
    _cache.clear();

    final bundle = DefaultAssetBundle.of(context);
    final assets = await EInkAssetCatalog.discover(
      bundle,
      directory: widget.assetDirectory,
    );
    if (!mounted || generation != _generation) {
      return;
    }

    _assets = assets;
    final first = await _loadFrame(0, generation);
    if (!mounted || generation != _generation) {
      return;
    }

    setState(() {
      _currentIndex = 0;
      _nextIndex = 0;
      _current = first;
      _next = null;
      _initialReveal = true;
      _loading = false;
      _transitionSeed++;
      _controller.reset();
    });
    _controller.forward(from: 0);
    unawaited(_prefetch((_currentIndex + 1) % _frameCount, generation));
  }

  Future<_RenderableEInkFrame> _loadFrame(int index, int generation) async {
    final cached = _cache[index];
    if (cached != null) {
      return cached;
    }

    EInkFrame frame;
    if (_assets.isEmpty) {
      frame = EInkFrame.demo(
        columns: _columns,
        rows: _rows,
        variant: index,
      );
    } else {
      frame = await EInkFrameDecoder.decodeAsset(
        bundle: DefaultAssetBundle.of(context),
        assetPath: _assets[index],
        columns: _columns,
        rows: _rows,
      );
    }

    if (!mounted || generation != _generation) {
      return _RenderableEInkFrame(frame);
    }

    final renderable = _RenderableEInkFrame(frame);
    _cache[index] = renderable;
    _trimCache({
      _currentIndex,
      index,
      (index + 1) % _frameCount,
    });
    return renderable;
  }

  Future<void> _prefetch(int index, int generation) async {
    try {
      await _loadFrame(index, generation);
    } catch (error) {
      debugPrint('E-ink prefetch skipped frame $index: $error');
    }
  }

  void _trimCache(Set<int> keep) {
    if (_cache.length <= 4) {
      return;
    }
    final removable = _cache.keys.where((key) => !keep.contains(key)).toList();
    for (final key in removable) {
      _cache.remove(key);
      if (_cache.length <= 4) {
        break;
      }
    }
  }

  void _scheduleNext() {
    _holdTimer?.cancel();
    if (!mounted || _loading || _frameCount < 2) {
      return;
    }
    _holdTimer = Timer(widget.holdDuration, _beginTransition);
  }

  Future<void> _beginTransition() async {
    if (!mounted || _controller.isAnimating || _loading || _frameCount < 2) {
      return;
    }
    final nextIndex = (_currentIndex + 1) % _frameCount;
    final generation = _generation;
    final next = await _loadFrame(nextIndex, generation);
    if (!mounted || generation != _generation) {
      return;
    }
    setState(() {
      _nextIndex = nextIndex;
      _next = next;
      _transitionSeed++;
    });
    _controller.forward(from: 0);
  }

  void _handleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) {
      return;
    }

    if (_initialReveal) {
      setState(() {
        _initialReveal = false;
        _controller.reset();
      });
      _scheduleNext();
      return;
    }

    setState(() {
      _currentIndex = _nextIndex;
      _current = _next ?? _current;
      _next = null;
      _controller.reset();
    });
    _scheduleNext();
    unawaited(
      _prefetch((_currentIndex + 1) % _frameCount, _generation),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (!width.isFinite ||
            !height.isFinite ||
            width <= 0 ||
            height <= 0) {
          return const SizedBox.shrink();
        }

        final sample = widget.sampleSize.clamp(1.5, 4.0).toDouble();
        final columns = math.max(100, (width / sample).round()).toInt();
        final rows = math.max(70, (height / sample).round()).toInt();
        _requestSize(columns, rows);

        final current = _current;
        if (current == null ||
            current.frame.columns != columns ||
            current.frame.rows != rows) {
          return const ColoredBox(color: EInkPalette.paper);
        }

        return RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                size: Size(width, height),
                painter: _EInkSlideshowPainter(
                  from: _initialReveal ? null : current,
                  to: _initialReveal ? current : _next,
                  progress: _controller.value,
                  seed: _transitionSeed,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _EInkSlideshowPainter extends CustomPainter {
  const _EInkSlideshowPainter({
    required this.from,
    required this.to,
    required this.progress,
    required this.seed,
  });

  final _RenderableEInkFrame? from;
  final _RenderableEInkFrame? to;
  final double progress;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = EInkPalette.paper);

    if (from != null) {
      _drawFrame(canvas, size, from!);
    }

    final target = to;
    if (target == null || progress <= 0) {
      return;
    }

    final reveal = _revealPath(size, progress, seed);
    if (progress > 0.04 && progress < 0.97) {
      final outer = _revealPath(size, (progress + 0.035).clamp(0.0, 1.0), seed);
      final inner = _revealPath(size, (progress - 0.025).clamp(0.0, 1.0), seed);
      final band = Path.combine(PathOperation.difference, outer, inner);
      canvas.save();
      canvas.clipPath(band);
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0x4077736A),
      );
      canvas.restore();
    }

    canvas.save();
    canvas.clipPath(reveal);
    _drawFrame(canvas, size, target);
    canvas.restore();
  }

  void _drawFrame(Canvas canvas, Size size, _RenderableEInkFrame renderable) {
    final frame = renderable.frame;
    canvas.save();
    canvas.scale(size.width / frame.columns, size.height / frame.rows);
    for (int level = 1; level <= 3; level++) {
      canvas.drawPath(
        renderable.paths[level],
        Paint()
          ..isAntiAlias = false
          ..color = EInkPalette.forLevel(level),
      );
    }
    canvas.restore();
  }

  Path _revealPath(Size size, double value, int salt) {
    if (value <= 0) {
      return Path();
    }
    if (value >= 1) {
      return Path()..addRect(Offset.zero & size);
    }

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0);
    const segment = 24.0;
    for (double x = size.width; x >= 0; x -= segment) {
      path.lineTo(x, _boundaryY(size, x, value, salt));
    }
    path
      ..lineTo(0, _boundaryY(size, 0, value, salt))
      ..close();
    return path;
  }

  double _boundaryY(Size size, double x, double value, int salt) {
    final phase = (x * 0.035) + (salt * 1.37);
    final wave = math.sin(phase) * 7.0;
    final hash = _hash01(x.round(), salt) * 10.0 - 5.0;
    final advance = ((value * 1.12) - 0.06) * size.height;
    return (advance + wave + hash).clamp(0.0, size.height);
  }

  double _hash01(int x, int salt) {
    var value = (x * 374761393) ^ (salt * 668265263);
    value = (value ^ (value >> 13)) * 1274126177;
    value ^= value >> 16;
    return (value & 0xFFFF) / 65535.0;
  }

  @override
  bool shouldRepaint(covariant _EInkSlideshowPainter oldDelegate) {
    return oldDelegate.from != from ||
        oldDelegate.to != to ||
        oldDelegate.progress != progress ||
        oldDelegate.seed != seed;
  }
}
