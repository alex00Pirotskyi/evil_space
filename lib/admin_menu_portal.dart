import 'package:flutter/material.dart';

import 'package:evil_space/admin_api.dart';
import 'package:evil_space/admin_commerce_screen.dart';
import 'package:evil_space/brand_logo.dart';
import 'package:evil_space/brand_surface.dart';
import 'package:evil_space/menu_api.dart';

class AdminMenuPortal extends StatefulWidget {
  const AdminMenuPortal({
    super.key,
    required this.onBackToAdmin,
    required this.onExit,
  });

  final VoidCallback onBackToAdmin;
  final VoidCallback onExit;

  @override
  State<AdminMenuPortal> createState() => _AdminMenuPortalState();
}

class _AdminMenuPortalState extends State<AdminMenuPortal> {
  final _adminApi = AdminApi();
  final _menuApi = MenuApi();
  AdminSession? _session;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      final session = await _adminApi.session();
      if (mounted) setState(() => _session = session);
    } catch (_) {
      if (mounted) setState(() => _session = const AdminSession.signedOut());
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return const Scaffold(
        backgroundColor: BrandPalette.paper,
        body: BrandPaper(
          child: Center(child: CircularProgressIndicator(color: BrandPalette.ink)),
        ),
      );
    }
    if (!session.authenticated) {
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
                      const EvilCoworkingLogo(width: 190),
                      const SizedBox(height: 30),
                      const Text(
                        'SIGN IN REQUIRED',
                        style: TextStyle(fontFamily: 'Georgia', fontSize: 30, color: BrandPalette.ink),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Open the main admin panel and sign in before managing the menu, promos and customers.',
                        style: TextStyle(fontFamily: 'Georgia', fontSize: 17, height: 1.35, color: BrandPalette.inkMuted),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: widget.onBackToAdmin,
                        style: FilledButton.styleFrom(
                          foregroundColor: BrandPalette.paperLift,
                          backgroundColor: BrandPalette.ink,
                          minimumSize: const Size.fromHeight(50),
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: const Text('OPEN ADMIN'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: widget.onExit,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BrandPalette.ink,
                          side: const BorderSide(color: BrandPalette.ink),
                          minimumSize: const Size.fromHeight(50),
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: const Text('BACK TO SITE'),
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

    return AdminCommerceScreen(api: _menuApi, onBack: widget.onBackToAdmin);
  }
}
