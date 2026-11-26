package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * Les insertions de la Amida (audit halakhique du 16/11) : Na'hem chez les Edot, conclusions et consignes
 * d'oubli, « שלום רב » d'un jeûne ashkénaze, « ועל הנסים », Na'hem sur la carte du jour.
 * Les textes : tools/siddur_insertions_amida.py ; leurs annotations : tools/siddur_annotations.py.
 */
class InsertionsAmidaTest {

    private val json = File("src/main/res/raw/siddur_annotations.json").readText()
    private fun nu(t: String) = t.replace(Regex("<[^>]+>"), " ").replace(Regex("[֑-ׇ]"), "").replace(Regex("\\s+"), " ").trim()
    private fun conditions(date: String, israel: Boolean = false) = CalendrierJuif.jour(LocalDate.parse(date), israel).conditions

    /** Les blocs lisibles en clair (ni repliés ni estompés), consignes comprises si [consignes]. */
    private fun visibles(n: Nusah, id: String, date: String, consignes: Boolean = false) =
        SiddurJour.lignes(DataFiles.siddur(n).texte(id)!!, SiddurJour.parse(json, n.cle).getValue(id), conditions(date), nusah = n.cle)
            .filterIsInstance<SiddurJour.Ligne.Bloc>().filter { it.style != SiddurJour.Style.HORS && (consignes || !it.bloc.consigne) }
            .map { nu(it.bloc.texte) }

    private fun nb(l: List<String>, motif: String) = l.count { Regex(motif).containsMatchIn(it) }

    /** Les annotations de bloc dont le texte contient [motif], avec ce texte. */
    private fun annotes(n: Nusah, id: String, motif: String): List<Pair<SiddurJour.Annotation, String>> {
        val texte = DataFiles.siddur(n).texte(id)!!
        return SiddurJour.parse(json, n.cle).getValue(id).filter { it.sorte == SiddurJour.Sorte.BLOC }
            .map { it to nu(texte.sections[it.section].blocs[it.bloc!!].texte) }.filter { Regex(motif).containsMatchIn(it.second) }
    }

    private val AMIDOT = listOf("chaharit", "minha", "arvit")

    @Test
    fun `edot - la conclusion de l officiant suit son Anenou, jamais celle du particulier`() {
        // Yalkut Yosef, Kitsour 557:3 : « ורק שליח צבור האומר עננו בין גואל לרופא, חותם בחתימה זו ».
        for (id in listOf("chaharit", "minha")) {
            val a = annotes(Nusah.EDOT, id, "העונה לעמו ישראל בעת צרה")
            assertEquals(id, 1, a.size)
            // 26/11 (Q2) : l'Anénou de l'officiant, les jours de jeûne public seulement, sous « Avec minyan ».
            assertEquals(id, "minyan", a[0].first.condition)
            assertEquals(id, "jeune", a[0].first.quand)
            assertEquals(id, 0, nb(visibles(Nusah.EDOT, id, "2025-11-18"), "העונה לעמו ישראל בעת צרה"))
        }
    }

    @Test
    fun `edot - Nahem a Arvit, Chaharit et Minha du 9 Av, un seul sceau`() {
        // Yalkut Yosef, Kitsour 557:1 : « וכן מנהג ירושלים לומר נחם בכל התפלות, ערבית שחרית ומנחה ».
        for (id in AMIDOT) {
            val ticha = visibles(Nusah.EDOT, id, "2027-08-12")
            assertEquals(id, 1, nb(ticha, "^בתשעה באב אומרים: נחם"))
            assertEquals(id, 1, nb(ticha, "ברוך אתה \\S+,? מנחם ציון"))
            assertEquals(id, 0, nb(ticha, "ברוך אתה \\S+,? בונה ירושלים"))
            val ord = visibles(Nusah.EDOT, id, "2026-11-13")
            assertEquals(id, 0, nb(ord, "נחם יהוה אלהינו"))
            assertEquals(id, 0, nb(ord, "מנחם ציון"))
            assertEquals(id, 1, nb(ord, "ברוך אתה \\S+,? בונה ירושלים"))
        }
        // Sfard, Ashkenaz : à Min'ha seulement (Rema 557:1).
        for (n in listOf(Nusah.SEFARD, Nusah.ASHKENAZ)) {
            assertEquals(n.cle, 0, nb(visibles(n, "chaharit", "2027-08-12"), "נחם יהוה אלהינו"))
            assertEquals(n.cle, 1, nb(visibles(n, "minha", "2027-08-12"), "נחם יהוה אלהינו"))
        }
    }

