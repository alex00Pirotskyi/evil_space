import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'brand_logo.dart';
import 'brand_surface.dart';
import 'language_icon.dart';
import 'localization.dart';
import 'menu_api.dart';

part 'menu_live_checkout.dart';

const _menuInkOverlay = WidgetStateProperty<Color>.fromMap({
  WidgetState.disabled: Colors.transparent,
  WidgetState.pressed: Color(0x2E1C1C1A),
  WidgetState.hovered: Color(0x1F1C1C1A),
  WidgetState.focused: Color(0x2E1C1C1A),
  WidgetState.any: Colors.transparent,
});

const _menuPaperOverlay = WidgetStateProperty<Color>.fromMap({
  WidgetState.disabled: Colors.transparent,
  WidgetState.pressed: Color(0x38F8F6EF),
  WidgetState.hovered: Color(0x29F8F6EF),
  WidgetState.focused: Color(0x38F8F6EF),
  WidgetState.any: Colors.transparent,
});

Future<T?> _showMenuSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: dismissible,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: Colors.black38,
  transitionDuration: const Duration(milliseconds: 240),
  pageBuilder: (context, animation, secondaryAnimation) => SafeArea(
    child: Align(alignment: Alignment.centerRight,
      child: Material(color: BrandPalette.paper, elevation: 12,
        child: builder(context))),
  ),
  transitionBuilder: (context, animation, secondaryAnimation, child) =>
    SlideTransition(position: Tween<Offset>(begin: const Offset(1, 0),
      end: Offset.zero).animate(CurvedAnimation(parent: animation,
        curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic)),
      child: child),
);

class _MenuSheetBody extends StatefulWidget {
  const _MenuSheetBody({required this.child, this.onDismiss,
    this.dismissible = true});
  final Widget child;
  final VoidCallback? onDismiss;
  final bool dismissible;
  @override
  State<_MenuSheetBody> createState() => _MenuSheetBodyState();
}

class _MenuSheetBodyState extends State<_MenuSheetBody> {
  double _distance = 0;
  bool _expanded = false;
  bool _handlingDismiss = false;

  void _dragEnd(DragEndDetails details) {
    if (_handlingDismiss) return;
    if (_distance > 65 || (details.primaryVelocity ?? 0) > 350) {
      if (widget.dismissible) {
        _handlingDismiss = true;
        final dismiss = widget.onDismiss;
        if (dismiss != null) { dismiss(); } else { Navigator.of(context).pop(); }
        return;
      }
    } else if (_distance < -35 || (details.primaryVelocity ?? 0) < -250) {
      _expanded = true;
    }
    setState(() => _distance = 0);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final width = _expanded ? min(screenWidth, 760.0) : min(screenWidth * 0.88, 560.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) { if (!_handlingDismiss) _distance = 0; },
      onHorizontalDragUpdate: (details) {
        if (_handlingDismiss) return;
        setState(() => _distance += details.primaryDelta ?? 0);
      },
      onHorizontalDragEnd: _dragEnd,
      onHorizontalDragCancel: () { if (!_handlingDismiss) setState(() => _distance = 0); },
      child: Transform.translate(
        offset: Offset(widget.dismissible ? max(0.0, _distance) : 0, 0),
        child: AnimatedContainer(
          key: const ValueKey('menu-curtain'),
          width: width,
          duration: const Duration(milliseconds: 180),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: BrandPalette.rule))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(key: const ValueKey('menu-curtain-handle'), width: 24,
              child: Center(child: Container(width: 4, height: 42,
                decoration: BoxDecoration(color: BrandPalette.inkMuted,
                  borderRadius: BorderRadius.circular(2))))),
            Expanded(child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {
                ...ScrollConfiguration.of(context).dragDevices, PointerDeviceKind.mouse,
              }),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0, 22, 20, 22),
                child: widget.child))),
          ]),
        ),
      ),
    );
  }
}

