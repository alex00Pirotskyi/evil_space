import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'brand_logo.dart';
import 'brand_surface.dart';
import 'localization.dart';
import 'menu_api.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({
    super.key,
    required this.localization,
    required this.onBack,
  });

  final LocalizationController localization;
  final VoidCallback onBack;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _api = MenuApi();
  final Map<String, int> _cart = {};
  MenuCatalog? _menu;
  String? _error;
  bool _loading = true;
  bool _checkingOut = false;

  @override
  void initState() {
    super.initState();
    widget.localization.addListener(_languageChanged);
    _load();
  }

  @override
  void didUpdateWidget(covariant MenuScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localization != widget.localization) {
      oldWidget.localization.removeListener(_languageChanged);
      widget.localization.addListener(_languageChanged);
    }
  }

  @override
  void dispose() {
    widget.localization.removeListener(_languageChanged);
    super.dispose();
  }

  void _languageChanged() {
    if (mounted) setState(() {});
  }

  String _copy(String key) {
    final language = widget.localization.language.code;
    return _menuCopy[language]?[key] ?? _menuCopy['en']![key]!;
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final menu = await _api.menu().timeout(const Duration(seconds: 10));
      if (!mounted) return;
      final available = {
        for (final group in menu.groups)
          for (final item in group.items.where((item) => item.enabled)) item.id,
      };
      _cart.removeWhere((id, _) => !available.contains(id));
      setState(() { _menu = menu; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = _copy('load_error'); });
    }
  }

  void _changeQuantity(MenuItem item, int delta) {
    if (_checkingOut) return;
    final next = ((_cart[item.id] ?? 0) + delta).clamp(0, 20);
    setState(() {
      if (next == 0) _cart.remove(item.id); else _cart[item.id] = next;
    });
  }

  List<_CartLine> get _cartLines {
    final menu = _menu;
    if (menu == null) return const [];
    final byId = <String, MenuItem>{
      for (final group in menu.groups)
        for (final item in group.items) item.id: item,
    };
    return _cart.entries
        .map((entry) => byId[entry.key] == null
            ? null
            : _CartLine(item: byId[entry.key]!, quantity: entry.value))
        .whereType<_CartLine>()
        .toList(growable: false);
  }

  int get _cartCount => _cart.values.fold(0, (sum, value) => sum + value);
  int get _cartTotal => _cartLines.fold(0, (sum, line) => sum + line.total);

  Future<void> _checkout() async {
    if (_checkingOut || _cart.isEmpty) return;
    final lines = _cartLines;
    if (lines.isEmpty) return;
    setState(() { _checkingOut = true; _error = null; });

    try {
      List<PromoPreview> promos = const [];
      try {
        promos = await _api.eligiblePromos(Map<String, int>.from(_cart)).timeout(
          const Duration(seconds: 8),
        );
      } catch (_) {
        // Guest checkout and transient promo lookup errors must not block payment.
      }
      if (!mounted) return;
      final choice = await showDialog<_CheckoutChoice>(
        context: context,
        builder: (_) => _CheckoutDialog(
          title: _copy('cart'),
          lines: lines,
          promos: promos,
          totalLabel: _copy('total'),
          promoLabel: _copy('your_promos'),
          useLabel: _copy('use_promo'),
          noPromoLabel: _copy('without_promo'),
          payLabel: _copy('pay'),
          cancelLabel: _copy('cancel'),
        ),
      );
      if (choice == null || !mounted) {
        setState(() => _checkingOut = false);
        return;
      }

      final order = await _api
          .createCartOrder(
            Map<String, int>.from(_cart),
            promoGrantId: choice.promoGrantId,
          )
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() { _checkingOut = false; _cart.clear(); });
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PaymentDialog(api: _api, order: order, lines: lines),
      );
    } on MenuApiException catch (error) {
      if (mounted) setState(() { _checkingOut = false; _error = error.message; });
    } catch (_) {
      if (mounted) setState(() { _checkingOut = false; _error = _copy('payment_error'); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = _menu;
    return Scaffold(
      backgroundColor: BrandPalette.paper,
      bottomNavigationBar: _cart.isEmpty ? null : _cartBar(),
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
                      Text(_copy('title'), style: _serif(44)),
                      const SizedBox(height: 6),
                      Text(_copy('subtitle'), style: _serif(16, color: BrandPalette.inkMuted, height: 1.35)),
                      const SizedBox(height: 22),
                      if (_error != null) _errorBox(_error!),
                      if (_loading && menu == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: CircularProgressIndicator(color: BrandPalette.ink)),
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

  Widget _header() => Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: BrandPalette.ink))),
        child: Row(children: [
          const EvilCoworkingLogo(width: 108),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: AppLanguage.values.map((language) {
              final selected = widget.localization.language == language;
              return TextButton(
                onPressed: () => widget.localization.setLanguage(language),
                style: TextButton.styleFrom(
                  foregroundColor: BrandPalette.ink,
                  minimumSize: const Size(40, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  shape: const RoundedRectangleBorder(),
                  side: selected ? const BorderSide(color: BrandPalette.ink) : BorderSide.none,
                ),
                child: Text(language.code.toUpperCase(), style: _mono(9)),
              );
            }).toList(growable: false),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: Text(_copy('back'), style: _mono(10)),
          ),
        ]),
      );

  Widget _group(MenuGroup group) {
    final items = group.items.where((item) => item.enabled).toList(growable: false);
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.only(bottom: 8),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: BrandPalette.ink))),
        child: Text(group.name.resolve(widget.localization.language.code).toUpperCase(), style: _mono(12)),
      ),
      for (final item in items) _item(item),
    ]);
  }

  Widget _item(MenuItem item) {
    final quantity = _cart[item.id] ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: BrandPalette.rule))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.name, style: _serif(25)),
          if (item.description != null) ...[
            const SizedBox(height: 5),
            Text(item.description!, style: _serif(15, color: BrandPalette.inkMuted, height: 1.3)),
          ],
          const SizedBox(height: 8),
          Text(_money(item.priceVnd), style: _mono(12)),
        ])),
        const SizedBox(width: 16),
        if (quantity == 0)
          FilledButton(
            onPressed: _checkingOut ? null : () => _changeQuantity(item, 1),
            style: _filledButtonStyle(),
            child: Text(_copy('add'), style: _mono(10, color: BrandPalette.paperLift)),
          )
        else
          Container(
            decoration: BoxDecoration(border: Border.all(color: BrandPalette.ink)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(onPressed: _checkingOut ? null : () => _changeQuantity(item, -1), icon: const Icon(Icons.remove, size: 18)),
              SizedBox(width: 34, child: Text('$quantity', textAlign: TextAlign.center, style: _mono(12))),
              IconButton(onPressed: _checkingOut || quantity >= 20 ? null : () => _changeQuantity(item, 1), icon: const Icon(Icons.add, size: 18)),
            ]),
          ),
      ]),
    );
  }

  Widget _cartBar() => Material(
        color: BrandPalette.paperLift,
        elevation: 12,
        child: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: BrandPalette.ink))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('${_copy('cart')} · $_cartCount', style: _mono(10)),
                const SizedBox(height: 3),
                Text(_money(_cartTotal), style: _serif(21)),
              ])),
              FilledButton.icon(
                onPressed: _checkingOut ? null : _checkout,
                style: _filledButtonStyle(minWidth: 150),
                icon: _checkingOut
                    ? const SizedBox.square(dimension: 15, child: CircularProgressIndicator(strokeWidth: 2, color: BrandPalette.paperLift))
                    : const Icon(Icons.shopping_cart_checkout, size: 18),
                label: Text(_checkingOut ? '…' : _copy('checkout'), style: _mono(10, color: BrandPalette.paperLift)),
              ),
            ]),
          ),
        ),
      );

  ButtonStyle _filledButtonStyle({double minWidth = 96}) => FilledButton.styleFrom(
        foregroundColor: BrandPalette.paperLift,
        backgroundColor: BrandPalette.ink,
        minimumSize: Size(minWidth, 48),
        shape: const RoundedRectangleBorder(),
      );

  Widget _empty() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(border: Border.all(color: BrandPalette.ink)),
        child: Text(_copy('empty'), style: _serif(20)),
      );

  Widget _errorBox(String message) => Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(border: Border.all(color: BrandPalette.ink)),
        child: Text(message, style: _mono(10.5, height: 1.35)),
      );
}

