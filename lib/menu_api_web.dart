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

  Future<MenuOrderPayment> createOrder(String itemId) async {
    final data = await _request(
      'POST',
      '/api/public/menu/order',
      body: {'itemId': itemId},
    );
    return MenuOrderPayment.fromJson(_map(data['order']));
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

  Future<Map<String, dynamic>?> pickMenuJson() async {
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = '.json,application/json';
    final completer = Completer<Map<String, dynamic>?>();

    late final JSFunction listener;
    listener = ((web.Event _) async {
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
          if (!completer.isCompleted) {
            completer.complete(Map<String, dynamic>.from(decoded));
          }
        } else {
          throw const FormatException('Menu JSON must contain an object.');
        }
      } catch (error, stackTrace) {
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      }
    }).toJS;

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
