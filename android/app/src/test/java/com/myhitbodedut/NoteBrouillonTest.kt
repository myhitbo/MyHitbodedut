package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Le brouillon de la note (13/11, audit FSEANCE-04, FDONNEES-02 et 03) :
 * il survit à la fenêtre recréée, et la garde « quelque chose a changé »
 * couvre les cinq champs.
 */
class NoteBrouillonTest {

    private val garde = NoteBrouillon.Etat("une note", 2, 4, "merci", "la patience")

    @Test
    fun `rien n a change tant que la fenetre dit ce qui est enregistre`() {
        assertFalse(NoteBrouillon.modifie(garde, garde))
        assertNull(NoteBrouillon.aGarder(garde, garde))
        // Les blancs de bord ne comptent pas : l'enregistrement les retire.
        assertFalse(NoteBrouillon.modifie(garde, garde.copy(note = "  une note \n", gratitude = "merci ")))
    }

    @Test
    fun `chacun des cinq champs compte pour la garde`() {
        listOf(
            garde.copy(note = "autre"),
            garde.copy(avant = 3),
            garde.copy(apres = 0),
            garde.copy(gratitude = ""),
            garde.copy(travail = "l'écoute"),
        ).forEach {
            assertTrue(NoteBrouillon.modifie(garde, it))
            assertEquals(it, NoteBrouillon.aGarder(garde, it))
        }
    }

    @Test
    fun `le brouillon d un jour se relit tel qu il a ete ecrit et ne touche pas un autre jour`() {
        val brut = NoteBrouillon.ecrireDans(null, "2026-11-13", garde)
        assertEquals(garde, NoteBrouillon.lireDans(brut, "2026-11-13"))
        assertNull(NoteBrouillon.lireDans(brut, "2026-11-12"))
        val deux = NoteBrouillon.ecrireDans(brut, "2026-11-12", NoteBrouillon.Etat(note = "hier"))
        assertEquals(garde, NoteBrouillon.lireDans(deux, "2026-11-13"))
        assertEquals("hier", NoteBrouillon.lireDans(deux, "2026-11-12")?.note)
    }

    @Test
    fun `retirer le dernier brouillon ne laisse rien`() {
        val brut = NoteBrouillon.ecrireDans(null, "2026-11-13", garde)
        assertNull(NoteBrouillon.ecrireDans(brut, "2026-11-13", null))
        assertNull(NoteBrouillon.lireDans("pas du json", "2026-11-13"))
    }

    @Test
    fun `un brouillon abime est ramene aux bornes`() {
        val brut = """{"d":{"note":"x","avant":9,"apres":-3}}"""
        val e = NoteBrouillon.lireDans(brut, "d")!!
        assertEquals(5, e.avant)
        assertEquals(0, e.apres)
    }
}
