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
      return parent.load(key);
    }

    final packed = Uint8List(totalLength);
    var offset = 0;
    for (final part in parts) {
      packed.setRange(offset, offset + part.length, part);
      offset += part.length;
    }

    final converted = _expandThreeBitMaster(packed, source: key);
    _assembled[key] = converted;
    return converted;
  }

  ByteData _expandThreeBitMaster(Uint8List source, {required String sourceKey}) {
    const headerSize = 16;
    if (source.length < headerSize ||
        source[0] != 0x45 ||
        source[1] != 0x49 ||
        source[2] != 0x4e ||
        source[3] != 0x4b) {
      throw FormatException('Invalid chunked e-ink master: $sourceKey');
    }

    final input = ByteData.sublistView(source, 0, headerSize);
    final version = source[4];
    final bits = source[5];
    final width = input.getUint16(6, Endian.big);
    final height = input.getUint16(8, Endian.big);
    final processingVersion = source[10];
    final compression = source[11];
    final payloadLength = input.getUint32(12, Endian.big);

    if (version != 2 || bits != 3 || width <= 0 || height <= 0) {
      throw FormatException('Unsupported chunked e-ink master: $sourceKey');
    }
    if (headerSize + payloadLength > source.length) {
      throw FormatException('Truncated chunked e-ink master: $sourceKey');
    }

    final payload = Uint8List.sublistView(
      source,
      headerSize,
      headerSize + payloadLength,
    );
    final threeBit = switch (compression) {
      0 => Uint8List.fromList(payload),
      1 => Uint8List.fromList(const ZLibDecoder().decodeBytes(payload)),
      _ => throw FormatException('Unsupported master compression: $sourceKey'),
    };

    final pixelCount = width * height;
    final expectedThreeBitBytes = ((pixelCount * 3) + 7) >> 3;
    if (threeBit.length != expectedThreeBitBytes) {
      throw FormatException('Invalid 3-bit master payload: $sourceKey');
    }

    final fourBit = Uint8List((pixelCount + 1) >> 1);
    var bitOffset = 0;
    for (var pixelIndex = 0; pixelIndex < pixelCount; pixelIndex++) {
      final byteIndex = bitOffset >> 3;
      final bitIndex = bitOffset & 7;
      var value = (threeBit[byteIndex] >> bitIndex) & 0x07;
      if (bitIndex > 5) {
        value |= (threeBit[byteIndex + 1] << (8 - bitIndex)) & 0x07;
      }
      bitOffset += 3;

      final expanded = ((value * 15) / 7).round().clamp(0, 15);
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
