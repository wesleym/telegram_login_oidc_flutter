import 'package:flutter/foundation.dart';

import 'telegram_login_oidc_flutter_platform_interface.dart';

export 'telegram_login_oidc_flutter_platform_interface.dart'
    show LoginData, TelegramLoginException;

class TelegramLogin {
  TelegramLogin._();

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
}
