package com.myhitbodedut

import org.junit.Assert.assertFalse
import org.junit.Test
import java.io.File

/** L'écran de garde laisse le téléphone se mettre en veille (audit du 12/11, FBARRIERE-02). */
class BarriereEcranTest {
    @Test
    fun `l ecran de garde ne garde pas l ecran allume`() {
        val code = File("src/main/java/com/myhitbodedut/GateService.kt").readLines()
            .filterNot { it.trim().startsWith("//") }.joinToString("\n")
        assertFalse(code.contains("FLAG_KEEP_SCREEN_ON"))
    }
}
