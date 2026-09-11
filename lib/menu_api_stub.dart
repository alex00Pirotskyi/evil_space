import 'menu_models.dart';

class MenuApi {
  Future<MenuCatalog> menu() async => const MenuCatalog.empty();

  Future<MenuOrderPayment> createOrder(String itemId) {
    throw const MenuApiException('Menu ordering is available on web.');
  }

  Future<MenuOrderPayment> createCartOrder(
    Map<String, int> cart, {
    int? promoGrantId,
  }) {
    throw const MenuApiException('Menu ordering is available on web.');
  }

  Future<List<PromoPreview>> eligiblePromos(Map<String, int> cart) async => const [];
  Future<List<CustomerPromo>> customerPromos() async => const [];
  Future<List<CustomerPromo>> claimPromo(String code) async => const [];

  Future<MenuOrderStatus> orderStatus(String token) {
    throw const MenuApiException('Menu ordering is available on web.');
  }

  Future<AdminMenuSnapshot> adminSnapshot() {
    throw const MenuApiException('Menu admin is available on web.');
  }

  Future<AdminMenuSnapshot> uploadMenuJson(Map<String, dynamic> menu) {
    throw const MenuApiException('Menu admin is available on web.');
  }

  Future<MenuDraftSnapshot> menuDraft() {
    throw const MenuApiException('Menu admin is available on web.');
  }

  Future<MenuDraftSnapshot> saveMenuDraft(MenuCatalog menu) {
    throw const MenuApiException('Menu admin is available on web.');
  }

  Future<(AdminMenuSnapshot, MenuDraftSnapshot)> publishMenuDraft(MenuCatalog menu) {
    throw const MenuApiException('Menu admin is available on web.');
  }

  Future<List<AdminPromotion>> adminPromotions() async => const [];
  Future<List<AdminPromotion>> createPromotion(Map<String, dynamic> promo) async => const [];
  Future<List<AdminPromotion>> updatePromotion(Map<String, dynamic> promo) async => const [];
  Future<List<AdminPromotion>> disablePromotion(int id) async => const [];
  Future<List<AdminCustomerSummary>> adminCustomers({String query = ''}) async => const [];

  Future<AdminCustomerDetail> adminCustomer(int id) {
    throw const MenuApiException('Customer admin is available on web.');
  }

  Future<AdminCustomerDetail> grantCustomerPromo({
    required int customerId,
    required int promotionId,
    int uses = 1,
  }) {
    throw const MenuApiException('Customer admin is available on web.');
  }

  Future<AdminCustomerDetail> revokeCustomerPromo(int grantId) {
    throw const MenuApiException('Customer admin is available on web.');
  }

  Future<Map<String, dynamic>?> pickMenuJson() async => null;

  Future<AdminMenuSnapshot> markPaid(int id) {
    throw const MenuApiException('Menu admin is available on web.');
  }
}
