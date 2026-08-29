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
  const DeskBookingState({required this.token, required this.status});

  final String token;
  final String status;

  bool get pending => status == 'pending';
  bool get accepted => status == 'accepted';
  bool get valid =>
      token.length >= 32 && (status == 'pending' || status == 'accepted');

  Map<String, dynamic> toJson() => {'token': token, 'status': status};

  factory DeskBookingState.fromJson(Map<String, dynamic> json) {
    return DeskBookingState(
      token: json['token']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }

  DeskBookingState withStatus(String value) =>
      DeskBookingState(token: token, status: value);
}

class PublicDeskException implements Exception {
  const PublicDeskException(this.message);

  final String message;

  @override
  String toString() => message;
}
