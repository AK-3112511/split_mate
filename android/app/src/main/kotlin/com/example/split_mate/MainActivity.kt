package com.example.split_mate

import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// A FragmentActivity so the fingerprint prompt (app lock, local_auth) can show.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "splitmate/privacy")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hidePreview" -> {
                        setPreviewHidden(call.arguments as? Boolean ?: false)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // With app lock on, the recent-apps screen shows a blank card instead of
    // balances. Android 13+ can hide just that preview; older versions only
    // offer FLAG_SECURE, which also blocks screenshots.
    private fun setPreviewHidden(hidden: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(!hidden)
        } else if (hidden) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
