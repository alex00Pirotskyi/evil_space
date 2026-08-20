import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EInkPalette {
  EInkPalette._();

  static const Color paper = Color(0xFFF2F0E8);
  static const Color lightInk = Color(0xFFC8C4B9);
  static const Color midInk = Color(0xFF746F66);
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
        final value = 0.64 + (wave * 0.1) + (band * 0.07) - (ny * 0.1);
        final threshold = ((x * 17 + y * 29 + variant * 43) & 15) / 15.0;
        final level = value > 0.8
            ? 0
            : value > 0.6
                ? (threshold > 0.78 ? 2 : 1)
                : value > 0.38
                    ? (threshold > 0.65 ? 3 : 2)
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

class EInkTargetResolution {
  const EInkTargetResolution(this.columns, this.rows);

  final int columns;
  final int rows;

  String get cacheKey => '${columns}x$rows';
}

class EInkResolutionPolicy {
  EInkResolutionPolicy._();

  static EInkTargetResolution resolve({
    required Size logicalSize,
    required double devicePixelRatio,
    double qualityFactor = 1.05,
    int maxDimension = 1536,
    int maxPixels = 1250000,
    int bucket = 32,
  }) {
    final width = logicalSize.width.isFinite ? logicalSize.width : 0.0;
    final height = logicalSize.height.isFinite ? logicalSize.height : 0.0;
    if (width <= 0 || height <= 0) {
      return const EInkTargetResolution(320, 200);
    }

    final dpr = devicePixelRatio.isFinite
        ? devicePixelRatio.clamp(1.0, 2.0).toDouble()
        : 1.0;
    final aspect = width / height;

    double columns = width * dpr * qualityFactor;
    double rows = height * dpr * qualityFactor;

    final dimensionScale = math.min(
      1.0,
      maxDimension / math.max(columns, rows),
    );
    final pixelScale = math.min(
      1.0,
      math.sqrt(maxPixels / math.max(1.0, columns * rows)),
    );
    final scale = math.min(dimensionScale, pixelScale);
    columns *= scale;
    rows *= scale;

    var bucketedColumns = math.max(
      256,
      ((columns / bucket).round() * bucket),
    );
    var bucketedRows = math.max(160, (bucketedColumns / aspect).round());

    if (bucketedRows > maxDimension ||
        bucketedColumns * bucketedRows > maxPixels) {
      final dimensionCap = math.min(
        1.0,
        maxDimension / math.max(bucketedColumns, bucketedRows),
      );
      final pixelCap = math.min(
        1.0,
        math.sqrt(maxPixels / (bucketedColumns * bucketedRows)),
      );
      final cap = math.min(dimensionCap, pixelCap);
      bucketedColumns = math.max(256, (bucketedColumns * cap).floor());
      bucketedRows = math.max(160, (bucketedRows * cap).floor());
    }

    return EInkTargetResolution(bucketedColumns, bucketedRows);
  }
}

class EInkMaster {
  EInkMaster._({
    required this.width,
    required this.height,
    required this.packedLuminance,
    required this.processingVersion,
    this.source,
  });

  static const int headerSize = 16;
  static const int formatVersion = 1;

  final int width;
  final int height;
  final Uint8List packedLuminance;
  final int processingVersion;
  final String? source;

  factory EInkMaster.fromByteData(ByteData data, {String? source}) {
    if (data.lengthInBytes < headerSize) {
      throw const FormatException('E-ink master is shorter than its header');
    }
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (bytes[0] != 0x45 ||
        bytes[1] != 0x49 ||
        bytes[2] != 0x4E ||
        bytes[3] != 0x4B) {
      throw const FormatException('Invalid e-ink master magic');
    }
    if (bytes[4] != formatVersion || bytes[5] != 4) {
      throw const FormatException('Unsupported e-ink master format');
    }

    final header = ByteData.sublistView(bytes, 0, headerSize);
    final width = header.getUint16(6, Endian.big);
    final height = header.getUint16(8, Endian.big);
    final processingVersion = bytes[10];
    final compression = bytes[11];
    final payloadLength = header.getUint32(12, Endian.big);
    if (width <= 0 || height <= 0) {
      throw const FormatException('Invalid e-ink master dimensions');
    }
    if (payloadLength <= 0 || headerSize + payloadLength > bytes.length) {
      throw const FormatException('Invalid e-ink master payload length');
    }

    final payload = Uint8List.sublistView(
      bytes,
      headerSize,
      headerSize + payloadLength,
    );
    final unpacked = switch (compression) {
      0 => Uint8List.fromList(payload),
      1 => const ZLibDecoder().decodeBytes(payload),
      _ => throw const FormatException('Unsupported e-ink master compression'),
    };
    final expectedLength = ((width * height) + 1) >> 1;
    if (unpacked.length != expectedLength) {
      throw FormatException(
        'E-ink master payload has ${unpacked.length} bytes; expected $expectedLength',
      );
    }

    return EInkMaster._(
      width: width,
      height: height,
      packedLuminance: unpacked,
      processingVersion: processingVersion,
      source: source,
    );
  }

  int luminanceAt(int x, int y) {
    final index = (y * width) + x;
    final byte = packedLuminance[index >> 1];
    final nibble = index.isEven ? (byte >> 4) : (byte & 0x0F);
    return nibble * 17;
  }
}

class EInkMasterLoader {
  EInkMasterLoader._();

  static Future<EInkMaster> loadAsset({
    required AssetBundle bundle,
    required String assetPath,
  }) async {
    final data = await bundle.load(assetPath);
    return EInkMaster.fromByteData(data, source: assetPath);
  }
}

class EInkMasterCatalog {
  EInkMasterCatalog._();

  static Future<List<String>> discover(
    AssetBundle bundle, {
    String directory = 'assets/eink/',
  }) async {
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    final assets = manifest
        .listAssets()
        .where(
          (asset) =>
              asset.startsWith(directory) &&
              asset.toLowerCase().endsWith('.einkm'),
        )
        .toList()
      ..sort();
    return assets;
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
    final luminance = Float64List(count);
    for (int index = 0; index < count; index++) {
      final offset = index * 4;
      final alpha = rgba[offset + 3] / 255.0;
      final red = (rgba[offset] * alpha) + (242 * (1 - alpha));
      final green = (rgba[offset + 1] * alpha) + (240 * (1 - alpha));
      final blue = (rgba[offset + 2] * alpha) + (232 * (1 - alpha));
      luminance[index] =
          (0.2126 * red) + (0.7152 * green) + (0.0722 * blue);
    }
    return _quantizeSync(
      luminance: luminance,
      columns: columns,
      rows: rows,
      source: source,
    );
  }

  static Future<EInkFrame> renderMaster({
    required EInkMaster master,
    required int requestedColumns,
    required int requestedRows,
  }) async {
    final targetAspect = requestedColumns / requestedRows;
    final sourceAspect = master.width / master.height;

    double cropLeft = 0;
    double cropTop = 0;
    double cropWidth = master.width.toDouble();
    double cropHeight = master.height.toDouble();
    if (sourceAspect > targetAspect) {
      cropWidth = master.height * targetAspect;
      cropLeft = (master.width - cropWidth) / 2;
    } else if (sourceAspect < targetAspect) {
      cropHeight = master.width / targetAspect;
      cropTop = (master.height - cropHeight) / 2;
    }

    final sourceScale = math.min(
      1.0,
      math.min(
        cropWidth / requestedColumns,
        cropHeight / requestedRows,
      ),
    );
    final columns = math.max(160, (requestedColumns * sourceScale).round());
    final rows = math.max(100, (requestedRows * sourceScale).round());
    final luminance = Float64List(columns * rows);

    for (int y = 0; y < rows; y++) {
      final sourceY = cropTop + (((y + 0.5) / rows) * cropHeight) - 0.5;
      final y0 = sourceY.floor().clamp(0, master.height - 1);
      final y1 = (y0 + 1).clamp(0, master.height - 1);
      final fy = (sourceY - y0).clamp(0.0, 1.0);

      for (int x = 0; x < columns; x++) {
        final sourceX = cropLeft + (((x + 0.5) / columns) * cropWidth) - 0.5;
        final x0 = sourceX.floor().clamp(0, master.width - 1);
        final x1 = (x0 + 1).clamp(0, master.width - 1);
        final fx = (sourceX - x0).clamp(0.0, 1.0);

        final top = _lerp(
          master.luminanceAt(x0, y0).toDouble(),
          master.luminanceAt(x1, y0).toDouble(),
          fx,
        );
        final bottom = _lerp(
          master.luminanceAt(x0, y1).toDouble(),
          master.luminanceAt(x1, y1).toDouble(),
          fx,
        );
        luminance[(y * columns) + x] = _lerp(top, bottom, fy);
      }
      if ((y & 31) == 31) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    return _quantizeAsync(
      luminance: luminance,
      columns: columns,
      rows: rows,
      source: master.source,
    );
  }

  static double _lerp(double a, double b, double t) => a + ((b - a) * t);

  static EInkFrame _quantizeSync({
    required Float64List luminance,
    required int columns,
    required int rows,
    String? source,
  }) {
    final normalized = _normalize(luminance);
    return _ditherSync(
      normalized: normalized,
      columns: columns,
      rows: rows,
      source: source,
    );
  }

  static Future<EInkFrame> _quantizeAsync({
    required Float64List luminance,
    required int columns,
    required int rows,
    String? source,
  }) async {
    final normalized = _normalize(luminance);
    await Future<void>.delayed(Duration.zero);

    final working = Float64List.fromList(normalized);
    final levels = Uint8List(columns * rows);
    for (int y = 0; y < rows; y++) {
      final leftToRight = y.isEven;
      for (int step = 0; step < columns; step++) {
        final x = leftToRight ? step : columns - 1 - step;
        final direction = leftToRight ? 1 : -1;
        final index = (y * columns) + x;
        final value = working[index].clamp(0.0, 255.0).toDouble();
        final quantized = _nearestPaperTone(value);
        levels[index] = quantized.$1;

        final midtone =
            (1.0 - ((value - 127.5).abs() / 127.5)).clamp(0.0, 1.0);
        final strength = 0.34 + (0.25 * midtone);
        final share = ((value - quantized.$2) * strength) / 8.0;
        _addError(working, columns, rows, x + direction, y, share);
        _addError(working, columns, rows, x + (2 * direction), y, share);
        _addError(working, columns, rows, x - direction, y + 1, share);
        _addError(working, columns, rows, x, y + 1, share);
        _addError(working, columns, rows, x + direction, y + 1, share);
        _addError(working, columns, rows, x, y + 2, share);
      }
      if ((y & 31) == 31) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    return EInkFrame(
      columns: columns,
      rows: rows,
      levels: levels,
      source: source,
    );
  }

  static Float64List _normalize(Float64List luminance) {
    final histogram = Uint32List(256);
    for (final value in luminance) {
      histogram[value.round().clamp(0, 255)]++;
    }
    final low = _histogramPercentile(histogram, luminance.length, 0.015);
    final high = _histogramPercentile(histogram, luminance.length, 0.985);
    final span = math.max(36.0, (high - low).toDouble());
    final normalized = Float64List(luminance.length);
    for (int index = 0; index < luminance.length; index++) {
      var value = ((luminance[index] - low) / span).clamp(0.0, 1.0);
      value = ((value - 0.5) * 1.08 + 0.5).clamp(0.0, 1.0);
      value = math.pow(value, 0.98).toDouble();
      normalized[index] = value * 255.0;
    }
    return normalized;
  }

  static EInkFrame _ditherSync({
    required Float64List normalized,
    required int columns,
    required int rows,
    String? source,
  }) {
    final working = Float64List.fromList(normalized);
    final levels = Uint8List(columns * rows);
    for (int y = 0; y < rows; y++) {
      final leftToRight = y.isEven;
      for (int step = 0; step < columns; step++) {
        final x = leftToRight ? step : columns - 1 - step;
        final direction = leftToRight ? 1 : -1;
        final index = (y * columns) + x;
        final value = working[index].clamp(0.0, 255.0).toDouble();
        final quantized = _nearestPaperTone(value);
        levels[index] = quantized.$1;
        final midtone =
            (1.0 - ((value - 127.5).abs() / 127.5)).clamp(0.0, 1.0);
        final strength = 0.34 + (0.25 * midtone);
        final share = ((value - quantized.$2) * strength) / 8.0;
        _addError(working, columns, rows, x + direction, y, share);
        _addError(working, columns, rows, x + (2 * direction), y, share);
        _addError(working, columns, rows, x - direction, y + 1, share);
        _addError(working, columns, rows, x, y + 1, share);
        _addError(working, columns, rows, x + direction, y + 1, share);
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
    final target = math.max(1, (total * percentile).round());
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
    if (value >= 151) {
      return (1, 190.0);
    }
    if (value >= 68) {
      return (2, 112.0);
    }
    return (3, 23.0);
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
        paths[level].addRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1));
      }
    }
    return paths;
  }
}

class EInkImageSlideshow extends StatefulWidget {
  const EInkImageSlideshow({
    super.key,
    this.assetDirectory = 'assets/eink/',
    double? sampleSize,
    this.holdDuration = const Duration(milliseconds: 6500),
    this.transitionDuration = const Duration(milliseconds: 1250),
    this.reducedMotion = false,
  });

  final String assetDirectory;
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
  bool _catalogLoaded = false;
  final Map<int, EInkMaster> _masterCache = {};
  final Map<String, _RenderableEInkFrame> _frameCache = {};
  final Set<int> _failedAssets = {};

  _RenderableEInkFrame? _current;
  _RenderableEInkFrame? _next;
  int _currentIndex = 0;
  int _nextIndex = 0;
  int _targetColumns = 0;
  int _targetRows = 0;
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
      ? const Duration(milliseconds: 160)
      : widget.transitionDuration;

  @override
  void didUpdateWidget(covariant EInkImageSlideshow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transitionDuration != widget.transitionDuration ||
        oldWidget.reducedMotion != widget.reducedMotion) {
      _controller.duration = _effectiveTransitionDuration;
    }
    if (oldWidget.assetDirectory != widget.assetDirectory) {
      _catalogLoaded = false;
      _assets = const [];
      _masterCache.clear();
      _frameCache.clear();
      _failedAssets.clear();
      _scheduleReload();
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

  void _requestResolution(EInkTargetResolution target) {
    if (_targetColumns == target.columns && _targetRows == target.rows) {
      return;
    }
    _targetColumns = target.columns;
    _targetRows = target.rows;
    _scheduleReload();
  }

  void _scheduleReload() {
    if (_targetColumns <= 0 || _targetRows <= 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_reloadForResolution());
      }
    });
  }

  _RenderableEInkFrame _demoFrame(int variant) {
    return _RenderableEInkFrame(
      EInkFrame.demo(
        columns: math.min(_targetColumns, 720),
        rows: math.min(_targetRows, 450),
        variant: variant,
      ),
    );
  }

  Future<void> _reloadForResolution() async {
    final generation = ++_generation;
    _holdTimer?.cancel();
    _controller.stop();
    _loading = true;

    if (_current == null) {
      setState(() {
        _current = _demoFrame(0);
        _initialReveal = false;
      });
    }

    final bundle = DefaultAssetBundle.of(context);
    if (!_catalogLoaded) {
      try {
        _assets = await EInkMasterCatalog.discover(
          bundle,
          directory: widget.assetDirectory,
        );
      } catch (error) {
        debugPrint('E-ink master discovery failed: $error');
        _assets = const [];
      }
      _catalogLoaded = true;
    }
    if (!mounted || generation != _generation) {
      return;
    }

    _RenderableEInkFrame? frame;
    int resolvedIndex = _currentIndex.clamp(0, math.max(0, _frameCount - 1));
    if (_assets.isNotEmpty) {
      for (int offset = 0; offset < _assets.length; offset++) {
        final index = (resolvedIndex + offset) % _assets.length;
        frame = await _loadFrame(index, generation);
        if (!mounted || generation != _generation) {
          return;
        }
        if (frame != null) {
          resolvedIndex = index;
          break;
        }
      }
    } else {
      frame = _demoFrame(resolvedIndex % 3);
    }

    frame ??= _demoFrame(0);
    setState(() {
      _currentIndex = resolvedIndex;
      _nextIndex = resolvedIndex;
      _current = frame;
      _next = null;
      _initialReveal = true;
      _loading = false;
      _transitionSeed++;
      _controller.reset();
    });
    _controller.forward(from: 0);
    unawaited(_prefetchNext(generation));
  }

  Future<EInkMaster?> _loadMaster(int index) async {
    final cached = _masterCache[index];
    if (cached != null) {
      return cached;
    }
    if (_failedAssets.contains(index)) {
      return null;
    }
    try {
      final master = await EInkMasterLoader.loadAsset(
        bundle: DefaultAssetBundle.of(context),
        assetPath: _assets[index],
      );
      _masterCache[index] = master;
      while (_masterCache.length > 3) {
        final removable = _masterCache.keys.firstWhere(
          (key) => key != _currentIndex && key != index,
          orElse: () => -1,
        );
        if (removable < 0) {
          break;
        }
        _masterCache.remove(removable);
      }
      return master;
    } catch (error) {
      _failedAssets.add(index);
      debugPrint('E-ink master failed ${_assets[index]}: $error');
      return null;
    }
  }

  Future<_RenderableEInkFrame?> _loadFrame(
    int index,
    int generation,
  ) async {
    final cacheKey = '$index:${_targetColumns}x$_targetRows:v4';
    final cached = _frameCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    if (_assets.isEmpty) {
      return _demoFrame(index % 3);
    }
    final master = await _loadMaster(index);
    if (master == null || !mounted || generation != _generation) {
      return null;
    }

    try {
      final frame = await EInkProcessor.renderMaster(
        master: master,
        requestedColumns: _targetColumns,
        requestedRows: _targetRows,
      );
      if (!mounted || generation != _generation) {
        return null;
      }
      final renderable = _RenderableEInkFrame(frame);
      _frameCache[cacheKey] = renderable;
      _trimFrameCache({cacheKey});
      return renderable;
    } catch (error) {
      debugPrint('E-ink render failed ${_assets[index]}: $error');
      return null;
    }
  }

  void _trimFrameCache(Set<String> keep) {
    if (_frameCache.length <= 4) {
      return;
    }
    final removable = _frameCache.keys.where((key) => !keep.contains(key)).toList();
    for (final key in removable) {
      _frameCache.remove(key);
      if (_frameCache.length <= 4) {
        break;
      }
    }
  }

  Future<(int, _RenderableEInkFrame)?> _findNextFrame(
    int generation,
  ) async {
    if (_assets.isEmpty) {
      final index = (_currentIndex + 1) % 3;
      return (index, _demoFrame(index));
    }
    if (_assets.length <= 1) {
      return null;
    }
    for (int offset = 1; offset < _assets.length; offset++) {
      final index = (_currentIndex + offset) % _assets.length;
      final frame = await _loadFrame(index, generation);
      if (!mounted || generation != _generation) {
        return null;
      }
      if (frame != null) {
        return (index, frame);
      }
    }
    return null;
  }

  Future<void> _prefetchNext(int generation) async {
    try {
      await _findNextFrame(generation);
    } catch (error) {
      debugPrint('E-ink prefetch failed: $error');
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
    final generation = _generation;
    final candidate = await _findNextFrame(generation);
    if (!mounted || generation != _generation) {
      return;
    }
    if (candidate == null) {
      _scheduleNext();
      return;
    }
    setState(() {
      _nextIndex = candidate.$1;
      _next = candidate.$2;
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
    unawaited(_prefetchNext(_generation));
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

        final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
        final target = EInkResolutionPolicy.resolve(
          logicalSize: Size(width, height),
          devicePixelRatio: dpr,
        );
        _requestResolution(target);

        final current = _current;
        if (current == null) {
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
        Paint()..color = const Color(0x38746F66),
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
