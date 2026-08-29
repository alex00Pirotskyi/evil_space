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

class AdminApiException implements Exception {
  const AdminApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
