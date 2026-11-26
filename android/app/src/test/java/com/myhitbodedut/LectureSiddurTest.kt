package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * La lecture de la Torah dans le siddour (26/11, phase B) : à sa place dans chaque office, repliée, puis sa haftara ;
 * et le texte « Lecture de la Torah ». Les mêmes cas côté web : web/test/lecture-siddur.test.mjs.
 */
class LectureSiddurTest {

    private val d = LectureTorah.parse(File("src/main/res/raw/lecture_torah.json").readText())
    private val annotationsJson = File("src/main/res/raw/siddur_annotations.json").readText()
    private val siddurs = LectureTorah.NUSAH.associateWith { SiddurLoader.parse(File("src/main/res/raw/siddur_$it.json").readText()) }

    private fun lignes(nusah: String, office: String, iso: String, il: Boolean = false, ouverts: Set<String> = emptySet()): List<SiddurJour.Ligne> {
        val date = LocalDate.parse(iso)
        val texte = siddurs.getValue(nusah).texte(office)!!
        val annotations = SiddurJour.parse(annotationsJson, nusah).getValue(office)
        val lectures = LectureTorah.lectures(d, date, office, il, false, nusah)
        return SiddurJour.lignes(texte, annotations, CalendrierJuif.jour(date, il).conditions, ouverts, nusah, il, lectures = lectures)
    }

    private fun lecturesDe(l: List<SiddurJour.Ligne>) = l.filterIsInstance<SiddurJour.Ligne.Lecture>()

    @Test
    fun `un lundi, la lecture repliee apres la benediction qui la suit, avant les Mi cheberakh`() {
        for (nusah in LectureTorah.NUSAH) {
            val l = lignes(nusah, "chaharit", "2026-11-23")
            val lectures = lecturesDe(l)
            assertEquals(nusah, 1, lectures.size)
            val lecture = lectures.single()
            assertEquals("semaine:VAYISHLACH", lecture.lecture.cle)
            assertEquals(3, lecture.lecture.montees.size)
            assertFalse(lecture.ouvert)
            // Juste après la bénédiction « אשר נתן לנו תורת אמת ».
            val k = l.indexOf(lecture)
            val avant = l[k - 1] as SiddurJour.Ligne.Bloc
            assertTrue(nusah, SiddurJour.empreinte(avant.bloc.texte).startsWith("ברוך אתה יהוה"))
            assertTrue(nusah, SiddurJour.empreinte(avant.bloc.texte).contains("אשר נתן"))
            // Les Mi chébérakh (Sfard, Ashkenaz) viennent après, repliés à part.
            if (nusah != "edot") {
                val mi = l.indexOfFirst { it is SiddurJour.Ligne.Replie && it.libelle == "ajout_mi_cheberakh_oleh" }
                assertTrue(nusah, mi > k)
            }
            // Dépliée : trois montées (Cohen, Lévi, Israël), puis la fin du repli.
            val ouverte = lignes(nusah, "chaharit", "2026-11-23", ouverts = setOf("lecture:chaharit:0"))
            val i = ouverte.indexOfFirst { it is SiddurJour.Ligne.Lecture }
            val suite = ouverte.drop(i + 1).take(4)
            assertEquals(listOf("Cohen", "Lévi", "Israël"), suite.take(3).map { (it as SiddurJour.Ligne.Passage).montee!!.libelle.fr })
            assertEquals(SiddurJour.Ligne.Fin("lecture:chaharit:0"), suite[3])
            assertTrue(SiddurJour.panneaux(ouverte).containsAll(listOf(i + 1, i + 2, i + 3)))
        }
    }

    @Test
    fun `un mardi sans lecture, ni lecture ni section de lecture`() {
        for (nusah in LectureTorah.NUSAH) assertTrue(nusah, lecturesDe(lignes(nusah, "chaharit", "2026-11-24")).isEmpty())
    }

