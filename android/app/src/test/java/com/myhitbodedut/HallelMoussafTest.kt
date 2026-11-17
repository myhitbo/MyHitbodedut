package com.myhitbodedut

import com.myhitbodedut.CalendrierJuif.C
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * Audit du 16/11, « Hallel et Moussaf » : ce que le jour change autour du Hallel et du Moussaf,
 * jusqu'à l'écran. Les mêmes cas côté web : web/test/hallel-moussaf.test.mjs.
 */
class HallelMoussafTest {

    private val json = File("src/main/res/raw/siddur_annotations.json").readText()
    private fun c(iso: String, israel: Boolean = false) = CalendrierJuif.jour(LocalDate.parse(iso), israel).conditions
    private fun lignes(n: Nusah, id: String, iso: String, israel: Boolean = false, ouverts: Set<String> = emptySet()) =
        SiddurJour.lignes(DataFiles.siddur(n).texte(id)!!, SiddurJour.parse(json, n.cle).getValue(id), c(iso, israel), ouverts, n.cle, israel)
    private fun plat(t: String) = t.replace(Regex("<[^>]+>"), "").replace(Regex("[\\u0591-\\u05C7\\s״׳\"'()\\[\\]]"), "")
    /** Le passage se lit en clair (ni replié ni estompé), hors des consignes. */
    private fun clair(l: List<SiddurJour.Ligne>, p: String) =
        l.any { it is SiddurJour.Ligne.Bloc && it.style != SiddurJour.Style.HORS && !it.bloc.consigne && plat(it.bloc.texte).contains(plat(p)) }
    private fun rappels(l: List<SiddurJour.Ligne>) = l.filterIsInstance<SiddurJour.Ligne.Rappel>().map { it.libelle }
    private fun renvois(l: List<SiddurJour.Ligne>) = l.filterIsInstance<SiddurJour.Ligne.Renvoi>().map { it.cible }

    @Test
    fun `les conditions derivees`() {
        // Roch 'Hodech Tévèt 5786 : le samedi 30 Kislev, puis le dimanche 1er Tévèt ; 'Hanouka en semaine.
        assertTrue(C.CHABBAT_ROCH_HODECH in c("2025-12-20") && C.ROCH_HODECH_CHOL !in c("2025-12-20"))
        assertTrue(C.ROCH_HODECH_CHOL in c("2025-12-21") && C.ROCH_HODECH_CHOL in c("2026-10-12"))
        assertTrue(C.HANOUKA_SANS_MOUSSAF in c("2025-12-17"))
        listOf("2025-12-20", "2025-12-21", "2026-12-05").forEach { assertFalse(it, C.HANOUKA_SANS_MOUSSAF in c(it)) }
        assertTrue(C.HANOUKA_HORS_ROCH_HODECH in c("2026-12-05") && C.HANOUKA_HORS_ROCH_HODECH !in c("2025-12-21"))
        // 'Hol hamoèd, pas Yom tov.
        assertTrue(C.HOL_HAMOED in c("2026-04-06") && C.HOL_HAMOED in c("2026-04-03", true))
        assertFalse(C.HOL_HAMOED in c("2026-04-02") || C.HOL_HAMOED in c("2026-04-03"))
        // Le soir du Séder : 15 Nissan, et 16 en diaspora ; pas le 7ᵉ jour ni le 8ᵉ.
        assertTrue(C.LEIL_PESSAH in c("2026-04-02") && C.LEIL_PESSAH in c("2026-04-02", true) && C.LEIL_PESSAH in c("2026-04-03"))
        assertFalse(C.LEIL_PESSAH in c("2026-04-03", true) || C.LEIL_PESSAH in c("2026-04-08") || C.LEIL_PESSAH in c("2026-04-09"))
        assertTrue(C.HALLEL_PARTIEL in c("2026-10-12") && C.HALLEL_PARTIEL !in c("2025-12-17") && C.HALLEL_PARTIEL !in c("2026-11-12"))
    }

