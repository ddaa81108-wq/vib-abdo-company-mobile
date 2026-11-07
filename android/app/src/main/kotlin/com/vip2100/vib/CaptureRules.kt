package com.vip2100.vib

/**
 * Release capture is closed unless the role is the exact server value.
 * A debug build is never secure: screenshots, recording, and recents stay
 * available, including while signed out.
 *
 * [WindowManager.LayoutParams.FLAG_SECURE] cannot allow a screenshot and
 * still block recording. Clearing it allows all three.
 */
internal object CaptureRules {
    const val adminRole = "admin"
    const val employeeRole = "employee"

    fun verifiedRole(role: String?): String? =
        if (role == adminRole || role == employeeRole) role else null

    fun windowIsSecure(debuggable: Boolean, role: String?): Boolean {
        if (debuggable) return false
        return verifiedRole(role) == null
    }
}

/** Drops a capture update that lost the race to a newer session generation. */
internal class CaptureGeneration {
    private var applied = Long.MIN_VALUE

    fun accept(generation: Long): Boolean {
        if (generation < applied) return false
        applied = generation
        return true
    }

    fun reset() {
        applied = Long.MIN_VALUE
    }
}
