package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Les annotations du siddour (10/10) : elles désignent encore le bon bloc,
 * leurs conditions existent, chaque libellé est traduit, et les ajouts
 * principaux sont là dans chaque nusah.
 */
class SiddurJourTest {

    private val json = File("src/main/res/raw/siddur_annotations.json").readText()

    @Test
    fun `chaque annotation designe encore son bloc`() {
        Nusah.entries.forEach { n ->
            val siddur = DataFiles.siddur(n)
            SiddurJour.parse(json, n.cle).forEach { (id, annotations) ->
                val texte = siddur.texte(id)!!
                annotations.forEach { a ->
                    val section = texte.sections[a.section]
                    val vu = if (a.bloc == null) SiddurJour.empreinte(section.titre)
                    else SiddurJour.empreinte(section.blocs[a.bloc].texte)
                    assertEquals("${n.cle}/$id §${a.section}/${a.bloc}", a.empreinte, vu)
                }
            }
        }
    }

    @Test
    fun `les conditions existent et chaque libelle est traduit`() {
        val connues = (CalendrierJuif.C.TOUTES + CalendrierJuif.C.DERIVEES).toSet()
        val xml = listOf("values", "values-en", "values-iw").map { File("src/main/res/$it/strings.xml").readText() }
        Nusah.entries.forEach { n ->
            SiddurJour.parse(json, n.cle).values.flatten().forEach { a ->
                assertTrue("${n.cle} : ${a.condition}", a.condition.removePrefix("!") in connues)
                xml.forEach { assertTrue("${n.cle} : ${SiddurJour.libelle(a.condition)}", it.contains("name=\"${SiddurJour.libelle(a.condition)}\"")) }
                if (a.sorte == SiddurJour.Sorte.BLOC) assertTrue(a.groupe != null && a.racine != null)
                a.libelle?.let { l -> xml.forEach { assertTrue("${n.cle} : $l", it.contains("name=\"$l\"")) } }
            }
        }
    }

    @Test
    fun `les ajouts principaux sont annotes dans les trois nusah`() {
        Nusah.entries.forEach { n ->
            val chaharit = SiddurJour.parse(json, n.cle).getValue("chaharit").map { it.condition }.toSet()
            listOf("yaale_veyavo", "al_hanissim", "hanouka", "pourim", "tal_oumatar", "berakha", "asseret_yemei_techouva")
                .forEach { assertTrue("${n.cle} : $it", it in chaharit) }
            // Été / hiver dans les trois offices (14/10 : l'Arvit ashkénaze n'était pas marqué).
            listOf("chaharit", "minha", "arvit").forEach { o ->
                val c = SiddurJour.parse(json, n.cle).getValue(o).map { it.condition }.toSet()
                listOf("tal_oumatar", "berakha").forEach { assertTrue("${n.cle} $o : $it", it in c) }
            }
            val repas = SiddurJour.parse(json, n.cle).getValue("birkat_hamazon").map { it.condition }.toSet()
            listOf("yaale_veyavo", "al_hanissim", "chabbat").forEach { assertTrue("${n.cle} repas : $it", it in repas) }
        }
    }

    /** Roch 'Hodech (12/10) : dans Cha'harit, « Aujourd'hui · Hallel › » puis « Moussaf › » ; un jour ordinaire, rien. */
    @Test
    fun `roch hodech - chaharit renvoie au hallel puis au moussaf`() {
        val rc = CalendrierJuif.jour(java.time.LocalDate.parse("2026-10-12"), false).conditions
        val ordinaire = CalendrierJuif.jour(java.time.LocalDate.parse("2026-10-14"), false).conditions
        Nusah.entries.forEach { n ->
            val siddur = DataFiles.siddur(n)
            val texte = siddur.texte("chaharit")!!
            val annotations = SiddurJour.parse(json, n.cle).getValue("chaharit")
            val renvois = SiddurJour.lignes(texte, annotations, rc, nusah = n.cle).filterIsInstance<SiddurJour.Ligne.Renvoi>()
            assertEquals(n.cle, listOf("hallel", "moussaf_rosh_hodech"), renvois.map { it.cible })
            renvois.forEach { assertTrue(n.cle, siddur.texte(it.cible) != null) }
            assertTrue(n.cle, SiddurJour.lignes(texte, annotations, ordinaire, nusah = n.cle).none { it is SiddurJour.Ligne.Renvoi })
        }
    }

