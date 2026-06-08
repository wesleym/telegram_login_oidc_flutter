import 'package:flutter/material.dart';
import 'package:telegram_login_oidc_flutter/telegram_login_oidc_flutter.dart';

// ---------------------------------------------------------------------------
// All platforms share the same bot and therefore share a client ID for Telegram
// login. Once you configure your apps with BotFather, it will provide you with
// the App URL for each platform.
//
// See README.md for additional setup steps. These include:
// * iOS: Add the two kinds of associated domain for your iOS App URL in Xcode:
// `webcredentials:appXXXXXXXXXX-login.tg.dev` (for when Telegram is not
// installed) and `applinks:appXXXXXXXXXX-login.tg.dev` (for when it is).
// * Android: Add an intent-filter matching your Android App URL directly to
//   MainActivity in android/app/src/main/AndroidManifest.xml.
// * Optionally add custom schemes as backup for universal links/Android App
//   Links.
// ---------------------------------------------------------------------------
// TODO: Replace with your bot's client ID, found in BotFather under "Login Widget".
const _clientId = 'YOUR_CLIENT_ID';
// TODO: Replace with the App URLs provisioned by BotFather for each platform.
const _iosAppUrl = 'https://appXXXXXXXXXX-login.tg.dev';
const _androidAppUrl = 'https://appYYYYYYYYYY-login.tg.dev';

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
    _configureAndCheckPending();
  }

  Future<void> _configureAndCheckPending() async {
    await TelegramLogin.configure(
      clientId: _clientId,
      iosAppUrl: _iosAppUrl,
      androidAppUrl: _androidAppUrl,
      scopes: const ['openid'],
      // TODO: Replace with your app's bundle ID if using the custom-scheme fallback.
      // iosFallbackScheme: 'com.example.yourapp',
    );
    // Recovers a sign-in that completed natively while this app run was away
    // (Android only — see "Recovering an interrupted sign-in" in the README).
    final pending = await TelegramLogin.consumePendingLogin();
    if (pending != null && mounted) setState(() => _idToken = pending.idToken);
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
