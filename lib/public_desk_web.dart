// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:evil_space/coworking_model.dart';
import 'package:evil_space/public_booking_signal.dart';
import 'package:evil_space/public_desk_models.dart';

class PublicDeskApi {
  static const _profileStorageKey = 'evil_space_saved_desk_contact_v1';
  static const _bookingStorageKey = 'evil_space_desk_booking_v1';
  static const _bookingsStorageKey = 'evil_space_desk_bookings_v2';
  static const _bootstrapStatusStorageKey = 'evil_space_bootstrap_status_v1';
  static const _bootstrapStatusConsumedKey =
      'evil_space_bootstrap_status_consumed_v1';

  Future<SiteStatus?> status() async {
    if (web.document.hidden) return null;

    final bootstrapStatus = _takeBootstrapStatus();
    if (bootstrapStatus != null) return bootstrapStatus;

    _markBootstrapStatusConsumed();
    try {
      final response = await web.window.fetch('/api/public/status'.toJS).toDart;
      if (!response.ok) return null;
      final raw = (await response.text().toDart).toDart;
      return _decodeStatus(raw);
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
    if (web.document.hidden) return booking;

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
        telegramLinkUrl: booking.telegramLinkUrl,
        telegramLinked:
            booking.telegramLinked || data['telegramLinked'] == true,
        serviceDate: data['serviceDate']?.toString() ?? booking.serviceDate,
        amountVnd: (data['amountVnd'] as num?)?.toInt() ?? booking.amountVnd,
      );
      if (!next.valid) {
        clearSavedBooking(booking.serviceDate);
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
    clearSavedBooking(booking.serviceDate);
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

  List<DeskBookingState> savedBookings() {
    final results = <DeskBookingState>[];
    try {
      final raw = web.window.localStorage.getItem(_bookingsStorageKey);
      final decoded = raw == null || raw.isEmpty ? null : jsonDecode(raw);
      if (decoded is List) {
        for (final item in decoded.whereType<Map>()) {
final booking = DeskBookingState.fromJson(Map<String, dynamic>.from(item));
if (booking.valid) results.add(booking);
        }
      }
      if (results.isEmpty) {
        final legacy = web.window.localStorage.getItem(_bookingStorageKey);
        if (legacy != null && legacy.isNotEmpty) {
final old = jsonDecode(legacy);
if (old is Map) {
  final map = Map<String, dynamic>.from(old);
  final now = DateTime.now().toUtc().add(const Duration(hours: 7));
  final date = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  map['serviceDate'] ??= date;
  map['amountVnd'] ??= 200000;
  final booking = DeskBookingState.fromJson(map);
  if (booking.valid) results.add(booking);
}
web.window.localStorage.removeItem(_bookingStorageKey);
        }
      }
    } catch (_) {}
    results.sort((a, b) => a.serviceDate.compareTo(b.serviceDate));
    return results;
  }

  void saveBooking(DeskBookingState booking) {
    final bookings = savedBookings()
        .where((item) => item.serviceDate != booking.serviceDate)
        .toList();
    bookings.add(booking);
    bookings.sort((a, b) => a.serviceDate.compareTo(b.serviceDate));
    web.window.localStorage.setItem(
      _bookingsStorageKey,
      jsonEncode(bookings.map((item) => item.toJson()).toList()),
    );
    notifyPublicBookingChanged();
  }

  void clearSavedBooking([String? serviceDate]) {
    if (serviceDate == null) {
      web.window.localStorage.removeItem(_bookingsStorageKey);
    } else {
      final bookings = savedBookings()
.where((item) => item.serviceDate != serviceDate)
.toList();
      if (bookings.isEmpty) {
        web.window.localStorage.removeItem(_bookingsStorageKey);
      } else {
        web.window.localStorage.setItem(
_bookingsStorageKey,
jsonEncode(bookings.map((item) => item.toJson()).toList()),
        );
      }
    }
    web.window.localStorage.removeItem(_bookingStorageKey);
    notifyPublicBookingChanged();
  }

  SiteStatus? _takeBootstrapStatus() {
    try {
      final raw = web.window.sessionStorage.getItem(_bootstrapStatusStorageKey);
      web.window.sessionStorage.removeItem(_bootstrapStatusStorageKey);
      web.window.sessionStorage.setItem(_bootstrapStatusConsumedKey, '1');
      if (raw == null || raw.isEmpty) return null;
      return _decodeStatus(raw);
    } catch (_) {
      return null;
    }
  }

  void _markBootstrapStatusConsumed() {
    try {
      web.window.sessionStorage.setItem(_bootstrapStatusConsumedKey, '1');
    } catch (_) {}
  }

  SiteStatus? _decodeStatus(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final status = decoded['status'];
      if (status is! Map) return null;
      return SiteStatus.fromJson(Map<String, dynamic>.from(status));
    } catch (_) {
      return null;
    }
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
