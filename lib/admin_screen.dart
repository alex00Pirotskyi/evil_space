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
  Timer? _refreshTimer;
  OperationsSnapshot? _snapshot;
  int _section = 0;
  int _incomePeriod = 0;
  int _purchaseTab = 0;
  bool _russian = true;
  bool _busy = false;
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
    super.dispose();
  }

  String t(String ru, String en) => _russian ? ru : en;

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _error = null);
    }
    try {
      final snapshot = await widget.api.operations();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
      });
    } on AdminApiException catch (error) {
      if (!mounted || silent) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted || silent) return;
      setState(() => _error = t('Не удалось загрузить данные.', 'Could not load data.'));
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
      final snapshot = await action();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _busy = false;
      });
      if (success != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success)),
        );
      }
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
    final snapshot = _snapshot;
    if (snapshot == null || _busy) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _AddCustomerDialog(
        russian: _russian,
        memberships: snapshot.activeMemberships,
        onDayPass: (name) async {
          Navigator.of(dialogContext).pop();
          await _apply(
            () => widget.api.addDayPass(name),
            success: t('Дневной пропуск добавлен', 'Day pass added'),
          );
        },
        onNewMonth: (name) async {
          Navigator.of(dialogContext).pop();
          await _apply(
            () => widget.api.addMonthPass(name),
            success: t('Абонемент на месяц добавлен', 'Month pass added'),
          );
        },
        onActiveMonth: (membership) async {
          Navigator.of(dialogContext).pop();
          await _apply(
            () => widget.api.checkInMembership(membership.id),
            success: t('Клиент отмечен', 'Customer checked in'),
          );
        },
      ),
    );
  }

  Future<void> _addPurchase() async {
    final title = _purchaseController.text.trim();
    if (title.isEmpty) return;
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
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: BrandPalette.ink)),
                  ),
                  child: Text(_error!, style: _mono(11)),
                ),
              Expanded(
                child: snapshot == null
                    ? const Center(
                        child: CircularProgressIndicator(color: BrandPalette.ink),
                      )
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
    final labels = [
      t('СЕГОДНЯ', 'TODAY'),
      t('МЕСЯЦ', 'MONTH'),
      t('ДОХОД', 'INCOME'),
      '${t('КУПИТЬ', 'BUY')}${snapshot == null || snapshot.toBuy.isEmpty ? '' : ' ${snapshot.toBuy.length}'}',
    ];
    final icons = const [
      Icons.today_outlined,
      Icons.calendar_month_outlined,
      Icons.payments_outlined,
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
          return TextButton.icon(
            onPressed: () => setState(() => _section = index),
            icon: Icon(icons[index], size: 18),
            label: Text(labels[index], style: _mono(10)),
            style: TextButton.styleFrom(
              foregroundColor: selected ? BrandPalette.paperLift : BrandPalette.ink,
              backgroundColor: selected ? BrandPalette.ink : Colors.transparent,
              minimumSize: const Size(118, 44),
              shape: const RoundedRectangleBorder(),
            ),
          );
        },
      ),
    );
  }

  Widget _body(OperationsSnapshot snapshot) {
    return switch (_section) {
      0 => _today(snapshot),
      1 => _month(snapshot),
      2 => _income(snapshot),
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
      FilledButton.icon(
        onPressed: _busy ? null : _showAddCustomer,
        icon: const Icon(Icons.person_add_alt_1, size: 22),
        label: Text(t('ДОБАВИТЬ КЛИЕНТА', 'ADD CUSTOMER'), style: _mono(13, color: BrandPalette.paperLift)),
        style: _primaryButton(),
      ),
      const SizedBox(height: 16),
      _metricRow([
        _MetricCard(t('ЛЮДЕЙ СЕГОДНЯ', 'PEOPLE TODAY'), '${snapshot.todayVisits.length}'),
        _MetricCard(t('ДОХОД СЕГОДНЯ', 'TODAY INCOME'), _money(snapshot.income.today)),
        _MetricCard(t('АКТИВНЫХ МЕСЯЦЕВ', 'ACTIVE MONTHS'), '${snapshot.activeMemberships.length}'),
      ]),
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

  Widget _month(OperationsSnapshot snapshot) {
    return _page([
      _metricRow([
        _MetricCard(t('АКТИВНЫЕ', 'ACTIVE'), '${snapshot.activeMemberships.length}'),
        _MetricCard(t('МЕСЯЦ ДОХОД', '30D INCOME'), _money(snapshot.income.thirtyDays)),
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
          return OutlinedButton(
            onPressed: () => setState(() => _incomePeriod = index),
            style: OutlinedButton.styleFrom(
              foregroundColor: selected ? BrandPalette.paperLift : BrandPalette.ink,
              backgroundColor: selected ? BrandPalette.ink : Colors.transparent,
              minimumSize: const Size(120, 48),
              side: const BorderSide(color: BrandPalette.ink),
              shape: const RoundedRectangleBorder(),
            ),
            child: Text(labels[index], style: _mono(10, color: selected ? BrandPalette.paperLift : BrandPalette.ink)),
          );
        }),
      ),
      const SizedBox(height: 28),
      Container(
        padding: const EdgeInsets.symmetric(vertical: 34),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: BrandPalette.ink), bottom: BorderSide(color: BrandPalette.ink)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(labels[_incomePeriod], style: _mono(11, color: BrandPalette.inkMuted)),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(_money(values[_incomePeriod]), style: _serif(48)),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buy(OperationsSnapshot snapshot) {
    final needed = _purchaseTab == 0;
    return _page([
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _purchaseController,
              enabled: !_busy,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addPurchase(),
              decoration: _input(t('Что купить?', 'What to buy?')),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _busy ? null : _addPurchase,
            style: _primaryButton(minWidth: 118),
            child: Text(t('ДОБАВИТЬ', 'ADD'), style: _mono(11, color: BrandPalette.paperLift)),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(child: _purchaseTabButton(0, '${t('КУПИТЬ', 'TO BUY')} (${snapshot.toBuy.length})')),
          const SizedBox(width: 8),
          Expanded(child: _purchaseTabButton(1, t('ИСТОРИЯ', 'HISTORY'))),
        ],
      ),
      const SizedBox(height: 18),
      if (needed && snapshot.toBuy.isEmpty)
        _empty(t('Список пуст.', 'Nothing to buy.'))
      else if (needed)
        ...snapshot.toBuy.map(
          (item) => _purchaseRow(
            item,
            action: TextButton(
              onPressed: _busy ? null : () => _apply(
                () => widget.api.markPurchaseBought(item.id),
                success: t('Перемещено в историю', 'Moved to history'),
              ),
              style: TextButton.styleFrom(
                foregroundColor: BrandPalette.paperLift,
                backgroundColor: BrandPalette.ink,
                minimumSize: const Size(94, 42),
                shape: const RoundedRectangleBorder(),
              ),
              child: Text(t('КУПЛЕНО', 'BOUGHT'), style: _mono(9.5, color: BrandPalette.paperLift)),
            ),
          ),
        )
      else if (snapshot.purchaseHistory.isEmpty)
        _empty(t('История пока пустая.', 'History is empty.'))
      else
        ...snapshot.purchaseHistory.map((item) => _purchaseRow(item)),
    ]);
  }

  Widget _purchaseTabButton(int index, String label) {
    final selected = _purchaseTab == index;
    return OutlinedButton(
      onPressed: () => setState(() => _purchaseTab = index),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? BrandPalette.paperLift : BrandPalette.ink,
        backgroundColor: selected ? BrandPalette.ink : Colors.transparent,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: BrandPalette.ink),
        shape: const RoundedRectangleBorder(),
      ),
      child: Text(label, style: _mono(10, color: selected ? BrandPalette.paperLift : BrandPalette.ink)),
    );
  }

  Widget _purchaseRow(PurchaseRequestRecord item, {Widget? action}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: BrandPalette.rule))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: _serif(18)),
                const SizedBox(height: 5),
                Text(
                  item.status == 'bought'
                      ? '${t('КУПЛЕНО', 'BOUGHT')} · ${_dateTime(item.boughtAt ?? item.createdAt)}'
                      : '${t('ДОБАВЛЕНО', 'ADDED')} · ${_dateTime(item.createdAt)}',
                  style: _mono(9.5, color: BrandPalette.inkMuted),
                ),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 10), action],
        ],
      ),
    );
  }

  Widget _smallToggle(String label, bool selected, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: selected ? BrandPalette.paperLift : BrandPalette.ink,
        backgroundColor: selected ? BrandPalette.ink : Colors.transparent,
        minimumSize: const Size(42, 40),
        padding: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(),
      ),
      child: Text(label, style: _mono(9.5, color: selected ? BrandPalette.paperLift : BrandPalette.ink)),
    );
  }

  Widget _metricRow(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 680;
        if (!wide) {
          return Column(
            children: cards
                .map((card) => Padding(padding: const EdgeInsets.only(bottom: 8), child: card))
                .toList(growable: false),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cards
              .map((card) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: card)))
              .toList(growable: false),
        );
      },
    );
  }

  Widget _sectionTitle(String label) {
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: BrandPalette.ink))),
      child: Text(label, style: _mono(11)),
    );
  }

  Widget _empty(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Text(text, style: _serif(18, color: BrandPalette.inkMuted)),
    );
  }

  Widget _row(String title, String meta, String end) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: BrandPalette.rule))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _serif(18)),
                const SizedBox(height: 5),
                Text(meta, style: _mono(9.5, color: BrandPalette.inkMuted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(end, style: _mono(10)),
        ],
      ),
    );
  }

  ButtonStyle _primaryButton({double minWidth = 0}) {
    return FilledButton.styleFrom(
      foregroundColor: BrandPalette.paperLift,
      backgroundColor: BrandPalette.ink,
      disabledForegroundColor: BrandPalette.paperLift,
      disabledBackgroundColor: BrandPalette.inkMuted,
      minimumSize: Size(minWidth, 56),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      shape: const RoundedRectangleBorder(),
    );
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: _mono(10),
      floatingLabelStyle: _mono(9),
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

  String _money(int amount) {
    if (amount == 0) return '0 VND';
    if (amount % 1000000 == 0) return '${amount ~/ 1000000} MLN VND';
    if (amount >= 1000000) {
      final value = amount / 1000000;
      final text = value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      return '$text MLN VND';
    }
    return '${amount ~/ 1000}K VND';
  }

  DateTime _nhaTrang(int seconds) {
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true)
        .add(const Duration(hours: 7));
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _time(int seconds) {
    final value = _nhaTrang(seconds);
    return '${_two(value.hour)}:${_two(value.minute)}';
  }

  String _date(int seconds) {
    final value = _nhaTrang(seconds);
    return '${_two(value.day)}.${_two(value.month)}.${value.year}';
  }

  String _dateTime(int seconds) => '${_date(seconds)} ${_time(seconds)}';

  int _daysLeft(int expiresAt) {
    final seconds = expiresAt - DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (seconds <= 0) return 0;
    return (seconds / 86400).ceil();
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: BrandPalette.ink)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: _mono(9.5)),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: _serif(28)),
          ),
        ],
      ),
    );
  }
}

