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
 * Audit du 16/11, structure des offices (Cha'harit, Min'ha, Arvit, Chema du coucher) : les mêmes cas
 * que web/test/offices.test.mjs. Chaque cas échouait avant la correction.
 */
class StructureOfficesTest {

    private val json = File("src/main/res/raw/siddur_annotations.json").readText()
    private val C = CalendrierJuif.C

    private fun conditions(nusah: String, iso: String, israel: Boolean = false) =
        SiddurJour.conditionsPour(nusah, israel, CalendrierJuif.jour(LocalDate.parse(iso), israel).conditions)

    private fun nu(s: String) =
        s.replace(Regex("<[^>]+>"), " ").replace(Regex("[\\u0591-\\u05C7]"), "").replace(Regex("\\s+"), " ").trim()

    /** « du_jour », « ordinaire » (en clair, sans mise en évidence) ou « replie » : les blocs qui répondent à [motif]. */
    private fun etats(nusah: String, id: String, iso: String, motif: Regex, israel: Boolean = false): Set<String> {
        val n = Nusah.entries.first { it.cle == nusah }
        val texte = DataFiles.siddur(n).texte(id)!!
        val jour = CalendrierJuif.jour(LocalDate.parse(iso), israel).conditions
        val lignes = SiddurJour.lignes(texte, SiddurJour.parse(json, nusah).getValue(id), jour, nusah = nusah, enIsrael = israel)
        val vus = lignes.filterIsInstance<SiddurJour.Ligne.Bloc>().filter { motif.containsMatchIn(nu(it.origine.texte)) }
            .map { when (it.style) { SiddurJour.Style.DU_JOUR -> "du_jour"; SiddurJour.Style.HORS -> "hors"; else -> "ordinaire" } }.toSet()
        val tous = texte.sections.flatMap { it.blocs }.count { motif.containsMatchIn(nu(it.texte)) }
        return if (vus.isEmpty() && tous > 0) setOf("replie") else vus
    }

    private fun indices(nusah: String, id: String, iso: String, israel: Boolean = false): List<String> {
        val n = Nusah.entries.first { it.cle == nusah }
        val texte = DataFiles.siddur(n).texte(id)!!
        val jour = CalendrierJuif.jour(LocalDate.parse(iso), israel).conditions
        return SiddurJour.lignes(texte, SiddurJour.parse(json, nusah).getValue(id), jour, nusah = nusah, enIsrael = israel)
            .filterIsInstance<SiddurJour.Ligne.Indice>().map { it.texte }
    }

    private val ichev = Regex("^ישב( \\(תהלים צא\\))? בסתר")

    @Test
    fun `mizmor letoda replie le chabbat a pessah et les veilles de pessah et de kippour`() {
        listOf("sefard", "ashkenaz").forEach { n ->
            assertEquals(n, setOf("ordinaire"), etats(n, "chaharit", "2026-11-18", Regex("^מזמור לתודה")))
            listOf("2026-04-01", "2026-04-05", "2026-09-20", "2026-11-21").forEach {
                assertEquals("$n $it", setOf("replie"), etats(n, "chaharit", it, Regex("^מזמור לתודה")))
            }
        }
        assertTrue(C.MIZMOR_LETODA in conditions("ashkenaz", "2025-10-09"))
    }

    @Test
    fun `edot sheassa li - la benediction en clair le 9 av selon le yalkut yosef`() {
        assertEquals(setOf("ordinaire"), etats("edot", "birkot_hachahar", "2026-07-23", Regex("^ברוך.*שעשה לי")))
        assertEquals(setOf("du_jour"), etats("edot", "birkot_hachahar", "2026-07-23", Regex("^בתשעה באב ויום")))
        assertEquals(setOf("replie"), etats("edot", "birkot_hachahar", "2026-11-18", Regex("^בתשעה באב ויום")))
        // Sfard : la consigne de son siddour.
        assertEquals(setOf("replie"), etats("sefard", "chaharit", "2026-09-21", Regex("^ברוך.*שעשה לי")))
        assertEquals(setOf("ordinaire"), etats("sefard", "chaharit", "2026-11-18", Regex("^ברוך.*שעשה לי")))
    }

