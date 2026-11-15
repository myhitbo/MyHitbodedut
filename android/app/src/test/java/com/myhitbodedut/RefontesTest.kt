package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/** Les trois accueils refondus (15/11) : Ciel complet, Bento et Pile. */
class RefontesTest {

    private val r = CielDuJour.Reperes(netz = 389, chatsot = 742, minhaKetana = 948, chkia = 1095, tset = 1113)

    private fun item(id: String, he: String = "שלום", fr: String = "Paix") = ChizukItem(
        id = id, moments = listOf(Moment.OUVERTURE), theme = null, edition = "e", ref = "ref", refSefaria = null,
        url = null, he = he, fr = fr, en = "", note = null, dureeLectureSec = 10, statutVerif = "ok", relu = true,
    )

    @Test
    fun `le moment du jour suit les zmanim`() {
        assertEquals(Refontes.Periode.NUIT, Refontes.periode(60, r))
        assertEquals(Refontes.Periode.AVANT_LEVER, Refontes.periode(380, r))
        assertEquals(Refontes.Periode.MATIN, Refontes.periode(500, r))
        assertEquals(Refontes.Periode.APRES_HATSOT, Refontes.periode(800, r))
        assertEquals(Refontes.Periode.MINHA_KETANA, Refontes.periode(1000, r))
        assertEquals(Refontes.Periode.BEIN_HACHMACHOT, Refontes.periode(1100, r))
        assertEquals(Refontes.Periode.NUIT, Refontes.periode(1300, r))
    }

    @Test
    fun `la part du jour va de zero au lever a un au coucher`() {
        assertEquals(0f, Refontes.partDuJour(100, r))
        assertEquals(0.5f, Refontes.partDuJour((r.netz + r.chkia) / 2, r), 0.01f)
        assertEquals(1f, Refontes.partDuJour(1400, r))
        assertEquals(0f, Refontes.partDuJour(600, CielDuJour.Reperes(600, 600, 600, 600, 620)))
    }

    @Test
    fun `le hizouk du jour reste le meme toute la journee et change le lendemain`() {
        val items = (1..40).map { item("c$it") }
        val jour = LocalDate.of(2026, 11, 15)
        assertEquals(Refontes.hizoukDuJour(items, jour), Refontes.hizoukDuJour(items.shuffled(), jour))
        assertNotEquals(Refontes.hizoukDuJour(items, jour), Refontes.hizoukDuJour(items, jour.plusDays(1)))
        // Sans hébreu ou sans traduction, un texte ne s'affiche pas en tuile.
        assertNull(Refontes.hizoukDuJour(listOf(item("a", he = ""), item("b", fr = "")), jour))
    }

    @Test
    fun `la derniere note est la plus recente jusqu a aujourd hui`() {
        val jours = listOf(
            DayRecord("2026-11-10", 20, "avant"),
            DayRecord("2026-11-14", 0, "hier"),
            DayRecord("2026-11-15", 30, ""),
            DayRecord("2026-11-16", 10, "demain"),
        )
        assertEquals("hier", Refontes.derniereNote(jours, "2026-11-15")?.note)
        assertNull(Refontes.derniereNote(emptyList(), "2026-11-15"))
    }

    @Test
    fun `les barres de la semaine distinguent fait, du et a venir`() {
        val d = LocalDate.of(2026, 11, 15)
        val semaine = listOf(
            WeekDay(d, done = true, exempt = false, shabbat = false, future = false),
            WeekDay(d, done = false, exempt = false, shabbat = false, future = false),
            WeekDay(d, done = false, exempt = false, shabbat = false, future = true),
        )
        val b = Refontes.barres(semaine)
        assertEquals(1f, b[0])
        assertTrue(b[1] > b[2])
    }

    @Test
    fun `la disposition se sauvegarde et un choix inconnu revient au classique`() {
        assertEquals(Store.Disposition.PILE, Store.Disposition.parse("pile"))
        assertEquals(Store.Disposition.CLASSIQUE, Store.Disposition.parse("inconnue"))
        assertEquals(Store.Disposition.CLASSIQUE, Store.Disposition.parse(null))
        val store = File("src/main/java/com/myhitbodedut/Store.kt").readText()
        assertTrue(store.contains(""".put("accueil_disposition", accueilDisposition(context).cle)"""))
        assertTrue(store.contains("""settings.has("accueil_disposition")"""))
    }

    @Test
    fun `chaque texte des refontes existe dans les trois langues`() {
        val fr = File("src/main/res/values/strings.xml").readText()
        val noms = Regex("""name="((?:disposition|periode|conseil|refonte|pile)_[a-z_]+)"""").findAll(fr).map { it.groupValues[1] }.toSet()
        assertTrue(noms.size > 30)
        for (l in listOf("values-en", "values-iw")) {
            val t = File("src/main/res/$l/strings.xml").readText()
            noms.forEach { assertTrue("$l : $it", t.contains("name=\"$it\"")) }
        }
    }

    @Test
    fun `les refontes ne montrent pas un journal verrouille`() {
        val code = File("src/main/java/com/myhitbodedut/AccueilRefontes.kt").readText()
        val note = code.substringAfter("private fun note()").substringBefore("private fun couleur")
        assertTrue(note.trimStart().startsWith(": Pair<String, String>? {\n        if (Store.journalVerrou(a)) return null"))
    }
}
