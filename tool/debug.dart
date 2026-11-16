import 'dart:io';

/// Deploy a separate, empty Flutter shader page; never touch production D1.
Future<void> main(List<String> args) async {
  if (args.any((argument) => argument != '--build-only')) {
    stderr.writeln('Usage: dart run tool/debug.dart [--build-only]');
    exitCode = 64;
    return;
  }

  final buildOnly = args.contains('--build-only');
  stdout.writeln('EVIL SPACE — ISOLATED PAPER PREVIEW');
  await _run('flutter', ['pub', 'get']);
  await _run('flutter', [
    'build', 'web', '--release', '--wasm',
    '--target=lib/main_debug.dart',
    '--output=build/debug_web',
    '--no-pub',
  ]);
  await _run('node', ['tool/prepare_debug_web.mjs']);
  await _run('node', ['--check', 'build/debug_web/flutter_bootstrap.js']);

  if (buildOnly) {
    stdout.writeln('Ready: build/debug_web (not deployed).');
    return;
  }

  final version = File('tool/wrangler_version.txt').readAsStringSync().trim();
  if (!RegExp(r'^4\.\d+\.\d+$').hasMatch(version)) {
    stderr.writeln('Invalid pinned Wrangler version: $version');
    exitCode = 1;
    return;
  }
  await _run('npx', [
    '--yes', 'wrangler@$version', 'deploy', '--config', 'wrangler.debug.toml',
  ]);
  stdout.writeln('Preview deployed to https://test.evils.space/');
}

Future<void> _run(String executable, List<String> arguments) async {
  stdout.writeln('> $executable ${arguments.join(' ')}');
  final process = await Process.start(
    executable,
    arguments,
    runInShell: Platform.isWindows,
  );
  await process.stdin.close();
  final output = stdout.addStream(process.stdout);
  final errors = stderr.addStream(process.stderr);
  final code = await process.exitCode;
  await Future.wait([output, errors]);
  if (code != 0) {
    stderr.writeln('Preview command failed ($code): $executable');
    exit(code);
  }
}
