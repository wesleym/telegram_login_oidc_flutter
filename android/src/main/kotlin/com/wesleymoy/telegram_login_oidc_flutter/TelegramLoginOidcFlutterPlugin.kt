package com.wesleymoy.telegram_login_oidc_flutter

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.NewIntentListener
import org.telegram.login.TelegramLogin

class TelegramLoginOidcFlutterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var lifecycleCallbacks: Application.ActivityLifecycleCallbacks? = null
    private var redirectUri: Uri? = null

    // A redirect that arrived as the host Activity's launch intent due to
    // process death (see handleLaunchIntent) before configure() told us the
    // redirect URI to match against. Resolved once configure() runs (see
    // resolvePendingLaunchIntent).
    private var pendingLaunchIntentUri: Uri? = null

    // Recognizes the redirect arriving via the host Activity's onNewIntent. The
    // library consumer must set up the appropriate intent filter.
    private val newIntentListener = NewIntentListener { intent ->
        val data = intent.data
        val matched = data != null && matchesRedirect(data)
        Log.d(TAG, "onNewIntent: data=$data redirectUri=$redirectUri matched=$matched loginLaunched=$loginLaunched")
        if (matched) {
            onCallback(data!!, this)
            true
        } else {
            false
        }
    }

    private fun matchesRedirect(uri: Uri): Boolean {
        val target = redirectUri ?: return false
        if (uri.scheme != target.scheme) {
            Log.d(TAG, "matchesRedirect: scheme mismatch ${uri.scheme} != ${target.scheme}")
            return false
        }
        if (target.host != null && uri.host != target.host) {
            Log.d(TAG, "matchesRedirect: host mismatch ${uri.host} != ${target.host}")
            return false
        }
        val targetPath = target.path
        if (!targetPath.isNullOrEmpty() && uri.path?.startsWith(targetPath) != true) {
            Log.d(TAG, "matchesRedirect: path mismatch ${uri.path} does not start with $targetPath")
            return false
        }
        return true
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "telegram_login_oidc_flutter")
        channel.setMethodCallHandler(this)
        appContext = binding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "configure" -> {
                val clientId = call.argument<String>("clientId")
                    ?: return result.error("invalid_arguments", "clientId is required", null)
                val redirectUriArg = call.argument<String>("redirectUri")
                    ?: return result.error("invalid_arguments", "redirectUri is required", null)
                val scopes = call.argument<List<String>>("scopes") ?: emptyList()
                redirectUri = Uri.parse(redirectUriArg)
                Log.d(TAG, "configure: redirectUri=$redirectUri")
                TelegramLogin.init(clientId, redirectUriArg, scopes)
                resolvePendingLaunchIntent()
                result.success(null)
            }
            "login" -> {
                val act = activity
                    ?: return result.error("no_activity", "Activity is not attached", null)
                if (pendingResult != null) {
                    return result.error("login_in_progress", "A login is already in progress", null)
                }
                appContext?.let { clearPendingLogin(it) }
                pendingResult = result
                pendingResultOwner = this
                Log.d(TAG, "login: starting, redirectUri=$redirectUri")
                TelegramLogin.startLogin(act)
                loginLaunched = true
                registerCancellationWatcher(act)
            }
            "consumePendingLogin" -> {
                val context = appContext
                    ?: return result.error("no_context", "Application context is not attached", null)
                if (resolvingOrphanedRedirect) {
                    // An orphaned redirect from a *previous* engine is still being
                    // exchanged for a token on this engine (see handleLaunchIntent /
                    // resolvePendingLaunchIntent / onCallback) — its result would
                    // race with this check and land in the stash just after we'd
                    // have already reported nothing. Defer until it resolves; see
                    // finishOrphanedRedirectResolution.
                    Log.d(TAG, "consumePendingLogin: deferring until in-flight redirect resolution completes")
                    pendingConsumeResult = result
                } else {
                    completeConsumePendingLogin(context, result)
                }
            }
            else -> result.notImplemented()
        }
    }

    // Watches for the host activity resuming after login was started. If we get
    // that resume without having first received a redirect URI callback, the user
    // (probably) closed the browser/custom-tab without completing the flow — i.e.
    // cancelled. But a resume of `act` can also be transient — e.g. a brief
    // resume/pause blip during the animated hand-off to the browser/Telegram —
    // so we debounce: only signal cancellation if the activity is *still* resumed
    // (and still no redirect has arrived) after a short grace period.
    private fun registerCancellationWatcher(act: Activity) {
        unregisterCancellationWatcher()
        val app = act.application
        val handler = Handler(Looper.getMainLooper())
        var actResumed = false
        val callbacks = object : Application.ActivityLifecycleCallbacks {
            override fun onActivityResumed(resumedActivity: Activity) {
                if (resumedActivity !== act) return
                actResumed = true
                Log.d(TAG, "onActivityResumed: act=$act loginLaunched=$loginLaunched pendingLaunchIntentUri=$pendingLaunchIntentUri")
                if (!loginLaunched || pendingLaunchIntentUri != null) return
                handler.postDelayed({
                    Log.d(TAG, "onActivityResumed (debounced): actResumed=$actResumed loginLaunched=$loginLaunched pendingLaunchIntentUri=$pendingLaunchIntentUri")
                    if (actResumed && loginLaunched && pendingLaunchIntentUri == null) {
                        signalCancelled()
                        app.unregisterActivityLifecycleCallbacks(this)
                        lifecycleCallbacks = null
                    }
                }, CANCELLATION_DEBOUNCE_MS)
            }
            override fun onActivityPaused(a: Activity) {
                if (a === act) actResumed = false
            }
            override fun onActivityCreated(a: Activity, b: Bundle?) {}
            override fun onActivityStarted(a: Activity) {}
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
        activityBinding = binding
        binding.addOnNewIntentListener(newIntentListener)
        handleLaunchIntent(binding.activity)
        if (loginLaunched) registerCancellationWatcher(binding.activity)
    }

    // If process death occurred, the redirect arrives as this Activity's launch
    // intent via onCreate rather than onNewIntent. NewIntentListener wouldn't
    // see it, so check for it here. On a freshly recreated engine, configure()
    // may not have run yet and redirectUri may be null, so stash the data and
    // let resolvePendingLaunchIntent decide once it has.
    private fun handleLaunchIntent(act: Activity) {
        val data = act.intent?.data ?: return
        if (redirectUri == null) {
            Log.d(TAG, "handleLaunchIntent: deferring data=$data until configure() runs")
            pendingLaunchIntentUri = data
            return
        }
        Log.d(TAG, "handleLaunchIntent: data=$data redirectUri=$redirectUri matched=${matchesRedirect(data)}")
        if (matchesRedirect(data)) onCallback(data, this)
    }

    // Resolves a launch-intent redirect that arrived before configure() set
    // redirectUri (see handleLaunchIntent). If it turns out to match, completes
    // the login; otherwise, if a cancellation check was deferred for it (see
    // registerCancellationWatcher), signals cancellation now since that resume
    // has already happened and won't fire again.
    private fun resolvePendingLaunchIntent() {
        val data = pendingLaunchIntentUri ?: return
        pendingLaunchIntentUri = null
        val matched = matchesRedirect(data)
        Log.d(TAG, "resolvePendingLaunchIntent: data=$data redirectUri=$redirectUri matched=$matched")
        if (matched) {
            onCallback(data, this)
        } else if (loginLaunched) {
            signalCancelled()
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        // The activity is being recreated — don't cancel the login, just drop the
        // watcher and listener for now; onAttachedToActivity will re-register them.
        unregisterCancellationWatcher()
        activityBinding?.removeOnNewIntentListener(newIntentListener)
        activityBinding = null
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        // True detachment (not a config change) — treat as cancellation.
        unregisterCancellationWatcher()
        activityBinding?.removeOnNewIntentListener(newIntentListener)
        activityBinding = null
        signalCancelled()
        activity = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    companion object {
        private var pendingResult: Result? = null

        // The plugin instance that registered `pendingResult` — i.e. the engine
        // that started the in-flight login. `pendingResult`/`loginLaunched` live
        // here in the companion object (shared across engine instances) because
        // the redirect can arrive on a freshly (re)created instance after an
        // engine teardown — see onCallback for why the owner check matters.
        private var pendingResultOwner: TelegramLoginOidcFlutterPlugin? = null
        private var loginLaunched = false
        private var appContext: Context? = null

        // True while an orphaned redirect's token exchange is in flight (see
        // onCallback/finishOrphanedRedirectResolution) — guards against a
        // same-engine `consumePendingLogin` call racing ahead of the stash.
        private var resolvingOrphanedRedirect = false
        private var pendingConsumeResult: Result? = null

        internal fun onCallback(uri: Uri, caller: TelegramLoginOidcFlutterPlugin) {
            // A redirect arrived — the user completed (or errored in) the flow,
            // so the cancellation watcher must not fire afterwards.
            loginLaunched = false
            var result = pendingResult
            val owner = pendingResultOwner
            pendingResult = null
            pendingResultOwner = null
            if (result != null && owner !== caller) {
                // `pendingResult` belongs to a *previous* engine instance — the
                // engine was torn down and recreated mid-flow (see `consumePendingLogin`
                // doc comments), and this companion-object field survived the
                // teardown. Calling `.success`/`.error` on it would deliver to a
                // dead channel and silently vanish — worse, it would also make us
                // skip stashing the token because we'd think this was a normal,
                // non-orphaned resolution. Discard it and treat this as orphaned so
                // the token gets persisted for recovery instead.
                Log.d(TAG, "onCallback: discarding pendingResult from a previous engine instance for uri=$uri")
                result = null
            }
            // No (valid) pendingResult means the Dart-side `login()` call that
            // started this flow was orphaned — most likely the Flutter engine was
            // torn down and recreated while the user was completing the flow in
            // Telegram/the browser (see `consumePendingLogin` doc comments for the
            // full rationale). We still complete the exchange below so we can stash
            // the token for recovery — and meanwhile mark resolution as in-flight,
            // so a `consumePendingLogin` call from this very engine's startup (which
            // would otherwise race ahead of the stash — see
            // finishOrphanedRedirectResolution) waits for it instead of reporting
            // nothing.
            val orphaned = result == null
            if (orphaned) {
                resolvingOrphanedRedirect = true
                Log.d(TAG, "onCallback: no pendingResult for uri=$uri, completing exchange to stash result")
            } else {
                Log.d(TAG, "onCallback: handling uri=$uri")
            }
            TelegramLogin.handleLoginResponse(
                uri,
                onSuccess = { data ->
                    Log.d(TAG, "onCallback: success idToken.length=${data.idToken.length}")
                    if (result != null) {
                        result.success(mapOf("idToken" to data.idToken))
                    } else {
                        appContext?.let { savePendingLogin(it, data.idToken) }
                    }
                    if (orphaned) finishOrphanedRedirectResolution()
                },
                onError = { error ->
                    Log.d(TAG, "onCallback: error=${error.message}")
                    result?.error("request_failed", error.message, null)
                    if (orphaned) finishOrphanedRedirectResolution()
                },
            )
        }

        // Resolves a `consumePendingLogin` call that was deferred (see the
        // "consumePendingLogin" branch of onMethodCall) because it arrived while
        // this engine was still exchanging an orphaned redirect for a token.
        // Whether that exchange succeeded, failed, or yielded nothing to stash,
        // the deferred call can now safely check the (possibly now-populated) stash.
        private fun finishOrphanedRedirectResolution() {
            resolvingOrphanedRedirect = false
            val waiting = pendingConsumeResult ?: return
            pendingConsumeResult = null
            val context = appContext ?: return waiting.error(
                "no_context", "Application context is not attached", null,
            )
            completeConsumePendingLogin(context, waiting)
        }

        private fun completeConsumePendingLogin(context: Context, result: Result) {
            val idToken = consumePendingLogin(context)
            Log.d(TAG, "consumePendingLogin: idToken=${idToken?.let { "present, length=${it.length}" } ?: "none"}")
            result.success(idToken?.let { mapOf("idToken" to it) })
        }

        private fun savePendingLogin(context: Context, idToken: String) {
            prefs(context).edit()
                .putString(PREFS_KEY_ID_TOKEN, idToken)
                .putLong(PREFS_KEY_TIMESTAMP, System.currentTimeMillis())
                .apply()
        }

        private fun clearPendingLogin(context: Context) {
            prefs(context).edit()
                .remove(PREFS_KEY_ID_TOKEN)
                .remove(PREFS_KEY_TIMESTAMP)
                .apply()
        }

        // Returns and clears a stashed idToken left behind by an orphaned login
        // (see `onCallback`/`savePendingLogin`), provided it's still within the
        // freshness window — an old token is more likely to have already expired
        // or been consumed elsewhere, so we discard it rather than risk surfacing
        // a stale/confusing result.
        private fun consumePendingLogin(context: Context): String? {
            val p = prefs(context)
            val idToken = p.getString(PREFS_KEY_ID_TOKEN, null)
            val timestamp = p.getLong(PREFS_KEY_TIMESTAMP, 0L)
            clearPendingLogin(context)
            if (idToken == null) return null
            val age = System.currentTimeMillis() - timestamp
            if (age > PENDING_LOGIN_TTL_MS) {
                Log.d(TAG, "consumePendingLogin: discarding stale stash, age=${age}ms")
                return null
            }
            return idToken
        }

        private fun prefs(context: Context): SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        private fun signalCancelled() {
            if (!loginLaunched) return
            loginLaunched = false
            val result = pendingResult ?: return
            pendingResult = null
            Log.d(TAG, "signalCancelled: signalling cancellation")
            result.error("cancelled", "Login was cancelled", null)
        }

        private const val TAG = "TelegramLoginOidc"

        // Grace period before trusting a resume of the host activity as a real
        // user-initiated cancellation, to ride out transient resume/pause blips
        // during the animated hand-off to the browser/Telegram app.
        private const val CANCELLATION_DEBOUNCE_MS = 1000L

        private const val PREFS_NAME = "telegram_login_oidc_flutter_pending"
        private const val PREFS_KEY_ID_TOKEN = "idToken"
        private const val PREFS_KEY_TIMESTAMP = "timestamp"

        // How long a stashed idToken from an orphaned login (see `onCallback`)
        // remains eligible for recovery via `consumePendingLogin` before it's
        // considered stale and discarded.
        private const val PENDING_LOGIN_TTL_MS = 5 * 60 * 1000L
    }
}