    /**
     * Règle du 26/11 : à Roch 'Hodech, Ya'alé véyavo en évidence avec sa seule ligne du jour (la variante de Pessa'h
     * est retirée, Q8) ; Al hanissim, du calendrier, est retiré, sans bandeau replié. À 'Hanouka, il revient, avec la
     * ligne de 'Hanouka seule.
     */
    @Test
    fun `roch hodech - yaale veyavo en evidence, al hanissim retire`() {
        val texte = DataFiles.siddur(Nusah.EDOT).texte("chaharit")!!
        val annotations = SiddurJour.parse(json, "edot").getValue("chaharit")
        val rc = CalendrierJuif.jour(java.time.LocalDate.parse("2026-10-12"), false).conditions
        val lignes = SiddurJour.lignes(texte, annotations, rc)
        assertTrue(SiddurJour.Ligne.Etiquette("yaale_veyavo", "ajout_yaale_veyavo") in lignes)
        assertTrue(lignes.none { it is SiddurJour.Ligne.Replie && it.condition == "al_hanissim" })
        assertTrue(lignes.none { it is SiddurJour.Ligne.Etiquette && it.condition == "al_hanissim" })
        val blocs = lignes.filterIsInstance<SiddurJour.Ligne.Bloc>().map { SiddurJour.empreinte(it.bloc.texte) }
        assertTrue(blocs.any { it.contains("ראש חדש הזה") })
        assertFalse(blocs.any { it.contains("חג המצות הזה") })
        assertFalse(blocs.any { it.startsWith("ועל הנסים") })
        // 'Hanouka (27 Kislev) : Al hanissim en évidence, « בימי מתתיה », sans « בימי מרדכי ».
        val hanouka = SiddurJour.lignes(texte, annotations, CalendrierJuif.jour(java.time.LocalDate.parse("2026-12-07"), false).conditions)
        assertTrue(SiddurJour.Ligne.Etiquette("al_hanissim", "ajout_al_hanissim") in hanouka)
        val h = hanouka.filterIsInstance<SiddurJour.Ligne.Bloc>().map { SiddurJour.empreinte(it.bloc.texte) }
        assertTrue(h.any { it.contains("בימי מתתיה") })
        assertFalse(h.any { it.contains("בימי מרדכי") })
        // Aucun repli du calendrier dans Cha'harit un jour ordinaire : seuls ceux des occasions restent.
        val ordinaire = SiddurJour.lignes(texte, annotations, CalendrierJuif.jour(java.time.LocalDate.parse("2026-11-17"), false).conditions)
        ordinaire.filterIsInstance<SiddurJour.Ligne.Replie>().forEach {
            assertTrue(it.condition, it.condition in SiddurJour.OCCASIONS || it.pasAujourdhui || it.libelle == "ajout_jeune_individuel")
        }
    }

    @Test
    fun `anenou - l officiant et le particulier, selon le nusah`() {
        val jeune = CalendrierJuif.jour(java.time.LocalDate.parse("2026-12-20"), false).conditions // 10 Tevet
        fun etiquettes(n: Nusah, id: String) = SiddurJour.lignes(DataFiles.siddur(n).texte(id)!!,
            SiddurJour.parse(json, n.cle).getValue(id), jeune, nusah = n.cle)
            .filterIsInstance<SiddurJour.Ligne.Etiquette>().map { it.libelle }
        fun nu(t: String) = SiddurJour.empreinte(t)
        fun tout(n: Nusah, id: String, c: Set<String>): List<SiddurJour.Ligne> {
            val texte = DataFiles.siddur(n).texte(id)!!
            val a = SiddurJour.parse(json, n.cle).getValue(id)
            val replis = SiddurJour.lignes(texte, a, c, nusah = n.cle).filterIsInstance<SiddurJour.Ligne.Replie>().map { it.cle }.toSet()
            return SiddurJour.lignes(texte, a, c, replis, nusah = n.cle)
        }
        // 26/11, Q2 : le particulier en évidence les jours de jeûne public ; Edot, à Cha'harit comme à Min'ha ;
        // Ashkenaz et Sfard, à Min'ha seulement.
        assertTrue(etiquettes(Nusah.EDOT, "chaharit").contains("ajout_anenou_particulier"))
        assertTrue(etiquettes(Nusah.EDOT, "minha").contains("ajout_anenou_particulier"))
        listOf(Nusah.ASHKENAZ, Nusah.SEFARD).forEach { n ->
            assertFalse(n.cle, etiquettes(n, "chaharit").any { it.startsWith("ajout_anenou") })
            assertTrue(n.cle, etiquettes(n, "minha").contains("ajout_anenou_particulier"))
        }
        // L'officiant, ces jours-là, replié sous « Avec minyan » (pas d'étiquette) ; son texte se lit une fois déplié.
        Nusah.entries.forEach { n ->
            assertFalse(n.cle, etiquettes(n, "minha").contains("ajout_anenou_officiant"))
            val l = SiddurJour.lignes(DataFiles.siddur(n).texte("minha")!!, SiddurJour.parse(json, n.cle).getValue("minha"), jeune, nusah = n.cle)
            assertTrue(n.cle, tout(n, "minha", jeune).filterIsInstance<SiddurJour.Ligne.Bloc>().any { "השליח ציבור אומר בחזרה" in nu(it.bloc.texte) || "אומר כאן הש״ץ עננו" in nu(it.bloc.texte) })
            assertTrue(n.cle, l.filterIsInstance<SiddurJour.Ligne.Replie>().all { r -> r.condition in SiddurJour.OCCASIONS || r.pasAujourdhui || r.libelle == "ajout_jeune_individuel" })
        }
        // Un jour ordinaire : l'officiant retiré, même tout déplié ; le particulier replié sous « Jeûne individuel ».
        val ordinaire = CalendrierJuif.jour(java.time.LocalDate.parse("2026-12-21"), false).conditions
        Nusah.entries.forEach { n ->
            val l = tout(n, "minha", ordinaire)
            assertFalse(n.cle, l.filterIsInstance<SiddurJour.Ligne.Bloc>().any { "השליח ציבור אומר בחזרה" in nu(it.bloc.texte) || "אומר כאן הש״ץ עננו" in nu(it.bloc.texte) })
            assertTrue(n.cle, l.any { it is SiddurJour.Ligne.Replie && it.libelle == "ajout_jeune_individuel" && !it.pasAujourdhui })
        }
    }

