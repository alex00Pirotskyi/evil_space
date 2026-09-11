import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:evil_space/brand_surface.dart';
import 'package:evil_space/customer_account.dart';
import 'package:evil_space/localization.dart';
import 'package:evil_space/public_promo_wallet.dart';

class PublicAccountBar extends StatefulWidget {
  const PublicAccountBar({super.key, required this.localization});

  final LocalizationController localization;

  @override
  State<PublicAccountBar> createState() => _PublicAccountBarState();
}

class _PublicAccountBarState extends State<PublicAccountBar> {
  final CustomerAccountApi _api = CustomerAccountApi();
  final TextEditingController _phoneInlineController = TextEditingController();
  CustomerAccountSnapshot? _snapshot;
  Timer? _refreshTimer;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.localization.addListener(_languageChanged);
    unawaited(_load());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_load(silent: true)),
    );
  }

  @override
  void didUpdateWidget(covariant PublicAccountBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localization != widget.localization) {
      oldWidget.localization.removeListener(_languageChanged);
      widget.localization.addListener(_languageChanged);
    }
  }

  @override
  void dispose() {
    widget.localization.removeListener(_languageChanged);
    _refreshTimer?.cancel();
    _phoneInlineController.dispose();
    super.dispose();
  }

  void _languageChanged() {
    if (mounted) setState(() {});
  }

  String _copy(String key) {
    final code = widget.localization.language.code;
    return _accountCopy[code]?[key] ?? _accountCopy['en']![key]!;
  }

  Future<void> _load({bool silent = false}) async {
    if (_busy && !silent) return;
    try {
      final snapshot = await _api.snapshot().timeout(const Duration(seconds: 8));
      if (!mounted) return;
      final phone = snapshot.customer?.phone;
      if (_phoneInlineController.text.trim().isEmpty && phone != null) {
        _phoneInlineController.text = phone;
      }
      setState(() {
        _snapshot = snapshot;
        if (!silent) _error = null;
      });
    } catch (_) {
      if (!mounted || silent) return;
      setState(() => _error = _copy('load_error'));
    }
  }

  Future<void> _phone({String? initialPhone}) async {
    final snapshot = _snapshot;
    if (snapshot == null || _busy) return;
    if (!snapshot.providers.phone) {
      _message(_copy('phone_setup'));
      return;
    }

    final nameController = TextEditingController(
      text: snapshot.customer?.name ?? '',
    );
    final phoneController = TextEditingController(
      text: initialPhone?.trim().isNotEmpty == true
          ? initialPhone!.trim()
          : snapshot.customer?.phone ?? '',
    );
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BrandPalette.paper,
        shape: const RoundedRectangleBorder(),
        title: Text(_copy('phone_title'), style: _serif(25)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: _copy('name')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: _copy('phone_number')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_copy('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_copy('send_code')),
          ),
        ],
      ),
    );
    if (submitted != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await _api
          .startPhone(nameController.text, phoneController.text)
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      _phoneInlineController.text = challenge.phone;
      setState(() => _busy = false);
      final codeController = TextEditingController();
      final verify = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: BrandPalette.paper,
          shape: const RoundedRectangleBorder(),
          title: Text(_copy('code_title'), style: _serif(25)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_copy('code_sent')} ${challenge.phone}',
                style: _serif(15),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(labelText: _copy('code')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_copy('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_copy('verify')),
            ),
          ],
        ),
      );
      if (verify != true || !mounted) return;
      setState(() => _busy = true);
      final account = await _api
          .verifyPhone(challenge.challenge, codeController.text)
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _snapshot = account;
        _busy = false;
      });
    } on CustomerAccountException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _copy('request_error');
      });
    }
  }

  Future<void> _telegram() async {
    final snapshot = _snapshot;
    if (snapshot == null || _busy) return;
    if (!snapshot.providers.telegram) {
      _message(_copy('telegram_setup'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final signup = await _api.startTelegram().timeout(const Duration(seconds: 10));
      final opened = await launchUrl(
        Uri.parse(signup.url),
        mode: LaunchMode.platformDefault,
      );
      if (!opened) {
        throw const CustomerAccountException('Could not open Telegram.');
      }
      for (var attempt = 0; attempt < 90 && mounted; attempt += 1) {
        await Future<void>.delayed(const Duration(seconds: 2));
        final account = await _api.telegramStatus(signup.token);
        if (account != null) {
          if (!mounted) return;
          setState(() {
            _snapshot = account;
            _busy = false;
          });
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _copy('telegram_timeout');
      });
    } on CustomerAccountException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _copy('request_error');
      });
    }
  }

  Future<void> _google() async {
    final snapshot = _snapshot;
    if (snapshot == null || _busy) return;
    final clientId = snapshot.providers.googleClientId;
    if (!snapshot.providers.google || clientId == null) {
      _message(_copy('google_setup'));
      return;
    }
    await _api.beginGoogleSignIn(clientId);
  }

  Future<void> _logout() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _api.logout().timeout(const Duration(seconds: 8));
      _phoneInlineController.clear();
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAdmin() async {
    await launchUrl(Uri.base.resolve('/admin'), webOnlyWindowName: '_self');
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  String _memberStatus(CustomerAccountView customer) {
    final connected = <String>[];
    if (customer.hasProvider('phone')) connected.add(_copy('phone_verified'));
    if (customer.hasProvider('telegram')) connected.add('TELEGRAM ✓');
    if (customer.hasProvider('google')) connected.add('GOOGLE ✓');
    connected.add(_copy('member_offer'));
    return connected.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final customer = snapshot?.customer;
    final ready = snapshot != null && !_busy;
    final secondary = _error ??
        (customer == null ? _copy('register_short') : _memberStatus(customer));

    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: BrandPalette.ink)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _accountLead(customer, secondary)),
                  if (snapshot?.adminAuthenticated == true) ...[
                    const SizedBox(width: 12),
                    _plainAction('ADMIN →', _openAdmin, enabled: !_busy),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              if (customer == null || !customer.hasProvider('phone'))
                _phoneField(ready)
              else
                _verifiedProvider(
                  icon: Icons.phone_outlined,
                  label: _copy('phone_verified'),
                ),
              const SizedBox(height: 10),
              _providerButton(
                icon: Icons.send_outlined,
                label: customer?.hasProvider('telegram') == true
                    ? 'TELEGRAM ✓'
                    : 'TELEGRAM',
                onPressed: _telegram,
                enabled: ready && customer?.hasProvider('telegram') != true,
              ),
              const SizedBox(height: 10),
              _googleButton(
                connected: customer?.hasProvider('google') == true,
                enabled: ready && customer?.hasProvider('google') != true,
              ),
              if (_busy) ...[
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: BrandPalette.ink,
                    ),
                  ),
                ),
              ],
              if (customer != null) ...[
                PublicPromoWallet(localization: widget.localization),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _plainAction(
                    _copy('sign_out'),
                    _logout,
                    enabled: !_busy,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountLead(CustomerAccountView? customer, String secondary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: BrandPalette.ink),
          ),
          child: Icon(
            customer == null ? Icons.person_outline : Icons.person,
            size: 22,
            color: BrandPalette.ink,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer == null
                      ? _copy('member_access')
                      : '${_copy('member')} · ${customer.name.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _mono(10.5),
                ),
                const SizedBox(height: 4),
                Text(
                  secondary,
                  style: _mono(
                    8.7,
                    color: _error == null
                        ? BrandPalette.inkMuted
                        : BrandPalette.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _phoneField(bool ready) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: _phoneInlineController,
        enabled: !_busy,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        onSubmitted: ready
            ? (_) => _phone(initialPhone: _phoneInlineController.text)
            : null,
        style: _mono(10.5),
        decoration: InputDecoration(
          hintText: _copy('phone_hint'),
          hintStyle: _mono(9.5, color: BrandPalette.inkMuted),
          prefixIcon: const Icon(Icons.phone_outlined, size: 19),
          prefixIconConstraints: const BoxConstraints(minWidth: 44),
          suffixIcon: Tooltip(
            message: _copy('send_code'),
            child: InkWell(
              onTap: ready
                  ? () => _phone(initialPhone: _phoneInlineController.text)
                  : null,
              child: const SizedBox(
                width: 48,
                child: Center(child: Icon(Icons.arrow_forward, size: 21)),
              ),
            ),
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 48),
          isDense: true,
          filled: true,
          fillColor: BrandPalette.paperLift,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 13,
          ),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: BrandPalette.ink),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: BrandPalette.ink),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: BrandPalette.ink, width: 1.6),
          ),
          disabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: BrandPalette.inkMuted),
          ),
        ),
      ),
    );
  }

  Widget _providerButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool enabled,
  }) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 19),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(label, style: _mono(10)),
        ),
        style: _outlineButtonStyle(),
      ),
    );
  }

  Widget _googleButton({required bool connected, required bool enabled}) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: enabled ? _google : null,
        style: _outlineButtonStyle(),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              child: Text(
                'G',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: BrandPalette.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(connected ? 'GOOGLE ✓' : 'GOOGLE', style: _mono(10)),
          ],
        ),
      ),
    );
  }

  Widget _verifiedProvider({required IconData icon, required String label}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: BrandPalette.ink),
        color: BrandPalette.paperLift,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 9),
          Text(label, style: _mono(9.5)),
        ],
      ),
    );
  }

  ButtonStyle _outlineButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: BrandPalette.ink,
      backgroundColor: BrandPalette.paperLift,
      side: const BorderSide(color: BrandPalette.ink),
      shape: const RoundedRectangleBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      minimumSize: const Size(double.infinity, 48),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _plainAction(
    String label,
    VoidCallback onPressed, {
    required bool enabled,
  }) {
    return TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: BrandPalette.ink,
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const RoundedRectangleBorder(),
      ),
      child: Text(label, style: _mono(8.8)),
    );
  }
}

