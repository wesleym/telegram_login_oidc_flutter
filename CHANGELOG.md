## 0.0.4

* Telegram login breakage on Android worked around.
  * Implementation detail: `TelegramLoginCallbackActivity` removed. The task affinity of the main activity means that this activity is started in a new task, and it's difficult to pass the result back to the main activity.
  * Breaking change: Remove `manifestPlaceholders["telegramAndroidAppUrl"]` from `android/app/build.gradle.kts`. Instead, add an intent filter matching your App URL directly to your launcher activity in `android/app/src/main/AndroidManifest.xml`. See "App configuration: Android" in the README for the exact filter to add.

* Added `TelegramLogin.consumePendingLogin()` for Android login where the app process dies.
* Added `TelegramLogin.isLoginRedirect(location)` to determine whether an incoming deep link is just a Telegram login.

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
