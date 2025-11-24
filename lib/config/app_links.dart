class AppLinks {
  // Set at build time; e.g., --dart-define=APP_PUBLIC_BASE_URL=https://xprex.app
  static const String publicBaseUrl = String.fromEnvironment('APP_PUBLIC_BASE_URL');

  static String videoLink(String videoId) {
    if (publicBaseUrl.isEmpty) return '';
    // Point to a canonical web route handled by your app or landing site
    return '$publicBaseUrl/video/$videoId';
  }
}