class _MenuRemoveAction extends StatelessWidget {
  const _MenuRemoveAction({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 64),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ).copyWith(overlayColor: _menuInkOverlay),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Ink(
          height: 44,
          width: double.infinity,
          decoration: BoxDecoration(
            color: onPressed == null ? BrandPalette.paperDeep : BrandPalette.ink,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.delete_outline,
            size: 24,
            color: onPressed == null ? BrandPalette.inkFaint : BrandPalette.paperLift,
          ),
        ),
        const SizedBox(height: 5),
        Text(label, style: _mono(8.5,
          color: onPressed == null ? BrandPalette.inkFaint : BrandPalette.inkMuted)),
      ],
    ),
  );
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({
    super.key,
    required this.localization,
    required this.onBack,
    this.api,
  });

  final LocalizationController localization;
  final VoidCallback onBack;
  final MenuApi? api;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late final MenuApi _api;
  MenuOrderPayment? _pendingOrder;
  String? _paymentToken;
  String? _pendingCartFingerprint;
  double _cartSwipeDistance = 0;
  final List<_CartLine> _cart = [];
  MenuCatalog? _menu;
  String? _error;
  bool _loading = true;
  bool _checkingOut = false;
  bool _editingItem = false;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? MenuApi();
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
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final menu = await _api.menu();
      if (!mounted) return;
      final available = {
        for (final group in menu.groups)
          for (final item in group.items.where((item) => item.enabled)) item.id,
      };
      _cart.removeWhere((line) => !available.contains(line.item.id));
      setState(() {
        _menu = menu;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _copy('load_error');
        });
      }
    }
  }

  Future<void> _addItem(MenuItem item) async {
    if (_checkingOut || _editingItem) return;
    if (!item.hasOptions) {
      final existing = _cart.indexWhere(
        (line) => line.item.id == item.id && line.options.isEmpty,
      );
      setState(() {
        if (existing >= 0) {
          final line = _cart[existing];
          if (line.quantity < 20) {
            _cart[existing] = line.copyWith(quantity: line.quantity + 1);
          }
        } else {
          _cart.add(
            _CartLine(
              item: item,
              quantity: 1,
              unitPriceVnd: item.priceVnd,
              options: const {},
            ),
          );
        }
      });
      return;
    }

    setState(() => _editingItem = true);
    final configured = await _showMenuSheet<_ConfiguredItem>(
      context,
      builder: (_) => _ItemOptionsSheet(
        item: item,
        languageCode: widget.localization.language.code,
        addLabel: _copy('add_to_cart'),
        cancelLabel: _copy('cancel'),
      ),
    );
    if (!mounted) return;
    setState(() => _editingItem = false);
    if (configured == null) return;

    final key = _selectionKey(item.id, configured.options);
    final existing = _cart.indexWhere((line) => line.key == key);
    setState(() {
      if (existing >= 0) {
        final line = _cart[existing];
        if (line.quantity < 20) {
          _cart[existing] = line.copyWith(quantity: line.quantity + 1);
        }
      } else {
        _cart.add(
          _CartLine(
            item: item,
            quantity: 1,
            unitPriceVnd: configured.unitPriceVnd,
            options: configured.options,
          ),
        );
      }
    });
  }

  List<_CartLine> get _cartLines => List.unmodifiable(_cart);

  int get _cartTotal => _cart.fold(0, (sum, line) => sum + line.total);
  String get _cartFingerprint => jsonEncode([
    for (final line in _cart) [line.key, line.quantity, line.unitPriceVnd],
  ]);
  int get _payTotal => _pendingOrder != null &&
          _pendingCartFingerprint == _cartFingerprint
      ? _pendingOrder!.amountVnd
      : _cartTotal;

  Future<void> _checkout({String? removeKey}) async {
    if (_checkingOut || _cart.isEmpty) return;
    _paymentToken ??= _newPaymentToken();
    setState(() {
      _checkingOut = true;
      _error = null;
    });
    try {
      final result = await _showMenuSheet<_LiveCheckoutResult>(
        context,
        dismissible: false,
        builder: (_) => _LiveCheckoutSheet(
          api: _api,
          lines: _cartLines,
          languageCode: widget.localization.language.code,
          initialOrder: _pendingOrder,
          initialRemoveKey: removeKey,
          paymentToken: _paymentToken!,
        ),
      );
      if (!mounted || result == null) return;
      setState(() {
        _cart
          ..clear()
          ..addAll(result.paid ? const [] : result.lines);
        _pendingOrder = result.paid ? null : result.order;
        _pendingCartFingerprint = result.synced && !result.paid
            ? _cartFingerprint
            : null;
        _paymentToken = result.paid || result.lines.isEmpty
            ? null
            : result.paymentToken;
      });
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = _menu;
    return Scaffold(
      backgroundColor: BrandPalette.paper,
      body: BrandPaper(
        child: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: Column(
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
                      Text(
                        _copy('subtitle'),
                        style: _serif(
                          16,
                          color: BrandPalette.inkMuted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 22),
                      if (_error != null) _errorBox(_error!),
                      if (_loading && menu == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: BrandPalette.ink,
                            ),
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
          )),
          if (_cart.isNotEmpty) _cartBar(),
          ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Container(
    height: 68,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: BrandPalette.ink)),
    ),
    child: Row(
      children: [
        const Expanded(child: Align(alignment: Alignment.centerLeft,
          child: EvilCoworkingLogo(width: 108))),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LanguageIcon(),
            const SizedBox(width: 6),
            ...AppLanguage.values
              .map((language) {
                final selected = widget.localization.language == language;
                return TextButton(
                  onPressed: () => widget.localization.setLanguage(language),
                  style: TextButton.styleFrom(
                    foregroundColor: BrandPalette.ink,
                    minimumSize: const Size(44, 44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    shape: const RoundedRectangleBorder(),
                    side: selected
                        ? const BorderSide(color: BrandPalette.ink)
                        : BorderSide.none,
                  ).copyWith(overlayColor: _menuInkOverlay),
                  child: Text(language.code.toUpperCase(), style: _mono(9)),
                );
              })
              .toList(growable: false),
          ],
        ),
        const SizedBox(width: 8),
        if (MediaQuery.sizeOf(context).width < 480)
          IconButton(
            tooltip: _copy('back'),
            onPressed: widget.onBack,
            style: const ButtonStyle(overlayColor: _menuInkOverlay),
            icon: const Icon(Icons.arrow_back, size: 18),
          )
        else
          TextButton.icon(
            onPressed: widget.onBack,
            style: const ButtonStyle(overlayColor: _menuInkOverlay),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: Text(_copy('back'), style: _mono(10)),
          ),
      ],
    ),
  );

  Widget _group(MenuGroup group) {
    final items = group.items
        .where((item) => item.enabled)
        .toList(growable: false);
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: BrandPalette.ink)),
          ),
          child: Text(
            group.name.resolve(widget.localization.language.code).toUpperCase(),
            style: _mono(12),
          ),
        ),
        for (final item in items) _item(item),
      ],
    );
  }

  Future<void> _removeItem(MenuItem item) async {
    if (_checkingOut || _editingItem) return;
    final variants = _cart.where((line) => line.item.id == item.id).toList();
    if (variants.isEmpty) return;
    String? key = variants.length == 1 ? variants.first.key : null;
    if (variants.length > 1) {
      setState(() => _editingItem = true);
      var closing = false;
      void finish(BuildContext sheetContext, [String? selection]) {
        if (closing) return;
        closing = true;
        Navigator.of(sheetContext).pop(selection);
      }
      key = await _showMenuSheet<String>(context, builder: (context) => _MenuSheetBody(
        onDismiss: () => finish(context),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_copy('choose_remove'), style: _serif(28)),
          const SizedBox(height: 16),
          for (final line in variants) TextButton(
            key: ValueKey('menu-remove-variant-${line.key}'),
            style: TextButton.styleFrom(foregroundColor: BrandPalette.ink,
              padding: const EdgeInsets.symmetric(vertical: 18)).copyWith(overlayColor: _menuInkOverlay),
            onPressed: () => finish(context, line.key),
            child: Text('${line.label(widget.localization.language.code)} × ${line.quantity}',
              style: _serif(19))),
          TextButton(onPressed: () => finish(context),
            child: Text(_copy('cancel'), style: _mono(11))),
        ])));
      if (!mounted) return;
      setState(() => _editingItem = false);
    }
    if (key == null || !mounted) return;
    if (_pendingOrder != null || _paymentToken != null) {
      await _checkout(removeKey: key);
      return;
    }
    final index = _cart.indexWhere((line) => line.key == key);
    if (index < 0) return;
    setState(() {
      final line = _cart[index];
      if (line.quantity == 1) { _cart.removeAt(index); }
      else { _cart[index] = line.copyWith(quantity: line.quantity - 1); }
    });
  }

  Widget _item(MenuItem item) {
    final language = widget.localization.language.code;
    final quantity = _cart.where((line) => line.item.id == item.id)
      .fold(0, (sum, line) => sum + line.quantity);
    final enabled = !_checkingOut && !_editingItem;
    final add = Semantics(button: true, selected: quantity > 0, enabled: enabled,
      hint: item.hasOptions ? _copy('customize') : _copy('add'),
      child: InkWell(key: ValueKey('menu-item-${item.id}'),
        onTap: enabled ? () => _addItem(item) : null,
        overlayColor: _menuInkOverlay,
        mouseCursor: WidgetStateMouseCursor.clickable,
        hoverDuration: const Duration(milliseconds: 150),
        child: Container(constraints: const BoxConstraints(minHeight: 72),
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(quantity > 0 ? 12 : 0, 18, 8, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${item.nameFor(language)}${quantity > 0 ? ' × $quantity' : ''}', style: _serif(25)),
            if (item.descriptionFor(language) case final description?) ...[
              const SizedBox(height: 5),
              Text(description, style: _serif(15, color: BrandPalette.inkMuted, height: 1.3)),
            ],
            const SizedBox(height: 8),
            Text(item.hasVariablePrice
              ? '${_copy('from').toUpperCase()} ${_money(item.priceVnd)}'
              : _money(item.priceVnd), style: _mono(12)),
          ]))));
    final surface = Material(
      key: ValueKey('menu-item-surface-${item.id}'),
      color: quantity > 0 ? const Color(0x0F1C1C1A) : Colors.transparent,
      animationDuration: const Duration(milliseconds: 150),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: add,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (quantity > 0) ...[
              Expanded(flex: 2, child: Center(child: _MenuRemoveAction(
                key: ValueKey('menu-remove-${item.id}'),
                label: _copy('remove'),
                onPressed: enabled ? () => _removeItem(item) : null,
              ))),
              const SizedBox(width: 8),
            ],
            Expanded(flex: 8, child: surface),
          ],
        ),
      ),
    );
  }

  Widget _cartBar() => SizedBox(width: 56, child: Material(
    color: BrandPalette.paperLift,
    child: GestureDetector(key: const ValueKey('menu-pay-bar'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _cartSwipeDistance = 0,
      onHorizontalDragUpdate: (details) => _cartSwipeDistance += details.primaryDelta ?? 0,
      onHorizontalDragEnd: (details) {
        if (_cartSwipeDistance < -35 || (details.primaryVelocity ?? 0) < -250) {
          unawaited(_checkout());
        }
      },
      child: Container(decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: BrandPalette.ink))),
        child: TextButton(key: const ValueKey('menu-pay'),
          onPressed: _checkingOut || _editingItem ? null : () => _checkout(),
          style: TextButton.styleFrom(foregroundColor: BrandPalette.ink,
            padding: EdgeInsets.zero, shape: const RoundedRectangleBorder())
            .copyWith(overlayColor: _menuInkOverlay),
          child: RotatedBox(quarterTurns: 3,
            child: Text('${_copy('pay')}: ${_money(_payTotal)}', style: _mono(12))))))));

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

