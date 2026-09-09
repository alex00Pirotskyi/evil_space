import 'package:flutter_test/flutter_test.dart';

import 'package:evil_space/app_route.dart';

void main() {
  test('menu deep link is first class', () {
    expect(AppRoute.fromUri(Uri.parse('/menu')), AppRoute.menu);
    expect(AppRoute.fromUri(Uri.parse('/menu/')), AppRoute.menu);
  });

  test('admin menu is separate from main admin route', () {
    expect(AppRoute.fromUri(Uri.parse('/admin/menu')), AppRoute.adminMenu);
    expect(AppRoute.fromUri(Uri.parse('/admin/menu/orders')), AppRoute.adminMenu);
    expect(AppRoute.fromUri(Uri.parse('/admin')), AppRoute.admin);
  });
}
