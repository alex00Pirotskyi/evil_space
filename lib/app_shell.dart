import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:evil_space/app_route.dart';
import 'package:evil_space/config.dart';
import 'package:evil_space/localization.dart';
import 'package:evil_space/pixel_emoji.dart';
import 'package:evil_space/pixel_image_slideshow.dart';
import 'package:evil_space/pixeltools.dart';

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
  Timer? _bootTimer;
  bool _isInitialLoad = true;

  static const List<String> _feedKeys = [
    'feed_community',
    'feed_workspace',
    'feed_studio',
  ];

  static const List<_ContactLink> _contactLinks = [
    _ContactLink(
      labelKey: 'contact_instagram',
      url: 'https://www.instagram.com/evil_space_coworking',
    ),
    _ContactLink(
      labelKey: 'contact_map',
      url: 'https://maps.app.goo.gl/5AFFB2AzszcsFvSz5?g_st=ic',
    ),
    _ContactLink(
      labelKey: 'contact_messenger',
      url: 'https://m.me/61585941012998?hash=AbbCb0BDEsCMHEqJ&source_id=8585216',
    ),
    _ContactLink(
      labelKey: 'contact_zalo',
      url: 'https://zalo.me/84565056748',
    ),
    _ContactLink(
      labelKey: 'contact_phone',
      url: 'tel:+84565056748',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bootTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() => _isInitialLoad = false);
      }
    });
  }

  @override
  void dispose() {
    _bootTimer?.cancel();
    super.dispose();
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
      backgroundColor: const Color(0xFF222222),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final gridSize =
              (screenWidth / 110.0).clamp(3.0, 8.0).toDouble();
          final isMobile = screenWidth < 700;
          final horizontalPadding = gridSize * (isMobile ? 4 : 7);
          final verticalPadding = gridSize * (isMobile ? 4 : 6);

          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: GridPainter(gridSize: gridSize),
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(
                            gridSize: gridSize,
                            isMobile: isMobile,
                          ),
                          SizedBox(height: gridSize * 8),
                          LayoutBuilder(
                            builder: (context, pageConstraints) {
                              return AnimatedSwitcher(
                                duration: const Duration(
                                  milliseconds: pageTransitionMs,
                                ),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                layoutBuilder:
                                    (currentChild, previousChildren) {
                                  return Stack(
                                    alignment: Alignment.topLeft,
                                    children: [
                                      ...previousChildren,
                                      ?currentChild,
                                    ],
                                  );
                                },
                                child: KeyedSubtree(
                                  key: ValueKey(widget.currentRoute),
                                  child: _buildPage(
                                    route: widget.currentRoute,
                                    gridSize: gridSize,
                                    maxWidth: pageConstraints.maxWidth,
                                  ),
                                ),
                              );
                            },
                          ),
                          SizedBox(height: gridSize * 12),
                        ],
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
    required double gridSize,
    required bool isMobile,
  }) {
    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        HoverablePixelBlock(
          key: const ValueKey('header_logo'),
          matrix: Pixelemoji.devilUnframed,
          gridSize: gridSize,
          semanticLabel: 'Evil Space home',
          onTap: () => widget.onNavigate(AppRoute.home),
        ),
        SizedBox(width: gridSize * 3),
        HoverablePixelString(
          key: const ValueKey('header_title'),
          word: widget.localization.t('brand_title'),
          gridSize: gridSize,
          bootDelay: const Duration(milliseconds: 350),
          isInstant: !_isInitialLoad,
          semanticLabel: 'Evil Space home',
          onTap: () => widget.onNavigate(AppRoute.home),
        ),
      ],
    );

    final languages = _buildLanguageSelector(gridSize);

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          brand,
          SizedBox(height: gridSize * 3),
          languages,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        brand,
        const Spacer(),
        languages,
      ],
    );
  }

  Widget _buildLanguageSelector(double gridSize) {
    return Wrap(
      spacing: gridSize * 2,
      runSpacing: gridSize,
      children: AppLanguage.values.map((language) {
        final selected = widget.localization.language == language;
        final semanticLabel = switch (language) {
          AppLanguage.en => 'English',
          AppLanguage.ru => 'Russian',
          AppLanguage.vi => 'Vietnamese',
        };

        return HoverablePixelString(
          key: ValueKey('language_${language.code}'),
          word: language.code.toUpperCase(),
          gridSize: math.max(3.0, gridSize * 0.8).toDouble(),
          isInstant: true,
          semanticLabel: semanticLabel,
          color: selected
              ? Colors.white
              : const Color(0xFF777777),
          hoverColor: Colors.white,
          onTap: () => widget.localization.setLanguage(language),
        );
      }).toList(),
    );
  }

  Widget _buildPage({
    required AppRoute route,
    required double gridSize,
    required double maxWidth,
  }) {
    return switch (route) {
      AppRoute.home => _buildHomePage(gridSize, maxWidth),
      AppRoute.feed => _buildFeedPage(gridSize, maxWidth),
      AppRoute.desks => _buildDeskPage(gridSize, maxWidth),
      AppRoute.office => _buildSimplePage(
          gridSize: gridSize,
          maxWidth: maxWidth,
          titleKey: 'office_title',
          messageKey: 'office_message',
        ),
      AppRoute.studio => _buildSimplePage(
          gridSize: gridSize,
          maxWidth: maxWidth,
          titleKey: 'studio_title',
          messageKey: 'studio_message',
        ),
      AppRoute.gallery => _buildGalleryPage(gridSize, maxWidth),
      AppRoute.contact || AppRoute.qr =>
        _buildContactPage(gridSize, maxWidth),
    };
  }

  Widget _buildHomePage(double gridSize, double maxWidth) {
    final items = [
      ('menu_feed', AppRoute.feed),
      ('menu_desk', AppRoute.desks),
      ('menu_office', AppRoute.office),
      ('menu_studio', AppRoute.studio),
      ('menu_gallery', AppRoute.gallery),
      ('menu_contact', AppRoute.contact),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pixelText(
          text: widget.localization.t('home_subtitle'),
          gridSize: gridSize,
          maxWidth: maxWidth,
          bootDelay: const Duration(milliseconds: 450),
        ),
        SizedBox(height: gridSize * 5),
        for (int index = 0; index < items.length; index++) ...[
          _pixelText(
            text: widget.localization.t(items[index].$1),
            gridSize: gridSize,
            maxWidth: maxWidth,
            bootDelay: Duration(
              milliseconds: 550 + (index * cascadeDelayMs),
            ),
            onTap: () => widget.onNavigate(items[index].$2),
          ),
          SizedBox(height: gridSize),
        ],
      ],
    );
  }

  Widget _buildFeedPage(double gridSize, double maxWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageTitle('feed_title', gridSize, maxWidth),
        SizedBox(height: gridSize * 5),
        for (int index = 0; index < _feedKeys.length; index++) ...[
          _pixelText(
            text: '- ${widget.localization.t(_feedKeys[index])}',
            gridSize: gridSize,
            maxWidth: maxWidth,
            bootDelay: Duration(
              milliseconds: 120 + (index * cascadeDelayMs),
            ),
          ),
          SizedBox(height: gridSize * 3),
        ],
      ],
    );
  }

  Widget _buildDeskPage(double gridSize, double maxWidth) {
    final options = [
      (widget.localization.t('desk_day'), '250K'),
      (widget.localization.t('desk_week'), '1.0M'),
      (widget.localization.t('desk_hot'), '3.2M'),
      (widget.localization.t('desk_private'), '3.5M'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageTitle('desk_title', gridSize, maxWidth),
        SizedBox(height: gridSize * 5),
        for (final option in options) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final priceWidth =
                  PixelTextLayout.measureLineCells(option.$2) * gridSize;
              final gap = gridSize * 5;
              final labelWidth = math
                  .max(gridSize * 12, constraints.maxWidth - priceWidth - gap)
                  .toDouble();
              final wrappedLabel = PixelTextLayout.wrapToWidth(
                text: option.$1,
                maxWidth: labelWidth,
                gridSize: gridSize,
              );

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: HoverablePixelString(
                      word: wrappedLabel,
                      gridSize: gridSize,
                      isInstant: !_isInitialLoad,
                    ),
                  ),
                  SizedBox(width: gap),
                  HoverablePixelString(
                    word: option.$2,
                    gridSize: gridSize,
                    isInstant: true,
                  ),
                ],
              );
            },
          ),
          SizedBox(height: gridSize * 3),
        ],
      ],
    );
  }

  Widget _buildSimplePage({
    required double gridSize,
    required double maxWidth,
    required String titleKey,
    required String messageKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageTitle(titleKey, gridSize, maxWidth),
        SizedBox(height: gridSize * 5),
        _pixelText(
          text: widget.localization.t(messageKey),
          gridSize: gridSize,
          maxWidth: maxWidth,
          isInstant: true,
          onTap: () => widget.onNavigate(AppRoute.contact),
        ),
      ],
    );
  }

  Widget _buildGalleryPage(double gridSize, double maxWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageTitle('gallery_title', gridSize, maxWidth),
        SizedBox(height: gridSize * 4),
        _pixelText(
          text: widget.localization.t('gallery_hint'),
          gridSize: math.max(3.0, gridSize * 0.8).toDouble(),
          maxWidth: maxWidth,
          isInstant: true,
          color: const Color(0xFF888888),
        ),
        SizedBox(height: gridSize * 5),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black),
          ),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: PixelAssetSlideshow(
              pixelCellSize: gridSize * slideshowPixelCellMultiplier,
              semanticsLabel: widget.localization.t('gallery_semantics'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactPage(double gridSize, double maxWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageTitle('contact_title', gridSize, maxWidth),
        SizedBox(height: gridSize * 4),
        _pixelText(
          text: widget.localization.t('contact_location'),
          gridSize: math.max(3.0, gridSize * 0.85).toDouble(),
          maxWidth: maxWidth,
          isInstant: true,
          color: const Color(0xFF999999),
        ),
        SizedBox(height: gridSize * 4),
        for (int index = 0; index < _contactLinks.length; index++) ...[
          _pixelText(
            text: widget.localization.t(_contactLinks[index].labelKey),
            gridSize: gridSize,
            maxWidth: maxWidth,
            bootDelay: Duration(
              milliseconds: 100 + (index * cascadeDelayMs),
            ),
            onTap: () => _launchExternal(_contactLinks[index].url),
          ),
          SizedBox(height: gridSize),
        ],
      ],
    );
  }

  Widget _pageTitle(
    String key,
    double gridSize,
    double maxWidth,
  ) {
    return _pixelText(
      text: widget.localization.t(key),
      gridSize: gridSize,
      maxWidth: maxWidth,
      isInstant: !_isInitialLoad,
    );
  }

  Widget _pixelText({
    required String text,
    required double gridSize,
    required double maxWidth,
    Duration bootDelay = Duration.zero,
    bool? isInstant,
    VoidCallback? onTap,
    Color color = const Color(0xFFDDDDDD),
  }) {
    final wrapped = PixelTextLayout.wrapToWidth(
      text: text,
      maxWidth: maxWidth,
      gridSize: gridSize,
    );

    return HoverablePixelString(
      word: wrapped,
      gridSize: gridSize,
      bootDelay: bootDelay,
      isInstant: isInstant ?? !_isInitialLoad,
      onTap: onTap,
      semanticLabel: text.replaceAll('\n', ' '),
      color: color,
    );
  }
}

class _ContactLink {
  const _ContactLink({
    required this.labelKey,
    required this.url,
  });

  final String labelKey;
  final String url;
}
