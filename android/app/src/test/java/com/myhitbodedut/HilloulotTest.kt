package com.myhitbodedut

import com.kosherjava.zmanim.hebrewcalendar.JewishCalendar
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/** La hilloula du jour et l'illustration de la carte du jour (11/10). */
class HilloulotTest {

    private val table = Hilloulot.parse(File("src/main/res/raw/hilloulot.json").readText())

    @Test
    fun `le cycle de Meton suit KosherJava`() {
        (5700..5900).forEach { a ->
            assertEquals("$a", JewishCalendar(a, JewishCalendar.TISHREI, 1).isJewishLeapYear, Hilloulot.embolismique(a))
        }
    }

    @Test
    fun `adar sans precision se dit en adar II, un 30 absent le 29`() {
        assertEquals(listOf("adar-7", "adar1-7", "adar2-7"), Hilloulot.cles(12, 7, embolismique = false, dernierJour = false))
        assertEquals(listOf("adar1-7"), Hilloulot.cles(12, 7, embolismique = true, dernierJour = false))
        assertEquals(listOf("adar-7", "adar2-7"), Hilloulot.cles(13, 7, embolismique = true, dernierJour = false))
        // Ashkénazes : « adar » en Adar I (Rema OH 568:7).
        assertEquals(listOf("adar-7", "adar1-7"), Hilloulot.cles(12, 7, embolismique = true, dernierJour = false, ashkenaz = true))
        assertEquals(listOf("adar2-7"), Hilloulot.cles(13, 7, embolismique = true, dernierJour = false, ashkenaz = true))
        assertEquals(listOf("8-29", "8-30"), Hilloulot.cles(8, 29, embolismique = false, dernierJour = true))
    }

    @Test
    fun `chaque jour d une annee simple a sa hilloula`() {
        var d = LocalDate.of(2025, 9, 23)
        while (d.isBefore(LocalDate.of(2026, 9, 12))) {
            assertTrue("$d", Hilloulot.pour(table, d, false).isNotEmpty())
            d = d.plusDays(1)
        }
        // 30 Tichri 5787 : Rabbi Tsvi Hirsch Chajes (Wikipédia).
        assertTrue(Hilloulot.pour(table, LocalDate.of(2026, 10, 11), false).any { it.he.contains("צבי הירש חיות") })
        assertTrue(table.keys.all { Regex("""(\d{1,2}|adar[12]?)-\d{1,2}""").matches(it) })
    }

    @Test
    fun `les liens de la carte du jour`() {
        assertEquals("https://hyomi.org.il/day.php?month1=0&dd=11&mm=10&yy=2026", Hilloulot.lienHyomi(LocalDate.of(2026, 10, 11)))
        assertEquals("https://halachayomit.co.il/he/default.aspx", Hilloulot.lienHalakha("iw"))
        assertEquals("https://halachayomit.co.il/en/default.aspx", Hilloulot.lienHalakha("en"))
        assertEquals("https://halachayomit.co.il/fr/default.aspx", Hilloulot.lienHalakha("fr"))
    }

    @Test
    fun `l illustration du jour de fete ou de chabbat`() {
        assertEquals("scene_sukkot", JourAffiche.illustration(listOf("soukkot"), LocalDate.of(2026, 9, 26)))
        assertEquals("char_matsa", JourAffiche.illustration(listOf("pessah"), LocalDate.of(2027, 4, 22)))
        assertEquals("char_shabbat", JourAffiche.illustration(emptyList(), LocalDate.of(2026, 10, 10)))
        assertEquals(null, JourAffiche.illustration(emptyList(), LocalDate.of(2026, 10, 11)))
    }

    @Test
    fun `date lisible et recherche par nom`() {
        assertEquals("ל׳ תשרי", Hilloulot.dateDe("7-30"))
        assertEquals("ז׳ אדר ב׳", Hilloulot.dateDe("adar2-7"))
        assertTrue(Hilloulot.recherche(table, "צבי הירש חיות").any { it.first == "7-30" })
        assertTrue(Hilloulot.recherche(table, "א").isEmpty())
        // En français et en anglais, avec ou sans accents (29/10).
        assertTrue(Hilloulot.recherche(table, "Chelah").isNotEmpty())
        assertTrue(Hilloulot.recherche(table, "Shelah").isNotEmpty())
        assertEquals(Hilloulot.recherche(table, "Moché").size, Hilloulot.recherche(table, "moche").size)
        // « Moïse » trouve Moché Rabbénou (THILLOULOT-10).
        assertTrue(Hilloulot.recherche(table, "Moïse").any { (cle, h) -> cle == "adar-7" && h.he == "משה רבנו" })
    }