    @Test
    fun `Roch Hodech et Hanouka a Roch Hodech Tevet, quatre montees`() {
        for (nusah in LectureTorah.NUSAH) {
            val rc = lecturesDe(lignes(nusah, "chaharit", "2026-11-10")).single().lecture
            assertEquals("Rosh Chodesh", rc.cle)
            assertEquals(4, rc.montees.size)
            val tevet = lecturesDe(lignes(nusah, "chaharit", "2026-12-11")).single().lecture
            assertEquals("Chanukah Day 7 (on Rosh Chodesh)", tevet.cle)
            assertEquals(listOf("28:1", "28:6", "28:11", "7:48"), tevet.montees.map { it.debut })
        }
    }

    @Test
    fun `9 Av, le matin et a Minha, selon le rite, sans les reperes qui la decrivaient`() {
        for (nusah in LectureTorah.NUSAH) {
            val matin = lecturesDe(lignes(nusah, "chaharit", "2026-07-23"))
            assertEquals(nusah, listOf(false, true), matin.map { it.haftara })
            assertEquals("Jeremiah", matin[0].lecture.haftara.single().livre)
            val minha = lignes(nusah, "minha", "2026-07-23")
            val l = lecturesDe(minha)
            assertEquals(nusah, listOf(false, true), l.map { it.haftara })
            val haftara = l[1].lecture.haftara.map { it.livre }
            assertEquals(nusah, if (nusah == "edot") listOf("Hosea", "Micah") else listOf("Isaiah"), haftara)
            assertTrue(nusah, minha.filterIsInstance<SiddurJour.Ligne.Indice>().none { "ויחל" in it.texte || "שובה ישראל" in it.texte })
            assertTrue(nusah, l.all { it.cle.startsWith("lecture:minha:") })
        }
    }

    @Test
    fun `un jeune public a Minha, Edot sans haftara, Ashkenaz et Sfard avec « דרשו »`() {
        for (nusah in LectureTorah.NUSAH) {
            val l = lecturesDe(lignes(nusah, "minha", "2026-12-20"))
            assertEquals(nusah, if (nusah == "edot") listOf(false) else listOf(false, true), l.map { it.haftara })
            assertEquals("Asara B'Tevet (Mincha)", l[0].lecture.cle)
            assertEquals(if (nusah == "edot") "Israël" else "Maftir", l[0].lecture.montees[2].libelle.fr)
        }
        // Un jour sans jeûne, rien à Min'ha.
        for (nusah in LectureTorah.NUSAH) assertTrue(lecturesDe(lignes(nusah, "minha", "2026-12-21")).isEmpty())
    }

