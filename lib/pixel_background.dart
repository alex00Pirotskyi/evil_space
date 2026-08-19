import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:evil_space/app_route.dart';
import 'package:evil_space/config.dart';
import 'package:evil_space/pixel_image_slideshow.dart';

enum PixelTransitionStyle {
  runway,
  diagonal,
  centerOut,
}

enum PixelBackgroundScene {
  home('assets/backgrounds/home/'),
  feed('assets/backgrounds/feed/'),
  desks('assets/backgrounds/desks/'),
  office('assets/backgrounds/office/'),
  studio('assets/backgrounds/studio/'),
  contact('assets/backgrounds/contact/');

  const PixelBackgroundScene(this.directory);

  final String directory;

  static PixelBackgroundScene fromRoute(AppRoute route) {
    return switch (route) {
      AppRoute.home => PixelBackgroundScene.home,
      AppRoute.feed => PixelBackgroundScene.feed,
      AppRoute.desks || AppRoute.map || AppRoute.book =>
        PixelBackgroundScene.desks,
      AppRoute.office => PixelBackgroundScene.office,
      AppRoute.studio => PixelBackgroundScene.studio,
      AppRoute.contact || AppRoute.qr => PixelBackgroundScene.contact,
      AppRoute.gallery => PixelBackgroundScene.home,
    };
  }
}

class LivingPixelBackground extends StatefulWidget {
  const LivingPixelBackground({
    super.key,
    required this.scene,
    this.fallbackDirectory = 'assets/slideshow/',
    this.pixelCellSize = 8,
    this.holdDuration = const Duration(milliseconds: slideshowHoldMs),
    this.transitionDuration =
        const Duration(milliseconds: slideshowTransitionMs),
    this.transitionStyle = PixelTransitionStyle.runway,
    this.brightness = 0.62,
    this.reducedMotion = false,
  });

  final PixelBackgroundScene scene;
  final String fallbackDirectory;
  final double pixelCellSize;
  final Duration holdDuration;
  final Duration transitionDuration;
  final PixelTransitionStyle transitionStyle;
  final double brightness;
  final bool reducedMotion;

  @override
  State<LivingPixelBackground> createState() => _LivingPixelBackgroundState();
}

