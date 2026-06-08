## Unreleased

* **Breaking (Android):** Replaced the `TelegramLoginCallbackActivity` trampoline with an `onNewIntent` listener on the host app's own activity. This fixes a bug where the redirect from Telegram could land in a separate task, causing Android to bring the wrong app (or the home screen) to the foreground instead of returning the user to the app.
  * **Migration:** Remove `manifestPlaceholders["telegramAndroidAppUrl"]` (and `telegramAndroidScheme`, if set) from `android/app/build.gradle.kts`. Instead, add an intent filter matching your App URL directly to your launcher activity (usually `MainActivity`) in `android/app/src/main/AndroidManifest.xml`. See "App configuration: Android" in the README for the exact filter to add.
* Added `TelegramLogin.consumePendingLogin()`. On Android, the OS can destroy and recreate the app's Flutter engine while the user is away completing the login (e.g. due to memory pressure or aggressive OEM background-app limits), orphaning the in-flight `login()` call. The native plugin now stashes the `id_token` from such an orphaned exchange; call `consumePendingLogin()` at startup to recover it. Returns `null` on iOS and web, and on Android when there is nothing to recover.
* Added `TelegramLogin.isLoginRedirect(location)`. If you use an App Link / Universal Link redirect URI, the OS also forwards that URL to your app's router as a deep link (alongside the plugin handling it natively) — which can crash routers that don't expect it (e.g. `go_router`'s `GoException: no routes for location: ...`). Use this to recognize and route past it. See "Keeping your router from choking on the redirect URL" in the README.

## 0.0.3

* Document more robust steps for ensuring that logging in on iOS works with or without Telegram installed. Two types of associated domains are needed instead of one.
* Repair reference to Telegram login library for iOS.
* Repair how the Telegram login library for Android is added as a dependency.

## 0.0.2

* Renamed package and repository to `telegram_login_oidc_flutter`. This works around a name collision with the existing [`telegram_login_flutter`](https://pub.dev/packages/telegram_login_flutter) and makes the difference clearer: `telegram_login_oidc_flutter` (this library) uses Telegram's newer OpenID Connect login system.
* Repaired `iosFallbackScheme`. This was previously not being passed due to an error while renaming.
* Migrated to built-in Kotlin for the Android Gradle Plugin.

## 0.0.1

* Initial pre-release.