    /** Chabbat Roch 'Hodech : le Hallel, mais pas le Moussaf de semaine ; « אתה יצרת » rappelé. */
    @Test
    fun `chabbat roch hodech - pas de renvoi au moussaf de semaine`() {
        Nusah.entries.forEach { n ->
            val l = lignes(n, "chaharit", "2025-12-20")
            assertEquals(n.cle, listOf("hallel"), renvois(l))
            assertTrue(n.cle, "ajout_rappel_moussaf_chabbat_roch_hodech" in rappels(l))
            val semaine = lignes(n, "chaharit", "2025-12-21")
            assertEquals(n.cle, listOf("hallel", "moussaf_rosh_hodech"), renvois(semaine))
            assertFalse(n.cle, "ajout_rappel_moussaf_chabbat_roch_hodech" in rappels(semaine))
        }
    }

    /** 'Hol hamoèd : le Moussaf de la fête, absent, signalé (Edot, Ashkenaz) ; pas celui de Roch 'Hodech. */
    @Test
    fun `hol hamoed - le moussaf de la fete est signale`() {
        listOf(Nusah.EDOT, Nusah.ASHKENAZ).forEach { n ->
            val l = lignes(n, "chaharit", "2026-04-06")
            assertEquals(n.cle, listOf("hallel"), renvois(l))
            assertTrue(n.cle, "ajout_rappel_moussaf_hol_hamoed" in rappels(l))
            assertFalse(n.cle, "ajout_rappel_moussaf_hol_hamoed" in rappels(lignes(n, "chaharit", "2026-04-02")))
        }
    }

    /** Le Kaddich après le Hallel : תתקבל tout jour de Moussaf, le demi-Kaddich à 'Hanouka sans Moussaf. */
    @Test
    fun `hallel - titkabal les jours de moussaf, ashkenaz compris`() {
        Nusah.entries.forEach { n ->
            listOf("2025-12-20", "2025-12-21", "2026-12-05", "2026-10-12", "2026-04-06").forEach { d ->
                assertTrue("${n.cle} $d", clair(lignes(n, "hallel", d), "תתקבל"))
            }
            val hanouka = lignes(n, "hallel", "2025-12-17")
            assertFalse(n.cle, clair(hanouka, "תתקבל"))
            assertTrue(n.cle, clair(hanouka, "יתגדל ויתקדש שמה רבא"))
        }
    }

    /** Edot : la bénédiction « לגמור את ההלל » les seuls jours de Hallel complet. */
    @Test
    fun `edot - pas de benediction au hallel partiel`() {
        assertFalse(clair(lignes(Nusah.EDOT, "hallel", "2026-10-12"), "וצונו לגמור את ההלל"))
        assertFalse(clair(lignes(Nusah.EDOT, "hallel", "2026-04-06"), "וצונו לגמור את ההלל"))
        assertTrue(clair(lignes(Nusah.EDOT, "hallel", "2025-12-17"), "וצונו לגמור את ההלל"))
        // Sfard : la bénédiction reste, avec la précision pour qui prie en minyan.
        assertTrue(clair(lignes(Nusah.SEFARD, "hallel", "2026-10-12"), "וצונו לקרא את ההלל"))
        assertTrue("ajout_rappel_berakha_hallel_sefard" in rappels(lignes(Nusah.SEFARD, "hallel", "2026-10-12")))
        assertFalse("ajout_rappel_berakha_hallel_sefard" in rappels(lignes(Nusah.SEFARD, "hallel", "2025-12-17")))
    }

    /** Le soir du Séder : renvoi au Hallel après l'Amida d'Arvit, Edot et Sfard ; rien en Ashkenaz. */
    @Test
    fun `leil pessah - hallel apres l amida d arvit`() {
        listOf(Nusah.EDOT, Nusah.SEFARD).forEach { n ->
            listOf("2026-04-02" to false, "2026-04-02" to true, "2026-04-03" to false).forEach { (d, israel) ->
                assertEquals("${n.cle} $d", listOf("hallel"), renvois(lignes(n, "arvit", d, israel)))
            }
            assertTrue(n.cle, renvois(lignes(n, "arvit", "2026-04-03", true)).isEmpty())
            assertTrue(n.cle, renvois(lignes(n, "arvit", "2026-04-08")).isEmpty())
        }
        assertTrue(renvois(lignes(Nusah.ASHKENAZ, "arvit", "2026-04-02")).isEmpty())
    }

