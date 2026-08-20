enum AppRoute {
  home('/'),
  qr('/qr');

  const AppRoute(this.path);

  final String path;

  static AppRoute fromUri(Uri uri) {
    final path = uri.path.toLowerCase().replaceAll(RegExp(r'/+$'), '');
    final normalized = path.isEmpty ? '/' : path;

    if (normalized == '/qr') {
      return AppRoute.qr;
    }

    // Legacy deep links intentionally resolve to the one-page landing site.
    return AppRoute.home;
  }
}
