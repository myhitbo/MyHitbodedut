package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Les versions de l'application (VersionApp, 17/11) : chaque version se retrouve par sa clé,
 * son accueil est déclaré au manifeste, son nom et sa description existent en trois langues,
 * et l'accueil d'origine renvoie vers la version choisie.
 */
class VersionAppTest {

    private fun lire(chemin: String) = File(chemin).readText()

    @Test
    fun `chaque version se retrouve par sa cle`() {
        VersionApp.values().forEach { assertEquals(it, VersionApp.parse(it.cle)) }
        assertNull(VersionApp.parse(null))
        assertNull(VersionApp.parse("inconnue"))
        assertNull("Classique est MainActivity elle-même", VersionApp.CLASSIQUE.accueil)
    }

    @Test
    fun `chaque accueil est au manifeste et chaque nom en trois langues`() {
        val manifeste = lire("src/main/AndroidManifest.xml")
        assertTrue(manifeste.contains("android:name=\".ChoixVersionActivity\""))
        VersionApp.values().mapNotNull { it.accueil }.forEach {
            assertTrue("${it.simpleName} absent du manifeste", manifeste.contains("android:name=\".${it.simpleName}\""))
        }
        val cles = listOf("settings_version", "version_choix_titre") + VersionApp.values().flatMap { v ->
            listOf("version_${v.cle}", "version_${v.cle}_desc")
        }
        listOf("values", "values-en", "values-iw").forEach { d ->
            val s = lire("src/main/res/$d/strings.xml")
            cles.forEach { assertTrue("$d : $it manque", s.contains("name=\"$it\"")) }
        }
    }

    @Test
    fun `l accueil d origine renvoie vers la version choisie et propose le choix`() {
        val main = lire("src/main/java/com/myhitbodedut/MainActivity.kt")
        assertTrue(main.contains("if (VersionApp.rediriger(this)) return"))
        assertTrue(main.contains("ChoixVersionActivity::class.java"))
        // Les captures de la CI partent de Classique : sans cela, l'écran du choix couvrirait l'accueil.
        assertTrue(lire("../../.github/captures/captures.py").contains("\"version_app\": (\"string\", \"classique\")"))
    }

    @Test
    fun `les polices des versions ont leur licence`() {
        listOf("OFL-SecularOne.txt", "OFL-Rubik.txt", "OFL-Heebo.txt", "OFL-Bellefair.txt").forEach {
            assertTrue(it, lire("src/main/assets/licences/$it").contains("SIL Open Font License"))
        }
    }
}
