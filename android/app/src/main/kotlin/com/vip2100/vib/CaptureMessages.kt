package com.vip2100.vib

/**
 * The channel payload rules. An unknown or incomplete call locks release
 * and does not clear the flag. Debug [CaptureLock]s ignore that lock.
 */
internal object CaptureMessages {
    const val METHOD = "applyVerifiedRole"

    enum class Status { APPLIED, NOT_IMPLEMENTED, INVALID }

    class Result(val status: Status, val applied: Boolean)

    fun handle(method: String, arguments: Any?, lock: CaptureLock): Result {
        if (method != METHOD) {
            lock.lockRelease()
            return Result(Status.NOT_IMPLEMENTED, applied = false)
        }
        val args = arguments as? Map<*, *>
        val generation = (args?.get("generation") as? Number)?.toLong()
        if (args == null || generation == null) {
            lock.lockRelease()
            return Result(Status.INVALID, applied = false)
        }
        val role = args["role"] as? String
        return Result(Status.APPLIED, lock.apply(role, generation))
    }
}