    @Test
    fun `le texte « Lecture de la Torah », Chabbat matin et Minha, Chemini Atseret, un jour sans lecture`() {
        // Chabbat 28/11/2026 : Vayichla'h le matin (sept montées et le maftir, haftara), le début de Vayéchev à Min'ha.
        val chabbat = LectureTorah.programme(d, LocalDate.parse("2026-11-28"), false, false, "edot")
        assertTrue(chabbat.aujourdhui)
        assertEquals(listOf(LectureTorah.CHAHARIT, LectureTorah.MINHA), chabbat.offices.map { it.first })
        assertEquals("parasha:VAYISHLACH", chabbat.offices[0].second.single().cle)
        assertEquals("Obadiah", chabbat.offices[0].second.single().haftara.single().livre)
        assertEquals("semaine:VAYESHEV", chabbat.offices[1].second.single().cle)
        val l = SiddurJour.lignesLecture(chabbat.offices[0].second, "lecture:chaharit:2026-11-28", emptySet())
        assertEquals(listOf(false, true), l.filterIsInstance<SiddurJour.Ligne.Lecture>().map { it.haftara })
        // Chemini Atsérèt un Chabbat (03/10/2026) : Sim'hat Torah en Israël, Chemini Atsérèt en diaspora.
        val il = LectureTorah.programme(d, LocalDate.parse("2026-10-03"), true, false, "ashkenaz")
        val dia = LectureTorah.programme(d, LocalDate.parse("2026-10-03"), false, false, "ashkenaz")
        assertEquals("Simchat Torah (on Shabbat)", il.offices[0].second.single().cle)
        assertEquals("Shmini Atzeret (on Shabbat)", dia.offices[0].second.single().cle)
        assertTrue(il != dia) // la question Israël ou diaspora est posée tant que le statut n'est pas confirmé
        // Un mardi sans lecture (24/11/2026) : la paracha du Chabbat qui vient, avec sa date (la lecture de jeudi n'est
        // que son début) ; un lundi a la sienne.
        val mardi = LectureTorah.programme(d, LocalDate.parse("2026-11-24"), false, false, "edot")
        assertFalse(mardi.aujourdhui)
        assertEquals(LocalDate.parse("2026-11-28"), mardi.date)
        assertEquals("parasha:VAYISHLACH", mardi.offices.single().second.single().cle)
        assertTrue(LectureTorah.programme(d, LocalDate.parse("2026-11-23"), false, false, "edot").aujourdhui)
        // Un dimanche avant Roch 'Hodech Kislev (mardi 10/11/2026) : celui-ci d'abord, la lecture de lundi passée.
        assertEquals("Rosh Chodesh", LectureTorah.programme(d, LocalDate.parse("2026-11-08"), false, false, "edot").offices.single().second.single().cle)
        // Le titre : « Lecture de la Torah », en tête des textes de certains moments, dans les trois nusah.
        assertEquals("Lecture de la Torah", LectureTorah.TITRE.fr)
        val liste = File("src/main/java/com/myhitbodedut/SiddurActivity.kt").readText()
        assertTrue(liste.contains("if (groupe.cle != \"moments\") emptyList() else listOf(LectureTorah.TITRE"))
        siddurs.values.forEach { s -> assertTrue(s.groupes.any { it.cle == "moments" }) }
    }

    @Test
    fun `la question Israel ou diaspora tient compte de la lecture`() {
        // Le 9 Tichri n'a pas de lecture ; le 23 Tichri (dimanche 04/10/2026) : Sim'hat Torah en diaspora, rien en Israël.
        val date = LocalDate.parse("2026-10-04")
        val texte = siddurs.getValue("edot").texte("chaharit")!!
        val annotations = SiddurJour.parse(annotationsJson, "edot").getValue("chaharit")
        val israel = CalendrierJuif.jour(date, true).conditions
        val diaspora = CalendrierJuif.jour(date, false).conditions
        assertTrue(SiddurJour.dependDeLaRegion(texte, annotations, israel, diaspora, "edot",
            lecturesIsrael = LectureTorah.lectures(d, date, "chaharit", true), lecturesDiaspora = LectureTorah.lectures(d, date, "chaharit", false)))
    }

    @Test
    fun `les chaines de la lecture dans les cinq langues, et la licence d'hebcal`() {
        for (dossier in listOf("values", "values-en", "values-iw", "values-es", "values-ar-rTN")) {
            val xml = File("src/main/res/$dossier/strings.xml").readText()
            for (cle in listOf("lecture_titre", "lecture_haftara", "lecture_prochaine", "lecture_jour")) assertTrue("$dossier $cle", xml.contains("name=\"$cle\""))
            assertTrue(dossier, xml.contains("<plurals name=\"lecture_montees\">"))
            assertTrue(dossier, xml.contains("@hebcal/leyning") && xml.contains("BSD") && xml.contains("Tanach with Ta’amei Hamikra"))
        }
        assertTrue(File("src/main/assets/licences/BSD-2-hebcal-leyning.txt").readText().contains("Copyright (c) 2020, hebcal"))
        assertTrue(File("src/main/java/com/myhitbodedut/SettingsActivity.kt").readText().contains("BSD-2-hebcal-leyning.txt"))
    }
}