class _CartLine {
  const _CartLine({required this.item, required this.quantity});
  final MenuItem item;
  final int quantity;
  int get total => item.priceVnd * quantity;
}

class _CheckoutChoice {
  const _CheckoutChoice(this.promoGrantId);
  final int? promoGrantId;
}

class _CheckoutDialog extends StatefulWidget {
  const _CheckoutDialog({
    required this.title,
    required this.lines,
    required this.promos,
    required this.totalLabel,
    required this.promoLabel,
    required this.useLabel,
    required this.noPromoLabel,
    required this.payLabel,
    required this.cancelLabel,
  });
  final String title;
  final List<_CartLine> lines;
  final List<PromoPreview> promos;
  final String totalLabel;
  final String promoLabel;
  final String useLabel;
  final String noPromoLabel;
  final String payLabel;
  final String cancelLabel;

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  int? _selectedGrantId;

  PromoPreview? get _selected {
    if (_selectedGrantId == null) return null;
    for (final promo in widget.promos) {
      if (promo.grantId == _selectedGrantId) return promo;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = widget.lines.fold(0, (sum, line) => sum + line.total);
    final selected = _selected;
    final total = selected?.finalAmountVnd ?? subtotal;
    return Dialog(
      backgroundColor: BrandPalette.paper,
      shape: const RoundedRectangleBorder(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(widget.title.toUpperCase(), style: _mono(12)),
            const SizedBox(height: 14),
            for (final line in widget.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Text('${line.quantity} ×', style: _mono(10)),
                  const SizedBox(width: 9),
                  Expanded(child: Text(line.item.name, style: _serif(18))),
                  Text(_money(line.total), style: _mono(10)),
                ]),
              ),
            if (widget.promos.isNotEmpty) ...[
              const Divider(color: BrandPalette.ink),
              Text(widget.promoLabel.toUpperCase(), style: _mono(10)),
              const SizedBox(height: 7),
              for (final promo in widget.promos)
                RadioListTile<int?>(
                  value: promo.grantId,
                  groupValue: _selectedGrantId,
                  contentPadding: EdgeInsets.zero,
                  title: Text(promo.name, style: _serif(17)),
                  subtitle: Text('${widget.useLabel} · -${_money(promo.discountVnd)} · ${promo.remainingUses} USE${promo.remainingUses == 1 ? '' : 'S'}', style: _mono(8.5, color: BrandPalette.inkMuted)),
                  onChanged: (value) => setState(() => _selectedGrantId = value),
                ),
              RadioListTile<int?>(
                value: null,
                groupValue: _selectedGrantId,
                contentPadding: EdgeInsets.zero,
                title: Text(widget.noPromoLabel, style: _serif(16)),
                onChanged: (_) => setState(() => _selectedGrantId = null),
              ),
            ],
            const Divider(color: BrandPalette.ink),
            if (selected != null) ...[
              _priceRow('SUBTOTAL', subtotal),
              _priceRow(selected.name.toUpperCase(), -selected.discountVnd),
              const SizedBox(height: 4),
            ],
            Row(children: [
              Expanded(child: Text(widget.totalLabel.toUpperCase(), style: _mono(11))),
              Text(_money(total), style: _serif(24)),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(widget.cancelLabel.toUpperCase(), style: _mono(9)))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(
                onPressed: () => Navigator.pop(context, _CheckoutChoice(_selectedGrantId)),
                style: FilledButton.styleFrom(backgroundColor: BrandPalette.ink, foregroundColor: BrandPalette.paperLift, shape: const RoundedRectangleBorder(), minimumSize: const Size.fromHeight(48)),
                child: Text(widget.payLabel.toUpperCase(), style: _mono(9, color: BrandPalette.paperLift)),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _priceRow(String label, int value) => Row(children: [
        Expanded(child: Text(label, style: _mono(9, color: BrandPalette.inkMuted))),
        Text(_money(value), style: _mono(9, color: BrandPalette.inkMuted)),
      ]);
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.api, required this.order, required this.lines});
  final MenuApi api;
  final MenuOrderPayment order;
  final List<_CartLine> lines;
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
      final status = await widget.api.orderStatus(widget.order.token).timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (status.status != _status) setState(() => _status = status.status);
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
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(paid ? '✓ PAYMENT CONFIRMED' : expired ? 'PAYMENT EXPIRED' : 'PAY HERE', style: _mono(12)),
            const SizedBox(height: 14),
            for (final line in widget.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('${line.quantity} × ${line.item.name} · ${_money(line.total)}', style: _serif(17)),
              ),
            if (widget.order.hasPromo) ...[
              const Divider(color: BrandPalette.rule),
              _summaryRow('SUBTOTAL', widget.order.originalAmountVnd),
              _summaryRow(widget.order.promoName?.toUpperCase() ?? 'PROMO', -widget.order.promoDiscountVnd),
            ],
            const SizedBox(height: 6),
            Text('TOTAL · ${_money(widget.order.amountVnd)}', style: _mono(14)),
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
                    dataModuleStyle: const QrDataModuleStyle(color: BrandPalette.ink),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('TRANSFER REFERENCE', style: _mono(9)),
              const SizedBox(height: 6),
              SelectableText(widget.order.paymentMessage, style: _mono(15)),
              const SizedBox(height: 18),
              Row(children: [
                const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: BrandPalette.ink)),
                const SizedBox(width: 10),
                Expanded(child: Text('Waiting for staff to confirm the bank payment…', style: _serif(15, color: BrandPalette.inkMuted))),
              ]),
            ] else if (paid)
              Text('Thank you. Your whole order is confirmed${widget.order.hasPromo ? ' and your promo was used.' : '.'}', style: _serif(18, height: 1.35))
            else
              Text('This payment request is no longer active. Any reserved promo has been returned to your account.', style: _serif(17, height: 1.35)),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(foregroundColor: BrandPalette.ink, side: const BorderSide(color: BrandPalette.ink), minimumSize: const Size.fromHeight(48), shape: const RoundedRectangleBorder()),
              child: Text(paid || expired ? 'CLOSE' : 'CANCEL VIEW', style: _mono(10)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, int value) => Row(children: [
        Expanded(child: Text(label, style: _mono(9, color: BrandPalette.inkMuted))),
        Text(_money(value), style: _mono(9, color: BrandPalette.inkMuted)),
      ]);
}

