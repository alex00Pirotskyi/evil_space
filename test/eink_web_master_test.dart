import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:evil_space/chunked_eink_asset_bundle.dart';
import 'package:evil_space/eink_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loads all real e-paper masters and dynamically renders one',
    () async {
      final bundle = ChunkedEInkAssetBundle(rootBundle);
      final assets = await EInkMasterCatalog.discover(bundle);

      expect(assets, hasLength(10));

      final masters = <EInkMaster>[];
      for (final asset in assets) {
        final master = await EInkMasterLoader.loadAsset(
          bundle: bundle,
          assetPath: asset,
        ).timeout(const Duration(seconds: 5));
        expect(master.width, greaterThanOrEqualTo(400), reason: asset);
        expect(master.height, greaterThanOrEqualTo(400), reason: asset);
        masters.add(master);
      }

      const logicalSize = Size(480, 300);
      final target = EInkResolutionPolicy.resolve(
        logicalSize: logicalSize,
        devicePixelRatio: 1.5,
      );

      expect(target.columns, greaterThan(logicalSize.width));
      expect(target.rows, greaterThan(logicalSize.height));

      final frame = await EInkProcessor.renderMaster(
        master: masters[2],
        requestedColumns: target.columns,
        requestedRows: target.rows,
      ).timeout(const Duration(seconds: 12));

      expect(frame.columns, greaterThanOrEqualTo(400));
      expect(frame.rows, greaterThanOrEqualTo(250));
      expect(frame.levels.length, frame.columns * frame.rows);
      expect(frame.levels.toSet().length, greaterThanOrEqualTo(3));
      expect(frame.source, contains('03_cafe_workspace'));
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
