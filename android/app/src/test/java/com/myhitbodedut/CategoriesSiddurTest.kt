package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate
import java.time.LocalTime

/**
 * Les ajouts du siddour en deux catégories (demande du 26/11 et réponses Q1-Q15 du propriétaire) : un ajout du
 * calendrier ne s'affiche que le jour où il se dit, retiré sans bandeau les autres jours ; un ajout d'occasion reste
 * replié mais visible. Les mêmes cas côté web : web/test/categories.test.mjs.
 */
class CategoriesSiddurTest {

    private val json = File("src/main/res/raw/siddur_annotations.json").readText()
    private val C = CalendrierJuif.C

    private fun c(iso: String, israel: Boolean = false) = CalendrierJuif.jour(LocalDate.parse(iso), israel).conditions

    private fun lignes(
        n: Nusah, id: String, conditions: Set<String>, ouverts: Set<String> = emptySet(), israel: Boolean = false,
        voisin: Set<String> = emptySet(),
    ) = SiddurJour.lignes(DataFiles.siddur(n).texte(id)!!, SiddurJour.parse(json, n.cle).getValue(id), conditions, ouverts,
        n.cle, israel, voisin = voisin)

    /** Tous les replis ouverts, jusqu'aux replis imbriqués. */
    private fun tout(n: Nusah, id: String, conditions: Set<String>, israel: Boolean = false, voisin: Set<String> = emptySet()): List<SiddurJour.Ligne> {
        var cles = emptySet<String>()
        while (true) {
            val l = lignes(n, id, conditions, cles, israel, voisin)
            val plus = cles + l.filterIsInstance<SiddurJour.Ligne.Replie>().map { it.cle }
            if (plus == cles) return l
            cles = plus
        }
    }

    private fun plat(t: String) = t.replace(Regex("<[^>]+>"), "").replace(Regex("[\\u0591-\\u05C7\\s״׳\"'()]"), "")
    private fun clair(l: List<SiddurJour.Ligne>) = l.filterIsInstance<SiddurJour.Ligne.Bloc>().filter { it.style != SiddurJour.Style.HORS }.map { plat(it.bloc.texte) }
    private fun blocs(l: List<SiddurJour.Ligne>) = l.filterIsInstance<SiddurJour.Ligne.Bloc>().map { plat(it.bloc.texte) }
    private fun a(l: List<String>, p: String) = l.any { plat(p) in it }
    private fun replis(l: List<SiddurJour.Ligne>) = l.filterIsInstance<SiddurJour.Ligne.Replie>()

    /** Un jour de semaine : aucun ajout du calendrier, ni en clair ni replié ; les occasions, repliées. */
    @Test
    fun `semaine - le birkat sans ajout du jour, les occasions repliees`() {
        Nusah.entries.forEach { n ->
            val l = lignes(n, "birkat_hamazon", c("2026-11-17"))
            val t = blocs(tout(n, "birkat_hamazon", c("2026-11-17")))
            assertFalse(n.cle, a(t, "רצה והחליצנו"))
            assertFalse(n.cle, a(t, "יעלה ויבא"))
            assertFalse(n.cle, a(t, "על הנסים"))
            // Les consignes d'oubli (Q5) : pas de Retsé ni de Ya'alé ce jour-là, retirées.
            assertTrue(n.cle, replis(l).none { it.condition == C.OUBLI })
            // Le zimoun, les Chéva bérakhot, les הרחמן de la table : repliés, « toucher pour lire ».
            assertTrue(n.cle, replis(l).any { it.condition == C.ZIMUN && !it.pasAujourdhui })
            assertTrue(n.cle, replis(l).all { it.condition in SiddurJour.OCCASIONS && !it.pasAujourdhui })
        }
    }

