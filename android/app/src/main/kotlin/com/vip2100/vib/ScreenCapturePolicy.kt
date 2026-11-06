package com.vip2100.vib

import android.view.Window
import android.view.WindowManager

internal object ScreenCapturePolicy {
    /** A stale generation does not reach [push], so the flag stays as it was. */
    fun apply(
        window: Window,
        lock: CaptureLock,
        role: String?,
        generation: Long,
    ): Boolean {
        if (!lock.apply(role, generation)) return false
        push(window, lock.secure)
        return true
    }

    fun push(window: Window, secure: Boolean) {
        if (secure) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
            )
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
