import 'dart:async';
import 'dart:io';

const _minimumFlutter = _Version(3, 47, 2);

Future<void> main(List<String> args) async {
  final verifyOnly = args.contains('--verify-only');
  final buildOnly = args.contains('--build-only');
  if (verifyOnly && buildOnly) {
    _die('Choose either --verify-only or --build-only, not both.');
  }

  stdout.writeln('EVIL SPACE · PRODUCTION RELEASE');
  stdout.writeln('===============================');

  await _verifyFlutterVersion();
  await _run('flutter', ['pub', 'get']);
  await _run('flutter', ['analyze', '--no-pub']);
  await _run('flutter', ['test', '--no-pub']);
  await _run('node', ['--check', 'worker/index.js']);
  await _run('node', ['--check', 'worker/entry.js']);

  if (verifyOnly) {
    stdout.writeln('Verification complete. No build or deployment performed.');
    return;
  }

  final webOutput = Directory('build/web');
  if (webOutput.existsSync()) {
    webOutput.deleteSync(recursive: true);
  }

  await _run('flutter', [
    'build',
    'web',
    '--release',
    '--wasm',
    '--no-pub',
    '--dart-define=EVIL_SPACE_ADMIN_PREVIEW=true',
  ]);
  await _run('node', ['--check', 'build/web/flutter_bootstrap.js']);
  await _run('dart', ['run', 'tool/verify_release.dart', 'build/web']);

  if (buildOnly) {
    stdout.writeln('Optimized Wasm release build is ready in build/web.');
    return;
  }

  await _run(
    'npx',
    ['--yes', 'wrangler', 'd1', 'migrations', 'apply', 'evil-space', '--remote'],
    confirm: true,
  );
  await _run('npx', ['--yes', 'wrangler', 'deploy']);

  stdout.writeln('');
  stdout.writeln('EVIL SPACE DEPLOYED SUCCESSFULLY.');
}

Future<void> _verifyFlutterVersion() async {
  final result = await Process.run(
    'flutter',
    ['--version'],
    runInShell: Platform.isWindows,
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    _die('Could not run flutter --version.');
  }

  final text = '${result.stdout}\n${result.stderr}';
  final match = RegExp(r'Flutter\s+(\d+)\.(\d+)\.(\d+)').firstMatch(text);
  if (match == null) _die('Could not parse Flutter version.');

  final installed = _Version(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
  if (installed.compareTo(_minimumFlutter) < 0) {
    _die(
      'Flutter $installed is too old. Evil Space requires '
      'Flutter $_minimumFlutter or newer.',
    );
  }
}

Future<void> _run(
  String executable,
  List<String> arguments, {
  bool confirm = false,
}) async {
  stdout.writeln('');
  stdout.writeln('> $executable ${arguments.join(' ')}');

  final process = await Process.start(
    executable,
    arguments,
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.normal,
  );

  final stdoutDone = stdout.addStream(process.stdout);
  final stderrDone = stderr.addStream(process.stderr);

  if (confirm) {
    process.stdin.writeln('y');
    await process.stdin.flush();
  }
  await process.stdin.close();

  final exitCode = await process.exitCode;
  await Future.wait([stdoutDone, stderrDone]);
  if (exitCode != 0) {
    _die('$executable failed with exit code $exitCode.');
  }
}

Never _die(String message) {
  stderr.writeln('');
  stderr.writeln('RELEASE FAILED: $message');
  exit(1);
}

class _Version implements Comparable<_Version> {
  const _Version(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  @override
  int compareTo(_Version other) {
    final majorResult = major.compareTo(other.major);
    if (majorResult != 0) return majorResult;
    final minorResult = minor.compareTo(other.minor);
    if (minorResult != 0) return minorResult;
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}
