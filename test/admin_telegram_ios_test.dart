import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin Telegram link is prepared before the connect tap', () {
    final source = File('lib/admin_portal.dart').readAsStringSync();

    final refreshStart = source.indexOf('Future<void> _refresh() async');
    final connectStart = source.indexOf('Future<void> _connect() async');
    final disconnectStart = source.indexOf('Future<void> _disconnect() async');

    expect(refreshStart, greaterThanOrEqualTo(0));
    expect(connectStart, greaterThan(refreshStart));
    expect(disconnectStart, greaterThan(connectStart));

    final refresh = source.substring(refreshStart, connectStart);
    final connect = source.substring(connectStart, disconnectStart);

    expect(refresh, contains('widget.api.createTelegramLink()'));
    expect(connect, isNot(contains('widget.api.createTelegramLink()')));
    expect(connect, contains("TargetPlatform.iOS ? '_self' : '_blank'"));
    expect(connect, contains('launchUrl('));
  });
}
