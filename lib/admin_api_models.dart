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
