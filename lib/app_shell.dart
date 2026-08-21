import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:evil_space/app_route.dart';
import 'package:evil_space/brand_logo.dart';
import 'package:evil_space/brand_surface.dart';
import 'package:evil_space/coworking_model.dart';
import 'package:evil_space/localization.dart';

typedef AppRouteCallback = void Function(AppRoute route);

class DailyScreen extends StatefulWidget {
  const DailyScreen({
    super.key,
    required this.currentRoute,
    required this.localization,
    required this.onNavigate,
  });

  final AppRoute currentRoute;
  final LocalizationController localization;
  final AppRouteCallback onNavigate;

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _pricesKey = GlobalKey();
  final GlobalKey _notesKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

  late final AnimationController _refreshController;
  SiteContent _content = SiteContent.demo;
  bool _qrScrollScheduled = false;

  static const _contacts = <_ContactLink>[
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
      duration: const Duration(milliseconds: 360),
    );
    widget.localization.addListener(_handleLocalizationChanged);
    _loadContent();
    _scheduleQrScrollIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) => _triggerRefresh());
  }

  @override
  void didUpdateWidget(covariant DailyScreen oldWidget) {
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

  Future<void> _loadContent() async {
    final content = await SiteContentRepository.load(rootBundle);
    if (mounted) {
      setState(() => _content = content);
    }
  }

  void _handleLocalizationChanged() {
    if (!mounted) return;
    setState(() {});
    _triggerRefresh();
  }

  void _triggerRefresh() {
    if (!mounted) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    _refreshController.forward(from: 0);
  }

  void _scheduleQrScrollIfNeeded() {
    if (widget.currentRoute != AppRoute.qr || _qrScrollScheduled) return;
    _qrScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollTo(_contactKey);
    });
  }

  Future<void> _scrollTo(GlobalKey key) async {
    final target = key.currentContext;
    if (target == null) return;
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    await Scrollable.ensureVisible(
      target,
      duration: reduced ? Duration.zero : const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.025,
    );
  }

  Future<void> _scrollHome() async {
    widget.onNavigate(AppRoute.home);
    if (!_scrollController.hasClients) return;
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    await _scrollController.animateTo(
      0,
      duration: reduced ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _launch(String value) async {
    final ok = await launchUrl(
      Uri.parse(value),
      mode: LaunchMode.platformDefault,
    );
    if (!ok) debugPrint('Could not launch $value');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandPalette.brown,
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, viewport) {
              final phone = viewport.maxWidth < 720;
              return Scrollbar(
                controller: _scrollController,
                thumbVisibility: !phone,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: kIsWeb
                      ? const ClampingScrollPhysics()
                      : const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                  child: BrandPaper(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: viewport.maxHeight),
                      child: SafeArea(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 980),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                phone ? 20 : 42,
                                phone ? 18 : 30,
                                phone ? 20 : 42,
                                phone ? 48 : 78,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _header(phone),
                                  SizedBox(height: phone ? 44 : 68),
                                  _hero(phone),
                                  SizedBox(height: phone ? 72 : 104),
                                  _work(phone),
                                  SizedBox(height: phone ? 72 : 104),
                                  KeyedSubtree(
                                    key: _pricesKey,
                                    child: _prices(phone),
                                  ),
                                  SizedBox(height: phone ? 72 : 104),
                                  KeyedSubtree(
                                    key: _notesKey,
                                    child: _notes(phone),
                                  ),
                                  SizedBox(height: phone ? 72 : 104),
                                  KeyedSubtree(
                                    key: _contactKey,
                                    child: _visit(phone),
                                  ),
                                  SizedBox(height: phone ? 66 : 98),
                                  _footer(phone),
                                ],
                              ),
                            ),
                          ),
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
                builder: (context, _) => CustomPaint(
                  painter: _EInkRefreshPainter(
                    progress: _refreshController.value,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(bool phone) {
    final meta = Text(
      '${_publicationDate()}   /   ISSUE ${_issueNumber().toString().padLeft(3, '0')}',
      style: _mono(10.5, color: BrandPalette.creamMuted, spacing: 0.9),
    );
    final languages = Wrap(
      spacing: 5,
      runSpacing: 5,
      children: AppLanguage.values
          .map(
            (language) => _DailyAction(
              label: language.code.toUpperCase(),
              selected: widget.localization.language == language,
              onTap: () => widget.localization.setLanguage(language),
            ),
          )
          .toList(),
    );
    final nav = Wrap(
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
        if (phone) ...[
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
          nav,
        ] else
          Row(
            children: [
              brand,
              const SizedBox(width: 28),
              Expanded(child: meta),
              nav,
              const SizedBox(width: 16),
              languages,
            ],
          ),
        const SizedBox(height: 18),
        const _Hairline(),
      ],
    );
  }

  Widget _hero(bool phone) {
    final status = _content.status;
    final dayPass = _priceFor('price_day_pass')?.price ?? '250K';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.localization.t('hero_kicker'),
          style: _mono(11.5, color: BrandPalette.creamMuted, spacing: 1.45),
        ),
        SizedBox(height: phone ? 24 : 30),
        Semantics(
          image: true,
          label: 'Evil Coworking',
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: phone ? 1.0 : 0.74,
              child: const EvilCoworkingLogo(),
            ),
          ),
        ),
        SizedBox(height: phone ? 34 : 48),
        _statusTicket(status, dayPass, phone),
      ],
    );
  }

  Widget _statusTicket(SiteStatus status, String dayPass, bool phone) {
    final primary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LIVE / ${widget.localization.t('local_data')}',
          style: _mono(10, color: BrandPalette.brown, spacing: 1),
        ),
        const SizedBox(height: 10),
        Text(
          '${status.free}',
          style: _serif(
            phone ? 88 : 118,
            color: BrandPalette.brown,
            weight: FontWeight.w700,
            height: 0.78,
            spacing: -4,
          ),
        ),
        SizedBox(height: phone ? 14 : 18),
        Text(
          widget.localization.t(status.free == 1 ? 'desk_free' : 'desks_free'),
          style: _serif(
            phone ? 29 : 42,
            color: BrandPalette.brown,
            weight: FontWeight.w700,
            height: 0.94,
          ),
        ),
      ],
    );

    final detail = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${status.occupied} / ${status.total} ${widget.localization.t('occupied')}',
          style: _mono(11.5, color: BrandPalette.brown, spacing: 0.45),
        ),
        const SizedBox(height: 12),
        _OccupancyMarks(total: status.total, occupied: status.occupied),
        const SizedBox(height: 12),
        Text(
          _statusUpdatedLabel(status),
          style: _mono(10, color: BrandPalette.creamFaint, spacing: 0.7),
        ),
        SizedBox(height: phone ? 22 : 28),
        Container(height: 1, color: const Color(0x66352822)),
        SizedBox(height: phone ? 18 : 22),
        Text(
          widget.localization.t('day_pass_now'),
          style: _mono(10, color: BrandPalette.creamFaint, spacing: 1),
        ),
        const SizedBox(height: 4),
        Text(
          dayPass,
          style: _serif(
            35,
            color: BrandPalette.brown,
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 11),
        _InlineLink(
          label: widget.localization.t('message_zalo'),
          onTap: () => _launch('https://zalo.me/84565056748'),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(phone ? 22 : 30),
      decoration: const BoxDecoration(
        color: BrandPalette.cream,
        boxShadow: [
          BoxShadow(
            color: Color(0x66201915),
            offset: Offset(5, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: phone
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [primary, const SizedBox(height: 26), detail],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(flex: 5, child: primary),
                const SizedBox(width: 54),
                Expanded(flex: 3, child: detail),
              ],
            ),
    );
  }

  Widget _work(bool phone) {
    final features = <(String, String)>[
      ('01', widget.localization.t('feature_big_desks')),
      ('02', widget.localization.t('feature_good_chairs')),
      ('03', widget.localization.t('feature_fast_wifi')),
      ('04', widget.localization.t('feature_cold_ac')),
    ];
    final tiles = features
        .map((item) => _FeatureTile(number: item.$1, label: item.$2))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(widget.localization.t('work_title'), phone),
        const SizedBox(height: 10),
        Text(
          widget.localization.t('work_intro'),
          style: _serif(phone ? 18 : 22,
              color: BrandPalette.creamMuted, height: 1.28),
        ),
        SizedBox(height: phone ? 24 : 30),
        if (phone)
          for (final tile in tiles) ...[
            tile,
            const SizedBox(height: 10),
          ]
        else ...[
          Row(children: [Expanded(child: tiles[0]), const SizedBox(width: 12), Expanded(child: tiles[1])]),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: tiles[2]), const SizedBox(width: 12), Expanded(child: tiles[3])]),
        ],
      ],
    );
  }

  Widget _prices(bool phone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: _sectionTitle(widget.localization.t('prices_title'), phone)),
            Text('VND', style: _mono(11, color: BrandPalette.creamMuted, spacing: 1.2)),
          ],
        ),
        SizedBox(height: phone ? 20 : 26),
        const _Hairline(),
        for (final price in _content.prices) ...[
          Padding(
            padding: EdgeInsets.symmetric(vertical: phone ? 15 : 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    widget.localization.t(price.labelKey),
                    style: _serif(phone ? 20 : 23, weight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  color: BrandPalette.cream,
                  child: Text(
                    price.price,
                    style: _mono(phone ? 15.5 : 17, color: BrandPalette.brown),
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

  Widget _notes(bool phone) {
    final notes = _content.announcements.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(widget.localization.t('notes_title'), phone),
        const SizedBox(height: 9),
        Text(
          widget.localization.t('notes_intro'),
          style: _serif(phone ? 18 : 21,
              color: BrandPalette.creamMuted, height: 1.25),
        ),
        SizedBox(height: phone ? 22 : 28),
        for (var i = 0; i < notes.length; i++) ...[
          _NoteCard(
            date: notes[i].date,
            text: notes[i].textFor(widget.localization.language.code),
            filled: i == 0,
            phone: phone,
          ),
          if (i != notes.length - 1) SizedBox(height: phone ? 12 : 14),
        ],
      ],
    );
  }

  Widget _visit(bool phone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(widget.localization.t('visit_title'), phone),
        const SizedBox(height: 10),
        Text(
          widget.localization.t('visit_copy'),
          style: _serif(phone ? 21 : 26, weight: FontWeight.w600, height: 1.22),
        ),
        const SizedBox(height: 8),
        Text(
          widget.localization.t('contact_location'),
          style: _mono(11, color: BrandPalette.creamMuted, spacing: 1.1),
        ),
        SizedBox(height: phone ? 24 : 30),
        const _Hairline(),
        for (final link in _contacts) ...[
          _ContactRow(
            label: widget.localization.t(link.labelKey),
            detail: link.detail,
            onTap: () => _launch(link.url),
          ),
          const _Hairline(light: true),
        ],
      ],
    );
  }

  Widget _footer(bool phone) {
    return Column(
      children: [
        const _Hairline(),
        SizedBox(height: phone ? 32 : 40),
        Opacity(
          opacity: 0.18,
          child: EvilCoworkingLogo(width: phone ? 190 : 250),
        ),
        const SizedBox(height: 20),
        Text(
          'EVIL SPACE  ·  NHA TRANG  ·  ${widget.localization.t('page_one')}',
          textAlign: TextAlign.center,
          style: _mono(10, color: BrandPalette.creamMuted, spacing: 1),
        ),
      ],
    );
  }

  Widget _sectionTitle(String value, bool phone) => Text(
        value,
        style: _serif(phone ? 35 : 48, weight: FontWeight.w700, height: 0.98),
      );

  SitePrice? _priceFor(String key) {
    for (final price in _content.prices) {
      if (price.labelKey == key) return price;
    }
    return null;
  }

  TextStyle _serif(
    double size, {
    Color color = BrandPalette.cream,
    FontWeight weight = FontWeight.w400,
    double? height,
    double? spacing,
  }) =>
      TextStyle(
        fontFamily: 'Georgia',
        fontFamilyFallback: const ['Times New Roman', 'serif'],
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: spacing,
        color: color,
      );

  TextStyle _mono(
    double size, {
    Color color = BrandPalette.cream,
    FontWeight weight = FontWeight.w700,
    double? height,
    double? spacing,
  }) =>
      TextStyle(
        fontFamily: 'Courier New',
        fontFamilyFallback: const ['Courier', 'monospace'],
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: spacing,
        color: color,
      );

  String _publicationDate() {
    final now = DateTime.now();
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return '${weekdays[now.weekday - 1]} / ${now.day.toString().padLeft(2, '0')} ${months[now.month - 1]} ${now.year}';
  }

  int _issueNumber() {
    final now = DateTime.now();
    return now.difference(DateTime(now.year, 1, 1)).inDays + 1;
  }

  String _statusUpdatedLabel(SiteStatus status) {
    final parsed = DateTime.tryParse(status.updated);
    if (parsed == null) return widget.localization.t('local_data');
    final now = DateTime.now();
    if (parsed.year == now.year && parsed.month == now.month && parsed.day == now.day) {
      return widget.localization.t('updated_today');
    }
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return '${widget.localization.t('updated')} ${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]}';
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.number, required this.label});
  final String number;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 104),
        padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x6680685A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(number, style: _monoText(10, BrandPalette.creamMuted, 0.9)),
            const SizedBox(height: 14),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1,
                color: BrandPalette.cream,
              ),
            ),
          ],
        ),
      );
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.date,
    required this.text,
    required this.filled,
    required this.phone,
  });
  final String date;
  final String text;
  final bool filled;
  final bool phone;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? BrandPalette.brown : BrandPalette.cream;
    final secondary = filled ? BrandPalette.creamFaint : BrandPalette.creamMuted;
    final dateText = Text(date, style: _monoText(10.5, secondary, 0.9));
    final bodyText = Text(
      text,
      style: TextStyle(
        fontFamily: 'Georgia',
        fontSize: phone ? 24 : 28,
        fontWeight: FontWeight.w600,
        height: 1.14,
        color: foreground,
      ),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(phone ? 19 : 24),
      decoration: BoxDecoration(
        color: filled ? BrandPalette.cream : Colors.transparent,
        border: Border.all(
          color: filled ? BrandPalette.cream : const Color(0x6680685A),
        ),
      ),
      child: phone
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [dateText, const SizedBox(height: 10), bodyText],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 106, child: dateText),
                Expanded(child: bodyText),
              ],
            ),
    );
  }
}

