package com.myhitbodedut

import com.myhitbodedut.Apparence.Accent
import com.myhitbodedut.Apparence.Fond
import com.myhitbodedut.Apparence.Habillage
import com.myhitbodedut.Apparence.Mode
import com.myhitbodedut.Apparence.Police
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Les habillages retenus sur la maquette (14/11) : Parchemin et Minuit doré,
 * avec la typographie Souffle (Bellefair et Open Sans). Les contrastes de
 * leurs palettes sont vérifiés par PaletteTest, comme ceux de toutes les autres.
 */
class HabillageTest {

    private fun lire(chemin: String) = File("src/main/$chemin").readText()

    @Test
    fun `la foret est l apparence d origine`() {
        assertEquals(Habillage.FORET, Habillage.de(Fond.parse(null), Accent.parse(null), Police.parse(null)))
        assertEquals(Police.SYSTEME, Police.parse("inconnue"))
        assertEquals(0, Police.SYSTEME.style)
    }

    @Test
    fun `chaque habillage se reconnait et un melange n en est pas un`() {
        Habillage.values().forEach { assertEquals(it, Habillage.de(it.fond, it.accent, it.police)) }
        assertEquals(Habillage.values().size, Habillage.values().map { Triple(it.fond, it.accent, it.police) }.toSet().size)
        assertNull(Habillage.de(Fond.PARCHEMIN, Accent.OR, Police.SOUFFLE))
        assertNull(Habillage.de(Fond.MINUIT, Accent.OR, Police.SYSTEME))
    }

    @Test
    fun `minuit dore se porte dans le noir et le rend en partant`() {
        assertEquals(Mode.SOMBRE, Habillage.mode(Habillage.FORET, Habillage.MINUIT, Mode.CLAIR))
        assertEquals(Mode.AUTO, Habillage.mode(Habillage.MINUIT, Habillage.PARCHEMIN, Mode.SOMBRE))
        // Un mode réglé à la main depuis reste le sien.
        assertEquals(Mode.CLAIR, Habillage.mode(Habillage.MINUIT, Habillage.FORET, Mode.CLAIR))
        assertEquals(Mode.SOMBRE, Habillage.mode(null, Habillage.PARCHEMIN, Mode.SOMBRE))
        assertEquals(Mode.CLAIR, Habillage.mode(Habillage.FORET, Habillage.PARCHEMIN, Mode.CLAIR))
    }

    @Test
    fun `la typographie souffle est livree avec ses licences`() {
        listOf("bellefair.ttf", "open_sans_regular.ttf", "open_sans_semibold.ttf", "open_sans_bold.ttf").forEach {
            val f = File("src/main/res/font/$it")
            assertTrue("$it absent", f.isFile && f.length() > 50_000)
        }
        val famille = lire("res/font/open_sans.xml")
        listOf("400" to "open_sans_regular", "600" to "open_sans_semibold", "700" to "open_sans_bold").forEach { (graisse, police) ->
            assertTrue("Open Sans $graisse", famille.contains("""android:fontWeight="$graisse" android:font="@font/$police""""))
        }
        mapOf("OFL-Bellefair.txt" to "Bellefair Project Authors", "OFL-OpenSans.txt" to "Open Sans Project Authors").forEach { (f, auteurs) ->
            val texte = lire("assets/licences/$f")
            assertTrue(f, texte.contains("SIL Open Font License") && texte.contains(auteurs))
        }
    }

    @Test
    fun `souffle se pose sur le theme comme une palette`() {
        val typo = lire("res/values/typographie.xml")
        val souffle = typo.substringAfter("""<style name="Police.Souffle"""").substringBefore("</style>")
        assertTrue(souffle.contains("""<item name="android:fontFamily">@font/open_sans</item>"""))
        assertTrue(souffle.contains("""<item name="mhPoliceBouton">@font/open_sans_semibold</item>"""))
        assertTrue(souffle.contains("""<item name="mhStyleTitre">@style/Titre.Souffle</item>"""))
        // L'attribut fontFamily d'AppCompat passerait devant les polices fixées par les vues (hébreu, Varela Round).
        assertFalse(souffle.contains("""<item name="fontFamily">"""))
        assertTrue(typo.substringAfter("""<style name="Titre.Souffle"""").substringBefore("</style>").contains("@font/bellefair"))
        val base = lire("res/values/themes.xml").substringAfter("""<style name="Theme.MyHitbodedut"""").substringBefore("</style>")
        assertTrue(base.contains("""<item name="mhStyleTitre">@style/Titre.Systeme</item>"""))
        assertTrue(base.contains("""<item name="mhPoliceBouton">sans-serif-medium</item>"""))
        assertFalse("bouton figé", lire("res/values/themes.xml").contains("sans-serif-medium</item>\n        <item name=\"android:textSize"))
        val apparence = lire("java/com/myhitbodedut/Apparence.kt")
        assertEquals("police posée sur chaque écran et sur l'écran de blocage", 2,
            Regex("""Store\.police\((activity|base)\)\.style""").findAll(apparence).count())
    }

    @Test
    fun `les grands titres suivent la typographie et le minuteur garde ses chiffres`() {
        mapOf(
            "layout/activity_main.xml" to "@+id/hero_greeting", "layout-land/activity_main.xml" to "@+id/hero_greeting",
            "layout/activity_celebration.xml" to "@+id/celebration_title", "layout/view_blocker.xml" to "@+id/blocker_title",
        ).forEach { (fichier, id) ->
            val xml = lire("res/$fichier")
            val debut = xml.lastIndexOf("<TextView", xml.indexOf("android:id=\"$id\""))
            val bloc = xml.substring(debut, xml.indexOf("/>", debut))
            assertTrue("$fichier $id", bloc.contains("""style="?attr/mhStyleTitre""""))
            assertFalse("$fichier $id : gras simulé sur Bellefair", bloc.contains("textStyle"))
        }
        // Bellefair n'a pas de chiffres à chasse fixe : le minuteur tremblerait chaque seconde.
        val seance = lire("res/layout/activity_session.xml")
        val minuteur = seance.substring(seance.lastIndexOf("<TextView", seance.indexOf("@+id/session_countdown\"")))
            .substringBefore("/>")
        assertFalse(minuteur.contains("mhStyleTitre") || minuteur.contains("bellefair"))
    }

    @Test
    fun `l habillage et la typographie sont dans les reglages et la sauvegarde`() {
        val ecran = lire("res/layout/activity_settings.xml")
        listOf("habillage_button", "typo_button").forEach { assertTrue(it, ecran.contains("@+id/$it\"")) }
        val store = lire("java/com/myhitbodedut/Store.kt")
        assertTrue(store.contains(""".put("apparence_police", police(context).cle)"""))
        assertTrue(store.contains("""settings.optString("apparence_police")"""))
    }
}