    @Test
    fun `motsae chabbat - vihi noam replie avant un yom tov dans la semaine sauf en edot`() {
        listOf("sefard", "ashkenaz", "edot").forEach { n ->
            assertEquals(n, setOf("du_jour"), etats(n, "arvit", "2026-11-15", ichev))
            listOf("2025-09-21", "2026-04-05").forEach {
                val attendu = if (n == "edot") "du_jour" else "replie"
                assertEquals("$n $it", setOf(attendu), etats(n, "arvit", it, ichev))
                assertEquals("$n $it", setOf(attendu), etats(n, "arvit", it, Regex("^ואתה קדוש")))
            }
            // Le Séder un samedi soir (2025-04-12) : ni ויהי נועם ni אתה חוננתנו.
            assertEquals(n, setOf("replie"), etats(n, "arvit", "2025-04-13", ichev))
        }
        assertFalse(C.MOTSAE_CHABBAT_YT in CalendrierJuif.jour(LocalDate.parse("2025-04-13"), false).conditions)
    }

    @Test
    fun `soir du 9 av - veata kadoch sans vihi noam`() {
        listOf("sefard", "ashkenaz", "edot").forEach { n ->
            listOf("2025-08-03", "2026-07-23").forEach {
                assertEquals("$n $it", setOf("replie"), etats(n, "arvit", it, ichev))
                assertEquals("$n $it", setOf("du_jour"), etats(n, "arvit", it, Regex("^ואתה קדוש")))
            }
        }
        // Sfard : « תתקבל » estompé ce soir-là.
        // (Depuis la double annotation, ce Kaddich est aussi replié sous le minyan.)
        assertTrue(SiddurJour.parse(json, "sefard").getValue("arvit")
            .any { it.condition == "!ticha_beav" && it.racine == C.VEATA_KADOCH && it.et == C.MINYAN })
    }

    @Test
    fun `motsae chabbat sfard - alenou une seule fois`() {
        listOf("2026-11-15", "2026-11-18", "2025-09-21").forEach {
            val texte = DataFiles.siddur(Nusah.entries.first { n -> n.cle == "sefard" }).texte("arvit")!!
            val lignes = SiddurJour.lignes(texte, SiddurJour.parse(json, "sefard").getValue("arvit"),
                CalendrierJuif.jour(LocalDate.parse(it), false).conditions, nusah = "sefard")
            assertEquals(it, 1, lignes.filterIsInstance<SiddurJour.Ligne.Bloc>().count { b -> nu(b.origine.texte).startsWith("עלינו לשבח") })
        }
    }

    @Test
    fun `tefilin - hol hamoed, israel, ashkenaz sans berakha, 9 av`() {
        val tef = Regex("להניח תפלין")
        assertEquals(setOf("ordinaire"), etats("edot", "chaharit", "2026-11-18", tef))
        listOf("2025-10-09" to false, "2025-10-09" to true, "2026-04-09" to false, "2026-11-21" to false).forEach { (iso, il) ->
            assertEquals("$iso $il", setOf("replie"), etats("edot", "chaharit", iso, tef, il))
        }
        assertEquals(setOf("ordinaire"), etats("edot", "chaharit", "2026-07-23", tef))
        assertEquals(setOf("ordinaire"), etats("ashkenaz", "chaharit", "2025-10-09", tef))
        assertTrue(indices("ashkenaz", "chaharit", "2025-10-09").any { "בלי ברכה" in it })
        assertFalse(indices("ashkenaz", "chaharit", "2025-10-09", true).any { "בלי ברכה" in it })
        assertEquals(setOf("replie"), etats("ashkenaz", "chaharit", "2025-10-09", tef, true))
        assertEquals(setOf("replie"), etats("ashkenaz", "chaharit", "2026-07-23", Regex("להתעטף בציצית")))
    }

