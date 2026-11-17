package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Test

/** La pochette du mini-lecteur se décode à la taille du disque, pas en pleine taille (FSEANCE-22). */
class PochetteTest {

    @Test
    fun `une grande pochette est reduite sans passer sous la taille du disque`() {
        // 3000 × 3000 pour un disque de 192 px : 3000 / 8 = 375, 3000 / 16 = 187 serait trop petit.
        assertEquals(8, Pochette.echantillon(3000, 3000, 192))
        // Le petit côté commande : une image en largeur n'est pas réduite sous la cible.
        assertEquals(2, Pochette.echantillon(4000, 500, 192))
    }

    @Test
    fun `une petite pochette ou des dimensions illisibles ne sont pas reduites`() {
        assertEquals(1, Pochette.echantillon(300, 300, 192))
        assertEquals(1, Pochette.echantillon(192, 192, 192))
        assertEquals(1, Pochette.echantillon(-1, -1, 192))
        assertEquals(1, Pochette.echantillon(3000, 3000, 0))
    }

    @Test
    fun `le facteur est une puissance de deux`() {
        listOf(500, 1000, 1500, 2048, 3000, 6000).forEach { cote ->
            val f = Pochette.echantillon(cote, cote, 128)
            assertEquals("$cote px", 0, f and (f - 1))
        }
    }
}
