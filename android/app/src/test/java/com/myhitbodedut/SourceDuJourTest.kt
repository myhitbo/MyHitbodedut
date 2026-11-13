package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * La source du jour (proposition 10, 19/10) : un paragraphe des sources libres,
 * le même toute la journée, et le même que le web (web/test/regles.test.mjs).
 */
class SourceDuJourTest {

    private val library = DataFiles.library

    private fun ici(jour: String): Pair<String, Int> {
        val p = SourceDuJour.choix(library, LocalDate.parse(jour))!!
        // Le rang gardé est bien celui du paragraphe dans sa source.
        assertEquals(p.indice, LibraryRules.paragraphs(library, p.source).indexOf(p.texte))
        return p.source.id to p.indice
    }

    @Test
    fun `le meme paragraphe que le web, le meme jour`() {
        assertEquals("src-lm2-25" to 9, ici("2026-10-19"))
        assertEquals("src-lt-zera" to 1, ici("2026-10-20"))
        assertEquals("src-lt-zera" to 2, ici("2027-01-01"))
    }

    @Test
    fun `seules les sources, jamais les articles, et assez longues`() {
        val c = SourceDuJour.candidats(library)
        assertTrue(c.size > 50)
        assertTrue(c.all { it.texte.length >= SourceDuJour.MIN })
        assertTrue(SourceDuJour.extrait("א".repeat(10) + " " + "ב".repeat(400)).endsWith("…"))
        assertTrue(File("src/main/java/com/myhitbodedut/MainActivity.kt").readText().contains("SourceDuJour.carte("))
    }

    /**
     * Audit du 12/11 (COUV-08, BIBLIO-03, FACCUEIL-08, FWEBCODE-08) : la carte ne montrait que
     * l'hébreu. Elle suit les langues de lecture, et la traduction est celle du même paragraphe.
     */
    @Test
    fun `la carte donne la traduction du meme paragraphe, selon les langues de lecture`() {
        // L'exemple de l'audit : Likoutei Tefilot II, 22, deuxième paragraphe.
        val p = SourceDuJour.candidats(library).first { it.source.id == "src-lt-hitbodedut" && it.indice == 1 }
        val francais = SourceDuJour.textes(p, LanguesTexte.Mode.HE_FR)
        assertEquals(listOf("he", "fr"), francais.map { it.first })
        assertEquals(SourceDuJour.extrait(p.texte), francais[0].second)
        assertTrue(francais[1].second, francais[1].second.startsWith("Aie pitié de moi et ouvre ma bouche en tout temps"))
        val anglais = SourceDuJour.textes(p, LanguesTexte.Mode.HE_EN)
        assertTrue(anglais[1].second, anglais[1].second.startsWith("Have mercy on me and open my mouth at all times"))
        // Une seule langue : elle seule ; l'hébreu seul en hébreu.
        assertEquals(listOf("fr"), SourceDuJour.textes(p, LanguesTexte.Mode.FR).map { it.first })
        assertEquals(listOf("he" to SourceDuJour.extrait(p.texte)), SourceDuJour.textes(p, LanguesTexte.Mode.HE))
        // Chaque extrait tient sur l'accueil, coupé à un mot.
        SourceDuJour.candidats(library).forEach { c ->
            SourceDuJour.textes(c, LanguesTexte.Mode.FR_EN).forEach { (_, t) -> assertTrue(t, t.length <= 321) }
        }
    }

    @Test
    fun `chaque paragraphe candidat a sa traduction francaise et anglaise, a son rang`() {
        SourceDuJour.candidats(library).forEach { p ->
            val cle = "${p.source.id}[${p.indice}]"
            assertEquals(cle, listOf("fr", "en"), SourceDuJour.textes(p, LanguesTexte.Mode.FR_EN).map { it.first })
            // Autant de traductions que de paragraphes : un rang ne peut pas glisser.
            assertEquals(cle, LibraryRules.paragraphs(library, p.source).size, p.source.paragraphesFr.size)
            assertEquals(cle, LibraryRules.paragraphs(library, p.source).size, p.source.paragraphesEn.size)
        }
    }

    @Test
    fun `un paragraphe court ecarte ne decale pas les traductions`() {
        val source = SourceEntry(id = "s", titreHe = "", ref = "", refSefaria = null, url = null, edition = "e",
            paragraphes = listOf("קצר", "א".repeat(SourceDuJour.MIN)), paragraphesSansNikkoud = emptyList(), liensChizuk = emptyList(),
            paragraphesFr = listOf("court", "long"), paragraphesEn = listOf("short", "long one"),
            statutVerif = "", sujet = null, leconSurLeSujet = null)
        val bibliotheque = Library("1", mapOf("e" to Edition("e", "", "Public Domain", true)), listOf(Section("a", LocalizedText("", "", ""), listOf(SubSection("b", LocalizedText("", "", ""), listOf(source))))))
        val p = SourceDuJour.candidats(bibliotheque).single()
        assertEquals(1, p.indice)
        assertEquals(listOf("he" to "א".repeat(SourceDuJour.MIN), "fr" to "long"), SourceDuJour.textes(p, LanguesTexte.Mode.HE_FR))
        assertEquals(listOf("en" to "long one"), SourceDuJour.textes(p, LanguesTexte.Mode.EN))
    }

    @Test
    fun `la carte de l accueil passe par les langues de lecture`() {
        val source = File("src/main/java/com/myhitbodedut/SourceDuJour.kt").readText()
        assertTrue(source.contains("textes(p, LanguesTexte.mode(c))"))
        // Plus de carte qui pose l'hébreu seul.
        assertTrue(!source.contains("text = extrait(p.texte)"))
    }
}
