import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:evil_space/eink_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('browser decodes a real slideshow asset into e-paper ink', () async {
    final frame = await EInkFrameDecoder.decodeAsset(
      bundle: rootBundle,
      assetPath: 'assets/slideshow/01_bar_closeup.jpg',
      columns: 160,
      rows: 100,
    );

    expect(frame.columns, 160);
    expect(frame.rows, 100);
    expect(frame.levels.length, 16000);
    expect(frame.levels.any((level) => level > 0), isTrue);
    expect(frame.levels.toSet().length, greaterThan(1));
  });
}
