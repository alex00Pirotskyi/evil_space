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
  String? _message;
  bool _messageIsError = false;

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
    } on AdminApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _session = const AdminSession.signedOut();
        _message = error.message;
        _messageIsError = true;
      });
    }
  }

  Future<void> _submit() async {
    if (_busy) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!email.contains('@')) {
      _setMessage('Enter a valid email address.', error: true);
      return;
    }
    if (password.length < 10) {
      _setMessage('Password must be at least 10 characters.', error: true);
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      if (_requestAccess) {
        final message = await _api.register(email: email, password: password);
        if (!mounted) return;
        setState(() {
          _busy = false;
          _message = message;
          _messageIsError = false;
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
        _messageIsError = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'Could not reach the Evil Space admin service.';
        _messageIsError = true;
      });
    }
  }

  void _setMessage(String value, {required bool error}) {
    setState(() {
      _message = value;
      _messageIsError = error;
    });
  }

  Future<void> _logoutAndExit() async {
    try {
      await _api.logout();
    } catch (_) {}
    if (!mounted) return;
    widget.onExit();
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
      if (AdminBuildConfig.previewEnabled) {
        return AdminScreen(onExit: _logoutAndExit);
      }
      return _AdminBuildDisabled(
        email: session.email,
        onLogout: _logoutAndExit,
      );
    }

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
                      const EvilCoworkingLogo(width: 220),
                      const SizedBox(height: 32),
                      const Divider(color: BrandPalette.ink),
                      const SizedBox(height: 18),
                      Text('STAFF ACCESS', style: _mono(11, spacing: 1.1)),
                      const SizedBox(height: 18),
                      Text(
                        _requestAccess
                            ? 'Request admin access.'
                            : 'Sign in to operations.',
                        style: _serif(36, height: 1.02),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _requestAccess
                            ? 'Enter the email and password you want to use. Evil Space will email the owner for approval. Your password is stored only as a salted server-side hash.'
                            : 'Only owner-approved administrators can sign in.',
                        style: _serif(
                          17,
                          color: BrandPalette.inkMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _emailController,
                        autofillHints: const [AutofillHints.email],
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        enabled: !_busy,
                        decoration: _inputDecoration('EMAIL'),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        autofillHints: _requestAccess
                            ? const [AutofillHints.newPassword]
                            : const [AutofillHints.password],
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        enabled: !_busy,
                        onSubmitted: (_) => _submit(),
                        decoration: _inputDecoration('PASSWORD'),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border.all(color: BrandPalette.ink),
                            color: _messageIsError
                                ? BrandPalette.paperDeep
                                : BrandPalette.paperLift,
                          ),
                          child: Text(
                            _message!,
                            style: _mono(10.5, height: 1.4),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          foregroundColor: BrandPalette.paperLift,
                          backgroundColor: BrandPalette.ink,
                          disabledForegroundColor: BrandPalette.paperLift,
                          disabledBackgroundColor: BrandPalette.inkMuted,
                          minimumSize: const Size.fromHeight(54),
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: Text(
                          _busy
                              ? 'PLEASE WAIT…'
                              : _requestAccess
                              ? 'SEND APPROVAL REQUEST'
                              : 'SIGN IN',
                          style: _mono(
                            10.5,
                            color: BrandPalette.paperLift,
                            spacing: 0.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _requestAccess = !_requestAccess;
                                _message = null;
                                _passwordController.clear();
                              }),
                        style: TextButton.styleFrom(
                          foregroundColor: BrandPalette.ink,
                          minimumSize: const Size.fromHeight(48),
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: Text(
                          _requestAccess
                              ? 'ALREADY APPROVED? SIGN IN'
                              : 'NEW ADMIN? REQUEST ACCESS',
                          style: _mono(10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: widget.onExit,
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: Text(
                          'BACK TO PUBLIC PAGE',
                          style: _mono(10),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BrandPalette.ink,
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: BrandPalette.ink),
                          shape: const RoundedRectangleBorder(),
                        ),
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
}

class _AdminBuildDisabled extends StatelessWidget {
  const _AdminBuildDisabled({required this.email, required this.onLogout});

  final String? email;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandPalette.paper,
      body: BrandPaper(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const EvilCoworkingLogo(width: 220),
                    const SizedBox(height: 28),
                    Text('SIGNED IN', style: _mono(11, spacing: 1.1)),
                    const SizedBox(height: 12),
                    Text(
                      email ?? 'Approved administrator',
                      style: _serif(30),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'This build does not include the operations dashboard. Rebuild the web app with EVIL_SPACE_ADMIN_PREVIEW=true.',
                      style: _serif(
                        17,
                        color: BrandPalette.inkMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: onLogout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BrandPalette.ink,
                        minimumSize: const Size.fromHeight(50),
                        side: const BorderSide(color: BrandPalette.ink),
                        shape: const RoundedRectangleBorder(),
                      ),
                      child: Text('LOG OUT', style: _mono(10)),
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
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: _mono(10, spacing: 0.7),
    filled: true,
    fillColor: BrandPalette.paperLift,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: BrandPalette.ink),
      borderRadius: BorderRadius.zero,
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: BrandPalette.ink, width: 2),
      borderRadius: BorderRadius.zero,
    ),
    disabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: BrandPalette.inkMuted),
      borderRadius: BorderRadius.zero,
    ),
  );
}

TextStyle _serif(
  double size, {
  Color color = BrandPalette.ink,
  double height = 1.05,
}) {
  return TextStyle(
    color: color,
    fontFamily: 'Georgia',
    fontFamilyFallback: const ['Times New Roman', 'serif'],
    fontSize: size,
    fontWeight: FontWeight.w400,
    height: height,
    letterSpacing: -0.25,
  );
}

TextStyle _mono(
  double size, {
  Color color = BrandPalette.ink,
  double spacing = 0,
  double height = 1.2,
}) {
  return TextStyle(
    color: color,
    fontFamily: 'Courier New',
    fontFamilyFallback: const ['monospace'],
    fontSize: size,
    fontWeight: FontWeight.w700,
    height: height,
    letterSpacing: spacing,
  );
}
