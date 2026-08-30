import 'dart:io';

const _maxFallbackJsGzipBytes = 1300000;

void main(List<String> args) {
  final root = Directory(args.isEmpty ? 'build/web' : args.first);
  if (!root.existsSync()) {
    _fail('Release directory does not exist: ${root.path}');
  }

  final requiredFiles = [
    'index.html',
    'flutter_bootstrap.js',
    'manifest.json',
    '_headers',
  ];
  for (final name in requiredFiles) {
    final file = File('${root.path}${Platform.pathSeparator}$name');
    if (!file.existsSync()) _fail('Missing release artifact: $name');
  }

  final index = File('${root.path}${Platform.pathSeparator}index.html')
      .readAsStringSync();
  final bootstrap = File(
    '${root.path}${Platform.pathSeparator}flutter_bootstrap.js',
  ).readAsStringSync();
  final headers = File('${root.path}${Platform.pathSeparator}_headers')
      .readAsStringSync();

  if (!index.contains('id="evil-space-boot"')) {
    _fail('The instant startup shell is missing from index.html.');
  }
  if (bootstrap.contains('{{flutter_')) {
    _fail('flutter_bootstrap.js still contains unresolved Flutter tokens.');
  }
  if (!bootstrap.contains('evil-bootstrap-start') ||
      !bootstrap.contains('initializeEngine')) {
    _fail('The optimized Flutter bootstrap was not emitted.');
  }
  if (!headers.contains('Cross-Origin-Opener-Policy: same-origin') ||
      !headers.contains('Cross-Origin-Embedder-Policy: credentialless')) {
    _fail('Cloudflare isolation headers required by threaded SkWasm are missing.');
  }

  final files = root
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .toList(growable: false);
  final wasmFiles = files.where((file) => file.path.endsWith('.wasm')).toList();
  final mainWasm = File('${root.path}${Platform.pathSeparator}main.dart.wasm');
  if (!mainWasm.existsSync()) {
    _fail('main.dart.wasm is missing. Build with flutter build web --wasm.');
  }

  final totalBytes = files.fold<int>(0, (sum, file) => sum + file.lengthSync());
  final mainJs = File('${root.path}${Platform.pathSeparator}main.dart.js');

  stdout.writeln('');
  stdout.writeln('EVIL SPACE RELEASE REPORT');
  stdout.writeln('-------------------------');
  stdout.writeln('files: ${files.length}');
  stdout.writeln('release tree: ${_formatBytes(totalBytes)}');
  stdout.writeln('wasm files: ${wasmFiles.length}');
  stdout.writeln('main.dart.wasm: ${_formatBytes(mainWasm.lengthSync())}');

  if (mainJs.existsSync()) {
    final raw = mainJs.readAsBytesSync();
    final gzipped = gzip.encode(raw).length;
    stdout.writeln('main.dart.js: ${_formatBytes(raw.length)}');
    stdout.writeln('main.dart.js gzip: ${_formatBytes(gzipped)}');
    if (gzipped > _maxFallbackJsGzipBytes) {
      _fail(
        'Fallback JS gzip grew above ${_formatBytes(_maxFallbackJsGzipBytes)}. '
        'Review bundle growth before deploying.',
      );
    }
  }

  final largest = [...files]
    ..sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
  stdout.writeln('largest artifacts:');
  for (final file in largest.take(6)) {
    final relative = file.path.substring(root.path.length + 1);
    stdout.writeln('  ${_formatBytes(file.lengthSync()).padLeft(9)}  $relative');
  }
  stdout.writeln('release verification: OK');
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  return '${(kb / 1024).toStringAsFixed(2)} MB';
}

Never _fail(String message) {
  stderr.writeln('RELEASE CHECK FAILED: $message');
  exit(1);
}