    /** Chabbat : Retsé en évidence ; les bénédictions de qui a oublié, repliées, avec les seules lignes du Chabbat (Q11). */
    @Test
    fun `chabbat - retse en evidence, l oubli replie avec ses lignes du jour`() {
        val chabbat = c("2026-11-21")
        Nusah.entries.forEach { n ->
            val l = lignes(n, "birkat_hamazon", chabbat)
            assertTrue(n.cle, SiddurJour.Ligne.Etiquette(C.CHABBAT, "ajout_chabbat") in l)
            assertTrue(n.cle, a(clair(l), "רצה והחליצנו"))
            assertTrue(n.cle, replis(l).any { it.condition == C.OUBLI })
        }
        listOf(Nusah.SEFARD, Nusah.ASHKENAZ).forEach { n ->
            val t = blocs(tout(n, "birkat_hamazon", chabbat))
            assertTrue(n.cle, a(t, "אשר נתן שבתות למנוחה"))
            assertFalse(n.cle, a(t, "אשר נתן ראשי חדשים"))
        }
        val e = blocs(tout(Nusah.EDOT, "birkat_hamazon", chabbat))
        assertTrue(a(e, "לשבת שבתות למנוחה") && !a(e, "לראש חודש (ו)ראשי חדשים"))
    }

    /** Roch 'Hodech : Ya'alé véyavo avec sa ligne ; « מגדול » seul (Sfard, Ashkenaz) ; le renvoi au Moussaf. */
    @Test
    fun `roch hodech - yaale veyavo, migdol, moussaf`() {
        val rh = c("2026-10-12")
        Nusah.entries.forEach { n ->
            val l = lignes(n, "birkat_hamazon", rh)
            assertTrue(n.cle, SiddurJour.Ligne.Etiquette(C.YAALE_VEYAVO, "ajout_yaale_veyavo") in l)
            assertFalse(n.cle, a(blocs(l), "חג המצות הזה"))
            assertTrue(n.cle, lignes(n, "chaharit", rh).any { it is SiddurJour.Ligne.Renvoi && it.cible == "moussaf_rosh_hodech" })
        }
    }

    /** 'Hanouka et Pourim : Al hanissim avec la seule ligne du jour. */
    @Test
    fun `hanouka et pourim - al hanissim avec la ligne du jour`() {
        Nusah.entries.forEach { n ->
            val h = clair(lignes(n, "chaharit", c("2026-12-07")))
            assertTrue(n.cle, a(h, "בימי מתתיה"))
            assertFalse(n.cle, a(h, "בימי מרדכי ואסתר"))
            val p = clair(lignes(n, "minha", c("2027-03-23")))
            assertTrue(n.cle, a(p, "בימי מרדכי ואסתר"))
            assertFalse(n.cle, a(p, "בימי מתתיה"))
            assertFalse(n.cle, a(clair(lignes(n, "minha", c("2026-11-17"))), "על הנסים"))
        }
    }

    /** Un jeûne public (10 Tévèt) : Anénou du particulier en clair, celui de l'officiant sous « Avec minyan » (Q2). */
    @Test
    fun `jeune public - anenou, avinou malkenou`() {
        val jeune = c("2026-12-20")
        Nusah.entries.forEach { n ->
            val l = lignes(n, "minha", jeune)
            assertTrue(n.cle, l.any { it is SiddurJour.Ligne.Etiquette && it.libelle == "ajout_anenou_particulier" })
            assertTrue(n.cle, l.none { it is SiddurJour.Ligne.Replie && it.libelle == "ajout_jeune_individuel" })
        }
        listOf(Nusah.SEFARD, Nusah.ASHKENAZ).forEach { n ->
            assertTrue(n.cle, lignes(n, "chaharit", jeune).any { it is SiddurJour.Ligne.Etiquette && it.condition == C.AVINOU_MALKENOU })
        }
    }

