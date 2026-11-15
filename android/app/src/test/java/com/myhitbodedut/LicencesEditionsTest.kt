package com.myhitbodedut

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Chaque édition dit sous quelle licence ses textes sont livrés (29/10,
 * PUBLICATION_PLAY_STORE.md § 3.3) : Google Play ne s'accommode pas d'un
 * « unknown ».
 *
 * Quatre éditions de Sefaria n'ont pas de licence déclarée. L'œuvre, de
 * Rabbi Natan de Breslev (m. 1844), est du domaine public ; seule l'est moins
 * la vocalisation de l'éditeur moderne. Elles sont donc livrées en
 * « texte seul », et ce test tombe si l'une d'elles reprend sa vocalisation,
 * dans le drapeau comme dans le contenu des fichiers livrés (res/raw : l'APK et
 * le site). Les relevés vocalisés vivent hors de res/raw, dans
 * livres/editions_vocalisees.json.
 */
class LicencesEditionsTest {

    private val editions = DataFiles.chizuk.editions.values + DataFiles.library.editions.values

    @Test
    fun `aucune edition sans licence`() {
        assertTrue("rien à vérifier : aucune édition lue", editions.isNotEmpty())
        editions.forEach { e ->
            assertTrue("${e.key} : licence vide", e.licence.isNotBlank())
            assertFalse("${e.key} : licence « unknown »", e.licence.equals("unknown", ignoreCase = true))
        }
    }

    @Test
    fun `une edition en texte seul ne reprend pas sa vocalisation`() {
        val texteSeul = editions.filter { it.licence.contains("texte seul") }
        assertTrue("les quatre éditions en texte seul ont disparu", texteSeul.map { it.key }.toSet() == setOf("sh", "shr", "le", "lt"))
        texteSeul.forEach { e ->
            assertFalse("${e.key} : édition en texte seul, nikkoud_ok doit rester faux", e.nikkoudOk)
        }
    }

    /**
     * Les signes de vocalisation et de cantillation : U+0591 à U+05BD, U+05BF à
     * U+05C2 et U+05C4 à U+05C7. Le maqaf (U+05BE) et le sof pasouq (U+05C3) sont
     * de la ponctuation et restent permis.
     */
    private fun vocalise(c: Char): Boolean =
        c.code in 0x0591..0x05BD || c.code in 0x05BF..0x05C2 || c.code in 0x05C4..0x05C7

    /** Toutes les chaînes d'un arbre JSON, avec leur chemin. */
    private fun chaines(x: Any?, chemin: String, sortie: MutableList<Pair<String, String>>) {
        when (x) {
            is String -> sortie += chemin to x
            is JSONObject -> x.keys().forEach { k -> chaines(x.get(k), "$chemin.$k", sortie) }
            is JSONArray -> for (i in 0 until x.length()) chaines(x.get(i), "$chemin[$i]", sortie)
        }
    }

    /** Les clés de tout l'arbre, pour traquer un champ « *_sans_nikkoud » oublié. */
    private fun cles(x: Any?, sortie: MutableSet<String>) {
        when (x) {
            is JSONObject -> x.keys().forEach { k -> sortie += k; cles(x.get(k), sortie) }
            is JSONArray -> for (i in 0 until x.length()) cles(x.get(i), sortie)
        }
    }

    private fun vocalisations(tableau: JSONArray, editionsTexteSeul: Set<String>): List<String> {
        val fautes = mutableListOf<String>()
        for (i in 0 until tableau.length()) {
            val o = tableau.getJSONObject(i)
            // Les sections de la bibliothèque contiennent des sous-sections ; on descend partout.
            descend(o, editionsTexteSeul, fautes)
        }
        return fautes
    }

    private fun descend(x: Any?, editionsTexteSeul: Set<String>, fautes: MutableList<String>) {
        when (x) {
            is JSONObject -> {
                if (x.optString("edition") in editionsTexteSeul) {
                    val textes = mutableListOf<Pair<String, String>>()
                    chaines(x, x.optString("id"), textes)
                    textes.filter { (_, t) -> t.any(::vocalise) }
                        .forEach { (chemin, t) -> fautes += "$chemin : « ${t.take(40)} »" }
                } else {
                    x.keys().forEach { k -> descend(x.get(k), editionsTexteSeul, fautes) }
                }
            }
            is JSONArray -> for (i in 0 until x.length()) descend(x.get(i), editionsTexteSeul, fautes)
        }
    }

    private fun texteSeul(json: JSONObject): Set<String> {
        val editions = json.getJSONObject("_meta").getJSONObject("editions")
        return editions.keys().asSequence().filter { !editions.getJSONObject(it).optBoolean("nikkoud_ok", false) }.toSet()
    }

    @Test
    fun `bibliotheque json ne livre aucune vocalisation d une edition en texte seul`() {
        val racine = JSONObject(DataFiles.bibliothequeJson)
        val seul = texteSeul(racine)
        assertEquals(setOf("sh", "shr", "lt"), seul)
        val fautes = vocalisations(racine.getJSONArray("sections"), seul)
        assertTrue("signes de vocalisation livrés (${fautes.size}) : ${fautes.take(5)}", fautes.isEmpty())
        // Le contrôle ne doit pas être vide : des entrées de ces éditions existent bien.
        assertTrue("rien à vérifier : aucune entrée en texte seul", DataFiles.library.entrees.filterIsInstance<SourceEntry>().any { it.edition in seul })
    }

    @Test
    fun `chizuk json ne livre aucune vocalisation d une edition en texte seul`() {
        val racine = JSONObject(DataFiles.chizukJson)
        val seul = texteSeul(racine)
        assertEquals(setOf("sh", "shr", "le", "lt", "by"), seul)
        val fautes = vocalisations(racine.getJSONArray("items"), seul)
        assertTrue("signes de vocalisation livrés (${fautes.size}) : ${fautes.take(5)}", fautes.isEmpty())
        assertTrue("rien à vérifier : aucun texte en texte seul", DataFiles.chizuk.items.any { it.edition in seul })
    }

    @Test
    fun `plus aucun champ sans_nikkoud dans les fichiers livres`() {
        listOf(DataFiles.bibliothequeJson, DataFiles.chizukJson).forEach { json ->
            val toutes = mutableSetOf<String>()
            cles(JSONObject(json), toutes)
            assertEquals("champs *_sans_nikkoud encore livrés", emptyList<String>(), toutes.filter { it.endsWith("_sans_nikkoud") })
        }
    }
}
