part of 'menu_screen.dart';


class _LiveCheckoutResult {
  const _LiveCheckoutResult({
    required this.lines,
    required this.order,
    required this.paid,
  });

  final List<_CartLine> lines;
  final MenuOrderPayment? order;
  final bool paid;
}

class _LiveCheckoutDialog extends StatefulWidget {
  const _LiveCheckoutDialog({
    required this.api,
    required this.lines,
    required this.languageCode,
    this.initialOrder,
  });

  final MenuApi api;
  final List<_CartLine> lines;
  final String languageCode;
  final MenuOrderPayment? initialOrder;

  @override
  State<_LiveCheckoutDialog> createState() => _LiveCheckoutDialogState();
}

class _LiveCheckoutDialogState extends State<_LiveCheckoutDialog> {
  late final List<_CartLine> _lines;
  List<PromoPreview> _promos = const [];
  MenuOrderPayment? _order;
  Timer? _pollTimer;
  Timer? _syncTimer;
  int? _selectedGrantId;
  String _status = 'pending';
  String? _error;
  bool _syncing = false;
  bool _dirty = true;
  bool _loadingPromos = true;
  bool _cashSelected = false;
  int _revision = 0;

  String _copy(String key) =>
      _menuCopy[widget.languageCode]?[key] ?? _menuCopy['en']![key]!;

  int get _subtotal => _lines.fold(0, (sum, line) => sum + line.total);

  PromoPreview? get _selectedPromo {
    final id = _selectedGrantId;
    if (id == null) return null;
    for (final promo in _promos) {
      if (promo.grantId == id) return promo;
    }
    return null;
  }

  int get _displayDiscount {
    final selected = _selectedPromo;
    if (selected != null) return selected.discountVnd;
    final order = _order;
    if (!_dirty &&
        order != null &&
        order.promoGrantId == _selectedGrantId &&
        order.hasPromo) {
      return order.promoDiscountVnd;
    }
    return 0;
  }

  int get _displayTotal {
    if (!_dirty && _order != null) return _order!.amountVnd;
    return (_subtotal - _displayDiscount).clamp(1, 999999999).toInt();
  }

  bool get _paid => _status == 'paid';
  bool get _inactive => _status == 'expired' || _status == 'cancelled';
  bool get _paymentReady =>
      !_dirty && !_syncing && _order != null && _status == 'pending';