    @Test
    fun `minha des jeunes - la lecture de la torah et la haftara selon le rite`() {
        listOf("edot", "sefard", "ashkenaz").forEach { n ->
            assertTrue(n, indices(n, "minha", "2025-12-30").any { "ויחל" in it })
            assertFalse(n, indices(n, "minha", "2026-11-18").any { "ויחל" in it })
            assertEquals(n, n != "edot", indices(n, "minha", "2025-12-30").any { "דרשו" in it })
        }
        assertTrue(indices("edot", "minha", "2026-07-23").any { "שובה ישראל" in it })
    }

    @Test
    fun `chaharit du 9 av - veani zot beriti retire, pitoum haketoret replie`() {
        listOf("edot", "sefard", "ashkenaz").forEach { n ->
            val a = SiddurJour.parse(json, n).getValue("chaharit").first { it.sorte == SiddurJour.Sorte.INDICE && it.condition == "!ticha_beav" }
            assertTrue(n, nu(a.retire!!).startsWith("ואני זאת בריתי"))
        }
        assertEquals(setOf("replie"), etats("ashkenaz", "chaharit", "2026-07-23", Regex("^פטום הקטרת")))
        assertEquals(setOf("ordinaire"), etats("ashkenaz", "chaharit", "2026-11-18", Regex("^פטום הקטרת")))
    }

    @Test
    fun `ledavid - chemini atseret ashkenaz de diaspora, edot hors d eloul`() {
        assertTrue(C.LEDAVID in conditions("ashkenaz", "2025-10-14"))
        assertFalse(C.LEDAVID in conditions("ashkenaz", "2025-10-15"))
        assertFalse(C.LEDAVID in conditions("ashkenaz", "2025-10-14", true))
        assertFalse(C.LEDAVID in conditions("sefard", "2025-10-14"))
        assertEquals(setOf("replie"), etats("edot", "chaharit", "2026-01-15", Regex("^לדוד.*יהוה אורי")))
        assertEquals(setOf("ordinaire"), etats("edot", "chaharit", "2026-08-20", Regex("^לדוד.*יהוה אורי")))
    }

    @Test
    fun `edot - mimaamakim a hochaana rabba, sefer torah, psaume 22, renvoi a l omer`() {
        assertEquals(setOf("du_jour"), etats("edot", "chaharit", "2025-10-13", Regex("^שיר המעלות.*ממעמקים")))
        assertEquals(setOf("replie"), etats("edot", "chaharit", "2025-10-14", Regex("^שיר המעלות.*ממעמקים")))
        assertTrue(indices("edot", "chaharit", "2026-11-19").any { "תכ״ג:ו" in it })
        assertTrue(indices("edot", "arvit", "2026-03-03").any { "אילת השחר" in it })
        val texte = DataFiles.siddur(Nusah.entries.first { it.cle == "edot" }).texte("arvit")!!
        val omer = SiddurJour.lignes(texte, SiddurJour.parse(json, "edot").getValue("arvit"),
            CalendrierJuif.jour(LocalDate.parse("2027-04-23"), false).conditions).filterIsInstance<SiddurJour.Ligne.Renvoi>()
        // Le 16 Nissan en diaspora, second soir du Séder : aussi le Hallel (audit du 16/11, Hallel et Moussaf).
        assertEquals(listOf("hallel", "sefirat_haomer"), omer.map { it.cible })
    }

