package com.vip2100.vib

import android.app.Activity
import android.view.Window
import android.view.WindowManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Reads FLAG_SECURE from a Robolectric Window. This is not an emulator
 * screenshot, recording, or recents thumbnail.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class CaptureWindowRobolectricTest {
    @Test
    fun releaseFlagOpensForAdminAndLocksAgainWhenTheHoldElapses() {
        val window = window()
        var token = 0L
        val lock = CaptureLock(
            debuggable = false,
            scheduleHold = { scheduled, _ -> token = scheduled },
            cancelHold = {},
        )
        fun push() = ScreenCapturePolicy.push(window, lock.secure)

        lock.apply(null, 0)
        push()
        assertSecure(window, true)

        val opened = CaptureMessages.handle(
            CaptureMessages.METHOD,
            mapOf("generation" to 1, "role" to "admin"),
            lock,
        )
        push()
        assertTrue(opened.applied)
        assertSecure(window, false)

        lock.onHoldElapsed(token)
        push()
        assertSecure(window, true)

        val stale = CaptureMessages.handle(
            CaptureMessages.METHOD,
            mapOf("generation" to 0, "role" to "employee"),
            lock,
        )
        push()
        assertFalse(stale.applied)
        assertSecure(window, true)
    }

    @Test
    fun aDeliveredSecureSetsTheFlagBeforeTheHold() {
        val window = window()
        var token = 0L
        val lock = CaptureLock(
            debuggable = false,
            scheduleHold = { scheduled, _ -> token = scheduled },
            cancelHold = {},
        )
        fun push() = ScreenCapturePolicy.push(window, lock.secure)

        CaptureMessages.handle(
            CaptureMessages.METHOD,
            mapOf("generation" to 1, "role" to "employee"),
            lock,
        )
        push()
        assertSecure(window, false)

        val locked = CaptureMessages.handle(
            CaptureMessages.METHOD,
            mapOf("generation" to 2),
            lock,
        )
        push()
        assertTrue(locked.applied)
        assertSecure(window, true)
        lock.onHoldElapsed(token)
        push()
        assertSecure(window, true)
    }

    @Test
    fun pauseSetsTheFlagWithoutWaitingForTheHold() {
        val window = window()
        val lock = CaptureLock(
            debuggable = false,
            scheduleHold = { _, _ -> },
            cancelHold = {},
        )
        fun push() = ScreenCapturePolicy.push(window, lock.secure)
        lock.apply("admin", 1)
        push()
        assertSecure(window, false)
        lock.onHostPause()
        push()
        assertSecure(window, true)
        val late = lock.apply("admin", 2)
        push()
        assertFalse(late)
        assertSecure(window, true)
        lock.onHostResume()
        push()
        assertSecure(window, true)
    }

    @Test
    fun debugWindowStaysClear() {
        val window = window()
        val lock = CaptureLock(
            debuggable = true,
            scheduleHold = { _, _ -> },
            cancelHold = {},
        )
        ScreenCapturePolicy.push(window, lock.secure)
        assertSecure(window, false)
        CaptureMessages.handle(
            CaptureMessages.METHOD,
            mapOf("generation" to 1),
            lock,
        )
        ScreenCapturePolicy.push(window, lock.secure)
        assertSecure(window, false)
        lock.onHoldElapsed(1)
        ScreenCapturePolicy.push(window, lock.secure)
        assertSecure(window, false)
    }

    private fun window(): Window {
        return Robolectric.buildActivity(Activity::class.java).setup().get().window
    }

    private fun assertSecure(window: Window, expected: Boolean) {
        val set = window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE != 0
        assertEquals(expected, set)
    }
}
