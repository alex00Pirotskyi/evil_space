import 'package:evil_space/admin_api_models.dart';

class AdminApi {
  Future<AdminSession> session() async => const AdminSession.signedOut();

  Future<String> register({
    required String email,
    required String password,
  }) async {
    throw const AdminApiException(
      'Admin access is available from the deployed web app.',
    );
  }

  Future<AdminSession> login({
    required String email,
    required String password,
  }) async {
    throw const AdminApiException(
      'Admin access is available from the deployed web app.',
    );
  }

  Future<void> logout() async {}

  Future<List<AdminAccount>> admins() async {
    throw const AdminApiException(
      'Admin access is available from the deployed web app.',
    );
  }

  Future<DeleteAdminResult> deleteAdmin({
    required String email,
    required String superPassword,
  }) async {
    throw const AdminApiException(
      'Admin access is available from the deployed web app.',
    );
  }
}
