package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.json.JSONObject
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

    private fun semaine(iso: String, il: Boolean = false, nusah: String = "edot") = LectureTorah.parachaSemaine(d, LocalDate.parse(iso), il, false, nusah)

    @Test
    fun `le texte « Lecture de la Torah », la paracha de la semaine, jamais une lecture de Yom tov`() {
        // Un mardi (24/11/2026) : la paracha du Chabbat qui vient, ses sept montées, le maftir et la haftara.
        val mardi = semaine("2026-11-24")
        assertEquals(LocalDate.parse("2026-11-28"), mardi.date)
        assertEquals("parasha:VAYISHLACH", mardi.lecture.cle)
        assertEquals(8, mardi.lecture.montees.size)
        assertEquals("Obadiah", mardi.lecture.haftara.single().livre)
        // Les noms hébreux, écrits à la manière de la langue (« Ovadia, Shmuel ») : « Haftara : Ovadia 1:1–21 ».
        val h = mardi.lecture.haftara.single()
        assertEquals("Ovadia 1:1–21", LectureTorah.reference(d, h.livre, h.debut, h.fin, "fr"))
        assertEquals("Berèchit 32:4–13", LectureTorah.reference(d, "Genesis", "32:4", "32:13", "fr"))
        assertEquals("Bereshit 32:4–13", LectureTorah.reference(d, "Genesis", "32:4", "32:13", "en"))
        assertEquals("Shmuel I 20:18–42", LectureTorah.reference(d, "I Samuel", "20:18", "20:42", "en"))
        assertEquals("עובדיה 1:1–21", LectureTorah.reference(d, h.livre, h.debut, h.fin, "es"))
        // Le Chabbat même : la sienne.
        assertEquals(mardi, semaine("2026-11-28"))
        // La semaine avant Souccot (Souccot un Chabbat, puis Chemini Atsérèt un Chabbat) et celle de Sim'hat Torah : Berèchit.
        for (il in listOf(true, false)) assertEquals(LocalDate.parse("2026-10-10"), semaine("2026-09-22", il).date)
        assertEquals("Berèchit", semaine("2026-10-04").lecture.titre.fr)
        assertTrue(semaine("2026-10-04").lecture.cle.startsWith("parasha:BERESHIS"))
        // Avant Pessa'h 5786 : le Chabbat de 'Hol hamoed n'a pas de paracha, Chemini le 11/04.
        assertEquals(LocalDate.parse("2026-04-11") to "parasha:SHMINI", semaine("2026-03-31", nusah = "ashkenaz").let { it.date to it.lecture.cle })
        // 5789 : le 8e jour de Pessa'h un Chabbat en diaspora ; Chemini dès le 07/04 en Israël, le 14/04 en diaspora.
        assertEquals(LocalDate.parse("2029-04-07"), semaine("2029-04-03", true, "ashkenaz").date)
        assertEquals(LocalDate.parse("2029-04-14"), semaine("2029-04-03", false, "ashkenaz").date)
        assertTrue(semaine("2029-04-03", false, "ashkenaz").lecture.cle.startsWith("parasha:SHMINI"))
        // Deux parachiot jointes : Matot-Masé (31/07/2027), une lecture.
        val jointes = semaine("2027-07-27", nusah = "ashkenaz")
        assertEquals("parasha:MATOS_MASEI", jointes.lecture.cle)
        assertEquals("Matot-Masé", jointes.lecture.titre.fr)
        assertEquals("30:2" to "36:13", jointes.lecture.montees.first().debut to jointes.lecture.montees[6].fin)
        // Chabbat Chekalim (Vayakhel, 06/03/2027) : son maftir et sa haftara restent.
        for (nusah in LectureTorah.NUSAH) {
            val chekalim = semaine("2027-03-02", nusah = nusah).lecture
            assertTrue(nusah, chekalim.cle.startsWith("parasha:VAYAKHEL+Shabbat Shekalim"))
            assertEquals("30:11", chekalim.montees.last().debut)
            assertEquals("II Kings", chekalim.haftara.first().livre)
            assertTrue(chekalim.raisons.isNotEmpty())
        }
        // Jamais une fête ni un jour de semaine, dans tout un cycle.
        var j = LocalDate.parse("2026-09-01")
        while (j < LocalDate.parse("2027-10-01")) {
            for (il in listOf(true, false)) {
                val p = semaine(j.toString(), il)
                assertTrue("$j", p.lecture.cle.startsWith("parasha:") && p.date.dayOfWeek == java.time.DayOfWeek.SATURDAY && !p.date.isBefore(j))
            }
            j = j.plusDays(1)
        }
        // Ses lignes : les montées avec le Targoum, pas la haftara.
        val l = SiddurJour.lignesLecture(listOf(mardi.lecture), "lecture:semaine:2026-11-28", setOf("lecture:semaine:2026-11-28:0", "lecture:semaine:2026-11-28:0:h"), targoum = true)
        val passages = l.filterIsInstance<SiddurJour.Ligne.Passage>()
        assertEquals(List(8) { true } + false, passages.map { it.targoum })
        // Le titre : « Lecture de la Torah », en tête des textes de certains moments, dans les trois nusah.
        assertEquals("Lecture de la Torah", LectureTorah.TITRE.fr)
        val liste = File("src/main/java/com/myhitbodedut/SiddurActivity.kt").readText()
        assertTrue(liste.contains("if (groupe.cle != \"moments\") emptyList() else listOf(LectureTorah.TITRE"))
        siddurs.values.forEach { s -> assertTrue(s.groupes.any { it.cle == "moments" }) }
    }

    private val texte = LectureTorah.Texte(File("src/main/res/raw/lecture_torah_texte.json").readText())
    private val targoum = LectureTorah.Texte(File("src/main/res/raw/lecture_torah_targoum.json").readText())

    @Test
    fun `Chnayim mikra, l hebreu deux fois puis le Targoum, ou une fois selon le reglage`() {
        val p = LectureTorah.Passage("Genesis", "32:4", "32:6")
        val deux = LectureTorah.chnayimMikra(texte.versets(p), targoum.versets(p))
        assertEquals(listOf(4, 4, 4, 5, 5, 5, 6, 6, 6), deux.map { it.verset })
        assertEquals(listOf(false, false, true, false, false, true, false, false, true), deux.map { it.targoum })
        assertEquals(texte.versets(p)[0].texte, deux[0].texte)
        assertEquals(deux[0], deux[1])
        assertEquals(targoum.versets(p)[0].texte, deux[2].texte)
        assertTrue(deux[2].texte.startsWith("וּשְׁלַח יַעֲקֹב אִזְגַּדִּין"))
        val une = LectureTorah.chnayimMikra(texte.versets(p), targoum.versets(p), uneFois = true)
        assertEquals(listOf(false, true, false, true, false, true), une.map { it.targoum })
        // Le réglage : gardé avec les autres réglages de lecture, deux fois par défaut ; le bouton du texte seul.
        val store = File("src/main/java/com/myhitbodedut/Store.kt").readText()
        assertTrue(store.contains("getBoolean(KEY_LECTURE_HEBREU_UNE_FOIS, false)") && store.contains(".put(\"lecture_hebreu_une_fois\""))
        val activite = File("src/main/java/com/myhitbodedut/SiddurLectureActivity.kt").readText()
        assertTrue(activite.contains("chnayimMikra = !livre && id == LectureTorah.ID_TEXTE"))
        assertTrue(activite.contains("Store.lectureHebreuUneFois(this@SiddurLectureActivity)"))
    }

    @Test
    fun `le Targoum Onkelos, meme versification que le texte, cinq livres, domaine public`() {
        val t = JSONObject(File("src/main/res/raw/lecture_torah_targoum.json").readText())
        val h = JSONObject(File("src/main/res/raw/lecture_torah_texte.json").readText()).getJSONObject("livres")
        val livres = t.getJSONObject("livres")
        assertEquals(setOf("Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy"), livres.keys().asSequence().toSet())
        var versets = 0
        for (livre in livres.keys()) {
            val a = livres.getJSONObject(livre)
            val b = h.getJSONObject(livre)
            assertEquals(livre, b.length(), a.length())
            for (c in a.keys()) {
                assertEquals("$livre $c", b.getJSONArray(c).length(), a.getJSONArray(c).length())
                versets += a.getJSONArray(c).length()
            }
        }
        assertEquals(5847, versets)
        // Bamidbar 25:19 rendu à son verset ; la licence et la source dans _meta et l'écran des licences.
        assertEquals("וַהֲוָה בָּתַר מוֹתָנָא׃", livres.getJSONObject("Numbers").getJSONArray("25").getString(18))
        assertEquals("Public Domain", t.getJSONObject("_meta").getString("licence"))
        for (dossier in listOf("values", "values-en", "values-iw", "values-es", "values-ar-rTN")) {
            assertTrue(dossier, File("src/main/res/$dossier/strings.xml").readText().contains("toratemetfreeware.com"))
        }
    }

    @Test
    fun `la question Israel ou diaspora tient compte de la lecture`() {
        // Dimanche 27/09/2026 (17 Tichri) : 'Hol hamoed en Israël, sa lecture ; second jour de Souccot en diaspora (Yom tov,
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
            for (cle in listOf("lecture_titre", "lecture_haftara", "lecture_paracha_semaine", "lecture_paracha_chabbat", "reglage_chnayim_mikra",
                    "lecture_hebreu_deux_fois", "lecture_hebreu_une_fois")) assertTrue("$dossier $cle", xml.contains("name=\"$cle\""))
            assertTrue(dossier, xml.contains("<plurals name=\"lecture_montees\">"))
            assertTrue(dossier, xml.contains("@hebcal/leyning") && xml.contains("BSD") && xml.contains("Tanach with Ta’amei Hamikra"))
        }
        assertTrue(File("src/main/assets/licences/BSD-2-hebcal-leyning.txt").readText().contains("Copyright (c) 2020, hebcal"))
        assertTrue(File("src/main/java/com/myhitbodedut/SettingsActivity.kt").readText().contains("BSD-2-hebcal-leyning.txt"))
    }
}
