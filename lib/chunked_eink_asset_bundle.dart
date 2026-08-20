import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';

class ChunkedEInkAssetBundle extends CachingAssetBundle {
  ChunkedEInkAssetBundle(this.parent);

  final AssetBundle parent;
  final Map<String, ByteData> _assembled = {};

  @override
  Future<ByteData> load(String key) async {
    if (!key.endsWith('.einkm')) {
      return parent.load(key);
    }

    final cached = _assembled[key];
    if (cached != null) {
      return cached;
    }

    final source = await _loadMasterSource(key);
    final converted = _expandMaster(source, sourceKey: key);
    _assembled[key] = converted;
    return converted;
  }

  Future<Uint8List> _loadMasterSource(String key) async {
    final parts = <Uint8List>[];
    var totalLength = 0;
    for (var partIndex = 0; partIndex < 100; partIndex++) {
      final partKey = '$key.part${partIndex.toString().padLeft(3, '0')}';
      try {
        final data = await parent.load(partKey);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        parts.add(Uint8List.fromList(bytes));
        totalLength += bytes.length;
      } catch (_) {
        break;
      }
    }

    if (parts.isEmpty) {
      final data = await parent.load(key);
      return Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }

    final source = Uint8List(totalLength);
    var offset = 0;
    for (final part in parts) {
      source.setRange(offset, offset + part.length, part);
      offset += part.length;
    }
    return source;
  }

  ByteData _expandMaster(Uint8List source, {required String sourceKey}) {
    const headerSize = 16;
    if (source.length < headerSize ||
        source[0] != 0x45 ||
        source[1] != 0x49 ||
        source[2] != 0x4e ||
        source[3] != 0x4b) {
      throw FormatException('Invalid e-ink master: $sourceKey');
    }

    final input = ByteData.sublistView(source, 0, headerSize);
    final version = source[4];
    final bits = source[5];
    final width = input.getUint16(6, Endian.big);
    final height = input.getUint16(8, Endian.big);
    final processingVersion = source[10];
    final compression = source[11];
    final payloadLength = input.getUint32(12, Endian.big);

    if (width <= 0 || height <= 0 || headerSize + payloadLength > source.length) {
      throw FormatException('Truncated e-ink master: $sourceKey');
    }

    if (version == 1 && bits == 4) {
      return ByteData.sublistView(source);
    }
    if (!((version == 2 && bits == 3) || (version == 3 && bits == 2))) {
      throw FormatException('Unsupported e-ink master: $sourceKey');
    }

    final payload = Uint8List.sublistView(
      source,
      headerSize,
      headerSize + payloadLength,
    );
    final packedInput = switch (compression) {
      0 => Uint8List.fromList(payload),
      1 => Uint8List.fromList(const ZLibDecoder().decodeBytes(payload)),
      _ => throw FormatException('Unsupported master compression: $sourceKey'),
    };

    final pixelCount = width * height;
    final expectedBytes = ((pixelCount * bits) + 7) >> 3;
    if (packedInput.length != expectedBytes) {
      throw FormatException('Invalid compact master payload: $sourceKey');
    }

    final fourBit = Uint8List((pixelCount + 1) >> 1);
    var bitOffset = 0;
    final inputMax = (1 << bits) - 1;
    for (var pixelIndex = 0; pixelIndex < pixelCount; pixelIndex++) {
      final value = _readBits(packedInput, bitOffset, bits);
      bitOffset += bits;
      final expanded = ((value * 15) / inputMax).round().clamp(0, 15);
      final outputIndex = pixelIndex >> 1;
      if (pixelIndex.isEven) {
        fourBit[outputIndex] = expanded << 4;
      } else {
        fourBit[outputIndex] |= expanded;
      }
    }

    final result = Uint8List(headerSize + fourBit.length);
    result[0] = 0x45;
    result[1] = 0x49;
    result[2] = 0x4e;
    result[3] = 0x4b;
    result[4] = 1;
    result[5] = 4;
    final header = ByteData.sublistView(result, 0, headerSize);
    header.setUint16(6, width, Endian.big);
    header.setUint16(8, height, Endian.big);
    result[10] = processingVersion;
    result[11] = 0;
    header.setUint32(12, fourBit.length, Endian.big);
    result.setRange(headerSize, result.length, fourBit);
    return ByteData.sublistView(result);
  }

  int _readBits(Uint8List bytes, int bitOffset, int bitCount) {
    final byteIndex = bitOffset >> 3;
    final bitIndex = bitOffset & 7;
    final mask = (1 << bitCount) - 1;
    var value = (bytes[byteIndex] >> bitIndex) & mask;
    final available = 8 - bitIndex;
    if (available < bitCount) {
      value |= (bytes[byteIndex + 1] << available) & mask;
    }
    return value;
  }

  @override
  void evict(String key) {
    _assembled.remove(key);
    super.evict(key);
  }

  @override
  void clear() {
    _assembled.clear();
    super.clear();
  }
}
