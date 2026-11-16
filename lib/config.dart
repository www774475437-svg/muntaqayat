/// App-wide links and the build number injected by GitHub Actions.
class AppConfig {
  static const owner = 'www774475437-svg';
  static const repo = 'salman-alemad';

  /// The website (GitHub Pages).
  static const siteUrl = 'https://www774475437-svg.github.io/salman-alemad/';

  /// Always points to the newest APK.
  static const apkUrl = 'https://github.com/$owner/$repo/releases/latest/download/salman-alemad.apk';

  /// Store links — fill in once the app is published there.
  static const playStoreUrl = '';
  static const appStoreUrl = '';

  static const latestReleaseApi = 'https://api.github.com/repos/$owner/$repo/releases/latest';

  /// Set at build time: --dart-define=BUILD_NUMBER=<run number>.
  static const buildNumber = int.fromEnvironment('BUILD_NUMBER', defaultValue: 0);
  /// The copy published on Google Play: Play updates it, so no APK update notices.
  static const fromPlay = bool.fromEnvironment('PLAY');

  static const version = '1.1.0';

  /// Online accounts (Firebase): sign-in, «اسأل الشيخ», admins. Off until set up.
  static const cloudEnabled = false;

  /// AI search. Off until set up.
  static const aiEnabled = false;

  /// Short link: channel answers are «…/#/a/<number>».
  static String fatwaLink(String id) =>
      id.startsWith('tg-') ? '$siteUrl#/a/${id.substring(3)}' : '$siteUrl#/fatwa/$id';

  /// The answer id a route points to, or null.
  static String? idFromRoute(String route) {
    if (route.startsWith('/a/')) return 'tg-${route.substring(3)}';
    if (route.startsWith('/fatwa/')) return Uri.decodeComponent(route.substring(7));
    return null;
  }
}