    @Test
    fun `chema du coucher - vidui, nuit du seder, yehi ratson le chabbat`() {
        assertEquals(setOf("ordinaire"), etats("edot", "chema_coucher", "2026-11-18", Regex("^אנא יהוה")))
        listOf("2026-11-21", "2026-11-15", "2027-03-11", "2026-09-12").forEach {
            assertEquals(it, setOf("replie"), etats("edot", "chema_coucher", it, Regex("^אנא יהוה")))
        }
        listOf("sefard", "ashkenaz").forEach { n ->
            assertEquals(n, setOf("replie"), etats(n, "chema_coucher", "2027-04-22", ichev))
            assertEquals(n, setOf("replie"), etats(n, "chema_coucher", "2027-04-23", ichev))
            assertEquals(n, setOf("ordinaire"), etats(n, "chema_coucher", "2027-04-23", ichev, true))
            assertTrue(n, indices(n, "chema_coucher", "2026-11-18").any { "ביאור הלכה" in it })
        }
        val texte = DataFiles.siddur(Nusah.entries.first { it.cle == "edot" }).texte("chema_coucher")!!
        fun ribono(iso: String) = SiddurJour.lignes(texte, SiddurJour.parse(json, "edot").getValue("chema_coucher"),
            CalendrierJuif.jour(LocalDate.parse(iso), false).conditions).filterIsInstance<SiddurJour.Ligne.Bloc>()
            .first { nu(it.origine.texte).startsWith("רבונו של עולם") }.bloc.texte
        assertTrue("יְהִי רָצוֹן" in ribono("2026-11-18"))
        assertFalse("יְהִי רָצוֹן" in ribono("2026-11-21"))
    }

    @Test
    fun `meguila - shehehiyanou la nuit en edot, asher heni la nuit en sfard et ashkenaz`() {
        fun etat(nusah: String, deNuit: Boolean, motif: Regex): Set<String> {
            val texte = DataFiles.siddur(Nusah.entries.first { it.cle == nusah }).texte("megila")!!
            val jour = CalendrierJuif.jour(LocalDate.parse("2026-03-03"), false).conditions.let { if (deNuit) it + C.NUIT else it }
            val vus = SiddurJour.lignes(texte, SiddurJour.parse(json, nusah).getValue("megila"), jour, nusah = nusah)
                .filterIsInstance<SiddurJour.Ligne.Bloc>().filter { motif.containsMatchIn(nu(it.origine.texte)) }
            return if (vus.isEmpty()) setOf("replie") else vus.map { it.style.name }.toSet()
        }
        assertEquals(setOf("NORMAL"), etat("edot", true, Regex("שהחינו")))
        assertEquals(setOf("replie"), etat("edot", false, Regex("שהחינו")))
        listOf("sefard", "ashkenaz").forEach { n ->
            assertEquals(n, setOf("NORMAL"), etat(n, true, Regex("^א שר הניא")))
            assertEquals(n, setOf("replie"), etat(n, false, Regex("^א שר הניא")))
            assertEquals(n, setOf("NORMAL"), etat(n, false, Regex("שהחינו")))
        }
        assertTrue(CalendrierJuif.nuit(LocalTime.of(20, 0), null, null))
        assertFalse(CalendrierJuif.nuit(LocalTime.of(10, 0), null, null))
        assertFalse(CalendrierJuif.nuit(LocalTime.of(5, 0), false, false))
    }

    private fun lignes(nusah: String, id: String, iso: String, ouverts: Set<String> = emptySet()): List<SiddurJour.Ligne> {
        val texte = DataFiles.siddur(Nusah.entries.first { it.cle == nusah }).texte(id)!!
        return SiddurJour.lignes(texte, SiddurJour.parse(json, nusah).getValue(id),
            CalendrierJuif.jour(LocalDate.parse(iso), false).conditions, ouverts, nusah = nusah)
    }

