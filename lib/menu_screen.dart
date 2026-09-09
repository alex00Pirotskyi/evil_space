import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:evil_space/brand_logo.dart';
import 'package:evil_space/brand_surface.dart';
import 'package:evil_space/menu_api.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _api = MenuApi();
  MenuCatalog? _menu;
  String? _error;
  bool _loading = true;
  String? _buyingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final menu = await _api.menu().timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _menu = menu;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the menu.';
      });
    }
  }

  Future<void> _buy(MenuItem item) async {
    if (_buyingId != null) return;
    setState(() {
      _buyingId = item.id;
      _error = null;
    });
    try {
      final order = await _api.createOrder(item.id).timeout(
        const Duration(seconds: 10),
      );
      if (!mounted) return;
      setState(() => _buyingId = null);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PaymentDialog(api: _api, order: order),
      );
    } on MenuApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _buyingId = null;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _buyingId = null;
        _error = 'Could not create the payment.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = _menu;
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
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 56),
                    children: [
                      Text('MENU', style: _serif(44)),
                      const SizedBox(height: 6),
                      Text(
                        'Choose an item, scan the payment QR, and wait for staff confirmation.',
                        style: _serif(16, color: BrandPalette.inkMuted, height: 1.35),
                      ),
                      const SizedBox(height: 22),
                      if (_error != null) _errorBox(_error!),
                      if (_loading && menu == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: CircularProgressIndicator(color: BrandPalette.ink),
                          ),
                        )
                      else if (menu == null || menu.groups.isEmpty)
                        _empty()
                      else
                        for (final group in menu.groups) ...[
                          _group(group),
                          const SizedBox(height: 24),
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
            label: Text('BACK', style: _mono(10)),
          ),
        ],
      ),
    );
  }

  Widget _group(MenuGroup group) {
    final items = group.items.where((item) => item.enabled).toList(growable: false);
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: BrandPalette.ink)),
          ),
          child: Text(group.name.toUpperCase(), style: _mono(12)),
        ),
        for (final item in items) _item(item),
      ],
    );
  }

  Widget _item(MenuItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
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
                Text(item.name, style: _serif(25)),
                if (item.description != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    item.description!,
                    style: _serif(15, color: BrandPalette.inkMuted, height: 1.3),
                  ),
                ],
                const SizedBox(height: 8),
                Text(_money(item.priceVnd), style: _mono(12)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton(
            onPressed: _buyingId == null ? () => _buy(item) : null,
            style: FilledButton.styleFrom(
              foregroundColor: BrandPalette.paperLift,
              backgroundColor: BrandPalette.ink,
              minimumSize: const Size(92, 48),
              shape: const RoundedRectangleBorder(),
            ),
            child: Text(
              _buyingId == item.id ? '…' : 'BUY',
              style: _mono(11, color: BrandPalette.paperLift),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(border: Border.all(color: BrandPalette.ink)),
      child: Text('The menu is being prepared.', style: _serif(20)),
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

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.api, required this.order});

  final MenuApi api;
  final MenuOrderPayment order;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  Timer? _timer;
  String _status = 'pending';
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polling || _status != 'pending') return;
    _polling = true;
    try {
      final status = await widget.api.orderStatus(widget.order.token).timeout(
        const Duration(seconds: 6),
      );
      if (!mounted) return;
      if (status.status != _status) {
        setState(() => _status = status.status);
      }
      if (_status != 'pending') _timer?.cancel();
    } catch (_) {
    } finally {
      _polling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final paid = _status == 'paid';
    final expired = _status == 'expired' || _status == 'cancelled';
    return Dialog(
      backgroundColor: BrandPalette.paper,
      shape: const RoundedRectangleBorder(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                paid
                    ? '✓ PAYMENT CONFIRMED'
                    : expired
                    ? 'PAYMENT EXPIRED'
                    : 'PAY HERE',
                style: _mono(12),
              ),
              const SizedBox(height: 14),
              Text(widget.order.itemName, style: _serif(31)),
              const SizedBox(height: 6),
              Text(_money(widget.order.amountVnd), style: _mono(14)),
              const SizedBox(height: 22),
              if (!paid && !expired) ...[
                Center(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: QrImageView(
                      data: widget.order.qrPayload,
                      version: QrVersions.auto,
                      size: 270,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(color: BrandPalette.ink),
                      dataModuleStyle: const QrDataModuleStyle(
                        color: BrandPalette.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('TRANSFER REFERENCE', style: _mono(9)),
                const SizedBox(height: 6),
                SelectableText(widget.order.paymentMessage, style: _mono(15)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: BrandPalette.ink,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Waiting for staff to confirm the bank payment…',
                        style: _serif(15, color: BrandPalette.inkMuted),
                      ),
                    ),
                  ],
                ),
              ] else if (paid)
                Text(
                  'Thank you. Your payment was confirmed by Evil Space staff.',
                  style: _serif(18, height: 1.35),
                )
              else
                Text(
                  'This payment request is no longer active. Close it and create a new order.',
                  style: _serif(17, height: 1.35),
                ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BrandPalette.ink,
                  side: const BorderSide(color: BrandPalette.ink),
                  minimumSize: const Size.fromHeight(48),
                  shape: const RoundedRectangleBorder(),
                ),
                child: Text(paid || expired ? 'CLOSE' : 'CANCEL VIEW', style: _mono(10)),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

TextStyle _serif(
  double size, {
  Color color = BrandPalette.ink,
  double? height,
}) {
  return TextStyle(
    fontFamily: 'Georgia',
    fontSize: size,
    color: color,
    height: height,
  );
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
