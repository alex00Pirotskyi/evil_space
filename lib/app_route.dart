enum AppRoute {
  home('/'),
  feed('/feed'),
  desks('/desks'),
  office('/office'),
  studio('/studio'),
  gallery('/gallery'),
  contact('/contact'),
  qr('/qr');

  const AppRoute(this.path);

  final String path;

  static AppRoute fromUri(Uri uri) {
    final path = uri.path.toLowerCase().replaceAll(RegExp(r'/+$'), '');
    final normalized = path.isEmpty ? '/' : path;

    return switch (normalized) {
      '/' => AppRoute.home,
      '/feed' => AppRoute.feed,
      '/desk' || '/desks' => AppRoute.desks,
      '/office' || '/offices' => AppRoute.office,
      '/studio' => AppRoute.studio,
      '/gallery' || '/pixel-gallery' => AppRoute.gallery,
      '/contact' => AppRoute.contact,
      '/qr' => AppRoute.qr,
      _ => AppRoute.home,
    };
  }
}
