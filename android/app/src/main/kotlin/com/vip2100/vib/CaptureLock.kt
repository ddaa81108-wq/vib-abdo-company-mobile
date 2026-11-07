package com.vip2100.vib

/**
 * Release capture state. Debug builds stay open.
 *
 * An allow is not permanent. It stays open only until [DEFAULT_HOLD_MS]
 * after the last allow that reached this object. The app refreshes that
 * hold while the verified session remains. Logout sends an immediate
 * secure update; if that update never arrives, the hold still locks.
 */
internal class CaptureLock(
    private val debuggable: Boolean,
    private val holdMs: Long = DEFAULT_HOLD_MS,
    private val scheduleHold: (token: Long, delayMs: Long) -> Unit,
    private val cancelHold: () -> Unit,
    private val generations: CaptureGeneration = CaptureGeneration(),
) {
    var secure: Boolean = !debuggable
        private set

    private var holdToken = 0L

    fun resetForNewEngine() {
        generations.reset()
        disarm()
        secure = !debuggable
    }

    /**
     * Returns false when [generation] is older than one already applied.
     * The secure flag is left unchanged in that case.
     */
    fun apply(role: String?, generation: Long): Boolean {
        if (!generations.accept(generation)) return false
        if (debuggable) {
            disarm()
            secure = false
            return true
        }
        if (CaptureRules.verifiedRole(role) == null) {
            disarm()
            secure = true
            return true
        }
        secure = false
        arm()
        return true
    }

    fun onHoldElapsed(token: Long) {
        if (debuggable || token == 0L || token != holdToken) return
        secure = true
        disarm()
    }

    /** Release locks until a later allow. Debug stays open. */
    fun lockRelease() {
        if (debuggable) return
        disarm()
        secure = true
    }

    fun disarm() {
        holdToken = 0L
        cancelHold()
    }

    private fun arm() {
        cancelHold()
        val token = holdToken + 1L
        holdToken = token
        scheduleHold(token, holdMs)
    }

    companion object {
        const val DEFAULT_HOLD_MS = 2000L
    }
}
