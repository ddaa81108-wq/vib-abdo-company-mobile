package com.vip2100.vib

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ScreenCapturePolicyTest {
    @Test
    fun debugBuildIsNotSecure() {
        assertFalse(ScreenCapturePolicy.windowIsSecure(debuggable = true))
    }

    @Test
    fun releaseBuildIsSecure() {
        assertTrue(ScreenCapturePolicy.windowIsSecure(debuggable = false))
    }
}
