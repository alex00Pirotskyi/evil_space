enum AppRoute {
  home('/'),
  menu('/menu'),
  qr('/qr'),
  adminMenu('/admin/menu'),
  admin('/admin');

  const AppRoute(this.path);

  final String path;

  static AppRoute fromUri(Uri uri) {
    final path = uri.path.toLowerCase().replaceAll(RegExp(r'/+$'), '');
    final normalized = path.isEmpty ? '/' : path;

    if (normalized == '/menu') {
      return AppRoute.menu;
    }

    if (normalized == '/qr') {
      return AppRoute.qr;
    }

    if (normalized == '/admin/menu' || normalized.startsWith('/admin/menu/')) {
      return AppRoute.adminMenu;
    }

    if (normalized == '/admin' || normalized.startsWith('/admin/')) {
      return AppRoute.admin;
    }

    // Legacy deep links intentionally resolve to the one-page landing site.
    return AppRoute.home;
  }
}