    /** Suite de l'audit du 16/11 : la double annotation. */
    @Test
    fun `double annotation - kaddich des ajouts du jour, tetkabal du 9 av, fin du kaddich ashkenaze`() {
        // לדוד ה׳ אורי en Eloul : le psaume en clair, son Kaddich replié sous « Avec minyan ».
        val l = lignes("ashkenaz", "chaharit", "2026-08-20")
        val psaume = l.indexOfFirst { it is SiddurJour.Ligne.Bloc && nu(it.bloc.texte).startsWith("לדוד יהוה אורי") }
        assertTrue(psaume >= 0)
        assertTrue((l[psaume + 1] as SiddurJour.Ligne.Replie).condition == C.MINYAN)
        // « תתקבל » (Ashkenaz, fin de Cha'harit), dans le groupe du minyan ouvert : retiré le 9 Av (26/11, sans repli).
        fun tetkabal(iso: String): List<SiddurJour.Ligne> {
            val ann = SiddurJour.parse(json, "ashkenaz").getValue("chaharit").first { it.empreinte.startsWith("תתקבל") && it.section == 6 }
            return lignes("ashkenaz", "chaharit", iso, setOf("6:${ann.groupe}"))
        }
        assertTrue(tetkabal("2026-07-23").none { it is SiddurJour.Ligne.Replie && it.libelle == "ajout_sauf_ticha_beav" })
        assertFalse(tetkabal("2026-07-23").any { it is SiddurJour.Ligne.Bloc && nu(it.bloc.texte).startsWith("תתקבל") })
        assertTrue(tetkabal("2026-11-18").any { it is SiddurJour.Ligne.Bloc && nu(it.bloc.texte).startsWith("תתקבל") })
        // Ashkenaz, Arvit du motsaé Chabbat : un repère reprend la fin du Kaddich après ואתה קדוש.
        assertTrue(lignes("ashkenaz", "arvit", "2026-11-15").any { it is SiddurJour.Ligne.Indice && "תתקבל" in it.texte })
        assertFalse(lignes("ashkenaz", "arvit", "2026-11-18").any { it is SiddurJour.Ligne.Indice && "תתקבל" in it.texte })
        // Le Hallel : son Kaddich sous le minyan.
        assertTrue(SiddurJour.parse(json, "edot").getValue("hallel").any { it.condition == C.MINYAN })
    }

    @Test
    fun `page de l omer - le texte de chaque rite`() {
        listOf(Nusah.SEFARD to "לעמר", Nusah.ASHKENAZ to "בעמר").forEach { (n, mot) ->
            val t = DataFiles.siddur(n).texte("sefirat_haomer")!!
            assertNull(n.cle, t.emprunt)
            assertTrue(n.cle, t.sections[0].blocs.any { nu(it.texte).contains("היום יום אחד $mot") })
        }
    }

    @Test
    fun `psaume 22 - aussi le jeudi soir d un pourim triple a jerusalem`() {
        val c = CalendrierJuif.jour(LocalDate.parse("2025-03-14"), true, true).conditions
        assertTrue(C.POURIM_TRIPLE_VENDREDI in c && C.POURIM !in c)
        val texte = DataFiles.siddur(Nusah.EDOT).texte("arvit")!!
        assertTrue(SiddurJour.lignes(texte, SiddurJour.parse(json, "edot").getValue("arvit"), c, enIsrael = true)
            .any { it is SiddurJour.Ligne.Indice && "אילת השחר" in it.texte })
    }

    @Test
    fun `pour cette heure - pas d office de semaine un chabbat ou un yom tov`() {
        fun m(moment: String, iso: String, h: Int) = JourAffiche.momentOuvrable(moment, LocalDate.parse(iso), LocalTime.of(h, 0), false)
        assertNull(m("arvit", "2026-11-20", 20))
        assertNull(m("chaharit", "2026-11-21", 9))
        assertNull(m("minha", "2026-09-21", 15))
        assertEquals("arvit", m("arvit", "2026-11-21", 20))
        assertEquals("chaharit", m("chaharit", "2026-11-18", 9))
        assertEquals("chema_coucher", m("chema_coucher", "2026-11-20", 23))
    }
}
