class AdminSession {
  const AdminSession({required this.authenticated, this.email});

  const AdminSession.signedOut() : authenticated = false, email = null;

  final bool authenticated;
  final String? email;

  factory AdminSession.fromJson(Map<String, dynamic> json) {
    return AdminSession(
      authenticated: json['authenticated'] == true,
      email: json['email']?.toString(),
    );
  }
}

class AdminAccount {
  const AdminAccount({
    required this.email,
    required this.status,
    required this.createdAt,
    this.approvedAt,
  });

  final String email;
  final String status;
  final int createdAt;
  final int? approvedAt;

  factory AdminAccount.fromJson(Map<String, dynamic> json) {
    return AdminAccount(
      email: json['email']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown',
      createdAt: _asInt(json['created_at']) ?? 0,
      approvedAt: _asInt(json['approved_at']),
    );
  }
}

class DeleteAdminResult {
  const DeleteAdminResult({required this.email, required this.deletedSelf});

  final String email;
  final bool deletedSelf;

  factory DeleteAdminResult.fromJson(Map<String, dynamic> json) {
    return DeleteAdminResult(
      email: json['email']?.toString() ?? '',
      deletedSelf: json['deletedSelf'] == true,
    );
  }
}

class VisitRecord {
  const VisitRecord({
    required this.id,
    required this.name,
    required this.kind,
    required this.amount,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String kind;
  final int amount;
  final int createdAt;

  factory VisitRecord.fromJson(Map<String, dynamic> json) {
    return VisitRecord(
      id: _asInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'day',
      amount: _asInt(json['amount']) ?? 0,
      createdAt: _asInt(json['created_at']) ?? 0,
    );
  }
}

class MembershipRecord {
  const MembershipRecord({
    required this.id,
    required this.name,
    required this.startsAt,
    required this.expiresAt,
  });

  final int id;
  final String name;
  final int startsAt;
  final int expiresAt;

  factory MembershipRecord.fromJson(Map<String, dynamic> json) {
    return MembershipRecord(
      id: _asInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      startsAt: _asInt(json['starts_at']) ?? 0,
      expiresAt: _asInt(json['expires_at']) ?? 0,
    );
  }
}

class PurchaseRequestRecord {
  const PurchaseRequestRecord({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    this.boughtAt,
  });

  final int id;
  final String title;
  final String status;
  final int createdAt;
  final int? boughtAt;

  factory PurchaseRequestRecord.fromJson(Map<String, dynamic> json) {
    return PurchaseRequestRecord(
      id: _asInt(json['id']) ?? 0,
      title: json['title']?.toString() ?? '',
      status: json['status']?.toString() ?? 'needed',
      createdAt: _asInt(json['created_at']) ?? 0,
      boughtAt: _asInt(json['bought_at']),
    );
  }
}

class IncomeSummary {
  const IncomeSummary({
    required this.today,
    required this.sevenDays,
    required this.thirtyDays,
    required this.all,
  });

  final int today;
  final int sevenDays;
  final int thirtyDays;
  final int all;

  factory IncomeSummary.fromJson(Map<String, dynamic> json) {
    return IncomeSummary(
      today: _asInt(json['today']) ?? 0,
      sevenDays: _asInt(json['seven_days']) ?? 0,
      thirtyDays: _asInt(json['thirty_days']) ?? 0,
      all: _asInt(json['all']) ?? 0,
    );
  }
}

class OperationsSnapshot {
  const OperationsSnapshot({
    required this.todayVisits,
    required this.activeMemberships,
    required this.toBuy,
    required this.purchaseHistory,
    required this.income,
  });

  final List<VisitRecord> todayVisits;
  final List<MembershipRecord> activeMemberships;
  final List<PurchaseRequestRecord> toBuy;
  final List<PurchaseRequestRecord> purchaseHistory;
  final IncomeSummary income;

  factory OperationsSnapshot.fromJson(Map<String, dynamic> json) {
    return OperationsSnapshot(
      todayVisits: _listOf(json['today_visits'], VisitRecord.fromJson),
      activeMemberships: _listOf(
        json['active_memberships'],
        MembershipRecord.fromJson,
      ),
      toBuy: _listOf(json['to_buy'], PurchaseRequestRecord.fromJson),
      purchaseHistory: _listOf(
        json['purchase_history'],
        PurchaseRequestRecord.fromJson,
      ),
      income: IncomeSummary.fromJson(
        _map(json['income']),
      ),
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
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

class AdminApiException implements Exception {
  const AdminApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