    /** Les dix jours : « המלך הקדוש » seul, « עושה השלום » et « לעילא ולעילא » dans le Kaddich (Q8). */
    @Test
    fun `dix jours - la seule formule du jour, kaddich compris`() {
        val dix = c("2027-10-05")
        val ordinaire = c("2026-11-17")
        listOf(Nusah.SEFARD, Nusah.ASHKENAZ, Nusah.EDOT).forEach { n ->
            val t = blocs(tout(n, "chaharit", dix))
            // Le Nom s'écrit autrement dans l'Amida Sfard (« יֹהֵוָהֵ ») : on le saute.
            val sceau = { f: String -> t.any { Regex("ברוךאתה[^,:]{4,12},?$f:?$").containsMatchIn(it) } }
            assertTrue(n.cle, sceau("המלךהקדוש"))
            assertFalse(n.cle, sceau("האלהקדוש"))
            val o = blocs(tout(n, "chaharit", ordinaire))
            assertFalse(n.cle, a(o, "המלך הקדוש"))
        }
        // Le Kaddich d'un ajout (la maison endeuillée, Sfard) : la variante des dix jours, oubliée jusqu'ici.
        val sfard = blocs(tout(Nusah.SEFARD, "chaharit", dix))
        assertTrue(a(sfard, "לעלא ולעלא מכל"))
        assertFalse(a(sfard, "לעלא מן כל"))
        assertTrue(a(blocs(tout(Nusah.SEFARD, "chaharit", ordinaire)), "לעלא מן כל"))
        assertTrue(a(blocs(tout(Nusah.ASHKENAZ, "chaharit", dix)), "לעלא לעלא מכל"))
        assertTrue(a(blocs(tout(Nusah.ASHKENAZ, "chaharit", dix)), "עושה השלום במרומיו"))
    }

    /** Eloul : Ledavid dès le 30 Av (Q13) ; hors d'Eloul, retiré en Sfard et en Ashkenaz, replié en Edot (Q10). */
    @Test
    fun `eloul - ledavid des le 30 av, replie en edot hors d eloul`() {
        assertTrue(C.LEDAVID in c("2026-08-13")) // 30 Av, premier jour de Roch 'Hodech Eloul
        assertFalse(C.LEDAVID in c("2026-08-12"))
        Nusah.entries.forEach { n ->
            assertTrue(n.cle, a(clair(lignes(n, "chaharit", c("2026-08-13"))), "יהוה אורי וישעי"))
        }
        listOf(Nusah.SEFARD, Nusah.ASHKENAZ).forEach { n ->
            assertFalse(n.cle, a(blocs(tout(n, "chaharit", c("2026-11-17"))), "יהוה אורי וישעי"))
        }
        val edot = lignes(Nusah.EDOT, "chaharit", c("2026-11-17"))
        assertTrue(replis(edot).any { it.condition == C.LEDAVID && it.pasAujourdhui })
        assertTrue(a(blocs(tout(Nusah.EDOT, "chaharit", c("2026-11-17"))), "יהוה אורי וישעי"))
    }

    /** Le soir (Q6) : le jour voisin, et ses ajouts gardés repliés au lieu d'être retirés. */
    @Test
    fun `vendredi soir - retse replie entre coucher et sortie, le soir qui suit aussi`() {
        val d = LocalDate.parse("2026-11-20") // vendredi
        assertEquals(d.plusDays(1), CalendrierJuif.jourVoisin("birkat_hamazon", d, LocalTime.of(16, 30), true, false))
        assertEquals(d, CalendrierJuif.jourVoisin("birkat_hamazon", d, LocalTime.of(18, 30), true, true))
        assertEquals(d.plusDays(1), CalendrierJuif.jourVoisin("meen_chaloch", d, LocalTime.of(17, 0), null, null))
        assertNull(CalendrierJuif.jourVoisin("birkat_hamazon", d, LocalTime.of(15, 59), null, null))
        assertNull(CalendrierJuif.jourVoisin("birkat_hamazon", d, LocalTime.of(14, 0), false, false))
        assertNull(CalendrierJuif.jourVoisin("chaharit", d, LocalTime.of(17, 0), true, false))
        val vendredi = c("2026-11-20")
        val samedi = c("2026-11-21")
        Nusah.entries.forEach { n ->
            val sans = lignes(n, "birkat_hamazon", vendredi)
            assertTrue(n.cle, replis(sans).none { it.condition == C.CHABBAT })
            val avec = lignes(n, "birkat_hamazon", vendredi, voisin = samedi)
            assertTrue(n.cle, replis(avec).any { it.condition == C.CHABBAT && it.pasAujourdhui })
            assertTrue(n.cle, replis(avec).any { it.condition == C.OUBLI })
            assertFalse(n.cle, a(clair(avec), "רצה והחליצנו"))
            // Méèn chaloch aussi.
            assertTrue(n.cle, replis(lignes(n, "meen_chaloch", vendredi, voisin = samedi)).any { it.condition == C.CHABBAT })
        }
        // Le samedi soir, après la sortie des étoiles : le dimanche, avec le Chabbat qui finit pour voisin.
        Nusah.entries.forEach { n ->
            assertTrue(n.cle, replis(lignes(n, "birkat_hamazon", c("2026-11-22"), voisin = samedi)).any { it.condition == C.CHABBAT && it.pasAujourdhui })
        }
    }