    @Test
    fun `les biographies d autres sources, a part, avec leur source`() {
        val complete = Hilloulot.avecBios(table, File("src/main/res/raw/hilloulot_bios.json").readText())
        assertEquals(table.keys, complete.keys)
        table.forEach { (cle, liste) -> assertEquals(cle, liste.map { it.he }, complete.getValue(cle).map { it.he }) }
        val bios = complete.values.flatten().flatMap { it.bios }
        assertTrue(bios.size > 2000)
        assertTrue(bios.all { it.source in setOf("m", "l") && it.texte.isNotBlank() })
        // La source est dite : chaque biographie de MyTzadik ou de המאיר לארץ garde le lien vers sa page.
        assertTrue(bios.all { it.lien?.startsWith("https://") == true })
        assertTrue(table.values.flatten().all { it.bios.isEmpty() })
    }

    @Test
    fun `un jour range les mieux connus d abord, les sources avant le doute`() {
        val h = { he: String, s: String, t: String?, d: String? -> Hilloulot.Hilloula(he, null, null, "", s, d, t) }
        val t = mapOf("8-23" to listOf(h("un", "m", null, null), h("doute", "wm", "x", "faux"), h("trois", "hwm", "x", null), h("deux", "wm", null, null), h("deux-notice", "wm", "x", null)))
        assertEquals(listOf("trois", "deux-notice", "deux", "doute", "un"), Hilloulot.duJour(t, listOf("8-23")).map { it.he })
        // Les plus célèbres ne sont plus relégués par une simple note : Rachbi (18 Iyar), le Rambam (20 Tevet).
        val cinq = { cle: String -> Hilloulot.duJour(table, listOf(cle)).take(5).map { it.he } }
        assertTrue(cinq("2-18").contains("רבי שמעון בר יוחאי"))
        assertTrue(cinq("10-20").any { it.contains("הרמב\"ם") })
    }

    @Test
    fun `un tsadik n apparait qu une fois par jour, et Rav Mandelbaum a la date de sa mort`() {
        // L'identifiant de dépliage d'une ligne est « jour|nom » : un nom ne se répète pas dans un jour.
        table.forEach { (cle, liste) -> assertEquals(cle, liste.size, liste.map { it.he.trim() }.distinct().size) }
        // Rabbi Natan de Breslev : une ligne, qui porte les deux sources et la biographie de MyTzadik.
        val natan = table.getValue("10-10").filter { it.he.contains("נתן") && it.he.contains("ברסלב") }
        assertEquals(1, natan.size)
        assertTrue(table.getValue("10-10").none { it.he.contains("שטרנהרץ") })
        // 22 Tevet 5594 est sa naissance ; il est mort le 17 Iyar 5665.
        assertTrue(table.getValue("10-22").none { it.he.contains("מנדלבאום") })
        assertEquals("ה'תרס\"ה", table.getValue("2-17").single { it.he.contains("מנדלבאום") }.annee)
    }

    @Test
    fun `la recherche suit l annee, de Tichri a Eloul`() {
        assertTrue(Hilloulot.rangDansLAnnee("7-1") < Hilloulot.rangDansLAnnee("11-30"))
        assertTrue(Hilloulot.rangDansLAnnee("11-30") < Hilloulot.rangDansLAnnee("adar1-1"))
        assertTrue(Hilloulot.rangDansLAnnee("adar1-30") < Hilloulot.rangDansLAnnee("adar-1"))
        assertTrue(Hilloulot.rangDansLAnnee("adar-29") < Hilloulot.rangDansLAnnee("adar2-1"))
        assertTrue(Hilloulot.rangDansLAnnee("adar2-29") < Hilloulot.rangDansLAnnee("1-1"))
        assertTrue(Hilloulot.rangDansLAnnee("1-1") < Hilloulot.rangDansLAnnee("6-29"))
        val rangs = Hilloulot.recherche(table, "רבי").map { Hilloulot.rangDansLAnnee(it.first) }
        assertTrue(rangs.size > 100)
        assertEquals(rangs.sorted(), rangs)
    }

    @Test
    fun `voir ce jour mene au prochain jour de la date`() {
        // 23 Hechvan 5787 : le 3 novembre 2026 ; depuis le 4, celui de 5788.
        assertEquals(LocalDate.of(2026, 11, 3), Hilloulot.prochainJour("8-23", LocalDate.of(2026, 10, 1), false))
        val suivant = Hilloulot.prochainJour("8-23", LocalDate.of(2026, 11, 4), false)!!
        assertTrue("8-23" in Hilloulot.clesPour(suivant, false))
        assertTrue(suivant.isAfter(LocalDate.of(2027, 10, 1)) && suivant.isBefore(LocalDate.of(2027, 12, 1)))
        // Adar II n'existe que les années embolismiques : il se trouve quand même.
        assertTrue(Hilloulot.prochainJour("adar2-14", LocalDate.of(2026, 11, 4), false) != null)
    }

