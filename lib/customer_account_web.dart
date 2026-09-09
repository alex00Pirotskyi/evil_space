// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';

import 'package:web/web.dart' as web;

import 'customer_account_models.dart';

class CustomerAccountApi {
  static const _deviceStorageKey = 'evil_space_device_id_v1';

  Future<CustomerAccountSnapshot> snapshot() async {
    final data = await _request('GET', '/api/public/account');
    return CustomerAccountSnapshot.fromJson(data);
  }

  Future<PhoneChallenge> startPhone(String name, String phone) async {
    final data = await _request(
      'POST',
      '/api/public/account/phone/start',
      body: {
        'name': name,
        'phone': phone,
        'device': _deviceProfile(),
      },
    );
    return PhoneChallenge.fromJson(data);
  }

  Future<CustomerAccountSnapshot> verifyPhone(
    String challenge,
    String code,
  ) async {
    final data = await _request(
      'POST',
      '/api/public/account/phone/verify',
      body: {'challenge': challenge, 'code': code},
    );
    return CustomerAccountSnapshot.fromJson(data);
  }

  Future<TelegramSignup> startTelegram() async {
    final data = await _request(
      'POST',
      '/api/public/account/telegram/start',
      body: {'device': _deviceProfile()},
    );
    return TelegramSignup.fromJson(data);
  }

  Future<CustomerAccountSnapshot?> telegramStatus(String token) async {
    try {
      final data = await _request(
        'GET',
        '/api/public/account/telegram/status?token=${Uri.encodeQueryComponent(token)}',
      );
      if (data['authenticated'] != true) return null;
      return CustomerAccountSnapshot.fromJson(data);
    } on CustomerAccountException catch (error) {
      if (error.statusCode == 404 || error.statusCode == 410) return null;
      rethrow;
    }
  }

  Future<CustomerAccountSnapshot> signInGoogle(String idToken) async {
    final data = await _request(
      'POST',
      '/api/public/account/google',
      body: {'idToken': idToken, 'device': _deviceProfile()},
    );
    return CustomerAccountSnapshot.fromJson(data);
  }

  Future<void> logout() async {
    await _request('POST', '/api/public/account/logout', body: const {});
  }

  Map<String, dynamic> _deviceProfile() {
    final navigator = web.window.navigator;
    return {
      'deviceId': _deviceId(),
      'platform': navigator.platform,
      'userAgent': navigator.userAgent,
      'language': navigator.language,
      'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      'screenWidth': web.window.screen.width,
      'screenHeight': web.window.screen.height,
      'viewportWidth': web.window.innerWidth,
      'viewportHeight': web.window.innerHeight,
      'pixelRatio': web.window.devicePixelRatio,
      'touchPoints': navigator.maxTouchPoints,
      'hardwareConcurrency': navigator.hardwareConcurrency,
      'vendor': navigator.vendor,
      'referrer': web.document.referrer,
    };
  }

  String _deviceId() {
    final existing = web.window.localStorage.getItem(_deviceStorageKey);
    if (existing != null &&
        RegExp(r'^[A-Za-z0-9_-]{16,100}$').hasMatch(existing)) {
      return existing;
    }
    final random = Random.secure();
    final value = 'dev_${List.generate(24, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    web.window.localStorage.setItem(_deviceStorageKey, value);
    return value;
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
      throw CustomerAccountException(
        data['error']?.toString() ?? 'Account request failed.',
        statusCode: response.status,
      );
    }
    return data;
  }
}
