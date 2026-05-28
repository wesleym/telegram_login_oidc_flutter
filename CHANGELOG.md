## 0.0.2

* Renamed package and repository to `telegram_login_oidc_flutter`. This works around a name collision with the existing [`telegram_login_flutter`](https://pub.dev/packages/telegram_login_flutter) and makes the difference clearer: `telegram_login_oidc_flutter` (this library) uses Telegram's newer OpenID Connect login system.
* Repaired `iosFallbackScheme`. This was previously not being passed due to an error while renaming.
* Migrated to built-in Kotlin for the Android Gradle Plugin.

## 0.0.1

* Initial pre-release.
