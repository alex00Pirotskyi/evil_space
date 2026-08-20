import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:evil_space/app_route.dart';
import 'package:evil_space/coworking_model.dart';
import 'package:evil_space/eink_image.dart';
import 'package:evil_space/localization.dart';

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
  final GlobalKey _photosKey = GlobalKey();
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
          : const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.03,
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
          : const Duration(milliseconds: 360),
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
      backgroundColor: EInkPalette.paper,
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _PaperTexturePainter()),
            ),
          ),
          LayoutBuilder(
            builder: (context, viewport) {
              final width = viewport.maxWidth;
              final height = viewport.maxHeight;
              final isPhone = width < 640;
              final horizontalPadding = isPhone ? 20.0 : 36.0;
              final verticalPadding = isPhone ? 18.0 : 28.0;
              final contentWidth = (width - (horizontalPadding * 2))
                  .clamp(1.0, 880.0)
                  .toDouble();

              return SafeArea(
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
                      isPhone ? 54 : 84,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 880,
                          minHeight: height - (verticalPadding * 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(isPhone),
                            SizedBox(height: isPhone ? 52 : 86),
                            _buildHero(contentWidth, isPhone),
                            SizedBox(height: isPhone ? 54 : 82),
                            KeyedSubtree(
                              key: _photosKey,
                              child: _buildPhotos(contentWidth, isPhone),
                            ),
                            SizedBox(height: isPhone ? 70 : 108),
                            KeyedSubtree(
                              key: _pricesKey,
                              child: _buildPrices(contentWidth, isPhone),
                            ),
                            SizedBox(height: isPhone ? 70 : 108),
                            KeyedSubtree(
                              key: _nowKey,
                              child: _buildAnnouncements(contentWidth, isPhone),
                            ),
                            SizedBox(height: isPhone ? 70 : 108),
                            KeyedSubtree(
                              key: _contactKey,
                              child: _buildContact(contentWidth, isPhone),
                            ),
                            SizedBox(height: isPhone ? 54 : 82),
                            _buildFooter(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isPhone) {
    final brand = _EInkAction(
      label: widget.localization.t('brand_title'),
      onTap: _scrollHome,
      strong: true,
    );
    final languages = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: AppLanguage.values.map((language) {
        final selected = widget.localization.language == language;
        return _EInkAction(
          label: language.code.toUpperCase(),
          selected: selected,
          onTap: () => widget.localization.setLanguage(language),
        );
      }).toList(),
    );
    final nav = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _EInkAction(
          label: widget.localization.t('nav_photos'),
          onTap: () => _scrollTo(_photosKey),
        ),
        _EInkAction(
          label: widget.localization.t('nav_prices'),
          onTap: () => _scrollTo(_pricesKey),
        ),
        _EInkAction(
          label: widget.localization.t('nav_now'),
          onTap: () => _scrollTo(_nowKey),
        ),
        _EInkAction(
          label: widget.localization.t('nav_contact'),
          onTap: () => _scrollTo(_contactKey),
        ),
      ],
    );

    if (isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: brand),
              languages,
            ],
          ),
          const SizedBox(height: 14),
          nav,
        ],
      );
    }

    return Row(
      children: [
        brand,
        const Spacer(),
        nav,
        const SizedBox(width: 18),
        languages,
      ],
    );
  }

  Widget _buildHero(double maxWidth, bool isPhone) {
    final status = _content.status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.localization.t('hero_kicker'),
          style: _monoStyle(
            fontSize: isPhone ? 12 : 13,
            weight: FontWeight.w700,
            letterSpacing: 1.7,
          ),
        ),
        SizedBox(height: isPhone ? 14 : 18),
        Text(
          widget.localization.t('hero_title'),
          style: _serifStyle(
            fontSize: isPhone ? 47 : 74,
            weight: FontWeight.w700,
            height: 0.96,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.localization.t('hero_city'),
          style: _serifStyle(
            fontSize: isPhone ? 24 : 32,
            weight: FontWeight.w400,
            height: 1.05,
          ),
        ),
        SizedBox(height: isPhone ? 42 : 58),
        _Hairline(width: maxWidth),
        SizedBox(height: isPhone ? 20 : 26),
        if (isPhone)
          _buildPhoneStatus(status)
        else
          _buildDesktopStatus(status),
        SizedBox(height: isPhone ? 20 : 26),
        _Hairline(width: maxWidth),
      ],
    );
  }

  Widget _buildPhoneStatus(SiteStatus status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.localization.t('today'),
          style: _monoStyle(
            fontSize: 12,
            weight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${status.occupied} / ${status.total}',
          style: _serifStyle(
            fontSize: 52,
            weight: FontWeight.w700,
            height: 0.95,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          widget.localization.t('occupied'),
          style: _serifStyle(fontSize: 19, weight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _OccupancyMarks(total: status.total, occupied: status.occupied),
        const SizedBox(height: 12),
        Text(
          '${status.free} ${widget.localization.t('free')}',
          style: _monoStyle(fontSize: 13, weight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildDesktopStatus(SiteStatus status) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.localization.t('today'),
                style: _monoStyle(
                  fontSize: 12,
                  weight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '${status.occupied} / ${status.total}',
                style: _serifStyle(
                  fontSize: 66,
                  weight: FontWeight.w700,
                  height: 0.92,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.localization.t('occupied'),
                  style: _serifStyle(fontSize: 21, weight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _OccupancyMarks(
                  total: status.total,
                  occupied: status.occupied,
                ),
                const SizedBox(height: 10),
                Text(
                  '${status.free} ${widget.localization.t('free')}',
                  style: _monoStyle(fontSize: 13, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotos(double maxWidth, bool isPhone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(widget.localization.t('photos_title'), isPhone),
        const SizedBox(height: 8),
        Text(
          widget.localization.t('photos_subtitle'),
          style: _serifStyle(
            fontSize: isPhone ? 17 : 19,
            color: EInkPalette.midInk,
          ),
        ),
        SizedBox(height: isPhone ? 22 : 28),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: EInkPalette.ink, width: 1.4),
          ),
          child: AspectRatio(
            aspectRatio: isPhone ? 4 / 3 : 16 / 10,
            child: EInkImageSlideshow(
              sampleSize: isPhone ? 1.6 : 2.0,
              reducedMotion:
                  MediaQuery.maybeOf(context)?.disableAnimations ?? false,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              widget.localization.t('photos_caption'),
              style: _monoStyle(
                fontSize: isPhone ? 10 : 11,
                color: EInkPalette.midInk,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            Text(
              'ATKINSON / 4-TONE',
              style: _monoStyle(
                fontSize: isPhone ? 10 : 11,
                color: EInkPalette.midInk,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrices(double maxWidth, bool isPhone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(widget.localization.t('prices_title'), isPhone),
        const SizedBox(height: 6),
        Text(
          widget.localization.t('prices_currency'),
          style: _monoStyle(
            fontSize: 11,
            weight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: isPhone ? 18 : 22),
        _Hairline(width: maxWidth),
        for (final price in _content.prices) ...[
          Padding(
            padding: EdgeInsets.symmetric(vertical: isPhone ? 15 : 17),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    widget.localization.t(price.labelKey),
                    style: _serifStyle(
                      fontSize: isPhone ? 19 : 22,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Text(
                  price.price,
                  style: _monoStyle(
                    fontSize: isPhone ? 17 : 19,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _Hairline(width: maxWidth, light: true),
        ],
      ],
    );
  }

  Widget _buildAnnouncements(double maxWidth, bool isPhone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(widget.localization.t('now_title'), isPhone),
        SizedBox(height: isPhone ? 18 : 22),
        _Hairline(width: maxWidth),
        for (int index = 0; index < _content.announcements.length; index++) ...[
          Padding(
            padding: EdgeInsets.symmetric(vertical: isPhone ? 18 : 22),
            child: isPhone
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _content.announcements[index].date,
                        style: _monoStyle(
                          fontSize: 11,
                          weight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _content.announcements[index]
                            .textFor(widget.localization.language.code),
                        style: _serifStyle(
                          fontSize: 20,
                          weight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 92,
                        child: Text(
                          _content.announcements[index].date,
                          style: _monoStyle(
                            fontSize: 11,
                            weight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _content.announcements[index]
                              .textFor(widget.localization.language.code),
                          style: _serifStyle(
                            fontSize: 21,
                            weight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          _Hairline(width: maxWidth, light: true),
        ],
      ],
    );
  }

  Widget _buildContact(double maxWidth, bool isPhone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(widget.localization.t('contact_title'), isPhone),
        const SizedBox(height: 8),
        Text(
          widget.localization.t('contact_location'),
          style: _serifStyle(
            fontSize: isPhone ? 17 : 19,
            color: EInkPalette.midInk,
          ),
        ),
        SizedBox(height: isPhone ? 20 : 26),
        _Hairline(width: maxWidth),
        for (final contact in _contactLinks) ...[
          Padding(
            padding: EdgeInsets.symmetric(vertical: isPhone ? 13 : 15),
            child: _ContactRow(
              label: widget.localization.t(contact.labelKey),
              detail: contact.detail,
              onTap: () => _launchExternal(contact.url),
              isPhone: isPhone,
            ),
          ),
          _Hairline(width: maxWidth, light: true),
        ],
      ],
    );
  }

  Widget _sectionHeading(String text, bool isPhone) {
    return Text(
      text,
      style: _serifStyle(
        fontSize: isPhone ? 34 : 44,
        weight: FontWeight.w700,
        height: 1.0,
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Text(
          'EVIL SPACE / NHA TRANG',
          style: _monoStyle(
            fontSize: 10,
            color: EInkPalette.midInk,
            letterSpacing: 1.0,
          ),
        ),
        const Spacer(),
        Text(
          'E-PAPER EDITION',
          style: _monoStyle(
            fontSize: 10,
            color: EInkPalette.midInk,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

TextStyle _serifStyle({
  required double fontSize,
  FontWeight weight = FontWeight.w400,
  Color color = EInkPalette.ink,
  double? height,
}) {
  return TextStyle(
    fontFamily: 'Georgia',
    fontFamilyFallback: const ['Times New Roman', 'serif'],
    fontSize: fontSize,
    fontWeight: weight,
    color: color,
    height: height,
  );
}

TextStyle _monoStyle({
  required double fontSize,
  FontWeight weight = FontWeight.w500,
  Color color = EInkPalette.ink,
  double letterSpacing = 0.4,
}) {
  return TextStyle(
    fontFamily: 'Courier New',
    fontFamilyFallback: const ['monospace'],
    fontSize: fontSize,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: 1.1,
  );
}

class _EInkAction extends StatefulWidget {
  const _EInkAction({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.strong = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool strong;

  @override
  State<_EInkAction> createState() => _EInkActionState();
}

class _EInkActionState extends State<_EInkAction> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  bool get _active => widget.selected || _hovered || _focused || _pressed;

  @override
  Widget build(BuildContext context) {
    final active = _active;
    return Semantics(
      button: true,
      label: widget.label,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (value) => setState(() => _hovered = value),
        onFocusChange: (value) => setState(() => _focused = value),
        onHighlightChanged: (value) => setState(() => _pressed = value),
        splashFactory: NoSplash.splashFactory,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minHeight: 42),
          padding: EdgeInsets.symmetric(
            horizontal: widget.strong ? 0 : 8,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: widget.strong
                ? Colors.transparent
                : (active ? EInkPalette.ink : Colors.transparent),
            border: widget.strong
                ? const Border(
                    bottom: BorderSide(color: EInkPalette.ink, width: 1.5),
                  )
                : Border.all(
                    color: active ? EInkPalette.ink : const Color(0x5577736A),
                    width: 1,
                  ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: _monoStyle(
              fontSize: widget.strong ? 15 : 11,
              weight: FontWeight.w700,
              color: widget.strong
                  ? EInkPalette.ink
                  : (active ? EInkPalette.paper : EInkPalette.ink),
              letterSpacing: widget.strong ? 1.5 : 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactRow extends StatefulWidget {
  const _ContactRow({
    required this.label,
    required this.detail,
    required this.onTap,
    required this.isPhone,
  });

  final String label;
  final String detail;
  final VoidCallback onTap;
  final bool isPhone;

  @override
  State<_ContactRow> createState() => _ContactRowState();
}

class _ContactRowState extends State<_ContactRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.label}, ${widget.detail}',
      child: InkWell(
        onTap: widget.onTap,
        onHover: (value) => setState(() => _hovered = value),
        splashFactory: NoSplash.splashFactory,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: widget.isPhone
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: _serifStyle(
                        fontSize: 20,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.detail,
                      style: _monoStyle(
                        fontSize: 12,
                        weight: FontWeight.w600,
                        color: _hovered
                            ? EInkPalette.ink
                            : EInkPalette.midInk,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.label,
                        style: _serifStyle(
                          fontSize: 21,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      widget.detail,
                      style: _monoStyle(
                        fontSize: 12,
                        weight: FontWeight.w600,
                        color: _hovered
                            ? EInkPalette.ink
                            : EInkPalette.midInk,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _hovered ? '→' : '↗',
                      style: _serifStyle(fontSize: 18, weight: FontWeight.w700),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _OccupancyMarks extends StatelessWidget {
  const _OccupancyMarks({required this.total, required this.occupied});

  final int total;
  final int occupied;

  @override
  Widget build(BuildContext context) {
    final safeTotal = total.clamp(1, 30);
    final safeOccupied = occupied.clamp(0, safeTotal);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(safeTotal, (index) {
        final filled = index < safeOccupied;
        return Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: filled ? EInkPalette.ink : Colors.transparent,
            border: Border.all(color: EInkPalette.ink, width: 1.2),
          ),
        );
      }),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline({required this.width, this.light = false});

  final double width;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Divider(
        height: 1,
        thickness: light ? 0.6 : 1.2,
        color: light ? const Color(0x6677736A) : EInkPalette.ink,
      ),
    );
  }
}

class _PaperTexturePainter extends CustomPainter {
  const _PaperTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    for (double y = 9; y < size.height; y += 23) {
      for (double x = 11; x < size.width; x += 29) {
        final seed = ((x.toInt() * 31) ^ (y.toInt() * 17)) & 7;
        final alpha = 5 + seed;
        paint.color = Color.fromARGB(alpha, 55, 52, 46);
        canvas.drawRect(
          Rect.fromLTWH(x + (seed % 3), y + (seed % 2), 0.8, 0.8),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PaperTexturePainter oldDelegate) => false;
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
