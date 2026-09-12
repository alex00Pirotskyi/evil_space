class MenuCatalog {
  const MenuCatalog({
    required this.version,
    required this.updatedAt,
    required this.groups,
  });

  const MenuCatalog.empty() : version = 0, updatedAt = 0, groups = const [];

  final int version;
  final int updatedAt;
  final List<MenuGroup> groups;

  factory MenuCatalog.fromJson(Map<String, dynamic> json) {
    return MenuCatalog(
      version: _asInt(json['version']) ?? 0,
      updatedAt: _asInt(json['updatedAt']) ?? 0,
      groups: _listOf(json['groups'], MenuGroup.fromJson),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'groups': groups.map((group) => group.toJson()).toList(growable: false),
      };
}

class MenuLocalizedText {
  const MenuLocalizedText({required this.en, required this.ru, required this.vi});

  final String en;
  final String ru;
  final String vi;

  factory MenuLocalizedText.fromJson(Object? value) {
    if (value is String) {
      final text = value.trim();
      return MenuLocalizedText(en: text, ru: text, vi: text);
    }
    final map = _mapOrNull(value);
    if (map == null) return const MenuLocalizedText(en: '', ru: '', vi: '');
    final en = map['en']?.toString().trim() ?? '';
    final ru = map['ru']?.toString().trim() ?? '';
    final vi = map['vi']?.toString().trim() ?? '';
    final fallback = en.isNotEmpty ? en : ru.isNotEmpty ? ru : vi;
    return MenuLocalizedText(
      en: en.isEmpty ? fallback : en,
      ru: ru.isEmpty ? fallback : ru,
      vi: vi.isEmpty ? fallback : vi,
    );
  }

  String resolve(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'ru': return ru;
      case 'vi': return vi;
      default: return en;
    }
  }

  Map<String, dynamic> toJson() => {'en': en, 'ru': ru, 'vi': vi};

  String toUpperCase() {
    if (en == ru && en == vi) return en.toUpperCase();
    return 'EN · ${en.toUpperCase()}\nRU · ${ru.toUpperCase()}\nVI · ${vi.toUpperCase()}';
  }

  @override
  String toString() => en;
}

class MenuGroup {
  const MenuGroup({required this.id, required this.name, required this.items});
  final String id;
  final MenuLocalizedText name;
  final List<MenuItem> items;

  factory MenuGroup.fromJson(Map<String, dynamic> json) => MenuGroup(
        id: json['id']?.toString() ?? '',
        name: MenuLocalizedText.fromJson(json['name']),
        items: _listOf(json['items'], MenuItem.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name.toJson(),
        'items': items.map((item) => item.toJson()).toList(growable: false),
      };
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.priceVnd,
    required this.enabled,
    this.description,
  });
  final String id;
  final String name;
  final int priceVnd;
  final bool enabled;
  final String? description;

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final description = json['description']?.toString().trim();
    return MenuItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      priceVnd: _asInt(json['priceVnd']) ?? 0,
      enabled: json['enabled'] != false,
      description: description == null || description.isEmpty ? null : description,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'priceVnd': priceVnd,
        'description': description,
        'enabled': enabled,
      };
}

class MenuOrderPayment {
  const MenuOrderPayment({
    required this.token,
    required this.orderCode,
    required this.itemId,
    required this.itemName,
    required this.amountVnd,
    required this.paymentMessage,
    required this.qrPayload,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.originalAmountVnd,
    required this.promoEligibleAmountVnd,
    required this.promoDiscountVnd,
    this.promoGrantId,
    this.promoName,
  });
  final String token;
  final String orderCode;
  final String itemId;
  final String itemName;
  final int originalAmountVnd;
  final int promoEligibleAmountVnd;
  final int promoDiscountVnd;
  final int? promoGrantId;
  final String? promoName;
  final int amountVnd;
  final String paymentMessage;
  final String qrPayload;
  final String status;
  final int createdAt;
  final int expiresAt;

  bool get hasPromo => promoDiscountVnd > 0;

