package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * Le soir sur les accueils des versions (recette du 22/11). Quand les zmanim du jour sont
 * passés, [DonneesAccueil.prochain] est null alors qu'un lieu est choisi : Bento, Instant et
 * Sérénité affichaient « Choisir un lieu », chaque soir. Ils montrent le dernier repère du jour
 * et son heure ; « Choisir un lieu » ne reste que sans lieu.
 */
class AccueilSoirTest {

    private val paris = ZoneId.of("Europe/Paris")

    private fun zman(cle: String, heure: Int, minute: Int) = DonneesAccueil.ZmanAffiche(
        cle, cle, "%02d:%02d".format(heure, minute), ZonedDateTime.of(2026, 11, 17, heure, minute, 0, 0, paris),
    )

    private fun donnees(lieu: String?, zmanim: List<DonneesAccueil.ZmanAffiche>, prochain: DonneesAccueil.ZmanAffiche?) = DonneesAccueil(
        prenom = "", dateCivile = "", dateHebraique = null, faite = false, minutesAujourdhui = 0, serie = 0,
        semaineFaits = 0, semaineDus = 6, totalMinutes = 0, objectifMinutes = 15, lieu = lieu, zmanim = zmanim,
        prochain = prochain, pensee = null, derniereNote = null,
    )

    private val jour = listOf(zman("netz", 8, 2), zman("chatsot", 12, 35), zman("minha_ketana", 15, 14), zman("chkia", 17, 8), zman("tset", 17, 59))

    @Test
    fun `le soir, le dernier repere du jour, et son heure`() {
        val soir = donnees("Paris", jour, prochain = null)
        assertEquals("tset", soir.dernierDuJour?.cle)
        assertEquals("17:59", soir.dernierDuJour?.heure)
    }

    @Test
    fun `en journee, le prochain zman, et rien d autre`() {
        assertNull(donnees("Paris", jour, prochain = jour[3]).dernierDuJour)
    }

    @Test
    fun `sans lieu, rien a montrer, on propose d en choisir un`() {
        assertNull(donnees(null, emptyList(), prochain = null).dernierDuJour)
    }

    /** Aucun des trois accueils ne propose plus de choisir un lieu sans avoir regardé le soir. */
    @Test
    fun `Bento, Instant et Serenite regardent le soir avant de proposer un lieu`() {
        listOf("BentoActivity", "InstantActivity", "SereniteActivity").forEach { ecran ->
            val code = File("src/main/java/com/myhitbodedut/$ecran.kt").readText()
            assertTrue("$ecran ne regarde pas le soir", code.contains("d.dernierDuJour"))
            listOf("R.string.version_choisir_lieu", "R.string.version_sans_lieu").forEach { libelle ->
                if (code.contains(libelle)) {
                    assertTrue("$ecran : $libelle avant d'avoir regardé le soir",
                        code.indexOf("d.dernierDuJour") < code.indexOf(libelle))
                }
            }
        }
    }
}