    @Test
    fun `les sceaux visibles - un seul pour Jerusalem, Modim garde le sien (audit du 12-11)`() {
        fun nu(t: String) = t.replace(Regex("<[^>]+>"), " ").replace(Regex("[\u0591-\u05C7]"), "").replace(Regex("\\s+"), " ")
        fun visibles(n: Nusah, id: String, date: String) = SiddurJour.lignes(DataFiles.siddur(n).texte(id)!!,
            SiddurJour.parse(json, n.cle).getValue(id), CalendrierJuif.jour(java.time.LocalDate.parse(date), false).conditions, nusah = n.cle)
            .filterIsInstance<SiddurJour.Ligne.Bloc>().map { nu(it.bloc.texte) }
        // TSIDDUR-01 : Min'ha Edot, un jour ordinaire : « בונה ירושלים » seul, sans le sceau de Na'hem ni celui d'Anénou.
        val minha = visibles(Nusah.EDOT, "minha", "2026-11-13")
        assertEquals(1, minha.count { Regex("ברוך אתה \\S+,? (בונה ירושלים|מנחם ציון)").containsMatchIn(it) })
        assertFalse(minha.any { "העונה לעמו ישראל בעת צרה" in it })
        assertFalse(visibles(Nusah.EDOT, "chaharit", "2026-11-13").any { "העונה לעמו ישראל בעת צרה" in it })
        // TSIDDUR-02 : Moussaf de Roch 'Hodech hors 'Hanouka (1er Kislev) : la fin de Modim et son sceau restent visibles.
        listOf(Nusah.EDOT, Nusah.ASHKENAZ, Nusah.SEFARD).forEach { n ->
            assertTrue(n.cle, visibles(n, "moussaf_rosh_hodech", "2026-11-11").any { "הטוב שמך ולך נאה להודות" in it })
        }
    }

    @Test
    fun `les sceaux visibles - fin d office, Hallel, dix jours, supplications (audit du 12-11)`() {
        fun nu(t: String) = t.replace(Regex("<[^>]+>"), " ").replace(Regex("[\u0591-\u05C7]"), "").replace(Regex("\\s+"), " ").trim()
        fun visibles(n: Nusah, id: String, date: String) = SiddurJour.lignes(DataFiles.siddur(n).texte(id)!!,
            SiddurJour.parse(json, n.cle).getValue(id), CalendrierJuif.jour(java.time.LocalDate.parse(date), false).conditions, nusah = n.cle)
            .filterIsInstance<SiddurJour.Ligne.Bloc>().map { nu(it.bloc.texte) }
        fun nb(l: List<String>, motif: String) = l.count { Regex(motif).containsMatchIn(it) }
        // TSIDDUR-03 : un vendredi (sans Ta'hanoun), la fin de Min'ha reste lue.
        assertTrue(visibles(Nusah.SEFARD, "minha", "2026-11-13").any { it.startsWith("עלינו לשבח") })
        assertTrue(visibles(Nusah.EDOT, "minha", "2026-11-13").any { "יהוה מלך גאות" in it })
        // TSIDDUR-03 : « שומר ישראל » (Sfard, Cha'harit) un mardi de Ta'hanoun.
        assertTrue(visibles(Nusah.SEFARD, "chaharit", "2026-11-17").any { it.startsWith("שומר ישראל") })
        // TSIDDUR-04 : Moussaf ashkénaze, qui prie seul : un seul sceau de la Kedoucha.
        assertEquals(1, nb(visibles(Nusah.ASHKENAZ, "moussaf_rosh_hodech", "2026-11-11"), "ברוך אתה \\S+ האל הקדוש"))
        // TSIDDUR-05 : Hallel partiel (Roch 'Hodech), Edot : pas de bénédiction « לגמור את ההלל ».
        assertFalse(visibles(Nusah.EDOT, "hallel", "2026-11-11").any { "לגמור את ההלל" in it })
        assertTrue(visibles(Nusah.EDOT, "hallel", "2026-12-07").any { "לגמור את ההלל" in it })
        // TSIDDUR-06 : dix jours (4 Tichri 5788), un seul sceau ; un jour ordinaire, celui de tous les jours.
        listOf(Nusah.SEFARD, Nusah.ASHKENAZ).forEach { n ->
            val dix = visibles(n, "chaharit", "2027-10-05")
            assertEquals(n.cle, 0, nb(dix, "ברוך אתה \\S+ האל הקדוש"))
            assertEquals(n.cle, 1, nb(dix, "ברוך אתה \\S+ המלך הקדוש"))
            val ord = visibles(n, "chaharit", "2026-11-13")
            assertEquals(n.cle, 1, nb(ord, "ברוך אתה \\S+ האל הקדוש"))
            assertEquals(n.cle, 0, nb(ord, "ברוך אתה \\S+ המלך הקדוש"))
        }
        // TSIDDUR-06 : Min'ha du 9 Av, Na'hem seul avec son sceau.
        listOf(Nusah.SEFARD, Nusah.ASHKENAZ, Nusah.EDOT).forEach { n ->
            val ticha = visibles(n, "minha", "2027-08-12")
            assertEquals(n.cle, 0, nb(ticha, "ברוך אתה \\S+,? בונה ירושלים"))
            assertEquals(n.cle, 1, nb(ticha, "ברוך אתה \\S+,? מנחם ציון"))
        }
        // TSIDDUR-07 : supplications du lundi et du jeudi (Edot) : lues le lundi, absentes le mardi.
        assertTrue(visibles(Nusah.EDOT, "chaharit", "2026-11-16").any { it.startsWith("אנשי אמונה") })
        assertFalse(visibles(Nusah.EDOT, "chaharit", "2026-11-17").any { it.startsWith("אנשי אמונה") })
    }

