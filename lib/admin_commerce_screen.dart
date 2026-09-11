import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'brand_logo.dart';
import 'brand_surface.dart';
import 'menu_api.dart';

class AdminCommerceScreen extends StatefulWidget {
  const AdminCommerceScreen({super.key, required this.api, required this.onBack});
  final MenuApi api;
  final VoidCallback onBack;

  @override
  State<AdminCommerceScreen> createState() => _AdminCommerceScreenState();
}

enum _CommerceTab { menu, promos, customers, orders }

class _AdminCommerceScreenState extends State<AdminCommerceScreen> {
  _CommerceTab _tab = _CommerceTab.menu;
  AdminMenuSnapshot? _snapshot;
  MenuDraftSnapshot? _draft;
  List<AdminPromotion> _promos = const [];
  List<AdminCustomerSummary> _customers = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Timer? _timer;
  final _customerSearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAll();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _refreshOrders());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _customerSearch.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait<Object>([
        widget.api.adminSnapshot(),
        widget.api.menuDraft(),
        widget.api.adminPromotions(),
        widget.api.adminCustomers(),
      ]);
      if (!mounted) return;
      setState(() {
        _snapshot = values[0] as AdminMenuSnapshot;
        _draft = values[1] as MenuDraftSnapshot;
        _promos = values[2] as List<AdminPromotion>;
        _customers = values[3] as List<AdminCustomerSummary>;
        _loading = false;
      });
    } on MenuApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load commerce admin.';
      });
    }
  }

  Future<void> _refreshOrders() async {
    if (_busy) return;
    try {
      final snapshot = await widget.api.adminSnapshot();
      if (mounted) setState(() => _snapshot = snapshot);
    } catch (_) {}
  }

  MenuCatalog get _editableMenu => _draft?.menu ?? const MenuCatalog.empty();

  void _replaceMenu(List<MenuGroup> groups) {
    final current = _editableMenu;
    setState(() {
      _draft = MenuDraftSnapshot(
        source: 'draft-local',
        baseCatalogId: _draft?.baseCatalogId,
        updatedAt: _draft?.updatedAt ?? 0,
        updatedByEmail: _draft?.updatedByEmail ?? '',
        menu: MenuCatalog(
          version: current.version <= 0 ? 1 : current.version,
          updatedAt: current.updatedAt,
          groups: groups,
        ),
        promoReferences: _draft?.promoReferences ?? const {},
      );
    });
  }

  Future<void> _saveDraft() async {
    if (_busy) return;
    await _runBusy(() async {
      final draft = await widget.api.saveMenuDraft(_editableMenu);
      if (mounted) setState(() => _draft = draft);
      _toast('Draft saved.');
    });
  }

  Future<void> _publish() async {
    if (_busy) return;
    final yes = await _confirm(
      'PUBLISH MENU?',
      'The current draft will become the live customer menu. Existing orders keep their original prices.',
      'PUBLISH',
    );
    if (yes != true || !mounted) return;
    await _runBusy(() async {
      final result = await widget.api.publishMenuDraft(_editableMenu);
      if (mounted) {
        setState(() {
          _snapshot = result.$1;
          _draft = result.$2;
        });
      }
      _toast('Menu published.');
    });
  }

  Future<void> _importJson() async {
    if (_busy) return;
    try {
      final raw = await widget.api.pickMenuJson();
      if (raw == null || !mounted) return;
      final menu = MenuCatalog.fromJson(raw);
      final draft = await widget.api.saveMenuDraft(menu);
      if (!mounted) return;
      setState(() => _draft = draft);
      _toast('JSON imported to draft. Review it before publishing.');
    } on MenuApiException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError('Could not import this menu JSON.');
    }
  }

  Future<void> _showJson() async {
    final pretty = const JsonEncoder.withIndent('  ').convert(_editableMenu.toJson());
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BrandPalette.paper,
        shape: const RoundedRectangleBorder(),
        title: Text('MENU JSON · ADVANCED', style: _serif(24)),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: SelectableText(pretty, style: _mono(10, height: 1.4)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('CLOSE', style: _mono(10))),
        ],
      ),
    );
  }

  Future<void> _addGroup() async {
    final group = await _groupDialog();
    if (group == null) return;
    _replaceMenu([..._editableMenu.groups, group]);
  }

  Future<void> _editGroup(int index) async {
    final current = _editableMenu.groups[index];
    final group = await _groupDialog(current: current);
    if (group == null) return;
    final groups = [..._editableMenu.groups]..[index] = group;
    _replaceMenu(groups);
  }

  Future<void> _deleteGroup(int index) async {
    final group = _editableMenu.groups[index];
    final refs = _draft?.promoReferences[group.id] ?? const [];
    final body = refs.isEmpty
        ? 'Delete ${group.name.en} and all of its items from this draft?'
        : '${group.name.en} is used by ${refs.length} active promo${refs.length == 1 ? '' : 's'}: ${refs.map((e) => e.name).join(', ')}. Deleting the group will make those promos ineligible until edited.';
    final yes = await _confirm('DELETE GROUP?', body, 'DELETE');
    if (yes != true) return;
    final groups = [..._editableMenu.groups]..removeAt(index);
    _replaceMenu(groups);
  }

  void _moveGroup(int from, int delta) {
    final to = from + delta;
    if (to < 0 || to >= _editableMenu.groups.length) return;
    final groups = [..._editableMenu.groups];
    final group = groups.removeAt(from);
    groups.insert(to, group);
    _replaceMenu(groups);
  }

  Future<void> _addItem(int groupIndex) async {
    final item = await _itemDialog();
    if (item == null) return;
    final groups = [..._editableMenu.groups];
    final group = groups[groupIndex];
    groups[groupIndex] = MenuGroup(id: group.id, name: group.name, items: [...group.items, item]);
    _replaceMenu(groups);
  }

  Future<void> _editItem(int groupIndex, int itemIndex) async {
    final groups = [..._editableMenu.groups];
    final group = groups[groupIndex];
    final item = await _itemDialog(current: group.items[itemIndex]);
    if (item == null) return;
    final items = [...group.items]..[itemIndex] = item;
    groups[groupIndex] = MenuGroup(id: group.id, name: group.name, items: items);
    _replaceMenu(groups);
  }

  void _moveItem(int groupIndex, int from, int delta) {
    final groups = [..._editableMenu.groups];
    final group = groups[groupIndex];
    final to = from + delta;
    if (to < 0 || to >= group.items.length) return;
    final items = [...group.items];
    final item = items.removeAt(from);
    items.insert(to, item);
    groups[groupIndex] = MenuGroup(id: group.id, name: group.name, items: items);
    _replaceMenu(groups);
  }

  Future<void> _deleteItem(int groupIndex, int itemIndex) async {
    final group = _editableMenu.groups[groupIndex];
    final item = group.items[itemIndex];
    final yes = await _confirm('DELETE ITEM?', 'Delete ${item.name} from this draft?', 'DELETE');
    if (yes != true) return;
    final groups = [..._editableMenu.groups];
    final items = [...group.items]..removeAt(itemIndex);
    groups[groupIndex] = MenuGroup(id: group.id, name: group.name, items: items);
    _replaceMenu(groups);
  }

  Future<MenuGroup?> _groupDialog({MenuGroup? current}) async {
    final id = TextEditingController(text: current?.id ?? '');
    final en = TextEditingController(text: current?.name.en ?? '');
    final ru = TextEditingController(text: current?.name.ru ?? '');
    final vi = TextEditingController(text: current?.name.vi ?? '');
    final result = await showDialog<MenuGroup>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BrandPalette.paper,
        shape: const RoundedRectangleBorder(),
        title: Text(current == null ? 'NEW GROUP' : 'EDIT GROUP', style: _serif(25)),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(id, 'STABLE ID', enabled: current == null),
              _field(en, 'ENGLISH'),
              _field(ru, 'RUSSIAN'),
              _field(vi, 'VIETNAMESE'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: _mono(10))),
          FilledButton(
            style: _darkButton(),
            onPressed: () {
              final stableId = _slug(id.text);
              if (stableId.isEmpty || en.text.trim().isEmpty || ru.text.trim().isEmpty || vi.text.trim().isEmpty) return;
              Navigator.pop(
                context,
                MenuGroup(
                  id: stableId,
                  name: MenuLocalizedText(en: en.text.trim(), ru: ru.text.trim(), vi: vi.text.trim()),
                  items: current?.items ?? const [],
                ),
              );
            },
            child: Text('SAVE', style: _mono(10, color: BrandPalette.paperLift)),
          ),
        ],
      ),
    );
    id.dispose(); en.dispose(); ru.dispose(); vi.dispose();
    return result;
  }

  Future<MenuItem?> _itemDialog({MenuItem? current}) async {
    final id = TextEditingController(text: current?.id ?? '');
    final name = TextEditingController(text: current?.name ?? '');
    final price = TextEditingController(text: current?.priceVnd.toString() ?? '');
    final description = TextEditingController(text: current?.description ?? '');
    var enabled = current?.enabled ?? true;
    final result = await showDialog<MenuItem>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: BrandPalette.paper,
          shape: const RoundedRectangleBorder(),
          title: Text(current == null ? 'NEW ITEM' : 'EDIT ITEM', style: _serif(25)),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(id, 'STABLE ID', enabled: current == null),
                _field(name, 'NAME'),
                _field(price, 'PRICE VND', keyboardType: TextInputType.number),
                _field(description, 'DESCRIPTION · OPTIONAL'),
                CheckboxListTile(
                  value: enabled,
                  contentPadding: EdgeInsets.zero,
                  title: Text('ACTIVE', style: _mono(10)),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) => setLocal(() => enabled = value ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: _mono(10))),
            FilledButton(
              style: _darkButton(),
              onPressed: () {
                final stableId = _slug(id.text);
                final value = int.tryParse(price.text.replaceAll(',', '').trim());
                if (stableId.isEmpty || name.text.trim().isEmpty || value == null || value <= 0) return;
                Navigator.pop(
                  context,
                  MenuItem(
                    id: stableId,
                    name: name.text.trim(),
                    priceVnd: value,
                    enabled: enabled,
                    description: description.text.trim().isEmpty ? null : description.text.trim(),
                  ),
                );
              },
              child: Text('SAVE', style: _mono(10, color: BrandPalette.paperLift)),
            ),
          ],
        ),
      ),
    );
    id.dispose(); name.dispose(); price.dispose(); description.dispose();
    return result;
  }

  Future<void> _newPromo() async {
    final payload = await _promoDialog();
    if (payload == null) return;
    await _runBusy(() async {
      final promos = await widget.api.createPromotion(payload);
      if (mounted) setState(() => _promos = promos);
      _toast('Promo created.');
    });
  }

  Future<void> _editPromo(AdminPromotion promo) async {
    final payload = await _promoDialog(current: promo);
    if (payload == null) return;
    payload['id'] = promo.id;
    await _runBusy(() async {
      final promos = await widget.api.updatePromotion(payload);
      if (mounted) setState(() => _promos = promos);
      _toast('New promo revision created. Existing grants keep their old rules.');
    });
  }

  Future<void> _disablePromo(AdminPromotion promo) async {
    final yes = await _confirm('DISABLE PROMO?', '${promo.name} will stop being usable, including existing unused grants.', 'DISABLE');
    if (yes != true) return;
    await _runBusy(() async {
      final promos = await widget.api.disablePromotion(promo.id);
      if (mounted) setState(() => _promos = promos);
    });
  }

  Future<Map<String, dynamic>?> _promoDialog({AdminPromotion? current}) async {
    final name = TextEditingController(text: current?.name ?? '');
    final key = TextEditingController(text: current?.promoKey ?? '');
    final code = TextEditingController(text: current?.code ?? '');
    final value = TextEditingController(text: current?.discountValue.toString() ?? '50');
    final maxDiscount = TextEditingController(text: current?.maxDiscountVnd?.toString() ?? '');
    final minimum = TextEditingController(text: current?.minimumSubtotalVnd.toString() ?? '0');
    final uses = TextEditingController(text: current?.maxUsesPerCustomer.toString() ?? '1');
    final totalUses = TextEditingController(text: current?.maxTotalUses?.toString() ?? '');
    final description = TextEditingController(text: current?.description ?? '');
    var discountType = current?.discountType ?? 'percent';
    var distribution = current?.distributionType ?? 'manual';
    final selectedGroups = <String>{...?current?.groupIds};
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: BrandPalette.paper,
          shape: const RoundedRectangleBorder(),
          title: Text(current == null ? 'CREATE PROMO' : 'EDIT PROMO', style: _serif(25)),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _field(name, 'NAME'),
                  _field(key, 'STABLE PROMO KEY', enabled: current == null),
                  _field(description, 'DESCRIPTION · OPTIONAL'),
                  _field(code, 'PUBLIC CODE · OPTIONAL'),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: discountType,
                        decoration: _inputDecoration('DISCOUNT TYPE'),
                        items: const [
                          DropdownMenuItem(value: 'percent', child: Text('Percent')),
                          DropdownMenuItem(value: 'fixed_vnd', child: Text('Fixed VND')),
                        ],
                        onChanged: (v) => setLocal(() => discountType = v ?? 'percent'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _field(value, discountType == 'percent' ? 'PERCENT' : 'VND', keyboardType: TextInputType.number)),
                  ]),
                  Row(children: [
                    Expanded(child: _field(maxDiscount, 'MAX DISCOUNT · OPTIONAL', keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: _field(minimum, 'MINIMUM PURCHASE', keyboardType: TextInputType.number)),
                  ]),
                  Row(children: [
                    Expanded(child: _field(uses, 'USES / CUSTOMER', keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: _field(totalUses, 'TOTAL USES · OPTIONAL', keyboardType: TextInputType.number)),
                  ]),
                  DropdownButtonFormField<String>(
                    initialValue: distribution,
                    decoration: _inputDecoration('WHO GETS IT'),
                    items: const [
                      DropdownMenuItem(value: 'signup', child: Text('Automatically on signup')),
                      DropdownMenuItem(value: 'manual', child: Text('Specific customers / manual')),
                      DropdownMenuItem(value: 'everyone', child: Text('Everyone')),
                      DropdownMenuItem(value: 'code', child: Text('Promo code only')),
                    ],
                    onChanged: (v) => setLocal(() => distribution = v ?? 'manual'),
                  ),
                  const SizedBox(height: 15),
                  Text('APPLIES TO GROUPS', style: _mono(10)),
                  const SizedBox(height: 5),
                  if (_editableMenu.groups.isEmpty)
                    Text('Publish or build a menu first.', style: _serif(15, color: BrandPalette.inkMuted))
                  else
                    for (final group in _editableMenu.groups)
                      CheckboxListTile(
                        value: selectedGroups.contains(group.id),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(group.name.en, style: _serif(16)),
                        subtitle: Text(group.id, style: _mono(8.5, color: BrandPalette.inkMuted)),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (checked) => setLocal(() {
                          if (checked == true) selectedGroups.add(group.id); else selectedGroups.remove(group.id);
                        }),
                      ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: _mono(10))),
            FilledButton(
              style: _darkButton(),
              onPressed: () {
                final promoKey = _slug(key.text.isEmpty ? name.text : key.text).toUpperCase();
                final discount = int.tryParse(value.text.trim());
                final useCount = int.tryParse(uses.text.trim());
                if (name.text.trim().isEmpty || promoKey.isEmpty || discount == null || discount <= 0 || useCount == null || useCount <= 0) return;
                Navigator.pop(context, {
                  'promoKey': promoKey,
                  'name': name.text.trim(),
                  'description': description.text.trim(),
                  'code': code.text.trim().isEmpty ? null : code.text.trim().toUpperCase(),
                  'discountType': discountType,
                  'discountValue': discount,
                  'maxDiscountVnd': _nullableInt(maxDiscount.text),
                  'minimumSubtotalVnd': int.tryParse(minimum.text.trim()) ?? 0,
                  'validFrom': 0,
                  'expiresAt': current?.expiresAt,
                  'maxUsesPerCustomer': useCount,
                  'maxTotalUses': _nullableInt(totalUses.text),
                  'distributionType': distribution,
                  'groupIds': selectedGroups.toList(growable: false),
                  'includeItemIds': current?.includeItemIds ?? const <String>[],
                  'excludeItemIds': current?.excludeItemIds ?? const <String>[],
                });
              },
              child: Text(current == null ? 'CREATE' : 'SAVE REVISION', style: _mono(10, color: BrandPalette.paperLift)),
            ),
          ],
        ),
      ),
    );
    name.dispose(); key.dispose(); code.dispose(); value.dispose(); maxDiscount.dispose(); minimum.dispose(); uses.dispose(); totalUses.dispose(); description.dispose();
    return result;
  }

  Future<void> _searchCustomers() async {
    try {
      final customers = await widget.api.adminCustomers(query: _customerSearch.text.trim());
      if (mounted) setState(() => _customers = customers);
    } on MenuApiException catch (e) {
      _setError(e.message);
    }
  }

  Future<void> _openCustomer(AdminCustomerSummary customer) async {
    AdminCustomerDetail detail;
    try {
      detail = await widget.api.adminCustomer(customer.id);
    } on MenuApiException catch (e) {
      _setError(e.message);
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> grant() async {
            final active = _promos.where((p) => p.active).toList(growable: false);
            if (active.isEmpty) return;
            final selected = await showDialog<AdminPromotion>(
              context: context,
              builder: (context) => SimpleDialog(
                backgroundColor: BrandPalette.paper,
                title: Text('GRANT PROMO', style: _serif(24)),
                children: [
                  for (final promo in active)
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, promo),
                      child: Text('${promo.name} · ${_discountLabel(promo)}', style: _serif(17)),
                    ),
                ],
              ),
            );
            if (selected == null) return;
            final next = await widget.api.grantCustomerPromo(customerId: customer.id, promotionId: selected.id);
            detail = next;
            setLocal(() {});
          }

          Future<void> revoke(CustomerPromo promo) async {
            final next = await widget.api.revokeCustomerPromo(promo.id);
            detail = next;
            setLocal(() {});
          }

          return AlertDialog(
            backgroundColor: BrandPalette.paper,
            shape: const RoundedRectangleBorder(),
            title: Text(detail.name.toUpperCase(), style: _serif(26)),
            content: SizedBox(
              width: 640,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text([detail.email, detail.phone, detail.telegram].whereType<String>().join(' · '), style: _mono(9, color: BrandPalette.inkMuted)),
                    const SizedBox(height: 20),
                    Row(children: [
                      Text('PROMOS · ${detail.promos.length}', style: _mono(10)),
                      const Spacer(),
                      TextButton.icon(onPressed: grant, icon: const Icon(Icons.add, size: 17), label: Text('GRANT PROMO', style: _mono(9))),
                    ]),
                    for (final promo in detail.promos)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: BrandPalette.rule))),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(promo.name, style: _serif(17)),
                            Text('${promo.discountLabel} · ${promo.remainingUses} AVAILABLE · ${promo.status.toUpperCase()}', style: _mono(8.5, color: BrandPalette.inkMuted)),
                          ])),
                          if (promo.status == 'active' && promo.reservedUses == 0)
                            TextButton(onPressed: () => revoke(promo), child: Text('REVOKE', style: _mono(8.5))),
                        ]),
                      ),
                    const SizedBox(height: 18),
                    Text('MENU ORDERS · ${detail.menuOrders}', style: _mono(10)),
                  ],
                ),
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('CLOSE', style: _mono(10)))],
          );
        },
      ),
    );
    await _searchCustomers();
  }

  Future<void> _markPaid(AdminMenuOrder order) async {
    final yes = await _confirm(
      'CONFIRM BANK PAYMENT?',
      '${order.itemName}\n${_money(order.amountVnd)}\n${order.paymentMessage}',
      'MARK PAID',
    );
    if (yes != true) return;
    await _runBusy(() async {
      final snapshot = await widget.api.markPaid(order.id);
      if (mounted) setState(() => _snapshot = snapshot);
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await action();
    } on MenuApiException catch (error) {
      _setError(error.message);
    } catch (_) {
      _setError('Request failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setError(String value) {
    if (mounted) setState(() => _error = value);
  }

  void _toast(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<bool?> _confirm(String title, String body, String action) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: BrandPalette.paper,
          shape: const RoundedRectangleBorder(),
          title: Text(title, style: _serif(24)),
          content: Text(body, style: _serif(16, height: 1.4)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('CANCEL', style: _mono(10))),
            FilledButton(style: _darkButton(), onPressed: () => Navigator.pop(context, true), child: Text(action, style: _mono(10, color: BrandPalette.paperLift))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandPalette.paper,
      body: BrandPaper(
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              _tabs(),
              Expanded(
                child: RefreshIndicator(
                  color: BrandPalette.ink,
                  onRefresh: _loadAll,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 70),
                    children: [
                      if (_error != null) _errorBox(_error!),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(50),
                          child: Center(child: CircularProgressIndicator(color: BrandPalette.ink)),
                        )
                      else
                        switch (_tab) {
                          _CommerceTab.menu => _menuTab(),
                          _CommerceTab.promos => _promoTab(),
                          _CommerceTab.customers => _customersTab(),
                          _CommerceTab.orders => _ordersTab(),
                        },
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: BrandPalette.ink))),
        child: Row(children: [
          const EvilCoworkingLogo(width: 108),
          const Spacer(),
          TextButton.icon(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back, size: 18), label: Text('ADMIN', style: _mono(10))),
        ]),
      );

  Widget _tabs() => Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: BrandPalette.rule))),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _tabButton(_CommerceTab.menu, 'MENU'),
              _tabButton(_CommerceTab.promos, 'PROMOS'),
              _tabButton(_CommerceTab.customers, 'CUSTOMERS'),
              _tabButton(_CommerceTab.orders, 'ORDERS'),
            ],
          ),
        ),
      );

  Widget _tabButton(_CommerceTab tab, String label) => TextButton(
        onPressed: () => setState(() => _tab = tab),
        style: TextButton.styleFrom(
          foregroundColor: BrandPalette.ink,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: const RoundedRectangleBorder(),
        ),
        child: Text(label, style: _mono(10, color: _tab == tab ? BrandPalette.ink : BrandPalette.inkMuted)),
      );

  Widget _menuTab() {
    final menu = _editableMenu;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('MENU BUILDER', style: _serif(40)),
      const SizedBox(height: 7),
      Text('Build the menu visually. JSON stays available as the advanced import/export format. Changes remain a draft until you publish.', style: _serif(16, color: BrandPalette.inkMuted, height: 1.35)),
      const SizedBox(height: 18),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(onPressed: _busy ? null : _saveDraft, style: _darkButton(), icon: const Icon(Icons.save_outlined), label: Text('SAVE DRAFT', style: _mono(9.5, color: BrandPalette.paperLift))),
        FilledButton.icon(onPressed: _busy ? null : _publish, style: _darkButton(), icon: const Icon(Icons.public), label: Text('PUBLISH', style: _mono(9.5, color: BrandPalette.paperLift))),
        OutlinedButton.icon(onPressed: _busy ? null : _importJson, style: _outlineButton(), icon: const Icon(Icons.upload_file, size: 18), label: Text('IMPORT JSON', style: _mono(9.5))),
        OutlinedButton.icon(onPressed: _showJson, style: _outlineButton(), icon: const Icon(Icons.code, size: 18), label: Text('JSON / ADVANCED', style: _mono(9.5))),
      ]),
      const SizedBox(height: 22),
      for (var gi = 0; gi < menu.groups.length; gi++) _groupCard(gi, menu.groups[gi]),
      OutlinedButton.icon(onPressed: _addGroup, style: _outlineButton(), icon: const Icon(Icons.add), label: Text('ADD GROUP', style: _mono(10))),
    ]);
  }

  Widget _groupCard(int index, MenuGroup group) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: BrandPalette.ink)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(group.name.en.toUpperCase(), style: _mono(11)),
              Text('${group.id} · ${group.name.ru} · ${group.name.vi}', style: _mono(8, color: BrandPalette.inkMuted)),
            ])),
            IconButton(onPressed: index > 0 ? () => _moveGroup(index, -1) : null, icon: const Icon(Icons.arrow_upward, size: 18)),
            IconButton(onPressed: index < _editableMenu.groups.length - 1 ? () => _moveGroup(index, 1) : null, icon: const Icon(Icons.arrow_downward, size: 18)),
            TextButton(onPressed: () => _editGroup(index), child: Text('EDIT', style: _mono(8.5))),
            TextButton(onPressed: () => _deleteGroup(index), child: Text('DELETE', style: _mono(8.5))),
          ]),
          const Divider(color: BrandPalette.rule),
          for (var ii = 0; ii < group.items.length; ii++)
            Row(children: [
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${group.items[ii].name}${group.items[ii].enabled ? '' : ' · DISABLED'}', style: _serif(17, color: group.items[ii].enabled ? BrandPalette.ink : BrandPalette.inkMuted)),
                  Text('${group.items[ii].id} · ${_money(group.items[ii].priceVnd)}', style: _mono(8.5, color: BrandPalette.inkMuted)),
                ]),
              )),
              IconButton(onPressed: ii > 0 ? () => _moveItem(index, ii, -1) : null, icon: const Icon(Icons.arrow_upward, size: 16)),
              IconButton(onPressed: ii < group.items.length - 1 ? () => _moveItem(index, ii, 1) : null, icon: const Icon(Icons.arrow_downward, size: 16)),
              TextButton(onPressed: () => _editItem(index, ii), child: Text('EDIT', style: _mono(8))),
              TextButton(onPressed: () => _deleteItem(index, ii), child: Text('×', style: _mono(12))),
            ]),
          const SizedBox(height: 5),
          TextButton.icon(onPressed: () => _addItem(index), icon: const Icon(Icons.add, size: 17), label: Text('ADD ITEM', style: _mono(9))),
        ]),
      );

  Widget _promoTab() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('PROMOS', style: _serif(40))),
          FilledButton.icon(onPressed: _busy ? null : _newPromo, style: _darkButton(), icon: const Icon(Icons.add), label: Text('NEW PROMO', style: _mono(9.5, color: BrandPalette.paperLift))),
        ]),
        const SizedBox(height: 8),
        Text('Create reusable server-side promotion rules. Existing customer grants stay pinned to the revision they received.', style: _serif(16, color: BrandPalette.inkMuted, height: 1.35)),
        const SizedBox(height: 20),
        if (_promos.isEmpty) Text('No promos yet.', style: _serif(17, color: BrandPalette.inkMuted)),
        for (final promo in _promos)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(border: Border.all(color: promo.active ? BrandPalette.ink : BrandPalette.rule)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(promo.name, style: _serif(20)),
                const SizedBox(height: 3),
                Text('${_discountLabel(promo)} · ${promo.groupIds.isEmpty ? 'ALL GROUPS' : promo.groupIds.join(' + ').toUpperCase()} · ${promo.maxUsesPerCustomer} USE${promo.maxUsesPerCustomer == 1 ? '' : 'S'}', style: _mono(8.8)),
                const SizedBox(height: 3),
                Text('${promo.distributionType.toUpperCase()} · REV ${promo.revision} · ${promo.grants} GRANTED · ${promo.consumed} USED${promo.active ? '' : ' · DISABLED'}', style: _mono(8, color: BrandPalette.inkMuted)),
              ])),
              TextButton(onPressed: promo.active ? () => _editPromo(promo) : null, child: Text('EDIT', style: _mono(8.5))),
              TextButton(onPressed: promo.active ? () => _disablePromo(promo) : null, child: Text('DISABLE', style: _mono(8.5))),
            ]),
          ),
      ]);

  Widget _customersTab() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('CUSTOMERS', style: _serif(40)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: _customerSearch, decoration: _inputDecoration('SEARCH NAME / PHONE / EMAIL / TELEGRAM'), onSubmitted: (_) => _searchCustomers())),
          const SizedBox(width: 8),
          FilledButton(onPressed: _searchCustomers, style: _darkButton(), child: Text('SEARCH', style: _mono(9.5, color: BrandPalette.paperLift))),
        ]),
        const SizedBox(height: 18),
        for (final customer in _customers)
          InkWell(
            onTap: () => _openCustomer(customer),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: BrandPalette.rule))),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(customer.name.isEmpty ? 'MEMBER #${customer.id}' : customer.name, style: _serif(18)),
                  Text([customer.email, customer.phone, customer.telegram].whereType<String>().join(' · '), style: _mono(8.5, color: BrandPalette.inkMuted)),
                ])),
                Text('${customer.activePromos} PROMOS · ${customer.menuOrders} ORDERS', style: _mono(8.5)),
                const Icon(Icons.chevron_right),
              ]),
            ),
          ),
      ]);

  Widget _ordersTab() {
    final orders = _snapshot?.orders ?? const <AdminMenuOrder>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('ORDERS', style: _serif(40)),
      const SizedBox(height: 15),
      if (_snapshot != null && !_snapshot!.paymentConfigured)
        _warning('PAYMENT QR NOT CONFIGURED', 'Set VIETQR_ACCOUNT_NUMBER before accepting real payments.'),
      if (orders.isEmpty) Text('No orders yet.', style: _serif(17, color: BrandPalette.inkMuted)),
      for (final order in orders)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: BrandPalette.rule))),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${order.orderCode} · ${order.itemName}', style: _serif(18)),
              Text('${_money(order.amountVnd)} · ${order.paymentMessage}', style: _mono(8.8)),
              if (order.promoDiscountVnd > 0)
                Text('${order.promoName ?? 'PROMO'} · -${_money(order.promoDiscountVnd)} FROM ${_money(order.originalAmountVnd)}', style: _mono(8, color: BrandPalette.inkMuted)),
              Text(order.status.toUpperCase(), style: _mono(8, color: BrandPalette.inkMuted)),
            ])),
            if (order.pending)
              FilledButton(onPressed: _busy ? null : () => _markPaid(order), style: _darkButton(), child: Text('MARK PAID', style: _mono(8.5, color: BrandPalette.paperLift))),
          ]),
        ),
    ]);
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool enabled = true,
    TextInputType? keyboardType,
  }) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          decoration: _inputDecoration(label),
        ),
      );

  Widget _warning(String title, String body) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(border: Border.all(color: BrandPalette.ink, width: 2)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: _mono(10)),
          const SizedBox(height: 5),
          Text(body, style: _serif(15)),
        ]),
      );

  Widget _errorBox(String value) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: BrandPalette.ink)),
        child: Text(value, style: _mono(9.5)),
      );
}

