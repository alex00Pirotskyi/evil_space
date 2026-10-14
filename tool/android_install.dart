// Wi-Fi ADB installation of the payment-listener Flutter entrypoint.
import 'dart:io';

Future<void> main(List<String> args) async {
  final ip = _option(args, '--ip');
  final serial = _option(args, '--serial');
  final buildOnly = args.contains('--build-only');
  final flutter = Platform.isWindows ? 'flutter.bat' : 'flutter';
  final adb = _adbPath();
  await _run(flutter, ['pub', 'get']);
  await _run(flutter, ['build', 'apk', '--release',
    '--target', 'lib/payment_listener_main.dart']);
  final apk = File('build/app/outputs/flutter-apk/app-release.apk');
  if (!apk.existsSync()) throw StateError('Flutter did not create the APK.');
  stdout.writeln('APK ready: ' + apk.absolute.path);
  if (buildOnly) return;

  if (ip.isNotEmpty) {
    final address = ip.contains(':') ? ip : ip + ':5555';
    await _run(adb, ['connect', address]);
  }
  final result = await Process.run(adb, ['devices']);
  if (result.exitCode != 0) throw StateError('adb devices failed: ' + result.stderr.toString());
  final devices = (result.stdout as String).split('\n').skip(1)
      .map((line) => line.trim().split(RegExp(r'\s+')))
      .where((columns) => columns.length >= 2 && columns[1] == 'device')
      .map((columns) => columns.first).toList();
  final selected = serial.isNotEmpty ? serial
      : ip.isNotEmpty ? (ip.contains(':') ? ip : ip + ':5555')
      : devices.length == 1 ? devices.single : '';
  if (selected.isEmpty || !devices.contains(selected)) {
    throw StateError(
      'No unique authorized device selected. Connected: ' + devices.toString() + '\n'
      'Pair the Sapo over Wireless debugging (Android 11+) using adb pair, '
      'or connect via USB and run adb tcpip 5555 once. '
      'Then use: make android SAPO_IP=IP:PORT',
    );
  }
  await _run(adb, ['-s', selected, 'install', '-r', apk.absolute.path]);
  await _run(adb, ['-s', selected, 'shell', 'am', 'start', '-n',
    'space.evils.paymentlistener/com.example.evil_space.MainActivity']);
  stdout.writeln('Evil Space Payment Listener installed and opened on ' + selected);
}

String _option(List<String> args, String key) {
  final index = args.indexOf(key);
  return index >= 0 && index + 1 < args.length ? args[index + 1].trim() : '';
}

String _adbPath() {
  final exe = Platform.isWindows ? 'adb.exe' : 'adb';
  for (final root in [
    Platform.environment['ANDROID_HOME'],
    Platform.environment['ANDROID_SDK_ROOT'],
    Platform.isWindows
        ? (Platform.environment['LOCALAPPDATA'] ?? '') + r'\Android\Sdk'
        : (Platform.environment['HOME'] ?? '') + '/Android/Sdk',
  ]) {
    if (root == null || root.isEmpty) continue;
    final full = File(root + Platform.pathSeparator + 'platform-tools' +
      Platform.pathSeparator + exe);
    if (full.existsSync()) return full.path;
  }
  return exe;
}

Future<void> _run(String command, List<String> arguments) async {
  stdout.writeln('> ' + command + ' ' + arguments.join(' '));
  final process = await Process.start(command, arguments,
    mode: ProcessStartMode.inheritStdio, runInShell: Platform.isWindows);
  final exit = await process.exitCode;
  if (exit != 0) throw StateError(command + ' failed with exit code ' + exit.toString());
}
