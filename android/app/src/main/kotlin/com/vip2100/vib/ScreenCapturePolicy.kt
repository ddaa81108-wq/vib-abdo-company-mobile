package com.vip2100.vib

import android.view.Window
import android.view.WindowManager

internal object ScreenCapturePolicy {
    /**
     * Returns false when [generation] is older than one already applied.
     * The flags are left untouched in that case.
     */
    fun apply(
        window: Window,
        debuggable: Boolean,
        role: String?,
        generation: Long,
        generations: CaptureGeneration,
    ): Boolean {
        if (!generations.accept(generation)) return false
        if (CaptureRules.windowIsSecure(debuggable, role)) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
            )
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
        return true
    }
}