class _ConfiguredItem {
  const _ConfiguredItem({required this.options, required this.unitPriceVnd});

  final Map<String, dynamic> options;
  final int unitPriceVnd;
}

class _ItemOptionsSheet extends StatefulWidget {
  const _ItemOptionsSheet({
    required this.item,
    required this.languageCode,
    required this.addLabel,
    required this.cancelLabel,
  });

  final MenuItem item;
  final String languageCode;
  final String addLabel;
  final String cancelLabel;

  @override
  State<_ItemOptionsSheet> createState() => _ItemOptionsSheetState();
}

class _ItemOptionsSheetState extends State<_ItemOptionsSheet> {
  late final Map<String, dynamic> _selected;
  bool _closing = false;

  void _finish([_ConfiguredItem? configured]) {
    if (_closing) return;
    setState(() => _closing = true);
    Navigator.of(context).pop(configured);
  }

  @override
  void initState() {
    super.initState();
    _selected = <String, dynamic>{};
    for (final option in widget.item.options) {
      if (option.isDots) {
        _selected[option.id] = option.defaultDots;
      } else if (option.isSingle && option.defaultChoice != null) {
        _selected[option.id] = option.defaultChoice;
      } else if (option.isMultiple) {
        _selected[option.id] = <String>[];
      }
    }
  }

