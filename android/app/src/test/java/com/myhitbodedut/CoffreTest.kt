package com.myhitbodedut

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** La sauvegarde chiffrée par mot de passe (audit de sécurité du 12/11/2026). */
class CoffreTest {

    private val clair = """{"format":"myhitbodedut","days":{"2026-11-12":{"note":"שלום, une note intime"}}}"""

    @Test
    fun `le bon mot de passe rend le texte, un autre ne rend rien`() {
        val chiffre = Coffre.chiffrer(clair, "mot de passe é", 100_000)
        assertTrue(Coffre.estChiffre(chiffre))
        assertFalse("la note se lit dans le fichier", chiffre.contains("intime"))
        assertEquals(clair, Coffre.dechiffrer(chiffre, "mot de passe é"))
        assertNull(Coffre.dechiffrer(chiffre, "mot de passe e"))
    }

    @Test
    fun `deux exports du meme texte ne se ressemblent pas`() {
        assertNotEquals(Coffre.chiffrer(clair, "a", 100_000), Coffre.chiffrer(clair, "a", 100_000))
    }

    @Test
    fun `un fichier modifie ou fabrique est refuse`() {
        val r = JSONObject(Coffre.chiffrer(clair, "a", 100_000))
        val data = r.getString("data")
        val abime = JSONObject(r.toString()).put("data", (if (data[0] == 'A') "B" else "A") + data.substring(1))
        assertNull(Coffre.dechiffrer(abime.toString(), "a"))
        // Une clé presque gratuite à deviner, ou un calcul sans fin.
        assertNull(Coffre.dechiffrer(JSONObject(r.toString()).put("iterations", 1).toString(), "a"))
        assertNull(Coffre.dechiffrer(JSONObject(r.toString()).put("iterations", 2_000_000_000).toString(), "a"))
        assertNull(Coffre.dechiffrer(clair, "a"))
        assertFalse(Coffre.estChiffre(clair))
        assertFalse(Coffre.estChiffre("pas du json"))
    }

    /** Le fichier écrit par la version web (coffre.js) se lit ici : même format, même dérivation. */
    @Test
    fun `une sauvegarde chiffree par le web se lit sur Android`() {
        val vecteur = JSONObject(File("../../web/test/vecteur_coffre.json").readText())
        assertEquals(vecteur.getString("clair"), Coffre.dechiffrer(vecteur.getJSONObject("chiffre").toString(), vecteur.getString("mot_de_passe")))
    }

    @Test
    fun `l export demande un mot de passe et l import sait lire un fichier chiffre`() {
        val reglages = File("src/main/java/com/myhitbodedut/SettingsActivity.kt").readText()
        assertTrue(reglages.contains("Coffre.chiffrer(clair, motDePasse)"))
        assertTrue(reglages.contains("Coffre.estChiffre(text)"))
    }
}