class _LivingPixelBackgroundState extends State<LivingPixelBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _holdTimer;

  Rgb565Frame? _currentFrame;
  Rgb565Frame? _nextFrame;
  List<Rgb565Frame> _sceneFrames = const [];
  List<Rgb565Frame>? _pendingSceneFrames;

  int _sceneIndex = 0;
  int _nextSceneIndex = 0;
  int _loadGeneration = 0;
  int _columns = 0;
  int _rows = 0;
  int _transitionSeed = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _effectiveTransitionDuration,
    )..addStatusListener(_handleTransitionStatus);
  }

  Duration get _effectiveTransitionDuration => widget.reducedMotion
      ? const Duration(milliseconds: 180)
      : widget.transitionDuration;

  @override
  void didUpdateWidget(covariant LivingPixelBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transitionDuration != widget.transitionDuration ||
        oldWidget.reducedMotion != widget.reducedMotion) {
      _controller.duration = _effectiveTransitionDuration;
    }

    if (oldWidget.scene != widget.scene ||
        oldWidget.fallbackDirectory != widget.fallbackDirectory) {
      _requestSceneReload();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller
      ..removeStatusListener(_handleTransitionStatus)
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
        _loadScene(columns, rows, preserveCurrent: false);
      }
    });
  }

  void _requestSceneReload() {
    if (_columns <= 0 || _rows <= 0) {
      return;
    }
    final columns = _columns;
    final rows = _rows;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadScene(columns, rows, preserveCurrent: true);
      }
    });
  }

  Future<List<String>> _discoverSceneAssets(AssetBundle bundle) async {
    final sceneAssets = await PixelAssetCatalog.discover(
      bundle,
      directory: widget.scene.directory,
    );
    if (sceneAssets.isNotEmpty) {
      return sceneAssets;
    }
    return PixelAssetCatalog.discover(
      bundle,
      directory: widget.fallbackDirectory,
    );
  }

  Future<void> _loadScene(
    int columns,
    int rows, {
    required bool preserveCurrent,
  }) async {
    final generation = ++_loadGeneration;
    final bundle = DefaultAssetBundle.of(context);

    _holdTimer?.cancel();
    _controller.stop();
    _loading = true;

    final assets = await _discoverSceneAssets(bundle);
    if (!mounted || generation != _loadGeneration) {
      return;
    }

    final frames = <Rgb565Frame>[];
    for (final asset in assets) {
      try {
        frames.add(
          await PixelFrameDecoder.decodeAsset(
            bundle: bundle,
            assetPath: asset,
            columns: columns,
            rows: rows,
          ),
        );
      } catch (error) {
        debugPrint('Living background skipped $asset: $error');
      }
      if (!mounted || generation != _loadGeneration) {
        return;
      }
    }

    if (frames.isEmpty) {
      final baseVariant = widget.scene.index * 3;
      frames.addAll([
        Rgb565Frame.demo(
          columns: columns,
          rows: rows,
          variant: baseVariant,
        ),
        Rgb565Frame.demo(
          columns: columns,
          rows: rows,
          variant: baseVariant + 1,
        ),
        Rgb565Frame.demo(
          columns: columns,
          rows: rows,
          variant: baseVariant + 2,
        ),
      ]);
    }

    if (!mounted || generation != _loadGeneration) {
      return;
    }

    _loading = false;

    final canMorph = preserveCurrent &&
        _currentFrame != null &&
        _currentFrame!.columns == columns &&
        _currentFrame!.rows == rows;

    if (canMorph) {
      setState(() {
        _pendingSceneFrames = frames;
        _nextFrame = frames.first;
        _nextSceneIndex = 0;
        _transitionSeed++;
      });
      _controller.forward(from: 0);
      return;
    }

    setState(() {
      _sceneFrames = frames;
      _pendingSceneFrames = null;
      _sceneIndex = 0;
      _nextSceneIndex = 0;
      _currentFrame = frames.first;
      _nextFrame = null;
      _controller.reset();
    });
    _scheduleNext();
  }

  void _scheduleNext() {
    _holdTimer?.cancel();
    if (!mounted || _sceneFrames.length < 2 || _loading) {
      return;
    }
    _holdTimer = Timer(widget.holdDuration, _beginSlideshowTransition);
  }

  void _beginSlideshowTransition() {
    if (!mounted ||
        _controller.isAnimating ||
        _sceneFrames.length < 2 ||
        _pendingSceneFrames != null) {
      return;
    }

    final next = (_sceneIndex + 1) % _sceneFrames.length;
    setState(() {
      _nextSceneIndex = next;
      _nextFrame = _sceneFrames[next];
      _transitionSeed++;
    });
    _controller.forward(from: 0);
  }

  void _handleTransitionStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) {
      return;
    }

    setState(() {
      _currentFrame = _nextFrame ?? _currentFrame;
      _nextFrame = null;

      if (_pendingSceneFrames != null) {
        _sceneFrames = _pendingSceneFrames!;
        _pendingSceneFrames = null;
        _sceneIndex = 0;
        _nextSceneIndex = 0;
      } else {
        _sceneIndex = _nextSceneIndex;
      }
      _controller.reset();
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

        final cell = math.max(4.0, widget.pixelCellSize);
        final columns = math.max(24, (width / cell).round()).toInt();
        final rows = math.max(16, (height / cell).round()).toInt();
        _requestSize(columns, rows);

        final current = _currentFrame;
        if (current == null ||
            current.columns != columns ||
            current.rows != rows) {
          return const ColoredBox(color: Color(0xFF171717));
        }

        return RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                size: Size(width, height),
                painter: LivingPixelBackgroundPainter(
                  from: current,
                  to: _nextFrame,
                  progress: _controller.value,
                  style: widget.transitionStyle,
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

class LivingPixelBackgroundPainter extends CustomPainter {
  LivingPixelBackgroundPainter({
    required this.from,
    required this.to,
    required this.progress,
    required this.style,
    required this.seed,
    required this.brightness,
    required this.reducedMotion,
  });

  final Rgb565Frame from;
  final Rgb565Frame? to;
  final double progress;
  final PixelTransitionStyle style;
  final int seed;
  final double brightness;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final columns = from.columns;
    final rows = from.rows;
    final cellWidth = size.width / columns;
    final cellHeight = size.height / rows;
    final paint = Paint();
    final target = to;

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < columns; x++) {
        final index = (y * columns) + x;
        final fromValue = from.pixels[index];
        final toValue = target == null ? fromValue : target.pixels[index];
        final localProgress = target == null
            ? 0.0
            : _pixelProgress(x, y, columns, rows, progress);
        final value = target == null
            ? fromValue
            : Rgb565.lerp(fromValue, toValue, localProgress);

        final red = (Rgb565.red8(value) * brightness).round().clamp(0, 255);
        final green =
            (Rgb565.green8(value) * brightness).round().clamp(0, 255);
        final blue =
            (Rgb565.blue8(value) * brightness).round().clamp(0, 255);
        paint.color = Color.fromARGB(255, red, green, blue);

        final left = x * cellWidth;
        final top = y * cellHeight;
        canvas.drawRect(
          Rect.fromLTWH(
            left,
            top,
            cellWidth + 0.35,
            cellHeight + 0.35,
          ),
          paint,
        );
      }
    }
  }

  double _pixelProgress(
    int x,
    int y,
    int columns,
    int rows,
    double globalProgress,
  ) {
    if (reducedMotion) {
      return globalProgress;
    }

    final nx = columns <= 1 ? 0.0 : x / (columns - 1);
    final ny = rows <= 1 ? 0.0 : y / (rows - 1);
    final jitter = _hash01(x, y, seed) * 0.16;

    final threshold = switch (style) {
      PixelTransitionStyle.runway => (nx * 0.72) + (ny * 0.06) + jitter,
      PixelTransitionStyle.diagonal =>
        (((nx + ny) * 0.38) + (jitter * 0.9)),
      PixelTransitionStyle.centerOut =>
        (_normalizedRadius(nx, ny) * 0.72) + jitter,
    };

    const feather = 0.28;
    final start = threshold - feather;
    return ((globalProgress - start) / feather).clamp(0.0, 1.0);
  }

  double _normalizedRadius(double nx, double ny) {
    final dx = nx - 0.5;
    final dy = ny - 0.5;
    return (math.sqrt((dx * dx) + (dy * dy)) / math.sqrt(0.5))
        .clamp(0.0, 1.0);
  }

  double _hash01(int x, int y, int salt) {
    var value = (x * 374761393) ^ (y * 668265263) ^ (salt * 1442695041);
    value = (value ^ (value >> 13)) * 1274126177;
    value ^= value >> 16;
    return (value & 0xFFFF) / 65535.0;
  }

  @override
  bool shouldRepaint(covariant LivingPixelBackgroundPainter oldDelegate) {
    return oldDelegate.from != from ||
        oldDelegate.to != to ||
        oldDelegate.progress != progress ||
        oldDelegate.style != style ||
        oldDelegate.seed != seed ||
        oldDelegate.brightness != brightness ||
        oldDelegate.reducedMotion != reducedMotion;
  }
}
