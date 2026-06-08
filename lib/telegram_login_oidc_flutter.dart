import 'package:flutter/foundation.dart';

import 'telegram_login_oidc_flutter_platform_interface.dart';

export 'telegram_login_oidc_flutter_platform_interface.dart'
    show LoginData, TelegramLoginException;

class TelegramLogin {
  TelegramLogin._();

  static String? _redirectUri;

  /// Configure credentials. Must be called before [login].
  ///
  /// [clientId] is the numeric client ID issued by BotFather (the same value
  /// applies to all platforms — iOS, Android, and web all share the same bot).
  ///
  /// [iosAppUrl] is the App URL provisioned by BotFather for your iOS app
  /// (e.g. `https://app{ID}-login.tg.dev`). Passed as-is to the iOS SDK as
  /// the redirect URI.
  ///
  /// [androidAppUrl] is the redirect URI for your Android app. Two forms are
  /// accepted:
  ///
  /// - **App Link** (recommended): the URL provisioned by BotFather,
  ///   e.g. `https://app{ID}-login.tg.dev`. The library automatically appends
  ///   `/tglogin` to construct the full redirect URI.
  /// - **Custom scheme** (fallback): your app's package name followed by
  ///   `://telegram-auth`, e.g. `com.example.yourapp://telegram-auth`.
  ///   Used as-is — no suffix is appended. Register this URI in BotFather
  ///   to enable the custom-scheme path.
  ///
  /// [iosFallbackScheme] is iOS-only: it sets the callback URL scheme used by
  /// [ASWebAuthenticationSession] on iOS < 17.4 when [iosAppUrl] is an
  /// https:// Universal Link rather than a custom scheme.
  ///
  /// [webNonce] and [webLang] are **web-only** and ignored on iOS and Android.
  /// [webNonce] is passed to Telegram as the `nonce` field to prevent replay
  /// attacks. [webLang] sets the UI language of the Telegram login popup
  /// (e.g. `'en'`, `'de'`).
  static Future<void> configure({
    required String clientId,
    String? iosAppUrl,
    String? androidAppUrl,
    List<String> scopes = const [],
    String? iosFallbackScheme,
    String? webNonce,
    String? webLang,
  }) {
    if (kIsWeb) {
      return TelegramLoginOidcFlutterPlatform.instance.configure(
        clientId: clientId,
        scopes: scopes,
        webNonce: webNonce,
        webLang: webLang,
      );
    }

    final effectiveRedirectUri = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => iosAppUrl,
      TargetPlatform.android => switch (androidAppUrl) {
        null => null,
        final url when url.startsWith('https://') => '$url/tglogin',
        final url => url,
      },
      _ => null,
    };

    assert(
      effectiveRedirectUri != null,
      'Provide iosAppUrl on iOS or androidAppUrl on Android.',
    );
    _redirectUri = effectiveRedirectUri;

    return TelegramLoginOidcFlutterPlatform.instance.configure(
      clientId: clientId,
      redirectUri: effectiveRedirectUri!,
      scopes: scopes,
      iosFallbackScheme: iosFallbackScheme,
    );
  }

  /// Start the Telegram OAuth login flow.
  ///
  /// Returns [LoginData] containing the OpenID Connect `id_token` on success.
  /// Throws [TelegramLoginException] on failure or cancellation.
  static Future<LoginData> login() {
    return TelegramLoginOidcFlutterPlatform.instance.login();
  }

  /// Recovers a login that completed natively but never made it back to the
  /// Dart side that started it.
  ///
  /// On Android, the OS can destroy and recreate the app's Flutter engine
  /// while the user is away completing the flow in Telegram or the browser
  /// (e.g. due to memory pressure or aggressive OEM background-app limits).
  /// When that happens, the native plugin still finishes the OIDC exchange
  /// and stashes the resulting `id_token`, but the original [login] call's
  /// [Future] is orphaned in the now-defunct isolate and can never resolve.
  ///
  /// Call this once at app startup (e.g. after [configure]) to pick up such
  /// a stashed result. Returns `null` if there is nothing to recover, or if
  /// the stashed result is too old to be trusted. On iOS and web, where this
  /// scenario cannot occur, this always returns `null`.
  static Future<LoginData?> consumePendingLogin() {
    return TelegramLoginOidcFlutterPlatform.instance.consumePendingLogin();
  }

  /// Returns whether [location] is this app's Telegram OIDC redirect —
  /// e.g. `https://app{ID}-login.tg.dev/tglogin?code=...` — rather than a
  /// real navigation target.
  ///
  /// On Android (and potentially iOS, depending on how you wire up universal
  /// links), the OS hands the redirect URL to your Flutter app as if it were
  /// any other deep link, *in addition to* the native plugin consuming it —
  /// see "Platform considerations: Android" in the README for the full
  /// explanation. If your router doesn't expect this URL, it can crash (e.g.
  /// `go_router`'s `GoException: no routes for location: ...`) or otherwise
  /// misbehave — usually surfacing only once a user is already signed in
  /// (typically via [consumePendingLogin]), since until then most apps'
  /// auth-redirect logic absorbs the bad location anyway.
  ///
  /// Call this at the top of your router's redirect/guard logic and route
  /// straight past any match (e.g. to your home screen) — the plugin has
  /// already handled the real work natively. Must be called after [configure]
  /// to have anything to compare against; returns `false` beforehand.
  static bool isLoginRedirect(String location) {
    final target = _redirectUri;
    if (target == null) return false;
    final targetUri = Uri.tryParse(target);
    final locationUri = Uri.tryParse(location);
    if (targetUri == null || locationUri == null) return false;

    if (targetUri.host.isNotEmpty &&
        locationUri.host.isNotEmpty &&
        targetUri.host != locationUri.host) {
      return false;
    }
    final targetPath = targetUri.path;
    if (targetPath.isEmpty) {
      // Custom-scheme redirect URIs (e.g. com.example.app://telegram-auth)
      // don't split meaningfully into host/path — fall back to a prefix
      // match against the full configured URI.
      return location.startsWith(target);
    }
    return locationUri.path == targetPath ||
        locationUri.path.startsWith('$targetPath/');
  }
}
