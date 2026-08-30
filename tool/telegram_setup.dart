import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

const _webhookUrl = 'https://evils.space/api/telegram/webhook';

Future<void> main() async {
  stdout.writeln('EVIL SPACE - TELEGRAM SETUP');
  stdout.writeln('===========================');
  stdout.writeln('This stores secrets in Cloudflare only. Nothing is written to GitHub.');
  stdout.writeln('');

  await _run('npx', ['--yes', 'wrangler', 'whoami']);
  await _run('npx', [
    '--yes',
    'wrangler',
    'd1',
    'migrations',
    'list',
    'evil-space',
    '--remote',
  ]);

  final botToken = _readSecret(
    'Paste the NEW BotFather token (rotate the token shared in chat first): ',
  );
  if (!_looksLikeTelegramToken(botToken)) {
    _die('That does not look like a Telegram bot token.');
  }

  final wifiPassword = _readSecret('Wi-Fi password: ');
  if (wifiPassword.length < 8 || wifiPassword.length > 128) {
    _die('Wi-Fi password must be between 8 and 128 characters.');
  }

  final webhookSecret = _randomSecret(32);
  final client = HttpClient();
  try {
    stdout.writeln('> validating Telegram bot token');
    final me = await _telegram(client, botToken, 'getMe', const {});
    final username = me['result'] is Map
        ? (me['result'] as Map)['username']?.toString() ?? ''
        : '';

    await _putWranglerSecret('TELEGRAM_BOT_TOKEN', botToken);
    await _putWranglerSecret('TELEGRAM_WEBHOOK_SECRET', webhookSecret);
    await _putWranglerSecret('WIFI_PASSWORD', wifiPassword);

    await _telegram(client, botToken, 'setWebhook', {
      'url': _webhookUrl,
      'secret_token': webhookSecret,
      'allowed_updates': ['message', 'callback_query'],
      'drop_pending_updates': true,
    });

    await _telegram(client, botToken, 'setMyCommands', {
      'commands': [
        {'command': 'menu', 'description': 'Open Evil Space admin menu'},
        {'command': 'today', 'description': 'Today occupancy and customers'},
        {'command': 'bookings', 'description': 'Pending desk bookings'},
        {'command': 'day', 'description': 'Add a day pass'},
        {'command': 'month', 'description': 'Month pass and check-in'},
        {'command': 'customer', 'description': 'Search customers'},
        {'command': 'income', 'description': 'Income summary'},
        {'command': 'buy', 'description': 'Shared purchase list'},
        {'command': 'settings', 'description': 'Notification settings'},
        {'command': 'help', 'description': 'Bot help'},
      ],
    });

    stdout.writeln('');
    stdout.writeln('Telegram configured successfully.');
    if (username.isNotEmpty) stdout.writeln('Bot: @$username');
    stdout.writeln('Webhook: $_webhookUrl');
    stdout.writeln('Secrets are stored only in Cloudflare.');
  } finally {
    client.close(force: true);
  }
}

String _readSecret(String prompt) {
  stdout.write(prompt);
  String? value;
  var echoChanged = false;
  try {
    stdin.echoMode = false;
    echoChanged = true;
  } catch (_) {}
  try {
    value = stdin.readLineSync();
  } finally {
    if (echoChanged) {
      try {
        stdin.echoMode = true;
      } catch (_) {}
    }
    stdout.writeln('');
  }
  final result = value?.trim() ?? '';
  if (result.isEmpty) _die('Secret cannot be empty.');
  return result;
}

bool _looksLikeTelegramToken(String value) {
  return RegExp(r'^\d{6,12}:[A-Za-z0-9_-]{30,}$').hasMatch(value);
}

String _randomSecret(int byteLength) {
  final random = Random.secure();
  final bytes = List<int>.generate(byteLength, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

Future<void> _putWranglerSecret(String name, String value) async {
  stdout.writeln('> storing $name in Cloudflare');
  final process = await Process.start(
    'npx',
    ['--yes', 'wrangler', 'secret', 'put', name],
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.normal,
  );

  final stdoutDone = stdout.addStream(process.stdout);
  final stderrDone = stderr.addStream(process.stderr);
  process.stdin.writeln(value);
  await process.stdin.flush();
  await process.stdin.close();
  final exitCode = await process.exitCode;
  await Future.wait([stdoutDone, stderrDone]);
  if (exitCode != 0) _die('Could not store $name in Cloudflare.');
}

Future<Map<String, dynamic>> _telegram(
  HttpClient client,
  String token,
  String method,
  Map<String, dynamic> payload,
) async {
  final request = await client.postUrl(
    Uri.parse('https://api.telegram.org/bot$token/$method'),
  );
  request.headers.contentType = ContentType.json;
  request.write(jsonEncode(payload));
  final response = await request.close();
  final raw = await utf8.decoder.bind(response).join();
  final decoded = raw.isEmpty ? null : jsonDecode(raw);
  final data = decoded is Map
      ? Map<String, dynamic>.from(decoded)
      : <String, dynamic>{};
  if (response.statusCode < 200 ||
      response.statusCode >= 300 ||
      data['ok'] != true) {
    final description = data['description']?.toString() ?? 'Telegram request failed.';
    _die('$method failed: $description');
  }
  return data;
}

Future<void> _run(String executable, List<String> arguments) async {
  stdout.writeln('> $executable ${arguments.join(' ')}');
  final process = await Process.start(
    executable,
    arguments,
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.normal,
  );
  final stdoutDone = stdout.addStream(process.stdout);
  final stderrDone = stderr.addStream(process.stderr);
  await process.stdin.close();
  final exitCode = await process.exitCode;
  await Future.wait([stdoutDone, stderrDone]);
  if (exitCode != 0) {
    _die('$executable failed with exit code $exitCode. Fix Cloudflare login first.');
  }
}

Never _die(String message) {
  stderr.writeln('');
  stderr.writeln('TELEGRAM SETUP FAILED: $message');
  exit(1);
}
