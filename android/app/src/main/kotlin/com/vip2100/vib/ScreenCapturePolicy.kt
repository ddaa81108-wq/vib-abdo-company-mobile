package com.vip2100.vib

import android.view.Window
import android.view.WindowManager

/**
 * Capture follows the Android build type, not a dart-define.
 *
 * [windowIsSecure] is true for every release compile (`debuggable == false`),
 * including a release APK signed with the debug keystore. Debug compiles
 * (`debuggable == true`) are not secure: screenshots and screen recording
 * both work, and the recents thumbnail can show the window.
 *
 * Android [WindowManager.LayoutParams.FLAG_SECURE] does not split those.
 * Clearing it allows screenshots, recording, and the recents image together.
 * There is no window flag that allows a screenshot while blocking recording.
 */
internal object ScreenCapturePolicy {
    fun windowIsSecure(debuggable: Boolean): Boolean = !debuggable

    fun apply(window: Window, debuggable: Boolean) {
        if (windowIsSecure(debuggable)) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
            )
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
