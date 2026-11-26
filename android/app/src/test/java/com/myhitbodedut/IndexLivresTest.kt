package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.io.StringWriter

/**
 * Décision du 24/11 : la recherche dans les livres lit un index écrit une fois, au lieu de relire
 * 28 Mo de livres à chaque requête. Elle doit trouver exactement ce que trouvait l'ancienne.
 */
class IndexLivresTest {

    private fun bloc(t: String, consigne: Boolean = false) = SiddurBloc(t, consigne)

    private val livres = Siddur(
        emptyList(),
        listOf(
            SiddurTexte("likoutei_moharan", "livres", LocalizedText("ליקוטי מוהר\"ן", "Likouté Moharan", "Likutey Moharan"), "", listOf(
                SiddurSection("תורה א", listOf(
                    bloc("אַשְׁרֵי תְמִימֵי דָרֶךְ, הַהוֹלְכִים בְּתוֹרַת ה'"),
                    bloc("consigne : שִׂמְחָה", consigne = true),
                    bloc("מִצְוָה גְּדוֹלָה לִהְיוֹת בְּשִׂמְחָה תָּמִיד"),
                )),
                SiddurSection("", listOf(bloc("שִׂמְחָה\tגְּדוֹלָה"))),
            )),
            SiddurTexte("sefer_hamidot", "livres", LocalizedText("ספר המידות", "Le livre des traits", "The Aleph-Bet Book"), "", listOf(
                SiddurSection("אמת", List(8) { bloc("שִׂמְחָה מספר $it — Prière, priere") }),
            )),
            SiddurTexte("chir", "livres", LocalizedText("שיר השירים", "", "Song of Songs"), "", listOf(
                SiddurSection("א", listOf(bloc("שִׁיר הַשִּׁירִים אֲשֶׁר לִשְׁלֹמֹה"))),
            )),
        ),
    )

    private fun index(): Sequence<String> = StringWriter().also { IndexLivres.ecrire(livres, it) }.toString().lineSequence()

    private fun avant(q: String, langue: String) =
        RechercheGlobale.dansRecueil(livres, RechercheGlobale.nu(q), RechercheGlobale.Sorte.LIVRE, langue)

    private fun apres(q: String, langue: String) = IndexLivres.chercher(index(), RechercheGlobale.nu(q), langue)

    @Test
    fun `memes resultats que l ancienne recherche`() {
        listOf("שמחה", "גדולה", "priere", "Prière", "Likoute", "Song", "שירים", "תמימי דרך", "rien du tout").forEach { q ->
            listOf("fr", "en", "he", "es", "ar").forEach { l ->
                assertEquals("« $q » en $l", avant(q, l), apres(q, l))
            }
        }
    }

    @Test
    fun `cinq au plus par livre, titre compris, et la place du paragraphe`() {
        val r = apres("שמחה", "fr").filter { it.id == "sefer_hamidot" }
        assertEquals(RechercheGlobale.PAR_TEXTE, r.size)
        assertEquals(listOf(0, 1, 2, 3, 4), r.map { it.bloc })
        assertTrue(r.first().extrait.startsWith("אמת · "))
    }

    @Test
    fun `une consigne ne se cherche pas, une tabulation ne casse pas l index`() {
        val r = apres("שמחה", "fr").filter { it.id == "likoutei_moharan" }
        assertEquals(listOf(2, 0), r.map { it.bloc })
    }

    @Test
    fun `une requete depassee s arrete`() {
        assertEquals(emptyList<RechercheGlobale.Resultat>(), IndexLivres.chercher(index(), RechercheGlobale.nu("שמחה"), "fr") { true })
    }

    @Test
    fun `l ecran de recherche passe par l index, et l ecrit en avance`() {
        val s = File("src/main/java/com/myhitbodedut/RechercheActivity.kt").readText()
        assertTrue(s.contains("fil.execute { IndexLivres.pret(c) }"))
        assertTrue(s.contains("livresIndexes = indexes"))
    }
}
