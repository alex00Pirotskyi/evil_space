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
  bool _manageAdmins = false;
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
    if (password.length < 4) {
      _setMessage('Password must be at least 4 characters.', error: true);
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
      if (!AdminBuildConfig.previewEnabled) {
        return _AdminBuildDisabled(
          email: session.email,
          onLogout: _logoutAndExit,
        );
      }

      if (_manageAdmins) {
        return _AdminManagementScreen(
          api: _api,
          currentEmail: session.email,
          onBack: () => setState(() => _manageAdmins = false),
          onDeletedSelf: _logoutAndExit,
        );
      }

      return Stack(
        children: [
          Positioned.fill(child: AdminScreen(onExit: _logoutAndExit)),
          Positioned(
            top: 12,
            right: 108,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _manageAdmins = true),
              icon: const Icon(Icons.admin_panel_settings_outlined, size: 17),
              label: Text('ADMINS', style: _mono(9.5)),
              style: OutlinedButton.styleFrom(
                foregroundColor: BrandPalette.ink,
                backgroundColor: BrandPalette.paper,
                minimumSize: const Size(44, 46),
                side: const BorderSide(color: BrandPalette.ink),
                shape: const RoundedRectangleBorder(),
              ),
            ),
          ),
        ],
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
                            ? 'Choose your email and password. Evil Space will email the owner for approval. Passwords are stored only as salted server-side hashes.'
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
                        obscureText: !_passwordVisible,
                        enableSuggestions: false,
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        enabled: !_busy,
                        onSubmitted: (_) => _submit(),
                        decoration: _inputDecoration('PASSWORD').copyWith(
                          suffixIcon: IconButton(
                            tooltip: _passwordVisible
                                ? 'HIDE PASSWORD'
                                : 'SHOW PASSWORD',
                            onPressed: _busy
                                ? null
                                : () => setState(
                                      () => _passwordVisible = !_passwordVisible,
                                    ),
                            icon: Icon(
                              _passwordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: BrandPalette.ink,
                            ),
                          ),
                        ),
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
                                _passwordVisible = false;
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

class _AdminManagementScreen extends StatefulWidget {
  const _AdminManagementScreen({
    required this.api,
    required this.currentEmail,
    required this.onBack,
    required this.onDeletedSelf,
  });

  final AdminApi api;
  final String? currentEmail;
  final VoidCallback onBack;
  final Future<void> Function() onDeletedSelf;

  @override
  State<_AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<_AdminManagementScreen> {
  List<AdminAccount>? _admins;
  String? _error;
  String? _busyEmail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final admins = await widget.api.admins();
      if (!mounted) return;
      setState(() {
        _admins = admins;
        _error = null;
      });
    } on AdminApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _admins = const [];
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _admins = const [];
        _error = 'Could not load administrators.';
      });
    }
  }

  Future<void> _delete(AdminAccount admin) async {
    if (_busyEmail != null) return;

    final controller = TextEditingController();
    var visible = false;
    final superPassword = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: BrandPalette.paper,
          shape: const RoundedRectangleBorder(),
          title: Text('Delete admin?', style: _serif(28)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(admin.email, style: _mono(11)),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  autofocus: true,
                  obscureText: !visible,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: _inputDecoration('SUPER PASSWORD').copyWith(
                    suffixIcon: IconButton(
                      tooltip: visible ? 'HIDE PASSWORD' : 'SHOW PASSWORD',
                      onPressed: () => setDialogState(() => visible = !visible),
                      icon: Icon(
                        visible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: BrandPalette.ink,
                      ),
                    ),
                  ),
                  onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('CANCEL', style: _mono(10)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              style: FilledButton.styleFrom(
                backgroundColor: BrandPalette.ink,
                foregroundColor: BrandPalette.paperLift,
                shape: const RoundedRectangleBorder(),
              ),
              child: Text(
                'DELETE',
                style: _mono(10, color: BrandPalette.paperLift),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();

    if (superPassword == null || superPassword.isEmpty || !mounted) return;

    setState(() {
      _busyEmail = admin.email;
      _error = null;
    });

    try {
      final result = await widget.api.deleteAdmin(
        email: admin.email,
        superPassword: superPassword,
      );
      if (!mounted) return;
      if (result.deletedSelf) {
        await widget.onDeletedSelf();
        return;
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.email} deleted.')),
      );
    } on AdminApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not delete this administrator.');
    } finally {
      if (mounted) setState(() => _busyEmail = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admins = _admins;

    return Scaffold(
      backgroundColor: BrandPalette.paper,
      body: BrandPaper(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: BrandPalette.ink)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'BACK TO OPERATIONS',
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Text('ADMINS', style: _mono(11, spacing: 0.8)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh, size: 17),
                      label: Text('REFRESH', style: _mono(9.5)),
                      style: TextButton.styleFrom(
                        foregroundColor: BrandPalette.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'ADMIN ACCESS',
                            style: _mono(10, color: BrandPalette.inkMuted),
                          ),
                          const SizedBox(height: 8),
                          Text('Administrators', style: _serif(36)),
                          const SizedBox(height: 10),
                          Text(
                            'Deleting an administrator requires the super password. Their active sessions are removed automatically.',
                            style: _serif(
                              17,
                              color: BrandPalette.inkMuted,
                              height: 1.4,
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                border: Border.all(color: BrandPalette.ink),
                                color: BrandPalette.paperDeep,
                              ),
                              child: Text(_error!, style: _mono(10.5)),
                            ),
                          ],
                          const SizedBox(height: 24),
                          if (admins == null)
                            const Center(
                              child: CircularProgressIndicator(
                                color: BrandPalette.ink,
                              ),
                            )
                          else if (admins.isEmpty)
                            Text('NO ADMINS FOUND', style: _mono(11))
                          else
                            ...admins.map(
                              (admin) => _AdminAccountRow(
                                admin: admin,
                                current: admin.email.toLowerCase() ==
                                    widget.currentEmail?.toLowerCase(),
                                busy: _busyEmail == admin.email,
                                onDelete: () => _delete(admin),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminAccountRow extends StatelessWidget {
  const _AdminAccountRow({
    required this.admin,
    required this.current,
    required this.busy,
    required this.onDelete,
  });

  final AdminAccount admin;
  final bool current;
  final bool busy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = admin.status.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BrandPalette.rule)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(admin.email, style: _mono(11.5)),
                const SizedBox(height: 6),
                Text(
                  '$status${current ? '  /  YOU' : ''}  /  ${_formatTimestamp(admin.createdAt)}',
                  style: _mono(9.5, color: BrandPalette.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: busy ? null : onDelete,
            style: OutlinedButton.styleFrom(
              foregroundColor: BrandPalette.ink,
              side: const BorderSide(color: BrandPalette.ink),
              shape: const RoundedRectangleBorder(),
            ),
            child: Text(busy ? 'WAIT…' : 'DELETE', style: _mono(9.5)),
          ),
        ],
      ),
    );
  }
}

String _formatTimestamp(int seconds) {
  if (seconds <= 0) return 'UNKNOWN DATE';
  final date = DateTime.fromMillisecondsSinceEpoch(
    seconds * 1000,
    isUtc: true,
  ).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year}';
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
                    Text(email ?? 'Approved administrator', style: _serif(30)),
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