    @Test
    fun `ashkenaz hors d israel - morid hatal retire l ete`() {
        val ete = CalendrierJuif.jour(java.time.LocalDate.parse("2027-06-01"), false).conditions
        fun etat(n: Nusah, israel: Boolean) = SiddurJour.lignes(DataFiles.siddur(n).texte("chaharit")!!,
            SiddurJour.parse(json, n.cle).getValue("chaharit"), ete, nusah = n.cle, enIsrael = israel)
        // 26/11 : ni replié ni en évidence, retiré.
        assertTrue(etat(Nusah.ASHKENAZ, false).none { (it is SiddurJour.Ligne.Replie && it.condition == "morid_hatal") ||
            (it is SiddurJour.Ligne.Etiquette && it.condition == "morid_hatal") })
        assertTrue(SiddurJour.Ligne.Etiquette("morid_hatal", "ajout_morid_hatal") in etat(Nusah.ASHKENAZ, true))
        assertTrue(SiddurJour.Ligne.Etiquette("morid_hatal", "ajout_morid_hatal") in etat(Nusah.SEFARD, false))
    }

    /** FLECTURE-08 : un paragraphe réduit de sa variante garde sa place d'origine (marque-pages). */
    @Test
    fun `chaque ligne garde le paragraphe d origine meme reduit`() {
        val ete = CalendrierJuif.jour(java.time.LocalDate.parse("2027-06-01"), false).conditions
        var reduits = 0
        for (n in Nusah.values()) {
            val texte = DataFiles.siddur(n).texte("chaharit")!!
            val tous = texte.sections.flatMap { it.blocs }
            SiddurJour.lignes(texte, SiddurJour.parse(json, n.cle).getValue("chaharit"), ete, nusah = n.cle, enIsrael = true)
                .filterIsInstance<SiddurJour.Ligne.Bloc>().forEach { l ->
                    assertTrue(n.cle, tous.any { it === l.origine })
                    if (l.bloc !== l.origine) reduits++
                }
        }
        assertTrue("au moins un paragraphe réduit", reduits > 0)
    }

    /** Avinou malkénou (14/10) : retiré un jour ordinaire (26/11), en évidence le 10 Tévèt et pendant les dix jours. */
    @Test
    fun `avinou malkenou - jeunes et dix jours seulement`() {
        fun am(d: String) = CalendrierJuif.C.AVINOU_MALKENOU in
            SiddurJour.conditionsPour("ashkenaz", true, CalendrierJuif.jour(java.time.LocalDate.parse(d), true).conditions)
        listOf("2026-12-20", "2026-09-15", "2026-09-13", "2026-09-14").forEach { assertTrue(it, am(it)) }
        listOf("2026-12-21", "2026-09-12", "2026-09-19", "2026-09-20", "2027-08-12").forEach { assertFalse(it, am(it)) }
        listOf(Nusah.ASHKENAZ, Nusah.SEFARD).forEach { n ->
            fun lignes(d: String) = SiddurJour.lignes(DataFiles.siddur(n).texte("chaharit")!!,
                SiddurJour.parse(json, n.cle).getValue("chaharit"),
                CalendrierJuif.jour(java.time.LocalDate.parse(d), true).conditions, nusah = n.cle, enIsrael = true)
            assertTrue("${n.cle}", lignes("2026-12-21").none { (it is SiddurJour.Ligne.Replie && it.condition == "avinou_malkenou") ||
                (it is SiddurJour.Ligne.Etiquette && it.condition == "avinou_malkenou") })
            assertTrue("${n.cle}", SiddurJour.Ligne.Etiquette("avinou_malkenou", "ajout_avinou_malkenou") in lignes("2026-12-20"))
        }
    }

