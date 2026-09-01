// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:evil_space/admin_api_models.dart';
import 'package:evil_space/admin_telegram_models.dart';

class AdminApi {
  Future<AdminSession> session() async {
    final data = await _request('GET', '/api/admin/session');
    return AdminSession.fromJson(data);
  }

  Future<String> register({
    required String email,
    required String password,
  }) async {
    final data = await _request(
      'POST',
      '/api/admin/register',
      body: {'email': email, 'password': password},
    );
    return data['message']?.toString() ?? 'Approval request sent.';
  }

  Future<AdminSession> login({
    required String email,
    required String password,
  }) async {
    final data = await _request(
      'POST',
      '/api/admin/login',
      body: {'email': email, 'password': password},
    );
    return AdminSession.fromJson(data);
  }

  Future<void> logout() async {
    await _request('POST', '/api/admin/logout');
  }

  Future<List<AdminAccount>> admins() async {
    final data = await _request('GET', '/api/admin/admins');
    final raw = data['admins'];
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((item) => AdminAccount.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<DeleteAdminResult> deleteAdmin({
    required String email,
    required String superPassword,
  }) async {
    final data = await _request(
      'POST',
      '/api/admin/delete',
      body: {'email': email, 'superPassword': superPassword},
    );
    return DeleteAdminResult.fromJson(data);
  }

  Future<AdminTelegramStatus> telegramStatus() async {
    final data = await _request('GET', '/api/admin/telegram');
    return AdminTelegramStatus.fromJson(data);
  }

  Future<AdminTelegramLink> createTelegramLink(String languageCode) async {
    final data = await _request(
      'POST',
      '/api/admin/telegram/link',
      body: {'language': languageCode},
    );
    return AdminTelegramLink.fromJson(data);
  }

  Future<void> disconnectTelegram() async {
    await _request('POST', '/api/admin/telegram/disconnect');
  }

  Future<AdminTelegramStatus> updateTelegramPreferences({
    required bool bookingNotifications,
    required bool purchaseNotifications,
  }) async {
    final data = await _request(
      'POST',
      '/api/admin/telegram/preferences',
      body: {
        'bookingNotifications': bookingNotifications,
        'purchaseNotifications': purchaseNotifications,
      },
    );
    return AdminTelegramStatus.fromJson(data);
  }

  Future<OperationsSnapshot> operations() async {
    final data = await _request('GET', '/api/admin/operations');
    return OperationsSnapshot.fromJson(_snapshotMap(data));
  }

  Future<OperationsSnapshot> updatePricing({
    required int dayPassVnd,
    required int monthPassVnd,
    required int lockerMonthVnd,
  }) async {
    return _operation('POST', '/api/admin/pricing', {
      'dayPassVnd': dayPassVnd,
      'monthPassVnd': monthPassVnd,
      'lockerMonthVnd': lockerMonthVnd,
    });
  }

  Future<OperationsSnapshot> createPromotion({
    required String description,
    required String startDate,
    required String endDate,
    String? startTime,
    String? endTime,
    int? dayPassVnd,
    int? monthPassVnd,
    int? lockerMonthVnd,
  }) async {
    return _operation('POST', '/api/admin/promotions', {
      'description': description,
      'startDate': startDate,
      'endDate': endDate,
      'startTime': startTime,
      'endTime': endTime,
      'dayPassVnd': dayPassVnd,
      'monthPassVnd': monthPassVnd,
      'lockerMonthVnd': lockerMonthVnd,
    });
  }

  Future<OperationsSnapshot> setPromotionEnabled(int id, bool enabled) async {
    return _operation('POST', '/api/admin/promotions/toggle', {
      'id': id,
      'enabled': enabled,
    });
  }

  Future<OperationsSnapshot> deletePromotion(int id) async {
    return _operation('POST', '/api/admin/promotions/delete', {'id': id});
  }

  Future<OperationsSnapshot> addDayPass(String name) async {
    return _operation('POST', '/api/admin/day-pass', {'name': name});
  }

  Future<OperationsSnapshot> addMonthPass(String name) async {
    return _operation('POST', '/api/admin/month-new', {'name': name});
  }

  Future<OperationsSnapshot> checkInMembership(int membershipId) async {
    return _operation('POST', '/api/admin/month-active', {
      'membershipId': membershipId,
    });
  }

  Future<OperationsSnapshot> acceptBooking(int id) async {
    await _request('POST', '/api/admin/booking/accept', body: {'id': id});
    return operations();
  }

  Future<OperationsSnapshot> declineBooking(int id) async {
    await _request('POST', '/api/admin/booking/decline', body: {'id': id});
    return operations();
  }

  Future<OperationsSnapshot> updateCustomer(CustomerRecord customer) async {
    return _operation('POST', '/api/admin/customers/update', {
      'id': customer.id,
      'name': customer.name,
      'phone': customer.phone,
      'email': customer.email,
      'telegram': customer.telegram,
      'contactOther': customer.contactOther,
      'notes': customer.notes,
    });
  }

  Future<OperationsSnapshot> updateCustomerFields({
    required int id,
    required String name,
    required String phone,
    required String email,
    required String telegram,
    required String contactOther,
    required String notes,
  }) async {
    return _operation('POST', '/api/admin/customers/update', {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'telegram': telegram,
      'contactOther': contactOther,
      'notes': notes,
    });
  }

  Future<OperationsSnapshot> deleteCustomer(int id) async {
    return _operation('POST', '/api/admin/customers/delete', {'id': id});
  }

  Future<OperationsSnapshot> addPurchase(String title) async {
    return _operation('POST', '/api/admin/purchases', {'title': title});
  }

  Future<OperationsSnapshot> markPurchaseBought(int id) async {
    return _operation('POST', '/api/admin/purchases/bought', {'id': id});
  }

  Future<OperationsSnapshot> _operation(
    String method,
    String path,
    Map<String, dynamic> body,
  ) async {
    final data = await _request(method, path, body: body);
    return OperationsSnapshot.fromJson(_snapshotMap(data));
  }

  Map<String, dynamic> _snapshotMap(Map<String, dynamic> data) {
    final snapshot = data['snapshot'];
    if (snapshot is Map<String, dynamic>) return snapshot;
    if (snapshot is Map) return Map<String, dynamic>.from(snapshot);
    return data;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final headers = web.Headers();
    headers.set('Accept', 'application/json');
    if (body != null) {
      headers.set('Content-Type', 'application/json');
    }

    final init = web.RequestInit(
      method: method,
      headers: headers,
      credentials: 'same-origin',
      body: body == null ? null : jsonEncode(body).toJS,
    );

    final response = await web.window.fetch(path.toJS, init).toDart;
    final raw = (await response.text().toDart).toDart;
    final decoded = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    if (!response.ok) {
      throw AdminApiException(
        data['error']?.toString() ?? 'Request failed.',
        statusCode: response.status,
      );
    }

    return data;
  }
}
