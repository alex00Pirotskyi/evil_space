// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';

import 'package:web/web.dart' as web;

import 'customer_account_models.dart';

class CustomerAccountApi {
  static const _deviceStorageKey = 'evil_space_device_id_v1';
  static const _googleStateKey = 'evil_space_google_state_v1';
  static const _googleNonceKey = 'evil_space_google_nonce_v1';

  Future<CustomerAccountSnapshot> snapshot() async {
    final callback = await _consumeGoogleCallback();
    if (callback != null) return callback;
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

  Future<void> beginGoogleSignIn(String clientId) async {
    if (clientId.trim().isEmpty) {
      throw const CustomerAccountException('Google Sign-In is not configured.');
    }
    final state = _randomToken(24);
    final nonce = _randomToken(24);
    web.window.sessionStorage.setItem(_googleStateKey, state);
    web.window.sessionStorage.setItem(_googleNonceKey, nonce);
    final redirectUri = '${web.window.location.origin}/';
    final uri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'id_token',
      'scope': 'openid email profile',
      'nonce': nonce,
      'state': state,
      'prompt': 'select_account',
    });
    web.window.location.assign(uri.toString());
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

  Future<CustomerAccountSnapshot?> _consumeGoogleCallback() async {
    final hash = web.window.location.hash;
    if (!hash.startsWith('#') || !hash.contains('id_token=')) return null;
    Map<String, String> values;
    try {
      values = Uri.splitQueryString(hash.substring(1));
    } catch (_) {
      return null;
    }
    final idToken = values['id_token'] ?? '';
    final state = values['state'] ?? '';
    final expectedState = web.window.sessionStorage.getItem(_googleStateKey) ?? '';
    if (idToken.isEmpty || state.isEmpty || state != expectedState) return null;
    web.window.sessionStorage.removeItem(_googleStateKey);
    web.window.sessionStorage.removeItem(_googleNonceKey);
    return signInGoogle(idToken);
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
    final value = 'dev_${_randomToken(24)}';
    web.window.localStorage.setItem(_deviceStorageKey, value);
    return value;
  }

  String _randomToken(int byteCount) {
    final random = Random.secure();
    final bytes = List<int>.generate(byteCount, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
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
