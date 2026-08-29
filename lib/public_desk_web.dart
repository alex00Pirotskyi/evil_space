// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:evil_space/coworking_model.dart';
import 'package:evil_space/public_desk_models.dart';

class PublicDeskApi {
  static const _storageKey = 'evil_space_saved_desk_contact_v1';

  Future<SiteStatus?> status() async {
    try {
      final response = await web.window.fetch('/api/public/status'.toJS).toDart;
      if (!response.ok) return null;
      final raw = (await response.text().toDart).toDart;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final status = decoded['status'];
      if (status is! Map) return null;
      return SiteStatus.fromJson(Map<String, dynamic>.from(status));
    } catch (_) {
      return null;
    }
  }

  Future<void> book(DeskBookingProfile profile) async {
    final headers = web.Headers();
    headers.set('Accept', 'application/json');
    headers.set('Content-Type', 'application/json');

    final response = await web.window
        .fetch(
          '/api/public/book'.toJS,
          web.RequestInit(
            method: 'POST',
            headers: headers,
            credentials: 'same-origin',
            body: jsonEncode(profile.toJson()).toJS,
          ),
        )
        .toDart;

    final raw = (await response.text().toDart).toDart;
    final decoded = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
    final data = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};

    if (!response.ok) {
      throw PublicDeskException(
        data['error']?.toString() ?? 'Could not send desk request.',
      );
    }
  }

  DeskBookingProfile? savedProfile() {
    try {
      final raw = web.window.localStorage.getItem(_storageKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final profile = DeskBookingProfile.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return profile.valid ? profile : null;
    } catch (_) {
      return null;
    }
  }

  void saveProfile(DeskBookingProfile profile) {
    web.window.localStorage.setItem(_storageKey, jsonEncode(profile.toJson()));
  }

  void clearSavedProfile() {
    web.window.localStorage.removeItem(_storageKey);
  }
}
