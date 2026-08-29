import 'package:flutter/material.dart';

import 'package:evil_space/admin_api.dart';
import 'package:evil_space/admin_screen.dart';
import 'package:evil_space/brand_logo.dart';
import 'package:evil_space/brand_surface.dart';

class AdminPortal extends StatefulWidget {
  const AdminPortal({super.key, required this.onExit});

  final VoidCallback onExit;

  @override
  State<AdminPortal> createState() => _AdminPortalState();
}

class _AdminPortalState extends State<AdminPortal> {
  final _api = AdminApi();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  AdminSession? _session;
  bool _requestAccess = false;
  bool _busy = false;
  bool _passwordVisible = false;
  bool _russian = true;
  String? _message;

  String t(String ru, String en) => _russian ? ru : en;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    try {
      final session = await _api.session();
      if (!mounted) return;
      setState(() => _session = session);
    } catch (_) {
      if (!mounted) return;
      setState(() => _session = const AdminSession.signedOut());
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!email.contains('@')) {
      setState(() => _message = t('Введите правильный email.', 'Enter a valid email.'));
      return;
    }
    if (password.length < 4) {
      setState(() => _message = t('Пароль минимум 4 символа.', 'Password must be at least 4 characters.'));
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      if (_requestAccess) {
        await _api.register(email: email, password: password);
        if (!mounted) return;
        setState(() {
          _busy = false;
          _message = t(
            'Запрос отправлен владельцу. После подтверждения можно войти.',
            'Request sent to the owner. Sign in after approval.',
          );
          _passwordController.clear();
        });
      } else {
        final session = await _api.login(email: email, password: password);
        if (!mounted) return;
        setState(() {
          _busy = false;
          _session = session;
          _message = null;
        });
      }
    } on AdminApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = t('Нет связи с сервером.', 'Could not reach the server.');
      });
    }
  }

  Future<void> _logoutAndExit() async {
    try {
      await _api.logout();
    } catch (_) {}
    if (!mounted) return;
    widget.onExit();
  }

  Future<void> _showAdmins() async {
    try {
      final admins = await _api.admins();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: BrandPalette.paper,
          shape: const RoundedRectangleBorder(),
          title: Text(t('Администраторы', 'Administrators'), style: _serif(28)),
          content: SizedBox(
            width: 460,
            child: admins.isEmpty
                ? Text(t('Список пуст.', 'No administrators.'), style: _serif(17))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: admins
                        .map(
                          (admin) => Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: BrandPalette.rule)),
                            ),
                            child: Row(
                              children: [
                                Expanded(child: Text(admin.email, style: _mono(10))),
                                const SizedBox(width: 10),
                                Text(
                                  admin.status == 'approved'
                                      ? t('АКТИВЕН', 'ACTIVE')
                                      : admin.status.toUpperCase(),
                                  style: _mono(9.5),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t('ЗАКРЫТЬ', 'CLOSE'), style: _mono(10)),
            ),
          ],
        ),
      );
    } on AdminApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
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

    if (session.authenticated) {
      if (!AdminBuildConfig.previewEnabled) {
        return _disabled();
      }
      return AdminScreen(
        api: _api,
        onExit: _logoutAndExit,
        onManageAdmins: _showAdmins,
      );
    }

    return _login();
  }

  Widget _disabled() {
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
                    const EvilCoworkingLogo(width: 210),
                    const SizedBox(height: 28),
                    Text(t('Админ-панель выключена в этой сборке.', 'Admin is disabled in this build.'), style: _serif(28)),
                    const SizedBox(height: 18),
                    OutlinedButton(
                      onPressed: _logoutAndExit,
                      style: _outlineButton(),
                      child: Text(t('ВЫЙТИ', 'EXIT'), style: _mono(10)),
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

  Widget _login() {
    return Scaffold(
      backgroundColor: BrandPalette.paper,
      body: BrandPaper(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const EvilCoworkingLogo(width: 210),
                          const Spacer(),
                          _languageButton('RU', _russian, () => setState(() => _russian = true)),
                          _languageButton('EN', !_russian, () => setState(() => _russian = false)),
                        ],
                      ),
                      const SizedBox(height: 30),
                      const Divider(color: BrandPalette.ink),
                      const SizedBox(height: 18),
                      Text(
                        _requestAccess ? t('Новый администратор', 'New administrator') : t('Вход', 'Sign in'),
                        style: _serif(36),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _requestAccess
                            ? t('Создайте пароль. Владелец получит письмо для подтверждения.', 'Create a password. The owner will receive an approval email.')
                            : t('Только для подтверждённых администраторов.', 'Approved administrators only.'),
                        style: _serif(17, color: BrandPalette.inkMuted, height: 1.35),
                      ),
                      const SizedBox(height: 26),
                      TextField(
                        controller: _emailController,
                        autofillHints: const [AutofillHints.email],
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        enabled: !_busy,
                        decoration: _input('EMAIL'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        autofillHints: _requestAccess
                            ? const [AutofillHints.newPassword]
                            : const [AutofillHints.password],
                        obscureText: !_passwordVisible,
                        enableSuggestions: false,
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        enabled: !_busy,
                        onSubmitted: (_) => _submit(),
                        decoration: _input(t('ПАРОЛЬ', 'PASSWORD')).copyWith(
                          suffixIcon: IconButton(
                            onPressed: _busy ? null : () => setState(() => _passwordVisible = !_passwordVisible),
                            icon: Icon(
                              _passwordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: BrandPalette.ink,
                            ),
                          ),
                        ),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(border: Border.all(color: BrandPalette.ink)),
                          child: Text(_message!, style: _mono(10.5, height: 1.35)),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: BrandPalette.ink,
                          foregroundColor: BrandPalette.paperLift,
                          minimumSize: const Size.fromHeight(56),
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: Text(
                          _busy
                              ? '…'
                              : _requestAccess
                              ? t('ОТПРАВИТЬ ЗАПРОС', 'REQUEST ACCESS')
                              : t('ВОЙТИ', 'SIGN IN'),
                          style: _mono(11, color: BrandPalette.paperLift),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _requestAccess = !_requestAccess;
                                _message = null;
                                _passwordController.clear();
                              }),
                        child: Text(
                          _requestAccess
                              ? t('УЖЕ ЕСТЬ ДОСТУП? ВОЙТИ', 'ALREADY APPROVED? SIGN IN')
                              : t('НОВЫЙ АДМИН? ЗАПРОСИТЬ ДОСТУП', 'NEW ADMIN? REQUEST ACCESS'),
                          style: _mono(9.5),
                        ),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton(
                        onPressed: widget.onExit,
                        style: _outlineButton(),
                        child: Text(t('НА САЙТ', 'BACK TO SITE'), style: _mono(10)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _languageButton(String label, bool selected, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: selected ? BrandPalette.paperLift : BrandPalette.ink,
        backgroundColor: selected ? BrandPalette.ink : Colors.transparent,
        minimumSize: const Size(42, 40),
        padding: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(),
      ),
      child: Text(label, style: _mono(9.5, color: selected ? BrandPalette.paperLift : BrandPalette.ink)),
    );
  }
}

InputDecoration _input(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: _mono(10),
    filled: true,
    fillColor: BrandPalette.paperLift,
    border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: BrandPalette.ink),
      borderRadius: BorderRadius.zero,
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: BrandPalette.ink, width: 2),
      borderRadius: BorderRadius.zero,
    ),
  );
}

ButtonStyle _outlineButton() {
  return OutlinedButton.styleFrom(
    foregroundColor: BrandPalette.ink,
    minimumSize: const Size.fromHeight(50),
    side: const BorderSide(color: BrandPalette.ink),
    shape: const RoundedRectangleBorder(),
  );
}

TextStyle _serif(
  double size, {
  Color color = BrandPalette.ink,
  double height = 1.08,
}) {
  return TextStyle(
    color: color,
    fontFamily: 'Georgia',
    fontFamilyFallback: const ['Times New Roman', 'serif'],
    fontSize: size,
    height: height,
  );
}

TextStyle _mono(
  double size, {
  Color color = BrandPalette.ink,
  double spacing = 0.35,
  double height = 1.2,
}) {
  return TextStyle(
    color: color,
    fontFamily: 'Courier New',
    fontFamilyFallback: const ['monospace'],
    fontSize: size,
    fontWeight: FontWeight.w700,
    letterSpacing: spacing,
    height: height,
  );
}