    /** Avinou malkénou à Min'ha (TSIDDUR-09) : seulement si Ta'hanoun s'y dit (pas le 13 Adar II, pas la veille de Kippour un vendredi). */
    @Test
    fun `avinou malkenou a minha - pas sans tahanoun`() {
        fun am(d: String) = CalendrierJuif.C.AVINOU_MALKENOU_MINHA in
            SiddurJour.conditionsPour("ashkenaz", true, CalendrierJuif.jour(java.time.LocalDate.parse(d), true).conditions)
        assertTrue(am("2026-12-20"))
        assertTrue(am("2026-09-15"))
        listOf("2027-03-22", "2028-09-29", "2026-12-21").forEach { assertFalse(it, am(it)) }
        // Roch Hachana (dimanche, jeudi) et Kippour (lundi), sans Ta'hanoun : Avinou malkénou à Min'ha ;
        // pas le vendredi (Roch Hachana 2028, 2ᵉ jour), ni un vendredi des dix jours (relecture du 15/11).
        listOf("2026-09-13", "2028-09-21", "2026-09-21").forEach { assertTrue(it, am(it)) }
        listOf("2028-09-22", "2026-09-18").forEach { assertFalse(it, am(it)) }
    }

    /** La lecture de la Torah (15/10) : ouverte les jours de lecture, retirée un mardi ordinaire (26/11). */
    @Test
    fun `kriat hatorah - retiree les jours sans lecture`() {
        fun c(d: String) = CalendrierJuif.jour(java.time.LocalDate.parse(d), true).conditions
        listOf("2026-10-19", "2026-10-15", "2026-10-17", "2026-11-11", "2026-12-20", "2026-09-29")
            .forEach { assertTrue(it, CalendrierJuif.C.KRIAT_HATORAH in c(it)) }
        listOf("2026-10-20", "2026-10-21", "2026-10-23").forEach { assertFalse(it, CalendrierJuif.C.KRIAT_HATORAH in c(it)) }
        Nusah.entries.forEach { n ->
            fun lignes(d: String) = SiddurJour.lignes(DataFiles.siddur(n).texte("chaharit")!!,
                SiddurJour.parse(json, n.cle).getValue("chaharit"), c(d), nusah = n.cle, enIsrael = true)
            assertTrue(n.cle, lignes("2026-10-20").none { (it is SiddurJour.Ligne.Replie && it.condition == "kriat_hatorah") ||
                (it is SiddurJour.Ligne.Etiquette && it.condition == "kriat_hatorah") })
            assertTrue(n.cle, SiddurJour.Ligne.Etiquette("kriat_hatorah", "ajout_kriat_hatorah") in lignes("2026-10-19"))
            // « אל ארך אפים » : dit un lundi ordinaire, retiré à Pourim (23/03/2027) et à 'Hanouka (07/12/2026), sans Ta'hanoun.
            fun elArekh(d: String) = lignes(d).filterIsInstance<SiddurJour.Ligne.Bloc>()
                .firstOrNull { SiddurJour.empreinte(it.bloc.texte).startsWith("אל ארך אפים") }?.style
            assertEquals(n.cle, SiddurJour.Style.DU_JOUR, elArekh("2026-10-19"))
            assertEquals(n.cle, null, elArekh("2027-03-23"))
            assertEquals(n.cle, null, elArekh("2026-12-07"))
        }
        // Les « יהי רצון » (Sfard, Ashkenaz) : lundi et jeudi avec Ta'hanoun seulement ; pas à Roch 'Hodech (11/11/2026, mercredi).
        listOf(Nusah.SEFARD, Nusah.ASHKENAZ).forEach { n ->
            fun yehiRatson(d: String) = SiddurJour.lignes(DataFiles.siddur(n).texte("chaharit")!!,
                SiddurJour.parse(json, n.cle).getValue("chaharit"), c(d), nusah = n.cle, enIsrael = true)
                .filterIsInstance<SiddurJour.Ligne.Bloc>().firstOrNull { SiddurJour.empreinte(it.bloc.texte).startsWith("יהי רצון מלפני אבינו") }?.style
            assertEquals(n.cle, SiddurJour.Style.DU_JOUR, yehiRatson("2026-10-19"))
            assertEquals(n.cle, null, yehiRatson("2026-11-11"))
        }
    }

    @Test
    fun `une condition niee s applique quand la cle manque`() {
        assertTrue(SiddurJour.vrai("!tahanoun_minha", setOf("chabbat")))
        assertFalse(SiddurJour.vrai("!tahanoun_minha", setOf("tahanoun_minha")))
        assertTrue(SiddurJour.vrai("roch_hodech", setOf("roch_hodech")))
        assertEquals("ajout_sans_tahanoun", SiddurJour.libelle("!tahanoun_chaharit"))
        assertEquals("fete_yom_kippour", SiddurJour.libelle("kippour"))
    }

