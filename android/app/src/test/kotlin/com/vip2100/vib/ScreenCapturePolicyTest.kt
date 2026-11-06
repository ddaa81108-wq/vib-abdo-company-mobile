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
}
