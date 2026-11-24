package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Le ciel en fond du Jour (24/11, TeintesCiel, PlanCiel) : chaque texte de la page garde les
 * seuils de PaletteTest à toute heure, de jour comme de nuit, pour chaque palette
 * « Fond » et « Accent », à toute hauteur du soleil ; lueur, nuages et collines compris. Les
 * étoiles jamais sous un texte (l'arc de l'astre : CielContinuTest).
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

    /** Les hauteurs du soleil parcourues : de la nuit noire au plein jour, tous les 4°. */
    private val hauteurs = (-24..60 step 4).map { it.toDouble() } + listOf(-1.0, 1.0, 2.0, 5.0)

    @Test
    fun `chaque texte reste lisible sur le ciel, a toute heure, lueur nuages et collines compris`() {
        val fautes = mutableListOf<String>()
        val tous = cas()
        assertTrue("palettes introuvables", tous.size >= 2 * 6 * 6)
        tous.forEach { k ->
            hauteurs.forEach { e ->
                listOf(true, false).forEach { matin ->
                    val t = TeintesCiel.pourCiel(e, matin, k.sombre, k.encres, k.papier)
                    // Tout le dégradé, et au-delà ; sous la lueur au plus fort, puis le bord et le corps des nuages.
                    val fonds = (0..64).map { t.degrade(it / 50f) }.flatMap { fond ->
                        val sousLueur = TeintesCiel.melange(fond, t.lueur, t.lueurAlpha.toDouble())
                        listOf(fond, sousLueur).flatMap { f ->
                            val bord = TeintesCiel.melange(f, t.bord, t.bordAlpha.toDouble())
                            listOf(f, bord, TeintesCiel.melange(f, t.corps, t.corpsAlpha.toDouble()), TeintesCiel.melange(bord, t.corps, t.corpsAlpha.toDouble()))
                        }
                    } + listOf(t.collineLoin, t.collinePres)
                    fonds.forEach { c ->
                        k.encres.forEach { en ->
                            val r = TeintesCiel.contraste(en.couleur, c)
                            if (r < en.seuil) fautes += "${k.nom} $e° ${if (matin) "matin" else "soir"} : %06X sur %06X = %.2f < %.1f".format(en.couleur and 0xFFFFFF, c and 0xFFFFFF, r, en.seuil)
                        }
                    }
                }
            }
        }
        assertTrue("contrastes insuffisants sur le ciel :\n" + fautes.distinct().take(40).joinToString("\n"), fautes.isEmpty())
    }

    /** La palette d'origine, vert : le ciel s'y voit bien, et chaque moment a sa couleur. */
    @Test
    fun `un vrai ciel dans les deux themes`() {
        val k = cas()
        listOf(false, true).forEach { sombre ->
            val origine = k.first { it.nom.startsWith("Fond.Vert × Accent.Vert") && it.sombre == sombre }
            fun ciel(e: Double, matin: Boolean) = TeintesCiel.pourCiel(e, matin, sombre, origine.encres, origine.papier)
            val nuit = ciel(-24.0, true)
            val jour = ciel(30.0, true)
            val coucher = ciel(0.0, false)
            listOf(nuit, jour, coucher, ciel(0.0, true)).forEach { t ->
                assertTrue("le ciel est resté le papier", t.haut != origine.papier || t.bas != origine.papier)
                if (sombre) assertTrue("un ciel sombre", TeintesCiel.luminance(t.haut) < 0.06)
                else assertTrue("un ciel pâle", TeintesCiel.luminance(t.haut) > 0.8)
            }
            // Le jour est bleu, le coucher rosé ou orangé à l'horizon, la nuit la plus sombre en thème sombre.
            assertTrue("le jour n'est pas bleu", (jour.haut and 0xFF) > ((jour.haut shr 16) and 0xFF))
            assertTrue("le coucher n'est pas chaud", ((coucher.bas shr 16) and 0xFF) > (coucher.bas and 0xFF))
            if (sombre) assertTrue("la nuit n'est pas la plus sombre", TeintesCiel.luminance(nuit.haut) <= TeintesCiel.luminance(jour.haut))
            // En thème sombre, le corps des nuages est une silhouette plus sombre que le ciel.
            if (sombre) assertTrue(TeintesCiel.luminance(jour.corps) < TeintesCiel.luminance(jour.haut))
        }
    }

    @Test
    fun `des encres impossibles laissent le papier`() {
        // Un gris moyen ne tient 7:1 sur aucun ciel : le papier reste, sans lueur ni nuage.
        val papier = 0xFF101A16.toInt()
        val t = TeintesCiel.pourCiel(30.0, true, true, listOf(TeintesCiel.Encre(0xFF777777.toInt(), 7.0)), papier)
        assertEquals(papier, t.haut)
        assertEquals(papier, t.bas)
        assertEquals(0f, t.lueurAlpha)
        assertEquals(0f, t.bordAlpha)
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
        // De 24 à 72 étoiles selon la taille de l'écran (elles s'allument avec le crépuscule, CielContinu.etoiles).
        assertEquals(24, PlanCiel.etoiles(320f, 300f).first)
        assertEquals(72, PlanCiel.etoiles(1280f, 800f).first)
    }
}
