package com.myhitbodedut

import com.myhitbodedut.CielDuJour.Phase
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Le ciel en fond du Jour (24/11, TeintesCiel, PlanCiel) : chaque texte de la page garde les
 * seuils de PaletteTest dans les quatre phases, de jour comme de nuit, pour chaque palette
 * « Fond » et « Accent » ; lueur et nuages à leur plus fort compris. L'astre se pose à côté des
 * anneaux, les étoiles jamais sous un texte.
 */
class TeintesCielTest {

    private fun lire(chemin: String) = File("src/main/res/$chemin").readText()

    private fun couleurs(dossier: String): Map<String, String> =
        Regex("""<color name="([a-z0-9_]+)">(#[0-9A-Fa-f]{6,8})</color>""")
            .findAll(lire("$dossier/colors.xml")).associate { it.groupValues[1] to it.groupValues[2] }

    private fun styles(dossier: String): Map<String, Map<String, String>> =
        Regex("""<style name="([A-Za-z.]+)"[^>]*>([\s\S]*?)</style>""")
            .findAll(lire("$dossier/palettes.xml"))
            .associate { style ->
                style.groupValues[1] to Regex("""<item name="([A-Za-z:]+)">([^<]+)</item>""")
                    .findAll(style.groupValues[2]).associate { it.groupValues[1] to it.groupValues[2] }
            }

    private fun argb(hex: String): Int = (0xFF000000.toInt()) or hex.removePrefix("#").takeLast(6).toInt(16)

    /** Une combinaison de palettes : son nom, le papier, et les encres du Jour avec leurs seuils. */
    private data class Cas(val nom: String, val sombre: Boolean, val papier: Int, val encres: List<TeintesCiel.Encre>)

    private fun cas(): List<Cas> = listOf(false, true).flatMap { sombre ->
        val c = if (sombre) couleurs("values") + couleurs("values-night") else couleurs("values")
        val st = styles(if (sombre) "values-night" else "values")
        val fonds = mapOf("Fond.Vert" to mapOf("mhPaper" to c.getValue("paper"), "mhInk" to c.getValue("ink"), "mhMuted" to c.getValue("muted"))) +
            st.filterKeys { it.startsWith("Fond.") }
        val accents = mapOf("Accent.Vert" to c.getValue("brand")) +
            st.filterKeys { it.startsWith("Accent.") }.mapValues { it.value.getValue("mhBrand") }
        fonds.flatMap { (fn, f) ->
            accents.map { (an, brand) ->
                Cas("$fn × $an ${if (sombre) "sombre" else "clair"}", sombre, argb(f.getValue("mhPaper")), listOf(
                    TeintesCiel.Encre(argb(f.getValue("mhInk")), 7.0),
                    TeintesCiel.Encre(argb(f.getValue("mhMuted")), 4.5),
                    TeintesCiel.Encre(argb(brand), 4.5),
                    TeintesCiel.Encre(argb(c.getValue("ring_week_text")), 4.5),
                    TeintesCiel.Encre(argb(c.getValue("ring_streak_text")), 4.5),
                ))
            }
        }
    }

    @Test
    fun `chaque texte reste lisible sur le ciel, lueur et nuages compris`() {
        val fautes = mutableListOf<String>()
        val tous = cas()
        assertTrue("palettes introuvables", tous.size >= 2 * 6 * 6)
        tous.forEach { k ->
            Phase.values().forEach { phase ->
                val t = TeintesCiel.pourPage(phase, k.sombre, k.encres, k.papier)
                // Tout le dégradé, et au-delà (la couleur du bas continue sous la page).
                (0..200).map { t.degrade(it / 160f) }.forEach { fond ->
                    // Sous la lueur au plus fort, puis sous un nuage au plus fort par-dessus.
                    val sousLueur = TeintesCiel.melange(fond, t.lueur, t.lueurAlpha.toDouble())
                    listOf(fond, sousLueur,
                        TeintesCiel.melange(fond, t.nuage, t.nuageAlpha.toDouble()),
                        TeintesCiel.melange(sousLueur, t.nuage, t.nuageAlpha.toDouble())).forEach { c ->
                        k.encres.forEach { e ->
                            val r = TeintesCiel.contraste(e.couleur, c)
                            if (r < e.seuil) fautes += "${k.nom} $phase : %06X sur %06X = %.2f < %.1f".format(e.couleur and 0xFFFFFF, c and 0xFFFFFF, r, e.seuil)
                        }
                    }
                }
            }
        }
        assertTrue("contrastes insuffisants sur le ciel :\n" + fautes.distinct().take(40).joinToString("\n"), fautes.isEmpty())
    }

