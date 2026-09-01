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
    this.customerId,
  });

  final int id;
  final String name;
  final String kind;
  final int amount;
  final int createdAt;
  final int? customerId;

  factory VisitRecord.fromJson(Map<String, dynamic> json) {
    return VisitRecord(
      id: _asInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'day',
      amount: _asInt(json['amount']) ?? 0,
      createdAt: _asInt(json['created_at']) ?? 0,
      customerId: _asInt(json['customer_id']),
    );
  }
}

class MembershipRecord {
  const MembershipRecord({
    required this.id,
    required this.name,
    required this.startsAt,
    required this.expiresAt,
    this.customerId,
  });

  final int id;
  final String name;
  final int startsAt;
  final int expiresAt;
  final int? customerId;

  factory MembershipRecord.fromJson(Map<String, dynamic> json) {
    return MembershipRecord(
      id: _asInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      startsAt: _asInt(json['starts_at']) ?? 0,
      expiresAt: _asInt(json['expires_at']) ?? 0,
      customerId: _asInt(json['customer_id']),
    );
  }
}

class BookingRequestRecord {
  const BookingRequestRecord({
    required this.id,
    required this.name,
    required this.contactType,
    required this.contactValue,
    required this.createdAt,
    required this.status,
    required this.serviceDay,
    required this.amountVnd,
    this.handledAt,
    this.handledByEmail,
  });

  final int id;
  final String name;
  final String contactType;
  final String contactValue;
  final int createdAt;
  final String status;
  final int serviceDay;
  final int amountVnd;
  final int? handledAt;
  final String? handledByEmail;

  bool get accepted => status == 'accepted';

  factory BookingRequestRecord.fromJson(Map<String, dynamic> json) {
    return BookingRequestRecord(
      id: _asInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      contactType: json['contact_type']?.toString() ?? '',
      contactValue: json['contact_value']?.toString() ?? '',
      createdAt: _asInt(json['created_at']) ?? 0,
      status: json['status']?.toString() ?? 'new',
      serviceDay: _asInt(json['service_day']) ?? 0,
      amountVnd: _asInt(json['amount_vnd']) ?? 200000,
      handledAt: _asInt(json['handled_at']),
      handledByEmail: json['handled_by_email']?.toString(),
    );
  }
}

