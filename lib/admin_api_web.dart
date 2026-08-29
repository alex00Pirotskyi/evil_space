// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:evil_space/admin_api_models.dart';

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

  Future<OperationsSnapshot> operations() async {
    final data = await _request('GET', '/api/admin/operations');
    return OperationsSnapshot.fromJson(_snapshotMap(data));
  }

  Future<OperationsSnapshot> addDayPass(String name) async {
    return _operation('POST', '/api/admin/day-pass', {'name': name});
  }

  Future<OperationsSnapshot> addMonthPass(String name) async {
    return _operation('POST', '/api/admin/month-new', {'name': name});
  }

  Future<OperationsSnapshot> checkInMembership(int membershipId) async {
    return _operation(
      'POST',
      '/api/admin/month-active',
      {'membershipId': membershipId},
    );
  }

  Future<OperationsSnapshot> addPurchase(String title) async {
    return _operation('POST', '/api/admin/purchases', {'title': title});
  }

  Future<OperationsSnapshot> markPurchaseBought(int id) async {
    return _operation(
      'POST',
      '/api/admin/purchases/bought',
      {'id': id},
    );
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
