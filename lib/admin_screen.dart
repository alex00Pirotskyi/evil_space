import 'dart:async';

import 'package:flutter/material.dart';

import 'package:evil_space/admin_api.dart';
import 'package:evil_space/brand_logo.dart';
import 'package:evil_space/brand_surface.dart';

class AdminBuildConfig {
  AdminBuildConfig._();

  static const previewEnabled = bool.fromEnvironment(
    'EVIL_SPACE_ADMIN_PREVIEW',
    defaultValue: false,
  );
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({
    super.key,
    required this.api,
    required this.onExit,
    required this.onManageAdmins,
  });

  final AdminApi api;
  final VoidCallback onExit;
  final VoidCallback onManageAdmins;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _purchaseController = TextEditingController();
  final _customerSearchController = TextEditingController();
  Timer? _refreshTimer;
  OperationsSnapshot? _snapshot;
  int _section = 0;
  int _incomePeriod = 0;
  int _purchaseTab = 0;
  bool _russian = true;
  bool _busy = false;
  bool _loading = true;
  String _customerQuery = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _purchaseController.dispose();
    _customerSearchController.dispose();
    super.dispose();
  }

  String t(String ru, String en) => _russian ? ru : en;

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final snapshot = await widget.api.operations().timeout(
        const Duration(seconds: 10),
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _error = null;
      });
    } on TimeoutException {
      if (!mounted || silent) return;
      setState(() {
        _loading = false;
        _error = t(
          'Сервер отвечает слишком долго. Нажмите ОБНОВИТЬ.',
          'The server is taking too long. Press REFRESH.',
        );
      });
    } on AdminApiException catch (error) {
      if (!mounted || silent) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted || silent) return;
      setState(() {
        _loading = false;
        _error = t('Не удалось загрузить данные.', 'Could not load data.');
      });
    }
  }

  Future<void> _apply(
    Future<OperationsSnapshot> Function() action, {
    String? success,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final snapshot = await action().timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _busy = false;
        _loading = false;
      });
      if (success != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = t(
          'Сервер отвечает слишком долго.',
          'The server is taking too long.',
        );
      });
    } on AdminApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = t('Не удалось сохранить.', 'Could not save.');
      });
    }
  }

  Future<void> _showAddCustomer() async {
    if (_busy) return;

    final passType = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ChoiceDialog(
        title: t('Добавить клиента', 'Add customer'),
        choices: [
          _Choice(
            value: 'day',
            icon: Icons.wb_sunny_outlined,
            title: t('ДНЕВНОЙ ПРОПУСК', 'DAY PASS'),
            subtitle: _money(_snapshot?.pricing.currentDayPassVnd ?? 200000),
          ),
          _Choice(
            value: 'month',
            icon: Icons.calendar_month_outlined,
            title: t('МЕСЯЧНЫЙ ПРОПУСК', 'MONTH PASS'),
            subtitle: _money(_snapshot?.pricing.currentMonthPassVnd ?? 2500000),
          ),
        ],
      ),
    );

    if (!mounted || passType == null) return;

    if (passType == 'day') {
      final name = await _askName(t('Дневной пропуск', 'Day pass'));
      if (name == null) return;
      await _apply(
        () => widget.api.addDayPass(name),
        success: t('Клиент добавлен', 'Customer added'),
      );
      return;
    }

    final monthType = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ChoiceDialog(
        title: t('Месячный пропуск', 'Month pass'),
        choices: [
          _Choice(
            value: 'new',
            icon: Icons.person_add_alt_1_outlined,
            title: t('НОВЫЙ', 'NEW'),
            subtitle: t('Новый абонемент на 1 месяц', 'New 1-month membership'),
          ),
          _Choice(
            value: 'active',
            icon: Icons.how_to_reg_outlined,
            title: t('АКТИВНЫЙ', 'ACTIVE'),
            subtitle: t(
              'Отметить уже оплаченный абонемент',
              'Check in an existing member',
            ),
          ),
        ],
      ),
    );

    if (!mounted || monthType == null) return;

    if (monthType == 'new') {
      final name = await _askName(
        t('Новый месячный абонемент', 'New month membership'),
      );
      if (name == null) return;
      await _apply(
        () => widget.api.addMonthPass(name),
        success: t('Абонемент создан на 1 месяц', '1-month membership created'),
      );
      return;
    }

    var memberships =
        _snapshot?.activeMemberships ?? const <MembershipRecord>[];
    if (memberships.isEmpty) {
      await _load();
      memberships = _snapshot?.activeMemberships ?? const <MembershipRecord>[];
    }
    if (!mounted) return;

    if (memberships.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('Нет активных абонементов.', 'No active memberships.'),
          ),
        ),
      );
      return;
    }

    final membership = await showDialog<MembershipRecord>(
      context: context,
      builder: (dialogContext) =>
          _MembershipDialog(russian: _russian, memberships: memberships),
    );

    if (!mounted || membership == null) return;
    await _apply(
      () => widget.api.checkInMembership(membership.id),
      success: t('Клиент отмечен', 'Customer checked in'),
    );
  }

  Future<String?> _askName(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: BrandPalette.paper,
        shape: const RoundedRectangleBorder(),
        title: Text(title, style: _serif(28)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: _inputDecoration(t('ИМЯ', 'NAME')),
          onSubmitted: (value) {
            final name = value.trim();
            if (name.isNotEmpty) Navigator.of(dialogContext).pop(name);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t('ОТМЕНА', 'CANCEL'), style: _mono(10)),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.of(dialogContext).pop(name);
            },
            style: _darkButton(),
            child: Text(
              t('ДОБАВИТЬ', 'ADD'),
              style: _mono(10, color: BrandPalette.paperLift),
            ),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _acceptBooking(BookingRequestRecord booking) async {
    await _apply(
      () => widget.api.acceptBooking(booking.id),
      success:
          '${t('ПРИНЯТО', 'ACCEPTED')} · ${_bookingDayLabel(booking)} · ${_date(booking.serviceDay)} · ${_money(booking.amountVnd)}',
    );
  }

  Future<void> _declineBooking(BookingRequestRecord booking) async {
    await _apply(
      () => widget.api.declineBooking(booking.id),
      success:
          '${t('ОТКЛОНЕНО', 'DECLINED')} · ${_bookingDayLabel(booking)} · ${_money(booking.amountVnd)}',
    );
  }

  Future<void> _editCustomer(CustomerRecord customer) async {
    final result = await showDialog<_CustomerEditResult>(
      context: context,
      builder: (_) =>
          _CustomerEditorDialog(russian: _russian, customer: customer),
    );
    if (!mounted || result == null) return;

    if (result.delete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: BrandPalette.paper,
          shape: const RoundedRectangleBorder(),
          title: Text(
            t('Удалить клиента?', 'Delete customer?'),
            style: _serif(26),
          ),
          content: Text(customer.name, style: _serif(18)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(t('ОТМЕНА', 'CANCEL'), style: _mono(10)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: _darkButton(),
              child: Text(
                t('УДАЛИТЬ', 'DELETE'),
                style: _mono(10, color: BrandPalette.paperLift),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await _apply(
        () => widget.api.deleteCustomer(customer.id),
        success: t('Клиент удалён', 'Customer deleted'),
      );
      return;
    }

    await _apply(
      () => widget.api.updateCustomerFields(
        id: customer.id,
        name: result.name,
        phone: result.phone,
        email: result.email,
        telegram: result.telegram,
        contactOther: result.contactOther,
        notes: result.notes,
      ),
      success: t('Клиент сохранён', 'Customer saved'),
    );
  }

  Future<void> _addPurchase() async {
    final title = _purchaseController.text.trim();
    if (title.isEmpty || _busy) return;
    _purchaseController.clear();
    await _apply(
      () => widget.api.addPurchase(title),
      success: t('Добавлено для всех админов', 'Shared with all admins'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return Scaffold(
      backgroundColor: BrandPalette.paper,
      body: BrandPaper(
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              _navigation(snapshot),
              _quickAdd(),
              if (_error != null) _errorBanner(),
              Expanded(
                child: snapshot == null
                    ? _loadingState()
                    : RefreshIndicator(
                        color: BrandPalette.ink,
                        onRefresh: _load,
                        child: _body(snapshot),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BrandPalette.ink)),
      ),
      child: Row(
        children: [
          const EvilCoworkingLogo(width: 104),
          const Spacer(),
          _smallToggle('RU', _russian, () => setState(() => _russian = true)),
          _smallToggle('EN', !_russian, () => setState(() => _russian = false)),
          const SizedBox(width: 8),
          IconButton(
            tooltip: t('Администраторы', 'Admins'),
            onPressed: widget.onManageAdmins,
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
          ),
          IconButton(
            tooltip: t('Выйти', 'Exit'),
            onPressed: widget.onExit,
            icon: const Icon(Icons.logout, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _navigation(OperationsSnapshot? snapshot) {
    final requestCount = snapshot?.bookingRequests.length ?? 0;
    final labels = [
      '${t('СЕГОДНЯ', 'TODAY')}${requestCount == 0 ? '' : ' $requestCount'}',
      t('МЕСЯЦ', 'MONTH'),
      t('КЛИЕНТЫ', 'CUSTOMERS'),
      t('ДОХОД', 'INCOME'),
      t('ЦЕНЫ', 'PRICES'),
      '${t('КУПИТЬ', 'BUY')}${snapshot == null || snapshot.toBuy.isEmpty ? '' : ' ${snapshot.toBuy.length}'}',
    ];
    final icons = const [
      Icons.today_outlined,
      Icons.calendar_month_outlined,
      Icons.people_outline,
      Icons.payments_outlined,
      Icons.local_offer_outlined,
      Icons.shopping_cart_outlined,
    ];

    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          final selected = index == _section;
          final foreground = selected
              ? BrandPalette.paperLift
              : BrandPalette.ink;
          return TextButton.icon(
            onPressed: () => setState(() => _section = index),
            icon: Icon(icons[index], size: 18),
            label: Text(labels[index], style: _mono(10, color: foreground)),
            style: TextButton.styleFrom(
              foregroundColor: foreground,
              backgroundColor: selected ? BrandPalette.ink : Colors.transparent,
              minimumSize: const Size(118, 44),
              shape: const RoundedRectangleBorder(),
            ),
          );
        },
      ),
    );
  }

  Widget _quickAdd() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BrandPalette.rule)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: FilledButton.icon(
            onPressed: _busy ? null : _showAddCustomer,
            icon: const Icon(Icons.person_add_alt_1, size: 22),
            label: Text(
              t('ДОБАВИТЬ КЛИЕНТА', 'ADD CUSTOMER'),
              style: _mono(13, color: BrandPalette.paperLift),
            ),
            style: FilledButton.styleFrom(
              foregroundColor: BrandPalette.paperLift,
              backgroundColor: BrandPalette.ink,
              disabledForegroundColor: BrandPalette.paperLift,
              disabledBackgroundColor: BrandPalette.inkMuted,
              minimumSize: const Size.fromHeight(56),
              shape: const RoundedRectangleBorder(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BrandPalette.ink)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(_error!, style: _mono(10.5))),
          TextButton(
            onPressed: _loading ? null : _load,
            child: Text(t('ОБНОВИТЬ', 'REFRESH'), style: _mono(9.5)),
          ),
        ],
      ),
    );
  }

  Widget _loadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_loading)
            const CircularProgressIndicator(color: BrandPalette.ink)
          else
            const Icon(Icons.cloud_off_outlined, size: 34),
          const SizedBox(height: 14),
          Text(
            _loading
                ? t('ЗАГРУЗКА…', 'LOADING…')
                : t('ДАННЫЕ НЕ ЗАГРУЖЕНЫ', 'DATA NOT LOADED'),
            style: _mono(10.5),
          ),
          if (!_loading) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _load,
              style: _outlineButton(),
              child: Text(t('ОБНОВИТЬ', 'REFRESH'), style: _mono(10)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _body(OperationsSnapshot snapshot) {
    return switch (_section) {
      0 => _today(snapshot),
      1 => _month(snapshot),
      2 => _customers(snapshot),
      3 => _income(snapshot),
      4 => _pricing(snapshot),
      _ => _buy(snapshot),
    };
  }

  Widget _page(List<Widget> children) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  Widget _today(OperationsSnapshot snapshot) {
    return _page([
      _metricRow([
        _MetricCard(
          t('ЛЮДЕЙ СЕГОДНЯ', 'PEOPLE TODAY'),
          '${snapshot.todayVisits.length}',
        ),
        _MetricCard(
          t('ДОХОД СЕГОДНЯ', 'TODAY INCOME'),
          _money(snapshot.income.today),
        ),
        _MetricCard(
          t('АКТИВНЫХ МЕСЯЦЕВ', 'ACTIVE MONTHS'),
          '${snapshot.activeMemberships.length}',
        ),
      ]),
      if (snapshot.bookingRequests.isNotEmpty) ...[
        const SizedBox(height: 28),
        _bookingGroup(snapshot.bookingRequests, tomorrow: false),
        const SizedBox(height: 20),
        _bookingGroup(snapshot.bookingRequests, tomorrow: true),
      ],
      const SizedBox(height: 28),
      _sectionTitle(t('СЕГОДНЯ', 'TODAY')),
      if (snapshot.todayVisits.isEmpty)
        _empty(t('Пока никого.', 'Nobody yet.'))
      else
        ...snapshot.todayVisits.map(
          (visit) => _row(
            visit.name,
            '${_time(visit.createdAt)}  ·  ${visit.kind == 'day' ? t('ДЕНЬ', 'DAY') : t('МЕСЯЦ', 'MONTH')}',
            visit.amount == 0 ? t('АКТИВЕН', 'ACTIVE') : _money(visit.amount),
          ),
        ),
    ]);
  }

  Widget _bookingGroup(
    List<BookingRequestRecord> bookings, {
    required bool tomorrow,
  }) {
    final rows = bookings
        .where((booking) => _isTomorrowBooking(booking) == tomorrow)
        .toList(growable: false);
    if (rows.isEmpty) return const SizedBox.shrink();
    final title = tomorrow
        ? t('БРОНИ НА ЗАВТРА', 'TOMORROW BOOKINGS')
        : t('БРОНИ НА СЕГОДНЯ', 'TODAY BOOKINGS');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('$title · ${rows.length}'),
        ...rows.map(_bookingRow),
      ],
    );
  }

  Widget _bookingRow(BookingRequestRecord booking) {
    final type = booking.contactType == 'telegram' ? 'TG' : t('ТЕЛ', 'PHONE');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BrandPalette.rule)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.name, style: _serif(19)),
                const SizedBox(height: 5),
                Text(
                  '$type · ${booking.contactValue} · ${_bookingDayLabel(booking)} · ${_date(booking.serviceDay)} · ${_money(booking.amountVnd)} · ${_time(booking.createdAt)}',
                  style: _mono(9.5, color: BrandPalette.inkMuted),
                ),
                if (booking.accepted &&
                    (booking.handledByEmail?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 5),
                  Text(
                    '${t('ПРИНЯТО', 'ACCEPTED')} · ${booking.handledByEmail}',
                    style: _mono(9, color: BrandPalette.inkMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (booking.accepted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: BrandPalette.ink,
                border: Border.all(color: BrandPalette.ink),
              ),
              child: Text(
                t('ПРИНЯТО', 'ACCEPTED'),
                style: _mono(9, color: BrandPalette.paperLift),
              ),
            )
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : () => _declineBooking(booking),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BrandPalette.ink,
                    minimumSize: const Size(0, 42),
                    side: const BorderSide(color: BrandPalette.ink),
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: Text(t('ОТКЛОНИТЬ', 'DECLINE'), style: _mono(9)),
                ),
                FilledButton(
                  onPressed: _busy ? null : () => _acceptBooking(booking),
                  style: _darkButton(minHeight: 42),
                  child: Text(
                    '${t('ПРИНЯТЬ', 'ACCEPT')} · ${_money(booking.amountVnd)}',
                    style: _mono(9.5, color: BrandPalette.paperLift),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  bool _isTomorrowBooking(BookingRequestRecord booking) {
    final local = DateTime.fromMillisecondsSinceEpoch(
      booking.serviceDay * 1000,
      isUtc: true,
    ).add(const Duration(hours: 7));
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    return local.year == tomorrow.year &&
        local.month == tomorrow.month &&
        local.day == tomorrow.day;
  }

  String _bookingDayLabel(BookingRequestRecord booking) =>
      _isTomorrowBooking(booking)
      ? t('ЗАВТРА', 'TOMORROW')
      : t('СЕГОДНЯ', 'TODAY');

  Widget _month(OperationsSnapshot snapshot) {
    return _page([
      _metricRow([
        _MetricCard(
          t('АКТИВНЫЕ', 'ACTIVE'),
          '${snapshot.activeMemberships.length}',
        ),
        _MetricCard(
          t('30 ДНЕЙ ДОХОД', '30D INCOME'),
          _money(snapshot.income.thirtyDays),
        ),
      ]),
      const SizedBox(height: 28),
      _sectionTitle(t('АКТИВНЫЕ АБОНЕМЕНТЫ', 'ACTIVE MEMBERSHIPS')),
      if (snapshot.activeMemberships.isEmpty)
        _empty(t('Нет активных абонементов.', 'No active memberships.'))
      else
        ...snapshot.activeMemberships.map(
          (membership) => _row(
            membership.name,
            '${t('ДО', 'UNTIL')} ${_date(membership.expiresAt)}',
            '${_daysLeft(membership.expiresAt)} ${t('ДН.', 'DAYS')}',
          ),
        ),
    ]);
  }

  Widget _customers(OperationsSnapshot snapshot) {
    final query = _customerQuery.trim().toLowerCase();
    final customers = snapshot.customers
        .where((customer) {
          if (query.isEmpty) return true;
          return [
            customer.name,
            customer.phone,
            customer.email,
            customer.telegram,
            customer.contactOther,
            customer.notes,
          ].any((value) => value.toLowerCase().contains(query));
        })
        .toList(growable: false);

    return _page([
      TextField(
        controller: _customerSearchController,
        decoration: _inputDecoration(t('ПОИСК КЛИЕНТА', 'SEARCH CUSTOMER')),
        onChanged: (value) => setState(() => _customerQuery = value),
      ),
      const SizedBox(height: 20),
      _sectionTitle(
        '${t('КЛИЕНТЫ', 'CUSTOMERS')} · ${snapshot.customers.length}',
      ),
      if (customers.isEmpty)
        _empty(t('Клиентов пока нет.', 'No customers yet.'))
      else
        ...customers.map(_customerRow),
    ]);
  }

  Widget _customerRow(CustomerRecord customer) {
    final contacts = <String>[
      if (customer.phone.isNotEmpty) customer.phone,
      if (customer.telegram.isNotEmpty) 'TG ${customer.telegram}',
      if (customer.email.isNotEmpty) customer.email,
      if (customer.contactOther.isNotEmpty) customer.contactOther,
    ];
    final meta = contacts.isEmpty
        ? t('КОНТАКТ НЕ ДОБАВЛЕН', 'NO CONTACT')
        : contacts.join(' · ');
    final trailing = customer.hasActiveMembership
        ? '${t('ДО', 'UNTIL')} ${_date(customer.activeUntil!)}'
        : t('ИЗМЕНИТЬ', 'EDIT');

    return InkWell(
      onTap: () => _editCustomer(customer),
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: BrandPalette.rule)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.name, style: _serif(18)),
                  const SizedBox(height: 5),
                  Text(meta, style: _mono(9, color: BrandPalette.inkMuted)),
                  if (customer.notes.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      customer.notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _serif(14, color: BrandPalette.inkMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(trailing, style: _mono(9.5)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _income(OperationsSnapshot snapshot) {
    final values = [
      snapshot.income.today,
      snapshot.income.sevenDays,
      snapshot.income.thirtyDays,
      snapshot.income.all,
    ];
    final labels = [
      t('СЕГОДНЯ', 'TODAY'),
      t('7 ДНЕЙ', '7 DAYS'),
      t('30 ДНЕЙ', '30 DAYS'),
      t('ВСЕ', 'ALL'),
    ];

    return _page([
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(labels.length, (index) {
          final selected = _incomePeriod == index;
          final foreground = selected
              ? BrandPalette.paperLift
              : BrandPalette.ink;
          return ChoiceChip(
            label: Text(labels[index], style: _mono(10, color: foreground)),
            selected: selected,
            onSelected: (_) => setState(() => _incomePeriod = index),
            selectedColor: BrandPalette.ink,
            backgroundColor: BrandPalette.paper,
            labelStyle: TextStyle(color: foreground),
            shape: const RoundedRectangleBorder(
              side: BorderSide(color: BrandPalette.ink),
            ),
            showCheckmark: false,
          );
        }),
      ),
      const SizedBox(height: 28),
      Text(_money(values[_incomePeriod]), style: _serif(54)),
      const SizedBox(height: 8),
      Text(labels[_incomePeriod], style: _mono(11)),
      const SizedBox(height: 30),
      _sectionTitle(t('ТАРИФЫ', 'PRICES')),
      _row(
        t('ДНЕВНОЙ ПРОПУСК', 'DAY PASS'),
        '',
        _money(snapshot.pricing.dayPassVnd),
      ),
      _row(
        t('МЕСЯЧНЫЙ ПРОПУСК', 'MONTH PASS'),
        '',
        _money(snapshot.pricing.monthPassVnd),
      ),
      _row(
        t('ЛИЧНЫЙ ШКАФЧИК', 'PERSONAL LOCKER'),
        '',
        _money(snapshot.pricing.lockerMonthVnd),
      ),
    ]);
  }

  Future<void> _editPricing(OperationsSnapshot snapshot) async {
    if (_busy) return;
    final result = await showDialog<_PricingEditResult>(
      context: context,
      builder: (_) =>
          _PricingEditorDialog(russian: _russian, pricing: snapshot.pricing),
    );
    if (!mounted || result == null) return;
    await _apply(
      () => widget.api.updatePricing(
        dayPassVnd: result.dayPassVnd,
        monthPassVnd: result.monthPassVnd,
        lockerMonthVnd: result.lockerMonthVnd,
      ),
      success: t('Цены обновлены', 'Prices updated'),
    );
  }

  Future<void> _addPromotion() async {
    if (_busy) return;
    final result = await showDialog<_PromotionDraft>(
      context: context,
      builder: (_) => _PromotionEditorDialog(russian: _russian),
    );
    if (!mounted || result == null) return;
    await _apply(
      () => widget.api.createPromotion(
        description: result.description,
        startDate: result.startDate,
        endDate: result.endDate,
        startTime: result.startTime,
        endTime: result.endTime,
        dayPassVnd: result.dayPassVnd,
        monthPassVnd: result.monthPassVnd,
        lockerMonthVnd: result.lockerMonthVnd,
      ),
      success: t('Акция запущена', 'Promotion created'),
    );
  }

  Future<void> _deletePromotion(PromotionRecord promotion) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: BrandPalette.paper,
        shape: const RoundedRectangleBorder(),
        title: Text(
          t('Удалить акцию?', 'Delete promotion?'),
          style: _serif(26),
        ),
        content: Text(promotion.description, style: _serif(17)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t('ОТМЕНА', 'CANCEL'), style: _mono(10)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: _darkButton(),
            child: Text(
              t('УДАЛИТЬ', 'DELETE'),
              style: _mono(10, color: BrandPalette.paperLift),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _apply(
      () => widget.api.deletePromotion(promotion.id),
      success: t('Акция удалена', 'Promotion deleted'),
    );
  }

  Widget _pricing(OperationsSnapshot snapshot) {
    final pricing = snapshot.pricing;
    return _page([
      _sectionTitle(t('ОСНОВНЫЕ ЦЕНЫ', 'BASE PRICES')),
      _row(t('ДНЕВНОЙ ПРОПУСК', 'DAY PASS'), '', _money(pricing.dayPassVnd)),
      _row(
        t('МЕСЯЧНЫЙ ПРОПУСК', 'MONTH PASS'),
        '',
        _money(pricing.monthPassVnd),
      ),
      _row(
        t('ЛИЧНЫЙ ШКАФЧИК', 'PERSONAL LOCKER'),
        '',
        _money(pricing.lockerMonthVnd),
      ),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: _busy ? null : () => _editPricing(snapshot),
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: Text(t('ИЗМЕНИТЬ ЦЕНЫ', 'EDIT PRICES'), style: _mono(10)),
        style: _outlineButton(minHeight: 50),
      ),
      const SizedBox(height: 32),
      Row(
        children: [
          Expanded(child: _sectionTitle(t('АКЦИИ', 'PROMOTIONS'))),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _addPromotion,
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              t('ДОБАВИТЬ АКЦИЮ', 'ADD PROMO'),
              style: _mono(9.5, color: BrandPalette.paperLift),
            ),
            style: _darkButton(minHeight: 46),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (snapshot.promotions.isEmpty)
        _empty(t('Акций пока нет.', 'No promotions yet.'))
      else
        ...snapshot.promotions.map(_promotionRow),
    ]);
  }

  Widget _promotionRow(PromotionRecord promotion) {
    final dateRange = promotion.startDay == promotion.endDay
        ? _date(promotion.startDay)
        : '${_date(promotion.startDay)} – ${_date(promotion.endDay)}';
    final timeRange = promotion.hasTimeWindow
        ? ' · ${_minuteLabel(promotion.startMinute!)}–${_minuteLabel(promotion.endMinute!)}'
        : '';
    final prices = <String>[
      if (promotion.dayPassVnd != null)
        '${t('ДЕНЬ', 'DAY')} ${_money(promotion.dayPassVnd!)}',
      if (promotion.monthPassVnd != null)
        '${t('МЕСЯЦ', 'MONTH')} ${_money(promotion.monthPassVnd!)}',
      if (promotion.lockerMonthVnd != null)
        '${t('ШКАФ', 'LOCKER')} ${_money(promotion.lockerMonthVnd!)}',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BrandPalette.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(promotion.description, style: _serif(19)),
                    const SizedBox(height: 5),
                    Text(
                      '$dateRange$timeRange',
                      style: _mono(9.5, color: BrandPalette.inkMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(prices, style: _mono(9.5)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: promotion.enabled,
                onChanged: _busy
                    ? null
                    : (enabled) => _apply(
                        () => widget.api.setPromotionEnabled(
                          promotion.id,
                          enabled,
                        ),
                        success: enabled
                            ? t('Акция запущена', 'Promotion running')
                            : t('Акция приостановлена', 'Promotion paused'),
                      ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _busy ? null : () => _deletePromotion(promotion),
              icon: const Icon(Icons.delete_outline, size: 17),
              label: Text(t('УДАЛИТЬ', 'DELETE'), style: _mono(9)),
            ),
          ),
        ],
      ),
    );
  }

  String _minuteLabel(int minute) {
    final hour = minute ~/ 60;
    final rest = minute % 60;
    return '${hour.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }

  Widget _buy(OperationsSnapshot snapshot) {
    final list = _purchaseTab == 0 ? snapshot.toBuy : snapshot.purchaseHistory;

    return _page([
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _purchaseController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addPurchase(),
              decoration: _inputDecoration(t('ЧТО КУПИТЬ?', 'WHAT TO BUY?')),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _busy ? null : _addPurchase,
            style: _darkButton(minHeight: 54),
            child: Text(
              t('ДОБАВИТЬ', 'ADD'),
              style: _mono(10, color: BrandPalette.paperLift),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: _tabButton(
              t('НУЖНО КУПИТЬ', 'TO BUY'),
              _purchaseTab == 0,
              () => setState(() => _purchaseTab = 0),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _tabButton(
              t('ИСТОРИЯ', 'HISTORY'),
              _purchaseTab == 1,
              () => setState(() => _purchaseTab = 1),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      if (list.isEmpty)
        _empty(
          _purchaseTab == 0
              ? t('Список пуст.', 'Nothing to buy.')
              : t('История пуста.', 'History is empty.'),
        )
      else
        ...list.map(_purchaseRow),
    ]);
  }

  Widget _purchaseRow(PurchaseRequestRecord purchase) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BrandPalette.rule)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(purchase.title, style: _serif(19)),
                const SizedBox(height: 5),
                Text(
                  _dateTime(purchase.boughtAt ?? purchase.createdAt),
                  style: _mono(9, color: BrandPalette.inkMuted),
                ),
              ],
            ),
          ),
          if (purchase.status != 'bought')
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _apply(
                      () => widget.api.markPurchaseBought(purchase.id),
                      success: t('Перенесено в историю', 'Moved to history'),
                    ),
              style: _darkButton(minHeight: 42),
              child: Text(
                t('КУПЛЕНО', 'BOUGHT'),
                style: _mono(9.5, color: BrandPalette.paperLift),
              ),
            )
          else
            Text(t('КУПЛЕНО', 'BOUGHT'), style: _mono(9.5)),
        ],
      ),
    );
  }

  Widget _metricRow(List<_MetricCard> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 700 ? cards.length : 1;
        final width = count == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (10 * (cards.length - 1))) / cards.length;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: cards
              .map(
                (card) => SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: BrandPalette.ink),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(card.label, style: _mono(9.5)),
                        const SizedBox(height: 14),
                        Text(card.value, style: _serif(30)),
                      ],
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Widget _sectionTitle(String label) {
    return Container(
      padding: const EdgeInsets.only(bottom: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BrandPalette.ink)),
      ),
      child: Text(label, style: _mono(10.5)),
    );
  }

  Widget _empty(String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: _serif(18, color: BrandPalette.inkMuted),
      ),
    );
  }

  Widget _row(String title, String meta, String trailing) {
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BrandPalette.rule)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _serif(18)),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(meta, style: _mono(9, color: BrandPalette.inkMuted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(trailing, style: _mono(10)),
        ],
      ),
    );
  }

  Widget _tabButton(String label, bool selected, VoidCallback onPressed) {
    final foreground = selected ? BrandPalette.paperLift : BrandPalette.ink;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: selected ? BrandPalette.ink : BrandPalette.paper,
        minimumSize: const Size.fromHeight(46),
        side: const BorderSide(color: BrandPalette.ink),
        shape: const RoundedRectangleBorder(),
      ),
      child: Text(label, style: _mono(9.5, color: foreground)),
    );
  }

  Widget _smallToggle(String label, bool selected, VoidCallback onPressed) {
    final foreground = selected ? BrandPalette.paperLift : BrandPalette.ink;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: selected ? BrandPalette.ink : Colors.transparent,
        minimumSize: const Size(42, 42),
        padding: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(),
      ),
      child: Text(label, style: _mono(9, color: foreground)),
    );
  }

  String _money(int amount) {
    if (amount == 0) return '0 VND';
    if (amount % 1000000 == 0) return '${amount ~/ 1000000} MLN VND';
    if (amount >= 1000000) {
      final value = amount / 1000000;
      return '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)} MLN VND';
    }
    if (amount % 1000 == 0) return '${amount ~/ 1000}K VND';
    return '$amount VND';
  }

  String _time(int seconds) {
    final value = DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal();
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _date(int seconds) {
    final value = DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal();
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  String _dateTime(int seconds) => '${_date(seconds)} ${_time(seconds)}';

  int _daysLeft(int expiresAt) {
    final now = DateTime.now();
    final expires = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000)
        .toLocal();
    final hours = expires.difference(now).inHours;
    if (hours <= 0) return 0;
    return (hours / 24).ceil();
  }
}