  factory MenuOrderPayment.fromJson(Map<String, dynamic> json) {
    final amount = _asInt(json['amountVnd']) ?? 0;
    final promoName = json['promoName']?.toString().trim();
    return MenuOrderPayment(
      token: json['token']?.toString() ?? '',
      orderCode: json['orderCode']?.toString() ?? '',
      itemId: json['itemId']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      originalAmountVnd: _asInt(json['originalAmountVnd']) ?? amount,
      promoEligibleAmountVnd: _asInt(json['promoEligibleAmountVnd']) ?? 0,
      promoDiscountVnd: _asInt(json['promoDiscountVnd']) ?? 0,
      promoGrantId: _asInt(json['promoGrantId']),
      promoName: promoName == null || promoName.isEmpty ? null : promoName,
      amountVnd: amount,
      paymentMessage: json['paymentMessage']?.toString() ?? '',
      qrPayload: json['qrPayload']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: _asInt(json['createdAt']) ?? 0,
      expiresAt: _asInt(json['expiresAt']) ?? 0,
    );
  }
}

class MenuOrderStatus {
  const MenuOrderStatus({
    required this.orderCode,
    required this.itemId,
    required this.itemName,
    required this.amountVnd,
    required this.originalAmountVnd,
    required this.promoEligibleAmountVnd,
    required this.promoDiscountVnd,
    required this.paymentMessage,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.promoGrantId,
    this.promoName,
    this.paidAt,
  });
  final String orderCode;
  final String itemId;
  final String itemName;
  final int originalAmountVnd;
  final int promoEligibleAmountVnd;
  final int promoDiscountVnd;
  final int? promoGrantId;
  final String? promoName;
  final int amountVnd;
  final String paymentMessage;
  final String status;
  final int createdAt;
  final int expiresAt;
  final int? paidAt;

  bool get paid => status == 'paid';
  bool get pending => status == 'pending';
  bool get expired => status == 'expired';

  factory MenuOrderStatus.fromJson(Map<String, dynamic> json) {
    final amount = _asInt(json['amountVnd']) ?? 0;
    final promoName = json['promoName']?.toString().trim();
    return MenuOrderStatus(
      orderCode: json['orderCode']?.toString() ?? '',
      itemId: json['itemId']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      originalAmountVnd: _asInt(json['originalAmountVnd']) ?? amount,
      promoEligibleAmountVnd: _asInt(json['promoEligibleAmountVnd']) ?? 0,
      promoDiscountVnd: _asInt(json['promoDiscountVnd']) ?? 0,
      promoGrantId: _asInt(json['promoGrantId']),
      promoName: promoName == null || promoName.isEmpty ? null : promoName,
      amountVnd: amount,
      paymentMessage: json['paymentMessage']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: _asInt(json['createdAt']) ?? 0,
      expiresAt: _asInt(json['expiresAt']) ?? 0,
      paidAt: _asInt(json['paidAt']),
    );
  }
}

class CustomerPromo {
  const CustomerPromo({
    required this.id,
    required this.promotionId,
    required this.promoKey,
    required this.name,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.groupIds,
    required this.source,
    required this.status,
    required this.grantedUses,
    required this.usedUses,
    required this.reservedUses,
    required this.remainingUses,
    required this.grantedAt,
    required this.validFrom,
    this.code,
    this.maxDiscountVnd,
    this.expiresAt,
  });
  final int id;
  final int promotionId;
  final String promoKey;
  final String name;
  final String description;
  final String? code;
  final String discountType;
  final int discountValue;
  final int? maxDiscountVnd;
  final List<String> groupIds;
  final String source;
  final String status;
  final int grantedUses;
  final int usedUses;
  final int reservedUses;
  final int remainingUses;
  final int grantedAt;
  final int validFrom;
  final int? expiresAt;

  bool get active => status == 'active' && remainingUses > 0;
  String get discountLabel => discountType == 'percent'
      ? '$discountValue% OFF'
      : '${discountValue.toString()} VND OFF';

