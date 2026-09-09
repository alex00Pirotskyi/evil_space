import 'menu_models.dart';

class MenuApi {
  Future<MenuCatalog> menu() async => const MenuCatalog.empty();

  Future<MenuOrderPayment> createOrder(String itemId) {
    throw const MenuApiException('Menu ordering is available on web.');
  }

  Future<MenuOrderPayment> createCartOrder(Map<String, int> cart) {
    throw const MenuApiException('Menu ordering is available on web.');
  }

  Future<MenuOrderStatus> orderStatus(String token) {
    throw const MenuApiException('Menu ordering is available on web.');
  }

  Future<AdminMenuSnapshot> adminSnapshot() {
    throw const MenuApiException('Menu admin is available on web.');
  }

  Future<AdminMenuSnapshot> uploadMenuJson(Map<String, dynamic> menu) {
    throw const MenuApiException('Menu admin is available on web.');
  }

  Future<Map<String, dynamic>?> pickMenuJson() async => null;

  Future<AdminMenuSnapshot> markPaid(int id) {
    throw const MenuApiException('Menu admin is available on web.');
  }
}
