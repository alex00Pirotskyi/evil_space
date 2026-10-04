part of 'menu_screen.dart';

String _newPaymentToken() {
  final random = Random.secure();
  return base64UrlEncode(
    List.generate(32, (_) => random.nextInt(256)),
  ).replaceAll('=', '');
}

class _LiveCheckoutResult {
  const _LiveCheckoutResult({
    required this.lines,
    required this.order,
    required this.paid,
    required this.paymentToken,
    required this.synced,
  });
  final bool synced;
  final List<_CartLine> lines;
  final MenuOrderPayment? order;
  final bool paid;
  final String paymentToken;
}

class _LiveCheckoutSheet extends StatefulWidget {
  const _LiveCheckoutSheet({
    super.key,
    required this.api,
    required this.lines,
    required this.languageCode,
    required this.paymentToken,
    required this.onClose,
    this.initialOrder,
    this.initialRemoveKey,
  });
  final MenuApi api;
  final List<_CartLine> lines;
  final String languageCode;
  final String paymentToken;
  final ValueChanged<_LiveCheckoutResult> onClose;
  final MenuOrderPayment? initialOrder;
  final String? initialRemoveKey;
  @override
  State<_LiveCheckoutSheet> createState() => _LiveCheckoutSheetState();
}

class _LiveCheckoutSheetState extends State<_LiveCheckoutSheet>
    with WidgetsBindingObserver {
  late final List<_CartLine> _lines;
  late String _paymentToken;
  List<_CartLine> _syncedLines = const [];
  List<PromoPreview> _promos = const [];
  MenuOrderPayment? _order;
  Timer? _pollTimer;
  int? _selectedGrantId;
  String _status = 'pending';
  String? _error;
  bool _initializing = true;
  bool _syncing = false;
  bool _polling = false;
  bool _dirty = true;
  bool _loadingPromos = false;
  bool _cashSelected = false;
  bool _cancelling = false;
  bool _closing = false;
  bool _resumed = true;
  int _revision = 0;
  int _promoRequest = 0;
  double _swipeDistance = 0;

  String _copy(String key) =>
      _menuCopy[widget.languageCode]?[key] ?? _menuCopy['en']![key]!;
  bool get _paid => _status == 'paid';
  bool get _inactive => _status == 'expired' || _status == 'cancelled';
  bool get _busy => _initializing || _syncing || _cancelling;
  bool get _editable => !_closing && !_busy && !_paid && !_inactive;
  bool get _paymentReady =>
      !_dirty &&
      !_busy &&
      _order != null &&
      _status == 'pending' &&
      _error == null;
  int get _subtotal => !_dirty && _order != null
      ? _order!.originalAmountVnd
      : _lines.fold(0, (sum, line) => sum + line.total);
  int get _discount => !_dirty ? (_order?.promoDiscountVnd ?? 0) : 0;
  int get _total => !_dirty && _order != null ? _order!.amountVnd : _subtotal;
  List<MenuCartRequestLine> get _requests =>
      _lines.map((line) => line.request).toList(growable: false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lines = widget.lines.map((line) => line.copyWith()).toList();
    final storedToken = widget.initialOrder?.token;
    _paymentToken = storedToken != null && storedToken.isNotEmpty
        ? storedToken
        : widget.paymentToken;
    _order = widget.initialOrder;
    _syncedLines = List.of(_lines);
    _selectedGrantId = _order?.promoGrantId;
    _status = _order?.status ?? 'pending';
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed) unawaited(_poll());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (!mounted) return;
    if (_order != null) {
      try {
        final status = await widget.api.orderStatus(_paymentToken);
        if (!mounted) return;
        _status = status.status;
        if (!status.pending) {
          setState(() {
            _initializing = false;
            _dirty = false;
            _applyStatus(status);
          });
          return;
        }
      } on MenuApiException catch (error) {
        if (!mounted) return;
        if (error.statusCode == 404) _order = null;
      } catch (_) {}
    }
    setState(() => _initializing = false);
    final removeKey = widget.initialRemoveKey;
    if (removeKey != null) {
      final index = _lines.indexWhere((line) => line.key == removeKey);
      if (index >= 0) {
        setState(() {
          final line = _lines[index];
          if (line.quantity == 1) { _lines.removeAt(index); }
          else { _lines[index] = line.copyWith(quantity: line.quantity - 1); }
          _revision++;
          _dirty = true;
        });
      }
      if (_lines.isEmpty) { await _cancelEmptyCart(); }
      else {
        await _syncPayment();
        if (mounted && !_paid && !_busy && _error == null && !_dirty) _close();
      }
      return;
    }
    // Promo lookup never delays the first QR.
    unawaited(_refreshPromos());
    await _syncPayment();
  }

  Future<void> _refreshPromos() async {
    if (_lines.isEmpty || _paid || _inactive) return;
    final requestId = ++_promoRequest;
    final revision = _revision;
    setState(() => _loadingPromos = true);
    try {
      final promos = await widget.api.eligiblePromos(
        _requests,
        paymentToken: _order?.token,
      );
      if (!mounted || requestId != _promoRequest || revision != _revision) {
        return;
      }
      setState(() {
        _promos = promos;
        _loadingPromos = false;
      });
    } catch (_) {
      if (mounted && requestId == _promoRequest) {
        setState(() => _loadingPromos = false);
      }
    }
  }

  void _syncCart() {
    _revision++;
    _promoRequest++;
    setState(() {
      _dirty = true;
      _error = null;
      _promos = const [];
      _loadingPromos = false;
    });
    unawaited(_syncPayment());
  }

  Future<void> _syncPayment({bool recoverMissing = true}) async {
    if (!mounted || _busy || _lines.isEmpty || _paid || _inactive) return;
    final revision = _revision;
    final requests = _requests;
    final grantId = _selectedGrantId;
    final creating = _order == null;
    setState(() {
      _syncing = true;
      _error = null;
    });
    try {
      final next = creating
          ? await widget.api.createCartOrder(
              requests,
              promoGrantId: grantId,
              paymentToken: _paymentToken,
            )
          : await widget.api.updateCartOrder(
              _paymentToken,
              requests,
              promoGrantId: grantId,
            );
      if (!mounted) return;
      setState(() {
        _order = next;
        // Older servers may return a canonical token different from our hint.
        if (next.token.isNotEmpty) _paymentToken = next.token;
        _status = next.status;
        _syncing = false;
        _dirty = revision != _revision;
        if (!_dirty) {
          for (var i = 0; i < _lines.length && i < next.items.length; i++) {
            final trusted = next.items[i];
            if (trusted.itemId == _lines[i].item.id) {
              _lines[i] = _lines[i].copyWith(
                quantity: trusted.quantity,
                unitPriceVnd: trusted.unitPriceVnd,
              );
            }
          }
          _syncedLines = List.of(_lines);
        }
      });
      if (_dirty) {
        unawaited(_syncPayment());
      } else {
        unawaited(_refreshPromos());
      }
    } on MenuApiException catch (error) {
      if (!mounted) return;
      var missingSession = false;
      if (error.statusCode == 409 || error.statusCode == 404) {
        try {
          final status = await widget.api.orderStatus(_paymentToken);
          if (!mounted) return;
          if (!status.pending) {
            setState(() {
              _applyStatus(status);
              _syncing = false;
              _dirty = false;
            });
            return;
          }
        } on MenuApiException catch (statusError) {
          missingSession = error.statusCode == 404 && statusError.statusCode == 404;
        } catch (_) {}
      }
      if (!mounted) return;
      if (missingSession && !creating && recoverMissing) {
        setState(() {
          _order = null;
          _syncing = false;
          _dirty = true;
        });
        // Reuse the same token for the server's idempotent create endpoint.
        // Never rotate it after an ambiguous network failure.
        await _syncPayment(recoverMissing: false);
        return;
      }
      setState(() {
        _syncing = false;
        _dirty = true;
        _error = error.message;
      });
      unawaited(_refreshPromos());
    } catch (_) {
      if (mounted) {
        setState(() {
          _syncing = false;
          _dirty = true;
          _error = _copy('payment_error');
        });
      }
    }
  }

  Future<void> _poll() async {
    if (_closing ||
        !_resumed ||
        _order == null ||
        _busy ||
        _polling ||
        _paid ||
        _inactive) {
      return;
    }
    _polling = true;
    final revision = _revision;
    final token = _paymentToken;
    try {
      final status = await widget.api.orderStatus(token);
      if (!mounted || _closing || _busy || token != _paymentToken) return;
      if (!status.pending) {
        setState(() {
          _applyStatus(status);
          _dirty = false;
          _error = null;
        });
      } else if (revision == _revision &&
          !_syncing &&
          !_dirty &&
          status.amountVnd != _order!.amountVnd) {
        setState(() {
          _dirty = true;
          _error = _copy('payment_changed');
        });
      }
    } catch (_) {
    } finally {
      _polling = false;
    }
  }

  void _applyStatus(MenuOrderStatus status) {
    _status = status.status;
    if (status.paid) {
      _lines
        ..clear()
        ..addAll(_syncedLines);
      _order = MenuOrderPayment(
        token: _paymentToken,
        orderCode: status.orderCode,
        itemId: status.itemId,
        itemName: status.itemName,
        amountVnd: status.amountVnd,
        paymentMessage: status.paymentMessage,
        qrPayload: '',
        status: status.status,
        createdAt: status.createdAt,
        expiresAt: status.expiresAt,
        originalAmountVnd: status.originalAmountVnd,
        promoEligibleAmountVnd: status.promoEligibleAmountVnd,
        promoDiscountVnd: status.promoDiscountVnd,
        promoGrantId: status.promoGrantId,
        promoName: status.promoName,
      );
    }
  }

  void _changeQuantity(String key, int delta) {
    if (!_editable) return;
    final index = _lines.indexWhere((line) => line.key == key);
    if (index < 0) return;
    final line = _lines[index];
    final quantity = (line.quantity + delta).clamp(0, 20).toInt();
    if (quantity == line.quantity) return;
    setState(() {
      if (quantity == 0) {
        _lines.removeAt(index);
      } else {
        _lines[index] = line.copyWith(quantity: quantity);
      }
    });
    if (_lines.isEmpty) {
      unawaited(_cancelEmptyCart());
    } else {
      _syncCart();
    }
  }

  void _removeLine(String key) {
    if (!_editable) return;
    final index = _lines.indexWhere((line) => line.key == key);
    if (index < 0) return;
    setState(() => _lines.removeAt(index));
    if (_lines.isEmpty) {
      unawaited(_cancelEmptyCart());
    } else {
      _syncCart();
    }
  }

  void _selectPromo(int? id) {
    if (!_editable || id == _selectedGrantId) return;
    setState(() => _selectedGrantId = id);
    _syncCart();
  }

  Future<void> _cancelEmptyCart() async {
    setState(() {
      _cancelling = true;
      _dirty = true;
      _error = null;
    });
    try {
      await widget.api.cancelCartOrder(_paymentToken);
      // A successful cancellation is final; another status request must not
      // block removing the last line on a slow or disconnected network.
      _status = 'cancelled';
      _order = null;
    } on MenuApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 409) {
        try {
          final status = await widget.api.orderStatus(_paymentToken);
          if (!mounted) return;
          if (!status.pending) {
            setState(() {
              _applyStatus(status);
              _cancelling = false;
              _dirty = false;
              _error = null;
            });
            if (!status.paid) {
              _order = null;
              _close();
            }
            return;
          }
        } catch (_) {}
      }
      if (!mounted) return;
      if (error.statusCode != 404) {
        setState(() {
          _cancelling = false;
          _error = error.message;
        });
        return;
      }
      _status = 'cancelled';
      _order = null;
    } catch (_) {
      if (mounted) {
        setState(() {
          _cancelling = false;
          _error = _copy('payment_error');
        });
      }
      return;
    }
    if (!mounted) return;
    _cancelling = false;
    _close();
  }

  void _newPayment() {
    if (_busy) return;
    setState(() {
      _paymentToken = _newPaymentToken();
      _order = null;
      _status = 'pending';
      _selectedGrantId = null;
    });
    _syncCart();
  }

  void _close() {
    if (_closing || _busy || _lines.isEmpty && _error != null) return;
    _closing = true;
    _pollTimer?.cancel();
    widget.onClose(
      _LiveCheckoutResult(
        lines: List.unmodifiable(_lines),
        order: _order,
        paid: _paid,
        paymentToken: _paymentToken,
        synced: !_dirty && _error == null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _close();
    },
    child: GestureDetector(
      key: const ValueKey('menu-payment-view'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _swipeDistance = 0,
      onHorizontalDragUpdate: (details) => _swipeDistance += details.primaryDelta ?? 0,
      onHorizontalDragEnd: (details) {
        if (_swipeDistance > 65 || (details.primaryVelocity ?? 0) > 350) _close();
      },
      child: ColoredBox(color: BrandPalette.paper,
        child: Column(children: [
          SizedBox(height: 52, width: double.infinity,
            child: DecoratedBox(decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: BrandPalette.rule))),
              child: TextButton.icon(
                key: const ValueKey('checkout-menu'),
                onPressed: _busy || _closing || _lines.isEmpty && _error != null ? null : _close,
                style: TextButton.styleFrom(foregroundColor: BrandPalette.ink,
                  shape: const RoundedRectangleBorder()).copyWith(overlayColor: _menuInkOverlay),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(_copy('return_menu'), style: _mono(12)),
              ))),
          Expanded(child: LayoutBuilder(builder: (context, constraints) =>
            ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {
                ...ScrollConfiguration.of(context).dragDevices, PointerDeviceKind.mouse,
              }),
              child: SingleChildScrollView(
                child: Center(child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Padding(padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
                    child: _content()),
                )),
              ),
            ),
          )),
        ])),
    ),
  );

  Widget _content() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_copy('your_cart').toUpperCase(), style: _mono(12)),
          const SizedBox(height: 12),
          for (var i = 0; i < _lines.length; i++) _cartLine(i),
          if (!_paid && !_inactive && _lines.isNotEmpty) ...[
            const Divider(color: BrandPalette.ink, height: 28),
            Text(_copy('your_promos').toUpperCase(), style: _mono(10)),
            _promoTile(null, _copy('without_promo')),
            if (_selectedGrantId != null &&
                !_promos.any((p) => p.grantId == _selectedGrantId))
              _promoTile(
                _selectedGrantId,
                _order?.promoName ?? _copy('promo'),
              ),
            for (final promo in _promos)
              _promoTile(
                promo.grantId,
                promo.name,
                '-${_money(promo.discountVnd)} · ${promo.remainingUses} ${_copy('uses_left')}',
              ),
            if (_loadingPromos)
              Text(
                _copy('loading_promos'),
                style: _mono(8.5, color: BrandPalette.inkMuted),
              ),
          ],
          const Divider(color: BrandPalette.ink),
          _priceRow(_copy('subtotal'), _subtotal),
          if (_discount > 0)
            _priceRow(_order?.promoName ?? _copy('promo'), -_discount),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(_copy('total').toUpperCase(), style: _mono(11)),
              ),
              Flexible(child: Text(_money(_total), style: _serif(24))),
            ],
          ),
          const SizedBox(height: 24),
          if (_paid) ...[
            Text(
              _copy('payment_confirmed'),
              textAlign: TextAlign.center,
              style: _mono(12),
            ),
            const SizedBox(height: 12),
            Text(
              _copy(
                _order?.hasPromo == true
                    ? 'payment_thanks_promo'
                    : 'payment_thanks',
              ),
              style: _serif(18),
            ),
          ] else if (_inactive) ...[
            Text(_copy('payment_expired'), style: _mono(12)),
            const SizedBox(height: 12),
            Text(_copy('payment_inactive'), style: _serif(16)),
            const SizedBox(height: 12),
            _button(_copy('refresh_payment'), _newPayment),
          ] else if (_paymentReady) ...[
            Text(
              '${_copy('pay_now').toUpperCase()} ${_money(_total)}',
              textAlign: TextAlign.center,
              style: _mono(13),
            ),
            const SizedBox(height: 16),
            if (_cashSelected) _cashView() else _qrView(),
          ] else if (_error == null) ...[
            const SizedBox(height: 26),
            const Center(
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: BrandPalette.ink,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _copy(
                _order == null ? 'preparing_payment' : 'updating_payment',
              ),
              textAlign: TextAlign.center,
              style: _serif(15),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: _serif(15)),
            const SizedBox(height: 12),
            _button(
              _copy('retry'),
              _busy
                  ? null
                  : () {
                      if (_lines.isEmpty) {
                        unawaited(_cancelEmptyCart());
                      } else {
                        unawaited(_syncPayment());
                      }
                    },
            ),
          ],
        ],
      );

  Widget _cartLine(int i) {
    final line = _lines[i];
    return Padding(
      key: ValueKey(line.key),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(line.label(widget.languageCode), style: _serif(18)),
          const SizedBox(height: 7),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '-',
                    style: const ButtonStyle(overlayColor: _menuInkOverlay),
                    onPressed: _editable
                        ? () => _changeQuantity(line.key, -1)
                        : null,
                    icon: const Icon(Icons.remove, size: 18),
                  ),
                  Text('${line.quantity}', style: _mono(11)),
                  IconButton(
                    tooltip: '+',
                    style: const ButtonStyle(overlayColor: _menuInkOverlay),
                    onPressed: _editable && line.quantity < 20
                        ? () => _changeQuantity(line.key, 1)
                        : null,
                    icon: const Icon(Icons.add, size: 18),
                  ),
                ],
              ),
              Text(_money(line.total), style: _mono(10)),
              SizedBox(
                width: 64,
                child: _MenuRemoveAction(
                  label: _copy('remove').toUpperCase(),
                  onPressed: _editable ? () => _removeLine(line.key) : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _promoTile(int? id, String name, [String? subtitle]) =>
      RadioListTile<int?>(
        value: id,
        groupValue: _selectedGrantId,
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(name, style: _serif(16)),
        subtitle: subtitle == null ? null : Text(subtitle, style: _mono(8.5)),
        onChanged: _editable ? _selectPromo : null,
      );
  Widget _priceRow(String name, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(name, style: _mono(9))),
        Text(_money(value), style: _mono(9)),
      ],
    ),
  );
  Widget _button(
    String text,
    VoidCallback? action, {
    IconData? icon,
  }) => OutlinedButton(
    onPressed: action,
    style: OutlinedButton.styleFrom(
      foregroundColor: BrandPalette.ink,
      side: const BorderSide(color: BrandPalette.ink),
      minimumSize: const Size.fromHeight(48),
      shape: const RoundedRectangleBorder(),
    ).copyWith(overlayColor: _menuInkOverlay),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
        Flexible(
          child: Text(
            text.toUpperCase(),
            textAlign: TextAlign.center,
            style: _mono(10),
          ),
        ),
      ],
    ),
  );
  Widget _qrView() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (_, constraints) => Center(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: QrImageView(
              data: _order!.qrPayload,
              version: QrVersions.auto,
              size: min(260, constraints.maxWidth - 24),
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(color: BrandPalette.ink),
              dataModuleStyle: const QrDataModuleStyle(color: BrandPalette.ink),
            ),
          ),
        ),
      ),
      const SizedBox(height: 18),
      Text(_copy('transfer_reference').toUpperCase(), style: _mono(9)),
      const SizedBox(height: 6),
      SelectableText(_order!.paymentMessage, style: _mono(15)),
      const SizedBox(height: 18),
      Text(
        _copy('waiting_bank'),
        style: _serif(15, color: BrandPalette.inkMuted),
      ),
      const SizedBox(height: 18),
      _button(
        _copy('pay_cash'),
        () => setState(() => _cashSelected = true),
        icon: Icons.payments_outlined,
      ),
    ],
  );
  Widget _cashView() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(_copy('cash_title'), style: _mono(11)),
      const SizedBox(height: 9),
      Text(_copy('cash_instruction'), style: _serif(17)),
      const SizedBox(height: 18),
      Text(
        _copy('waiting_cash'),
        style: _serif(15, color: BrandPalette.inkMuted),
      ),
      const SizedBox(height: 18),
      _button(
        _copy('pay_qr'),
        () => setState(() => _cashSelected = false),
        icon: Icons.qr_code_2,
      ),
    ],
  );
}