  factory CustomerPromo.fromJson(Map<String, dynamic> json) => CustomerPromo(
        id: _asInt(json['id']) ?? 0,
        promotionId: _asInt(json['promotionId']) ?? 0,
        promoKey: json['promoKey']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        code: _nullableText(json['code']),
        discountType: json['discountType']?.toString() ?? 'percent',
        discountValue: _asInt(json['discountValue']) ?? 0,
        maxDiscountVnd: _asInt(json['maxDiscountVnd']),
        groupIds: _stringList(json['groupIds']),
        source: json['source']?.toString() ?? '',
        status: json['status']?.toString() ?? 'active',
        grantedUses: _asInt(json['grantedUses']) ?? 0,
        usedUses: _asInt(json['usedUses']) ?? 0,
        reservedUses: _asInt(json['reservedUses']) ?? 0,
        remainingUses: _asInt(json['remainingUses']) ?? 0,
        grantedAt: _asInt(json['grantedAt']) ?? 0,
        validFrom: _asInt(json['validFrom']) ?? 0,
        expiresAt: _asInt(json['expiresAt']),
      );
}

class PromoPreview {
  const PromoPreview({
    required this.grantId,
    required this.promotionId,
    required this.promoKey,
    required this.name,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.originalAmountVnd,
    required this.eligibleAmountVnd,
    required this.discountVnd,
    required this.finalAmountVnd,
    required this.remainingUses,
    this.expiresAt,
  });
  final int grantId;
  final int promotionId;
  final String promoKey;
  final String name;
  final String description;
  final String discountType;
  final int discountValue;
  final int originalAmountVnd;
  final int eligibleAmountVnd;
  final int discountVnd;
  final int finalAmountVnd;
  final int remainingUses;
  final int? expiresAt;

  factory PromoPreview.fromJson(Map<String, dynamic> json) => PromoPreview(
        grantId: _asInt(json['grantId']) ?? 0,
        promotionId: _asInt(json['promotionId']) ?? 0,
        promoKey: json['promoKey']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        discountType: json['discountType']?.toString() ?? 'percent',
        discountValue: _asInt(json['discountValue']) ?? 0,
        originalAmountVnd: _asInt(json['originalAmountVnd']) ?? 0,
        eligibleAmountVnd: _asInt(json['eligibleAmountVnd']) ?? 0,
        discountVnd: _asInt(json['discountVnd']) ?? 0,
        finalAmountVnd: _asInt(json['finalAmountVnd']) ?? 0,
        remainingUses: _asInt(json['remainingUses']) ?? 0,
        expiresAt: _asInt(json['expiresAt']),
      );
}

class PromoReference {
  const PromoReference({required this.id, required this.name, required this.promoKey});
  final int id;
  final String name;
  final String promoKey;
  factory PromoReference.fromJson(Map<String, dynamic> json) => PromoReference(
        id: _asInt(json['id']) ?? 0,
        name: json['name']?.toString() ?? '',
        promoKey: json['promoKey']?.toString() ?? '',
      );
}

class MenuDraftSnapshot {
  const MenuDraftSnapshot({
    required this.source,
    required this.updatedAt,
    required this.updatedByEmail,
    required this.menu,
    required this.promoReferences,
    this.baseCatalogId,
  });
  final String source;
  final int? baseCatalogId;
  final int updatedAt;
  final String updatedByEmail;
  final MenuCatalog menu;
  final Map<String, List<PromoReference>> promoReferences;

  factory MenuDraftSnapshot.fromJson(Map<String, dynamic> json) {
    final menuJson = _mapOrNull(json['menu']) ?? const <String, dynamic>{};
    final references = <String, List<PromoReference>>{};
    final refsMap = _mapOrNull(json['promoReferences']);
    if (refsMap != null) {
      for (final entry in refsMap.entries) {
        references[entry.key] = _listOf(entry.value, PromoReference.fromJson);
      }
    }
    return MenuDraftSnapshot(
      source: json['source']?.toString() ?? 'empty',
      baseCatalogId: _asInt(json['baseCatalogId']),
      updatedAt: _asInt(json['updatedAt']) ?? 0,
      updatedByEmail: json['updatedByEmail']?.toString() ?? '',
      menu: MenuCatalog.fromJson(menuJson),
      promoReferences: references,
    );
  }
}

