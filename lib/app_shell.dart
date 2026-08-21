import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:evil_space/app_route.dart';
import 'package:evil_space/coworking_model.dart';
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

class _MatrixScreenState extends State<MatrixScreen>
    with SingleTickerProviderStateMixin {
  static const Color _paper = Color(0xFFF2F0E8);
  static const Color _ink = Color(0xFF171715);
  static const Color _midInk = Color(0xFF77736A);
  static const Color _lightInk = Color(0xFFC8C4B9);

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _pricesKey = GlobalKey();
  final GlobalKey _notesKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

  late final AnimationController _refreshController;

  SiteContent _content = SiteContent.demo;
  bool _qrScrollScheduled = false;

  static const List<_ContactLink> _contactLinks = [
    _ContactLink(
      labelKey: 'contact_instagram',
      detail: '@evil_space_coworking',
      url: 'https://www.instagram.com/evil_space_coworking',
    ),
    _ContactLink(
      labelKey: 'contact_map',
      detail: 'NHA TRANG',
      url: 'https://maps.app.goo.gl/5AFFB2AzszcsFvSz5?g_st=ic',
    ),
    _ContactLink(
      labelKey: 'contact_zalo',
      detail: '+84 56 5056 748',
      url: 'https://zalo.me/84565056748',
    ),
    _ContactLink(
      labelKey: 'contact_phone',
      detail: '+84 56 5056 748',
      url: 'tel:+84565056748',
    ),
    _ContactLink(
      labelKey: 'contact_messenger',
      detail: 'EVIL SPACE',
      url: 'https://m.me/61585941012998?hash=AbbCb0BDEsCMHEqJ&source_id=8585216',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    widget.localization.addListener(_handleLocalizationChanged);
    _loadContent();
    _scheduleQrScrollIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) => _triggerRefresh());
  }

  @override
  void didUpdateWidget(covariant MatrixScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localization != widget.localization) {
      oldWidget.localization.removeListener(_handleLocalizationChanged);
      widget.localization.addListener(_handleLocalizationChanged);
    }
    if (oldWidget.currentRoute != widget.currentRoute) {
      _qrScrollScheduled = false;
      _scheduleQrScrollIfNeeded();
    }
  }

  @override
  void dispose() {
    widget.localization.removeListener(_handleLocalizationChanged);
    _refreshController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleLocalizationChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
    _triggerRefresh();
  }

  void _triggerRefresh() {
    if (!mounted) {
      return;
    }
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reducedMotion) {
      return;
    }
    _refreshController.forward(from: 0);
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
          : const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _launchExternal(String urlString) async {
    final launched = await launchUrl(
      Uri.parse(urlString),
      mode: LaunchMode.platformDefault,
    );
    if (!launched) {
      debugPrint('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _PaperTexturePainter()),
            ),
          ),
          LayoutBuilder(
            builder: (context, viewport) {
              final isPhone = viewport.maxWidth < 680;
              final horizontalPadding = isPhone ? 20.0 : 38.0;
              final verticalPadding = isPhone ? 18.0 : 28.0;

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
                      isPhone ? 44 : 72,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 920),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(isPhone),
                            SizedBox(height: isPhone ? 52 : 78),
                            _buildHero(isPhone),
                            SizedBox(height: isPhone ? 72 : 108),
                            _buildWorkHere(isPhone),
                            SizedBox(height: isPhone ? 72 : 108),
                            KeyedSubtree(
                              key: _pricesKey,
                              child: _buildPrices(isPhone),
                            ),
                            SizedBox(height: isPhone ? 72 : 108),
                            KeyedSubtree(
                              key: _notesKey,
                              child: _buildNotes(isPhone),
                            ),
                            SizedBox(height: isPhone ? 72 : 108),
                            KeyedSubtree(
                              key: _contactKey,
                              child: _buildVisit(isPhone),
                            ),
                            SizedBox(height: isPhone ? 56 : 86),
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
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _refreshController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _EInkRefreshPainter(
                      progress: _refreshController.value,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isPhone) {
    final meta = Text(
      '${_publicationDate()}   /   ISSUE ${_issueNumber().toString().padLeft(3, '0')}',
      style: _monoStyle(
        fontSize: 10.5,
        weight: FontWeight.w700,
        letterSpacing: 0.9,
        color: _midInk,
      ),
    );

    final languages = Wrap(
      spacing: 5,
      runSpacing: 5,
      children: AppLanguage.values.map((language) {
        return _DailyAction(
          label: language.code.toUpperCase(),
          selected: widget.localization.language == language,
          onTap: () => widget.localization.setLanguage(language),
        );
      }).toList(),
    );

    final navigation = Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        _DailyAction(
          label: widget.localization.t('nav_prices'),
          onTap: () => _scrollTo(_pricesKey),
        ),
        _DailyAction(
          label: widget.localization.t('nav_notes'),
          onTap: () => _scrollTo(_notesKey),
        ),
        _DailyAction(
          label: widget.localization.t('nav_visit'),
          onTap: () => _scrollTo(_contactKey),
        ),
      ],
    );

    final brand = _DailyAction(
      label: widget.localization.t('brand_daily'),
      strong: true,
      onTap: _scrollHome,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isPhone) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: brand),
              const SizedBox(width: 12),
              languages,
            ],
          ),
          const SizedBox(height: 12),
          meta,
          const SizedBox(height: 15),
          navigation,
        ] else ...[
          Row(
            children: [
              brand,
              const SizedBox(width: 28),
              Expanded(child: meta),
              navigation,
              const SizedBox(width: 16),
              languages,
            ],
          ),
        ],
        const SizedBox(height: 17),
        const _Hairline(),
      ],
    );
  }

  Widget _buildHero(bool isPhone) {
    final status = _content.status;
    final dayPass = _priceFor('price_day_pass');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.localization.t('hero_kicker'),
          style: _monoStyle(
            fontSize: 12,
            weight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: isPhone ? 18 : 24),
        Text(
          '${status.free}',
          style: _serifStyle(
            fontSize: isPhone ? 92 : 142,
            weight: FontWeight.w700,
            height: 0.78,
            letterSpacing: -4,
          ),
        ),
        SizedBox(height: isPhone ? 14 : 20),
        Text(
          widget.localization.t(
            status.free == 1 ? 'desk_free' : 'desks_free',
          ),
          style: _serifStyle(
            fontSize: isPhone ? 32 : 48,
            weight: FontWeight.w700,
            height: 0.95,
          ),
        ),
        SizedBox(height: isPhone ? 28 : 38),
        const _Hairline(),
        SizedBox(height: isPhone ? 18 : 22),
        if (isPhone)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOccupancy(status),
              const SizedBox(height: 22),
              _buildHeroPrice(dayPass),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(flex: 3, child: _buildOccupancy(status)),
              const SizedBox(width: 36),
              Expanded(flex: 2, child: _buildHeroPrice(dayPass)),
            ],
          ),
        SizedBox(height: isPhone ? 18 : 22),
        const _Hairline(),
      ],
    );
  }

  Widget _buildOccupancy(SiteStatus status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${status.occupied} / ${status.total} ${widget.localization.t('occupied')}',
          style: _monoStyle(
            fontSize: 12,
            weight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 11),
        _OccupancyMarks(total: status.total, occupied: status.occupied),
        const SizedBox(height: 11),
        Text(
          _statusUpdatedLabel(status),
          style: _monoStyle(
            fontSize: 10.5,
            weight: FontWeight.w700,
            letterSpacing: 0.8,
            color: _midInk,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroPrice(SitePrice? dayPass) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.localization.t('day_pass_now'),
          style: _monoStyle(
            fontSize: 10.5,
            weight: FontWeight.w700,
            letterSpacing: 1.1,
            color: _midInk,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          dayPass?.price ?? '250K',
          style: _serifStyle(
            fontSize: 38,
            weight: FontWeight.w700,
            height: 1,
          ),
        ),
        const SizedBox(height: 12),
        _InlineLink(
          label: widget.localization.t('message_zalo'),
          onTap: () => _launchExternal('https://zalo.me/84565056748'),
        ),
      ],
    );
  }

  Widget _buildWorkHere(bool isPhone) {
    final features = [
      ('01', widget.localization.t('feature_big_desks')),
      ('02', widget.localization.t('feature_good_chairs')),
      ('03', widget.localization.t('feature_fast_wifi')),
      ('04', widget.localization.t('feature_cold_ac')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(widget.localization.t('work_title'), isPhone),
        const SizedBox(height: 9),
        Text(
          widget.localization.t('work_intro'),
          style: _serifStyle(
            fontSize: isPhone ? 19 : 23,
            height: 1.25,
            color: _midInk,
          ),
        ),
        SizedBox(height: isPhone ? 24 : 30),
        const _Hairline(),
        if (isPhone)
          for (final feature in features) ...[
            _FeatureRow(number: feature.$1, label: feature.$2),
            const _Hairline(light: true),
          ]
        else
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _FeatureRow(
                      number: features[0].$1,
                      label: features[0].$2,
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: _FeatureRow(
                      number: features[1].$1,
                      label: features[1].$2,
                    ),
                  ),
                ],
              ),
              const _Hairline(light: true),
              Row(
                children: [
                  Expanded(
                    child: _FeatureRow(
                      number: features[2].$1,
                      label: features[2].$2,
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    child: _FeatureRow(
                      number: features[3].$1,
                      label: features[3].$2,
                    ),
                  ),
                ],
              ),
              const _Hairline(light: true),
            ],
          ),
      ],
    );
  }

  Widget _buildPrices(bool isPhone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _sectionHeading(
                widget.localization.t('prices_title'),
                isPhone,
              ),
            ),
            Text(
              'VND',
              style: _monoStyle(
                fontSize: 11,
                weight: FontWeight.w700,
                letterSpacing: 1.2,
                color: _midInk,
              ),
            ),
          ],
        ),
        SizedBox(height: isPhone ? 20 : 26),
        const _Hairline(),
        for (final price in _content.prices) ...[
          Padding(
            padding: EdgeInsets.symmetric(vertical: isPhone ? 15 : 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    widget.localization.t(price.labelKey),
                    style: _serifStyle(
                      fontSize: isPhone ? 20 : 23,
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
          const _Hairline(light: true),
        ],
      ],
    );
  }

  Widget _buildNotes(bool isPhone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(widget.localization.t('notes_title'), isPhone),
        const SizedBox(height: 9),
        Text(
          widget.localization.t('notes_intro'),
          style: _serifStyle(
            fontSize: isPhone ? 18 : 21,
            color: _midInk,
          ),
        ),
        SizedBox(height: isPhone ? 20 : 26),
        const _Hairline(),
        for (final announcement in _content.announcements.take(3)) ...[
          Padding(
            padding: EdgeInsets.symmetric(vertical: isPhone ? 20 : 25),
            child: isPhone
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NoteDate(announcement.date),
                      const SizedBox(height: 9),
                      _NoteText(
                        announcement.textFor(
                          widget.localization.language.code,
                        ),
                        isPhone: true,
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 108,
                        child: _NoteDate(announcement.date),
                      ),
                      Expanded(
                        child: _NoteText(
                          announcement.textFor(
                            widget.localization.language.code,
                          ),
                          isPhone: false,
                        ),
                      ),
                    ],
                  ),
          ),
          const _Hairline(light: true),
        ],
      ],
    );
  }

  Widget _buildVisit(bool isPhone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(widget.localization.t('visit_title'), isPhone),
        const SizedBox(height: 10),
        Text(
          widget.localization.t('visit_copy'),
          style: _serifStyle(
            fontSize: isPhone ? 22 : 27,
            weight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.localization.t('contact_location'),
          style: _monoStyle(
            fontSize: 11,
            weight: FontWeight.w700,
            letterSpacing: 1.1,
            color: _midInk,
          ),
        ),
        SizedBox(height: isPhone ? 24 : 30),
        const _Hairline(),
        for (final link in _contactLinks) ...[
          _ContactRow(
            label: widget.localization.t(link.labelKey),
            detail: link.detail,
            onTap: () => _launchExternal(link.url),
          ),
          const _Hairline(light: true),
        ],
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Hairline(),
        const SizedBox(height: 14),
        Text(
          'EVIL SPACE  ·  NHA TRANG  ·  ${widget.localization.t('page_one')}',
          textAlign: TextAlign.center,
          style: _monoStyle(
            fontSize: 10,
            weight: FontWeight.w700,
            letterSpacing: 1.0,
            color: _midInk,
          ),
        ),
      ],
    );
  }

  Widget _sectionHeading(String text, bool isPhone) {
    return Text(
      text,
      style: _serifStyle(
        fontSize: isPhone ? 35 : 48,
        weight: FontWeight.w700,
        height: 0.98,
      ),
    );
  }

  SitePrice? _priceFor(String labelKey) {
    for (final price in _content.prices) {
      if (price.labelKey == labelKey) {
        return price;
      }
    }
    return null;
  }

  String _publicationDate() {
    final now = DateTime.now();
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${weekdays[now.weekday - 1]} / ${now.day.toString().padLeft(2, '0')} ${months[now.month - 1]} ${now.year}';
  }

  int _issueNumber() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, 1, 1);
    return now.difference(firstDay).inDays + 1;
  }

  String _statusUpdatedLabel(SiteStatus status) {
    final parsed = DateTime.tryParse(status.updated);
    if (parsed == null) {
      return widget.localization.t('local_data');
    }

    final now = DateTime.now();
    final sameDay = parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day;
    if (sameDay) {
      return widget.localization.t('updated_today');
    }

    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${widget.localization.t('updated')} ${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]}';
  }

  TextStyle _serifStyle({
    required double fontSize,
    FontWeight weight = FontWeight.w400,
    double? height,
    double? letterSpacing,
    Color color = _ink,
  }) {
    return TextStyle(
      fontFamily: 'Georgia',
      fontFamilyFallback: const ['Times New Roman', 'serif'],
      fontSize: fontSize,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  TextStyle _monoStyle({
    required double fontSize,
    FontWeight weight = FontWeight.w400,
    double? height,
    double? letterSpacing,
    Color color = _ink,
  }) {
    return TextStyle(
      fontFamily: 'Courier New',
      fontFamilyFallback: const ['Courier', 'monospace'],
      fontSize: fontSize,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 38,
            child: Text(
              number,
              style: const TextStyle(
                fontFamily: 'Courier New',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Color(0xFF77736A),
              ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF171715),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteDate extends StatelessWidget {
  const _NoteDate(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: const TextStyle(
        fontFamily: 'Courier New',
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
        color: Color(0xFF77736A),
      ),
    );
  }
}

class _NoteText extends StatelessWidget {
  const _NoteText(this.value, {required this.isPhone});

  final String value;
  final bool isPhone;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: TextStyle(
        fontFamily: 'Georgia',
        fontSize: isPhone ? 24 : 29,
        fontWeight: FontWeight.w600,
        height: 1.16,
        color: const Color(0xFF171715),
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
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: List.generate(total, (index) {
        final filled = index < occupied;
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: filled ? const Color(0xFF171715) : Colors.transparent,
            border: Border.all(color: const Color(0xFF171715), width: 1.2),
          ),
        );
      }),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label $detail',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF171715),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Text(
                    detail,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontFamily: 'Courier New',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: Color(0xFF77736A),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  '→',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineLink extends StatelessWidget {
  const _InlineLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Text(
            '$label →',
            style: const TextStyle(
              fontFamily: 'Courier New',
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              decoration: TextDecoration.underline,
              decorationThickness: 1.2,
              color: Color(0xFF171715),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyAction extends StatelessWidget {
  const _DailyAction({
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
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF171715) : Colors.transparent,
              border: Border.all(
                color: strong ? const Color(0xFF171715) : Colors.transparent,
                width: 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Courier New',
                fontSize: strong ? 12 : 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: strong ? 1.1 : 0.55,
                color: selected
                    ? const Color(0xFFF2F0E8)
                    : const Color(0xFF171715),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline({this.light = false});

  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: light ? 0.7 : 1.2,
      color: light ? const Color(0xFFC8C4B9) : const Color(0xFF171715),
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

class _PaperTexturePainter extends CustomPainter {
  const _PaperTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()..color = const Color(0x08171715);
    final dotPaint = Paint()..color = const Color(0x0A171715);

    for (double y = 11; y < size.height; y += 31) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    for (double y = 17; y < size.height; y += 47) {
      for (double x = 13 + ((y.toInt() % 3) * 7); x < size.width; x += 61) {
        canvas.drawRect(Rect.fromLTWH(x, y, 0.8, 0.8), dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PaperTexturePainter oldDelegate) => false;
}

class _EInkRefreshPainter extends CustomPainter {
  const _EInkRefreshPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 0.999) {
      return;
    }

    final flash = progress < 0.42
        ? progress / 0.42
        : (1 - progress) / 0.58;
    final flashAlpha = (flash.clamp(0.0, 1.0) * 24).round();
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color.fromARGB(flashAlpha, 23, 23, 21),
    );

    final front = size.height * progress;
    final bandHeight = (size.height * 0.035).clamp(14.0, 42.0);
    canvas.drawRect(
      Rect.fromLTWH(0, front - bandHeight, size.width, bandHeight),
      Paint()..color = const Color.fromARGB(20, 119, 115, 106),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, front - 1, size.width, 2),
      Paint()..color = const Color.fromARGB(28, 23, 23, 21),
    );
  }

  @override
  bool shouldRepaint(covariant _EInkRefreshPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
