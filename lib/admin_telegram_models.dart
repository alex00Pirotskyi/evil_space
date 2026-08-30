class AdminTelegramStatus {
  const AdminTelegramStatus({
    required this.linked,
    required this.username,
    required this.bookingNotifications,
    required this.purchaseNotifications,
    required this.botUsername,
  });

  final bool linked;
  final String username;
  final bool bookingNotifications;
  final bool purchaseNotifications;
  final String botUsername;

  factory AdminTelegramStatus.fromJson(Map<String, dynamic> json) {
    return AdminTelegramStatus(
      linked: json['linked'] == true,
      username: json['username']?.toString() ?? '',
      bookingNotifications: json['bookingNotifications'] != false,
      purchaseNotifications: json['purchaseNotifications'] != false,
      botUsername: json['botUsername']?.toString() ?? 'CoworkingEvilAdminBot',
    );
  }
}

class AdminTelegramLink {
  const AdminTelegramLink({required this.url, required this.expiresAt});

  final String url;
  final int expiresAt;

  factory AdminTelegramLink.fromJson(Map<String, dynamic> json) {
    return AdminTelegramLink(
      url: json['url']?.toString() ?? '',
      expiresAt: int.tryParse(json['expiresAt']?.toString() ?? '') ?? 0,
    );
  }

  bool get valid => url.startsWith('https://t.me/') && expiresAt > 0;
}
