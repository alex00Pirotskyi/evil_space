import 'dart:async';

import 'package:flutter/material.dart';

import 'brand_surface.dart';
import 'localization.dart';
import 'menu_api.dart';

class PublicPromoWallet extends StatefulWidget {
  const PublicPromoWallet({super.key, required this.localization});

  final LocalizationController localization;

  @override
  State<PublicPromoWallet> createState() => _PublicPromoWalletState();
}

class _PublicPromoWalletState extends State<PublicPromoWallet> {
  final MenuApi _api = MenuApi();
  List<CustomerPromo> _promos = const [];
  Timer? _timer;
  bool _authenticated = false;
  bool _loading = true;
  bool _expanded = false;
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    widget.localization.addListener(_languageChanged);
    unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => unawaited(_load(silent: true)));
  }

  @override
  void didUpdateWidget(covariant PublicPromoWallet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localization != widget.localization) {
      oldWidget.localization.removeListener(_languageChanged);
      widget.localization.addListener(_languageChanged);
    }
  }

  @override
  void dispose() {
    widget.localization.removeListener(_languageChanged);
    _timer?.cancel();
    super.dispose();
  }

  void _languageChanged() {
    if (mounted) setState(() {});
  }

  String _copy(String key) {
    final language = widget.localization.language.code;
    return _promoCopy[language]?[key] ?? _promoCopy['en']![key]!;
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final promos = await _api.customerPromos().timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _authenticated = true;
        _promos = promos;
        _loading = false;
      });
    } on MenuApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 401) {
        setState(() {
          _authenticated = false;
          _promos = const [];
          _loading = false;
          _expanded = false;
        });
      } else if (!silent) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (!mounted || silent) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _claimCode() async {
    if (_claiming) return;
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: BrandPalette.paper,
        shape: const RoundedRectangleBorder(),
        title: Text(_copy('claim_title'), style: _serif(24)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: _copy('promo_code')),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(_copy('cancel'), style: _mono(9)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            style: _darkButton(),
            child: Text(_copy('claim'), style: _mono(9, color: BrandPalette.paperLift)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.trim().isEmpty || !mounted) return;

    setState(() => _claiming = true);
    try {
      final promos = await _api.claimPromo(code.trim()).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _promos = promos;
        _expanded = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_copy('claimed'))));
    } on MenuApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_copy('claim_error'))));
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_authenticated) return const SizedBox.shrink();

    final active = _promos.where((promo) => promo.active).toList(growable: false);
    return Container(
      padding: const EdgeInsets.only(top: 14, bottom: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BrandPalette.ink)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.local_offer_outlined, size: 20),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '${_copy('my_promos')} · ${active.length}',
                      style: _mono(10.2),
                    ),
                  ),
                  Text(
                    active.isEmpty ? _copy('none') : _copy('available'),
                    style: _mono(8.3, color: BrandPalette.inkMuted),
                  ),
                  const SizedBox(width: 6),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 10),
            if (_promos.isEmpty)
              Text(_copy('empty'), style: _serif(15, color: BrandPalette.inkMuted))
            else
              for (final promo in _promos) _promoRow(promo),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _claiming ? null : _claimCode,
                icon: _claiming
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.6, color: BrandPalette.ink),
                      )
                    : const Icon(Icons.add, size: 16),
                label: Text(_copy('claim_code'), style: _mono(8.8)),
                style: TextButton.styleFrom(
                  foregroundColor: BrandPalette.ink,
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                  shape: const RoundedRectangleBorder(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _promoRow(CustomerPromo promo) {
    final groups = promo.groupIds.isEmpty
        ? _copy('all_groups')
        : promo.groupIds.map((id) => id.toUpperCase()).join(' + ');
    final uses = promo.remainingUses == 1
        ? '1 ${_copy('use')}'
        : '${promo.remainingUses} ${_copy('uses')}';
    final status = promo.active ? '$uses ${_copy('available').toUpperCase()}' : promo.status.toUpperCase();
    final expiry = promo.expiresAt == null ? _copy('no_expiry') : '${_copy('expires')} ${_date(promo.expiresAt!)}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: BrandPalette.rule))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(promo.name, style: _serif(17)),
                const SizedBox(height: 3),
                Text('${promo.discountLabel} · $groups', style: _mono(8.6)),
                const SizedBox(height: 3),
                Text('$status · $expiry', style: _mono(7.9, color: BrandPalette.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _date(int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year}';
}

ButtonStyle _darkButton() => FilledButton.styleFrom(
      foregroundColor: BrandPalette.paperLift,
      backgroundColor: BrandPalette.ink,
      shape: const RoundedRectangleBorder(),
    );

TextStyle _mono(double size, {Color color = BrandPalette.ink}) => TextStyle(
      fontFamily: 'Courier New',
      fontFamilyFallback: const ['monospace'],
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: color,
    );

TextStyle _serif(double size, {Color color = BrandPalette.ink}) => TextStyle(
      fontFamily: 'Georgia',
      fontSize: size,
      color: color,
    );

const _promoCopy = <String, Map<String, String>>{
  'en': {
    'my_promos': 'MY PROMOS',
    'available': 'available',
    'none': 'none',
    'empty': 'No promos in your account yet.',
    'use': 'use',
    'uses': 'uses',
    'all_groups': 'ALL MENU',
    'no_expiry': 'NO EXPIRY',
    'expires': 'EXPIRES',
    'claim_code': 'CLAIM PROMO CODE',
    'claim_title': 'Claim promo code',
    'promo_code': 'Promo code',
    'claim': 'CLAIM',
    'cancel': 'CANCEL',
    'claimed': 'Promo added to your account.',
    'claim_error': 'Could not claim this promo.',
  },
  'ru': {
    'my_promos': 'МОИ ПРОМО',
    'available': 'доступно',
    'none': 'нет',
    'empty': 'На аккаунте пока нет промо.',
    'use': 'использование',
    'uses': 'использований',
    'all_groups': 'ВСЁ МЕНЮ',
    'no_expiry': 'БЕЗ СРОКА',
    'expires': 'ДО',
    'claim_code': 'ДОБАВИТЬ ПРОМОКОД',
    'claim_title': 'Добавить промокод',
    'promo_code': 'Промокод',
    'claim': 'ДОБАВИТЬ',
    'cancel': 'ОТМЕНА',
    'claimed': 'Промо добавлено в аккаунт.',
    'claim_error': 'Не удалось добавить промо.',
  },
  'vi': {
    'my_promos': 'KHUYẾN MÃI CỦA TÔI',
    'available': 'khả dụng',
    'none': 'không có',
    'empty': 'Tài khoản chưa có khuyến mãi.',
    'use': 'lượt',
    'uses': 'lượt',
    'all_groups': 'TOÀN BỘ MENU',
    'no_expiry': 'KHÔNG HẾT HẠN',
    'expires': 'HẾT HẠN',
    'claim_code': 'NHẬP MÃ KHUYẾN MÃI',
    'claim_title': 'Nhập mã khuyến mãi',
    'promo_code': 'Mã khuyến mãi',
    'claim': 'NHẬN',
    'cancel': 'HỦY',
    'claimed': 'Đã thêm khuyến mãi vào tài khoản.',
    'claim_error': 'Không thể nhận khuyến mãi này.',
  },
};