const _accountCopy = <String, Map<String, String>>{
  'en': {
    'member_access': 'MEMBER ACCESS',
    'member': 'MEMBER',
    'member_offer': '50% MEMBER OFFER',
    'register_short': 'REGISTER ONCE · GET 50% OFF COWORKING',
    'phone_verified': 'PHONE ✓',
    'phone_number': 'Phone number',
    'phone_hint': 'PHONE · +84…',
    'phone_title': 'Register by phone',
    'phone_setup': 'Phone SMS verification still needs an SMS provider configured.',
    'telegram_setup': 'Telegram registration is not configured yet.',
    'google_setup': 'Google Sign-In is not configured yet.',
    'name': 'Name',
    'cancel': 'Cancel',
    'send_code': 'Send code',
    'code_title': 'Verify phone',
    'code_sent': 'Code sent to',
    'code': '6-digit code',
    'verify': 'Verify',
    'sign_out': 'SIGN OUT',
    'load_error': 'Could not load account status.',
    'request_error': 'Account request failed.',
    'telegram_timeout': 'Telegram registration timed out. Try again.',
  },
  'ru': {
    'member_access': 'ДОСТУП УЧАСТНИКА',
    'member': 'УЧАСТНИК',
    'member_offer': 'СКИДКА УЧАСТНИКА 50%',
    'register_short': 'РЕГИСТРАЦИЯ · СКИДКА 50% НА КОВОРКИНГ',
    'phone_verified': 'ТЕЛЕФОН ✓',
    'phone_number': 'Номер телефона',
    'phone_hint': 'ТЕЛЕФОН · +84…',
    'phone_title': 'Регистрация по телефону',
    'phone_setup': 'Для SMS-подтверждения нужно настроить SMS-провайдера.',
    'telegram_setup': 'Регистрация через Telegram пока не настроена.',
    'google_setup': 'Google Sign-In пока не настроен.',
    'name': 'Имя',
    'cancel': 'Отмена',
    'send_code': 'Отправить код',
    'code_title': 'Подтвердите телефон',
    'code_sent': 'Код отправлен на',
    'code': '6-значный код',
    'verify': 'Подтвердить',
    'sign_out': 'ВЫЙТИ',
    'load_error': 'Не удалось загрузить аккаунт.',
    'request_error': 'Ошибка аккаунта.',
    'telegram_timeout': 'Время регистрации Telegram истекло. Попробуйте снова.',
  },
  'vi': {
    'member_access': 'THÀNH VIÊN',
    'member': 'THÀNH VIÊN',
    'member_offer': 'ƯU ĐÃI THÀNH VIÊN 50%',
    'register_short': 'ĐĂNG KÝ · GIẢM 50% COWORKING',
    'phone_verified': 'ĐIỆN THOẠI ✓',
    'phone_number': 'Số điện thoại',
    'phone_hint': 'ĐIỆN THOẠI · +84…',
    'phone_title': 'Đăng ký bằng điện thoại',
    'phone_setup': 'Cần cấu hình nhà cung cấp SMS để xác minh số điện thoại.',
    'telegram_setup': 'Đăng ký Telegram chưa được cấu hình.',
    'google_setup': 'Google Sign-In chưa được cấu hình.',
    'name': 'Tên',
    'cancel': 'Hủy',
    'send_code': 'Gửi mã',
    'code_title': 'Xác minh điện thoại',
    'code_sent': 'Đã gửi mã đến',
    'code': 'Mã 6 chữ số',
    'verify': 'Xác minh',
    'sign_out': 'ĐĂNG XUẤT',
    'load_error': 'Không thể tải trạng thái tài khoản.',
    'request_error': 'Yêu cầu tài khoản thất bại.',
    'telegram_timeout': 'Đăng ký Telegram hết thời gian. Hãy thử lại.',
  },
};

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