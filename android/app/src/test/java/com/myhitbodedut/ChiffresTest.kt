package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.text.NumberFormat
import java.util.Locale

/** Décision du 24/11 : en arabe, les nombres que l'application écrit sont en chiffres 0 à 9. */
class ChiffresTest {

    @Test
    fun `en arabe sans region, des chiffres 0 a 9`() {
        val l = Chiffres.locale("ar")
        assertEquals("1234", String.format(l, "%d", 1234))
        assertTrue(NumberFormat.getIntegerInstance(l).format(2985).all { it !in '٠'..'٩' && it !in '۰'..'۹' })
        assertTrue(String.format(l, "%.1f", 31.8).startsWith("31"))
    }

    @Test
    fun `en arabe de Tunisie aussi, et la region reste`() {
        val l = Chiffres.locale(Locale.forLanguageTag("ar-TN"))
        assertEquals("TN", l.country)
        assertEquals("42", String.format(l, "%d", 42))
    }

    @Test
    fun `les autres langues ne changent pas`() {
        listOf("fr", "en", "he", "es").forEach { assertEquals(it, Locale.forLanguageTag(it), Chiffres.locale(it)) }
    }

    /** Les écrans qui écrivent des nombres passent par Chiffres. */
    @Test
    fun `boussole, vol, tehilim, chemin et lune passent par Chiffres`() {
        mapOf(
            "BoussoleActivity" to "Chiffres.locale(ChizukCard.language(this))",
            "VolActivity" to "Chiffres.locale(ChizukCard.language(this))",
            "VolAlerte" to "Chiffres.locale(ChizukCard.language(c))",
            "TehilimActivity" to "Chiffres.locale(resources.configuration.locales[0])",
            "VueJour" to "Chiffres.locale(langue)",
            "MainActivity" to "Chiffres.locale(resources.configuration.locales[0])",
        ).forEach { (f, attendu) ->
            assertTrue(f, File("src/main/java/com/myhitbodedut/$f.kt").readText().contains(attendu))
        }
    }
}
