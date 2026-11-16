part of 'menu_screen.dart';

// The phone menu remains the original editorial list. Wider devices get a
// dedicated touchscreen ordering surface without changing the cart or API.
extension _TabletMenuLayout on _MenuScreenState {
  Widget _tabletMenu(MenuCatalog? menu, double width) {
    final hasSidebar = width >= 1024;
    final sidebarWidth = hasSidebar ? min(356.0, max(304.0, width * 0.29)) : 0.0;
    final columns = width >= 1280 ? 3 : 2;
    final groups = menu?.groups.where((group) =>
      group.items.any((item) => item.enabled)).toList(growable: false) ?? const <MenuGroup>[];

    return Row(children: [
      Expanded(child: Column(children: [
        if (!hasSidebar) _cartBar(),
        _tabletCategories(groups),
        Expanded(child: RefreshIndicator(
            color: BrandPalette.ink,
            onRefresh: _checkingOut ? () async {} : _load,
            child: ListView(
              key: const ValueKey('menu-grid-list'),
              controller: _menuScroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 72),
              children: [
                Text(_copy('title'), style: _serif(42)),
                const SizedBox(height: 6),
                Text(_copy('subtitle'), style: _serif(16,
                  color: BrandPalette.inkMuted, height: 1.35)),
                const SizedBox(height: 26),
                if (_error != null) _errorBox(_error!),
                if (_preparationError != null) ...[
                  _errorBox(_preparationError!),
                  TextButton(key: const ValueKey('prepare-payment-retry'),
                    onPressed: () => _checkoutKey.currentState?._syncPayment(),
                    child: Text(_copy('retry'))),
                ],
                if (_loading && menu == null)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator(color: BrandPalette.ink)))
                else if (groups.isEmpty) _empty()
                else for (final group in groups) ...[
                  _tabletGroup(group, columns),
                  const SizedBox(height: 28),
                ],
              ],
            ),
          )),
      ])),
      if (hasSidebar) _tabletCart(sidebarWidth),
    ]);
  }

  Widget _tabletCategories(List<MenuGroup> groups) {
    if (groups.length < 2) return const SizedBox.shrink();
    final active = groups.any((group) => group.id == _selectedCategoryId)
      ? _selectedCategoryId : groups.first.id;
    return Container(
      key: const ValueKey('menu-category-bar'),
      height: 62,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BrandPalette.rule))),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {
          ...ScrollConfiguration.of(context).dragDevices,
          PointerDeviceKind.mouse,
        }),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          children: [
            for (final group in groups)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: TextButton(
                  key: ValueKey('menu-category-${group.id}'),
                  onPressed: () {
                    setState(() => _selectedCategoryId = group.id);
                    final target = _groupAnchors[group.id]?.currentContext;
                    if (target != null) {
                      Scrollable.ensureVisible(target,
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeInOutCubic,
                        alignment: 0.02);
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    minimumSize: const Size(64, 42),
                    foregroundColor: active == group.id
                      ? BrandPalette.paperLift : BrandPalette.ink,
                    backgroundColor: active == group.id
                      ? BrandPalette.ink : Colors.transparent,
                    shape: const RoundedRectangleBorder(),
                    side: BorderSide(color: active == group.id
                      ? BrandPalette.ink : BrandPalette.rule),
                  ).copyWith(overlayColor: _menuInkOverlay),
                  child: Text(group.name.resolve(widget.localization.language.code)
                    .toUpperCase(), style: _mono(10)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tabletGroup(MenuGroup group, int columns) {
    final items = group.items.where((item) => item.enabled).toList(growable: false);
    if (items.isEmpty) return const SizedBox.shrink();
    final key = _groupAnchors.putIfAbsent(group.id, () => GlobalKey());
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        key: key,
        padding: const EdgeInsets.only(bottom: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: BrandPalette.ink))),
        child: Text(group.name.resolve(widget.localization.language.code)
          .toUpperCase(), style: _mono(12)),
      ),
      const SizedBox(height: 14),
      GridView.builder(
        key: ValueKey('menu-product-grid-${group.id}'),
        shrinkWrap: true,
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 190,
        ),
        itemBuilder: (_, index) => _tabletItem(items[index]),
      ),
    ]);
  }

  Widget _tabletItem(MenuItem item) {
    final language = widget.localization.language.code;
    final quantity = _cart.where((line) => line.item.id == item.id)
      .fold<int>(0, (sum, line) => sum + line.quantity);
    final enabled = !_checkingOut && !_editingItem;
    final description = item.descriptionFor(language);
    return Material(
      key: ValueKey('menu-grid-card-${item.id}'),
      color: quantity > 0 ? BrandPalette.paperDeep : BrandPalette.paperLift,
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true, selected: quantity > 0, enabled: enabled,
        hint: item.hasOptions ? _copy('customize') : _copy('add'),
        child: InkWell(
          key: ValueKey('menu-grid-item-${item.id}'),
          onTap: enabled ? () => _addItem(item) : null,
          overlayColor: _menuInkOverlay,
          child: Container(
            decoration: BoxDecoration(border: Border.all(
              color: quantity > 0 ? BrandPalette.ink : BrandPalette.rule)),
            padding: const EdgeInsets.fromLTRB(16, 15, 14, 11),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.nameFor(language),
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: _serif(23, height: 1.05)),
              if (description != null) ...[
                const SizedBox(height: 8),
                Text(description,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: _serif(14, height: 1.25,
                    color: BrandPalette.inkMuted)),
              ],
              const Spacer(),
              Row(children: [
                Expanded(child: Text(
                  item.hasVariablePrice
                    ? '${_copy('from').toUpperCase()} ${_money(item.priceVnd)}'
                    : _money(item.priceVnd),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: _mono(11))),
                if (quantity > 0) ...[
                  IconButton(
                    key: ValueKey('menu-grid-remove-${item.id}'),
                    tooltip: _copy('remove'),
                    onPressed: enabled ? () => unawaited(_removeItem(item)) : null,
                    icon: const Icon(Icons.remove, size: 20),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: BrandPalette.paperLift,
                      shape: const RoundedRectangleBorder()),
                  ),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Text('$quantity', style: _mono(12))),
                ],
                const SizedBox(width: 4),
                Container(
                  width: 48, height: 48,
                  decoration: const BoxDecoration(color: BrandPalette.ink),
                  alignment: Alignment.center,
                  child: const Icon(Icons.add, color: BrandPalette.paperLift,
                    size: 22),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tabletCart(double width) {
    final language = widget.localization.language.code;
    final enabled = !_checkingOut && !_editingItem;
    return Container(
      key: const ValueKey('menu-cart-sidebar'),
      width: width,
      decoration: const BoxDecoration(
        color: BrandPalette.paperLift,
        border: Border(left: BorderSide(color: BrandPalette.ink))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          child: Row(children: [
            Expanded(child: Text(_copy('your_cart').toUpperCase(),
              style: _mono(12))),
            Text('${_cart.fold<int>(0, (sum, line) => sum + line.quantity)}',
              style: _mono(12, color: BrandPalette.inkMuted)),
          ]),
        ),
        const Divider(color: BrandPalette.rule, height: 1),
        Expanded(child: _cart.isEmpty
          ? Center(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(switch (language) {
                'ru' => 'Выберите напиток из меню',
                'vi' => 'Chọn món từ thực đơn',
                _ => 'Choose something from the menu',
              }, style: _serif(19, color: BrandPalette.inkMuted),
                 textAlign: TextAlign.center)))
          : ListView.separated(
              key: const ValueKey('menu-cart-lines'),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: _cart.length,
              separatorBuilder: (_, _) =>
                const Divider(color: BrandPalette.rule, height: 20),
              itemBuilder: (_, index) {
                final line = _cart[index];
                return Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.label(language), maxLines: 3,
                      overflow: TextOverflow.ellipsis, style: _serif(19)),
                    const SizedBox(height: 10),
                    Row(children: [
                      IconButton(
                        key: ValueKey('menu-cart-minus-${line.key}'),
                        tooltip: _copy('remove'),
                        onPressed: enabled ? () => unawaited(_tabletRemoveLine(line.key)) : null,
                        icon: const Icon(Icons.remove, size: 18),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          side: const BorderSide(color: BrandPalette.rule),
                          shape: const RoundedRectangleBorder())),
                      SizedBox(width: 28, child: Text('${line.quantity}',
                        style: _mono(12), textAlign: TextAlign.center)),
                      IconButton(
                        key: ValueKey('menu-cart-plus-${line.key}'),
                        tooltip: _copy('add'),
                        onPressed: enabled && line.quantity < 20
                          ? () => _tabletIncreaseLine(line.key) : null,
                        icon: const Icon(Icons.add, size: 18),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          side: const BorderSide(color: BrandPalette.rule),
                          shape: const RoundedRectangleBorder())),
                      const SizedBox(width: 5),
                      Expanded(child: Text(_money(line.total),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right, style: _mono(11))),
                    ]),
                  ]);
              },
            )),
        const Divider(color: BrandPalette.ink, height: 1),
        Padding(padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(_copy('total').toUpperCase(),
                style: _mono(11))),
              Text(_money(_payTotal), style: _serif(24)),
            ]),
            const SizedBox(height: 16),
            SizedBox(height: 58, child: TextButton(
              key: const ValueKey('menu-pay'),
              onPressed: enabled && _payTotal > 0 ? () => _checkout() : null,
              style: TextButton.styleFrom(
                backgroundColor: _payTotal > 0
                  ? BrandPalette.ink : BrandPalette.paperDeep,
                foregroundColor: BrandPalette.paperLift,
                disabledForegroundColor: BrandPalette.inkMuted,
                shape: const RoundedRectangleBorder())
                .copyWith(overlayColor: _menuPaperOverlay),
              child: Text('${_copy('pay')}: ${_money(_payTotal)}',
                style: _mono(13,
                  color: _payTotal > 0
                    ? BrandPalette.paperLift : BrandPalette.inkMuted)),
            )),
          ])),
      ]),
    );
  }

  void _tabletIncreaseLine(String key) {
    if (_checkingOut || _editingItem) return;
    final index = _cart.indexWhere((line) => line.key == key);
    if (index < 0 || _cart[index].quantity >= 20) return;
    setState(() {
      final line = _cart[index];
      _cart[index] = line.copyWith(quantity: line.quantity + 1);
    });
  }

  Future<void> _tabletRemoveLine(String key) async {
    if (_checkingOut || _editingItem) return;
    final index = _cart.indexWhere((line) => line.key == key);
    if (index < 0) return;
    // Reuse the existing safe cart-revision flow when a checkout was opened.
    if (_pendingOrder != null || _paymentToken != null) {
      await _checkout(removeKey: key);
      return;
    }
    setState(() {
      final line = _cart[index];
      if (line.quantity == 1) _cart.removeAt(index);
      else _cart[index] = line.copyWith(quantity: line.quantity - 1);
    });
  }
}
