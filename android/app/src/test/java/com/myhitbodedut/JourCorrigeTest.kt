package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** Corriger ou retirer une journée inscrite par erreur (audit du 12/11, FDONNEES-04). */
class JourCorrigeTest {

    private val jour = DayRecord("2026-11-10", 200, "", listOf("famille"))

    @Test
    fun `corriger remplace les minutes au lieu de les ajouter`() {
        val c = Store.jourCorrige(jour, "2026-11-10", 20)!!
        assertEquals(20, c.minutes)
        assertEquals(listOf("famille"), c.themes)
        assertTrue(c.faite)
    }

    @Test
    fun `retirer une journee sans note la fait disparaitre`() {
        assertNull(Store.jourCorrige(jour, "2026-11-10", 0))
    }

    @Test
    fun `retirer une journee garde sa note sans valider le jour`() {
        val c = Store.jourCorrige(jour.copy(note = "ma note"), "2026-11-10", 0)!!
        assertEquals("ma note", c.note)
        assertEquals(0, c.minutes)
        assertTrue(c.noteSeule)
        assertFalse(c.faite)
    }

    @Test
    fun `le dialogue d un jour fait propose la correction et le retrait avec confirmation`() {
        val src = File("src/main/java/com/myhitbodedut/AjoutTemps.kt").readText()
        assertTrue(src.contains("jour_corriger_duree"))
        assertTrue(src.contains("jour_retirer_confirmation"))
        assertTrue(src.contains("Store.corrigerJour"))
    }
}
