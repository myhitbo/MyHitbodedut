package com.myhitbodedut

import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** Un fichier de sauvegarde fabriqué ne fait ni planter ni encombrer l'application (revue du 15/11). */
class ImportBornesTest {

    private val store = File("src/main/java/com/myhitbodedut/Store.kt").readText()

    @Test
    fun `une date hors de 2000 a 2100 n est pas une date du journal`() {
        // « 0000-01-01 » faisait planter l'accueil (JewishCalendar refuse l'ère avant J.-C.).
        listOf("0000-01-01", "1999-12-31", "2101-01-01", "-999999999-01-01", "+10000-01-01").forEach {
            assertNull("« $it » ne doit pas être acceptée", Store.dateValide(it))
        }
        assertNotNull(Store.dateValide("2000-01-01"))
        assertNotNull(Store.dateValide("2100-12-31"))
    }

    @Test
    fun `l echelle de lecture importee ne peut pas valoir NaN`() {
        assertTrue(store.contains("optDouble(\"lecture_echelle\", Double.NaN).takeIf { it.isFinite() }"))
        assertTrue(store.contains("getFloat(KEY_LECTURE_ECHELLE, 1f).takeIf { it.isFinite() }"))
    }

    @Test
    fun `les listes importees sont bornees comme sur le web`() {
        listOf(
            "heures.distinct().take(12)",
            "it.length <= 255 }.take(500)",
            ".take(4000))).apply()",
            "'|' !in it && it.length <= 100",
            "'|' !in it && it.length <= 40",
            ".takeIf { s -> s.length <= 40 } }.take(20)",
            "takeLast(IMPORT_DATES_MAX)",
        ).forEach { assertTrue("« $it » manque dans Store.kt", store.contains(it)) }
    }

    @Test
    fun `le journal enrichi importe s ecrit une seule fois`() {
        val ajouts = store.substringAfter("private fun importerAjouts(").substringBefore("val tikkun =")
        assertTrue(ajouts.contains("if (change) setJournalPlusBrut(context, ici.toString())"))
        assertTrue(!ajouts.contains("JournalPlus.ecrire("))
    }
}
