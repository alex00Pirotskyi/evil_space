class DeskBookingProfile {
  const DeskBookingProfile({
    required this.name,
    required this.contactType,
    required this.contactValue,
  });

  final String name;
  final String contactType;
  final String contactValue;

  Map<String, dynamic> toJson() => {
    'name': name,
    'contactType': contactType,
    'contactValue': contactValue,
  };

  factory DeskBookingProfile.fromJson(Map<String, dynamic> json) {
    return DeskBookingProfile(
      name: json['name']?.toString() ?? '',
      contactType: json['contactType']?.toString() ?? '',
      contactValue: json['contactValue']?.toString() ?? '',
    );
  }

  bool get valid =>
      name.trim().isNotEmpty &&
      (contactType == 'phone' || contactType == 'telegram') &&
      contactValue.trim().isNotEmpty;
}

class DeskBookingState {
  const DeskBookingState({
    required this.token,
    required this.status,
    this.telegramLinkUrl,
    this.telegramLinked = false,
  });

  final String token;
  final String status;
  final String? telegramLinkUrl;
  final bool telegramLinked;

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
      (pending || accepted || declined || cancelled);

  Map<String, dynamic> toJson() => {
    'token': token,
    'status': status,
    if (telegramLinkUrl != null) 'telegramLinkUrl': telegramLinkUrl,
    'telegramLinked': telegramLinked,
  };

  factory DeskBookingState.fromJson(Map<String, dynamic> json) {
    return DeskBookingState(
      token: json['token']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      telegramLinkUrl: json['telegramLinkUrl']?.toString(),
      telegramLinked: json['telegramLinked'] == true,
    );
  }

  DeskBookingState withStatus(String value) => DeskBookingState(
    token: token,
    status: value,
    telegramLinkUrl: telegramLinkUrl,
    telegramLinked: telegramLinked,
  );
}

class PublicDeskException implements Exception {
  const PublicDeskException(this.message);

  final String message;

  @override
  String toString() => message;
}
