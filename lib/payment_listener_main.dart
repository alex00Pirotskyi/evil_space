import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const PaymentListenerApp());

class PaymentListenerApp extends StatelessWidget {
  const PaymentListenerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Evil Space Payments',
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF101014),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFEF5555),
        brightness: Brightness.dark,
      ),
    ),
    home: const PaymentDashboard(),
  );
}

class PaymentDashboard extends StatefulWidget {
  const PaymentDashboard({super.key});
  @override
  State<PaymentDashboard> createState() => _PaymentDashboardState();
}

class _PaymentDashboardState extends State<PaymentDashboard>
    with WidgetsBindingObserver {
  static const channel = MethodChannel('evils.space/payments');
  final _secret = TextEditingController();
  Timer? _timer;
  Map<String, dynamic> _status = {};
  String _message = '';
  bool _busy = false;
  bool _showSecret = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
    _secret.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _secret.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final next = await channel.invokeMapMethod<String, dynamic>('status');
      if (!mounted) return;
      setState(() => _status = next ?? {});
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Cannot read Android listener status: $error');
    }
  }

  Future<void> _command(String name, {Map<String, dynamic>? args}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final answer = await channel.invokeMethod<Object?>(name, args);
      if (!mounted) return;
      if (name == 'configure') _secret.clear();
      setState(() {
        _message = switch (name) {
          'configure' => 'Device secret saved securely.',
          'ping' => answer == true ? 'Cloudflare connection verified.' : 'Unexpected server response.',
          'flush' => 'Retry requested. Upload runs when internet is available.',
          _ => '',
        };
      });
    } on PlatformException catch (error) {
      if (mounted) setState(() => _message = error.message ?? 'Action failed.');
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _refresh();
      }
    }
  }

  String _time(Object? epoch) {
    final ms = (epoch as num?)?.toInt() ?? 0;
    if (ms == 0) return 'Never';
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    String n(int value) => value.toString().padLeft(2, '0');
    return n(date.day) + '/' + n(date.month) + ' ' +
      n(date.hour) + ':' + n(date.minute);
  }

  @override
  Widget build(BuildContext context) {
    final access = _status['notificationAccess'] == true;
    final configured = _status['configured'] == true;
    final pending = (_status['pending'] as num?)?.toInt() ?? 0;
    final lastError = (_status['lastError'] ?? '').toString();
    final recent = (_status['recent'] as List?) ?? const [];
    final ready = configured && access;

    return Scaffold(
      appBar: AppBar(title: const Text('EVIL SPACE  /  PAYMENTS'),
        backgroundColor: const Color(0xFF101014)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            Row(children: [
              Icon(ready ? Icons.verified : Icons.warning_amber_rounded,
                color: ready ? Colors.greenAccent : Colors.orangeAccent, size: 32),
              const SizedBox(width: 12),
              Expanded(child: Text(ready ? 'LISTENER READY' : 'SETUP REQUIRED',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 18),
            _line('VCB notification access', access ? 'ENABLED' : 'DISABLED'),
            _line('Device secret', configured ? 'CONFIGURED' : 'MISSING'),
            _line('Unsent payment events', pending.toString()),
            _line('Last VCB notification', _time(_status['lastNotification'])),
            _line('Last server response', _time(_status['lastDelivery'])),
            if (lastError.isNotEmpty) Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text('Upload error: $lastError',
                style: const TextStyle(color: Colors.orangeAccent))),
            if (_message.isNotEmpty) Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: SelectableText(_message)),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _busy ? null : () => _command('notificationSettings'),
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Grant notification access'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _command('batterySettings'),
              icon: const Icon(Icons.battery_saver_outlined),
              label: const Text('Battery / background settings'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _secret,
              obscureText: !_showSecret,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Cloudflare device secret',
                hintText: 'Paste the same secret configured in Wrangler',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _showSecret = !_showSecret),
                  icon: Icon(_showSecret ? Icons.visibility_off : Icons.visibility),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy || _secret.text.trim().length < 32
                ? null : () => _command('configure',
                    args: {'secret': _secret.text.trim()}),
              child: const Text('Save device secret'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: _busy || !configured ? null : () => _command('ping'),
                child: const Text('Test server'),
              )),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton(
                onPressed: _busy || !configured ? null : () => _command('flush'),
                child: const Text('Retry uploads'),
              )),
            ]),
            const SizedBox(height: 16),
            const Text('RECENT TRANSACTIONS',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
            const SizedBox(height: 10),
            if (recent.isEmpty)
              const Text('No matching VCB transfer notifications received yet.',
                style: TextStyle(color: Colors.white70)),
            for (final item in recent)
              if (item is Map) Card(
                child: ListTile(
                  title: Text(item['amount'].toString() + ' VND  ·  EVIL ' +
                    item['code'].toString()),
                  subtitle: Text(_time(item['createdAt'])),
                  trailing: Text(item['status'].toString(), style: TextStyle(
                    color: item['status'] == 'matched' ? Colors.greenAccent
                      : item['status'] == 'pending' ? Colors.orangeAccent
                      : Colors.white70)),
                ),
              ),
            const SizedBox(height: 18),
            const Text(
              'Only com.VCB notifications with an incoming amount, the receiving '
              'account, a timestamp and an EVIL order reference are forwarded. '
              'The app does not access VCB credentials. Automatic confirmation '
              'depends on bank notification delivery.',
              style: TextStyle(color: Colors.white60, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
    ]),
  );
}
