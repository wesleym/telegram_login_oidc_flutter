import Flutter
import TelegramLogin
import UIKit

public class TelegramLoginFlutterPlugin: NSObject, FlutterPlugin, FlutterApplicationLifeCycleDelegate, FlutterSceneLifeCycleDelegate {
    // Tracks whether a login is in-flight so we can route cross-app redirect URLs.
    private static var hasPendingLogin = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "telegram_login_oidc_flutter",
            binaryMessenger: registrar.messenger()
        )
        let instance = TelegramLoginFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
        registrar.addSceneDelegate(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "configure":
            guard
                let args = call.arguments as? [String: Any],
                let clientId = args["clientId"] as? String,
                let redirectUri = args["redirectUri"] as? String
            else {
                result(FlutterError(
                    code: "invalid_arguments",
                    message: "clientId and redirectUri are required",
                    details: nil
                ))
                return
            }
            let scopes = args["scopes"] as? [String] ?? []
            let fallbackScheme = args["iosFallbackScheme"] as? String
            Task { @MainActor in
                TelegramLogin.configure(
                    clientId: clientId,
                    redirectUri: redirectUri,
                    scopes: scopes,
                    fallbackScheme: fallbackScheme
                )
                result(nil)
            }

        case "login":
            TelegramLoginFlutterPlugin.hasPendingLogin = true
            Task { @MainActor in
                TelegramLogin.login { loginResult in
                    TelegramLoginFlutterPlugin.hasPendingLogin = false
                    switch loginResult {
                    case .success(let data):
                        result(["idToken": data.idToken])
                    case .failure(let error):
                        result(Self.flutterError(from: error))
                    }
                }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - FlutterApplicationLifeCycleDelegate (non-scene apps)

    public func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return handleURL(url)
    }

    public func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        return handleUserActivity(userActivity)
    }

    // MARK: - FlutterSceneLifeCycleDelegate (scene-based apps)

    public func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
        for context in URLContexts {
            if handleURL(context.url) { return true }
        }
        return false
    }

    public func scene(_ scene: UIScene, continue userActivity: NSUserActivity) -> Bool {
        return handleUserActivity(userActivity)
    }

    // MARK: - Private

    private func handleURL(_ url: URL) -> Bool {
        guard TelegramLoginFlutterPlugin.hasPendingLogin else { return false }
        Task { @MainActor in
            TelegramLogin.handle(url)
        }
        return true
    }

    private func handleUserActivity(_ userActivity: NSUserActivity) -> Bool {
        guard
            TelegramLoginFlutterPlugin.hasPendingLogin,
            userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let url = userActivity.webpageURL
        else { return false }
        Task { @MainActor in
            TelegramLogin.handle(url)
        }
        return true
    }

    private static func flutterError(from error: Error) -> FlutterError {
        guard let e = error as? TelegramLoginError else {
            return FlutterError(code: "request_failed", message: error.localizedDescription, details: nil)
        }
        switch e {
        case .notConfigured:
            return FlutterError(code: "not_configured", message: e.errorDescription, details: nil)
        case .noAuthorizationCode:
            return FlutterError(code: "no_auth_code", message: e.errorDescription, details: nil)
        case .serverError(let statusCode):
            return FlutterError(code: "server_error", message: e.errorDescription, details: statusCode)
        case .requestFailed(let msg):
            return FlutterError(code: "request_failed", message: msg, details: nil)
        case .cancelled:
            return FlutterError(code: "cancelled", message: e.errorDescription, details: nil)
        }
    }
}