  bool get _valid {
    for (final option in widget.item.options) {
      if (option.isSingle && option.required) {
        final value = _selected[option.id]?.toString() ?? '';
        if (value.isEmpty) return false;
      }
    }
    return true;
  }

  int get _unitPrice {
    var total = widget.item.priceVnd;
    for (final option in widget.item.options) {
      if (option.isDots) {
        final value = _selected[option.id] is int
            ? _selected[option.id] as int
            : option.defaultDots;
        total += (value - option.min) * option.pricePerStepVnd;
        continue;
      }
      if (option.isSingle) {
        final selected = _selected[option.id]?.toString();
        if (selected == null) continue;
        for (final value in option.values) {
          if (value.id == selected) {
            total += value.priceDeltaVnd;
            break;
          }
        }
        continue;
      }
      final selected = _selected[option.id];
      if (selected is List) {
        for (final raw in selected) {
          for (final value in option.values) {
            if (value.id == raw.toString()) {
              total += value.priceDeltaVnd;
              break;
            }
          }
        }
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return _MenuSheetBody(
      onDismiss: () => _finish(),
      dismissible: !_closing,
      child: AbsorbPointer(absorbing: _closing, child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.item.nameFor(widget.languageCode).toUpperCase(),
            style: _mono(12),
          ),
          const SizedBox(height: 6),
          Text(_money(_unitPrice), style: _serif(25)),
          const SizedBox(height: 18),
          for (final option in widget.item.options) ...[
            _option(option),
            const SizedBox(height: 18),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _finish(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BrandPalette.ink,
                    side: const BorderSide(color: BrandPalette.ink),
                    minimumSize: const Size.fromHeight(48),
                    shape: const RoundedRectangleBorder(),
                  ).copyWith(overlayColor: _menuInkOverlay),
                  child: Text(
                    widget.cancelLabel.toUpperCase(),
                    style: _mono(9),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: !_valid || _closing
                      ? null
                      : () => _finish(
                          _ConfiguredItem(
                            options: _normalizedSelection(),
                            unitPriceVnd: _unitPrice,
                          ),
                        ),
                  style: FilledButton.styleFrom(
                    backgroundColor: BrandPalette.ink,
                    foregroundColor: BrandPalette.paperLift,
                    minimumSize: const Size.fromHeight(48),
                    shape: const RoundedRectangleBorder(),
                  ).copyWith(overlayColor: _menuPaperOverlay),
                  child: Text(
                    widget.addLabel.toUpperCase(),
                    style: _mono(9, color: BrandPalette.paperLift),
                  ),
                ),
              ),
            ],
          ),
        ],
      )),
    );
  }

  Map<String, dynamic> _normalizedSelection() {
    final result = <String, dynamic>{};
    for (final option in widget.item.options) {
      final value = _selected[option.id];
      if (option.isMultiple) {
        final selected = value is List
            ? value.map((entry) => entry.toString()).toList(growable: false)
            : const <String>[];
        result[option.id] = selected;
      } else if (value != null) {
        result[option.id] = value;
      }
    }
    return result;
  }

  Widget _option(MenuOptionGroup option) {
    final title = option.name.resolve(widget.languageCode).toUpperCase();
    if (option.isDots) {
      final selected =
          (_selected[option.id] is int
                  ? _selected[option.id] as int
                  : option.defaultDots)
              .clamp(option.min, option.max);
      final steps = option.max - option.min;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: _mono(10))),
              Text('$selected', style: _mono(11)),
              if (option.pricePerStepVnd > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '· +${_money(option.pricePerStepVnd)} / +1',
                  style: _mono(8.5, color: BrandPalette.inkMuted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              activeTrackColor: BrandPalette.ink,
              inactiveTrackColor: BrandPalette.rule,
              thumbColor: BrandPalette.ink,
              overlayColor: BrandPalette.ink.withOpacity(0.08),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
              tickMarkShape: const RoundSliderTickMarkShape(
                tickMarkRadius: 2.5,
              ),
              activeTickMarkColor: BrandPalette.paper,
              inactiveTickMarkColor: BrandPalette.ink,
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              value: selected.toDouble(),
              min: option.min.toDouble(),
              max: option.max.toDouble(),
              divisions: steps > 0 ? steps : null,
              onChanged: steps <= 0
                  ? null
                  : (next) =>
                        setState(() => _selected[option.id] = next.round()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                for (var value = option.min; value <= option.max; value++)
                  Expanded(
                    child: Text(
                      '$value',
                      textAlign: value == option.min
                          ? TextAlign.left
                          : value == option.max
                          ? TextAlign.right
                          : TextAlign.center,
                      style: _mono(9, color: BrandPalette.inkMuted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    if (option.isSingle) {
      final selected = _selected[option.id]?.toString();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _mono(10)),
          const SizedBox(height: 5),
          for (final value in option.values)
            RadioListTile<String>(
              value: value.id,
              groupValue: selected,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      value.name.resolve(widget.languageCode),
                      style: _serif(17),
                    ),
                  ),
                  if (value.priceDeltaVnd > 0)
                    Text('+${_money(value.priceDeltaVnd)}', style: _mono(9)),
                ],
              ),
              onChanged: (next) => setState(() => _selected[option.id] = next),
            ),
        ],
      );
    }

    final selected =
        (_selected[option.id] as List?)?.cast<String>() ?? <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _mono(10)),
        const SizedBox(height: 5),
        for (final value in option.values)
          CheckboxListTile(
            value: selected.contains(value.id),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    value.name.resolve(widget.languageCode),
                    style: _serif(17),
                  ),
                ),
                if (value.priceDeltaVnd > 0)
                  Text('+${_money(value.priceDeltaVnd)}', style: _mono(9)),
              ],
            ),
            onChanged: (checked) {
              final next = [...selected];
              if (checked == true) {
                if (!next.contains(value.id)) next.add(value.id);
              } else {
                next.remove(value.id);
              }
              setState(() => _selected[option.id] = next);
            },
          ),
      ],
    );
  }
}