const _menuCopy = <String, Map<String, String>>{
  'en': {
    'title': 'MENU',
    'subtitle': 'Add anything you want, choose quantities, then pay for the whole cart with one QR.',
    'back': 'BACK', 'add': 'ADD', 'cart': 'CART', 'checkout': 'CHECKOUT',
    'total': 'Total', 'pay': 'Create payment', 'cancel': 'Cancel',
    'your_promos': 'Your promos', 'use_promo': 'Use promo', 'without_promo': 'Pay without promo',
    'empty': 'The menu is being prepared.', 'load_error': 'Could not load the menu.',
    'payment_error': 'Could not create the payment.',
  },
  'ru': {
    'title': 'МЕНЮ',
    'subtitle': 'Добавьте нужные товары, выберите количество и оплатите всю корзину одним QR.',
    'back': 'НАЗАД', 'add': 'ДОБАВИТЬ', 'cart': 'КОРЗИНА', 'checkout': 'ОФОРМИТЬ',
    'total': 'Итого', 'pay': 'Создать оплату', 'cancel': 'Отмена',
    'your_promos': 'Ваши промо', 'use_promo': 'Использовать', 'without_promo': 'Без промо',
    'empty': 'Меню готовится.', 'load_error': 'Не удалось загрузить меню.',
    'payment_error': 'Не удалось создать платёж.',
  },
  'vi': {
    'title': 'THỰC ĐƠN',
    'subtitle': 'Thêm món, chọn số lượng rồi thanh toán toàn bộ giỏ hàng bằng một mã QR.',
    'back': 'QUAY LẠI', 'add': 'THÊM', 'cart': 'GIỎ HÀNG', 'checkout': 'THANH TOÁN',
    'total': 'Tổng', 'pay': 'Tạo thanh toán', 'cancel': 'Hủy',
    'your_promos': 'Khuyến mãi của bạn', 'use_promo': 'Dùng khuyến mãi', 'without_promo': 'Không dùng khuyến mãi',
    'empty': 'Thực đơn đang được chuẩn bị.', 'load_error': 'Không thể tải thực đơn.',
    'payment_error': 'Không thể tạo thanh toán.',
  },
};

String _money(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index += 1) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return '${value < 0 ? '-' : ''}${buffer.toString()} VND';
}

TextStyle _serif(double size, {Color color = BrandPalette.ink, double? height}) => TextStyle(
      fontFamily: 'Georgia',
      fontSize: size,
      color: color,
      height: height,
    );

TextStyle _mono(double size, {Color color = BrandPalette.ink, double? height}) => TextStyle(
      fontFamily: 'Courier New',
      fontFamilyFallback: const ['monospace'],
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.7,
      color: color,
      height: height,
    );
