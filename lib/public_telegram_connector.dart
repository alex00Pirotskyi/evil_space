import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:evil_space/brand_surface.dart';
import 'package:evil_space/localization.dart';
import 'package:evil_space/public_account_bar.dart';
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
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0);
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
    _scrollOffset.dispose();
    super.dispose();
  }

  void _handleLocalizationChanged() {
    if (mounted) setState(() {});
  }

  void _refresh() {
    String? next;
    for (final booking in _deskApi.savedBookings()) {
      if (booking.canConnectTelegram && (booking.pending || booking.accepted)) {
        next = booking.telegramLinkUrl;
        break;
      }
    }
    if (!mounted || next == _telegramUrl) return;
    setState(() => _telegramUrl = next);
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical) {
      _scrollOffset.value = notification.metrics.pixels;
    }
    return false;
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

  double _memberAnchorTop(BuildContext context, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final safeTop = MediaQuery.paddingOf(context).top;
    if (width >= 620) return safeTop + 276;
    if (width < 440) return safeTop + 259;
    return safeTop + 238;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final anchorTop = _memberAnchorTop(context, constraints);
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                onNotification: _handleScroll,
                child: widget.child,
              ),
            ),
            ValueListenableBuilder<double>(
              valueListenable: _scrollOffset,
              builder: (context, scrollOffset, _) {
                final top = anchorTop - scrollOffset;
                if (top <= -46 || top >= constraints.maxHeight) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  left: 0,
                  right: 0,
                  top: top,
                  child: PublicAccountBar(localization: widget.localization),
                );
              },
            ),
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
      },
    );
  }
}