    /** Israël ou diaspora non confirmé (Q7) : la question n'a lieu d'être que si le texte en dépend ce jour-là. */
    @Test
    fun `israel ou diaspora - le texte en depend-il aujourd hui`() {
        fun depend(n: Nusah, id: String, iso: String) = SiddurJour.dependDeLaRegion(DataFiles.siddur(n).texte(id)!!,
            SiddurJour.parse(json, n.cle).getValue(id), c(iso, true), c(iso, false), n.cle)
        // Le 22 Nissan 5787 : Isrou 'hag en Israël, 8ᵉ jour de Pessa'h en diaspora.
        Nusah.entries.forEach { n -> assertTrue(n.cle, depend(n, "chaharit", "2027-04-29")) }
        // Un mardi ordinaire d'hiver après le 4 décembre : rien ne diffère.
        Nusah.entries.forEach { n -> assertFalse(n.cle, depend(n, "chaharit", "2027-01-19")) }
        // Entre le 7 'Hechvan et le 4 décembre, « ותן טל ומטר » diffère.
        Nusah.entries.forEach { n -> assertTrue(n.cle, depend(n, "chaharit", "2026-11-17")) }
        // L'Ashkenaz ne dit pas מוריד הטל hors d'Israël : l'été, la question se pose ; pas en Sfard.
        assertTrue(depend(Nusah.ASHKENAZ, "minha", "2027-06-01"))
        assertFalse(depend(Nusah.SEFARD, "minha", "2027-06-01"))
    }

    /** L'omer du soir (Q12) : le seul compte du soir ; hors de l'omer, la section d'Arvit et son titre retirés. */
    @Test
    fun `omer - le compte du soir seulement`() {
        val soir = CalendrierJuif.jourDeLaPriere("sefirat_haomer", LocalDate.parse("2027-04-29"), LocalTime.of(21, 0))
        assertEquals(LocalDate.parse("2027-04-30"), soir)
        val jour8 = c(soir.toString())
        assertTrue("omer_8" in jour8)
        listOf(Nusah.SEFARD, Nusah.ASHKENAZ).forEach { n ->
            val l = clair(lignes(n, "arvit", jour8))
            assertTrue(n.cle, l.any { "8.היום" in it })
            assertFalse(n.cle, l.any { "7.היום" in it || "9.היום" in it })
            val page = clair(lignes(n, "sefirat_haomer", jour8))
            assertEquals(n.cle, 1, page.count { Regex("^\\S+(ניסן|אייר|סיון)\\d+\\.").containsMatchIn(it) })
            // Hors de l'omer : ni compte ni titre de section à Arvit ; la page garde les 49 jours repliés.
            val hors = lignes(n, "arvit", c("2026-11-18"))
            assertTrue(n.cle, hors.none { it is SiddurJour.Ligne.Titre && plat(it.texte) == plat("ספירת העומר") })
            assertTrue(n.cle, replis(lignes(n, "sefirat_haomer", c("2026-11-18"))).single().pasAujourdhui)
            assertEquals(n.cle, 49, blocs(tout(n, "sefirat_haomer", c("2026-11-18"))).count { Regex("^\\S+(ניסן|אייר|סיון)\\d+\\.").containsMatchIn(it) })
        }
        // Edot : la date, le compte et la séfira du soir.
        val edot = clair(lignes(Nusah.EDOT, "sefirat_haomer", jour8))
        assertTrue(a(edot, "שמונה ימים לעמר"))
        assertFalse(a(edot, "שבעה ימים לעמר"))
    }

