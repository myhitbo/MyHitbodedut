package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * La lecture de la Torah dans le siddour (26/11) : à sa place dans chaque office de semaine, repliée, ses montées
 * dépliées. Les mêmes cas côté web : web/test/lecture-siddur.test.mjs.
 */
class LectureSiddurTest {

    private val d = LectureTorah.parse(File("src/main/res/raw/lecture_torah.json").readText())
    private val annotationsJson = File("src/main/res/raw/siddur_annotations.json").readText()
    private val siddurs = LectureTorah.NUSAH.associateWith { SiddurLoader.parse(File("src/main/res/raw/siddur_$it.json").readText()) }

    private fun lignes(nusah: String, office: String, iso: String, il: Boolean = false, ouverts: Set<String> = emptySet()): List<SiddurJour.Ligne> {
        val date = LocalDate.parse(iso)
        val texte = siddurs.getValue(nusah).texte(office)!!
        val annotations = SiddurJour.parse(annotationsJson, nusah).getValue(office)
        val lectures = LectureTorah.lecturesOffice(d, date, office, il, false, nusah)
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
            assertEquals(listOf("Cohen", "Lévi", "Israël"), suite.take(3).map { (it as SiddurJour.Ligne.Passage).montee.libelle.fr })
            assertEquals(SiddurJour.Ligne.Fin("lecture:chaharit:0"), suite[3])
            assertTrue(SiddurJour.panneaux(ouverte).containsAll(listOf(i + 1, i + 2, i + 3)))
            // « Berèchit 32:4–6 », le nom hébreu du livre écrit à la manière de chaque langue.
            val m = (suite[0] as SiddurJour.Ligne.Passage).montee
            assertEquals("Berèchit 32:4–6", LectureTorah.reference(d, m.livre, m.debut, m.fin, "fr"))
            assertEquals("Bereshit 32:4–6", LectureTorah.reference(d, m.livre, m.debut, m.fin, "en"))
            assertEquals("בראשית 32:4–6", LectureTorah.reference(d, m.livre, m.debut, m.fin, "es"))
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
    fun `9 Av, le matin et a Minha, une seule lecture, sans les reperes qui la decrivaient`() {
        for (nusah in LectureTorah.NUSAH) {
            val matin = lecturesDe(lignes(nusah, "chaharit", "2026-07-23")).single()
            assertEquals("Tish'a B'Av", matin.lecture.cle)
            assertEquals(listOf("4:25", "4:30", "4:36"), matin.lecture.montees.map { it.debut })
            // Le matin aussi, le troisième est maftir dans les trois rites (Choul'han Aroukh O.H. 559:4).
            assertEquals(nusah, "Maftir", matin.lecture.montees[2].libelle.fr)
            val minha = lignes(nusah, "minha", "2026-07-23")
            val l = lecturesDe(minha).single()
            assertEquals("Tish'a B'Av (Mincha)", l.lecture.cle)
            assertTrue(l.cle.startsWith("lecture:minha:"))
            // Le troisième : maftir, dans les trois rites ce jour-là.
            assertEquals(nusah, "Maftir", l.lecture.montees[2].libelle.fr)
            assertTrue(nusah, minha.filterIsInstance<SiddurJour.Ligne.Indice>().none { "ויחל" in it.texte || "שובה ישראל" in it.texte })
        }
    }

    @Test
    fun `un jeune public a Minha, le troisieme selon le rite`() {
        for (nusah in LectureTorah.NUSAH) {
            val l = lecturesDe(lignes(nusah, "minha", "2026-12-20")).single()
            assertEquals("Asara B'Tevet (Mincha)", l.lecture.cle)
            assertEquals(if (nusah == "edot") "Israël" else "Maftir", l.lecture.montees[2].libelle.fr)
        }
        // Un jour sans jeûne, rien à Min'ha.
        for (nusah in LectureTorah.NUSAH) assertTrue(lecturesDe(lignes(nusah, "minha", "2026-12-21")).isEmpty())
    }

    @Test
    fun `pas de Yom tov ni de Chabbat dans les offices de semaine, le reste garde sa lecture`() {
        // Le siddour n'a pas l'office de Chabbat ni de Yom tov : leur lecture n'y vient jamais (« Pas de Yom Tov »).
        for (nusah in LectureTorah.NUSAH) {
            for (iso in listOf("2026-11-28", "2026-04-02", "2026-10-03")) assertTrue("$nusah $iso", lecturesDe(lignes(nusah, "chaharit", iso)).isEmpty())
            assertTrue(nusah, lecturesDe(lignes(nusah, "minha", "2026-09-21")).isEmpty()) // Kippour
            // 'Hol hamoed, 'Hanouka : la lecture reste.
            assertEquals("Pesach Chol ha-Moed Day 1", lecturesDe(lignes(nusah, "chaharit", "2026-04-05")).single().lecture.cle)
            assertEquals("Chanukah Day 3", lecturesDe(lignes(nusah, "chaharit", "2026-12-07")).single().lecture.cle)
        }
        val jour = CalendrierJuif.jour(LocalDate.parse("2026-11-28"), false)
        assertTrue(CalendrierJuif.C.KRIAT_HATORAH in jour.conditions && !LectureTorah.litDansLOffice(jour, LectureTorah.CHAHARIT))
    }

    @Test
    fun `le calendrier et le calcul s'accordent, cinq ans durant`() {
        var j = LocalDate.parse("2025-09-01")
        while (j < LocalDate.parse("2030-09-01")) {
            for (il in listOf(false, true)) {
                val jour = CalendrierJuif.jour(j, il)
                for (office in LectureTorah.OFFICES) {
                    assertEquals("$j $il $office", LectureTorah.litDansLOffice(jour, office), LectureTorah.lectures(d, j, office, il).isNotEmpty())
                }
            }
            j = j.plusDays(1)
        }
    }

    @Test
    fun `la question Israel ou diaspora tient compte de la lecture`() {
        // Dimanche 27/09/2026 (16 Tichri) : 'Hol hamoed en Israël, sa lecture ; second jour de Souccot en diaspora (Yom tov,
        // rien dans l'office de semaine).
        val date = LocalDate.parse("2026-09-27")
        assertEquals("Sukkot Chol ha-Moed Day 1 (Israel)", LectureTorah.lecturesOffice(d, date, "chaharit", true).single().cle)
        assertTrue(LectureTorah.lecturesOffice(d, date, "chaharit", false).isEmpty())
        val texte = siddurs.getValue("edot").texte("chaharit")!!
        val annotations = SiddurJour.parse(annotationsJson, "edot").getValue("chaharit")
        val israel = CalendrierJuif.jour(date, true).conditions
        val diaspora = CalendrierJuif.jour(date, false).conditions
        assertTrue(SiddurJour.dependDeLaRegion(texte, annotations, israel, diaspora, "edot",
            lecturesIsrael = LectureTorah.lecturesOffice(d, date, "chaharit", true), lecturesDiaspora = LectureTorah.lecturesOffice(d, date, "chaharit", false)))
    }

    @Test
    fun `les chaines de la lecture dans les cinq langues, et la licence d'hebcal`() {
        for (dossier in listOf("values", "values-en", "values-iw", "values-es", "values-ar-rTN")) {
            val xml = File("src/main/res/$dossier/strings.xml").readText()
            for (cle in listOf("lecture_titre", "lecture_chargement")) assertTrue("$dossier $cle", xml.contains("name=\"$cle\""))
            assertTrue(dossier, xml.contains("<plurals name=\"lecture_montees\">"))
            assertTrue(dossier, xml.contains("@hebcal/leyning") && xml.contains("BSD") && xml.contains("Tanach with Ta’amei Hamikra"))
        }
        assertTrue(File("src/main/assets/licences/BSD-2-hebcal-leyning.txt").readText().contains("Copyright (c) 2020, hebcal"))
        assertTrue(File("src/main/java/com/myhitbodedut/SettingsActivity.kt").readText().contains("BSD-2-hebcal-leyning.txt"))
    }
}
