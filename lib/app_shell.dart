import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:evil_space/app_route.dart';
import 'package:evil_space/coworking_model.dart';
import 'package:evil_space/experience_widgets.dart';
import 'package:evil_space/localization.dart';
import 'package:evil_space/pixel_background.dart';

typedef AppRouteCallback = void Function(AppRoute route);

class MatrixScreen extends StatefulWidget {
  const MatrixScreen({
    super.key,
    required this.currentRoute,
    required this.localization,
    required this.onNavigate,
  });

  final AppRoute currentRoute;
  final LocalizationController localization;
  final AppRouteCallback onNavigate;

  @override
  State<MatrixScreen> createState() => _MatrixScreenState();
}

class _MatrixScreenState extends State<MatrixScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _pricesKey = GlobalKey();
  final GlobalKey _nowKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

  SiteContent _content = SiteContent.demo;
  bool _qrScrollScheduled = false;

  static const List<_ContactLink> _contactLinks = [
    _ContactLink(
      labelKey: 'contact_zalo',
      detail: '+84 56 5056 748',
      url: 'https://zalo.me/84565056748',
    ),
    _ContactLink(
      labelKey: 'contact_instagram',
      detail: '@evil_space_coworking',
      url: 'https://www.instagram.com/evil_space_coworking',
    ),
    _ContactLink(
      labelKey: 'contact_messenger',
      detail: 'EVIL SPACE',
      url: 'https://m.me/61585941012998?hash=AbbCb0BDEsCMHEqJ&source_id=8585216',
    ),
    _ContactLink(
      labelKey: 'contact_phone',
      detail: '+84 56 5056 748',
      url: 'tel:+84565056748',
    ),
    _ContactLink(
      labelKey: 'contact_map',
      detail: 'NHA TRANG',
      url: 'https://maps.app.goo.gl/5AFFB2AzszcsFvSz5?g_st=ic',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadContent();
    _scheduleQrScrollIfNeeded();
  }

  @override
  void didUpdateWidget(covariant MatrixScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentRoute != widget.currentRoute) {
      _qrScrollScheduled = false;
      _scheduleQrScrollIfNeeded();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    final content = await SiteContentRepository.load(rootBundle);
    if (mounted) {
      setState(() => _content = content);
    }
  }

  void _scheduleQrScrollIfNeeded() {
    if (widget.currentRoute != AppRoute.qr || _qrScrollScheduled) {
      return;
    }
    _qrScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollTo(_contactKey);
      }
    });
  }

  Future<void> _scrollTo(GlobalKey key) async {
    final target = key.currentContext;
    if (target == null) {
      return;
    }
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    await Scrollable.ensureVisible(
      target,
      duration: reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  Future<void> _launchExternal(String urlString) async {
    final uri = Uri.parse(urlString);
    final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!launched) {
      debugPrint('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, viewport) {
          final width = viewport.maxWidth;
          final height = viewport.maxHeight;
          final isPhone = width < 620;
          final isCompact = width < 900;
          final reducedMotion =
              MediaQuery.maybeOf(context)?.disableAnimations ?? false;
          final ledPitch = isPhone ? 4.0 : (isCompact ? 4.5 : 5.0);
          final horizontalPadding = ledPitch * (isPhone ? 4 : (isCompact ? 6 : 8));
          final verticalPadding = ledPitch * (isPhone ? 4 : 5);
          final contentWidth = (width - (horizontalPadding * 2))
              .clamp(1.0, 920.0)
              .toDouble();

          return Stack(
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: LivingPixelBackground(
                      pixelCellSize: ledPitch,
                      brightness: isPhone ? 0.69 : 0.76,
                      reducedMotion: reducedMotion,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: !isPhone,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      verticalPadding,
                      horizontalPadding,
                      ledPitch * (isPhone ? 12 : 16),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 920,
                          minHeight: height - (verticalPadding * 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(
                              maxWidth: contentWidth,
                              isPhone: isPhone,
                              ledPitch: ledPitch,
                            ),
                            SizedBox(height: ledPitch * (isPhone ? 10 : 15)),
                            _buildHero(
                              maxWidth: contentWidth,
                              isPhone: isPhone,
                              ledPitch: ledPitch,
                            ),
                            SizedBox(height: ledPitch * (isPhone ? 17 : 24)),
                            KeyedSubtree(
                              key: _pricesKey,
                              child: _buildPrices(
                                maxWidth: contentWidth,
                                isPhone: isPhone,
                                ledPitch: ledPitch,
                              ),
                            ),
                            SizedBox(height: ledPitch * (isPhone ? 15 : 21)),
                            KeyedSubtree(
                              key: _nowKey,
                              child: _buildAnnouncements(
                                maxWidth: contentWidth,
                                isPhone: isPhone,
                                ledPitch: ledPitch,
                              ),
                            ),
                            SizedBox(height: ledPitch * (isPhone ? 15 : 21)),
                            KeyedSubtree(
                              key: _contactKey,
                              child: _buildContact(
                                maxWidth: contentWidth,
                                isPhone: isPhone,
                                ledPitch: ledPitch,
                              ),
                            ),
                            SizedBox(height: ledPitch * (isPhone ? 12 : 16)),
                            _buildFooter(contentWidth, ledPitch),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader({
    required double maxWidth,
    required bool isPhone,
    required double ledPitch,
  }) {
    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LedDevilLogo(
          ledPitch: ledPitch * (isPhone ? 0.64 : 0.72),
          onTap: () {
            widget.onNavigate(AppRoute.home);
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
              );
            }
          },
        ),
        SizedBox(width: ledPitch * 3),
        Flexible(
          child: LedMatrixText(
            text: widget.localization.t('brand_title'),
            maxWidth: isPhone ? 205 : 270,
            ledPitch: ledPitch,
            fontSize: isPhone ? 25 : 31,
            letterSpacing: 1.2,
            maxLines: 1,
            header: true,
            onTap: () => widget.onNavigate(AppRoute.home),
          ),
        ),
      ],
    );

    final languageSelector = _buildLanguageSelector(isPhone, ledPitch);
    final navigation = _buildNavigation(isPhone, ledPitch);

    if (isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          brand,
          SizedBox(height: ledPitch * 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: navigation),
              SizedBox(width: ledPitch * 3),
              languageSelector,
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: brand),
        navigation,
        SizedBox(width: ledPitch * 6),
        languageSelector,
      ],
    );
  }

  Widget _buildLanguageSelector(bool isPhone, double ledPitch) {
    return Wrap(
      spacing: ledPitch * 2,
      runSpacing: ledPitch,
      children: AppLanguage.values.map((language) {
        final selected = widget.localization.language == language;
        return LedMatrixText(
          text: language.code.toUpperCase(),
          maxWidth: ledPitch * 11,
          ledPitch: ledPitch,
          fontSize: isPhone ? 16 : 18,
          maxLines: 1,
          color: selected ? Colors.white : const Color(0xFFA8A8A8),
          hoverColor: Colors.white,
          semanticLabel: language.code,
          onTap: () => widget.localization.setLanguage(language),
        );
      }).toList(),
    );
  }

  Widget _buildNavigation(bool isPhone, double ledPitch) {
    final items = [
      (widget.localization.t('nav_prices'), _pricesKey),
      (widget.localization.t('nav_now'), _nowKey),
      (widget.localization.t('nav_contact'), _contactKey),
    ];

    return Wrap(
      spacing: ledPitch * 4,
      runSpacing: ledPitch,
      children: items.map((item) {
        return LedMatrixText(
          text: item.$1,
          maxWidth: isPhone ? ledPitch * 25 : ledPitch * 30,
          ledPitch: ledPitch,
          fontSize: isPhone ? 17 : 19,
          maxLines: 1,
          color: const Color(0xFFD0D0D0),
          hoverColor: Colors.white,
          onTap: () => _scrollTo(item.$2),
        );
      }).toList(),
    );
  }

  Widget _buildHero({
    required double maxWidth,
    required bool isPhone,
    required double ledPitch,
  }) {
    final status = _content.status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LedMatrixText(
          text: widget.localization.t('hero_title'),
          maxWidth: maxWidth,
          ledPitch: ledPitch,
          fontSize: isPhone ? 48 : 68,
          letterSpacing: 1.0,
          header: true,
        ),
        SizedBox(height: ledPitch * 2),
        LedMatrixText(
          text: widget.localization.t('hero_city'),
          maxWidth: maxWidth,
          ledPitch: ledPitch,
          fontSize: isPhone ? 26 : 32,
          color: const Color(0xFFD2D2D2),
          letterSpacing: 1.2,
          maxLines: 1,
        ),
        SizedBox(height: ledPitch * (isPhone ? 9 : 12)),
        LedMatrixText(
          text: widget.localization.t('today'),
          maxWidth: maxWidth,
          ledPitch: ledPitch,
          fontSize: isPhone ? 19 : 21,
          color: const Color(0xFFB8B8B8),
          letterSpacing: 1.0,
          maxLines: 1,
        ),
        SizedBox(height: ledPitch),
        LedMatrixText(
          text: '${status.occupied} / ${status.total}',
          maxWidth: maxWidth,
          ledPitch: ledPitch,
          fontSize: isPhone ? 50 : 64,
          letterSpacing: 1.5,
          maxLines: 1,
        ),
        SizedBox(height: ledPitch),
        LedMatrixText(
          text: widget.localization.t('occupied'),
          maxWidth: maxWidth,
          ledPitch: ledPitch,
          fontSize: isPhone ? 24 : 28,
          color: const Color(0xFFE8E8E8),
        ),
        SizedBox(height: ledPitch * 2),
        LedMatrixText(
          text: '${status.free} ${widget.localization.t('free')}',
          maxWidth: maxWidth,
          ledPitch: ledPitch,
          fontSize: isPhone ? 20 : 22,
          color: const Color(0xFFC8C8C8),
          maxLines: 1,
        ),
        SizedBox(height: ledPitch * 6),
        LedMatrixText(
          text: widget.localization.t('photos_note'),
          maxWidth: maxWidth,
          ledPitch: ledPitch,
          fontSize: isPhone ? 16 : 18,
          color: const Color(0xFFA8A8A8),
        ),
      ],
    );
  }

  Widget _buildPrices({
    required double maxWidth,
    required bool isPhone,
    required double ledPitch,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          widget.localization.t('prices_title'),
          maxWidth,
          isPhone,
          ledPitch,
        ),
        SizedBox(height: ledPitch * 2),
        LedMatrixText(
          text: widget.localization.t('prices_currency'),
          maxWidth: ledPitch * 22,
          ledPitch: ledPitch,
          fontSize: isPhone ? 16 : 18,
          maxLines: 1,
          color: const Color(0xFFA0A0A0),
        ),
        SizedBox(height: ledPitch * 6),
        for (final price in _content.prices) ...[
          _priceRow(
            price: price,
            maxWidth: maxWidth,
            isPhone: isPhone,
            ledPitch: ledPitch,
          ),
          SizedBox(height: ledPitch * 3),
        ],
      ],
    );
  }

  Widget _priceRow({
    required SitePrice price,
    required double maxWidth,
    required bool isPhone,
    required double ledPitch,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final priceWidth = isPhone ? ledPitch * 21 : ledPitch * 25;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LedMatrixText(
                text: widget.localization.t(price.labelKey),
                maxWidth: (available - priceWidth - (ledPitch * 3))
                    .clamp(ledPitch, available),
                ledPitch: ledPitch,
                fontSize: isPhone ? 22 : 25,
                color: const Color(0xFFE2E2E2),
              ),
            ),
            SizedBox(width: ledPitch * 3),
            LedMatrixText(
              text: price.price,
              maxWidth: priceWidth,
              ledPitch: ledPitch,
              fontSize: isPhone ? 22 : 25,
              textAlign: TextAlign.right,
              maxLines: 1,
              color: Colors.white,
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnnouncements({
    required double maxWidth,
    required bool isPhone,
    required double ledPitch,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          widget.localization.t('now_title'),
          maxWidth,
          isPhone,
          ledPitch,
        ),
        SizedBox(height: ledPitch * 6),
        for (int index = 0;
            index < _content.announcements.length;
            index++) ...[
          LedMatrixText(
            text: _content.announcements[index].date,
            maxWidth: maxWidth,
            ledPitch: ledPitch,
            fontSize: isPhone ? 17 : 19,
            color: const Color(0xFFA8A8A8),
            maxLines: 1,
          ),
          SizedBox(height: ledPitch),
          LedMatrixText(
            text: _content.announcements[index]
                .textFor(widget.localization.language.code),
            maxWidth: maxWidth,
            ledPitch: ledPitch,
            fontSize: isPhone ? 22 : 25,
            color: const Color(0xFFE2E2E2),
          ),
          if (index < _content.announcements.length - 1)
            SizedBox(height: ledPitch * 6),
        ],
      ],
    );
  }

  Widget _buildContact({
    required double maxWidth,
    required bool isPhone,
    required double ledPitch,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          widget.localization.t('contact_title'),
          maxWidth,
          isPhone,
          ledPitch,
        ),
        SizedBox(height: ledPitch * 2),
        LedMatrixText(
          text: widget.localization.t('contact_location'),
          maxWidth: maxWidth,
          ledPitch: ledPitch,
          fontSize: isPhone ? 19 : 21,
          color: const Color(0xFFB8B8B8),
        ),
        SizedBox(height: ledPitch * 6),
        for (final contact in _contactLinks) ...[
          LedMatrixText(
            text:
                '${widget.localization.t(contact.labelKey)}  /  ${contact.detail}',
            maxWidth: maxWidth,
            ledPitch: ledPitch,
            fontSize: isPhone ? 21 : 24,
            color: const Color(0xFFD8D8D8),
            hoverColor: Colors.white,
            onTap: () => _launchExternal(contact.url),
          ),
          SizedBox(height: ledPitch * 2),
        ],
      ],
    );
  }

  Widget _sectionTitle(
    String text,
    double maxWidth,
    bool isPhone,
    double ledPitch,
  ) {
    return LedMatrixText(
      text: text,
      maxWidth: maxWidth,
      ledPitch: ledPitch,
      fontSize: isPhone ? 34 : 42,
      letterSpacing: 1.1,
      header: true,
    );
  }

  Widget _buildFooter(double maxWidth, double ledPitch) {
    return Align(
      alignment: Alignment.centerLeft,
      child: LedMatrixText(
        text: 'EVIL SPACE / NHA TRANG',
        maxWidth: maxWidth,
        ledPitch: ledPitch,
        fontSize: 16,
        color: const Color(0xFF929292),
        maxLines: 1,
      ),
    );
  }
}

class _ContactLink {
  const _ContactLink({
    required this.labelKey,
    required this.detail,
    required this.url,
  });

  final String labelKey;
  final String detail;
  final String url;
}