class _Choice {
  const _Choice({
    required this.value,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final String value;
  final IconData icon;
  final String title;
  final String subtitle;
}

class _ChoiceDialog extends StatelessWidget {
  const _ChoiceDialog({required this.title, required this.choices});

  final String title;
  final List<_Choice> choices;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BrandPalette.paper,
      shape: const RoundedRectangleBorder(),
      title: Text(title, style: _serif(28)),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: choices
              .map(
                (choice) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(choice.value),
                    icon: Icon(choice.icon, size: 22),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(choice.title, style: _mono(11)),
                          const SizedBox(height: 4),
                          Text(
                            choice.subtitle,
                            style: _serif(15, color: BrandPalette.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BrandPalette.ink,
                      alignment: Alignment.centerLeft,
                      minimumSize: const Size.fromHeight(64),
                      side: const BorderSide(color: BrandPalette.ink),
                      shape: const RoundedRectangleBorder(),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _MembershipDialog extends StatefulWidget {
  const _MembershipDialog({required this.russian, required this.memberships});

  final bool russian;
  final List<MembershipRecord> memberships;

  @override
  State<_MembershipDialog> createState() => _MembershipDialogState();
}

class _MembershipDialogState extends State<_MembershipDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String t(String ru, String en) => widget.russian ? ru : en;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.memberships
        .where(
          (membership) => membership.name.toLowerCase().contains(
            _query.trim().toLowerCase(),
          ),
        )
        .toList(growable: false);

    return AlertDialog(
      backgroundColor: BrandPalette.paper,
      shape: const RoundedRectangleBorder(),
      title: Text(
        t('Активный абонемент', 'Active membership'),
        style: _serif(28),
      ),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: _inputDecoration(t('ПОИСК', 'SEARCH')),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        t('Ничего не найдено.', 'Nothing found.'),
                        style: _serif(17, color: BrandPalette.inkMuted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final membership = filtered[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          title: Text(membership.name, style: _serif(18)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).pop(membership),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerEditResult {
  const _CustomerEditResult({
    required this.name,
    required this.phone,
    required this.email,
    required this.telegram,
    required this.contactOther,
    required this.notes,
    this.delete = false,
  });

  final String name;
  final String phone;
  final String email;
  final String telegram;
  final String contactOther;
  final String notes;
  final bool delete;
}

class _CustomerEditorDialog extends StatefulWidget {
  const _CustomerEditorDialog({required this.russian, required this.customer});

  final bool russian;
  final CustomerRecord customer;

  @override
  State<_CustomerEditorDialog> createState() => _CustomerEditorDialogState();
}

class _CustomerEditorDialogState extends State<_CustomerEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _telegram;
  late final TextEditingController _other;
  late final TextEditingController _notes;

  String t(String ru, String en) => widget.russian ? ru : en;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _name = TextEditingController(text: customer.name);
    _phone = TextEditingController(text: customer.phone);
    _email = TextEditingController(text: customer.email);
    _telegram = TextEditingController(text: customer.telegram);
    _other = TextEditingController(text: customer.contactOther);
    _notes = TextEditingController(text: customer.notes);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _telegram.dispose();
    _other.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      _CustomerEditResult(
        name: name,
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        telegram: _telegram.text.trim(),
        contactOther: _other.text.trim(),
        notes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BrandPalette.paper,
      shape: const RoundedRectangleBorder(),
      title: Text(t('Клиент', 'Customer'), style: _serif(28)),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _name,
                decoration: _inputDecoration(t('ИМЯ', 'NAME')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phone,
                decoration: _inputDecoration(t('ТЕЛЕФОН', 'PHONE')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _telegram,
                decoration: _inputDecoration('TELEGRAM'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration('EMAIL'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _other,
                decoration: _inputDecoration(
                  t('ДРУГОЙ КОНТАКТ', 'OTHER CONTACT'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notes,
                minLines: 3,
                maxLines: 6,
                decoration: _inputDecoration(t('ЗАМЕТКИ', 'NOTES')),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            _CustomerEditResult(
              name: widget.customer.name,
              phone: widget.customer.phone,
              email: widget.customer.email,
              telegram: widget.customer.telegram,
              contactOther: widget.customer.contactOther,
              notes: widget.customer.notes,
              delete: true,
            ),
          ),
          child: Text(t('УДАЛИТЬ', 'DELETE'), style: _mono(9.5)),
        ),
        const SizedBox(width: 12),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('ОТМЕНА', 'CANCEL'), style: _mono(9.5)),
        ),
        FilledButton(
          onPressed: _save,
          style: _darkButton(),
          child: Text(
            t('СОХРАНИТЬ', 'SAVE'),
            style: _mono(9.5, color: BrandPalette.paperLift),
          ),
        ),
      ],
    );
  }
}

class _PricingEditResult {
  const _PricingEditResult(
    this.dayPassVnd,
    this.monthPassVnd,
    this.lockerMonthVnd,
  );
  final int dayPassVnd;
  final int monthPassVnd;
  final int lockerMonthVnd;
}

class _PricingEditorDialog extends StatefulWidget {
  const _PricingEditorDialog({required this.russian, required this.pricing});
  final bool russian;
  final PricingConfig pricing;

  @override
  State<_PricingEditorDialog> createState() => _PricingEditorDialogState();
}

class _PricingEditorDialogState extends State<_PricingEditorDialog> {
  late final TextEditingController _day;
  late final TextEditingController _month;
  late final TextEditingController _locker;
  String? _error;

  String t(String ru, String en) => widget.russian ? ru : en;

  @override
  void initState() {
    super.initState();
    _day = TextEditingController(text: '${widget.pricing.dayPassVnd}');
    _month = TextEditingController(text: '${widget.pricing.monthPassVnd}');
    _locker = TextEditingController(text: '${widget.pricing.lockerMonthVnd}');
  }

  @override
  void dispose() {
    _day.dispose();
    _month.dispose();
    _locker.dispose();
    super.dispose();
  }

  int? _price(TextEditingController controller) {
    final value = int.tryParse(
      controller.text.trim().replaceAll(RegExp(r'[^0-9]'), ''),
    );
    return value != null && value > 0 ? value : null;
  }

  void _save() {
    final day = _price(_day);
    final month = _price(_month);
    final locker = _price(_locker);
    if (day == null || month == null || locker == null) {
      setState(
        () => _error = t('Введите все цены в VND.', 'Enter all prices in VND.'),
      );
      return;
    }
    Navigator.of(context).pop(_PricingEditResult(day, month, locker));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BrandPalette.paper,
      shape: const RoundedRectangleBorder(),
      title: Text(t('Основные цены', 'Base prices'), style: _serif(28)),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _day,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(t('ДЕНЬ · VND', 'DAY PASS · VND')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _month,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(
                t('МЕСЯЦ · VND', 'MONTH PASS · VND'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locker,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(
                t('ШКАФ · VND', 'LOCKER / MONTH · VND'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: _mono(9.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('ОТМЕНА', 'CANCEL'), style: _mono(10)),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: BrandPalette.ink,
            foregroundColor: BrandPalette.paperLift,
            shape: const RoundedRectangleBorder(),
          ),
          child: Text(
            t('СОХРАНИТЬ', 'SAVE'),
            style: _mono(10, color: BrandPalette.paperLift),
          ),
        ),
      ],
    );
  }
}

class _PromotionDraft {
  const _PromotionDraft({
    required this.description,
    required this.startDate,
    required this.endDate,
    this.startTime,
    this.endTime,
    this.dayPassVnd,
    this.monthPassVnd,
    this.lockerMonthVnd,
  });
  final String description;
  final String startDate;
  final String endDate;
  final String? startTime;
  final String? endTime;
  final int? dayPassVnd;
  final int? monthPassVnd;
  final int? lockerMonthVnd;
}

class _PromotionEditorDialog extends StatefulWidget {
  const _PromotionEditorDialog({required this.russian});
  final bool russian;

  @override
  State<_PromotionEditorDialog> createState() => _PromotionEditorDialogState();
}

class _PromotionEditorDialogState extends State<_PromotionEditorDialog> {
  final _description = TextEditingController();
  final _dayPrice = TextEditingController();
  final _monthPrice = TextEditingController();
  final _lockerPrice = TextEditingController();
  late DateTime _startDate;
  late DateTime _endDate;
  bool _limitTime = false;
  TimeOfDay _startTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 0);
  String? _error;

  String t(String ru, String en) => widget.russian ? ru : en;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = _startDate;
  }

  @override
  void dispose() {
    _description.dispose();
    _dayPrice.dispose();
    _monthPrice.dispose();
    _lockerPrice.dispose();
    super.dispose();
  }

  String _dateValue(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  String _timeValue(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  int? _optionalPrice(TextEditingController controller) {
    final raw = controller.text.trim();
    if (raw.isEmpty) return null;
    final value = int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''));
    return value != null && value > 0 ? value : -1;
  }

  Future<void> _pickDate(bool start) async {
    final current = start ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _startDate = picked;
        if (_endDate.isBefore(picked)) _endDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _startTime : _endTime,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  void _save() {
    final description = _description.text.trim();
    final day = _optionalPrice(_dayPrice);
    final month = _optionalPrice(_monthPrice);
    final locker = _optionalPrice(_lockerPrice);
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    if (description.isEmpty) {
      setState(
        () => _error = t(
          'Добавьте описание акции.',
          'Add a promotion description.',
        ),
      );
      return;
    }
    if ([day, month, locker].contains(-1)) {
      setState(
        () => _error = t(
          'Цена должна быть больше 0.',
          'Price must be greater than 0.',
        ),
      );
      return;
    }
    if (day == null && month == null && locker == null) {
      setState(
        () => _error = t(
          'Укажите хотя бы одну акционную цену.',
          'Set at least one promotional price.',
        ),
      );
      return;
    }
    if (_limitTime && endMinutes <= startMinutes) {
      setState(
        () => _error = t(
          'Время окончания должно быть позже начала.',
          'End time must be after start time.',
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      _PromotionDraft(
        description: description,
        startDate: _dateValue(_startDate),
        endDate: _dateValue(_endDate),
        startTime: _limitTime ? _timeValue(_startTime) : null,
        endTime: _limitTime ? _timeValue(_endTime) : null,
        dayPassVnd: day,
        monthPassVnd: month,
        lockerMonthVnd: locker,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BrandPalette.paper,
      shape: const RoundedRectangleBorder(),
      title: Text(t('Новая акция', 'New promotion'), style: _serif(28)),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _description,
                maxLength: 240,
                decoration: _inputDecoration(t('ОПИСАНИЕ', 'DESCRIPTION')),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(true),
                      child: Text(
                        '${t('С', 'FROM')} ${_dateValue(_startDate)}',
                        style: _mono(9.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(false),
                      child: Text(
                        '${t('ДО', 'TO')} ${_dateValue(_endDate)}',
                        style: _mono(9.5),
                      ),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _limitTime,
                onChanged: (value) => setState(() => _limitTime = value),
                title: Text(
                  t('Ограничить по времени дня', 'Limit by time of day'),
                  style: _serif(16),
                ),
              ),
              if (_limitTime)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickTime(true),
                        child: Text(
                          '${t('С', 'FROM')} ${_timeValue(_startTime)}',
                          style: _mono(9.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickTime(false),
                        child: Text(
                          '${t('ДО', 'TO')} ${_timeValue(_endTime)}',
                          style: _mono(9.5),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Text(
                t(
                  'Акционные цены · оставьте ненужные поля пустыми',
                  'Promo prices · leave unused fields empty',
                ),
                style: _mono(9.5, color: BrandPalette.inkMuted),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _dayPrice,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(t('ДЕНЬ · VND', 'DAY PASS · VND')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _monthPrice,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  t('МЕСЯЦ · VND', 'MONTH PASS · VND'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _lockerPrice,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  t('ШКАФ · VND', 'LOCKER / MONTH · VND'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: _mono(9.5)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('ОТМЕНА', 'CANCEL'), style: _mono(10)),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: BrandPalette.ink,
            foregroundColor: BrandPalette.paperLift,
            shape: const RoundedRectangleBorder(),
          ),
          child: Text(
            t('ЗАПУСТИТЬ', 'RUN PROMO'),
            style: _mono(10, color: BrandPalette.paperLift),
          ),
        ),
      ],
    );
  }
}

class _MetricCard {
  const _MetricCard(this.label, this.value);

  final String label;
  final String value;
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: _mono(9),
    floatingLabelStyle: _mono(9),
    filled: true,
    fillColor: BrandPalette.paperLift,
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 16),
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

ButtonStyle _darkButton({double minHeight = 48}) {
  return FilledButton.styleFrom(
    foregroundColor: BrandPalette.paperLift,
    backgroundColor: BrandPalette.ink,
    minimumSize: Size(0, minHeight),
    shape: const RoundedRectangleBorder(),
  );
}

ButtonStyle _outlineButton({double minHeight = 48}) {
  return OutlinedButton.styleFrom(
    foregroundColor: BrandPalette.ink,
    minimumSize: const Size(0, 46),
    side: const BorderSide(color: BrandPalette.ink),
    shape: const RoundedRectangleBorder(),
  );
}

TextStyle _serif(
  double size, {
  Color color = BrandPalette.ink,
  double height = 1.08,
}) {
  return TextStyle(
    color: color,
    fontFamily: 'Georgia',
    fontFamilyFallback: const ['Times New Roman', 'serif'],
    fontSize: size,
    height: height,
  );
}

TextStyle _mono(
  double size, {
  Color color = BrandPalette.ink,
  double spacing = 0.35,
  double height = 1.2,
}) {
  return TextStyle(
    color: color,
    fontFamily: 'Courier New',
    fontFamilyFallback: const ['monospace'],
    fontSize: size,
    fontWeight: FontWeight.w700,
    letterSpacing: spacing,
    height: height,
  );
}