    // --- Audit du 16/11, « Ta'hanoun et ce qui en dépend » (les mêmes cas : web/test/tahanoun.test.mjs) ---------------

    private fun c(date: String) = CalendrierJuif.jour(java.time.LocalDate.parse(date), false).conditions

    /** Le style d'un bloc ce jour-là ; null quand il est replié ou retiré. */
    private fun styleDe(n: Nusah, id: String, si: Int, bi: Int, date: String): SiddurJour.Style? {
        val texte = DataFiles.siddur(n).texte(id)!!
        val lignes = SiddurJour.lignes(texte, SiddurJour.parse(json, n.cle).getValue(id), c(date), nusah = n.cle)
        return lignes.filterIsInstance<SiddurJour.Ligne.Bloc>().firstOrNull { it.origine === texte.sections[si].blocs[bi] }?.style
    }

    @Test
    fun `al erekh apayim suit lamnatseah, pas le tahanoun (MB 131-35)`() {
        listOf(Nusah.SEFARD to 12, Nusah.ASHKENAZ to 5).forEach { (n, s) ->
            assertEquals(n.cle, SiddurJour.Style.DU_JOUR, styleDe(n, "chaharit", s, 1, "2026-02-02")) // lundi, Tou biChvat
            assertEquals(n.cle, null, styleDe(n, "chaharit", s, 1, "2026-08-13")) // jeudi, Roch 'Hodech : retiré (26/11)
            assertEquals(n.cle, null, styleDe(n, "chaharit", s, 1, "2025-12-30")) // mardi, 10 Tévèt (ShA haRav 429:12)
        }
    }

    @Test
    fun `ashkenaz - vidoui et piyout du lundi et du jeudi seulement (MB 134-1)`() {
        listOf(73, 83).forEach { b ->
            assertEquals("$b", SiddurJour.Style.DU_JOUR, styleDe(Nusah.ASHKENAZ, "chaharit", 4, b, "2025-11-17"))
            assertEquals("$b", null, styleDe(Nusah.ASHKENAZ, "chaharit", 4, b, "2025-11-18"))
        }
        // Le Vidouï d'avant Avinou malkénou, « selon l'usage » (26/11, Q14) : replié le lundi, retiré le mardi.
        fun usage(d: String) = SiddurJour.lignes(DataFiles.siddur(Nusah.ASHKENAZ).texte("chaharit")!!, SiddurJour.parse(json, "ashkenaz").getValue("chaharit"),
            c(d), nusah = "ashkenaz").any { it is SiddurJour.Ligne.Replie && it.libelle == "ajout_lundi_jeudi_usage" }
        assertTrue(usage("2025-11-17"))
        assertFalse(usage("2025-11-18"))
        assertEquals(null, styleDe(Nusah.ASHKENAZ, "chaharit", 4, 2, "2025-11-17"))
        assertEquals(SiddurJour.Style.DU_JOUR, styleDe(Nusah.ASHKENAZ, "chaharit", 4, 84, "2025-11-18")) // שומר ישראל
    }

    @Test
    fun `tsom guedalia - avinou malkenou sans les lignes des jeunes`() {
        assertEquals(null, styleDe(Nusah.ASHKENAZ, "chaharit", 4, 14, "2025-09-25")) // ברך עלינו, retiré (26/11)
        assertEquals(SiddurJour.Style.DU_JOUR, styleDe(Nusah.ASHKENAZ, "chaharit", 4, 13, "2025-09-25")) // חדש עלינו
        assertEquals(SiddurJour.Style.DU_JOUR, styleDe(Nusah.ASHKENAZ, "chaharit", 4, 14, "2025-12-30")) // 10 Tévèt
    }

    @Test
    fun `edot - avinou malkenou du chabbat sans les lignes de faute`() {
        // Blocs 83-84 de l'Amida Edot depuis les insertions de la Amida du 16/11 (Na'hem, consignes d'oubli).
        assertEquals(null, styleDe(Nusah.EDOT, "chaharit", 9, 83, "2025-09-27")) // retiré (26/11)
        assertEquals(SiddurJour.Style.DU_JOUR, styleDe(Nusah.EDOT, "chaharit", 9, 84, "2025-09-27"))
        assertEquals(SiddurJour.Style.DU_JOUR, styleDe(Nusah.EDOT, "chaharit", 9, 83, "2025-09-29"))
    }

    @Test
    fun `edot - pas de vidoui a minha la veille de pessah cheni, kaddich du hallel les jours de moussaf`() {
        assertFalse(CalendrierJuif.C.TAHANOUN_MINHA in SiddurJour.conditionsPour("edot", false, c("2026-04-30")))
        assertTrue(CalendrierJuif.C.TAHANOUN_MINHA in SiddurJour.conditionsPour("sefard", false, c("2026-04-30")))
        assertTrue(CalendrierJuif.C.KADDICH_COMPLET_HALLEL in c("2025-12-21")) // Roch 'Hodech Tévèt
        assertTrue(CalendrierJuif.C.KADDICH_COMPLET_HALLEL in c("2025-12-20")) // Chabbat 'Hanouka
        assertFalse(CalendrierJuif.C.KADDICH_COMPLET_HALLEL in c("2025-12-16")) // 'Hanouka, mardi
    }

