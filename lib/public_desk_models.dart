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

class PublicDeskException implements Exception {
  const PublicDeskException(this.message);

  final String message;

  @override
  String toString() => message;
}
