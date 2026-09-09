import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:evil_space/admin_api.dart';
import 'package:evil_space/brand_logo.dart';
import 'package:evil_space/brand_surface.dart';
import 'package:evil_space/menu_api.dart';

class AdminMenuPortal extends StatefulWidget {
  const AdminMenuPortal({
    super.key,
    required this.onBackToAdmin,
    required this.onExit,
  });

  final VoidCallback onBackToAdmin;
  final VoidCallback onExit;

  @override
  State<AdminMenuPortal> createState() => _AdminMenuPortalState();
}

class _AdminMenuPortalState extends State<AdminMenuPortal> {
  final _adminApi = AdminApi();
  final _menuApi = MenuApi();
  AdminSession? _session;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final session = await _adminApi.session();
      if (!mounted) return;
      setState(() => _session = session);
    } catch (_) {
      if (!mounted) return;
      setState(() => _session = const AdminSession.signedOut());
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return const Scaffold(
        backgroundColor: BrandPalette.paper,
        body: BrandPaper(
          child: Center(
            child: CircularProgressIndicator(color: BrandPalette.ink),
          ),
        ),
      );
    }
    if (!session.authenticated) {
      return Scaffold(
        backgroundColor: BrandPalette.paper,
        body: BrandPaper(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const EvilCoworkingLogo(width: 190),
                      const SizedBox(height: 30),
                      Text('SIGN IN REQUIRED', style: _serif(30)),
                      const SizedBox(height: 12),
                      Text(
                        'Open the main admin panel and sign in before editing the public menu.',
                        style: _serif(17, color: BrandPalette.inkMuted, height: 1.35),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: widget.onBackToAdmin,
                        style: _darkButton(),
                        child: Text('OPEN ADMIN', style: _mono(10, color: BrandPalette.paperLift)),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: widget.onExit,
                        style: _outlineButton(),
                        child: Text('BACK TO SITE', style: _mono(10)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return AdminMenuScreen(api: _menuApi, onBack: widget.onBackToAdmin);
  }
}

class AdminMenuScreen extends StatefulWidget {
  const AdminMenuScreen({super.key, required this.api, required this.onBack});

  final MenuApi api;
  final VoidCallback onBack;

  @override
  State<AdminMenuScreen> createState() => _AdminMenuScreenState();
}

class _AdminMenuScreenState extends State<AdminMenuScreen> {
  AdminMenuSnapshot? _snapshot;
  Timer? _timer;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final snapshot = await widget.api.adminSnapshot().timeout(
        const Duration(seconds: 10),
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _error = null;
      });
    } on MenuApiException catch (error) {
      if (!mounted || silent) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted || silent) return;
      setState(() {
        _loading = false;
        _error = 'Could not load menu admin.';
      });
    }
  }

  Future<void> _upload() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final raw = await widget.api.pickMenuJson();
      if (!mounted) return;
      if (raw == null) {
        setState(() => _busy = false);
        return;
      }
      final snapshot = await widget.api.uploadMenuJson(raw).timeout(
        const Duration(seconds: 15),
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menu published.')),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } on MenuApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not read or upload this JSON file.';
      });
    }
  }

  Future<void> _markPaid(AdminMenuOrder order) async {
    if (_busy || !order.pending) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: BrandPalette.paper,
        shape: const RoundedRectangleBorder(),
        title: Text('CONFIRM BANK PAYMENT?', style: _serif(24)),
        content: Text(
          '${order.itemName}\n${_money(order.amountVnd)}\n${order.paymentMessage}',
          style: _serif(17, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('CANCEL', style: _mono(10)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: _darkButton(),
            child: Text('MARK PAID', style: _mono(10, color: BrandPalette.paperLift)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final snapshot = await widget.api.markPaid(order.id).timeout(
        const Duration(seconds: 10),
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _busy = false;
      });
    } on MenuApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not mark the order paid.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      backgroundColor: BrandPalette.paper,
      body: BrandPaper(
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: RefreshIndicator(
                  color: BrandPalette.ink,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 60),
                    children: [
                      Text('MENU ADMIN', style: _serif(42)),
                      const SizedBox(height: 8),
                      Text(
                        'Upload one JSON file to replace the public menu. Existing orders keep their original item name and price.',
                        style: _serif(16, color: BrandPalette.inkMuted, height: 1.35),
                      ),
                      const SizedBox(height: 20),
                      if (_error != null) _errorBox(_error!),
                      if (snapshot != null && !snapshot.paymentConfigured)
                        _warning(
                          'PAYMENT QR NOT CONFIGURED',
                          'Set VIETQR_ACCOUNT_NUMBER in the Worker before accepting real menu payments. Bank BIN: ${snapshot.bankBin}.',
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _busy ? null : _upload,
                              icon: const Icon(Icons.upload_file_outlined),
                              label: Text(_busy ? '…' : 'UPLOAD MENU JSON', style: _mono(11, color: BrandPalette.paperLift)),
                              style: _darkButton(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _load,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text('REFRESH', style: _mono(10)),
                            style: _outlineButton(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      if (_loading && snapshot == null)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(color: BrandPalette.ink),
                          ),
                        )
                      else ...[
                        _catalog(snapshot?.catalog),
                        const SizedBox(height: 32),
                        _orders(snapshot?.orders ?? const []),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BrandPalette.ink)),
      ),
      child: Row(
        children: [
          const EvilCoworkingLogo(width: 108),
          const Spacer(),
          TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: Text('ADMIN', style: _mono(10)),
          ),
        ],
      ),
    );
  }

  Widget _catalog(AdminMenuCatalog? catalog) {
    if (catalog == null) {
      const sample = {
        'version': 1,
        'groups': [
          {
            'id': 'beverages',
            'name': 'Beverages',
            'items': [
              {
                'id': 'cola',
                'name': 'Cola',
                'priceVnd': 30000,
                'description': null,
              },
            ],
          },
        ],
      };
      return _section(
        'NO MENU PUBLISHED',
        [
          Text('Upload a JSON file in this format:', style: _serif(17)),
          const SizedBox(height: 12),
          SelectableText(
            const JsonEncoder.withIndent('  ').convert(sample),
            style: _mono(10, height: 1.45),
          ),
        ],
      );
    }

    return _section(
      'ACTIVE MENU · V${catalog.version}',
      [
        Text(
          'Published by ${catalog.createdByEmail}${catalog.createdAt > 0 ? ' · ${_date(catalog.createdAt)}' : ''}',
          style: _mono(9.5, color: BrandPalette.inkMuted),
        ),
        const SizedBox(height: 16),
        for (final group in catalog.groups) ...[
          Text(group.name.toUpperCase(), style: _mono(11)),
          const SizedBox(height: 5),
          for (final item in group.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.name}${item.enabled ? '' : ' · DISABLED'}',
                      style: _serif(17, color: item.enabled ? BrandPalette.ink : BrandPalette.inkMuted),
                    ),
                  ),
                  Text(_money(item.priceVnd), style: _mono(10)),
                ],
              ),
            ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _orders(List<AdminMenuOrder> orders) {
    final pending = orders.where((order) => order.pending).toList(growable: false);
    final history = orders.where((order) => !order.pending).take(30).toList(growable: false);
    return _section(
      'MENU ORDERS${pending.isEmpty ? '' : ' · ${pending.length} PENDING'}',
      [
        if (orders.isEmpty)
          Text('No menu orders yet.', style: _serif(17, color: BrandPalette.inkMuted))
        else ...[
          for (final order in pending) _order(order),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('RECENT', style: _mono(10, color: BrandPalette.inkMuted)),
            const SizedBox(height: 8),
            for (final order in history) _order(order),
          ],
        ],
      ],
    );
  }

  Widget _order(AdminMenuOrder order) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BrandPalette.rule)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${order.orderCode} · ${order.itemName}', style: _serif(19)),
                const SizedBox(height: 4),
                Text('${_money(order.amountVnd)} · ${order.paymentMessage}', style: _mono(9.5)),
                if (order.paid)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('PAID${order.paidByEmail == null ? '' : ' · ${order.paidByEmail}'}', style: _mono(9, color: BrandPalette.inkMuted)),
                  )
                else if (!order.pending)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(order.status.toUpperCase(), style: _mono(9, color: BrandPalette.inkMuted)),
                  ),
              ],
            ),
          ),
          if (order.pending) ...[
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _busy ? null : () => _markPaid(order),
              style: _darkButton().copyWith(
                minimumSize: const WidgetStatePropertyAll(Size(110, 44)),
              ),
              child: Text('MARK PAID', style: _mono(9.5, color: BrandPalette.paperLift)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(border: Border.all(color: BrandPalette.ink)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: _mono(11)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _warning(String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: BrandPalette.ink, width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _mono(10.5)),
          const SizedBox(height: 6),
          Text(body, style: _serif(15, height: 1.3)),
        ],
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(border: Border.all(color: BrandPalette.ink)),
      child: Text(message, style: _mono(10.5, height: 1.35)),
    );
  }
}

String _date(int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
}

String _money(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index += 1) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return '${value < 0 ? '-' : ''}${buffer.toString()} VND';
}

ButtonStyle _darkButton() {
  return FilledButton.styleFrom(
    foregroundColor: BrandPalette.paperLift,
    backgroundColor: BrandPalette.ink,
    minimumSize: const Size.fromHeight(50),
    shape: const RoundedRectangleBorder(),
  );
}

ButtonStyle _outlineButton() {
  return OutlinedButton.styleFrom(
    foregroundColor: BrandPalette.ink,
    side: const BorderSide(color: BrandPalette.ink),
    minimumSize: const Size(120, 50),
    shape: const RoundedRectangleBorder(),
  );
}

TextStyle _serif(
  double size, {
  Color color = BrandPalette.ink,
  double? height,
}) {
  return TextStyle(fontFamily: 'Georgia', fontSize: size, color: color, height: height);
}

TextStyle _mono(
  double size, {
  Color color = BrandPalette.ink,
  double? height,
}) {
  return TextStyle(
    fontFamily: 'Courier New',
    fontSize: size,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    color: color,
    height: height,
  );
}