    /** La palette d'origine, vert : le ciel s'y voit bien, et chaque phase a sa couleur. */
    @Test
    fun `un vrai ciel dans les deux themes`() {
        val k = cas()
        listOf(false, true).forEach { sombre ->
            val origine = k.first { it.nom.startsWith("Fond.Vert × Accent.Vert") && it.sombre == sombre }
            val ciels = Phase.values().associateWith { TeintesCiel.pourPage(it, sombre, origine.encres, origine.papier) }
            ciels.forEach { (phase, t) ->
                assertTrue("$phase $sombre : le ciel est resté le papier", t.haut != origine.papier || t.bas != origine.papier)
                if (sombre) assertTrue("$phase : un ciel sombre", TeintesCiel.luminance(t.haut) < 0.06)
                else assertTrue("$phase : un ciel pâle", TeintesCiel.luminance(t.haut) > 0.8)
            }
            // Le jour est bleu, l'aube et le coucher tirent vers le rose et le violet, la nuit est la plus sombre.
            val jour = ciels.getValue(Phase.JOUR).haut
            assertTrue("le jour n'est pas bleu", (jour and 0xFF) > ((jour shr 16) and 0xFF))
            val coucher = ciels.getValue(Phase.COUCHER).milieu
            assertTrue("le coucher n'est pas rosé", ((coucher shr 16) and 0xFF) > ((coucher shr 8) and 0xFF))
            if (sombre) assertTrue("la nuit n'est pas la plus sombre",
                Phase.values().all { TeintesCiel.luminance(ciels.getValue(Phase.NUIT).haut) <= TeintesCiel.luminance(ciels.getValue(it).haut) })
            // La nuit n'a pas de nuages ; le jour en a, pâles.
            assertEquals(0f, ciels.getValue(Phase.NUIT).nuageAlpha)
            assertTrue(ciels.getValue(Phase.JOUR).nuageAlpha in 0f..0.75f)
        }
    }

    @Test
    fun `des encres impossibles laissent le papier`() {
        // Un gris moyen ne tient 7:1 sur aucun ciel : le papier reste, sans lueur ni nuage.
        val papier = 0xFF101A16.toInt()
        val t = TeintesCiel.pourPage(Phase.JOUR, true, listOf(TeintesCiel.Encre(0xFF777777.toInt(), 7.0)), papier)
        assertEquals(papier, t.haut)
        assertEquals(papier, t.bas)
        assertEquals(0f, t.lueurAlpha)
        assertEquals(0f, t.nuageAlpha)
    }

    @Test
    fun `assombrir ou eclaircir garde la teinte`() {
        val bleu = 0xFF5FB1EA.toInt()
        val sombre = TeintesCiel.aLuminance(bleu, 0.03)
        assertTrue(TeintesCiel.luminance(sombre) <= 0.03)
        assertEquals(TeintesCiel.hsl(bleu)[0], TeintesCiel.hsl(sombre)[0], 0.02)
        val pale = TeintesCiel.aLuminance(bleu, 0.86)
        assertTrue(TeintesCiel.luminance(pale) >= 0.86)
        assertEquals(TeintesCiel.hsl(bleu)[0], TeintesCiel.hsl(pale)[0], 0.02)
    }