class AdminPromotion {
  const AdminPromotion({
    required this.id,
    required this.promoKey,
    required this.revision,
    required this.name,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.minimumSubtotalVnd,
    required this.validFrom,
    required this.maxUsesPerCustomer,
    required this.distributionType,
    required this.active,
    required this.groupIds,
    required this.includeItemIds,
    required this.excludeItemIds,
    required this.grants,
    required this.consumed,
    this.code,
    this.maxDiscountVnd,
    this.expiresAt,
    this.maxTotalUses,
  });
  final int id;
  final String promoKey;
  final int revision;
  final String name;
  final String description;
  final String? code;
  final String discountType;
  final int discountValue;
  final int? maxDiscountVnd;
  final int minimumSubtotalVnd;
  final int validFrom;
  final int? expiresAt;
  final int maxUsesPerCustomer;
  final int? maxTotalUses;
  final String distributionType;
  final bool active;
  final List<String> groupIds;
  final List<String> includeItemIds;
  final List<String> excludeItemIds;
  final int grants;
  final int consumed;

  factory AdminPromotion.fromJson(Map<String, dynamic> json) => AdminPromotion(
        id: _asInt(json['id']) ?? 0,
        promoKey: json['promoKey']?.toString() ?? '',
        revision: _asInt(json['revision']) ?? 1,
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        code: _nullableText(json['code']),
        discountType: json['discountType']?.toString() ?? 'percent',
        discountValue: _asInt(json['discountValue']) ?? 0,
        maxDiscountVnd: _asInt(json['maxDiscountVnd']),
        minimumSubtotalVnd: _asInt(json['minimumSubtotalVnd']) ?? 0,
        validFrom: _asInt(json['validFrom']) ?? 0,
        expiresAt: _asInt(json['expiresAt']),
        maxUsesPerCustomer: _asInt(json['maxUsesPerCustomer']) ?? 1,
        maxTotalUses: _asInt(json['maxTotalUses']),
        distributionType: json['distributionType']?.toString() ?? 'manual',
        active: json['active'] == true,
        groupIds: _stringList(json['groupIds']),
        includeItemIds: _stringList(json['includeItemIds']),
        excludeItemIds: _stringList(json['excludeItemIds']),
        grants: _asInt(json['grants']) ?? 0,
        consumed: _asInt(json['consumed']) ?? 0,
      );
}

class AdminCustomerSummary {
  const AdminCustomerSummary({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.activePromos,
    required this.menuOrders,
    this.phone,
    this.email,
    this.telegram,
  });
  final int id;
  final String name;
  final String? phone;
  final String? email;
  final String? telegram;
  final int createdAt;
  final int updatedAt;
  final int activePromos;
  final int menuOrders;

  factory AdminCustomerSummary.fromJson(Map<String, dynamic> json) => AdminCustomerSummary(
        id: _asInt(json['id']) ?? 0,
        name: json['name']?.toString() ?? '',
        phone: _nullableText(json['phone']),
        email: _nullableText(json['email']),
        telegram: _nullableText(json['telegram']),
        createdAt: _asInt(json['createdAt']) ?? 0,
        updatedAt: _asInt(json['updatedAt']) ?? 0,
        activePromos: _asInt(json['activePromos']) ?? 0,
        menuOrders: _asInt(json['menuOrders']) ?? 0,
      );
}

class AdminCustomerDetail extends AdminCustomerSummary {
  const AdminCustomerDetail({
    required super.id,
    required super.name,
    required super.createdAt,
    required super.updatedAt,
    required super.activePromos,
    required super.menuOrders,
    super.phone,
    super.email,
    super.telegram,
    required this.promos,
  });
  final List<CustomerPromo> promos;

  factory AdminCustomerDetail.fromJson(Map<String, dynamic> json) => AdminCustomerDetail(
        id: _asInt(json['id']) ?? 0,
        name: json['name']?.toString() ?? '',
        phone: _nullableText(json['phone']),
        email: _nullableText(json['email']),
        telegram: _nullableText(json['telegram']),
        createdAt: _asInt(json['createdAt']) ?? 0,
        updatedAt: _asInt(json['updatedAt']) ?? 0,
        activePromos: _asInt(json['activePromos']) ?? 0,
        menuOrders: _asInt(json['menuOrders']) ?? 0,
        promos: _listOf(json['promos'], CustomerPromo.fromJson),
      );
}