    @Test
    fun `pas de tahanoun aujourd hui - le reglage ponctuel retire le tahanoun, pas lamnatseah`() {
        val jour = SiddurJour.avecSansTahanoun(c("2025-11-17"), true)
        listOf("edot", "sefard", "ashkenaz").forEach { n ->
            val cc = SiddurJour.conditionsPour(n, false, jour)
            listOf(CalendrierJuif.C.TAHANOUN_CHAHARIT, CalendrierJuif.C.TAHANOUN_MINHA, CalendrierJuif.C.LUNDI_JEUDI)
                .forEach { assertFalse("$n $it", it in cc) }
            assertTrue(n, CalendrierJuif.C.LAMNATSEAH in cc)
            assertTrue(n, "ajout_sans_tahanoun_ponctuel" in JourAffiche.ajouts(jour, n))
        }
        assertTrue(CalendrierJuif.C.TAHANOUN_CHAHARIT in SiddurJour.conditionsPour("sefard", false, SiddurJour.avecSansTahanoun(c("2025-11-17"), false)))
        assertTrue("ajout_vidoui_erev_kippour" in JourAffiche.ajouts(c("2025-10-01"), "ashkenaz"))
        assertTrue("ajout_sans_tahanoun_pessah_cheni" in JourAffiche.ajouts(c("2026-05-01"), "ashkenaz"))
    }

    /**
     * Audit du 16/11 : Tikoun 'hatsot. Tikoun Ra'hel replié à Roch 'Hodech, de Roch Hachana à Chemini
     * Atseret, en Nissan, pendant l'omer (Kitsour Yalkut Yosef, דיני תיקון חצות §נה) ; Tikoun Léa la nuit
     * du 9 Av (§נו) ; יענך et עד אנה les jours sans Ta'hanoun (consigne du siddour). Les trois noussa'h.
     */
    @Test
    fun `audit du 16-11, Tikoun hatsot selon le jour`() {
        fun lignes(iso: String, n: Nusah): List<SiddurJour.Ligne> {
            val texte = DataFiles.siddur(n).texte("tikoun_hatsot")!!
            val a = SiddurJour.parse(json, n.cle).getValue("tikoun_hatsot")
            val c = CalendrierJuif.jour(java.time.LocalDate.parse(iso), false).conditions
            return SiddurJour.lignes(texte, a, c, nusah = n.cle)
        }
        // 26/11 : ce qui ne se dit pas est retiré, sans repli ; ce qui se dit, en clair (discret).
        fun absents(iso: String, n: Nusah): Set<String> {
            val texte = DataFiles.siddur(n).texte("tikoun_hatsot")!!
            val vus = lignes(iso, n).filterIsInstance<SiddurJour.Ligne.Bloc>().map { it.origine }.toSet()
            assertTrue(lignes(iso, n).none { it is SiddurJour.Ligne.Replie })
            return buildSet {
                if (texte.sections[1].blocs.none { it in vus }) add("rahel")
                if (texte.sections[2].blocs.withIndex().none { (k, b) -> k !in setOf(2, 3, 8, 9, 10) && b in vus }) add("lea")
                if (listOf(2, 3, 8, 9, 10).none { texte.sections[2].blocs[it] in vus }) add("tahanoun")
            }
        }
        Nusah.entries.forEach { n ->
            assertEquals(n.cle, emptySet<String>(), absents("2026-11-19", n))
            assertEquals(n.cle, setOf("rahel", "tahanoun"), absents("2027-03-09", n)) // Roch 'Hodech
            assertEquals(n.cle, setOf("rahel", "tahanoun"), absents("2026-04-08", n)) // Nissan
            assertEquals(n.cle, setOf("rahel"), absents("2026-09-15", n)) // dix jours de pénitence
            assertEquals(n.cle, setOf("rahel"), absents("2027-05-12", n)) // omer, avec Ta'hanoun
            assertEquals(n.cle, setOf("lea", "tahanoun"), absents("2026-07-23", n)) // 9 Av : Tikoun Ra'hel seul
        }
        // Les indications fixes (YY §נא et §נח), en Edot seulement, sans « Aujourd'hui ».
        val fixes = lignes("2026-11-19", Nusah.EDOT).filterIsInstance<SiddurJour.Ligne.Indice>()
        assertEquals(2, fixes.size)
        assertTrue(fixes.all { it.fixe })
        assertTrue(lignes("2026-11-19", Nusah.ASHKENAZ).none { it is SiddurJour.Ligne.Indice })
        // Le jour hébreu de la nuit : avant minuit, le lendemain.
        assertEquals(java.time.LocalDate.parse("2026-11-21"),
            CalendrierJuif.jourDeLaPriere("tikoun_hatsot", java.time.LocalDate.parse("2026-11-20"), java.time.LocalTime.of(23, 50)))
        assertEquals(java.time.LocalDate.parse("2026-07-05"),
            CalendrierJuif.jourDeLaPriere("tikoun_hatsot", java.time.LocalDate.parse("2026-07-05"), java.time.LocalTime.of(12, 50)))
    }

