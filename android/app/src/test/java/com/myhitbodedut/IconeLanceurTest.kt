package com.myhitbodedut

import android.content.pm.PackageManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * L'icône de lancement selon צדיק / צדקת et la couleur des boutons (29/10) :
 * une entrée du manifeste par combinaison, chacune avec son icône, sur une
 * plaque claire (la frange du détourage, voir LauncherIconTest).
 */
class IconeLanceurTest {

    private val manifeste = File("src/main/AndroidManifest.xml").readText()
    private val couleurs = File("src/main/res/values/colors.xml").readText()
    private val palettes = File("src/main/res/values/palettes.xml").readText()

    private fun couleur(nom: String, xml: String = couleurs): String? =
        Regex("""<color name="$nom">#([0-9A-Fa-f]{6})</color>""").find(xml)?.groupValues?.get(1)

    @Test
    fun `une entree par combinaison, le hassid sur le vert par defaut`() {
        val alias = Regex("""<activity-alias\s+android:name="\.(Icone_[a-z]+_[a-z]+)"\s+android:enabled="(true|false)"""")
            .findAll(manifeste).associate { it.groupValues[1] to (it.groupValues[2] == "true") }
        assertEquals(IconeLanceur.tous().map { it.removePrefix("com.myhitbodedut.") }.sorted(), alias.keys.sorted())
        assertEquals(listOf("Icone_m_vert"), alias.filterValues { it }.keys.toList())
        assertEquals("com.myhitbodedut.Icone_m_vert", IconeLanceur.PAR_DEFAUT)
        assertEquals("com.myhitbodedut.Icone_f_bordeaux", IconeLanceur.alias(Adresse.FEMME, Apparence.Accent.BORDEAUX))
        assertEquals("com.myhitbodedut.Icone_m_bleu", IconeLanceur.alias(null, Apparence.Accent.BLEU))
        // Une seule porte d'entrée : MainActivity ne se lance que par les alias.
        assertEquals(IconeLanceur.tous().size, Regex("category.LAUNCHER").findAll(manifeste).count())
    }

    @Test
    fun `chaque icone a son visage et la plaque claire de sa palette`() {
        listOf("m" to "ic_launcher_face", "f" to "ic_launcher_face_f").forEach { (g, visage) ->
            assertTrue(File("src/main/res/drawable-nodpi/$visage.webp").exists())
            Apparence.Accent.values().forEach { a ->
                val nom = "ic_launcher_${g}_${a.cle}"
                assertTrue("$nom dans le manifeste", "@mipmap/$nom\"" in manifeste)
                val xml = File("src/main/res/mipmap-anydpi/$nom.xml").readText()
                assertTrue(nom, "@drawable/$visage\"" in xml && "@color/icone_fond_${a.cle}\"" in xml)
                val hex = couleur("icone_fond_${a.cle}")!!
                val attendu = if (a == Apparence.Accent.VERT) couleur("mint")!!
                else Regex("""<style name="Accent\.${a.cle.replaceFirstChar { it.uppercase() }}"[\s\S]*?<item name="mhMint">#([0-9A-Fa-f]{6})""")
                    .find(palettes)!!.groupValues[1]
                assertEquals(nom, attendu.uppercase(), hex.uppercase())
                val clarte = (0..2).sumOf { hex.substring(it * 2, it * 2 + 2).toInt(16) } / 3
                assertTrue("$nom : fond trop sombre", clarte >= 200)
            }
        }
    }

    /**
     * FACCUEIL-01 (13/11) : éteindre l'entrée par laquelle l'application a été lancée fait retirer
     * sa tâche par Android. Le choix est seulement enregistré ; l'icône ne suit qu'à la sortie de
     * l'application, par les rappels de cycle de vie posés à son ouverture.
     */
    @Test
    fun `l icone ne change jamais ecran ouvert`() {
        val store = File("src/main/java/com/myhitbodedut/Store.kt").readText()
        listOf("fun setAdresse", "fun setAccent").forEach { f ->
            val corps = store.substringAfter(f).substringBefore("\n    }")
            assertFalse(f, "IconeLanceur" in corps)
        }
        val app = File("src/main/java/com/myhitbodedut/MyHitbodedutApp.kt").readText()
        assertTrue("IconeLanceur.installer(this)" in app)
        val code = File("src/main/java/com/myhitbodedut/IconeLanceur.kt").readText()
        // Une seule porte vers setComponentEnabledSetting : privée, appelée quand le dernier écran s'arrête.
        assertTrue("private fun appliquer(context: Context)" in code)
        val arret = code.substringAfter("override fun onActivityStopped").substringBefore("override fun onActivityCreated")
        assertTrue("visibles == 0 && !activity.isChangingConfigurations" in arret && "appliquer(application)" in arret)
        assertEquals(1, Regex("""\bappliquer\(""").findAll(code.replace("fun appliquer(", "")).count())
        // La présentation est marquée vue dès le choix צדיק / צדקת : la tâche peut être retirée à la sortie.
        val choisir = File("src/main/java/com/myhitbodedut/OnboardingActivity.kt").readText()
            .substringAfter("private fun choisir(adresse: Adresse)").substringBefore("\n    }")
        assertTrue("Store.setOnboarded(this)" in choisir)
    }

    private val defaut = PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
    private val allumee = PackageManager.COMPONENT_ENABLED_STATE_ENABLED
    private val eteinte = PackageManager.COMPONENT_ENABLED_STATE_DISABLED
    private fun nom(a: Adresse, c: Apparence.Accent) = IconeLanceur.alias(a, c)

    @Test
    fun `a l installation rien a poser, puis l entree voulue s allume avant que celle du manifeste ne s eteigne`() {
        val neuf = IconeLanceur.tous().associateWith { defaut }
        assertEquals(emptyList<Pair<String, Int>>(), IconeLanceur.changements(IconeLanceur.PAR_DEFAUT, neuf))
        val tsadeket = nom(Adresse.FEMME, Apparence.Accent.VERT)
        // Seule l'entrée du manifeste (enabled="true") passe par DISABLED.
        assertEquals(listOf(tsadeket to allumee, IconeLanceur.PAR_DEFAUT to eteinte), IconeLanceur.changements(tsadeket, neuf))
    }

    @Test
    fun `une entree eteinte retourne a l etat du manifeste, jamais a DISABLED`() {
        val tsadeket = nom(Adresse.FEMME, Apparence.Accent.VERT)
        val bleu = nom(Adresse.FEMME, Apparence.Accent.BLEU)
        val etats = IconeLanceur.tous().associateWith { defaut } + (tsadeket to allumee) + (IconeLanceur.PAR_DEFAUT to eteinte)
        assertEquals(emptyList<Pair<String, Int>>(), IconeLanceur.changements(tsadeket, etats))
        assertEquals(listOf(bleu to allumee, tsadeket to defaut), IconeLanceur.changements(bleu, etats))
        // Retour au hassid sur le vert : l'entrée du manifeste retrouve son état d'origine.
        assertEquals(listOf(IconeLanceur.PAR_DEFAUT to defaut, tsadeket to defaut), IconeLanceur.changements(IconeLanceur.PAR_DEFAUT, etats))
        // Quel que soit le départ, le résultat laisse une entrée active et une seule : la voulue.
        IconeLanceur.tous().forEach { voulu ->
            val apres = etats + IconeLanceur.changements(voulu, etats)
            assertEquals(listOf(voulu), IconeLanceur.tous().filter { IconeLanceur.active(it, apres.getValue(it)) })
            assertTrue(voulu, apres.filterValues { it == eteinte }.keys.all { it == IconeLanceur.PAR_DEFAUT })
        }
    }

    /** Les installations d'avant le 13/11 ont des entrées éteintes par DISABLED : on ne les retouche pas pour rien. */
    @Test
    fun `les entrees deja eteintes par DISABLED restent telles quelles`() {
        val bleu = nom(Adresse.HOMME, Apparence.Accent.BLEU)
        val ancien = IconeLanceur.tous().associateWith { eteinte } + (bleu to allumee)
        assertEquals(emptyList<Pair<String, Int>>(), IconeLanceur.changements(bleu, ancien))
        val violet = nom(Adresse.HOMME, Apparence.Accent.VIOLET)
        assertEquals(listOf(violet to allumee, bleu to defaut), IconeLanceur.changements(violet, ancien))
    }

    @Test
    fun `le changement attend que l application ait vraiment quitte l ecran`() {
        val nous = "com.myhitbodedut"
        assertTrue(IconeLanceur.peutBasculer(ecranAllume = true, seanceEnCours = false, sommets = listOf(nous), paquet = nous))
        assertTrue(IconeLanceur.peutBasculer(true, false, emptyList(), nous))
        assertTrue(IconeLanceur.peutBasculer(true, false, listOf(null), nous))
        // Écran éteint : on rallumera sur l'application.
        assertFalse(IconeLanceur.peutBasculer(false, false, listOf(nous), nous))
        // Une séance tourne, téléphone posé ou application quittée.
        assertFalse(IconeLanceur.peutBasculer(true, true, listOf(nous), nous))
        // Les réglages du téléphone ou le choix d'un fichier, ouverts au-dessus de nous dans notre tâche.
        assertFalse(IconeLanceur.peutBasculer(true, false, listOf("com.android.settings"), nous))
        assertFalse(IconeLanceur.peutBasculer(true, false, listOf(nous, "com.android.documentsui"), nous))
        // L'édition légère a son propre identifiant.
        assertTrue(IconeLanceur.peutBasculer(true, false, listOf("com.myhitbodedut.light"), "com.myhitbodedut.light"))
    }
}