class AdminMenuSnapshot {
  const AdminMenuSnapshot({
    required this.paymentConfigured,
    required this.bankBin,
    required this.orders,
    this.catalog,
  });
  final bool paymentConfigured;
  final String bankBin;
  final AdminMenuCatalog? catalog;
  final List<AdminMenuOrder> orders;

  factory AdminMenuSnapshot.fromJson(Map<String, dynamic> json) {
    final catalogJson = _mapOrNull(json['catalog']);
    return AdminMenuSnapshot(
      paymentConfigured: json['paymentConfigured'] == true,
      bankBin: json['bankBin']?.toString() ?? '970436',
      catalog: catalogJson == null ? null : AdminMenuCatalog.fromJson(catalogJson),
      orders: _listOf(json['orders'], AdminMenuOrder.fromJson),
    );
  }
}

class AdminMenuCatalog {
  const AdminMenuCatalog({
    required this.id,
    required this.version,
    required this.createdAt,
    required this.createdByEmail,
    required this.sourceJson,
    required this.groups,
  });
  final int id;
  final int version;
  final int createdAt;
  final String createdByEmail;
  final String sourceJson;
  final List<MenuGroup> groups;

  factory AdminMenuCatalog.fromJson(Map<String, dynamic> json) => AdminMenuCatalog(
        id: _asInt(json['id']) ?? 0,
        version: _asInt(json['version']) ?? 0,
        createdAt: _asInt(json['createdAt']) ?? 0,
        createdByEmail: json['createdByEmail']?.toString() ?? '',
        sourceJson: json['sourceJson']?.toString() ?? '',
        groups: _listOf(json['groups'], MenuGroup.fromJson),
      );
}

class AdminMenuOrder {
  const AdminMenuOrder({
    required this.id,
    required this.orderCode,
    required this.itemName,
    required this.amountVnd,
    required this.originalAmountVnd,
    required this.promoEligibleAmountVnd,
    required this.promoDiscountVnd,
    required this.paymentMessage,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.promoGrantId,
    this.promoName,
    this.paidAt,
    this.paidByEmail,
  });
  final int id;
  final String orderCode;
  final String itemName;
  final int originalAmountVnd;
  final int promoEligibleAmountVnd;
  final int promoDiscountVnd;
  final int? promoGrantId;
  final String? promoName;
  final int amountVnd;
  final String paymentMessage;
  final String status;
  final int createdAt;
  final int expiresAt;
  final int? paidAt;
  final String? paidByEmail;

  bool get pending => status == 'pending';
  bool get paid => status == 'paid';

  factory AdminMenuOrder.fromJson(Map<String, dynamic> json) {
    final paidBy = json['paidByEmail']?.toString().trim();
    final promoName = json['promoName']?.toString().trim();
    final amount = _asInt(json['amountVnd']) ?? 0;
    return AdminMenuOrder(
      id: _asInt(json['id']) ?? 0,
      orderCode: json['orderCode']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      originalAmountVnd: _asInt(json['originalAmountVnd']) ?? amount,
      promoEligibleAmountVnd: _asInt(json['promoEligibleAmountVnd']) ?? 0,
      promoDiscountVnd: _asInt(json['promoDiscountVnd']) ?? 0,
      promoGrantId: _asInt(json['promoGrantId']),
      promoName: promoName == null || promoName.isEmpty ? null : promoName,
      amountVnd: amount,
      paymentMessage: json['paymentMessage']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: _asInt(json['createdAt']) ?? 0,
      expiresAt: _asInt(json['expiresAt']) ?? 0,
      paidAt: _asInt(json['paidAt']),
      paidByEmail: paidBy == null || paidBy.isEmpty ? null : paidBy,
    );
  }
}

class MenuApiException implements Exception {
  const MenuApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

Map<String, dynamic>? _mapOrNull(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<T> _listOf<T>(Object? value, T Function(Map<String, dynamic>) parser) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => parser(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.map((entry) => entry.toString()).toList(growable: false);
}

String? _nullableText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}
