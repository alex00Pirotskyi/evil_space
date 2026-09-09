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
}

class MenuLocalizedText {
  const MenuLocalizedText({
    required this.en,
    required this.ru,
    required this.vi,
  });

  final String en;
  final String ru;
  final String vi;

  factory MenuLocalizedText.fromJson(Object? value) {
    if (value is String) {
      final text = value.trim();
      return MenuLocalizedText(en: text, ru: text, vi: text);
    }

    final map = _mapOrNull(value);
    if (map == null) {
      return const MenuLocalizedText(en: '', ru: '', vi: '');
    }

    final en = map['en']?.toString().trim() ?? '';
    final ru = map['ru']?.toString().trim() ?? '';
    final vi = map['vi']?.toString().trim() ?? '';
    final fallback = en.isNotEmpty
        ? en
        : ru.isNotEmpty
        ? ru
        : vi;
    return MenuLocalizedText(
      en: en.isEmpty ? fallback : en,
      ru: ru.isEmpty ? fallback : ru,
      vi: vi.isEmpty ? fallback : vi,
    );
  }

  String resolve(String languageCode) {
    switch (languageCode.toLowerCase()) {
      case 'ru':
        return ru;
      case 'vi':
        return vi;
      default:
        return en;
    }
  }

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

  factory MenuGroup.fromJson(Map<String, dynamic> json) {
    return MenuGroup(
      id: json['id']?.toString() ?? '',
      name: MenuLocalizedText.fromJson(json['name']),
      items: _listOf(json['items'], MenuItem.fromJson),
    );
  }
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
      description: description == null || description.isEmpty
          ? null
          : description,
    );
  }
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
  });

  final String token;
  final String orderCode;
  final String itemId;
  final String itemName;
  final int amountVnd;
  final String paymentMessage;
  final String qrPayload;
  final String status;
  final int createdAt;
  final int expiresAt;

  factory MenuOrderPayment.fromJson(Map<String, dynamic> json) {
    return MenuOrderPayment(
      token: json['token']?.toString() ?? '',
      orderCode: json['orderCode']?.toString() ?? '',
      itemId: json['itemId']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      amountVnd: _asInt(json['amountVnd']) ?? 0,
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
    required this.paymentMessage,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.paidAt,
  });

  final String orderCode;
  final String itemId;
  final String itemName;
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
    return MenuOrderStatus(
      orderCode: json['orderCode']?.toString() ?? '',
      itemId: json['itemId']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      amountVnd: _asInt(json['amountVnd']) ?? 0,
      paymentMessage: json['paymentMessage']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: _asInt(json['createdAt']) ?? 0,
      expiresAt: _asInt(json['expiresAt']) ?? 0,
      paidAt: _asInt(json['paidAt']),
    );
  }
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

  factory AdminMenuCatalog.fromJson(Map<String, dynamic> json) {
    return AdminMenuCatalog(
      id: _asInt(json['id']) ?? 0,
      version: _asInt(json['version']) ?? 0,
      createdAt: _asInt(json['createdAt']) ?? 0,
      createdByEmail: json['createdByEmail']?.toString() ?? '',
      sourceJson: json['sourceJson']?.toString() ?? '',
      groups: _listOf(json['groups'], MenuGroup.fromJson),
    );
  }
}

class AdminMenuOrder {
  const AdminMenuOrder({
    required this.id,
    required this.orderCode,
    required this.itemName,
    required this.amountVnd,
    required this.paymentMessage,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.paidAt,
    this.paidByEmail,
  });

  final int id;
  final String orderCode;
  final String itemName;
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
    return AdminMenuOrder(
      id: _asInt(json['id']) ?? 0,
      orderCode: json['orderCode']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      amountVnd: _asInt(json['amountVnd']) ?? 0,
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

int? _asInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}
