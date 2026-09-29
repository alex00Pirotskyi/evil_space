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