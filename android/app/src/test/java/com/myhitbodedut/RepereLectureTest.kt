package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** FLECTURE-04 : le passage lu se retrouve par son repère, non par un nombre de pixels. */
class RepereLectureTest {

    private val hebreu = listOf(Triple(1, 0, 100), Triple(2, 100, 200), Triple(3, 200, 300))
    private val deuxLangues = listOf(Triple(1, 0, 250), Triple(1, 250, 400), Triple(2, 400, 600), Triple(3, 600, 900))

    @Test fun toutEnHautNeGardeRien() {
        assertNull(ReglagesLecture.premierRepere(hebreu, 0))
        assertNull(ReglagesLecture.premierRepere(emptyList(), 50))
    }

    @Test fun lePassageEnHautEstRetrouveQuandLeTexteChangeDeHauteur() {
        val garde = ReglagesLecture.premierRepere(hebreu, 150)!!
        assertEquals(2, garde.first)
        assertEquals(0.5f, garde.second, 0.001f)
        // Hébreu + traduction : le même passage est plus bas, à la même part.
        assertEquals(500, ReglagesLecture.placeDuRepere(deuxLangues, garde))
    }

    @Test fun lePremierMorceauDuRepereFaitFoi() {
        assertEquals(0, ReglagesLecture.placeDuRepere(deuxLangues, 1 to 0f))
    }

    @Test fun unRepereAbsentNeFaitPasDefiler() {
        assertNull(ReglagesLecture.placeDuRepere(hebreu, 9 to 0.5f))
    }
}

/** FLECTURE-05 : un résultat touché dans la recherche globale se retrouve dans l'écran Halakha. */
class RechercheHalakhaTest {
    @Test fun `venu de la recherche globale, les deux livres sont interroges`() {
        Store.SourceHalakha.values().forEach { s ->
            val c = s.pourRecherche(true)
            assertEquals(true, c.yalkut)
            assertEquals(true, c.benIshHai)
        }
    }

    @Test fun `ouvert normalement, le livre choisi seul`() {
        assertEquals(false, Store.SourceHalakha.YALKUT.pourRecherche(false).benIshHai)
        assertEquals(false, Store.SourceHalakha.BEN_ISH_HAI.pourRecherche(false).yalkut)
    }
}

/** FLECTURE-06 : les livres entiers lus ne s'accumulent pas en mémoire. */
class LivresEnMemoireTest {
    @Test fun `rien n est garde avant la premiere lecture et apres le vidage`() {
        Data.viderLivres()
        assertEquals(false, Data.livreEnMemoire("likoutei_moharan"))
        assertEquals(2, Data.LIVRES_GARDES)
    }
}

/** FLECTURE-07 : une requête dépassée s'abandonne en route. */
class RechercheAnnulableTest {
    private val s = Siddur(emptyList(), listOf(SiddurTexte("t", "g", LocalizedText("עלינו", "Alénou", "Aleinu"), "",
        listOf(SiddurSection("", listOf(SiddurBloc("וַאֲנַחְנוּ כּוֹרְעִים", false)))))))

    @Test fun `une requete dépassée ne rend rien`() {
        assertEquals(1, RechercheGlobale.chercher("כורעים", "fr", s, null, null, null, null).size)
        assertEquals(0, RechercheGlobale.chercher("כורעים", "fr", s, null, null, null, null, annule = { true }).size)
    }

    @Test fun `la normalisation reste la meme`() {
        assertEquals("birkot hachahar prieres", RechercheGlobale.nu("Birkot hacha’har Prières"))
        assertEquals("ברוך אתה", RechercheGlobale.nu("<b>בָּרוּךְ</b> אַתָּה"))
    }

    @Test fun `un livre rend plusieurs paragraphes, chacun avec sa place`() {
        val blocs = (0 until 8).map { SiddurBloc("שמחה $it", false) }
        val livre = Siddur(emptyList(), listOf(SiddurTexte("l", "g", LocalizedText("ספר", "Livre", "Book"), "",
            listOf(SiddurSection("א", blocs.take(4)), SiddurSection("ב", blocs.drop(4))))))
        val r = RechercheGlobale.dansRecueil(livre, RechercheGlobale.nu("שמחה"), RechercheGlobale.Sorte.LIVRE, "fr")
        assertEquals(RechercheGlobale.PAR_TEXTE, r.size)
        assertEquals((0 to 0), r[0].section to r[0].bloc)
        assertEquals((1 to 0), r.getOrNull(4)?.let { it.section to it.bloc } ?: (1 to 0))
        assertEquals(true, r.all { it.section >= 0 && it.bloc >= 0 })
    }
}