  @override
  void initState() {
    super.initState();
    _lines = widget.lines.map((line) => line.copyWith()).toList();
    _order = widget.initialOrder;
    _selectedGrantId = widget.initialOrder?.promoGrantId;
    _status = widget.initialOrder?.status ?? 'pending';
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_initialize());
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (_lines.isEmpty) {
      _close();
      return;
    }
    final existing = _order;
    if (existing != null) {
      try {
        final status = await widget.api
            .orderStatus(existing.token)
            .timeout(const Duration(seconds: 6));
        if (!mounted) return;
        if (status.paid) {
          setState(() {
            _status = 'paid';
            _dirty = false;
            _loadingPromos = false;
          });
          _pollTimer?.cancel();
          return;
        }
        if (!status.pending) {
          _order = null;
          _selectedGrantId = null;
        }
      } catch (_) {
        // Re-syncing below will surface a real session error if needed.
      }
    }
    await _refreshPromos();
    if (!mounted) return;
    await _syncPayment();
  }

  Future<void> _refreshPromos() async {
    if (_lines.isEmpty || _paid) return;
    if (mounted) setState(() => _loadingPromos = true);
    try {
      final promos = await widget.api
          .eligiblePromos(
            _requests,
            paymentToken: _order?.token,
          )
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _promos = promos;
        _loadingPromos = false;
        if (_selectedGrantId != null &&
            !_promos.any((promo) => promo.grantId == _selectedGrantId) &&
            _order?.promoGrantId != _selectedGrantId) {
          _selectedGrantId = null;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPromos = false);
    }
  }

  List<MenuCartRequestLine> get _requests =>
      _lines.map((line) => line.request).toList(growable: false);

  void _scheduleSync({bool immediate = false}) {
    if (_paid || _lines.isEmpty) return;
    _revision += 1;
    _dirty = true;
    _error = null;
    _syncTimer?.cancel();
    if (mounted) setState(() {});
    _syncTimer = Timer(
      immediate ? Duration.zero : const Duration(milliseconds: 420),
      () => unawaited(_syncPayment()),
    );
  }

  Future<void> _syncPayment() async {
    if (_syncing || _lines.isEmpty || _paid) return;
    _syncTimer?.cancel();
    final revision = _revision;
    final requests = _requests;
    final promoGrantId = _selectedGrantId;
    setState(() {
      _syncing = true;
      _error = null;
    });

    try {
      final current = _order;
      final next = current == null
          ? await widget.api
              .createCartOrder(requests, promoGrantId: promoGrantId)
              .timeout(const Duration(seconds: 12))
          : await widget.api
              .updateCartOrder(
                current.token,
                requests,
                promoGrantId: promoGrantId,
              )
              .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _order = next;
        _status = next.status;
        _syncing = false;
        if (revision == _revision) _dirty = false;
      });
      unawaited(_refreshPromos());
      if (_dirty) _scheduleSync(immediate: true);
    } on MenuApiException catch (error) {
      if (!mounted) return;
      if (promoGrantId != null && error.statusCode == 409) {
        setState(() {
          _selectedGrantId = null;
          _syncing = false;
          _error = null;
        });
        _scheduleSync(immediate: true);
        return;
      }
      setState(() {
        _syncing = false;
        _dirty = true;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _dirty = true;
        _error = _copy('payment_error');
      });
    }
  }

  Future<void> _poll() async {
    final order = _order;
    if (order == null || _syncing || _dirty || _paid) return;
    try {
      final status = await widget.api
          .orderStatus(order.token)
          .timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (status.status == _status) return;
      if (status.paid) {
        setState(() => _status = 'paid');
        _pollTimer?.cancel();
        return;
      }
      if (!status.pending) {
        setState(() {
          _status = status.status;
          _order = null;
          _selectedGrantId = null;
          _dirty = true;
        });
        await _refreshPromos();
        if (mounted) _scheduleSync(immediate: true);
      }
    } catch (_) {}
  }

  void _changeQuantity(int index, int delta) {
    if (_paid || _syncing) return;
    final line = _lines[index];
    final next = (line.quantity + delta).clamp(0, 20).toInt();
    if (next == line.quantity) return;
    setState(() {
      if (next == 0) {
        _lines.removeAt(index);
      } else {
        _lines[index] = line.copyWith(quantity: next);
      }
    });
    if (_lines.isEmpty) {
      unawaited(_cancelAndClose());
      return;
    }
    _scheduleSync();
  }

  void _removeLine(int index) {
    if (_paid || _syncing) return;
    setState(() => _lines.removeAt(index));
    if (_lines.isEmpty) {
      unawaited(_cancelAndClose());
      return;
    }
    _scheduleSync();
  }

  void _selectPromo(int? grantId) {
    if (_paid || _syncing || grantId == _selectedGrantId) return;
    setState(() => _selectedGrantId = grantId);
    _scheduleSync(immediate: true);
  }

  Future<void> _cancelAndClose() async {
    final order = _order;
    if (order != null) {
      try {
        await widget.api.cancelCartOrder(order.token);
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.of(context).pop(
      _LiveCheckoutResult(
        lines: List.unmodifiable(_lines),
        order: null,
        paid: false,
      ),
    );
  }

  void _close() {
    Navigator.of(context).pop(
      _LiveCheckoutResult(
        lines: List.unmodifiable(_lines),
        order: _paid ? null : _order,
        paid: _paid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final discount = _displayDiscount;
    final total = _displayTotal;
    final currentPromoMissing =
        _selectedGrantId != null &&
        !_promos.any((promo) => promo.grantId == _selectedGrantId) &&
        order?.promoGrantId == _selectedGrantId &&
        order?.hasPromo == true;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: BrandPalette.paper,
        shape: const RoundedRectangleBorder(),
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_copy('your_cart').toUpperCase(), style: _mono(12)),
                const SizedBox(height: 12),
                for (var index = 0; index < _lines.length; index++)
                  _cartLine(index),
                const Divider(color: BrandPalette.ink, height: 28),
                Text(_copy('your_promos').toUpperCase(), style: _mono(10)),
                const SizedBox(height: 6),
                RadioListTile<int?>(
                  value: null,
                  groupValue: _selectedGrantId,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(_copy('without_promo'), style: _serif(16)),
                  onChanged: _syncing ? null : _selectPromo,
                ),
                if (currentPromoMissing)
                  RadioListTile<int?>(
                    value: _selectedGrantId,
                    groupValue: _selectedGrantId,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      order?.promoName ?? _copy('promo'),
                      style: _serif(17),
                    ),
                    subtitle: Text(
                      '-${_money(order!.promoDiscountVnd)}',
                      style: _mono(8.5, color: BrandPalette.inkMuted),
                    ),
                    onChanged: _syncing ? null : _selectPromo,
                  ),
                for (final promo in _promos)
                  RadioListTile<int?>(
                    value: promo.grantId,
                    groupValue: _selectedGrantId,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(promo.name, style: _serif(17)),
                    subtitle: Text(
                      '-${_money(promo.discountVnd)} \u00B7 ${promo.remainingUses} USE${promo.remainingUses == 1 ? '' : 'S'}',
                      style: _mono(8.5, color: BrandPalette.inkMuted),
                    ),
                    onChanged: _syncing ? null : _selectPromo,
                  ),
                if (_loadingPromos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _copy('loading_promos'),
                      style: _mono(8.5, color: BrandPalette.inkMuted),
                    ),
                  ),
                const Divider(color: BrandPalette.ink),
                _priceRow(_copy('subtotal').toUpperCase(), _subtotal),
                if (discount > 0)
                  _priceRow(
                    (order?.promoName ?? _selectedPromo?.name ?? _copy('promo'))
                        .toUpperCase(),
                    -discount,
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(_copy('total').toUpperCase(), style: _mono(11)),
                    ),
                    Text(_money(total), style: _serif(24)),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  '${_copy('pay_now').toUpperCase()} ${_money(total)}',
                  textAlign: TextAlign.center,
                  style: _mono(13),
                ),
                const SizedBox(height: 16),
                if (_paid)
                  _paidView()
                else if (_inactive)
                  _inactiveView()
                else if (!_paymentReady)
                  _updatingView()
                else if (_cashSelected)
                  _cashView()
                else
                  _qrView(order!),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Bord