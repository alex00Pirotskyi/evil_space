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
          : const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  Future<void> _scrollHome() async {
    widget.onNavigate(AppRoute.home);
    if (!_scrollController.hasClients) {
      return;
    }
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    await _scrollController.animateTo(
      0,
      duration: reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
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
          final isCompact = width < 980;
          final reducedMotion =
              MediaQuery.maybeOf(context)?.disableAnimations ?? false;

          final backgroundPitch = isPhone ? 6.0 : (isCompact ? 7.0 : 8.0);
          final textPitch = isPhone ? 2.2 : (isCompact ? 2.4 : 2.6);
          final horizontalPadding = isPhone ? 18.0 : (isCompact ? 28.0 : 36.0);
          final verticalPadding = isPhone ? 18.0 : 26.0;
          final availableWidth = width - (horizontalPadding * 2);
          final contentWidth = availableWidth.clamp(1.0, 760.0).toDouble();

          return Stack(
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: LivingPixelBackground(
                      pixelCellSize: backgroundPitch,
                      brightness: isPhone ? 0.72 : 0.82,
                      focusStrength: isPhone ? 0.16 : 0.27,
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
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      verticalPadding,
                      horizontalPadding,
                      isPhone ? 60 : 86,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 760,
                          minHeight: height - (verticalPadding * 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(
                              maxWidth: contentWidth,
                              isPhone: isPhone,
                              textPitch: textPitch,
                            ),
                            SizedBox(height: isPhone ? 46 : 76),
                            _buildHero(
                              maxWidth: contentWidth,
                              isPhone: isPhone,
                              textPitch: textPitch,
                            ),
                            SizedBox(height: isPhone ? 82 : 132),
                            KeyedSubtree(
                              key: _pricesKey,
                              child: _buildPrices(
                                maxWidth: contentWidth,
                                isPhone: isPhone,
                                textPitch: textPitch,
                              ),
                            ),
                            SizedBox(height: isPhone ? 76 : 116),
                            KeyedSubtree(
                              key: _nowKey,
                              child: _buildAnnouncements(
                                maxWidth: contentWidth,
                                isPhone: isPhone,
                                textPitch: textPitch,
                              ),
                            ),
                            SizedBox(height: isPhone ? 76 : 116),
                            KeyedSubtree(
                              key: _contactKey,
                              child: _buildContact(
                                maxWidth: contentWidth,
                                isPhone: isPhone,
                                textPitch: textPitch,
                              ),
                            ),
                            SizedBox(height: isPhone ? 58 : 84),
                            _buildFooter(contentWidth, textPitch),
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
    required double textPitch,
  }) {
    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LedDevilLogo(
          ledPitch: textPitch * 1.35,
          onTap: _scrollHome,
        ),
        const SizedBox(width: 14),
        Flexible(
          child: LedMatrixText(
            text: widget.localization.t('brand_title'),
            maxWidth: isPhone ? 210 : 280,
            ledPitch: textPitch,
            fontSize: isPhone ? 26 : 31,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
            maxLines: 1,
            header: true,
            color: const Color(0xFFE9E9E9),
            hoverColor: Colors.white,
            onTap: _scrollHome,
          ),
        ),
      ],
    );

    final languageSelector = _buildLanguageSelector(isPhone, textPitch);
    final navigation = _buildNavigation(isPhone, textPitch);

    if (isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: brand),
              languageSelector,
            ],
          ),
          const SizedBox(height: 18),
          navigation,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: brand),
        navigation,
        const SizedBox(width: 28),
        languageSelector,
      ],
    );
  }

  Widget _buildLanguageSelector(bool isPhone, double textPitch) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: AppLanguage.values.map((language) {
        final selected = widget.localization.language == language;
        return LedMatrixText(
          text: language.code.toUpperCase(),
          maxWidth: 54,
          ledPitch: textPitch,
          fontSize: isPhone ? 15 : 17,
          fontWeight: FontWeight.w800,
          maxLines: 1,
          color: selected ? Colors.white : const Color(0xFF8A8A8A),
          hoverColor: Colors.white,
          semanticLabel: language.code,
          onTap: () => widget.localization.setLanguage(language),
        );
      }).toList(),
    );
  }

  Widget _buildNavigation(bool isPhone, double textPitch) {
    final items = [
      (widget.localization.t('nav_prices'), _pricesKey),
      (widget.localization.t('nav_now'), _nowKey),
      (widget.localization.t('nav_contact'), _contactKey),
    ];

    return Wrap(
      spacing: isPhone ? 20 : 24,
      runSpacing: 12,
      children: items.map((item) {
        return LedMatrixText(
          text: item.$1,
          maxWidth: isPhone ? 118 : 142,
          ledPitch: textPitch,
          fontSize: isPhone ? 17 : 19,
          fontWeight: FontWeight.w800,
          maxLines: 1,
          color: const Color(0xFFC4C4C4),
          hoverColor: Colors.white,
          onTap: () => _scrollTo(item.$2),
        );
      }).toList(),
    );
  }

  Widget _buildHero({
    required double maxWidth,
    required bool isPhone,
    required double textPitch,
  }) {
    final status = _content.status;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LedMatrixText(
          text: widget.localization.t('hero_title'),
          maxWidth: maxWidth,
          ledPitch: textPitch,
          fontSize: isPhone ? 42 : 66,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          header: true,
          glow: true,
          color: Colors.white,
          maxLines: isPhone ? 2 : 1,
        ),
        const SizedBox(height: 10),
        LedMatrixText(
          text: widget.localization.t('hero_city'),
          maxWidth: maxWidth,
          ledPitch: textPitch,
          fontSize: isPhone ? 22 : 27,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFCACACA),
          letterSpacing: 1.0,
          maxLines: 1,
        ),
        SizedBox(height: isPhone ? 54 : 72),
        LedMatrixText(
          text: widget.localization.t('today'),
          maxWidth: 160,
          ledPitch: textPitch,
          fontSize: isPhone ? 16 : 18,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF9B9B9B),
          letterSpacing: 1.2,
          maxLines: 1,
        ),
        const SizedBox(height: 12),
        if (isPhone)
          _buildMobileOccupancy(status, maxWidth, textPitch)
        else
          _buildDesktopOccupancy(status, maxWidth, textPitch),
      ],
    );
  }

  Widget _buildMobileOccupancy(
    SiteStatus status,
    double maxWidth,
    double textPitch,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LedMatrixText(
          text: '${status.occupied} / ${status.total}',
          maxWidth: maxWidth,
          ledPitch: textPitch,
          fontSize: 48,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
          maxLines: 1,
          color: Colors.white,
        ),
        const SizedBox(height: 10),
        LedMatrixText(
          text: widget.localization.t('occupied'),
          maxWidth: maxWidth,
          ledPitch: textPitch,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFE0E0E0),
          maxLines: 2,
        ),
        const SizedBox(height: 14),
        LedOccupancyStrip(
          total: status.total,
          occupied: status.occupied,
          pitch: textPitch * 2.5,
        ),
        const SizedBox(height: 12),
        LedMatrixText(
          text: '${status.free} ${widget.localization.t('free')}',
          maxWidth: maxWidth,
          ledPitch: textPitch,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFB4B4B4),
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _buildDesktopOccupancy(
    SiteStatus status,
    double maxWidth,
    double textPitch,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          LedMatrixText(
            text: '${status.occupied} / ${status.total}',
            maxWidth: 230,
            ledPitch: textPitch,
            fontSize: 60,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            maxLines: 1,
            color: Colors.white,
          ),
          const SizedBox(width: 36),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LedMatrixText(
                  text: widget.localization.t('occupied'),
                  maxWidth: 360,
                  ledPitch: textPitch,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFE1E1E1),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                LedOccupancyStrip(
                  total: status.total,
                  occupied: status.occupied,
                  pitch: textPitch * 2.6,
                ),
                const SizedBox(height: 10),
                LedMatrixText(
                  text: '${status.free} ${widget.localization.t('free')}',
                  maxWidth: 280,
                  ledPitch: textPitch,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFAFAFAF),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrices({
    required double maxWidth,
    required bool isPhone,
    required double textPitch,
  }) {
    final sectionWidth = isPhone ? maxWidth : maxWidth.clamp(1, 610).toDouble();

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: sectionWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              widget.localization.t('prices_title'),
              sectionWidth,
              isPhone,
              textPitch,
            ),
            const SizedBox(height: 8),
            LedMatrixText(
              text: widget.localization.t('prices_currency'),
              maxWidth: 90,
              ledPitch: textPitch,
              fontSize: isPhone ? 14 : 16,
              fontWeight: FontWeight.w800,
              maxLines: 1,
              color: const Color(0xFF8D8D8D),
            ),
            SizedBox(height: isPhone ? 28 : 34),
            for (final price in _content.prices) ...[
              _priceRow(
                price: price,
                isPhone: isPhone,
                textPitch: textPitch,
              ),
              SizedBox(height: isPhone ? 17 : 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _priceRow({
    required SitePrice price,
    required bool isPhone,
    required double textPitch,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final valueWidth = isPhone ? 86.0 : 108.0;
        final gap = isPhone ? 16.0 : 24.0;
        final labelWidth = _maxDouble(
          120,
          constraints.maxWidth - valueWidth - gap,
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LedMatrixText(
                text: widget.localization.t(price.labelKey),
                maxWidth: labelWidth,
                ledPitch: textPitch,
                fontSize: isPhone ? 20 : 23,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFDADADA),
                maxLines: 2,
              ),
            ),
            SizedBox(width: gap),
            SizedBox(
              width: valueWidth,
              child: Align(
                alignment: Alignment.topRight,
                child: LedMatrixText(
                  text: price.price,
                  maxWidth: valueWidth,
                  ledPitch: textPitch,
                  fontSize: isPhone ? 20 : 23,
                  fontWeight: FontWeight.w900,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnnouncements({
    required double maxWidth,
    required bool isPhone,
    required double textPitch,
  }) {
    final sectionWidth = isPhone ? maxWidth : maxWidth.clamp(1, 680).toDouble();

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: sectionWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              widget.localization.t('now_title'),
              sectionWidth,
              isPhone,
              textPitch,
            ),
            SizedBox(height: isPhone ? 26 : 32),
            for (int index = 0;
                index < _content.announcements.length;
                index++) ...[
              _announcementRow(
                announcement: _content.announcements[index],
                sectionWidth: sectionWidth,
                isPhone: isPhone,
                textPitch: textPitch,
              ),
              if (index < _content.announcements.length - 1)
                SizedBox(height: isPhone ? 28 : 30),
            ],
          ],
        ),
      ),
    );
  }

  Widget _announcementRow({
    required SiteAnnouncement announcement,
    required double sectionWidth,
    required bool isPhone,
    required double textPitch,
  }) {
    final date = LedMatrixText(
      text: announcement.date,
      maxWidth: 100,
      ledPitch: textPitch,
      fontSize: isPhone ? 14 : 16,
      fontWeight: FontWeight.w800,
      color: const Color(0xFF8D8D8D),
      maxLines: 1,
    );

    final text = LedMatrixText(
      text: announcement.textFor(widget.localization.language.code),
      maxWidth: isPhone ? sectionWidth : sectionWidth - 126,
      ledPitch: textPitch,
      fontSize: isPhone ? 20 : 22,
      fontWeight: FontWeight.w800,
      color: const Color(0xFFDEDEDE),
      maxLines: 3,
    );

    if (isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          date,
          const SizedBox(height: 8),
          text,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 102, child: date),
        const SizedBox(width: 24),
        Expanded(child: text),
      ],
    );
  }

  Widget _buildContact({
    required double maxWidth,
    required bool isPhone,
    required double textPitch,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          widget.localization.t('contact_title'),
          maxWidth,
          isPhone,
          textPitch,
        ),
        const SizedBox(height: 10),
        LedMatrixText(
          text: widget.localization.t('contact_location'),
          maxWidth: maxWidth,
          ledPitch: textPitch,
          fontSize: isPhone ? 16 : 18,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF999999),
          maxLines: 2,
        ),
        SizedBox(height: isPhone ? 28 : 34),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = isPhone ? 1 : 2;
            final spacing = isPhone ? 0.0 : 34.0;
            final itemWidth = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - spacing) / 2;

            return Wrap(
              spacing: spacing,
              runSpacing: isPhone ? 16 : 20,
              children: _contactLinks.map((contact) {
                final text =
                    '${widget.localization.t(contact.labelKey)}  /  ${contact.detail}';
                return SizedBox(
                  width: itemWidth,
                  child: LedMatrixText(
                    text: text,
                    maxWidth: itemWidth,
                    ledPitch: textPitch,
                    fontSize: isPhone ? 19 : 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFD7D7D7),
                    hoverColor: Colors.white,
                    maxLines: 2,
                    onTap: () => _launchExternal(contact.url),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _sectionTitle(
    String text,
    double maxWidth,
    bool isPhone,
    double textPitch,
  ) {
    return LedMatrixText(
      text: text,
      maxWidth: maxWidth,
      ledPitch: textPitch,
      fontSize: isPhone ? 30 : 38,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.8,
      header: true,
      color: Colors.white,
      glow: true,
      maxLines: 2,
    );
  }

  Widget _buildFooter(double maxWidth, double textPitch) {
    return Align(
      alignment: Alignment.centerLeft,
      child: LedMatrixText(
        text: 'EVIL SPACE / NHA TRANG',
        maxWidth: maxWidth,
        ledPitch: textPitch,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF6E6E6E),
        maxLines: 1,
      ),
    );
  }
}

double _maxDouble(double a, double b) => a > b ? a : b;

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
