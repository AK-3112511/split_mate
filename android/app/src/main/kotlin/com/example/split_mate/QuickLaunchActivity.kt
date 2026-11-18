package com.example.split_mate

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Pass-through for the long-press launcher shortcuts.
 *
 * Android starts static shortcuts with FLAG_ACTIVITY_CLEAR_TASK, which would
 * tear down a running SplitMate and replay the intro. This activity lives in its
 * own task, so only that task is cleared; it forwards the link to MainActivity
 * (reusing the running app via onNewIntent) and closes without drawing.
 */
class QuickLaunchActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val link = intent?.data
        if (link != null) {
            startActivity(
                Intent(Intent.ACTION_VIEW, link, this, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
        finish()
    }
}
