import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:evil_space/brand_surface.dart';
import 'package:evil_space/customer_account.dart';
import 'package:evil_space/localization.dart';

class PublicAccountBar extends StatefulWidget {
  const PublicAccountBar({super.key, required this.localization});

  final LocalizationController localization;

  @override
  State<PublicAccountBar> createState() => _PublicAccountBarState();
}

class _PublicAccountBarState extends State<PublicAccountBar> {
  final CustomerAccountApi _api = CustomerAccountApi();
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
      setState(() {
        _snapshot = snapshot;
        if (!silent) _error = null;
      });
    } catch (_) {
      if (!mounted || silent) return;
      setState(() => _error = _copy('load_error'));
    }
  }

  Future<void> _phone() async {
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
      text: snapshot.customer?.phone ?? '',
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
              decoration: InputDecoration(labelText: _copy('phone')),
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
              Text('${_copy('code_sent')} ${challenge.phone}', style: _serif(15)),
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
      if (!opened) throw const CustomerAccountException('Could not open Telegram.');
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
    if (customer.hasProvider('phone')) connected.add(_copy('phone_short'));
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final gutter = compact ? 20.0 : 40.0;
        return Material(
          type: MaterialType.transparency,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: SizedBox(
                  height: 44,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: BrandPalette.ink),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                customer == null
                                    ? _copy('member_access')
                                    : '✓ ${_copy('member')} · ${customer.name.toUpperCase()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _mono(9.2, color: BrandPalette.inkMuted),
                              ),
                            ),
                            if (snapshot?.adminAuthenticated == true)
                              _smallAction(
                                'ADMIN →',
                                _openAdmin,
                                enabled: !_busy,
                              ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                secondary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _mono(
                                  compact ? 8.2 : 8.7,
                                  color: _error == null
                                      ? BrandPalette.ink
                                      : BrandPalette.inkMuted,
                                ),
                              ),
                            ),
                            if (_busy) ...[
                              const SizedBox(width: 5),
                              const SizedBox.square(
                                dimension: 11,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: BrandPalette.ink,
                                ),
                              ),
                            ],
                            if (customer == null) ...[
                              _smallAction(
                                _copy('phone_short'),
                                _phone,
                                enabled: ready,
                              ),
                              _smallAction('TELEGRAM', _telegram, enabled: ready),
                              _smallAction('GOOGLE', _google, enabled: ready),
                            ] else ...[
                              if (!customer.hasProvider('phone'))
                                _smallAction(
                                  _copy('phone_short'),
                                  _phone,
                                  enabled: ready,
                                ),
                              if (!customer.hasProvider('telegram'))
                                _smallAction('TELEGRAM', _telegram, enabled: ready),
                              if (!customer.hasProvider('google'))
                                _smallAction('GOOGLE', _google, enabled: ready),
                              _smallAction(
                                _copy('sign_out'),
                                _logout,
                                enabled: !_busy,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _smallAction(
    String label,
    VoidCallback onPressed, {
    required bool enabled,
  }) {
    return TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: BrandPalette.ink,
        minimumSize: const Size(0, 22),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: const RoundedRectangleBorder(),
      ),
      child: Text(label, style: _mono(8.1)),
    );
  }
}

const _accountCopy = <String, Map<String, String>>{
  'en': {
    'member_access': 'MEMBER ACCESS',
    'member': 'MEMBER',
    'member_offer': '50% MEMBER OFFER',
    'register_short': 'REGISTER ONCE · GET 50% OFF COWORKING',
    'phone_short': 'PHONE',
    'phone': 'PHONE',
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
    'phone_short': 'ТЕЛЕФОН',
    'phone': 'ТЕЛЕФОН',
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
    'phone_short': 'ĐIỆN THOẠI',
    'phone': 'ĐIỆN THOẠI',
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