import 'package:flutter/material.dart';
import 'package:telegram_login_oidc_flutter/telegram_login_oidc_flutter.dart';

// ---------------------------------------------------------------------------
// All platforms share the same bot and therefore share a client ID for Telegram
// login. Once you configure your apps with BotFather, it will provide you with
// the App URL for each platform.
//
// See README.md for additional setup steps. These include:
// * iOS: Add an associated domain based on your iOS App URL in Xcode:
// `applinks:https://app1279099312-login.tg.dev`.
// * Optionally add custom schemes as backup for universal links/Android App
// Links.
// ---------------------------------------------------------------------------
const _clientId = '8944110757';
const _iosAppUrl = 'https://app1279099312-login.tg.dev';
const _androidAppUrl = 'https://app43211768-login.tg.dev';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telegram Login Demo',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loading = false;
  String? _idToken;
  String? _error;

  @override
  void initState() {
    super.initState();
    TelegramLogin.configure(
      clientId: _clientId,
      iosAppUrl: _iosAppUrl,
      androidAppUrl: _androidAppUrl,
      scopes: const ['openid'],
      iosFallbackScheme: 'com.wesleymoy.telegramLoginFlutterExample',
    );
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _idToken = null;
      _error = null;
    });
    try {
      final data = await TelegramLogin.login();
      setState(() => _idToken = data.idToken);
    } on TelegramLoginException catch (e) {
      setState(() => _error = '[${e.code}] ${e.message}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Telegram Login')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign in with Telegram'),
            ),
            const SizedBox(height: 24),
            if (_idToken != null) ...[
              const Text('id_token:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SelectableText(
                _idToken!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
