import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'menu_models.dart';

class MenuApi {
  Future<MenuCatalog> menu() async {
    final data = await _request('GET', '/api/public/menu');
    return MenuCatalog.fromJson(_map(data['menu']));
  }

  Future<MenuOrderPayment> createOrder(String itemId) {
    return createCartOrder({itemId: 1});
  }

  Future<MenuOrderPayment> createCartOrder(
    Map<String, int> cart, {
    int? promoGrantId,
  }) async {
    final items = _cartItems(cart);
    final data = await _request(
      'POST',
      '/api/public/menu/order',
      body: {
        'items': items,
        if (promoGrantId != null) 'promoGrantId': promoGrantId,
      },
    );
    return MenuOrderPayment.fromJson(_map(data['order']));
  }

  Future<List<PromoPreview>> eligiblePromos(Map<String, int> cart) async {
    final data = await _request(
      'POST',
      '/api/public/menu/promos',
      body: {'items': _cartItems(cart)},
    );
    return _list(data['promos'], PromoPreview.fromJson);
  }

  Future<List<CustomerPromo>> customerPromos() async {
    final data = await _request('GET', '/api/public/account/promos');
    return _list(data['promos'], CustomerPromo.fromJson);
  }

  Future<List<CustomerPromo>> claimPromo(String code) async {
    final data = await _request(
      'POST',
      '/api/public/account/promos/claim',
      body: {'code': code},
    );
    return _list(data['promos'], CustomerPromo.fromJson);
  }

  Future<MenuOrderStatus> orderStatus(String token) async {
    final data = await _request(
      'GET',
      '/api/public/menu/order?token=${Uri.encodeQueryComponent(token)}',
    );
    return MenuOrderStatus.fromJson(_map(data['order']));
  }

  Future<AdminMenuSnapshot> adminSnapshot() async {
    final data = await _request('GET', '/api/admin/menu');
    return AdminMenuSnapshot.fromJson(_map(data['snapshot']));
  }

  Future<AdminMenuSnapshot> uploadMenuJson(Map<String, dynamic> menu) async {
    final data = await _request(
      'POST',
      '/api/admin/menu/upload',
      body: {'menu': menu},
    );
    return AdminMenuSnapshot.fromJson(_map(data['snapshot']));
  }

  Future<MenuDraftSnapshot> menuDraft() async {
    final data = await _request('GET', '/api/admin/menu/draft');
    return MenuDraftSnapshot.fromJson(_map(data['draft']));
  }

  Future<MenuDraftSnapshot> saveMenuDraft(MenuCatalog menu) async {
    final data = await _request(
      'POST',
      '/api/admin/menu/draft',
      body: {'menu': menu.toJson()},
    );
    return MenuDraftSnapshot.fromJson(_map(data['draft']));
  }

  Future<(AdminMenuSnapshot, MenuDraftSnapshot)> publishMenuDraft(
    MenuCatalog menu,
  ) async {
    final data = await _request(
      'POST',
      '/api/admin/menu/publish',
      body: {'menu': menu.toJson()},
    );
    return (
      AdminMenuSnapshot.fromJson(_map(data['snapshot'])),
      MenuDraftSnapshot.fromJson(_map(data['draft'])),
    );
  }

  Future<List<AdminPromotion>> adminPromotions() async {
    final data = await _request('GET', '/api/admin/promos');
    return _list(_map(data['snapshot'])['promos'], AdminPromotion.fromJson);
  }

  Future<List<AdminPromotion>> createPromotion(Map<String, dynamic> promo) async {
    final data = await _request('POST', '/api/admin/promos', body: promo);
    return _list(_map(data['snapshot'])['promos'], AdminPromotion.fromJson);
  }

  Future<List<AdminPromotion>> updatePromotion(Map<String, dynamic> promo) async {
    final data = await _request('POST', '/api/admin/promos/update', body: promo);
    return _list(_map(data['snapshot'])['promos'], AdminPromotion.fromJson);
  }

  Future<List<AdminPromotion>> disablePromotion(int id) async {
    final data = await _request(
      'POST',
      '/api/admin/promos/disable',
      body: {'id': id},
    );
    return _list(_map(data['snapshot'])['promos'], AdminPromotion.fromJson);
  }

  Future<List<AdminCustomerSummary>> adminCustomers({String query = ''}) async {
    final data = await _request(
      'GET',
      '/api/admin/customers?q=${Uri.encodeQueryComponent(query)}',
    );
    return _list(data['customers'], AdminCustomerSummary.fromJson);
  }

  Future<AdminCustomerDetail> adminCustomer(int id) async {
    final data = await _request('GET', '/api/admin/customers?id=$id');
    return AdminCustomerDetail.fromJson(_map(data['customer']));
  }

  Future<AdminCustomerDetail> grantCustomerPromo({
    required int customerId,
    required int promotionId,
    int uses = 1,
  }) async {
    final data = await _request(
      'POST',
      '/api/admin/customers/promos/grant',
      body: {
        'customerId': customerId,
        'promotionId': promotionId,
        'uses': uses,
      },
    );
    return AdminCustomerDetail.fromJson(_map(data['customer']));
  }

  Future<AdminCustomerDetail> revokeCustomerPromo(int grantId) async {
    final data = await _request(
      'POST',
      '/api/admin/customers/promos/revoke',
      body: {'grantId': grantId},
    );
    return AdminCustomerDetail.fromJson(_map(data['customer']));
  }

  Future<Map<String, dynamic>?> pickMenuJson() async {
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = '.json,application/json';
    final completer = Completer<Map<String, dynamic>?>();

    Future<void> readSelectedFile() async {
      try {
        final file = input.files?.item(0);
        if (file == null) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }
        final raw = (await file.text().toDart).toDart;
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          if (!completer.isCompleted) completer.complete(decoded);
        } else if (decoded is Map) {
          if (!completer.isCompleted) completer.complete(Map<String, dynamic>.from(decoded));
        } else {
          throw const FormatException('Menu JSON must contain an object.');
        }
      } catch (error, stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      }
    }

    late final JSFunction listener;
    listener = ((web.Event _) { unawaited(readSelectedFile()); }).toJS;
    input.addEventListener('change', listener);
    input.click();
    return completer.future.whenComplete(
      () => input.removeEventListener('change', listener),
    );
  }

  Future<AdminMenuSnapshot> markPaid(int id) async {
    final data = await _request(
      'POST',
      '/api/admin/menu/order/paid',
      body: {'id': id},
    );
    return AdminMenuSnapshot.fromJson(_map(data['snapshot']));
  }

  List<Map<String, dynamic>> _cartItems(Map<String, int> cart) => cart.entries
      .where((entry) => entry.value > 0)
      .map((entry) => <String, dynamic>{'itemId': entry.key, 'quantity': entry.value})
      .toList(growable: false);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final headers = web.Headers();
    headers.set('Accept', 'application/json');
    if (body != null) headers.set('Content-Type', 'application/json');

    final response = await web.window
        .fetch(
          path.toJS,
          web.RequestInit(
            method: method,
            headers: headers,
            credentials: 'same-origin',
            body: body == null ? null : jsonEncode(body).toJS,
          ),
        )
        .toDart;
    final raw = (await response.text().toDart).toDart;
    final decoded = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : decoded is Map
            ? Map<String, dynamic>.from(decoded)
            : <String, dynamic>{};

    if (!response.ok) {
      throw MenuApiException(
        data['error']?.toString() ?? 'Request failed.',
        statusCode: response.status,
      );
    }
    return data;
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) parser) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((entry) => parser(Map<String, dynamic>.from(entry)))
      .toList(growable: false);
}