    /** Audit du 16/11 : le Chema du coucher Sfard signale l'usage 'Habad, sans rien replier. */
    @Test
    fun `audit du 16-11, Chema du coucher Sfard, usage Habad`() {
        val texte = DataFiles.siddur(Nusah.SEFARD).texte("chema_coucher")!!
        val a = SiddurJour.parse(json, "sefard").getValue("chema_coucher")
        val c = CalendrierJuif.jour(java.time.LocalDate.parse("2026-11-19"), false).conditions
        val l = SiddurJour.lignes(texte, a, c, nusah = "sefard")
        // Avec le repère « המפיל après l'aube » de l'audit des offices (Biour Halakha 239), qui n'est pas fixe.
        assertEquals(2, l.filterIsInstance<SiddurJour.Ligne.Indice>().size)
        val ind = l.filterIsInstance<SiddurJour.Ligne.Indice>().filter { it.fixe }
        assertEquals(1, ind.size)
        assertTrue(ind.single().fixe && ind.single().texte.contains("חב״ד"))
        // Seul repli : « יחיד אומר: אל מלך נאמן », sous « Sans minyan » (26/11, Q4).
        assertEquals(listOf(SiddurJour.SANS_MINYAN), l.filterIsInstance<SiddurJour.Ligne.Replie>().map { it.condition })
    }

    /**
     * Un repli ouvert dans un groupe replié qu'on a ouvert (double annotation, audit du 16/11) : le pied
     * « Replier » du groupe vient après tous ses membres, repli imbriqué compris. Sfard, Cha'harit d'un mercredi
     * de Ta'hanoun : la maison endeuillée (occasion, repliée), son psaume 49 et son Kaddich sous le minyan ; le
     * psaume 16 des jours sans Ta'hanoun n'y est pas (26/11, Q11).
     */
    @Test
    fun `un repli ouvert dans un groupe ouvert - le panneau du groupe va jusqu a son dernier membre`() {
        val texte = DataFiles.siddur(Nusah.SEFARD).texte("chaharit")!!
        val a = SiddurJour.parse(json, "sefard").getValue("chaharit")
        val c = CalendrierJuif.jour(java.time.LocalDate.parse("2026-11-18"), false).conditions
        val ferme = SiddurJour.lignes(texte, a, c, nusah = "sefard")
        val groupe = ferme.filterIsInstance<SiddurJour.Ligne.Replie>().single { it.condition == CalendrierJuif.C.BEIT_AVEL }.cle
        val un = SiddurJour.lignes(texte, a, c, setOf(groupe), nusah = "sefard")
        val minyan = un.filterIsInstance<SiddurJour.Ligne.Replie>().single { it.cle.startsWith("$groupe:") }.cle
        val l = SiddurJour.lignes(texte, a, c, setOf(groupe, minyan), nusah = "sefard")
        val si = texte.sections.indexOfFirst { s -> s.blocs.any { SiddurJour.empreinte(it.texte).startsWith("בבית האבל") } }
        val b0 = texte.sections[si].blocs.indexOfFirst { SiddurJour.empreinte(it.texte).startsWith("בבית האבל") }
        val bloc = { bi: Int -> l.indexOfFirst { it is SiddurJour.Ligne.Bloc && it.origine === texte.sections[si].blocs[b0 + bi] } }
        val debut = l.indexOfFirst { it is SiddurJour.Ligne.Replie && it.cle == groupe }
        val fin = l.indexOf(SiddurJour.Ligne.Fin(groupe))
        val debutMinyan = l.indexOfFirst { it is SiddurJour.Ligne.Replie && it.cle == minyan }
        val finMinyan = l.indexOf(SiddurJour.Ligne.Fin(minyan))
        // Dans l'ordre : le groupe, la consigne et le psaume 49, le repli du minyan, le Kaddich, sa fin, la fin du groupe.
        assertTrue(debut < bloc(0) && bloc(0) < bloc(1) && bloc(1) < debutMinyan && debutMinyan < bloc(5) && bloc(5) < finMinyan && finMinyan < fin)
        // Le psaume 16 (« ובימים שאין בהם תחנון ») n'est pas du jour : absent du groupe déplié.
        assertEquals(-1, bloc(3))
        assertEquals(-1, bloc(4))
        val panneau = SiddurJour.panneaux(l)
        listOf(0, 1, 2, 5, 9).forEach { assertTrue("$it", bloc(it) in panneau) }
        assertFalse(debut in panneau || fin in panneau)
        // Sans repli ouvert, pas de fin ni de panneau.
        assertTrue(ferme.none { it is SiddurJour.Ligne.Fin } && SiddurJour.panneaux(ferme).isEmpty())
    }
}
