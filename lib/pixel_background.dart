import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:evil_space/config.dart';
import 'package:evil_space/pixel_image_slideshow.dart';

class LivingPixelBackground extends StatefulWidget {
  const LivingPixelBackground({
    super.key,
    this.assetDirectory = 'assets/slideshow/',
    this.pixelCellSize = 5,
    this.holdDuration = const Duration(milliseconds: 6500),
    this.transitionDuration =
        const Duration(milliseconds: slideshowTransitionMs),
    this.brightness = 0.68,
    this.reducedMotion = false,
  });

  final String assetDirectory;
  final double pixelCellSize;
  final Duration holdDuration;
  final Duration transitionDuration;
  final double brightness;
  final bool reducedMotion;

  @override
  State<LivingPixelBackground> createState() => _LivingPixelBackgroundState();
}

class _LivingPixelBackgroundState extends State<LivingPixelBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _transition;
  Timer? _holdTimer;

  List<Rgb565Frame> _frames = const [];
  int _currentIndex = 0;
  int _nextIndex = 0;
  int _transitionSeed = 0;
  int _loadGeneration = 0;
  int _columns = 0;
  int _rows = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _transition = AnimationController(
      vsync: this,
      duration: _effectiveTransitionDuration,
    )..addStatusListener(_handleTransitionStatus);
  }

  Duration get _effectiveTransitionDuration => widget.reducedMotion
      ? const Duration(milliseconds: 160)
      : widget.transitionDuration;

  @override
  void didUpdateWidget(covariant LivingPixelBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transitionDuration != widget.transitionDuration ||
        oldWidget.reducedMotion != widget.reducedMotion) {
      _transition.duration = _effectiveTransitionDuration;
    }
    if (oldWidget.assetDirectory != widget.assetDirectory) {
      _reloadCurrentSize();
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

  void _requestSize(int columns, int rows) {
    if (_columns == columns && _rows == rows) {
      return;
    }
    _columns = columns;
    _rows = rows;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadFrames(columns, rows);
      }
    });
  }

  void _reloadCurrentSize() {
    if (_columns <= 0 || _rows <= 0) {
      return;
    }
    final columns = _columns;
    final rows = _rows;
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
    _loading = true;

    final paths = await PixelAssetCatalog.discover(
      bundle,
      directory: widget.assetDirectory,
    );
    if (!mounted || generation != _loadGeneration) {
      return;
    }

    final loaded = <Rgb565Frame>[];
    for (final path in paths) {
      try {
        loaded.add(
          await PixelFrameDecoder.decodeAsset(
            bundle: bundle,
            assetPath: path,
            columns: columns,
            rows: rows,
          ),
        );
      } catch (error) {
        debugPrint('Background skipped $path: $error');
      }
      if (!mounted || generation != _loadGeneration) {
        return;
      }
    }

    if (loaded.isEmpty) {
      loaded.addAll([
        Rgb565Frame.demo(columns: columns, rows: rows, variant: 0),
        Rgb565Frame.demo(columns: columns, rows: rows, variant: 1),
        Rgb565Frame.demo(columns: columns, rows: rows, variant: 2),
      ]);
    }

    if (!mounted || generation != _loadGeneration) {
      return;
    }

    setState(() {
      _frames = loaded;
      _currentIndex = 0;
      _nextIndex = 0;
      _transitionSeed = 0;
      _loading = false;
      _transition.reset();
    });
    _scheduleNext();
  }

  void _scheduleNext() {
    _holdTimer?.cancel();
    if (!mounted || _frames.length < 2 || _loading) {
      return;
    }
    _holdTimer = Timer(widget.holdDuration, _beginTransition);
  }

  void _beginTransition() {
    if (!mounted || _transition.isAnimating || _frames.length < 2) {
      return;
    }
    setState(() {
      _nextIndex = (_currentIndex + 1) % _frames.length;
      _transitionSeed++;
    });
    _transition.forward(from: 0);
  }

  void _handleTransitionStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) {
      return;
    }
    setState(() {
      _currentIndex = _nextIndex;
      _transition.reset();
    });
    _scheduleNext();
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

        final cell = widget.pixelCellSize.clamp(3.0, 10.0).toDouble();
        final columns = math.max(32, (width / cell).round()).toInt();
        final rows = math.max(24, (height / cell).round()).toInt();
        _requestSize(columns, rows);

        if (_frames.isEmpty ||
            _frames.first.columns != columns ||
            _frames.first.rows != rows) {
          return const ColoredBox(color: Color(0xFF171717));
        }

        final current = _frames[_currentIndex];
        final next = _frames[_nextIndex];

        return RepaintBoundary(
          child: AnimatedBuilder(
            animation: _transition,
            builder: (context, _) {
              return CustomPaint(
                size: Size(width, height),
                painter: _LivingPixelPainter(
                  from: current,
                  to: next,
                  progress: _transition.value,
                  seed: _transitionSeed,
                  brightness: widget.brightness,
                  reducedMotion: widget.reducedMotion,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _LivingPixelPainter extends CustomPainter {
  const _LivingPixelPainter({
    required this.from,
    required this.to,
    required this.progress,
    required this.seed,
    required this.brightness,
    required this.reducedMotion,
  });

  final Rgb565Frame from;
  final Rgb565Frame to;
  final double progress;
  final int seed;
  final double brightness;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final columns = from.columns;
    final rows = from.rows;
    final cellWidth = size.width / columns;
    final cellHeight = size.height / rows;
    final paint = Paint()..isAntiAlias = false;

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < columns; x++) {
        final index = (y * columns) + x;
        final localProgress = _pixelProgress(x, y, columns, rows);
        final value = Rgb565.lerp(
          from.pixels[index],
          to.pixels[index],
          localProgress,
        );

        paint.color = Color.fromARGB(
          255,
          (Rgb565.red8(value) * brightness).round().clamp(0, 255),
          (Rgb565.green8(value) * brightness).round().clamp(0, 255),
          (Rgb565.blue8(value) * brightness).round().clamp(0, 255),
        );

        canvas.drawRect(
          Rect.fromLTWH(
            x * cellWidth,
            y * cellHeight,
            cellWidth + 0.35,
            cellHeight + 0.35,
          ),
          paint,
        );
      }
    }
  }

  double _pixelProgress(int x, int y, int columns, int rows) {
    if (progress <= 0) {
      return 0;
    }
    if (reducedMotion) {
      return progress;
    }

    final nx = columns <= 1 ? 0.0 : x / (columns - 1);
    final ny = rows <= 1 ? 0.0 : y / (rows - 1);
    final jitter = _hash01(x, y, seed) * 0.14;
    final threshold = (nx * 0.76) + (ny * 0.05) + jitter;
    const feather = 0.30;
    return ((progress - (threshold - feather)) / feather)
        .clamp(0.0, 1.0);
  }

  double _hash01(int x, int y, int salt) {
    var value = (x * 374761393) ^ (y * 668265263) ^ (salt * 1442695041);
    value = (value ^ (value >> 13)) * 1274126177;
    value ^= value >> 16;
    return (value & 0xFFFF) / 65535.0;
  }

  @override
  bool shouldRepaint(covariant _LivingPixelPainter oldDelegate) {
    return oldDelegate.from != from ||
        oldDelegate.to != to ||
        oldDelegate.progress != progress ||
        oldDelegate.seed != seed ||
        oldDelegate.brightness != brightness ||
        oldDelegate.reducedMotion != reducedMotion;
  }
}