class _OccupancyMarks extends StatelessWidget {
  const _OccupancyMarks({required this.total, required this.occupied});
  final int total;
  final int occupied;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 5,
        runSpacing: 5,
        children: List.generate(total, (index) {
          final filled = index < occupied;
          return Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              color: filled ? BrandPalette.brown : Colors.transparent,
              border: Border.all(color: BrandPalette.brown, width: 1.2),
            ),
          );
        }),
      );
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.label, required this.detail, required this.onTap});
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
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
                        color: BrandPalette.cream,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Text(
                      detail,
                      textAlign: TextAlign.right,
                      style: _monoText(11, BrandPalette.creamMuted, 0.6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('→', style: TextStyle(fontSize: 19, color: BrandPalette.cream)),
                ],
              ),
            ),
          ),
        ),
      );
}

class _InlineLink extends StatelessWidget {
  const _InlineLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
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
                decoration: TextDecoration.underline,
                decorationColor: BrandPalette.brown,
                color: BrandPalette.brown,
              ),
            ),
          ),
        ),
      );
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
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? BrandPalette.cream : Colors.transparent,
                border: Border.all(
                  color: strong || selected ? BrandPalette.cream : Colors.transparent,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Courier New',
                  fontSize: strong ? 12 : 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: strong ? 1.05 : 0.55,
                  color: selected ? BrandPalette.brown : BrandPalette.cream,
                ),
              ),
            ),
          ),
        ),
      );
}