    /** Pas de Ta'hanoun aujourd'hui (Q1) : le Ta'hanoun et les ajouts du lundi et du jeudi retirés, למנצח reste. */
    @Test
    fun `pas de tahanoun aujourd hui - retire le tahanoun seul`() {
        val lundi = c("2026-11-16")
        val sans = SiddurJour.avecSansTahanoun(lundi, true)
        Nusah.entries.forEach { n ->
            assertTrue(n.cle, a(clair(lignes(n, "chaharit", lundi)), "שומר ישראל") || n == Nusah.EDOT)
            val l = clair(lignes(n, "chaharit", sans))
            assertFalse(n.cle, a(l, "ויאמר דוד אל גד"))
            assertFalse(n.cle, a(l, "אנשי אמונה אבדו"))
            assertTrue(n.cle, a(l, "יענך יהוה ביום צרה"))
        }
        // La section « תחנון » de Sfard, retirée avec son titre.
        assertTrue(lignes(Nusah.SEFARD, "chaharit", sans).none { it is SiddurJour.Ligne.Titre && plat(it.texte) == plat("תחנון") })
    }

    /** Le voyageur (Q3) : replié du 7 'Hechvan au 4 décembre, retiré le reste de l'année. */
    @Test
    fun `voyageur - replie seulement quand israel et la diaspora different`() {
        assertTrue(C.VOYAGEUR_TAL_OUMATAR in c("2026-11-17"))
        assertFalse(C.VOYAGEUR_TAL_OUMATAR in c("2027-01-19") || C.VOYAGEUR_TAL_OUMATAR in c("2027-06-01"))
        listOf(Nusah.EDOT, Nusah.ASHKENAZ).forEach { n ->
            assertTrue(n.cle, replis(lignes(n, "chaharit", c("2026-11-17"))).any { it.libelle == "ajout_voyageur_tal_oumatar" })
            assertTrue(n.cle, replis(lignes(n, "chaharit", c("2027-01-19"))).none { it.libelle == "ajout_voyageur_tal_oumatar" })
        }
    }

    /** Les consignes d'oubli (Q5) : l'hiver, celle de « משיב הרוח », repliée ; l'été, retirée. */
    @Test
    fun `oubli - replie le jour ou l ajout se dit`() {
        fun oubli(n: Nusah, iso: String) = tout(n, "chaharit", c(iso)).filterIsInstance<SiddurJour.Ligne.Bloc>()
            .any { it.bloc.consigne && "משיבהרוח" in plat(it.bloc.texte) && ("טעה" in plat(it.bloc.texte)) }
        Nusah.entries.forEach { n ->
            assertTrue(n.cle, oubli(n, "2027-01-19"))
            assertFalse(n.cle, oubli(n, "2027-06-01"))
        }
    }

    /** Les usages datés (Q14) : Barekhi nafchi à Arvit (Edot), replié le soir de Roch 'Hodech, retiré les autres. */
    @Test
    fun `usage date - replie le jour dit, retire les autres`() {
        assertTrue(replis(lignes(Nusah.EDOT, "arvit", c("2026-10-12"))).any { it.libelle == "ajout_roch_hodech_usage" })
        assertTrue(replis(lignes(Nusah.EDOT, "arvit", c("2026-11-18"))).none { it.libelle == "ajout_roch_hodech_usage" })
        // Le psaume 121 d'Arvit (Sfard) : en Israël seulement, replié.
        assertTrue(replis(lignes(Nusah.SEFARD, "arvit", c("2026-11-18", true), israel = true)).any { it.libelle == "ajout_israel_usage" })
        assertTrue(replis(lignes(Nusah.SEFARD, "arvit", c("2026-11-18"))).none { it.libelle == "ajout_israel_usage" })
    }

