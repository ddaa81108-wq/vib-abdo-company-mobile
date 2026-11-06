package com.vip2100.vib

/**
 * Release capture state. Debug builds stay open.
 *
 * Logout and a failed session lock immediately when the call arrives,
 * when the activity pauses, or when a newer secure intent is applied.
 * [DEFAULT_HOLD_MS] is only the last resort: both the channel message and
 * the intent file failed. It is not a logout delay, and a same-generation
 * refresh must not be described as instant protection.
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

    /** Set after the first channel call in this process. */
    var channelAccepted: Boolean = false
        private set

    private var hostPaused = false
    private var holdToken = 0L

    fun resetForNewEngine() {
        generations.reset()
        channelAccepted = false
        hostPaused = false
        disarm()
        secure = !debuggable
    }

    fun markChannelAccepted() {
        channelAccepted = true
    }

    /** Recents and background. Does not open the window again. */
    fun onHostPause() {
        if (debuggable) return
        hostPaused = true
        disarm()
        secure = true
    }

    /** Stay secure until a later verified allow. */
    fun onHostResume() {
        hostPaused = false
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
        if (hostPaused) return false
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
