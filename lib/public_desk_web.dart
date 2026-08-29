// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:evil_space/coworking_model.dart';
import 'package:evil_space/public_desk_models.dart';

class PublicDeskApi {
  static const _profileStorageKey = 'evil_space_saved_desk_contact_v1';
  static const _bookingStorageKey = 'evil_space_desk_booking_v1';

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

  Future<DeskBookingState> book(DeskBookingProfile profile) async {
    final data = await _jsonRequest(
      'POST',
      '/api/public/book',
      body: profile.toJson(),
    );
    final booking = DeskBookingState.fromJson(data);
    if (!booking.valid) {
      throw const PublicDeskException('Could not save desk request status.');
    }
    saveBooking(booking);
    return booking;
  }

  Future<DeskBookingState?> bookingStatus(DeskBookingState booking) async {
    try {
      final response = await web.window
          .fetch(
            '/api/public/booking?token=${Uri.encodeQueryComponent(booking.token)}'
                .toJS,
          )
          .toDart;
      final raw = (await response.text().toDart).toDart;
      final decoded = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
      final data = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};

      if (response.status == 404 || response.status == 410) {
        clearSavedBooking();
        return null;
      }
      if (!response.ok) {
        throw PublicDeskException(
          data['error']?.toString() ?? 'Could not refresh booking status.',
        );
      }

      final next = DeskBookingState(
        token: booking.token,
        status: data['status']?.toString() ?? '',
      );
      if (!next.valid) {
        clearSavedBooking();
        return null;
      }
      saveBooking(next);
      return next;
    } catch (error) {
      if (error is PublicDeskException) rethrow;
      return booking;
    }
  }

  Future<void> deleteBooking(DeskBookingState booking) async {
    await _jsonRequest(
      'POST',
      '/api/public/booking/delete',
      body: {'token': booking.token},
    );
    clearSavedBooking();
  }

  DeskBookingProfile? savedProfile() {
    try {
      final raw = web.window.localStorage.getItem(_profileStorageKey);
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
    web.window.localStorage.setItem(
      _profileStorageKey,
      jsonEncode(profile.toJson()),
    );
  }

  void clearSavedProfile() {
    web.window.localStorage.removeItem(_profileStorageKey);
  }

  DeskBookingState? savedBooking() {
    try {
      final raw = web.window.localStorage.getItem(_bookingStorageKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final booking = DeskBookingState.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      return booking.valid ? booking : null;
    } catch (_) {
      return null;
    }
  }

  void saveBooking(DeskBookingState booking) {
    web.window.localStorage.setItem(
      _bookingStorageKey,
      jsonEncode(booking.toJson()),
    );
  }

  void clearSavedBooking() {
    web.window.localStorage.removeItem(_bookingStorageKey);
  }

  Future<Map<String, dynamic>> _jsonRequest(
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
    final data = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};

    if (!response.ok) {
      throw PublicDeskException(
        data['error']?.toString() ?? 'Desk request failed.',
      );
    }
    return data;
  }
}