    /** Qui prie seul (Q4) : « יחיד אומר » et la braïta repliés sous « Sans minyan ». */
    @Test
    fun `sans minyan - replie`() {
        listOf(Nusah.SEFARD, Nusah.ASHKENAZ).forEach { n ->
            val l = lignes(n, "chaharit", c("2026-11-17"))
            assertTrue(n.cle, replis(l).any { it.condition == SiddurJour.SANS_MINYAN && it.libelle == "ajout_sans_minyan" })
            assertTrue(n.cle, l.none { it is SiddurJour.Ligne.Seul })
            assertFalse(n.cle, a(clair(l), "אל מלך נאמן"))
        }
    }

    /** Les formes de l'homme et de la femme (Q12) : selon צדיק / צדקת ; sans réglage, les deux. */
    @Test
    fun `homme et femme - la seule forme du reglage`() {
        val jour = c("2026-11-17")
        listOf(Nusah.SEFARD, Nusah.ASHKENAZ, Nusah.EDOT).forEach { n ->
            val femme = clair(lignes(n, "birkot_hachahar", SiddurJour.avecAdresse(jour, "f")))
            val homme = clair(lignes(n, "birkot_hachahar", SiddurJour.avecAdresse(jour, "m")))
            val aucun = clair(lignes(n, "birkot_hachahar", jour))
            assertTrue(n.cle, a(femme, "שעשני כרצונו") && !a(femme, "שלא עשני אשה"))
            assertTrue(n.cle, a(homme, "שלא עשני אשה") && !a(homme, "שעשני כרצונו"))
            assertTrue(n.cle, a(aucun, "שלא עשני אשה") && a(aucun, "שעשני כרצונו"))
        }
        val e = clair(lignes(Nusah.EDOT, "birkot_hachahar", SiddurJour.avecAdresse(jour, "f")))
        assertTrue(e.filter { "עשני" in it }.toString(), a(e, "שלא עשני גויה"))
        assertFalse(e.filter { "האשה" in it }.toString(), a(e, "האשה אומרת"))
    }

    /** Les textes d'occasion ajoutés (Q15) : repliés, chaque jour, à leur place. */
    @Test
    fun `occasions ajoutees - brit mila, maison endeuillee, mi cheberakh`() {
        val jour = c("2026-11-16") // lundi, jour de lecture
        listOf(Nusah.SEFARD, Nusah.ASHKENAZ).forEach { n ->
            assertTrue(n.cle, replis(lignes(n, "birkat_hamazon", jour)).any { it.libelle == "ajout_brit_mila" })
            val l = lignes(n, "chaharit", jour)
            listOf("ajout_mi_cheberakh_oleh", "ajout_mi_cheberakh_malade", "ajout_mi_cheberakh_yoledet", "ajout_hagomel")
                .forEach { lib -> assertTrue("${n.cle} $lib", replis(l).any { it.libelle == lib }) }
            // Dans le Mi chébérakh de l'oleh, en semaine, pas « ולכבוד השבת » (Q11).
            val oleh = blocs(tout(n, "chaharit", jour)).first { "בעבורשעלהלתורה" in it }
            assertFalse(n.cle, "ולכבודהשבת" in oleh)
        }
        val avel = replis(lignes(Nusah.EDOT, "birkat_hamazon", jour)).filter { it.condition == C.BEIT_AVEL }
        assertEquals(3, avel.size)
        assertTrue(a(blocs(tout(Nusah.EDOT, "birkat_hamazon", jour)), "מנחם אבלים שאכלנו משלו"))
    }

    /** Ce qui se dit tous les jours n'est jamais retiré : la simulation le vérifie jour par jour (SimulationSiddurTest). */
    @Test
    fun `les occasions ne sont jamais vraies, les categories sont celles du generateur`() {
        val outil = File("../../tools/siddur_annotations.py").readText()
        SiddurJour.OCCASIONS.forEach { assertTrue(it, "\"$it\"" in outil || it in setOf("usage", "occasion", "sans_minyan")) }
        val semaine = c("2026-11-17")
        SiddurJour.OCCASIONS.forEach { assertFalse(it, it in SiddurJour.conditionsPour("edot", false, semaine)) }
        assertTrue("\"regle\"" in json && "retiré" in json.substringAfter("\"regle\"").substringBefore("\n"))
    }
}
