class DeskBookingProfile {
  const DeskBookingProfile({
    required this.name,
    required this.contactType,
    required this.contactValue,
    required this.serviceDate,
  });

  final String name;
  final String contactType;
  final String contactValue;
  final String serviceDate;

  Map<String, dynamic> toJson() => {
    'name': name,
    'contactType': contactType,
    'contactValue': contactValue,
    'serviceDate': serviceDate,
  };

  factory DeskBookingProfile.fromJson(Map<String, dynamic> json) {
    return DeskBookingProfile(
      name: json['name']?.toString() ?? '',
      contactType: json['contactType']?.toString() ?? '',
      contactValue: json['contactValue']?.toString() ?? '',
      serviceDate: json['serviceDate']?.toString() ?? '',
    );
  }

  bool get valid =>
      name.trim().isNotEmpty &&
      (contactType == 'phone' || contactType == 'telegram') &&
      contactValue.trim().isNotEmpty &&
      RegExp(r'^\d{4}-\d{2}-\d{2}\$').hasMatch(serviceDate);
}

class DeskBookingState {
  const DeskBookingState({
    required this.token,
    required this.status,
    this.telegramLinkUrl,
    this.telegramLinked = false,
    required this.serviceDate,
    required this.amountVnd,
  });

  final String token;
  final String status;
  final String? telegramLinkUrl;
  final bool telegramLinked;
  final String serviceDate;
  final int amountVnd;

  bool get pending => status == 'pending';
  bool get accepted => status == 'accepted';
  bool get declined => status == 'declined';
  bool get cancelled => status == 'cancelled';
  bool get finished => declined || cancelled;
  bool get canConnectTelegram =>
      !telegramLinked &&
      telegramLinkUrl != null &&
      telegramLinkUrl!.startsWith('https://t.me/');
  bool get valid =>
      token.length >= 32 &&
      (pending || accepted || declined || cancelled) &&
      RegExp(r'^\d{4}-\d{2}-\d{2}\$').hasMatch(serviceDate) &&
      amountVnd > 0;

  Map<String, dynamic> toJson() => {
    'token': token,
    'status': status,
    if (telegramLinkUrl != null) 'telegramLinkUrl': telegramLinkUrl,
    'telegramLinked': telegramLinked,
    'serviceDate': serviceDate,
    'amountVnd': amountVnd,
  };

  factory DeskBookingState.fromJson(Map<String, dynamic> json) {
    return DeskBookingState(
      token: json['token']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      telegramLinkUrl: json['telegramLinkUrl']?.toString(),
      telegramLinked: json['telegramLinked'] == true,
      serviceDate: json['serviceDate']?.toString() ?? '',
      amountVnd: (json['amountVnd'] as num?)?.toInt() ?? 0,
    );
  }

  DeskBookingState withStatus(String value) => DeskBookingState(
    token: token,
    status: value,
    telegramLinkUrl: telegramLinkUrl,
    telegramLinked: telegramLinked,
    serviceDate: serviceDate,
    amountVnd: amountVnd,
  );
}

class PublicDeskException implements Exception {
  const PublicDeskException(this.message);

  final String message;

  @override
  String toString() => message;
}