    @Test
    fun `carte du jour - Nahem dit a quels offices, selon le nusah`() {
        val av = conditions("2027-08-12")
        assertTrue("ajout_ticha_beav_trois" in JourAffiche.ajouts(av, "edot"))
        for (n in listOf("sefard", "ashkenaz")) assertTrue(n, "ajout_ticha_beav_minha" in JourAffiche.ajouts(av, n))
        assertTrue(JourAffiche.ajouts(conditions("2027-08-11"), "edot").none { it.startsWith("ajout_ticha_beav") })
    }

    @Test
    fun `edot - consignes d oubli de la Amida, repliees`() {
        // משיב הרוח (114:2-8), המלך הקדוש (582:2-3), טל ומטר (117:3-10), המלך המשפט (107:8 ; 582:10-11),
        // יעלה ויבא (107:16), על הנסים (682:5 ; 693:2) : Yalkut Yosef, Kitsour.
        for (id in AMIDOT) {
            val a = annotes(Nusah.EDOT, id, "\\(ילקוט יוסף, קיצור שו״ע").filter { it.first.condition == "oubli" }
            assertEquals(id, 6, a.size)
            assertEquals(id, 0, nb(visibles(Nusah.EDOT, id, "2026-12-07", consignes = true), "ילקוט יוסף, קיצור שו״ע"))
        }
        // À Arvit de Roch 'Hodech, on ne revient pas pour יעלה ויבא.
        assertEquals(1, annotes(Nusah.EDOT, "arvit", "^אם שכח יעלה ויבא בערבית של ראש חודש, אינו חוזר").size)
    }

    @Test
    fun `sfard et ashkenaz - qui a dit morid hatal ne recommence pas`() {
        // Choul'han Aroukh 114:5 : « וה"מ שלא הזכיר טל אבל אם הזכיר טל אין מחזירין אותו ».
        for (n in listOf(Nusah.SEFARD, Nusah.ASHKENAZ)) for (id in AMIDOT) {
            val a = annotes(n, id, "^ואם לא אמר משיב הרוח ומוריד הגשם אבל אמר מוריד הטל")
            assertEquals("${n.cle} $id", listOf("oubli"), a.map { it.first.condition })
        }
    }

    @Test
    fun `le voyageur entre Israel et la diaspora, pour tal oumatar`() {
        // Edot : Yalkut Yosef, Kitsour 117:15-17 ; Ashkenaz : Michna Beroura 117:5.
        for (n in listOf(Nusah.EDOT, Nusah.ASHKENAZ)) for (id in AMIDOT) {
            val a = annotes(n, id, "^בן ארץ ישראל בחוץ לארץ")
            assertEquals("${n.cle} $id", listOf("ajout_voyageur_tal_oumatar"), a.map { it.first.libelle })
            assertEquals("${n.cle} $id", "facultatif", a[0].first.condition)
        }
    }

    @Test
    fun `ashkenaz - minha d un jeune public, shim shalom sans shalom rav`() {
        // Rema 127:2 : שים שלום chaque fois qu'on dit ברכת כהנים, à Min'ha d'un jeûne public ; sinon שלום רב.
        val jeune = visibles(Nusah.ASHKENAZ, "minha", "2026-12-20")
        assertEquals(0, nb(jeune, "^שלום רב"))
        assertEquals(1, nb(jeune, "שים שלום טובה"))
        val ordinaire = visibles(Nusah.ASHKENAZ, "minha", "2026-12-21")
        assertEquals(1, nb(ordinaire, "^שלום רב"))
        assertEquals(0, nb(ordinaire, "שים שלום טובה"))
    }

    @Test
    fun `al hanissim avec le vav, dans les trois noussa'h`() {
        // Yalkut Yosef, Kitsour 682:4 ; Michna Beroura 682:1.
        for (n in Nusah.entries) for (id in AMIDOT + "birkat_hamazon" + "moussaf_rosh_hodech") {
            val blocs = DataFiles.siddur(n).texte(id)!!.sections.flatMap { it.blocs }.filter { !it.consigne }.map { nu(it.texte) }
            assertTrue("${n.cle} $id", blocs.none { Regex("^\\(?על הנסים ועל הפרקן").containsMatchIn(it) })
            assertTrue("${n.cle} $id", blocs.any { Regex("^\\(?ועל הנסים ועל הפרקן").containsMatchIn(it) })
        }
    }

    @Test
    fun `ashkenaz - la meme note pour oseh hachalom aux trois offices`() {
        // Maté Efraïm 582:22 : la chatima reste « המברך », « ויש נוהגין לומר עושה השלום ».
        for (id in AMIDOT) {
            val a = annotes(Nusah.ASHKENAZ, id, "^בעשי״ת: בספר חיים")
            assertEquals(id, 1, a.size)
            assertTrue(id, a[0].second.endsWith("(יש נוהגין לחתום: ברוך אתה יהוה עשה השלום. מטה אפרים תקפב:כב)"))
        }
    }
}
