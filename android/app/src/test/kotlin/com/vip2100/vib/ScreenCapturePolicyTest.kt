package com.vip2100.vib

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ScreenCapturePolicyTest {
    @Test
    fun debugIsCapturableWhenSignedOut() {
        assertFalse(CaptureRules.windowIsSecure(debuggable = true, role = null))
    }

    @Test
    fun debugIsCapturableForEveryRole() {
        assertFalse(CaptureRules.windowIsSecure(debuggable = true, role = "admin"))
        assertFalse(CaptureRules.windowIsSecure(debuggable = true, role = "employee"))
        assertFalse(CaptureRules.windowIsSecure(debuggable = true, role = "Admin"))
        assertFalse(CaptureRules.windowIsSecure(debuggable = true, role = "guest"))
    }

    @Test
    fun releaseAdminAndEmployeeAreCapturable() {
        assertFalse(CaptureRules.windowIsSecure(debuggable = false, role = "admin"))
        assertFalse(CaptureRules.windowIsSecure(debuggable = false, role = "employee"))
        assertEquals("admin", CaptureRules.verifiedRole("admin"))
        assertEquals("employee", CaptureRules.verifiedRole("employee"))
    }

    @Test
    fun releaseRejectsMissingAndInexactRoles() {
        for (role in listOf(null, "", "Admin", "Employee", "admin ", " employee", "guest", "owner")) {
            assertTrue(CaptureRules.windowIsSecure(debuggable = false, role = role))
            assertNull(CaptureRules.verifiedRole(role))
        }
    }

    @Test
    fun olderGenerationDoesNotReplaceANewerOne() {
        val generations = CaptureGeneration()
        assertTrue(generations.accept(2))
        assertFalse(generations.accept(1))
        assertTrue(generations.accept(2))
        assertTrue(generations.accept(3))
    }

    @Test
    fun resetAllowsANewEngineToStartAtZero() {
        val generations = CaptureGeneration()
        assertTrue(generations.accept(4))
        generations.reset()
        assertTrue(generations.accept(0))
    }

    @Test
    fun releaseStartsSecureAndAllowOpensIt() {
        val harness = LockHarness()
        assertTrue(harness.lock.secure)
        assertTrue(harness.lock.apply(null, 0))
        assertTrue(harness.lock.secure)
        assertEquals(0, harness.schedules)
        assertTrue(harness.lock.apply("admin", 1))
        assertFalse(harness.lock.secure)
        assertEquals(1, harness.schedules)
        assertTrue(harness.lock.apply("employee", 2))
        assertFalse(harness.lock.secure)
    }

    @Test
    fun holdElapsedLocksWhenTheSecureUpdateNeverArrives() {
        val harness = LockHarness()
        harness.lock.apply("admin", 1)
        assertFalse(harness.lock.secure)
        harness.elapse()
        assertTrue(harness.lock.secure)
        assertEquals(1, harness.schedules)
    }

    @Test
    fun aDeliveredSecureUpdateLocksImmediatelyAndCancelsTheHold() {
        val harness = LockHarness()
        harness.lock.apply("employee", 1)
        val expired = harness.token
        assertTrue(harness.lock.apply(null, 2))
        assertTrue(harness.lock.secure)
        harness.lock.onHoldElapsed(expired!!)
        assertTrue(harness.lock.secure)
    }

    @Test
    fun aStaleAllowDoesNotReopenAfterSecure() {
        val harness = LockHarness()
        harness.lock.apply("admin", 2)
        harness.lock.apply(null, 4)
        assertFalse(harness.lock.apply("admin", 3))
        assertFalse(harness.lock.apply("employee", 1))
        assertTrue(harness.lock.secure)
    }

    @Test
    fun pauseLocksImmediatelyAndARefreshCannotOpenUntilResume() {
        val harness = LockHarness()
        harness.lock.apply("admin", 2)
        harness.lock.onHostPause()
        assertTrue(harness.lock.secure)
        assertFalse(harness.lock.apply("admin", 3))
        assertTrue(harness.lock.secure)
        harness.lock.onHostResume()
        assertTrue(harness.lock.secure)
        assertTrue(harness.lock.apply("admin", 3))
        assertFalse(harness.lock.secure)
    }

    @Test
    fun aSecureIntentLocksWithoutTheHoldAndALateRefreshStaysClosed() {
        val harness = LockHarness()
        harness.lock.apply("admin", 5)
        assertFalse(harness.lock.secure)
        val intent = CaptureIntents.parse("6\n\n")
        assertTrue(intent != null)
        assertTrue(CaptureIntents.shouldApply(channelAccepted = true, intent!!))
        assertTrue(harness.lock.apply(intent.role, intent.generation))
        assertTrue(harness.lock.secure)
        assertFalse(harness.lock.apply("admin", 5))
        assertTrue(harness.lock.secure)
        harness.elapse()
        assertTrue(harness.lock.secure)
    }

    @Test
    fun anAllowIntentIsIgnoredUntilTheChannelHasSpoken() {
        val allow = CaptureIntents.parse("4\nadmin\n")
        assertTrue(allow != null)
        assertFalse(CaptureIntents.shouldApply(channelAccepted = false, allow!!))
        assertTrue(CaptureIntents.shouldApply(channelAccepted = true, allow))
        val secure = CaptureIntents.parse("5\n\n")
        assertTrue(secure != null)
        assertTrue(CaptureIntents.shouldApply(channelAccepted = false, secure!!))
        assertNull(CaptureIntents.parse("nope"))
    }

    @Test
    fun debugPauseDoesNotLock() {
        val harness = LockHarness(debuggable = true)
        harness.lock.onHostPause()
        assertFalse(harness.lock.secure)
        harness.lock.onHostResume()
        assertFalse(harness.lock.secure)
    }

    @Test
    fun aSameGenerationRefreshExtendsTheHoldOnce() {
        val harness = LockHarness()
        harness.lock.apply("admin", 5)
        val first = harness.token
        harness.lock.apply("admin", 5)
        val second = harness.token
        assertTrue(second != first)
        harness.lock.onHoldElapsed(first!!)
        assertFalse(harness.lock.secure)
        harness.lock.onHoldElapsed(second!!)
        assertTrue(harness.lock.secure)
    }

    @Test
    fun aRefreshAfterTheHoldCanReopenAndTheNextHoldLocksAgain() {
        val harness = LockHarness()
        harness.lock.apply("admin", 5)
        harness.elapse()
        assertTrue(harness.lock.secure)
        assertTrue(harness.lock.apply("admin", 5))
        assertFalse(harness.lock.secure)
        harness.elapse()
        assertTrue(harness.lock.secure)
    }

    @Test
    fun anInexactRoleLocksWithoutWaitingForTheHold() {
        val harness = LockHarness()
        harness.lock.apply("admin", 1)
        assertTrue(harness.lock.apply("Admin", 2))
        assertTrue(harness.lock.secure)
        harness.elapse()
        assertTrue(harness.lock.secure)
    }

    @Test
    fun debugNeverLocksFromTheHoldOrAMissingRole() {
        val harness = LockHarness(debuggable = true)
        assertFalse(harness.lock.secure)
        harness.lock.apply(null, 0)
        harness.lock.apply("guest", 1)
        assertFalse(harness.lock.secure)
        assertEquals(0, harness.schedules)
        harness.lock.onHoldElapsed(1)
        assertFalse(harness.lock.secure)
        harness.lock.lockRelease()
        assertFalse(harness.lock.secure)
    }

    @Test
    fun aNewEngineStartsSecureOnRelease() {
        val harness = LockHarness()
        harness.lock.apply("admin", 6)
        assertFalse(harness.lock.secure)
        harness.lock.resetForNewEngine()
        assertTrue(harness.lock.secure)
        assertTrue(harness.lock.apply(null, 0))
        assertTrue(harness.lock.secure)
        assertFalse(harness.lock.apply("admin", -1))
        assertTrue(harness.lock.secure)
    }

    @Test
    fun aChannelMissLocksReleaseAndDoesNotClearTheFlag() {
        val harness = LockHarness()
        harness.lock.apply("admin", 2)
        assertFalse(harness.lock.secure)
        val unknown = CaptureMessages.handle("enable", null, harness.lock)
        assertEquals(CaptureMessages.Status.NOT_IMPLEMENTED, unknown.status)
        assertTrue(harness.lock.secure)
        val invalid = CaptureMessages.handle(
            CaptureMessages.METHOD,
            mapOf("role" to "admin"),
            harness.lock,
        )
        assertEquals(CaptureMessages.Status.INVALID, invalid.status)
        assertTrue(harness.lock.secure)
        val stale = CaptureMessages.handle(
            CaptureMessages.METHOD,
            mapOf("generation" to 1, "role" to "admin"),
            harness.lock,
        )
        assertEquals(CaptureMessages.Status.APPLIED, stale.status)
        assertFalse(stale.applied)
        assertTrue(harness.lock.secure)
        val again = CaptureMessages.handle(
            CaptureMessages.METHOD,
            mapOf("generation" to 3, "role" to "employee"),
            harness.lock,
        )
        assertTrue(again.applied)
        assertFalse(harness.lock.secure)
    }

    @Test
    fun lockReleaseKeepsALaterVerifiedAllowAbleToOpen() {
        val harness = LockHarness()
        harness.lock.apply("admin", 2)
        harness.lock.lockRelease()
        assertTrue(harness.lock.secure)
        assertTrue(harness.lock.apply("employee", 3))
        assertFalse(harness.lock.secure)
    }

    private class LockHarness(debuggable: Boolean = false) {
        var token: Long? = null
        var schedules = 0
        val lock = CaptureLock(
            debuggable = debuggable,
            scheduleHold = { scheduled, delayMs ->
                assertEquals(CaptureLock.DEFAULT_HOLD_MS, delayMs)
                schedules += 1
                token = scheduled
            },
            cancelHold = {},
        )

        fun elapse() {
            val scheduled = token ?: error("no hold")
            lock.onHoldElapsed(scheduled)
        }
    }
}