class _CartLine {
  const _CartLine({
    required this.item,
    required this.quantity,
    required this.unitPriceVnd,
    required this.options,
  });

  final MenuItem item;
  final int quantity;
  final int unitPriceVnd;
  final Map<String, dynamic> options;

  String get key => _selectionKey(item.id, options);
  int get total => unitPriceVnd * quantity;
  MenuCartRequestLine get request => MenuCartRequestLine(
    itemId: item.id,
    quantity: quantity,
    options: options,
  );

  _CartLine copyWith({int? quantity, int? unitPriceVnd}) => _CartLine(
    item: item,
    quantity: quantity ?? this.quantity,
    unitPriceVnd: unitPriceVnd ?? this.unitPriceVnd,
    options: options,
  );

  String label(String languageCode) {
    final parts = <String>[];
    for (final option in item.options) {
      final selected = options[option.id];
      if (option.isDots) {
        final value = selected is int ? selected : option.defaultDots;
        parts.add('${option.name.resolve(languageCode)} $value/${option.max}');
      } else if (option.isSingle) {
        final id = selected?.toString();
        if (id == null) continue;
        final value = option.values
            .where((entry) => entry.id == id)
            .firstOrNull;
        if (value != null) parts.add(value.name.resolve(languageCode));
      } else if (option.isMultiple && selected is List) {
        for (final raw in selected) {
          final value = option.values
              .where((entry) => entry.id == raw.toString())
              .firstOrNull;
          if (value != null) parts.add(value.name.resolve(languageCode));
        }
      }
    }
    final base = item.nameFor(languageCode);
    return parts.isEmpty ? base : '$base · ${parts.join(' · ')}';
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

String _selectionKey(String itemId, Map<String, dynamic> options) {
  dynamic canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: canonical(value[key])};
    }
    if (value is List) {
      return value.map(canonical).toList(growable: false);
    }
    return value;
  }

  return '$itemId:${jsonEncode(canonical(options))}';
}

