import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:evil_space/app_route.dart';
import 'package:evil_space/config.dart';
import 'package:evil_space/coworking_model.dart';
import 'package:evil_space/experience_widgets.dart';
import 'package:evil_space/localization.dart';
import 'package:evil_space/pixel_background.dart';
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
  Timer? _devilIdleTimer;
  bool _isInitialLoad = true;
  bool _bookingRequestReady = false;

  CoworkingStatus _status = CoworkingStatus.demo;
  AppRoute? _previewRoute;
  DevilState _devilState = DevilState.idle;
  int _stayDays = 1;
  String? _selectedDeskId;
  int _bookingStep = 0;
  String _bookingWhenKey = 'book_today';
  String _bookingProductKey = 'desk_day';

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
    _loadStatus();
    _scheduleDevilSleep();
  }

  @override
  void didUpdateWidget(covariant MatrixScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentRoute != widget.currentRoute) {
      _previewRoute = null;
      _wakeDevil(DevilState.happy);
    }
  }

  @override
  void dispose() {
    _bootTimer?.cancel();
    _devilIdleTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final status = await CoworkingStatusRepository.load(rootBundle);
    if (mounted) {
      setState(() => _status = status);
    }
  }

  void _scheduleDevilSleep() {
    _devilIdleTimer?.cancel();
    _devilIdleTimer = Timer(const Duration(seconds: 28), () {
      if (mounted && _previewRoute == null) {
        setState(() => _devilState = DevilState.sleep);
      }
    });
  }

  void _wakeDevil([DevilState state = DevilState.idle]) {
    _devilIdleTimer?.cancel();
    if (mounted && _devilState != state) {
      setState(() => _devilState = state);
    }
    _scheduleDevilSleep();
  }

  void _setPreview(AppRoute? route) {
    if (_previewRoute == route) {
      return;
    }
    setState(() {
      _previewRoute = route;
      _devilState = route == null ? DevilState.idle : DevilState.hoverRight;
    });
    _scheduleDevilSleep();
  }

  void _navigate(AppRoute route) {
    _setPreview(null);
    _wakeDevil(DevilState.happy);
    widget.onNavigate(route);
  }

  void _startBooking({String? deskId, String? productKey}) {
    setState(() {
      _selectedDeskId = deskId ?? _selectedDeskId;
      _bookingProductKey = productKey ?? 'desk_day';
      _bookingWhenKey = 'book_today';
      _bookingStep = 0;
      _bookingRequestReady = false;
      _devilState = DevilState.happy;
    });
    widget.onNavigate(AppRoute.book);
    _scheduleDevilSleep();
  }

  Future<void> _launchExternal(String urlString) async {
    _wakeDevil(DevilState.happy);
    final uri = Uri.parse(urlString);
    final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!launched) {
      debugPrint('Could not launch $urlString');
    }
  }

  Future<void> _completeBooking(_ContactLink contact) async {
    final selectedDesk = _status.deskById(_selectedDeskId);
    final summary = <String>[
      'EVIL SPACE',
      'WHEN: ${widget.localization.t(_bookingWhenKey)}',
      'PRODUCT: ${widget.localization.t(_bookingProductKey)}',
      if (selectedDesk != null) 'DESK: ${selectedDesk.label}',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: summary));
    if (mounted) {
      setState(() {
        _bookingRequestReady = true;
        _devilState = DevilState.success;
      });
    }
    await _launchExternal(contact.url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF171717),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final gridSize =
              (screenWidth / 110.0).clamp(3.0, 8.0).toDouble();
          final isMobile = screenWidth < 700;
          final horizontalPadding = gridSize * (isMobile ? 4 : 7);
          final verticalPadding = gridSize * (isMobile ? 4 : 6);
          final effectiveRoute = _previewRoute ?? widget.currentRoute;
          final reducedMotion =
              MediaQuery.maybeOf(context)?.disableAnimations ?? false;

          return Stack(
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: LivingPixelBackground(
                      scene: PixelBackgroundScene.fromRoute(effectiveRoute),
                      pixelCellSize: math.max(5.5, gridSize * 1.3),
                      transitionStyle: PixelTransitionStyle.runway,
                      brightness: isMobile ? 0.54 : 0.60,
                      reducedMotion: reducedMotion,
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(color: Color(0x33000000)),
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
                                duration: Duration(
                                  milliseconds:
                                      reducedMotion ? 120 : pageTransitionMs,
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
        PixelDevilMascot(
          gridSize: gridSize,
          state: _devilState,
          onTap: () {
            _wakeDevil(DevilState.success);
            _navigate(AppRoute.home);
          },
        ),
        SizedBox(width: gridSize * 3),
        HoverablePixelString(
          key: const ValueKey('header_title'),
          word: widget.localization.t('brand_title'),
          gridSize: gridSize,
          bootDelay: const Duration(milliseconds: 350),
          isInstant: !_isInitialLoad,
          semanticLabel: 'Evil Space home',
          color: Colors.white,
          onTap: () => _navigate(AppRoute.home),
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
          color: selected ? Colors.white : const Color(0xFF999999),
          hoverColor: Colors.white,
          onTap: () {
            _wakeDevil(DevilState.happy);
            widget.localization.setLanguage(language);
          },
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
      AppRoute.map => _buildMapPage(gridSize, maxWidth),
      AppRoute.book => _buildBookingPage(gridSize, maxWidth),
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
      ('menu_map', AppRoute.map),
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
          color: Colors.white,
        ),
        SizedBox(height: gridSize * 4),
        _availabilityLine(gridSize, maxWidth),
        SizedBox(height: gridSize * 3),
        _pixelText(
          text: widget.localization.t('cta_work_here'),
          gridSize: gridSize,
          maxWidth: maxWidth,
          isInstant: true,
          color: Colors.white,
          onTap: _startBooking,
          onHover: (hovered) => _setPreview(hovered ? AppRoute.desks : null),
        ),
        SizedBox(height: gridSize * 6),
        for (int index = 0; index < items.length; index++) ...[
          _pixelText(
            text: widget.localization.t(items[index].$1),
            gridSize: gridSize,
            maxWidth: maxWidth,
            bootDelay: Duration(
              milliseconds: 550 + (index * cascadeDelayMs),
            ),
            onTap: () => _navigate(items[index].$2),
            onHover: (hovered) =>
                _setPreview(hovered ? items[index].$2 : null),
          ),
          SizedBox(height: gridSize),
        ],
      ],
    );
  }

  Widget _availabilityLine(double gridSize, double maxWidth) {
    return _pixelText(
      text:
          '${_status.available} / ${_status.total} ${widget.localization.t('home_availability')}',
      gridSize: math.max(3.0, gridSize * 0.85).toDouble(),
      maxWidth: maxWidth,
      isInstant: true,
      color: const Color(0xFFD0D0D0),
      onTap: () => _navigate(AppRoute.map),
      onHover: (hovered) => _setPreview(hovered ? AppRoute.map : null),
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
    final quote = PricingCalculator.forDays(_stayDays);
    const stayOptions = [1, 3, 5, 10, 30];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageTitle('desk_title', gridSize, maxWidth),
        SizedBox(height: gridSize * 3),
        _availabilityLine(gridSize, maxWidth),
        SizedBox(height: gridSize * 6),
        _pixelText(
          text: widget.localization.t('pricing_stay'),
          gridSize: math.max(3.0, gridSize * 0.85).toDouble(),
          maxWidth: maxWidth,
          isInstant: true,
          color: const Color(0xFFCFCFCF),
        ),
        SizedBox(height: gridSize * 2),
        Wrap(
          spacing: gridSize * 4,
          runSpacing: gridSize * 2,
          children: stayOptions.map((days) {
            final selected = days == _stayDays;
            return HoverablePixelString(
              word: '$days',
              gridSize: gridSize,
              isInstant: true,
              semanticLabel:
                  '$days ${widget.localization.t('pricing_days')}',
              color: selected ? Colors.white : const Color(0xFF999999),
              hoverColor: Colors.white,
              onTap: () {
                _wakeDevil(DevilState.happy);
                setState(() => _stayDays = days);
              },
            );
          }).toList(),
        ),
        SizedBox(height: gridSize * 5),
        for (final option in quote.options) ...[
          _pricingRow(
            option: option,
            best: option.key == quote.bestKey,
            gridSize: gridSize,
            maxWidth: maxWidth,
          ),
          SizedBox(height: gridSize * 2),
        ],
        SizedBox(height: gridSize * 3),
        _pixelText(
          text:
              '${widget.localization.t('pricing_best')} / ${widget.localization.t(quote.bestKey)}',
          gridSize: math.max(3.0, gridSize * 0.85).toDouble(),
          maxWidth: maxWidth,
          isInstant: true,
          color: Colors.white,
        ),
        SizedBox(height: gridSize * 4),
        _pixelText(
          text: widget.localization.t('cta_work_here'),
          gridSize: gridSize,
          maxWidth: maxWidth,
          isInstant: true,
          color: Colors.white,
          onTap: () => _startBooking(productKey: quote.bestKey),
        ),
        SizedBox(height: gridSize * 3),
        _pixelText(
          text: widget.localization.t('menu_map'),
          gridSize: math.max(3.0, gridSize * 0.85).toDouble(),
          maxWidth: maxWidth,
          isInstant: true,
          color: const Color(0xFFC0C0C0),
          onTap: () => _navigate(AppRoute.map),
        ),
      ],
    );
  }

  Widget _pricingRow({
    required PricingOption option,
    required bool best,
    required double gridSize,
    required double maxWidth,
  }) {
    final price = PricingCalculator.compactVnd(option.priceVnd);
    final color = best ? Colors.white : const Color(0xFFB0B0B0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final priceWidth = PixelTextLayout.measureLineCells(price) * gridSize;
        final gap = gridSize * 5;
        final labelWidth = math
            .max(gridSize * 12, constraints.maxWidth - priceWidth - gap)
            .toDouble();
        final label = PixelTextLayout.wrapToWidth(
          text: widget.localization.t(option.key),
          maxWidth: labelWidth,
          gridSize: gridSize,
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: HoverablePixelString(
                word: label,
                gridSize: gridSize,
                isInstant: true,
                color: color,
              ),
            ),
            SizedBox(width: gap),
            HoverablePixelString(
              word: price,
              gridSize: gridSize,
              isInstant: true,
              color: color,
            ),
          ],
        );
      },
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
          color: Colors.white,
          onTap: () => _navigate(AppRoute.contact),
        ),
        SizedBox(height: gridSize * 5),
        _pixelText(
          text: widget.localization.t('cta_work_here'),
          gridSize: math.max(3.0, gridSize * 0.85).toDouble(),
          maxWidth: maxWidth,
          isInstant: true,
          color: const Color(0xFFD0D0D0),
          onTap: _startBooking,
        ),
      ],
    );
  }

  Widget _buildMapPage(double gridSize, double maxWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageTitle('map_title', gridSize, maxWidth),
        SizedBox(height: gridSize * 2),
        _availabilityLine(gridSize, maxWidth),
        SizedBox(height: gridSize * 2),
        _pixelText(
          text: widget.localization.t('map_hint'),
          gridSize: math.max(3.0, gridSize * 0.8).toDouble(),
          maxWidth: maxWidth,
          isInstant: true,
          color: const Color(0xFFBBBBBB),
        ),
        SizedBox(height: gridSize * 4),
        PixelFloorMap(
          status: _status,
          gridSize: gridSize,
          selectedDeskId: _selectedDeskId,
          translate: widget.localization.t,
          onSelectDesk: (deskId) {
            _wakeDevil(DevilState.happy);
            setState(() => _selectedDeskId = deskId);
          },
          onWorkHere: (deskId) => _startBooking(deskId: deskId),
        ),
      ],
    );
  }

  Widget _buildBookingPage(double gridSize, double maxWidth) {
    final selectedDesk = _status.deskById(_selectedDeskId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageTitle('book_title', gridSize, maxWidth),
        if (selectedDesk != null) ...[
          SizedBox(height: gridSize * 2),
          _pixelText(
            text:
                '${widget.localization.t('book_selected_desk')} / ${selectedDesk.label}',
            gridSize: math.max(3.0, gridSize * 0.8).toDouble(),
            maxWidth: maxWidth,
            isInstant: true,
            color: const Color(0xFFCCCCCC),
          ),
        ],
        if (_bookingRequestReady) ...[
          SizedBox(height: gridSize * 3),
          _pixelText(
            text: widget.localization.t('book_request_ready'),
            gridSize: gridSize,
            maxWidth: maxWidth,
            isInstant: true,
            color: Colors.white,
          ),
        ],
        SizedBox(height: gridSize * 5),
        if (_bookingStep == 0)
          _bookingChoiceStep(
            titleKey: 'book_step_when',
            choiceKeys: const ['book_today', 'book_tomorrow', 'book_other'],
            gridSize: gridSize,
            maxWidth: maxWidth,
            selectedKey: _bookingWhenKey,
            onChoose: (key) {
              _wakeDevil(DevilState.happy);
              setState(() {
                _bookingWhenKey = key;
                _bookingStep = 1;
              });
            },
          )
        else if (_bookingStep == 1)
          _bookingChoiceStep(
            titleKey: 'book_step_product',
            choiceKeys: const [
              'desk_day',
              'desk_week',
              'desk_hot',
              'desk_private',
            ],
            gridSize: gridSize,
            maxWidth: maxWidth,
            selectedKey: _bookingProductKey,
            onChoose: (key) {
              _wakeDevil(DevilState.happy);
              setState(() {
                _bookingProductKey = key;
                _bookingStep = 2;
              });
            },
          )
        else
          _buildContactChoiceStep(gridSize, maxWidth),
        if (_bookingStep > 0) ...[
          SizedBox(height: gridSize * 5),
          _pixelText(
            text: widget.localization.t('book_back'),
            gridSize: math.max(3.0, gridSize * 0.8).toDouble(),
            maxWidth: maxWidth,
            isInstant: true,
            color: const Color(0xFFAAAAAA),
            onTap: () {
              _wakeDevil();
              setState(() {
                _bookingStep = math.max(0, _bookingStep - 1);
                _bookingRequestReady = false;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _bookingChoiceStep({
    required String titleKey,
    required List<String> choiceKeys,
    required double gridSize,
    required double maxWidth,
    required String selectedKey,
    required ValueChanged<String> onChoose,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pixelText(
          text: widget.localization.t(titleKey),
          gridSize: gridSize,
          maxWidth: maxWidth,
          isInstant: true,
          color: Colors.white,
        ),
        SizedBox(height: gridSize * 4),
        for (final key in choiceKeys) ...[
          _pixelText(
            text: widget.localization.t(key),
            gridSize: gridSize,
            maxWidth: maxWidth,
            isInstant: true,
            color: key == selectedKey
                ? Colors.white
                : const Color(0xFFC0C0C0),
            onTap: () => onChoose(key),
          ),
          SizedBox(height: gridSize * 2),
        ],
      ],
    );
  }

  Widget _buildContactChoiceStep(double gridSize, double maxWidth) {
    final bookingContacts = _contactLinks.where(
      (contact) =>
          contact.labelKey == 'contact_zalo' ||
          contact.labelKey == 'contact_messenger' ||
          contact.labelKey == 'contact_phone',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pixelText(
          text: widget.localization.t('book_step_contact'),
          gridSize: gridSize,
          maxWidth: maxWidth,
          isInstant: true,
          color: Colors.white,
        ),
        SizedBox(height: gridSize * 3),
        _pixelText(
          text:
              '${widget.localization.t(_bookingWhenKey)} / ${widget.localization.t(_bookingProductKey)}',
          gridSize: math.max(3.0, gridSize * 0.8).toDouble(),
          maxWidth: maxWidth,
          isInstant: true,
          color: const Color(0xFFC0C0C0),
        ),
        SizedBox(height: gridSize * 4),
        for (final contact in bookingContacts) ...[
          _pixelText(
            text: widget.localization.t(contact.labelKey),
            gridSize: gridSize,
            maxWidth: maxWidth,
            isInstant: true,
            color: Colors.white,
            onTap: () => _completeBooking(contact),
          ),
          SizedBox(height: gridSize * 2),
        ],
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
          color: const Color(0xFFBBBBBB),
        ),
        SizedBox(height: gridSize * 5),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24),
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
          color: const Color(0xFFC0C0C0),
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
      color: Colors.white,
    );
  }

  Widget _pixelText({
    required String text,
    required double gridSize,
    required double maxWidth,
    Duration bootDelay = Duration.zero,
    bool? isInstant,
    VoidCallback? onTap,
    ValueChanged<bool>? onHover,
    Color color = const Color(0xFFF0F0F0),
  }) {
    final wrapped = PixelTextLayout.wrapToWidth(
      text: text,
      maxWidth: maxWidth,
      gridSize: gridSize,
    );

    Widget result = HoverablePixelString(
      word: wrapped,
      gridSize: gridSize,
      bootDelay: bootDelay,
      isInstant: isInstant ?? !_isInitialLoad,
      onTap: onTap,
      semanticLabel: text.replaceAll('\n', ' '),
      color: color,
      hoverColor: Colors.white,
    );

    if (onHover != null) {
      result = MouseRegion(
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: result,
      );
    }
    return result;
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