    // --- Le plan ---------------------------------------------------------------------------

    private val d = 2.625f
    /** Un Pixel 6 debout : 411 dp de large, des anneaux de 260 dp centrés, 180 dp sous le haut. */
    private val largeur = 411 * d
    private val jauge = PlanCiel.Zone(75.5f * d, 180 * d, 335.5f * d, 440 * d)
    private val textes = listOf(
        PlanCiel.Zone(24 * d, 8 * d, 200 * d, 56 * d),       // la date hébraïque
        PlanCiel.Zone(24 * d, 64 * d, 387 * d, 160 * d),     // le salut et les lignes d'état
        PlanCiel.Zone(24 * d, 444 * d, 387 * d, 520 * d),    // la légende et le palier
    )

    @Test
    fun `l astre se pose a cote des anneaux, loin des textes`() {
        Phase.values().forEach { phase ->
            val p = PlanCiel.astre(phase, jauge, largeur, textes, d)
            assertNotNull("$phase sans astre", p)
            val (x, y) = p!![0] to p[1]
            val couronne = PlanCiel.rayon(phase) * d * PlanCiel.COURONNE
            assertTrue("$phase : pas à côté des anneaux", x + PlanCiel.rayon(phase) * d <= jauge.gauche || x - PlanCiel.rayon(phase) * d >= jauge.droite)
            assertTrue("$phase : sur un texte", textes.none { it.touche(x, y, couronne) })
            assertTrue("$phase : hors de l'écran", x - PlanCiel.rayon(phase) * d >= 0 && x + PlanCiel.rayon(phase) * d <= largeur)
            // L'aube à gauche, le reste à droite.
            assertEquals("$phase : mauvais côté", phase == Phase.AUBE, x < jauge.gauche)
        }
        // Le jour et la nuit haut, l'aube et le coucher bas.
        assertTrue(PlanCiel.astre(Phase.JOUR, jauge, largeur, textes, d)!![1] < PlanCiel.astre(Phase.COUCHER, jauge, largeur, textes, d)!![1])
    }

    @Test
    fun `sans place a cote des anneaux, pas d astre`() {
        // Accueil couché : les anneaux au bord, le texte juste à côté d'eux.
        val couche = PlanCiel.Zone(16 * d, 4 * d, 252 * d, 240 * d)
        val colonne = listOf(PlanCiel.Zone(268 * d, 4 * d, 800 * d, 400 * d))
        assertNull(PlanCiel.astre(Phase.JOUR, couche, 820 * d, colonne, d))
    }

    @Test
    fun `aucune etoile sous un texte ni sur les anneaux`() {
        val etoiles = CielVivant.etoiles(60, 29L, 0.7f, 1.7f)
        val hauteur = 700 * d * 0.78f
        val zones = textes + jauge
        val libres = PlanCiel.libres(etoiles, largeur, hauteur, zones, d)
        assertTrue("trop d'étoiles écartées", libres.count { it } >= 15)
        val ecart = (PlanCiel.MARGE_DP + CielVivant.DERIVE_X_DP) * d
        libres.forEachIndexed { i, libre ->
            if (!libre) return@forEachIndexed
            val x = etoiles[i * CielVivant.CHAMPS] * largeur
            val y = etoiles[i * CielVivant.CHAMPS + 1] * hauteur
            assertTrue("étoile $i sous un texte", zones.none { it.touche(x, y, ecart) })
        }
        // La nuit, de 24 à 72 étoiles selon la taille de l'écran ; le jour, aucune.
        assertEquals(24, PlanCiel.etoiles(Phase.NUIT, true, 320f, 300f).first)
        assertEquals(72, PlanCiel.etoiles(Phase.NUIT, true, 1280f, 800f).first)
        assertEquals(0, PlanCiel.etoiles(Phase.JOUR, true, 411f, 700f).first)
        assertEquals(0, PlanCiel.etoiles(Phase.AUBE, false, 411f, 700f).first)
    }
}