class CustomerRecord {
  const CustomerRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.telegram,
    required this.contactOther,
    required this.notes,
    required this.createdAt,
    this.activeUntil,
  });

  final int id;
  final String name;
  final String phone;
  final String email;
  final String telegram;
  final String contactOther;
  final String notes;
  final int createdAt;
  final int? activeUntil;

  bool get hasActiveMembership => activeUntil != null && activeUntil! > 0;

  factory CustomerRecord.fromJson(Map<String, dynamic> json) {
    return CustomerRecord(
      id: _asInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      telegram: json['telegram']?.toString() ?? '',
      contactOther: json['contact_other']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      createdAt: _asInt(json['created_at']) ?? 0,
      activeUntil: _asInt(json['active_until']),
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

class PricingConfig {
  const PricingConfig({
    required this.dayPassVnd,
    required this.monthPassVnd,
    required this.lockerMonthVnd,
    required this.currentDayPassVnd,
    required this.currentMonthPassVnd,
    required this.currentLockerMonthVnd,
    required this.activePromoId,
    required this.activePromoDescription,
  });

  static const defaults = PricingConfig(
    dayPassVnd: 200000,
    monthPassVnd: 2500000,
    lockerMonthVnd: 1000000,
    currentDayPassVnd: 200000,
    currentMonthPassVnd: 2500000,
    currentLockerMonthVnd: 1000000,
    activePromoId: 0,
    activePromoDescription: '',
  );

  final int dayPassVnd;
  final int monthPassVnd;
  final int lockerMonthVnd;
  final int currentDayPassVnd;
  final int currentMonthPassVnd;
  final int currentLockerMonthVnd;
  final int activePromoId;
  final String activePromoDescription;

  factory PricingConfig.fromJson(Map<String, dynamic> json) {
    return PricingConfig(
      dayPassVnd: _asInt(json['day_pass_vnd']) ?? 200000,
      monthPassVnd: _asInt(json['month_pass_vnd']) ?? 2500000,
      lockerMonthVnd: _asInt(json['locker_month_vnd']) ?? 1000000,
      currentDayPassVnd: _asInt(json['current_day_pass_vnd']) ?? 200000,
      currentMonthPassVnd: _asInt(json['current_month_pass_vnd']) ?? 2500000,
      currentLockerMonthVnd:
          _asInt(json['current_locker_month_vnd']) ?? 1000000,
      activePromoId: _asInt(json['active_promo_id']) ?? 0,
      activePromoDescription:
          json['active_promo_description']?.toString() ?? '',
    );
  }
}

class PromotionRecord {
  const PromotionRecord({
    required this.id,
    required this.description,
    required this.startDay,
    required this.endDay,
    required this.enabled,
    required this.createdAt,
    required this.createdByEmail,
    this.startMinute,
    this.endMinute,
    this.dayPassVnd,
    this.monthPassVnd,
    this.lockerMonthVnd,
  });

  final int id;
  final String description;
  final int startDay;
  final int endDay;
  final int? startMinute;
  final int? endMinute;
  final int? dayPassVnd;
  final int? monthPassVnd;
  final int? lockerMonthVnd;
  final bool enabled;
  final int createdAt;
  final String createdByEmail;

  bool get hasTimeWindow => startMinute != null && endMinute != null;

  factory PromotionRecord.fromJson(Map<String, dynamic> json) {
    return PromotionRecord(
      id: _asInt(json['id']) ?? 0,
      description: json['description']?.toString() ?? '',
      startDay: _asInt(json['start_day']) ?? 0,
      endDay: _asInt(json['end_day']) ?? 0,
      startMinute: _asInt(json['start_minute']),
      endMinute: _asInt(json['end_minute']),
      dayPassVnd: _asInt(json['day_pass_vnd']),
      monthPassVnd: _asInt(json['month_pass_vnd']),
      lockerMonthVnd: _asInt(json['locker_month_vnd']),
      enabled: (_asInt(json['enabled']) ?? 0) == 1,
      createdAt: _asInt(json['created_at']) ?? 0,
      createdByEmail: json['created_by_email']?.toString() ?? '',
    );
  }
}

class OperationsSnapshot {
  const OperationsSnapshot({
    required this.todayVisits,
    required this.activeMemberships,
    required this.bookingRequests,
    required this.customers,
    required this.toBuy,
    required this.purchaseHistory,
    required this.pricing,
    required this.promotions,
    required this.income,
  });

  final List<VisitRecord> todayVisits;
  final List<MembershipRecord> activeMemberships;
  final List<BookingRequestRecord> bookingRequests;
  final List<CustomerRecord> customers;
  final List<PurchaseRequestRecord> toBuy;
  final List<PurchaseRequestRecord> purchaseHistory;
  final PricingConfig pricing;
  final List<PromotionRecord> promotions;
  final IncomeSummary income;

  factory OperationsSnapshot.fromJson(Map<String, dynamic> json) {
    return OperationsSnapshot(
      todayVisits: _listOf(json['today_visits'], VisitRecord.fromJson),
      activeMemberships: _listOf(
        json['active_memberships'],
        MembershipRecord.fromJson,
      ),
      bookingRequests: _listOf(
        json['booking_requests'],
        BookingRequestRecord.fromJson,
      ),
      customers: _listOf(json['customers'], CustomerRecord.fromJson),
      toBuy: _listOf(json['to_buy'], PurchaseRequestRecord.fromJson),
      purchaseHistory: _listOf(
        json['purchase_history'],
        PurchaseRequestRecord.fromJson,
      ),
      pricing: PricingConfig.fromJson(_map(json['pricing'])),
      promotions: _listOf(json['promotions'], PromotionRecord.fromJson),
      income: IncomeSummary.fromJson(_map(json['income'])),
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
