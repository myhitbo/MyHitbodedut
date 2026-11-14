package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Dire honnêtement ce qui n'est pas traduit et d'où viennent les textes (audit du 12/11 : COUV-01, 02, 05,
 * TLIVRES-05, 09, TPLAYDOCS-13).
 */
class SourcesLicencesTest {

    private val K = "src/main/java/com/myhitbodedut/"

    @Test
    fun `le Yalkout Yossef n'est traduit qu'en partie, et le lecteur le sait`() {
        val yalkut = SiddurLoader.parse(File("src/main/res/raw/livre_yalkut_yosef_kitsour.json").readText()).textes.first()
        val traduits = yalkut.chapitresTraduits()
        assertTrue("$traduits", traduits in 1 until yalkut.sections.size)
        // Un livre entièrement traduit n'a pas d'avis de traduction partielle.
        val esther = SiddurLoader.parse(File("src/main/res/raw/livre_meguilat_esther.json").readText()).textes.first()
        assertEquals(esther.sections.size, esther.chapitresTraduits())
        val lecteur = File("${K}SiddurLectureActivity.kt").readText()
        assertTrue(lecteur.contains("R.string.lecture_traduction_partielle, chapitresTraduits, texte.sections.size"))
        // Le siddour dit lui aussi qu'il n'est pas traduit : la note n'est plus réservée aux livres.
        assertTrue(lecteur.contains("val sansTraduction = if (LanguesTexte.manque(langues, traduit))"))
    }

    @Test
    fun `la mention de traduction automatique figure sur le hizouk et la bibliotheque`() {
        assertTrue(File("${K}ChizukActivity.kt").readText().contains("LanguesTexte.mentionAuto(this)"))
        assertTrue(File("${K}LibraryEntryActivity.kt").readText().contains("LanguesTexte.mentionAuto(this)"))
        assertTrue(LanguesTexte.montreTraduction(LanguesTexte.Mode.HE_FR))
        assertTrue(!LanguesTexte.montreTraduction(LanguesTexte.Mode.HE))
    }

    @Test
    fun `les sources et licences sont dans les reglages, en trois langues, avec les textes des licences`() {
        assertTrue(File("src/main/res/layout/activity_settings.xml").readText().contains("@string/settings_licences"))
        assertTrue(File("${K}SettingsActivity.kt").readText().contains("licences/\$nom"))
        for (dossier in listOf("values", "values-en", "values-iw")) {
            val xml = File("src/main/res/$dossier/strings.xml").readText()
            for (cle in listOf("settings_licences", "licences_texte", "licences_android", "lecture_traduction_partielle"))
                assertTrue("$dossier $cle", xml.contains("name=\"$cle\""))
            for (mot in listOf("KosherJava", "LGPL 2.1", "ZXing", "Apache 2.0", "CC BY-NC-SA 2.5", "GeoNames", "OFL"))
                assertTrue("$dossier $mot", xml.contains(mot))
        }
        assertTrue(File("src/main/assets/licences/LGPL-2.1-KosherJava.txt").readText().contains("GNU LESSER GENERAL PUBLIC LICENSE"))
        assertTrue(File("src/main/assets/licences/Apache-2.0-ZXing.txt").readText().contains("Apache License"))
    }
}
