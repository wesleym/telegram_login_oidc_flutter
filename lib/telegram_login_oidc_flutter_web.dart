import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'telegram_login_oidc_flutter_platform_interface.dart';

@JS('Telegram.Login.auth')
external void _telegramLoginAuth(JSObject options, JSFunction callback);

class TelegramLoginFlutterWeb extends TelegramLoginFlutterPlatform {
  static void registerWith(Object registrar) {
    TelegramLoginFlutterPlatform.instance = TelegramLoginFlutterWeb();
  }

  String? _clientId;
  List<String> _scopes = const [];
  String? _nonce;
  String? _lang;
  Future<void>? _scriptReady;

  @override
  Future<void> configure({
    required String clientId,
    String? redirectUri,
    List<String> scopes = const [],
    String? iosFallbackScheme,
    String? webNonce,
    String? webLang,
  }) async {
    _clientId = clientId;
    _scopes = scopes;
    _nonce = webNonce;
    _lang = webLang;
    _scriptReady ??= _injectScript();
    await _scriptReady!;
  }

  @override
  Future<LoginData> login() async {
    final ready = _scriptReady;
    if (ready == null || _clientId == null) {
      throw const TelegramLoginException(
        code: 'not_configured',
        message: 'Call configure() before login()',
      );
    }
    await ready;

    final optionsMap = <String, Object?>{
      'client_id': int.parse(_clientId!),
      if (_scopes.isNotEmpty) 'request_access': _scopes,
      if (_nonce != null) 'nonce': _nonce,
      if (_lang != null) 'lang': _lang,
    };

    final completer = Completer<LoginData>();

    void onResult(JSAny? result) {
      if (completer.isCompleted) return;
      // Telegram passes null or false when the user cancels.
      if (result == null || result.isA<JSBoolean>()) {
        completer.completeError(const TelegramLoginException(
          code: 'cancelled',
          message: 'Login was cancelled',
        ));
        return;
      }
      final data = result.dartify()! as Map<Object?, Object?>;
      final idToken = data['id_token']! as String;
      completer.complete(LoginData(idToken: idToken));
    }

    _telegramLoginAuth(optionsMap.jsify()! as JSObject, onResult.toJS);
    return completer.future;
  }

  Future<void> _injectScript() {
    const src = 'https://telegram.org/js/telegram-login.js';
    if (web.document.querySelector('script[src="$src"]') != null) {
      return Future.value();
    }

    final completer = Completer<void>();
    final script =
        web.document.createElement('script') as web.HTMLScriptElement;
    script.src = src;
    script.async = true;
    script.addEventListener('load', ((JSAny _) => completer.complete()).toJS);
    script.addEventListener(
      'error',
      ((JSAny _) {
        if (!completer.isCompleted) {
          completer.completeError(const TelegramLoginException(
            code: 'script_load_failed',
            message: 'Failed to load Telegram Login script',
          ));
        }
      }).toJS,
    );
    web.document.head!.append(script);
    return completer.future;
  }
}