const _menuCopy = <String, Map<String, String>>{
  'en': {
    'pay': 'PAY',
    'your_cart': 'Your cart',
    'remove': 'Remove',
    'choose_remove': 'Remove one drink',
    'pay_now': 'Pay',
    'loading_promos': 'Loading promos…',
    'preparing_payment': 'Preparing your QR…',
    'updating_payment': 'Updating your QR…',
    'retry': 'Retry',
    'refresh_payment': 'New payment QR',
    'promo_unavailable':
        'This promo is no longer eligible. Choose another promo or continue without one.',
    'uses_left': 'uses left',
    'payment_changed':
        'The payment changed. Refresh the cart to see the current amount.',
    'title': 'MENU',
    'subtitle':
        'Add anything you want, choose quantities, then pay for the whole cart with one QR or cash.',
    'back': 'BACK',
    'add': 'ADD',
    'cart': 'CART',
    'checkout': 'CHECKOUT',
    'customize': 'SETTINGS',
    'add_to_cart': 'ADD TO CART',
    'from': 'from',
    'total': 'Total',
    'cancel': 'Cancel',
    'your_promos': 'Your promos',
    'use_promo': 'Use promo',
    'without_promo': 'Pay without promo',
    'empty': 'The menu is being prepared.',
    'load_error': 'Could not load the menu.',
    'payment_error': 'Could not create the payment.',
    'payment_title': 'PAY HERE',
    'payment_confirmed': '✓ PAYMENT CONFIRMED',
    'payment_expired': 'PAYMENT EXPIRED',
    'subtotal': 'Subtotal',
    'promo': 'Promo',
    'transfer_reference': 'Transfer reference',
    'waiting_bank': 'Waiting for staff to confirm the bank payment…',
    'pay_cash': 'Pay cash',
    'cash_title': 'Pay cash at counter',
    'cash_instruction':
        'Please pay the total in cash at the counter. Staff will confirm your order here.',
    'waiting_cash': 'Waiting for staff to confirm the cash payment…',
    'pay_qr': 'Pay by QR instead',
    'payment_thanks': 'Thank you. Your whole order is confirmed.',
    'payment_thanks_promo':
        'Thank you. Your whole order is confirmed and your promo was used.',
    'payment_inactive':
        'This payment request is no longer active. Any reserved promo has been returned to your account.',
    'close': 'Close',
    'cancel_view': 'Close',
  },
  'ru': {
    'pay': 'ОПЛАТИТЬ',
    'your_cart': 'Ваша корзина',
    'remove': 'Удалить',
    'choose_remove': 'Убрать один напиток',
    'pay_now': 'Оплатить',
    'loading_promos': 'Загружаем промо…',
    'preparing_payment': 'Создаём QR…',
    'updating_payment': 'Обновляем QR…',
    'retry': 'Повторить',
    'refresh_payment': 'Новый QR для оплаты',
    'promo_unavailable':
        'Это промо больше не подходит. Выберите другое или продолжите без промо.',
    'uses_left': 'осталось использований',
    'payment_changed':
        'Платёж изменился. Обновите корзину, чтобы увидеть актуальную сумму.',
    'title': 'МЕНЮ',
    'subtitle':
        'Добавьте нужные товары, выберите количество и оплатите всю корзину одним QR или наличными.',
    'back': 'НАЗАД',
    'add': 'ДОБАВИТЬ',
    'cart': 'КОРЗИНА',
    'checkout': 'ОФОРМИТЬ',
    'customize': 'НАСТРОИТЬ',
    'add_to_cart': 'В КОРЗИНУ',
    'from': 'от',
    'total': 'Итого',
    'cancel': 'Отмена',
    'your_promos': 'Ваши промо',
    'use_promo': 'Использовать',
    'without_promo': 'Без промо',
    'empty': 'Меню готовится.',
    'load_error': 'Не удалось загрузить меню.',
    'payment_error': 'Не удалось создать платёж.',
    'payment_title': 'ОПЛАТА',
    'payment_confirmed': '✓ ОПЛАТА ПОДТВЕРЖДЕНА',
    'payment_expired': 'ВРЕМЯ ОПЛАТЫ ИСТЕКЛО',
    'subtotal': 'Сумма',
    'promo': 'Промо',
    'transfer_reference': 'Назначение перевода',
    'waiting_bank': 'Ожидаем подтверждение банковского перевода сотрудником…',
    'pay_cash': 'Оплатить наличными',
    'cash_title': 'Оплата наличными',
    'cash_instruction':
        'Оплатите итоговую сумму наличными на стойке. Сотрудник подтвердит заказ здесь.',
    'waiting_cash': 'Ожидаем подтверждение оплаты наличными сотрудником…',
    'pay_qr': 'Оплатить по QR',
    'payment_thanks': 'Спасибо. Ваш заказ подтверждён.',
    'payment_thanks_promo':
        'Спасибо. Ваш заказ подтверждён, промо использовано.',
    'payment_inactive':
        'Этот платёж больше не активен. Зарезервированное промо возвращено в ваш аккаунт.',
    'close': 'Закрыть',
    'cancel_view': 'Закрыть',
  },
  'vi': {
    'pay': 'THANH TOÁN',
    'your_cart': 'Giỏ hàng của bạn',
    'remove': 'Xóa',
    'choose_remove': 'Bớt một đồ uống',
    'pay_now': 'Thanh toán',
    'loading_promos': 'Đang tải khuyến mãi…',
    'preparing_payment': 'Đang tạo mã QR…',
    'updating_payment': 'Đang cập nhật mã QR…',
    'retry': 'Thử lại',
    'refresh_payment': 'Mã QR thanh toán mới',
    'promo_unavailable':
        'Khuyến mãi này không còn áp dụng. Chọn khuyến mãi khác hoặc tiếp tục không dùng khuyến mãi.',
    'uses_left': 'lượt còn lại',
    'payment_changed':
        'Thanh toán đã thay đổi. Làm mới giỏ hàng để xem số tiền hiện tại.',
    'title': 'THỰC ĐƠN',
    'subtitle':
        'Thêm món, chọn số lượng rồi thanh toán toàn bộ giỏ hàng bằng một mã QR hoặc tiền mặt.',
    'back': 'QUAY LẠI',
    'add': 'THÊM',
    'cart': 'GIỎ HÀNG',
    'checkout': 'THANH TOÁN',
    'customize': 'TÙY CHỈNH',
    'add_to_cart': 'THÊM VÀO GIỎ',
    'from': 'từ',
    'total': 'Tổng',
    'cancel': 'Hủy',
    'your_promos': 'Khuyến mãi của bạn',
    'use_promo': 'Dùng khuyến mãi',
    'without_promo': 'Không dùng khuyến mãi',
    'empty': 'Thực đơn đang được chuẩn bị.',
    'load_error': 'Không thể tải thực đơn.',
    'payment_error': 'Không thể tạo thanh toán.',
    'payment_title': 'THANH TOÁN',
    'payment_confirmed': '✓ ĐÃ XÁC NHẬN THANH TOÁN',
    'payment_expired': 'YÊU CẦU THANH TOÁN ĐÃ HẾT HẠN',
    'subtotal': 'Tạm tính',
    'promo': 'Khuyến mãi',
    'transfer_reference': 'Nội dung chuyển khoản',
    'waiting_bank': 'Đang chờ nhân viên xác nhận chuyển khoản…',
    'pay_cash': 'Thanh toán tiền mặt',
    'cash_title': 'Trả tiền mặt tại quầy',
    'cash_instruction':
        'Vui lòng thanh toán tổng số tiền bằng tiền mặt tại quầy. Nhân viên sẽ xác nhận đơn hàng tại đây.',
    'waiting_cash': 'Đang chờ nhân viên xác nhận thanh toán tiền mặt…',
    'pay_qr': 'Thanh toán bằng QR',
    'payment_thanks': 'Cảm ơn bạn. Đơn hàng đã được xác nhận.',
    'payment_thanks_promo':
        'Cảm ơn bạn. Đơn hàng đã được xác nhận và khuyến mãi đã được sử dụng.',
    'payment_inactive':
        'Yêu cầu thanh toán này không còn hiệu lực. Khuyến mãi đã giữ chỗ được trả lại vào tài khoản của bạn.',
    'close': 'Đóng',
    'cancel_view': 'Đóng',
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

TextStyle _serif(
  double size, {
  Color color = BrandPalette.ink,
  double? height,
}) => TextStyle(
  fontFamily: 'Georgia',
  fontSize: size,
  color: color,
  height: height,
);

TextStyle _mono(
  double size, {
  Color color = BrandPalette.ink,
  double? height,
}) => TextStyle(
  fontFamily: 'Courier New',
  fontFamilyFallback: const ['monospace'],
  fontSize: size,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.7,
  color: color,
  height: height,
);
