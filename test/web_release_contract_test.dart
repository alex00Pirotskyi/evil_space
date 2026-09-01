import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web release keeps the optimized Flutter bootstrap contract', () {
    final index = File('web/index.html').readAsStringSync();
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();
    final headers = File('web/_headers').readAsStringSync();

    expect(index, contains('id="evil-space-boot"'));
    expect(index, contains('flutter_bootstrap.js'));
    expect(index, contains('openingHoursSpecification'));
    expect(bootstrap, contains('{{flutter_js}}'));
    expect(bootstrap, contains('{{flutter_build_config}}'));
    expect(bootstrap, contains('/api/public/status'));
    expect(bootstrap, contains('initializeEngine'));
    expect(bootstrap, contains('evil_space_bootstrap_status_v1'));
    expect(headers, contains('Cross-Origin-Opener-Policy: same-origin'));
    expect(
      headers,
      contains('Cross-Origin-Embedder-Policy: credentialless'),
    );
  });

  test('public startup keeps admin behind a deferred Flutter boundary', () {
    final router = File('lib/app_router.dart').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();

    expect(router, contains("deferred as admin_portal"));
    expect(router, contains('admin_portal.loadLibrary()'));
    expect(main, contains('ListenableBuilder('));
    expect(main, isNot(contains('return AnimatedBuilder(')));
  });

  test('release automation pins Wasm-first Flutter 3.47.2 builds', () {
    final workflow = File('.github/workflows/web-ci.yml').readAsStringSync();
    final makefile = File('Makefile').readAsStringSync();
    final release = File('tool/release.dart').readAsStringSync();

    expect(workflow, contains("flutter-version: '3.47.2'"));
    expect(workflow, contains('flutter build web --release --wasm'));
    expect(makefile, contains('.DEFAULT_GOAL := deploy'));
    expect(makefile, contains('dart run tool/release.dart'));
    expect(release, contains("'--wasm'"));
    expect(release, contains("'migrations', 'apply'"));
    expect(release, contains("'wrangler', 'deploy'"));
  });
}
