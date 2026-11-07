package com.vip2100.vib

/**
 * Local capture intent. Generation on the first line, role on the second.
 * An empty role means the window must be secure. No cookie or code is stored.
 */
internal data class CaptureIntent(val generation: Long, val role: String?)

internal object CaptureIntents {
    const val FILE_NAME = "capture-intent.txt"

    fun parse(text: String?): CaptureIntent? {
        if (text.isNullOrBlank()) return null
        val lines = text.split('\n')
        val generation = lines.firstOrNull()?.trim()?.toLongOrNull() ?: return null
        if (generation < 0L) return null
        val role = lines.getOrNull(1)?.trim()?.takeIf { it.isNotEmpty() }
        return CaptureIntent(generation, role)
    }

    /**
     * Before any channel call in this process, an allow file must not open
     * the window. A secure intent still applies.
     */
    fun shouldApply(channelAccepted: Boolean, intent: CaptureIntent): Boolean {
        if (channelAccepted) return true
        return CaptureRules.verifiedRole(intent.role) == null
    }
}
