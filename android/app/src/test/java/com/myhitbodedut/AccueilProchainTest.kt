package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * Le temps annoncé jusqu'au prochain zman, sur les accueils des versions (recette du 22/11).
 * Dans la dernière minute avant un zman, Pile, Bento, Instant et Sérénité annonçaient
 * « dans 0 min » ; en grand, sur la tuile de Bento.
 */
class AccueilProchainTest {

    private val paris = ZoneId.of("Europe/Paris")

    private fun a(heure: Int, minute: Int, seconde: Int = 0) = ZonedDateTime.of(2026, 11, 17, heure, minute, seconde, 0, paris)

    @Test
    fun `les minutes entieres, comme avant`() {
        assertEquals(7, DonneesAccueil.minutesAvant(a(10, 32, 30), a(10, 40)))
        assertEquals(8, DonneesAccueil.minutesAvant(a(10, 32), a(10, 40)))
        assertEquals(72, DonneesAccueil.minutesAvant(a(9, 28), a(10, 40)))
    }

    @Test
    fun `dans la derniere minute, une minute, jamais zero`() {
        assertEquals(1, DonneesAccueil.minutesAvant(a(10, 39, 1), a(10, 40)))
        assertEquals(1, DonneesAccueil.minutesAvant(a(10, 39, 59), a(10, 40)))
        assertEquals(1, DonneesAccueil.minutesAvant(a(10, 38, 30), a(10, 40)))
    }

    /** Un écran resté ouvert après l'heure : pas de minutes négatives. */
    @Test
    fun `l heure passee, toujours une minute`() {
        assertEquals(1, DonneesAccueil.minutesAvant(a(10, 45), a(10, 40)))
    }

    /** Le même instant vu d'un autre fuseau donne le même compte. */
    @Test
    fun `le fuseau du telephone ne change rien`() {
        val ici = a(10, 32, 30).withZoneSameInstant(ZoneId.of("Asia/Jerusalem"))
        assertEquals(7, DonneesAccueil.minutesAvant(ici, a(10, 40)))
    }

    @Test
    fun `l annonce passe par ce compte`() {
        val code = File("src/main/java/com/myhitbodedut/AccueilVersion.kt").readText()
        assertTrue(code.contains("val minutes = minutesAvant(maintenant, z.instant)"))
    }
}
