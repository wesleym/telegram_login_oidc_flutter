import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'telegram_login_oidc_flutter_method_channel.dart';

class LoginData {
  final String idToken;
  const LoginData({required this.idToken});
}

class TelegramLoginException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  const TelegramLoginException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => 'TelegramLoginException($code): $message';
}

abstract class TelegramLoginOidcFlutterPlatform extends PlatformInterface {
  TelegramLoginOidcFlutterPlatform() : super(token: _token);

  static final Object _token = Object();
  static TelegramLoginOidcFlutterPlatform _instance =
      MethodChannelTelegramLoginOidcFlutter();

  static TelegramLoginOidcFlutterPlatform get instance => _instance;
  static set instance(TelegramLoginOidcFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> configure({
    required String clientId,
    String? redirectUri,
    List<String> scopes = const [],
    String? iosFallbackScheme,
    // Web-only — ignored on iOS and Android.
    String? webNonce,
    String? webLang,
  }) => throw UnimplementedError('configure() has not been implemented.');

  Future<LoginData> login() =>
      throw UnimplementedError('login() has not been implemented.');
}
