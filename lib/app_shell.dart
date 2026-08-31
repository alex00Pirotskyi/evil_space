import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:evil_space/app_route.dart';
import 'package:evil_space/brand_logo.dart';
import 'package:evil_space/brand_surface.dart';
import 'package:evil_space/coworking_model.dart';
import 'package:evil_space/localization.dart';
import 'package:evil_space/public_desk.dart';

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
  static const _instagramUrl = 'https://www.instagram.com/evil_space_coworking';
  static const _mapsUrl = 'https://maps.app.goo.gl/5AFFB2AzszcsFvSz5?g_st=ic';
  static const _directionsUrl =
      'https://www.google.com/maps/dir/?api=1&destination=evil%20space%2C%2060%20Cao%20V%C4%83n%20B%C3%A9%2C%20B%E1%BA%AFc%20Nha%20Trang%2C%20Kh%C3%A1nh%20H%C3%B2a%20650000';
  static const _zaloUrl = 'https://zalo.me/84565056748';
  static const _telegramUrl = 'https://t.me/your_evil_space';
  static const _phoneUrl = 'tel:+84565056748';
  static const _bookingBotBaseUrl =
      'https://t.me/CoworkingEvilAdminBot?start=book_';

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _visitKey = GlobalKey();
  final PublicDeskApi _deskApi = PublicDeskApi();

  late final AnimationController _refreshController;
  Timer? _statusTimer;
  SiteContent _content = SiteContent.demo;
  SiteStatus? _liveStatus;
  List<DeskBookingState> _bookings = const [];
  bool _bookingBusy = false;
  bool _qrScrollScheduled = false;
  bool _publicRefreshInFlight = false;
  bool _publicRefreshQueued = false;

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    widget.localization.addListener(_handleLocalizationChanged);
    _bookings = _deskApi.savedBookings();
    unawaited(_loadContent());
    unawaited(_loadPublicState());
    _statusTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_loadPublicState()),
    );
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
    _statusTimer?.cancel();
    _refreshController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    final content = await SiteContentRepository.load(rootBundle);
    if (!mounted) return;
    setState(() => _content = content);
  }

  Future<void> _loadPublicState() async {
    if (_publicRefreshInFlight) {
      _publicRefreshQueued = true;
      return;
    }

    _publicRefreshInFlight = true;
    final currentBookings = List<DeskBookingState>.from(_bookings);
    try {
      final statusFuture = _deskApi.status().timeout(
        const Duration(seconds: 8),
        onTimeout: () => null,
      );
      final bookingsFuture = Future.wait(currentBookings.map(_refreshBooking));
      final results = await Future.wait<Object?>([
        statusFuture,
        bookingsFuture,
      ]);
      if (!mounted) return;

      final status = results[0] as SiteStatus?;
      final refreshedBookings = (results[1] as List<DeskBookingState?>)
          .whereType<DeskBookingState>()
          .toList(growable: false);
      final statusChanged = status != null && !_sameStatus(_liveStatus, status);
      final bookingContextUnchanged = _sameBookings(_bookings, currentBookings);
      final bookingChanged =
          bookingContextUnchanged &&
          !_sameBookings(_bookings, refreshedBookings);

      if (!statusChanged && !bookingChanged) return;
      setState(() {
        if (statusChanged) _liveStatus = status;
        if (bookingChanged) _bookings = refreshedBookings;
      });
    } finally {
      _publicRefreshInFlight = false;
      if (_publicRefreshQueued && mounted) {
        _publicRefreshQueued = false;
        unawaited(_loadPublicState());
      }
    }
  }

  Future<DeskBookingState?> _refreshBooking(DeskBookingState booking) async {
    try {
      return await _deskApi
          .bookingStatus(booking)
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      return booking;
    } on PublicDeskException {
      return booking;
    }
  }

  bool _sameStatus(SiteStatus? a, SiteStatus? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.total == b.total &&
        a.occupied == b.occupied &&
        a.tomorrowOccupied == b.tomorrowOccupied &&
        a.todayPrice == b.todayPrice &&
        a.tomorrowPrice == b.tomorrowPrice &&
        a.todayDate == b.todayDate &&
        a.tomorrowDate == b.tomorrowDate &&
        _statusDayKey(a.updated) == _statusDayKey(b.updated);
  }

  String _statusDayKey(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toUtc().add(const Duration(hours: 7));
    return '${local.year}-${local.month}-${local.day}';
  }

  bool _sameBookings(List<DeskBookingState> a, List<DeskBookingState> b) {
    if (a.length != b.length) return false;
    final left = [...a]..sort((x, y) => x.serviceDate.compareTo(y.serviceDate));
    final right = [...b]
      ..sort((x, y) => x.serviceDate.compareTo(y.serviceDate));
    for (var index = 0; index < left.length; index += 1) {
      final x = left[index];
      final y = right[index];
      if (x.token != y.token ||
          x.status != y.status ||
          x.serviceDate != y.serviceDate ||
          x.amountVnd != y.amountVnd ||
          x.telegramLinkUrl != y.telegramLinkUrl ||
          x.telegramLinked != y.telegramLinked) {
        return false;
      }
    }
    return true;
  }

  DeskBookingState? _bookingFor(String serviceDate) {
    for (final booking in _bookings) {
      if (booking.serviceDate == serviceDate) return booking;
    }
    return null;
  }

  String _serviceDateForOffset(int days) {
    final local = _nhaTrangNow().add(Duration(days: days));
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  String _compactServiceDate(String serviceDate) =>
      serviceDate.replaceAll('-', '');

  Future<void> _launchTelegramBooking(String serviceDate) async {
    final url =
        '$_bookingBotBaseUrl${_compactServiceDate(serviceDate)}_${widget.localization.language.code}';
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: defaultTargetPlatform == TargetPlatform.iOS
            ? '_self'
            : '_blank',
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('COULD NOT OPEN TELEGRAM')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('COULD NOT OPEN TELEGRAM')));
    }
  }

  Future<void> _requestDesk(String serviceDate) async {
    if (_bookingBusy || _bookingFor(serviceDate) != null) return;

    final profile = await showDialog<DeskBookingProfile>(
      context: context,
      builder: (_) => _DeskBookingDialog(
        localization: widget.localization,
        serviceDate: serviceDate,
        isTomorrow: serviceDate == _serviceDateForOffset(1),
        onTelegram: () => unawaited(_launchTelegramBooking(serviceDate)),
      ),
    );
    if (!mounted || profile == null) return;
    await _sendDeskRequest(profile);
  }

  Future<void> _sendDeskRequest(DeskBookingProfile profile) async {
    setState(() => _bookingBusy = true);
    try {
      final booking = await _deskApi
          .book(profile)
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _bookings = [
          ..._bookings.where((item) => item.serviceDate != booking.serviceDate),
          booking,
        ]..sort((a, b) => a.serviceDate.compareTo(b.serviceDate));
        _bookingBusy = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _bookingBusy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('REQUEST TIMEOUT')));
    } on PublicDeskException catch (error) {
      if (!mounted) return;
      setState(() => _bookingBusy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _bookingBusy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('COULD NOT SEND REQUEST')));
    }
  }

  Future<void> _connectBookingTelegram(DeskBookingState booking) async {
    final url = booking.telegramLinkUrl;
    if (url == null || !booking.canConnectTelegram) return;
    await _launch(url);
  }

  Future<void> _deleteDeskRequest(DeskBookingState booking) async {
    if (_bookingBusy) return;
    setState(() => _bookingBusy = true);
    try {
      await _deskApi
          .deleteBooking(booking)
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _bookings = _bookings
            .where((item) => item.serviceDate != booking.serviceDate)
            .toList(growable: false);
        _bookingBusy = false;
      });
      await _loadPublicState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.localization.t('booking_deleted'))),
      );
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _bookingBusy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('REQUEST TIMEOUT')));
    } on PublicDeskException catch (error) {
      if (!mounted) return;
      setState(() => _bookingBusy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _clearFinishedBooking(DeskBookingState booking) {
    _deskApi.clearSavedBooking(booking.serviceDate);
    setState(() {
      _bookings = _bookings
          .where((item) => item.serviceDate != booking.serviceDate)
          .toList(growable: false);
    });
  }

  void _handleLocalizationChanged() {
    if (!mounted) return;
    setState(() {});
    _triggerRefresh();
  }

  void _triggerRefresh() {
    if (!mounted || (MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      return;
    }
    _refreshController.forward(from: 0);
  }

  void _scheduleQrScrollIfNeeded() {
    if (widget.currentRoute != AppRoute.qr || _qrScrollScheduled) return;
    _qrScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final target = _visitKey.currentContext;
      if (target != null) {
        await Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _launch(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.platformDefault)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('COULD NOT OPEN THIS LINK')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandPalette.paper,
      body: BrandPaper(
        child: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                child: Scrollbar(
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 32),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 620;
                        final gutter = compact ? 20.0 : 40.0;
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: SelectionArea(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  gutter,
                                  compact ? 20 : 32,
                                  gutter,
                                  16,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _header(compact),
                                    const SizedBox(height: 44),
                                    _availability(compact),
                                    const SizedBox(height: 50),
                                    _prices(compact),
                                    const SizedBox(height: 50),
                                    _openings(compact),
                                    const SizedBox(height: 50),
                                    _note(compact),
                                    const SizedBox(height: 50),
                                    KeyedSubtree(
                                      key: _visitKey,
                                      child: _visit(compact),
                                    ),
                                    const SizedBox(height: 50),
                                    _footer(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _refreshController,
                  builder: (context, _) => CustomPaint(
                    painter: _EInkRefreshPainter(_refreshController.value),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(bool compact) {
    final now = _nhaTrangNow();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          children: [
            Text(
              '${widget.localization.t('brand_daily')}  ·  ${_dateLabel(now)}  ·  NO. ${_issueNumber(now).toString().padLeft(3, '0')}',
              style: _mono(10.5, color: BrandPalette.inkMuted, spacing: 0.65),
            ),
            _languagePicker(),
          ],
        ),
        const SizedBox(height: 26),
        Align(
          alignment: Alignment.centerLeft,
          child: EvilCoworkingLogo(width: compact ? 210 : 270),
        ),
        const SizedBox(height: 26),
        const _Rule(),
        const SizedBox(height: 14),
        Text(
          widget.localization.t('hero_kicker'),
          style: _mono(11, color: BrandPalette.inkMuted, spacing: 1.35),
        ),
      ],
    );
  }

  Widget _languagePicker() {
    return Semantics(
      label: 'Language',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: AppLanguage.values
            .map((language) {
              final selected = widget.localization.language == language;
              return Padding(
                padding: const EdgeInsets.only(left: 2),
                child: TextButton(
                  onPressed: () => widget.localization.setLanguage(language),
                  style: TextButton.styleFrom(
                    foregroundColor: BrandPalette.ink,
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: const RoundedRectangleBorder(),
                    side: selected
                        ? const BorderSide(color: BrandPalette.ink)
                        : BorderSide.none,
                  ),
                  child: Text(
                    language.code.toUpperCase(),
                    style: _mono(10.5, spacing: 0.7),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  Widget _availability(bool compact) {
    final status = _liveStatus ?? _content.status;
    final todayDate = status.todayDate.isEmpty
        ? _serviceDateForOffset(0)
        : status.todayDate;
    final tomorrowDate = status.tomorrowDate.isEmpty
        ? _serviceDateForOffset(1)
        : status.tomorrowDate;
    final todayBooking = _bookingFor(todayDate);
    final tomorrowBooking = _bookingFor(tomorrowDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionKicker(widget.localization.t('availability_kicker')),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${status.free}',
              style: _serif(compact ? 86 : 116, height: 0.78),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  widget.localization.t(
                    status.free == 1 ? 'desk_free' : 'desks_free',
                  ),
                  style: _serif(compact ? 23 : 30, height: 0.96),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _OccupancyMarks(total: status.total, occupied: status.occupied),
        const SizedBox(height: 12),
        Text(
          '${status.occupied} / ${status.total} ${widget.localization.t('occupied')}  ·  ${_updatedLabel(status.updated)}',
          style: _mono(10.5, color: BrandPalette.inkMuted, spacing: 0.55),
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: _PaperButton(
                label: widget.localization.t('booking_today'),
                detail: _bookingBusy ? '…' : _moneyLabel(status.todayPrice),
                icon: Icons.today_outlined,
                filled: true,
                onPressed:
                    _bookingBusy || todayBooking != null || status.free <= 0
                    ? null
                    : () => _requestDesk(todayDate),
              ),
            ),
            Expanded(
              child: _PaperButton(
                label: widget.localization.t('booking_tomorrow'),
                detail: _bookingBusy
                    ? '…'
                    : '${_moneyLabel(status.tomorrowPrice)} · ${status.tomorrowFree} ${widget.localization.t('free_short')}',
                icon: Icons.event_outlined,
                onPressed:
                    _bookingBusy ||
                        tomorrowBooking != null ||
                        status.tomorrowFree <= 0
                    ? null
                    : () => _requestDesk(tomorrowDate),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.localization.t('half_day_note'),
          style: _mono(9, color: BrandPalette.inkMuted, spacing: 0.35),
        ),
        if (todayBooking != null) ...[
          const SizedBox(height: 16),
          _bookingCard(todayBooking, false),
        ],
        if (tomorrowBooking != null) ...[
          const SizedBox(height: 10),
          _bookingCard(tomorrowBooking, true),
        ],
      ],
    );
  }

  Widget _bookingCard(DeskBookingState booking, bool tomorrow) {
    final bookingStatusKey = booking.accepted
        ? 'booking_accepted'
        : booking.declined
        ? 'booking_declined'
        : booking.cancelled
        ? 'booking_cancelled'
        : 'booking_pending';
    final bookingIcon = booking.accepted
        ? Icons.check_circle_outline
        : booking.declined
        ? Icons.cancel_outlined
        : booking.cancelled
        ? Icons.block_outlined
        : Icons.hourglass_top_outlined;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: booking.accepted
            ? BrandPalette.paperDeep
            : BrandPalette.paperLift,
        border: Border.all(color: BrandPalette.ink),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(bookingIcon, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '${widget.localization.t(tomorrow ? 'booking_tomorrow' : 'booking_today')} · ${widget.localization.t(bookingStatusKey)}',
                  style: _mono(11.5, spacing: 0.55),
                ),
              ),
              Text(_moneyLabel(booking.amountVnd), style: _serif(18)),
            ],
          ),
          if (booking.telegramLinked) ...[
            const SizedBox(height: 10),
            Text(
              widget.localization.t('booking_telegram_connected'),
              style: _mono(9, color: BrandPalette.inkMuted),
            ),
          ] else if (booking.canConnectTelegram && !booking.finished) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _connectBookingTelegram(booking),
              icon: const Icon(Icons.send_outlined, size: 17),
              label: Text(
                widget.localization.t('booking_connect_telegram'),
                style: _mono(9.5),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: BrandPalette.ink,
                minimumSize: const Size.fromHeight(46),
                side: const BorderSide(color: BrandPalette.ink),
                shape: const RoundedRectangleBorder(),
              ),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _bookingBusy
                ? null
                : booking.finished
                ? () => _clearFinishedBooking(booking)
                : () => _deleteDeskRequest(booking),
            icon: Icon(
              booking.finished ? Icons.refresh : Icons.close,
              size: 17,
            ),
            label: Text(
              _bookingBusy
                  ? '…'
                  : widget.localization.t(
                      booking.finished ? 'booking_again' : 'booking_delete',
                    ),
              style: _mono(9.5),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: BrandPalette.ink,
              minimumSize: const Size.fromHeight(46),
              side: const BorderSide(color: BrandPalette.ink),
              shape: const RoundedRectangleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  String _moneyLabel(int value) {
    if (value % 1000000 == 0) return '${value ~/ 1000000} MLN VND';
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)} MLN VND';
    }
    if (value % 1000 == 0) return '${value ~/ 1000}K VND';
    return '$value VND';
  }

  Widget _prices(bool compact) {
    return _Section(
      title: widget.localization.t('prices_title'),
      child: Column(
        children: _content.prices
            .map((price) {
              return Container(
                constraints: const BoxConstraints(minHeight: 76),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: BrandPalette.rule)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.localization.t(price.labelKey),
                        style: _mono(11, spacing: 0.8),
                      ),
                    ),
                    Text(
                      price.price,
                      textAlign: TextAlign.right,
                      style: _serif(compact ? 24 : 30),
                    ),
                  ],
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  Widget _openings(bool compact) {
    return _Section(
      title: widget.localization.t('opening_title'),
      child: Column(
        children: _content.openings
            .map((opening) {
              return Container(
                constraints: const BoxConstraints(minHeight: 70),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: BrandPalette.rule)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(right: 14),
                      decoration: BoxDecoration(
                        color: opening.isOpen
                            ? BrandPalette.ink
                            : Colors.transparent,
                        border: Border.all(color: BrandPalette.ink),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.localization.t(opening.labelKey),
                        style: _serif(compact ? 18 : 21),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.localization.t(
                        opening.isOpen ? 'now_open' : 'coming_soon',
                      ),
                      style: _mono(
                        9.5,
                        color: BrandPalette.inkMuted,
                        spacing: 0.6,
                      ),
                    ),
                  ],
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  Widget _note(bool compact) {
    final announcement = _content.announcements.first;
    return _Section(
      title: widget.localization.t('notes_title'),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: compact ? 24 : 30),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: BrandPalette.ink)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: compact ? 62 : 86,
              child: Text(
                announcement.date,
                style: _mono(10, color: BrandPalette.inkMuted, spacing: 0.7),
              ),
            ),
            Expanded(
              child: Text(
                announcement.textFor(widget.localization.language.code),
                style: _serif(compact ? 21 : 26, height: 1.16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _visit(bool compact) {
    return _Section(
      title: widget.localization.t('visit_title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 22),
          Text(
            widget.localization.t('visit_copy'),
            style: _serif(compact ? 18 : 21, height: 1.35),
          ),
          const SizedBox(height: 24),
          Container(
            height: compact ? 170 : 190,
            decoration: BoxDecoration(
              color: BrandPalette.paperDeep,
              border: Border.all(color: BrandPalette.ink),
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _LocationPlatePainter()),
                ),
                Positioned(
                  left: compact ? 18 : 26,
                  right: compact ? 18 : 26,
                  bottom: compact ? 16 : 22,
                  child: Container(
                    color: BrandPalette.paperLift,
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      widget.localization.t('contact_location'),
                      style: _mono(10.5, spacing: 0.65, height: 1.45),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CompactLink(
                label: widget.localization.t('contact_directions'),
                icon: Icons.near_me_outlined,
                onPressed: () => _launch(_directionsUrl),
              ),
              _CompactLink(
                label: widget.localization.t('contact_map'),
                icon: Icons.rate_review_outlined,
                onPressed: () => _launch(_mapsUrl),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _ContactLink(
            label: widget.localization.t('contact_instagram'),
            detail: '@evil_space_coworking',
            onPressed: () => _launch(_instagramUrl),
          ),
          _ContactLink(
            label: widget.localization.t('contact_telegram'),
            detail: '@your_evil_space',
            onPressed: () => _launch(_telegramUrl),
          ),
          _ContactLink(
            label: widget.localization.t('contact_zalo'),
            detail: '+84 56 5056 748',
            onPressed: () => _launch(_zaloUrl),
          ),
          _ContactLink(
            label: widget.localization.t('contact_phone'),
            detail: '+84 56 5056 748',
            onPressed: () => _launch(_phoneUrl),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Column(
      children: [
        const _Rule(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'EVIL SPACE  ·  NHA TRANG',
                style: _mono(9.5, color: BrandPalette.inkMuted, spacing: 0.75),
              ),
            ),
            Text(
              widget.localization.t('page_one'),
              style: _mono(9.5, color: BrandPalette.inkMuted, spacing: 0.75),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionKicker(String text) => Text(
    text,
    style: _mono(10.5, color: BrandPalette.inkMuted, spacing: 1.05),
  );

  String _updatedLabel(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return widget.localization.t('local_data');
    final today = _nhaTrangNow();
    final localParsed = parsed.toUtc().add(const Duration(hours: 7));
    if (localParsed.year == today.year &&
        localParsed.month == today.month &&
        localParsed.day == today.day) {
      return widget.localization.t('updated_today');
    }
    return '${widget.localization.t('updated')} ${localParsed.day.toString().padLeft(2, '0')} ${_months[localParsed.month - 1]}';
  }

  DateTime _nhaTrangNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 7));

  int _issueNumber(DateTime date) {
    final start = DateTime.utc(date.year, 1, 1);
    final day = DateTime.utc(date.year, date.month, date.day);
    return day.difference(start).inDays + 1;
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')} ${_months[date.month - 1]} ${date.year}';
}

class _DeskBookingDialog extends StatefulWidget {
  const _DeskBookingDialog({
    required this.localization,
    required this.onTelegram,
    required this.serviceDate,
    required this.isTomorrow,
  });

  final LocalizationController localization;
  final VoidCallback onTelegram;
  final String serviceDate;
  final bool isTomorrow;

  @override
  State<_DeskBookingDialog> createState() => _DeskBookingDialogState();
}

class _DeskBookingDialogState extends State<_DeskBookingDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _telegram() {
    Navigator.of(context).pop();
    widget.onTelegram();
  }

  void _submitPhone() {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    if (name.isEmpty || phone.length < 3) return;
    Navigator.of(context).pop(
      DeskBookingProfile(
        name: name,
        contactType: 'phone',
        contactValue: phone,
        serviceDate: widget.serviceDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.localization;
    return AlertDialog(
      backgroundColor: BrandPalette.paper,
      shape: const RoundedRectangleBorder(),
      title: Text(
        l.t(
          widget.isTomorrow ? 'booking_title_tomorrow' : 'booking_title_today',
        ),
        style: _serif(30),
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: _telegram,
              icon: const Icon(Icons.send_outlined, size: 20),
              label: Text(
                l.t('booking_tg_button'),
                style: _mono(10, color: BrandPalette.paperLift),
              ),
              style: FilledButton.styleFrom(
                foregroundColor: BrandPalette.paperLift,
                backgroundColor: BrandPalette.ink,
                minimumSize: const Size.fromHeight(54),
                shape: const RoundedRectangleBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.t('booking_tg_copy'),
              textAlign: TextAlign.center,
              style: _mono(8.5, color: BrandPalette.inkMuted, height: 1.35),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: Divider(color: BrandPalette.rule)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(l.t('booking_or'), style: _mono(9)),
                ),
                const Expanded(child: Divider(color: BrandPalette.rule)),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              l.t('booking_phone_copy'),
              textAlign: TextAlign.center,
              style: _mono(8.5, color: BrandPalette.inkMuted, height: 1.35),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              autofocus: false,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: _bookingInput(l.t('booking_name')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitPhone(),
              decoration: _bookingInput(l.t('booking_phone')),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: _submitPhone,
          style: FilledButton.styleFrom(
            backgroundColor: BrandPalette.ink,
            foregroundColor: BrandPalette.paperLift,
            minimumSize: const Size(160, 48),
            shape: const RoundedRectangleBorder(),
          ),
          child: Text(
            l.t('booking_send'),
            style: _mono(9.5, color: BrandPalette.paperLift),
          ),
        ),
      ],
    );
  }
}

const _months = <String>[
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Rule(),
        const SizedBox(height: 14),
        Text(title, style: _mono(11, spacing: 1.05)),
        child,
      ],
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
      spacing: 7,
      runSpacing: 7,
      children: List.generate(total, (index) {
        final filled = index < occupied;
        return Semantics(
          label: filled ? 'Occupied desk' : 'Free desk',
          child: Container(
            width: 17,
            height: 17,
            decoration: BoxDecoration(
              color: filled ? BrandPalette.ink : Colors.transparent,
              border: Border.all(color: BrandPalette.ink, width: 1.2),
            ),
          ),
        );
      }),
    );
  }
}

class _PaperButton extends StatelessWidget {
  const _PaperButton({
    required this.label,
    required this.detail,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final String detail;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? BrandPalette.paperLift : BrandPalette.ink;
    return Semantics(
      button: true,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: filled ? BrandPalette.ink : Colors.transparent,
          minimumSize: const Size.fromHeight(58),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: const BorderSide(color: BrandPalette.ink),
          shape: const RoundedRectangleBorder(),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: _mono(11, color: foreground, spacing: 0.75),
              ),
            ),
            Flexible(
              flex: 2,
              child: Text(
                detail,
                textAlign: TextAlign.right,
                style: _serif(19, color: foreground),
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, size: 19),
          ],
        ),
      ),
    );
  }
}

class _CompactLink extends StatelessWidget {
  const _CompactLink({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, style: _mono(10, spacing: 0.55)),
      style: OutlinedButton.styleFrom(
        foregroundColor: BrandPalette.ink,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        side: const BorderSide(color: BrandPalette.ink),
        shape: const RoundedRectangleBorder(),
      ),
    );
  }
}

class _ContactLink extends StatelessWidget {
  const _ContactLink({
    required this.label,
    required this.detail,
    required this.onPressed,
  });

  final String label;
  final String detail;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: BrandPalette.ink,
        minimumSize: const Size.fromHeight(58),
        padding: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(),
      ),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: BrandPalette.rule)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: _mono(10.5, spacing: 0.7))),
            Text(
              detail,
              style: _mono(10, color: BrandPalette.inkMuted, spacing: 0.25),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_outward, size: 18),
          ],
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 1, child: ColoredBox(color: BrandPalette.ink));
}

class _LocationPlatePainter extends CustomPainter {
  const _LocationPlatePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final secondary = Paint()
      ..color = BrandPalette.inkFaint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final primary = Paint()
      ..color = BrandPalette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final roadOne = Path()
      ..moveTo(-12, size.height * 0.34)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.08,
        size.width * 0.58,
        size.height * 0.55,
        size.width + 12,
        size.height * 0.18,
      );
    final roadTwo = Path()
      ..moveTo(size.width * 0.2, -10)
      ..cubicTo(
        size.width * 0.42,
        size.height * 0.3,
        size.width * 0.25,
        size.height * 0.72,
        size.width * 0.52,
        size.height + 10,
      );
    canvas.drawPath(roadOne, secondary);
    canvas.drawPath(roadTwo, secondary);

    final center = Offset(size.width * 0.7, size.height * 0.38);
    canvas.drawCircle(center, 18, primary);
    canvas.drawCircle(center, 5, Paint()..color = BrandPalette.ink);
    canvas.drawLine(
      center + const Offset(0, 18),
      center + const Offset(0, 36),
      primary,
    );
  }

  @override
  bool shouldRepaint(covariant _LocationPlatePainter oldDelegate) => false;
}

class _EInkRefreshPainter extends CustomPainter {
  const _EInkRefreshPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1 || size.isEmpty) return;
    final intensity = progress < 0.5 ? progress * 2 : (1 - progress) * 2;
    final wash = Paint()
      ..color = BrandPalette.ink.withValues(alpha: 0.035 * intensity);
    canvas.drawRect(Offset.zero & size, wash);

    final lines = Paint()
      ..color = BrandPalette.ink.withValues(alpha: 0.045 * intensity)
      ..strokeWidth = 0.7;
    for (var y = 0.0; y < size.height; y += 7) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), lines);
    }
  }

  @override
  bool shouldRepaint(covariant _EInkRefreshPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

InputDecoration _bookingInput(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: _mono(9),
    filled: true,
    fillColor: BrandPalette.paperLift,
    border: const OutlineInputBorder(
      borderSide: BorderSide(color: BrandPalette.ink),
      borderRadius: BorderRadius.zero,
    ),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: BrandPalette.ink),
      borderRadius: BorderRadius.zero,
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: BrandPalette.ink, width: 2),
      borderRadius: BorderRadius.zero,
    ),
  );
}

TextStyle _serif(
  double size, {
  Color color = BrandPalette.ink,
  double height = 1.05,
}) {
  return TextStyle(
    color: color,
    fontFamily: 'Georgia',
    fontFamilyFallback: const ['Times New Roman', 'serif'],
    fontSize: size,
    fontWeight: FontWeight.w400,
    height: height,
    letterSpacing: -0.25,
  );
}

TextStyle _mono(
  double size, {
  Color color = BrandPalette.ink,
  double spacing = 0,
  double height = 1.2,
}) {
  return TextStyle(
    color: color,
    fontFamily: 'Courier New',
    fontFamilyFallback: const ['monospace'],
    fontSize: size,
    fontWeight: FontWeight.w700,
    height: height,
    letterSpacing: spacing,
  );
}
