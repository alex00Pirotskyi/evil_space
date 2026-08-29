import 'package:evil_space/admin_api_models.dart';

class AdminApi {
  Future<AdminSession> session() async => const AdminSession.signedOut();

  Future<String> register({
    required String email,
    required String password,
  }) async => _webOnly();

  Future<AdminSession> login({
    required String email,
    required String password,
  }) async => _webOnly();

  Future<void> logout() async {}

  Future<List<AdminAccount>> admins() async => _webOnly();

  Future<DeleteAdminResult> deleteAdmin({
    required String email,
    required String superPassword,
  }) async => _webOnly();

  Future<OperationsSnapshot> operations() async => _webOnly();

  Future<OperationsSnapshot> addDayPass(String name) async => _webOnly();

  Future<OperationsSnapshot> addMonthPass(String name) async => _webOnly();

  Future<OperationsSnapshot> checkInMembership(int membershipId) async =>
      _webOnly();

  Future<OperationsSnapshot> acceptBooking(int id) async => _webOnly();

  Future<OperationsSnapshot> updateCustomer(CustomerRecord customer) async =>
      _webOnly();

  Future<OperationsSnapshot> updateCustomerFields({
    required int id,
    required String name,
    required String phone,
    required String email,
    required String telegram,
    required String contactOther,
    required String notes,
  }) async => _webOnly();

  Future<OperationsSnapshot> deleteCustomer(int id) async => _webOnly();

  Future<OperationsSnapshot> addPurchase(String title) async => _webOnly();

  Future<OperationsSnapshot> markPurchaseBought(int id) async => _webOnly();

  Never _webOnly() {
    throw const AdminApiException(
      'Admin access is available from the deployed web app.',
    );
  }
}
