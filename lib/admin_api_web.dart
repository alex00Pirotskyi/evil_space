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
