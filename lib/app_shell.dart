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
      alignment: 0.05,
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
      backgroundColor: const Color(0xFF171717),
      body: LayoutBuilder(
        builder: (context, viewport) {
          final width = viewport.maxWidth;
          final height = viewport.maxHeight;
          final isPhone = width < 620;
          final isCompact = width < 900;
          final reducedMotion =
              MediaQuery.maybeOf(context)?.disableAnimations ?? false;
          final backgroundPixelSize = isPhone ? 4.0 : (isCompact ? 5.0 : 6.0);
          final horizontalPadding = isPhone ? 16.0 : (isCompact ? 28.0 : 44.0);
          final verticalPadding = isPhone ? 18.0 : 28.0;
          final contentWidth = (width - (horizontalPadding * 2))
              .clamp(1.0, 920.0)
              .toDouble();

          return Stack(
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: LivingPixelBackground(
                      pixelCellSize: backgroundPixelSize,
                      brightness: isPhone ? 0.62 : 0.69,
                      reducedMotion: reducedMotion,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: isPhone
                        ? const Color(0x52000000)
                        : const Color(0x3D000000),
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
                      isPhone ? 44 : 72,
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
                            ),
                            SizedBox(height: isPhone ? 38 : 68),
                            _buildHero(
                              maxWidth: contentWidth,
                              isPhone: isPhone,
                            ),
                            SizedBox(height: isPhone ? 64 : 104),
                            KeyedSubtree(
                              key: _pricesKey,
                              child: _buildPrices(
                                maxWidth: contentWidth,
                                isPhone: isPhone,
                              ),
                            ),
                            SizedBox(height: isPhone ? 58 : 92),
                            KeyedSubtree(
                              key: _nowKey,
                              child: _buildAnnouncements(
                                maxWidth: contentWidth,
                                isPhone: isPhone,
                              ),
                            ),
                            SizedBox(height: isPhone ? 58 : 92),
                            KeyedSubtree(
                              key: _contactKey,
                              child: _buildContact(
                                maxWidth: contentWidth,
                                isPhone: isPhone,
                              ),
                            ),
                            SizedBox(height: isPhone ? 46 : 72),
                            _buildFooter(contentWidth),
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
  }) {
    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PixelDevilLogo(
          pixelSize: isPhone ? 2.0 : 2.3,
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
        const SizedBox(width: 12),
        Flexible(
          child: ReadablePixelText(
            text: widget.localization.t('brand_title'),
            maxWidth: isPhone ? 210 : 270,
            fontSize: isPhone ? 22 : 26,
            pixelSize: 1.7,
            letterSpacing: 1.8,
            maxLines: 1,
            header: true,
            onTap: () => widget.onNavigate(AppRoute.home),
          ),
        ),
      ],
    );

    final languageSelector = _buildLanguageSelector(isPhone);
    final navigation = _buildNavigation(isPhone);

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
          const SizedBox(height: 14),
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

  Widget _buildLanguageSelector(bool isPhone) {
    return Wrap(
      spacing: isPhone ? 10 : 14,
      children: AppLanguage.values.map((language) {
        final selected = widget.localization.language == language;
        return ReadablePixelText(
          text: language.code.toUpperCase(),
          maxWidth: 36,
          fontSize: isPhone ? 13 : 14,
          pixelSize: 1.35,
          maxLines: 1,
          color: selected ? Colors.white : const Color(0xFF9E9E9E),
          hoverColor: Colors.white,
          semanticLabel: language.code,
          onTap: () => widget.localization.setLanguage(language),
        );
      }).toList(),
    );
  }

  Widget _buildNavigation(bool isPhone) {
    final items = [
      (widget.localization.t('nav_prices'), _pricesKey),
      (widget.localization.t('nav_now'), _nowKey),
      (widget.localization.t('nav_contact'), _contactKey),
    ];

    return Wrap(
      spacing: isPhone ? 18 : 24,
      runSpacing: 4,
      children: items.map((item) {
        return ReadablePixelText(
          text: item.$1,
          maxWidth: isPhone ? 92 : 120,
          fontSize: isPhone ? 14 : 15,
          pixelSize: 1.4,
          maxLines: 1,
          color: const Color(0xFFD8D8D8),
          onTap: () => _scrollTo(item.$2),
        );
      }).toList(),
    );
  }

  Widget _buildHero({
    required double maxWidth,
    required bool isPhone,
  }) {
    final status = _content.status;
    return _ReadabilityScrim(
      strong: true,
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 18 : 28,
        vertical: isPhone ? 26 : 38,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReadablePixelText(
            text: widget.localization.t('hero_title'),
            maxWidth: maxWidth - (isPhone ? 36 : 56),
            fontSize: isPhone ? 42 : 62,
            pixelSize: 2.0,
            letterSpacing: 1.4,
            header: true,
          ),
          const SizedBox(height: 8),
          ReadablePixelText(
            text: widget.localization.t('hero_city'),
            maxWidth: maxWidth - (isPhone ? 36 : 56),
            fontSize: isPhone ? 22 : 28,
            pixelSize: 1.6,
            color: const Color(0xFFD0D0D0),
            letterSpacing: 1.8,
            maxLines: 1,
          ),
          SizedBox(height: isPhone ? 34 : 46),
          ReadablePixelText(
            text: widget.localization.t('today'),
            maxWidth: maxWidth - (isPhone ? 36 : 56),
            fontSize: isPhone ? 15 : 17,
            pixelSize: 1.4,
            color: const Color(0xFFBDBDBD),
            letterSpacing: 1.6,
            maxLines: 1,
          ),
          const SizedBox(height: 6),
          ReadablePixelText(
            text: '${status.occupied} / ${status.total}',
            maxWidth: maxWidth - (isPhone ? 36 : 56),
            fontSize: isPhone ? 44 : 56,
            pixelSize: 1.8,
            letterSpacing: 2.0,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          ReadablePixelText(
            text: widget.localization.t('occupied'),
            maxWidth: maxWidth - (isPhone ? 36 : 56),
            fontSize: isPhone ? 20 : 24,
            pixelSize: 1.55,
            color: const Color(0xFFF0F0F0),
          ),
          const SizedBox(height: 8),
          ReadablePixelText(
            text: '${status.free} ${widget.localization.t('free')}',
            maxWidth: maxWidth - (isPhone ? 36 : 56),
            fontSize: isPhone ? 16 : 18,
            pixelSize: 1.4,
            color: const Color(0xFFC5C5C5),
            maxLines: 1,
          ),
          SizedBox(height: isPhone ? 24 : 30),
          ReadablePixelText(
            text: widget.localization.t('photos_note'),
            maxWidth: maxWidth - (isPhone ? 36 : 56),
            fontSize: isPhone ? 12 : 13,
            pixelSize: 1.25,
            color: const Color(0xFFAAAAAA),
          ),
        ],
      ),
    );
  }

  Widget _buildPrices({
    required double maxWidth,
    required bool isPhone,
  }) {
    return _ReadabilityScrim(
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 18 : 28,
        vertical: isPhone ? 24 : 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            widget.localization.t('prices_title'),
            maxWidth - (isPhone ? 36 : 56),
            isPhone,
          ),
          const SizedBox(height: 6),
          ReadablePixelText(
            text: widget.localization.t('prices_currency'),
            maxWidth: 80,
            fontSize: 12,
            pixelSize: 1.25,
            maxLines: 1,
            color: const Color(0xFF9E9E9E),
          ),
          SizedBox(height: isPhone ? 22 : 28),
          for (final price in _content.prices) ...[
            _priceRow(
              price: price,
              maxWidth: maxWidth - (isPhone ? 36 : 56),
              isPhone: isPhone,
            ),
            SizedBox(height: isPhone ? 14 : 16),
          ],
        ],
      ),
    );
  }

  Widget _priceRow({
    required SitePrice price,
    required double maxWidth,
    required bool isPhone,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final priceWidth = isPhone ? 78.0 : 104.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ReadablePixelText(
                text: widget.localization.t(price.labelKey),
                maxWidth: (available - priceWidth - 12).clamp(1, available),
                fontSize: isPhone ? 18 : 21,
                pixelSize: 1.5,
                color: const Color(0xFFF2F2F2),
              ),
            ),
            const SizedBox(width: 12),
            ReadablePixelText(
              text: price.price,
              maxWidth: priceWidth,
              fontSize: isPhone ? 18 : 21,
              pixelSize: 1.5,
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
  }) {
    final innerWidth = maxWidth - (isPhone ? 36 : 56);
    return _ReadabilityScrim(
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 18 : 28,
        vertical: isPhone ? 24 : 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            widget.localization.t('now_title'),
            innerWidth,
            isPhone,
          ),
          SizedBox(height: isPhone ? 22 : 28),
          for (int index = 0;
              index < _content.announcements.length;
              index++) ...[
            ReadablePixelText(
              text: _content.announcements[index].date,
              maxWidth: innerWidth,
              fontSize: isPhone ? 13 : 14,
              pixelSize: 1.3,
              color: const Color(0xFFAAAAAA),
              maxLines: 1,
            ),
            const SizedBox(height: 5),
            ReadablePixelText(
              text: _content.announcements[index]
                  .textFor(widget.localization.language.code),
              maxWidth: innerWidth,
              fontSize: isPhone ? 18 : 21,
              pixelSize: 1.5,
              color: const Color(0xFFF2F2F2),
            ),
            if (index < _content.announcements.length - 1)
              SizedBox(height: isPhone ? 22 : 26),
          ],
        ],
      ),
    );
  }

  Widget _buildContact({
    required double maxWidth,
    required bool isPhone,
  }) {
    final innerWidth = maxWidth - (isPhone ? 36 : 56);
    return _ReadabilityScrim(
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 18 : 28,
        vertical: isPhone ? 24 : 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            widget.localization.t('contact_title'),
            innerWidth,
            isPhone,
          ),
          const SizedBox(height: 8),
          ReadablePixelText(
            text: widget.localization.t('contact_location'),
            maxWidth: innerWidth,
            fontSize: isPhone ? 15 : 17,
            pixelSize: 1.4,
            color: const Color(0xFFB8B8B8),
          ),
          SizedBox(height: isPhone ? 24 : 30),
          for (final contact in _contactLinks) ...[
            ReadablePixelText(
              text:
                  '${widget.localization.t(contact.labelKey)}  /  ${contact.detail}',
              maxWidth: innerWidth,
              fontSize: isPhone ? 18 : 21,
              pixelSize: 1.5,
              color: const Color(0xFFF2F2F2),
              hoverColor: Colors.white,
              onTap: () => _launchExternal(contact.url),
            ),
            SizedBox(height: isPhone ? 8 : 10),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, double maxWidth, bool isPhone) {
    return ReadablePixelText(
      text: text,
      maxWidth: maxWidth,
      fontSize: isPhone ? 28 : 34,
      pixelSize: 1.7,
      letterSpacing: 1.6,
      header: true,
    );
  }

  Widget _buildFooter(double maxWidth) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ReadablePixelText(
        text: 'EVIL SPACE / NHA TRANG',
        maxWidth: maxWidth,
        fontSize: 11,
        pixelSize: 1.2,
        color: const Color(0xFF8E8E8E),
        maxLines: 1,
      ),
    );
  }
}

class _ReadabilityScrim extends StatelessWidget {
  const _ReadabilityScrim({
    required this.child,
    required this.padding,
    this.strong = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(strong ? 0xD9000000 : 0xC4000000),
            Color(strong ? 0xB8000000 : 0xA3000000),
            const Color(0x44000000),
          ],
          stops: const [0, 0.68, 1],
        ),
        border: const Border(
          left: BorderSide(color: Color(0x44FFFFFF)),
        ),
      ),
      child: Padding(padding: padding, child: child),
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
