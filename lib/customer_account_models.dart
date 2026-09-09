class CustomerIdentityView {
  const CustomerIdentityView({
    required this.provider,
    required this.displayValue,
    required this.verifiedAt,
  });

  final String provider;
  final String displayValue;
  final int verifiedAt;

  factory CustomerIdentityView.fromJson(Map<String, dynamic> json) {
    return CustomerIdentityView(
      provider: json['provider']?.toString() ?? '',
      displayValue: json['displayValue']?.toString() ?? '',
      verifiedAt: (json['verifiedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

class CustomerAccountView {
  const CustomerAccountView({
    required this.id,
    required this.name,
    required this.identities,
    required this.deviceCount,
    this.phone,
    this.email,
    this.telegram,
  });

  final int id;
  final String name;
  final String? phone;
  final String? email;
  final String? telegram;
  final List<CustomerIdentityView> identities;
  final int deviceCount;

  bool hasProvider(String provider) =>
      identities.any((identity) => identity.provider == provider);

  factory CustomerAccountView.fromJson(Map<String, dynamic> json) {
    final raw = json['identities'];
    final identities = <CustomerIdentityView>[];
    if (raw is List) {
      for (final item in raw.whereType<Map>()) {
        identities.add(
          CustomerIdentityView.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }
    return CustomerAccountView(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      phone: _nullableText(json['phone']),
      email: _nullableText(json['email']),
      telegram: _nullableText(json['telegram']),
      identities: identities,
      deviceCount: (json['deviceCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class CustomerProviderConfig {
  const CustomerProviderConfig({
    required this.phone,
    required this.telegram,
    required this.telegramBotUsername,
    required this.google,
    this.googleClientId,
  });

  final bool phone;
  final bool telegram;
  final String telegramBotUsername;
  final bool google;
  final String? googleClientId;

  factory CustomerProviderConfig.fromJson(Map<String, dynamic> json) {
    return CustomerProviderConfig(
      phone: json['phone'] == true,
      telegram: json['telegram'] == true,
      telegramBotUsername:
          json['telegramBotUsername']?.toString() ?? 'CoworkingEvilAdminBot',
      google: json['google'] == true,
      googleClientId: _nullableText(json['googleClientId']),
    );
  }
}

class CustomerAccountSnapshot {
  const CustomerAccountSnapshot({
    required this.authenticated,
    required this.adminAuthenticated,
    required this.providers,
    required this.registrationDiscountPercent,
    this.customer,
  });

  final bool authenticated;
  final bool adminAuthenticated;
  final CustomerProviderConfig providers;
  final int registrationDiscountPercent;
  final CustomerAccountView? customer;

  factory CustomerAccountSnapshot.fromJson(Map<String, dynamic> json) {
    final customerJson = json['customer'];
    final providerJson = json['providers'];
    return CustomerAccountSnapshot(
      authenticated: json['authenticated'] == true,
      adminAuthenticated: json['adminAuthenticated'] == true,
      customer: customerJson is Map
          ? CustomerAccountView.fromJson(Map<String, dynamic>.from(customerJson))
          : null,
      providers: CustomerProviderConfig.fromJson(
        providerJson is Map
            ? Map<String, dynamic>.from(providerJson)
            : const <String, dynamic>{},
      ),
      registrationDiscountPercent:
          (json['registrationDiscountPercent'] as num?)?.toInt() ?? 50,
    );
  }
}

class PhoneChallenge {
  const PhoneChallenge({
    required this.challenge,
    required this.phone,
    required this.expiresAt,
  });

  final String challenge;
  final String phone;
  final int expiresAt;

  factory PhoneChallenge.fromJson(Map<String, dynamic> json) {
    return PhoneChallenge(
      challenge: json['challenge']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      expiresAt: (json['expiresAt'] as num?)?.toInt() ?? 0,
    );
  }
}

class TelegramSignup {
  const TelegramSignup({
    required this.token,
    required this.url,
    required this.expiresAt,
  });

  final String token;
  final String url;
  final int expiresAt;

  factory TelegramSignup.fromJson(Map<String, dynamic> json) {
    return TelegramSignup(
      token: json['token']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      expiresAt: (json['expiresAt'] as num?)?.toInt() ?? 0,
    );
  }
}

class CustomerAccountException implements Exception {
  const CustomerAccountException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

String? _nullableText(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