    @Test
    fun `les biographies ne portent ni coordonnees de tiers ni residus de source`() {
        val bios = File("src/main/res/raw/hilloulot_bios.json").readText()
        assertTrue("courriel", !bios.contains("@"))
        assertTrue("telephone", !Regex("""\d{2,3}-\d{6,7}|\b0\d{8,9}\b|\d{3}-\d{3}-\d{4}|\(9722\)""").containsMatchIn(bios))
        listOf("WhatsApp", "דוא\\\"ל", "חייגו", "(ק)", "[להאזנה]", "איתן בן יצחק רפאל", "אביבה בת אסתר גיטל", "מסודי בת פרחה")
            .forEach { assertTrue(it, !bios.contains(it)) }
        // Un crédit « באדיבות … », pas la prose (« באדיבותו », « התייחס באדיבות ובמאור פנים »).
        assertTrue("credit", !Regex("""באדיבות(?!ו)(?!\s+וב)""").containsMatchIn(bios))
        // Ni la tête d'un crédit coupé, seule sur sa ligne (« …ליוצרה.⏎התמונה »).
        assertTrue("tete", !Regex("""\\n(?:התמונה|התמונות|תמונת הציון|תמונת הצדיק|תמונת האוהל)(?=\\n|")""").containsMatchIn(bios))
    }

    @Test
    fun `le nettoyage des biographies garde la prose`() {
        val bios = File("src/main/res/raw/hilloulot_bios.json").readText()
        // Relecture du 15/11 : « לעילוי נשמת » et « באדיבות » de la prose restent, comme le « : » des lignes non coupées.
        listOf("לעילוי נשמת אביו וביקש מבורא עולם", "להדליק נר לעילוי נשמתו", "התייחס באדיבות ובמאור פנים", "באדיבותו ונדיבותו")
            .forEach { assertTrue(it, bios.contains(it)) }
        assertTrue("מספריו:", Regex("מספריו:").findAll(bios).count() > 1000)
    }

    /** « ה'תר"ץ » → 5690 ; sans le millénaire, le sixième ; null pour une année civile ou glosée. */
    private fun anneeHebraique(a: String): Int? {
        val m = Regex("""(?:([א-ט])['׳])?([א-ת"״]+)""").matchEntire(a.trim()) ?: return null
        val v = "אבגדהוזחטיכלמנסעפצקרשת".toList().zip(listOf(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 200, 300, 400)).toMap() +
            mapOf('ך' to 20, 'ם' to 40, 'ן' to 50, 'ף' to 80, 'ץ' to 90)
        val n = m.groupValues[2].sumOf { v[it] ?: 0 }
        val mille = m.groupValues[1].firstOrNull()?.let { v[it]!! } ?: 5
        return if (n == 0) null else mille * 1000 + n
    }

    @Test
    fun `les dates des hilloulot existent l annee de leur deces`() {
        // THILLOULOT-12 : Adar I et Adar II, les années embolismiques seulement ; un 30, si le mois en a 30 cette année-là.
        // Restent, faute d'autre source, cinq faits de החכם היומי seul (relevés par l'audit du 12/11), à vérifier.
        val aVerifier = setOf("חכם עובדיה מזרחי הלוי", "חכם דוד כהן", "חכם יהושע יהודה אמאדו", "חכם יוסף בן אדהאן", "חכם משה חפץ")
        val impossibles = table.flatMap { (cle, l) -> l.map { cle to it } }.filter { (cle, h) ->
            val y = anneeHebraique(h.annee)?.takeIf { it >= 4000 } ?: return@filter false
            val (m, j) = cle.split("-").let { it[0] to it[1].toInt() }
            when (m) {
                "adar1" -> !Hilloulot.embolismique(y)
                "adar2" -> !Hilloulot.embolismique(y) || j == 30
                "adar" -> j == 30 && !Hilloulot.embolismique(y)
                else -> j > JewishCalendar(y, m.toInt(), 1).daysInJewishMonth
            }
        }
        assertEquals(impossibles.joinToString { (cle, h) -> "$cle ${h.he} ${h.annee}" }, aVerifier.sorted(), impossibles.map { it.second.he }.sorted())
    }
}
