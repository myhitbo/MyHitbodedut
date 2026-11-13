package com.myhitbodedut

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Les textes à compteur s'accordent au nombre (audit du 12/11, TFRLANGUE-01 et TEN-02).
 *
 * Dès la première hitbodedout, l'écran affichait « 1 trophées gagnés », « Série : 1 jours sur 7 »
 * et « votre 1ᵉ trophée » ; en anglais, « 3 times hitbodedut ». Ces chaînes sont des pluriels
 * dans les trois langues (une <plurals> écrite en français seulement ferait retomber l'anglais
 * et l'hébreu sur le français), et le code les demande avec leur quantité.
 */
class CompteursTest {

    private val accordees = listOf("ring_streak_detail", "ring_week_detail", "grade_sous", "grade_sous_max",
        "trophees_autres", "grade_partage_texte", "trophee_detail_grade")

    private fun formes(dossier: String, nom: String): Map<String, String> {
        val racine = DocumentBuilderFactory.newInstance().newDocumentBuilder()
            .parse(File("src/main/res/$dossier/strings.xml")).documentElement
        val noeuds = racine.getElementsByTagName("plurals")
        for (i in 0 until noeuds.length) {
            val e = noeuds.item(i) as org.w3c.dom.Element
            if (e.getAttribute("name") != nom) continue
            val items = e.getElementsByTagName("item")
            return (0 until items.length).associate { j ->
                val item = items.item(j) as org.w3c.dom.Element
                item.getAttribute("quantity") to item.textContent
            }
        }
        return emptyMap()
    }

    private fun source(f: String) = File("src/main/java/com/myhitbodedut/$f").readText()

    @Test
    fun `les sept compteurs sont des pluriels dans les trois langues`() {
        listOf("values", "values-en", "values-iw").forEach { d ->
            val xml = File("src/main/res/$d/strings.xml").readText()
            accordees.forEach { nom ->
                assertFalse("$d : $nom est encore une <string>", xml.contains("<string name=\"$nom\""))
                val f = formes(d, nom)
                assertTrue("$d : $nom n'a pas « one » et « other »", f.containsKey("one") && f.containsKey("other"))
            }
            // L'hébreu a son duel, comme les pluriels voisins.
            if (d == "values-iw") accordees.forEach { assertTrue("$d : $it sans « two »", formes(d, it).containsKey("two")) }
        }
    }

    @Test
    fun `le singulier francais ne porte plus de pluriel`() {
        val nb = " "
        assertEquals("Série$nb: %1\$d jour sur %2\$d", formes("values", "ring_streak_detail")["one"])
        assertEquals("%1\$d trophée gagné", formes("values", "grade_sous_max")["one"])
        assertEquals("%1\$d trophée gagné · encore %2\$d pour %3\$s", formes("values", "grade_sous")["one"])
        assertEquals("… et %1\$d autre trophée plus loin", formes("values", "trophees_autres")["one"])
        // L'ordinal : « premier » au rang 1, jamais « 1ᵉ ».
        assertEquals("En %1\$s$nb: c’était votre premier trophée.", formes("values", "trophee_detail_grade")["one"])
        assertFalse(File("src/main/res/values/strings.xml").readText().contains("jours sur %4\$d"))
    }

    @Test
    fun `l anglais compte des jours de hitbodedut`() {
        assertEquals("%1\$d day of hitbodedut, %2\$s in total", formes("values-en", "journal_summary")["one"])
        assertEquals("%1\$d days of hitbodedut, %2\$s in total", formes("values-en", "journal_summary")["other"])
        assertEquals("First %1\$d days of hitbodedut", formes("values-en", "trophee_premier_pas_desc")["other"])
        assertEquals("Coming back once after a week’s break", formes("values-en", "trophee_retour_desc")["one"])
        assertEquals("%1\$d trophy earned", formes("values-en", "grade_sous_max")["one"])
        assertFalse(File("src/main/res/values-en/strings.xml").readText().contains("times hitbodedut"))
        assertFalse(File("src/main/res/values-en/strings.xml").readText().contains("time hitbodedut"))
    }

    @Test
    fun `le code demande ces textes avec leur quantite`() {
        val appels = listOf("MainActivity.kt", "StreakWidget.kt", "PaliersActivity.kt", "FicheTrophee.kt").joinToString("\n") { source(it) }
        accordees.forEach { nom ->
            assertFalse("R.string.$nom est encore appelé", appels.contains("R.string.$nom,") || appels.contains("R.string.$nom)"))
            assertTrue("R.plurals.$nom n'est pas appelé", appels.contains("getQuantityString(R.plurals.$nom,"))
        }
        // Le site relit les mêmes chaînes : il passe par tr.p, qui choisit la forme.
        val web = File("../../web/src/js/app.js").readText()
        accordees.forEach { nom ->
            assertFalse("le site : tr.t('$nom')", web.contains("tr.t('$nom'"))
            assertTrue("le site : tr.p('$nom')", web.contains("tr.p('$nom'"))
        }
    }

    /** La description des anneaux reçoit deux phrases déjà accordées, pas des nombres nus. */
    @Test
    fun `la description des anneaux se compose de phrases accordees`() {
        listOf("values", "values-en", "values-iw").forEach { d ->
            val xml = File("src/main/res/$d/strings.xml").readText()
            val description = Regex("""<string name="rings_description">([^<]*)</string>""").find(xml)!!.groupValues[1]
            assertEquals("$d : $description", listOf("%1\$s", "%2\$s", "%3\$s", "%4\$s"),
                Regex("""%\d\$[sd]""").findAll(description).map { it.value }.toList())
        }
    }
}