class _Hairline extends StatelessWidget {
  const _Hairline({this.light = false});
  final bool light;

  @override
  Widget build(BuildContext context) => Container(
        height: light ? 0.7 : 1.1,
        color: light ? const Color(0x6680685A) : BrandPalette.cream,
      );
}

class _ContactLink {
  const _ContactLink({required this.labelKey, required this.detail, required this.url});
  final String labelKey;
  final String detail;
  final String url;
}

TextStyle _monoText(double size, Color color, double spacing) => TextStyle(
      fontFamily: 'Courier New',
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: spacing,
      color: color,
    );

class _EInkRefreshPainter extends CustomPainter {
  const _EInkRefreshPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 0.999) return;
    final flash = progress < 0.4 ? progress / 0.4 : (1 - progress) / 0.6;
    final alpha = (flash.clamp(0.0, 1.0) * 24).round();
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color.fromARGB(alpha, 231, 210, 192),
    );
    final front = size.height * progress;
    final band = (size.height * 0.035).clamp(14.0, 40.0);
    canvas.drawRect(
      Rect.fromLTWH(0, front - band, size.width, band),
      Paint()..color = const Color.fromARGB(18, 231, 210, 192),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, front - 1, size.width, 2),
      Paint()..color = const Color.fromARGB(32, 43, 31, 26),
    );
  }

  @override
  bool shouldRepaint(covariant _EInkRefreshPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