class _AddCustomerDialog extends StatefulWidget {
  const _AddCustomerDialog({
    required this.russian,
    required this.memberships,
    required this.onDayPass,
    required this.onNewMonth,
    required this.onActiveMonth,
  });

  final bool russian;
  final List<MembershipRecord> memberships;
  final ValueChanged<String> onDayPass;
  final ValueChanged<String> onNewMonth;
  final ValueChanged<MembershipRecord> onActiveMonth;

  @override
  State<_AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<_AddCustomerDialog> {
  final _nameController = TextEditingController();
  int _mode = 0;
  MembershipRecord? _membership;

  String t(String ru, String en) => widget.russian ? ru : en;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: BrandPalette.paper,
      shape: const RoundedRectangleBorder(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t('ДОБАВИТЬ КЛИЕНТА', 'ADD CUSTOMER'), style: _mono(11)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _modeButton(0, t('ДЕНЬ', 'DAY'))),
                  const SizedBox(width: 6),
                  Expanded(child: _modeButton(1, t('НОВЫЙ МЕСЯЦ', 'NEW MONTH'))),
                  const SizedBox(width: 6),
                  Expanded(child: _modeButton(2, t('АКТИВНЫЙ', 'ACTIVE'))),
                ],
              ),
              const SizedBox(height: 18),
              if (_mode < 2)
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: _dialogInput(t('Имя', 'Name')),
                )
              else if (widget.memberships.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    t('Нет активных абонементов.', 'No active memberships.'),
                    style: _serif(17, color: BrandPalette.inkMuted),
                  ),
                )
              else
                Autocomplete<MembershipRecord>(
                  displayStringForOption: (option) => option.name,
                  optionsBuilder: (value) {
                    final query = value.text.trim().toLowerCase();
                    if (query.isEmpty) return widget.memberships;
                    return widget.memberships.where(
                      (item) => item.name.toLowerCase().contains(query),
                    );
                  },
                  onSelected: (value) => setState(() => _membership = value),
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: true,
                      decoration: _dialogInput(t('Активный клиент', 'Active member')),
                      onSubmitted: (_) => _submit(),
                    );
                  },
                ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _mode == 2 && widget.memberships.isEmpty ? null : _submit,
                style: FilledButton.styleFrom(
                  foregroundColor: BrandPalette.paperLift,
                  backgroundColor: BrandPalette.ink,
                  minimumSize: const Size.fromHeight(54),
                  shape: const RoundedRectangleBorder(),
                ),
                child: Text(
                  _mode == 2 ? t('ОТМЕТИТЬ', 'CHECK IN') : t('ДОБАВИТЬ', 'ADD'),
                  style: _mono(11, color: BrandPalette.paperLift),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t('ОТМЕНА', 'CANCEL'), style: _mono(10)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeButton(int mode, String label) {
    final selected = _mode == mode;
    return OutlinedButton(
      onPressed: () => setState(() {
        _mode = mode;
        _membership = null;
        _nameController.clear();
      }),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? BrandPalette.paperLift : BrandPalette.ink,
        backgroundColor: selected ? BrandPalette.ink : Colors.transparent,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        side: const BorderSide(color: BrandPalette.ink),
        shape: const RoundedRectangleBorder(),
      ),
      child: Text(label, textAlign: TextAlign.center, style: _mono(9.3, color: selected ? BrandPalette.paperLift : BrandPalette.ink)),
    );
  }

  void _submit() {
    if (_mode == 2) {
      final membership = _membership;
      if (membership != null) widget.onActiveMonth(membership);
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    if (_mode == 0) {
      widget.onDayPass(name);
    } else {
      widget.onNewMonth(name);
    }
  }

  InputDecoration _dialogInput(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: _mono(10),
      filled: true,
      fillColor: BrandPalette.paperLift,
      border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: BrandPalette.ink, width: 2),
        borderRadius: BorderRadius.zero,
      ),
    );
  }
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