    /** « וּלְכַפָּרַת פֶּשַׁע » : plus à partir de Nissan, Edot compris (Kitsour Yalkut Yosef 423:14). */
    @Test
    fun `edot - ulekhaparat pecha jusqu a adar II`() {
        val nissan = lignes(Nusah.EDOT, "moussaf_rosh_hodech", "2027-04-08")
        assertTrue(nissan.any { it is SiddurJour.Ligne.Replie && it.condition == C.EMBOLISMIQUE_AVANT_NISSAN })
        assertFalse(clair(nissan, "ולכפרת פשע"))
        assertTrue(clair(lignes(Nusah.EDOT, "moussaf_rosh_hodech", "2026-11-11"), "ולכפרת פשע"))
    }

    /** Edot : ברכי נפשי après Moussaf ; à Roch 'Hodech Tévèt, le psaume de 'Hanouka après lui. */
    @Test
    fun `edot - barekhi nafchi apres moussaf, psaume de hanouka apres lui`() {
        val moussaf = lignes(Nusah.EDOT, "moussaf_rosh_hodech", "2026-10-12")
        assertTrue(clair(moussaf, "ברכי נפשי את יהוה"))
        assertFalse("ajout_rappel_psaume_hanouka_apres_moussaf" in rappels(moussaf))
        assertTrue("ajout_rappel_psaume_hanouka_apres_moussaf" in rappels(lignes(Nusah.EDOT, "moussaf_rosh_hodech", "2025-12-21")))
        // Le Chir chel yom : le psaume 30 replié à Roch 'Hodech Tévèt, en clair les autres jours de 'Hanouka.
        val ps30 = { l: List<SiddurJour.Ligne> -> l.any { it is SiddurJour.Ligne.Etiquette && it.condition == C.HANOUKA_HORS_ROCH_HODECH } }
        assertTrue(ps30(lignes(Nusah.EDOT, "chaharit", "2025-12-17")))
        assertFalse(ps30(lignes(Nusah.EDOT, "chaharit", "2025-12-21")))
        assertTrue(lignes(Nusah.EDOT, "chaharit", "2025-12-21").any { it is SiddurJour.Ligne.Replie && it.condition == C.HANOUKA_HORS_ROCH_HODECH })
    }

    /** Le Kaddich autour de Moussaf, Roch 'Hodech en semaine : pas de תתקבל après ובא לציון (Edot), demi-Kaddich avant Moussaf. */
    @Test
    fun `roch hodech - kaddich autour du moussaf`() {
        val edot = lignes(Nusah.EDOT, "chaharit", "2026-10-12")
        assertTrue(rappels(edot).containsAll(listOf("ajout_rappel_sans_titkabal", "ajout_rappel_demi_kaddich_moussaf_edot")))
        // Le rappel précède le renvoi au Moussaf.
        val i = edot.indexOfFirst { it is SiddurJour.Ligne.Rappel && it.libelle == "ajout_rappel_demi_kaddich_moussaf_edot" }
        assertTrue(i in 0 until edot.indexOfFirst { it is SiddurJour.Ligne.Renvoi && it.cible == "moussaf_rosh_hodech" })
        val ashkenaz = lignes(Nusah.ASHKENAZ, "chaharit", "2026-10-12")
        val j = ashkenaz.indexOfFirst { it is SiddurJour.Ligne.Rappel && it.libelle == "ajout_rappel_demi_kaddich_moussaf" }
        assertTrue(j in 0 until ashkenaz.indexOfFirst { it is SiddurJour.Ligne.Renvoi && it.cible == "moussaf_rosh_hodech" })
        listOf(Nusah.EDOT, Nusah.ASHKENAZ).forEach { assertTrue(rappels(lignes(it, "chaharit", "2026-11-12")).isEmpty()) }
    }

    /** Chaque rappel a son libellé dans les trois langues. */
    @Test
    fun `chaque rappel est traduit`() {
        val xml = listOf("values", "values-en", "values-iw").map { File("src/main/res/$it/strings.xml").readText() }
        Nusah.entries.forEach { n ->
            SiddurJour.parse(json, n.cle).values.flatten().filter { it.sorte == SiddurJour.Sorte.RENVOI && it.cible == null }.forEach { a ->
                assertTrue("${n.cle} ${a.condition}", a.libelle != null)
                xml.forEach { assertTrue(a.libelle!!, it.contains("name=\"${a.libelle}\"")) }
                assertTrue(a.libelle!!, Libelles.res(a.libelle) != null)
            }
        }
    }
}
