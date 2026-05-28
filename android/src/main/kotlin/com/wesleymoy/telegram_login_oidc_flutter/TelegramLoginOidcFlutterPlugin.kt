package com.wesleymoy.telegram_login_oidc_flutter

import android.app.Activity
import android.app.Application
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.telegram.login.TelegramLogin

class TelegramLoginOidcFlutterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var lifecycleCallbacks: Application.ActivityLifecycleCallbacks? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "telegram_login_oidc_flutter")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "configure" -> {
                val clientId = call.argument<String>("clientId")
                    ?: return result.error("invalid_arguments", "clientId is required", null)
                val redirectUri = call.argument<String>("redirectUri")
                    ?: return result.error("invalid_arguments", "redirectUri is required", null)
                val scopes = call.argument<List<String>>("scopes") ?: emptyList()
                TelegramLogin.init(clientId, redirectUri, scopes)
                result.success(null)
            }
            "login" -> {
                val act = activity
                    ?: return result.error("no_activity", "Activity is not attached", null)
                if (pendingResult != null) {
                    return result.error("login_in_progress", "A login is already in progress", null)
                }
                pendingResult = result
                TelegramLogin.startLogin(act)
                loginLaunched = true
                registerCancellationWatcher(act)
            }
            else -> result.notImplemented()
        }
    }

    // Watches for the host activity resuming after login was started. If we get
    // that resume without having first received a redirect URI callback, the user
    // closed the browser/custom-tab without completing the flow — i.e. cancelled.
    private fun registerCancellationWatcher(act: Activity) {
        unregisterCancellationWatcher()
        val app = act.application
        val callbacks = object : Application.ActivityLifecycleCallbacks {
            override fun onActivityResumed(resumedActivity: Activity) {
                if (loginLaunched && resumedActivity === act) {
                    signalCancelled()
                    app.unregisterActivityLifecycleCallbacks(this)
                    lifecycleCallbacks = null
                }
            }
            override fun onActivityCreated(a: Activity, b: Bundle?) {}
            override fun onActivityStarted(a: Activity) {}
            override fun onActivityPaused(a: Activity) {}
            override fun onActivityStopped(a: Activity) {}
            override fun onActivitySaveInstanceState(a: Activity, b: Bundle) {}
            override fun onActivityDestroyed(a: Activity) {}
        }
        lifecycleCallbacks = callbacks
        app.registerActivityLifecycleCallbacks(callbacks)
    }

    private fun unregisterCancellationWatcher() {
        val callbacks = lifecycleCallbacks ?: return
        activity?.application?.unregisterActivityLifecycleCallbacks(callbacks)
        lifecycleCallbacks = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        // Re-register with the new activity instance in case a config change
        // (e.g. screen rotation) happened while a login was in progress.
        if (loginLaunched) registerCancellationWatcher(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // The activity is being recreated — don't cancel the login, just drop the
        // watcher for now; onAttachedToActivity will re-register it afterwards.
        unregisterCancellationWatcher()
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        // True detachment (not a config change) — treat as cancellation.
        unregisterCancellationWatcher()
        signalCancelled()
        activity = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    companion object {
        private var pendingResult: Result? = null
        private var loginLaunched = false

        internal fun onCallback(uri: Uri) {
            // A redirect arrived — the user completed (or errored in) the flow,
            // so the cancellation watcher must not fire afterwards.
            loginLaunched = false
            val result = pendingResult ?: return
            pendingResult = null
            TelegramLogin.handleLoginResponse(
                uri,
                onSuccess = { data -> result.success(mapOf("idToken" to data.idToken)) },
                onError = { error -> result.error("request_failed", error.message, null) },
            )
        }

        private fun signalCancelled() {
            if (!loginLaunched) return
            loginLaunched = false
            val result = pendingResult ?: return
            pendingResult = null
            result.error("cancelled", "Login was cancelled", null)
        }
    }
}
