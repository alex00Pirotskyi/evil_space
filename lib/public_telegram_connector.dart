import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:evil_space/brand_surface.dart';
import 'package:evil_space/localization.dart';
import 'package:evil_space/public_desk.dart';

class PublicTelegramConnector extends StatefulWidget {
  const PublicTelegramConnector({
    super.key,
    required this.localization,
    required this.child,
  });

  final LocalizationController localization;
  final Widget child;

  @override
  State<PublicTelegramConnector> createState() =>
      _PublicTelegramConnectorState();
}

class _PublicTelegramConnectorState extends State<PublicTelegramConnector> {
  final PublicDeskApi _deskApi = PublicDeskApi();
  Timer? _timer;
  String? _telegramUrl;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    widget.localization.addListener(_handleLocalizationChanged);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void didUpdateWidget(covariant PublicTelegramConnector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localization != widget.localization) {
      oldWidget.localization.removeListener(_handleLocalizationChanged);
      widget.localization.addListener(_handleLocalizationChanged);
    }
  }

  @override
  void dispose() {
    widget.localization.removeListener(_handleLocalizationChanged);
    _timer?.cancel();
    super.dispose();
  }

  void _handleLocalizationChanged() {
    if (mounted) setState(() {});
  }

  void _refresh() {
    final booking = _deskApi.savedBooking();
    final next = booking?.canConnectTelegram == true &&
            (booking!.pending || booking.accepted)
        ? booking.telegramLinkUrl
        : null;
    if (!mounted || next == _telegramUrl) return;
    setState(() => _telegramUrl = next);
  }

  Future<void> _openTelegram() async {
    final value = _telegramUrl;
    if (value == null || _opening) return;
    final uri = Uri.tryParse(value);
    if (uri == null) return;

    setState(() => _opening = true);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('COULD NOT OPEN TELEGRAM')),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (_telegramUrl != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Material(
                    color: BrandPalette.paperLift,
                    elevation: 8,
                    shape: const RoundedRectangleBorder(
                      side: BorderSide(color: BrandPalette.ink),
                    ),
                    child: InkWell(
                      onTap: _opening ? null : _openTelegram,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.send_outlined, size: 19),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.localization.t(
                                  'booking_connect_telegram',
                                ),
                                style: const TextStyle(
                                  color: BrandPalette.ink,
                                  fontFamily: 'Courier New',
                                  fontFamilyFallback: ['monospace'],
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _opening ? '…' : '→',
                              style: const TextStyle(
                                color: BrandPalette.ink,
                                fontFamily: 'Georgia',
                                fontSize: 20,
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
          ),
      ],
    );
  }
}
