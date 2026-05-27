import 'package:flutter/services.dart';

import 'telegram_login_flutter_platform_interface.dart';

class MethodChannelTelegramLoginFlutter extends TelegramLoginFlutterPlatform {
  final _channel = const MethodChannel('telegram_login_flutter');

  @override
  Future<void> configure({
    required String clientId,
    String? redirectUri,
    List<String> scopes = const [],
    String? iosFallbackScheme,
    String? webNonce,
    String? webLang,
  }) async {
    final args = <String, dynamic>{
      'clientId': clientId,
      'redirectUri': redirectUri!,
      'scopes': scopes,
    };
    if (iosFallbackScheme != null) args['fallbackScheme'] = iosFallbackScheme;
    await _channel.invokeMethod<void>('configure', args);
  }

  @override
  Future<LoginData> login() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('login');
      return LoginData(idToken: result!['idToken'] as String);
    } on PlatformException catch (e) {
      throw TelegramLoginException(
        code: e.code,
        message: e.message ?? e.code,
        statusCode: e.details is int ? e.details as int : null,
      );
    }
  }
}