InputDecoration _inputDecoration(String label) => InputDecoration(
      labelText: label,
      labelStyle: _mono(8.5, color: BrandPalette.inkMuted),
      enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: BrandPalette.rule)),
      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: BrandPalette.ink)),
      disabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: BrandPalette.rule)),
    );

String _discountLabel(AdminPromotion promo) => promo.discountType == 'percent'
    ? '${promo.discountValue}% OFF'
    : '${_money(promo.discountValue)} OFF';

String _slug(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

int? _nullableInt(String value) {
  final text = value.replaceAll(',', '').trim();
  if (text.isEmpty) return null;
  return int.tryParse(text);
}

String _money(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index += 1) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return '${value < 0 ? '-' : ''}${buffer.toString()} VND';
}

ButtonStyle _darkButton() => FilledButton.styleFrom(
      foregroundColor: BrandPalette.paperLift,
      backgroundColor: BrandPalette.ink,
      minimumSize: const Size(120, 48),
      shape: const RoundedRectangleBorder(),
    );

ButtonStyle _outlineButton() => OutlinedButton.styleFrom(
      foregroundColor: BrandPalette.ink,
      side: const BorderSide(color: BrandPalette.ink),
      minimumSize: const Size(120, 48),
      shape: const RoundedRectangleBorder(),
    );

TextStyle _serif(double size, {Color color = BrandPalette.ink, double? height}) => TextStyle(
      fontFamily: 'Georgia',
      fontSize: size,
      color: color,
      height: height,
    );

TextStyle _mono(double size, {Color color = BrandPalette.ink, double? height}) => TextStyle(
      fontFamily: 'Courier New',
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
      color: color,
      height: height,
    );
