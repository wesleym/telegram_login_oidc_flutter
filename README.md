# telegram_login_oidc_flutter

A Flutter plugin that lets users log in to your app with Telegram. This library builds on the Telegram OpenID Connect login method introduced in 2026.

https://core.telegram.org/bots/telegram-login

This library provides the functionality of Telegram’s native login libraries on each supported platform.

- iOS: https://github.com/TelegramMessenger/telegram-login-ios
- Android: https://github.com/TelegramMessenger/telegram-login-android
- Web: https://core.telegram.org/bots/telegram-login#using-the-telegram-login-library

## Prerequisites

To build for iOS, your app’s minimum deployment target must be `15.0`.

To build for Android, your [`minSdkVersion`](https://developer.android.com/ndk/guides/sdk-versions#minsdkversion) must be `23`.

## Installation

```bash
flutter pub add telegram_login_oidc_flutter
```

### Installation: Android

telegram-login-android is hosted on GitHub Packages must be accessible to use telegram_login_oidc_flutter. As a result, you must have a GitHub account to provision credentials to access it.

1. Create a *Classic* Personal Access Token. The PAT needs to have the `read:packages` scope.
    
    ⚠️ This token must be created as a classic PAT. Fine-grained PATs are not compatible with GitHub Packages. See <https://github.com/github/roadmap/issues/558>.
    
1. Add your GitHub username and your PAT to the `gradle.properties` in your [Gradle User Home directory](https://docs.gradle.org/current/userguide/directory_layout.html#dir:gradle_user_home). By default, that’s a folder named `.gradle` in your home directory. You may have to create this file.
    
    ```bash
    gpr.user=YOUR_GITHUB_USERNAME
    gpr.key=ghp_abcde12345ABCDE67890abcde12345ABCDE67890
    ```
    
    You can also provide these values with the `GITHUB_USERNAME` and `GITHUB_TOKEN` environment variables.

1. Add the GitHub Packages Maven repository to your app’s `android/build.gradle.kts`:

    ```kotlin
    allprojects {
        repositories {
            google()
            mavenCentral()
            maven {
                url = uri("https://maven.pkg.github.com/TelegramMessenger/telegram-login-android")
                credentials {
                    username = providers.gradleProperty("gpr.user").orNull ?: System.getenv("GITHUB_USERNAME")
                    password = providers.gradleProperty("gpr.key").orNull ?: System.getenv("GITHUB_TOKEN")
                }
            }
        }
    }
    ```
    

## Bot configuration

To add Telegram login to an app, first create a Telegram bot. Open the [@BotFather](https://t.me/BotFather) mini app to create and configure your bot.

ℹ️ The chat interface is not the mini-app. Tap the "Open" button to launch the mini-app.

Once you've created an app, select "Login Widget". As of May 2026, the default login method is the legacy login widget. If available, select "Switch to OpenID Connect Login".

### Bot configuration: iOS

To configure your iOS app, you’ll need your _team ID_ and your app’s _bundle ID_.

You can find your team ID at https://developer.apple.com/account in “Membership details”.

You can find your app's bundle ID in Xcode:

1. Open `//ios/Runner.xcworkspace` in Xcode.
2. In the Project navigator (left sidebar), click the Runner project.
3. In the left pane, click the Runner target (and not the Runner project above it).
4. Select the "General" tab

Your bundle ID is in the "Identity" section, labelled as the "Bundle Identifier". More details about finding your app's bundle ID: <https://developer.apple.com/documentation/xcode/changing-the-bundle-identifier>.

In the Login Widget section of the BotFather mini app, select "Add Native App" -> "iOS". Enter the team ID and bundle ID. Once you’ve entered this information, an App URL will appear for your iOS app. You’ll need this later.

Optional: Select "Add a Redirect URI". Enter your bundle ID followed by `://`. For example, you might enter `com.wesleymoy.telegramLoginOidcFlutterExample://`. This allows Telegram to launch your app with a custom scheme if launching with a universal link fails. See App Configuration.

### Bot configuration: Android

To configure your Android app, you’ll need your application ID (also known as the package name) and the fingerprint of your signing certificate.

Your application ID is set in `android/app/build.gradle.kts`. Look for a line containing `applicationId`. See https://developer.android.com/build/configure-app-module for more details about where to find this.

You can get your signing certificate’s SHA-256 fingerprint. From your project’s `android` directory:

```bash
./gradlew signingReport
```

In the Login Widget section of the BotFather mini app, select "Add Native App" -> "Android". Enter the application ID and signing certificate fingerprint. Once you’ve entered this information, an App URL will appear for your Android app. You’ll need this later.

Optional: Select "Add a Redirect URI". Enter your application ID followed by `://`. For example, you might enter `com.wesleymoy.telegram_login_oidc_flutter_example://`. This allows Telegram to launch your app with a custom scheme if launching with an App Link fails. See App Configuration.

### Bot configuration: web

To configure your web app, you’ll need the origin (`https` and domain) you’ll be hosting your app on.

⚠️ Telegram doesn’t let you add `localhost` as a trusted origin, so you won’t be able to use Telegram Login to authenticate against your development instance. Do a full `flutter build web` and deploy the release to test it.

In the Login Widget section of the BotFather mini app, select "Add a Trusted Origin". Enter the origin you're hosting your app on.

## App configuration

### App configuration: iOS

Telegram uses a [universal link](https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content) to open your app after Telegram login completes. To make your app open automatically when this happens, you need to add the Associated Domains entitlement to your app and associate your App URL from Telegram.

1. Open `//ios/Runner.xcworkspace` in Xcode.
2. In the Project navigator (left sidebar), click the Runner project.
3. In the left pane, click the Runner target (and not the Runner project above it).
4. Select the "Signing & Capabilities" tab.
5. If there isn't an "Associated Domains" section, click "+ Capability" and add it.
6. Add the following two domains to let Telegram redirect back to your app after authentication. Substitute the domain name of your App URL for your iOS app from Telegram:
   * `webcredentials:appXXXXXXXXXX-login.tg.dev`: used when Telegram is not installed on the device.
   * `applinks:appXXXXXXXXXX-login.tg.dev`: used for the universal link callback when Telegram is installed.

More detail about adding an associated domain to your app: <https://developer.apple.com/documentation/xcode/supporting-associated-domains#Add-the-associated-domains-entitlement-to-your-app>.

There are also two changes to make in your project's info. First, allow telegram_login_oidc_flutter to determine if the Telegram app is installed.

1. Select the "Info" tab.
2. In the "Custom iOS Target Properties" section, add the key "Queried URL Schemes" (`LSApplicationQueriesSchemes`). For its Item 0, set the value to `tg`.

How to edit your app’s Info in Xcode: <https://developer.apple.com/documentation/bundleresources/managing-your-app-s-information-property-list#Configure-information-property-list-values>. Information about Queried URL Schemes: <https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/LaunchServicesKeys.html#//apple_ref/doc/plist/info/LSApplicationQueriesSchemes>.

Optional: In the "URL Types" section (`CFBundleURLTypes`), click the "+" button. Enter your bundle ID in both the Identifier and URL Schemes fields. This allows Telegram to launch your app with a custom scheme if launching with a universal link fails.

Information about URL Types: <https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html#//apple_ref/doc/uid/20001431-102207>.

### App configuration: Android

Telegram uses an [App Link](https://developer.android.com/training/app-links) to open your app after Telegram login completes. To make your app open automatically when this happens, add an intent filter matching your App URL inside your main `<activity>` in `android/app/src/main/AndroidManifest.xml`:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="https"
          android:host="appYYYYYYYYYY-login.tg.dev"
          android:pathPrefix="/tglogin"/>
</intent-filter>
```

Replace `appYYYYYYYYYY-login.tg.dev` with the domain of your App URL for your Android native app in BotFather — the same value you pass as `androidAppUrl` to `TelegramLogin.configure` (see Usage below).

Optional: if you also registered a custom-scheme redirect URI as a fallback (see Bot configuration: Android above), add a second intent filter for it inside your `<activity>`:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="com.example.yourapp"/>
</intent-filter>
```

Replace `com.example.yourapp` with your application ID followed by `://`, matching what you registered in BotFather.

### Usage

#### Configure once (e.g. in `initState`)

```dart
import 'package:telegram_login_oidc_flutter/telegram_login_oidc_flutter.dart';

TelegramLogin.configure(
  // The client ID for your bot, as shown in "Login Widget" in BotFather.
  clientId: 'YOUR_CLIENT_ID',

  // App URLs provisioned by BotFather for each native platform.
  // Web apps don't have App URLs.
  iosAppUrl:     'https://appXXXXXXXXXX-login.tg.dev',
  androidAppUrl: 'https://appXXXXXXXXXX-login.tg.dev',

  // Available scopes: https://core.telegram.org/bots/telegram-login#available-scopes
  // "openid" must be one of the scopes you request.
  scopes: const ['openid'],

  // (optional) Your iOS bundle ID, as a backup if the universal link doesn't work.
  // iosFallbackScheme: 'com.example.yourapp',

  // Web-only options (ignored on iOS and Android):
  // webNonce: 'random-nonce-value',  // prevents replay attacks
  // webLang:  'en',                  // popup UI language
);
```

#### Sign in

```dart
try {
  final data = await TelegramLogin.login();
  print(data.idToken); // OpenID Connect id_token
} on TelegramLoginException catch (e) {
  // e.code: 'cancelled' | 'not_configured' | 'no_auth_code' |
  //         'server_error' | 'request_failed'
  print('[${e.code}] ${e.message}');
}
```

#### Ignoring the redirect

If you use an App Link / Universal Link (`https://`) as your redirect URI, your app's router will also receive that redirect
URL as if it were a deep link. A URL like
`https://app{ID}-login.tg.dev/tglogin?code=...` is never a real navigation
target, so if your router doesn't expect it, it can crash — e.g. `go_router`
raises `GoException: no routes for location: ...`.

Use [`TelegramLogin.isLoginRedirect`](#) to recognize and route to a reasonable app launch route.
If you use `go_router`, you can set up a redirect:

```dart
GoRouter(
  redirect: (context, state) {
    if (TelegramLogin.isLoginRedirect(state.matchedLocation)) {
      return '/'; // or an appropriate route for launch
    }
  },
);
```

#### Error codes

| Code | Platform | Meaning |
| --- | --- | --- |
| `cancelled` | all | User dismissed the auth UI without completing sign-in |
| `not_configured` | all | `configure()` was not called before `login()` |
| `no_auth_code` | iOS, Android | Callback URL arrived but contained no `code` parameter |
| `server_error` | iOS, Android | Token endpoint returned a non-200 HTTP status (`statusCode` field is set) |
| `request_failed` | iOS, Android | Network error or unexpected server response |
| `script_load_failed` | web | Telegram Login JS script failed to load |

> **Important:** The `idToken` returned upon success is a JWT. You **must** send this token to your backend to cryptographically verify its validity before logging the user into your system. Read more about [validating ID tokens](https://core.telegram.org/bots/telegram-login#validating-id-tokens) in the core documentation.
> 

## Platform considerations

### Platform considerations: web

**Important:** The `telegram-login.js` library relies on communicating with a popup window to complete the authentication flow. If your website serves the `Cross-Origin-Opener-Policy: same-origin` HTTP header, this cross-window communication will be blocked and the login process will fail. To ensure the JavaScript library functions correctly, you must either remove this header or use a more permissive policy, such as `Cross-Origin-Opener-Policy: same-origin-allow-popups`.

### Platform considerations: android

#### Recovering an interrupted sign-in (Android)

On Android, your app process can die and your app's Flutter engine can go away while the user is completing the flow in Telegram or the browser. When that happens, the authentication still finishes and the `id_token` is sent to your app, but the `Future` returned by the original `login()` call is orphaned in the now-defunct isolate and never resolves.

If this happens, you'll notice that you end up back your app, but login appears never to have been initiated.

Call `TelegramLogin.consumePendingLogin()` once at startup (after `configure()`) to recover such a result:

```dart
final pending = await TelegramLogin.consumePendingLogin();
if (pending != null) {
  print(pending.idToken); // pick up where the interrupted login left off
}
```

Thus function returns `null` if there's nothing to recover or if the recovered result is too old to be trusted. This function always returns `null` on iOS and web.
