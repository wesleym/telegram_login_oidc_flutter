package com.wesleymoy.telegram_login_oidc_flutter

import android.app.Activity
import android.content.Intent
import android.os.Bundle

class TelegramLoginCallbackActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        intent.data?.let { TelegramLoginFlutterPlugin.onCallback(it) }
        finish()
    }
}
