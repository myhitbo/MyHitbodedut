package com.myhitbodedut

import com.kosherjava.zmanim.hebrewcalendar.JewishCalendar
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import kotlin.math.abs
import kotlin.math.hypot

/**
 * Le ciel continu (24/11) : les clés de couleurs (CielContinu) sans saut d'une minute à l'autre,
 * sur des journées entières simulées minute par minute (y compris là où le soleil reste bas à
 * midi ou haut à minuit, au nord), le matin et le soir et leur passage, les étapes du jour (nuit
 * noire, bleu du crépuscule, rouges, jaunes, heure dorée, bleu du jour, orange, violet), la lune
 * du mois hébreu contre le molad et la lune vraie, et l'arc de l'astre (PlanCiel.arc). Le soleil
 * lui-même : SoleilTest. Les mêmes cas côté web (ciel.test.mjs).
 */
class CielContinuTest {

    private fun canal(c: Int, d: Int) = (c shr d) and 0xFF

    @Test
    fun `aucune minute ne saute`() {
        listOf(true, false).forEach { matin ->
            var avant = CielContinu.brutes(-30.0, matin)
            var e = -30.0
            while (e <= 70.0) {
                val c = CielContinu.brutes(e, matin)
                for (i in 0..2) for (d in intArrayOf(0, 8, 16)) {
                    assertTrue("$matin $e° : ${CielContinu.hexa(avant[i])} → ${CielContinu.hexa(c[i])}", abs(canal(c[i], d) - canal(avant[i], d)) <= 8)
                }
                avant = c
                e += 0.25
            }
        }
        // Un quart de degré, c'est une minute ou deux de soleil : les dosages aussi glissent (la
        // lueur, la plus vive, s'éteint en 3° : 0,125 par quart de degré au plus).
        var e = -30.0
        while (e <= 70.0) {
            listOf(CielContinu::etoiles, CielContinu::nuages, CielContinu::rayons, CielContinu::soleilVisible, CielContinu::luneVisible, CielContinu::lueurVisible, CielContinu::chaleur).forEach { f ->
                assertTrue("$e°", abs(f(e + 0.25) - f(e)) <= 0.13)
            }
            e += 0.25
        }
    }

    @Test
    fun `le matin et le soir se rejoignent a midi et a minuit`() {
        // Le matin, tout le matin ; le soir, tout le soir ; moitié-moitié au méridien.
        assertEquals(1.0, CielContinu.partMatin(-90.0), 1e-12)
        assertEquals(1.0, CielContinu.partMatin(-15.0), 1e-12)
        assertEquals(0.0, CielContinu.partMatin(90.0), 1e-12)
        assertEquals(0.0, CielContinu.partMatin(15.0), 1e-12)
        listOf(0.0, 180.0, -180.0).forEach { assertEquals(0.5, CielContinu.partMatin(it), 1e-12) }
        assertEquals(1.0, CielContinu.partMatin(-165.0), 1e-12)
        assertEquals(0.0, CielContinu.partMatin(165.0), 1e-12)
        // Sans saut de −180° à 180° (minuit), ni d'un dixième de degré à l'autre.
        var h = -180.0
        while (h < 180.0) {
            assertTrue("$h", abs(CielContinu.partMatin(h + 0.1) - CielContinu.partMatin(h)) < 0.01)
            h += 0.1
        }
        assertEquals(CielContinu.partMatin(-179.99), CielContinu.partMatin(179.99), 2e-3)
        // Le mélange passe entre les deux suites ; aux bouts, ce sont elles.
        for (e in listOf(-10.0, -4.0, 0.0, 3.0, 7.0)) {
            val m = CielContinu.brutes(e, true)
            val s = CielContinu.brutes(e, false)
            val mi = CielContinu.brutes(e, 0.5)
            for (i in 0..2) for (d in intArrayOf(0, 8, 16)) {
                assertTrue(canal(mi[i], d) in minOf(canal(m[i], d), canal(s[i], d))..maxOf(canal(m[i], d), canal(s[i], d)))
            }
            assertTrue(CielContinu.brutes(e, 1.0).contentEquals(m) && CielContinu.brutes(e, 0.0).contentEquals(s))
        }
    }

    // --- Des journées entières, minute par minute --------------------------------------------

    private class Lieu(val nom: String, val lat: Double, val lon: Double, val fuseau: String)

    private val lieux = listOf(
        Lieu("Jérusalem", 31.778, 35.235, "Asia/Jerusalem"), Lieu("Paris", 48.857, 2.352, "Europe/Paris"),
        Lieu("New York", 40.713, -74.006, "America/New_York"), Lieu("Sydney", -33.869, 151.209, "Australia/Sydney"),
        // Au nord : le soleil de midi reste sous 12° l'hiver, celui de minuit au-dessus de −18° l'été.
        Lieu("Stockholm", 59.33, 18.07, "Europe/Stockholm"), Lieu("Moscou", 55.756, 37.617, "Europe/Moscow"),
        // Nuit polaire et jour polaire.
        Lieu("Tromsø", 69.649, 18.955, "Europe/Oslo"),
    )
    private val jours = listOf(LocalDate.of(2026, 3, 20), LocalDate.of(2026, 6, 21), LocalDate.of(2026, 11, 24), LocalDate.of(2026, 12, 21))

    /** Chaque minute d'un jour local, de minuit à minuit. */
    private fun journee(l: Lieu, jour: LocalDate): List<EtatCiel> {
        val debut = jour.atStartOfDay(ZoneId.of(l.fuseau)).toInstant().toEpochMilli()
        return (0..24 * 60).map { EtatCiel.de(Soleil.position(debut + it * 60_000L, l.lat, l.lon), 15) }
    }

    private fun saut(a: Int, b: Int) = intArrayOf(0, 8, 16).maxOf { abs(canal(a, it) - canal(b, it)) }

    @Test
    fun `des journees entieres sans a-coup, au nord comme au sud`() {
        val fautes = mutableListOf<String>()
        lieux.forEach { l ->
            jours.forEach { jour ->
                val etats = journee(l, jour)
                for (m in 1 until etats.size) {
                    val a = etats[m - 1]
                    val b = etats[m]
                    val ca = CielContinu.brutes(a.hauteur, a.matin)
                    val cb = CielContinu.brutes(b.hauteur, b.matin)
                    val s = (0..2).maxOf { saut(ca[it], cb[it]) }
                    if (s > 8) fautes += "${l.nom} $jour ${m / 60} h ${m % 60} : %.2f° → %.2f°, matin %.2f → %.2f, saut de $s".format(a.hauteur, b.hauteur, a.matin, b.matin)
                    // L'astre paraît et s'efface en douceur, même au jour et à la nuit polaires (le
                    // soleil le plus rapide, à l'équateur, monte d'un quart de degré par minute).
                    if (abs(a.astreVisible - b.astreVisible) > 0.13 || abs(a.lueurVisible - b.lueurVisible) > 0.13) {
                        fautes += "${l.nom} $jour ${m / 60} h ${m % 60} : l'astre %.2f → %.2f, sa lueur %.2f → %.2f".format(a.astreVisible, b.astreVisible, a.lueurVisible, b.lueurVisible)
                    }
                }
            }
        }
        assertTrue("à-coups :\n" + fautes.take(30).joinToString("\n"), fautes.isEmpty())
    }

    @Test
    fun `l astre ne saute pas d un bord a l autre`() {
        // Le Pixel 6 de la fin du fichier, sans texte à côté des anneaux : l'astre visible, hors du
        // disque des anneaux, avance d'au plus 8 dp par minute ; plus vite seulement quand tout son
        // arc dure une heure ou deux (Tromsø fin novembre), où il glisse derrière les anneaux, vers
        // midi, en quelques minutes : au plus 2 500 dp par arc entier (3,5 dp par minute un jour de
        // douze heures).
        val fautes = mutableListOf<String>()
        val cx = (jauge.gauche + jauge.droite) / 2
        val cy = (jauge.haut + jauge.bas) / 2
        val rayonAnneaux = (jauge.droite - jauge.gauche) / 2
        fun place(e: EtatCiel): FloatArray? {
            val soleil = e.estSoleil
            val p = PlanCiel.arc(if (soleil) e.progresJour else e.progresNuit, CielContinu.elevationDessinee(if (soleil) e.hauteur else -e.hauteur),
                jauge, largeur, r, couronne, textes, d) ?: return null
            // Caché derrière les anneaux, il peut passer vite : on ne le voit pas.
            return if (hypot(p[0] - cx, p[1] - cy) + r < rayonAnneaux) null else p
        }
        lieux.forEach { l ->
            jours.forEach { jour ->
                val etats = journee(l, jour)
                for (m in 1 until etats.size) {
                    val a = etats[m - 1]
                    val b = etats[m]
                    if (a.astreVisible < 0.05 || b.astreVisible < 0.05 || a.estSoleil != b.estSoleil) continue
                    val pa = place(a) ?: continue
                    val pb = place(b) ?: continue
                    val pas = hypot(pb[0] - pa[0], pb[1] - pa[1]) / d
                    val arcEntier = if (a.estSoleil) abs(b.progresJour - a.progresJour) else abs(b.progresNuit - a.progresNuit)
                    if (pas > maxOf(8.0, 2500 * arcEntier)) fautes += "${l.nom} $jour ${m / 60} h ${m % 60} : ${if (a.estSoleil) "le soleil" else "la lune"} fait %.1f dp".format(pas)
                }
            }
        }
        assertTrue("sauts de l'astre :\n" + fautes.take(30).joinToString("\n"), fautes.isEmpty())
    }

    @Test
    fun `les etapes du jour`() {
        fun lum(c: Int) = TeintesCiel.luminance(c)
        // La nuit noire, sous −18°.
        assertTrue(CielContinu.brutes(-25.0, true).all { lum(it) < 0.03 })
        // Le lever et le coucher : l'horizon rouge-orangé, le soir plus orangé que le matin.
        listOf(true, false).forEach { matin ->
            val h = CielContinu.brutes(0.0, matin)[2]
            assertTrue(canal(h, 16) > canal(h, 8) && canal(h, 8) > canal(h, 0))
        }
        assertTrue(canal(CielContinu.brutes(0.0, false)[2], 8) < canal(CielContinu.brutes(0.0, true)[2], 8))
        // Les jaunes du matin, l'heure dorée.
        val jaune = CielContinu.brutes(3.0, true)[2]
        assertTrue(canal(jaune, 16) > 240 && canal(jaune, 8) > 200 && canal(jaune, 0) < 180)
        // Le bleu du jour.
        CielContinu.brutes(40.0, true).forEach { assertTrue(canal(it, 0) > canal(it, 16)) }
        // Le violet du crépuscule le soir.
        val violet = CielContinu.brutes(-4.0, false)[1]
        assertTrue(canal(violet, 0) > canal(violet, 8) && canal(violet, 16) > canal(violet, 8))
        // Les étoiles : aucune à −4°, toutes à −14° ; les rayons seulement à l'heure dorée.
        assertEquals(0.0, CielContinu.etoiles(-4.0), 1e-9)
        assertEquals(1.0, CielContinu.etoiles(-14.0), 1e-9)
        assertEquals(0.0, CielContinu.rayons(-2.0), 1e-9)
        assertEquals(1.0, CielContinu.rayons(3.0), 1e-9)
        assertEquals(0.0, CielContinu.rayons(12.0), 1e-9)
        // Les nuages, presque rien la nuit ; blancs le jour, dorés bas.
        assertTrue(CielContinu.nuages(-20.0) < 0.2 && CielContinu.nuages(5.0) == 1.0)
        assertEquals(0xFFFFFFFF.toInt(), CielContinu.NUAGE_CORPS.a(30.0))
        val dore = CielContinu.NUAGE_BORD.a(3.0)
        assertTrue(canal(dore, 16) > canal(dore, 0) + 80)
    }

    @Test
    fun `la lune du mois hebreu est celle du molad, et a peu pres la vraie`() {
        // Chaque soir de 2026 et 2027 à 21 h à Jérusalem : le jour hébreu affiché (celui qui a
        // commencé à la tombée de la nuit, ZmanimVignette.jourHebreuAffiche), l'âge que la lune en
        // reçoit, l'âge depuis le molad du mois (KosherJava) et celui de la lune moyenne (nouvelle
        // lune du 6/1/2000 à 18 h 14 UTC, lunaison de 29,530589 jours).
        val zone = ZoneId.of("Asia/Jerusalem")
        var jour = LocalDate.of(2026, 1, 1)
        while (jour.year < 2028) {
            val soir = ZonedDateTime.of(jour.atTime(21, 0), zone)
            val hebreu = jour.plusDays(1)
            val l = CielContinu.lune(CalendrierJuif.jour(hebreu, true).jourHebreu)
            val molad = JewishCalendar(hebreu).moladAsDate.time
            val depuisMolad = (soir.toInstant().toEpochMilli() - molad) / 86_400_000.0
            val vraie = ((soir.toInstant().toEpochMilli() / 86_400_000.0 + 2440587.5 - 2451550.26) % CielContinu.MOIS_LUNAIRE + CielContinu.MOIS_LUNAIRE) % CielContinu.MOIS_LUNAIRE
            fun ecart(x: Double, y: Double) = abs(x - y).let { minOf(it, CielContinu.MOIS_LUNAIRE - it) }
            // Roch 'Hodech tombe le jour du molad ou jusqu'à deux jours après ; la lune moyenne
            // s'écarte de la vraie d'une demi-journée environ : deux jours d'âge au plus, la part
            // éclairée à 0,2 près.
            assertTrue("$jour : âge ${l.age} pour ${"%.2f".format(depuisMolad)} jours depuis le molad", ecart(l.age, depuisMolad) <= 2.1)
            assertTrue("$jour : âge ${l.age} pour une lune moyenne de ${"%.2f".format(vraie)} jours", ecart(l.age, vraie) <= 2.1)
            jour = jour.plusDays(1)
        }
        // La pleine lune du 24 novembre 2026 (vers 15 h UTC) : le soir, 15 Kislev, la lune est pleine.
        val ce = CalendrierJuif.jour(LocalDate.of(2026, 11, 25), true)
        assertEquals(15, ce.jourHebreu)
        assertTrue(CielContinu.lune(ce.jourHebreu).eclairee > 0.98)
    }

    @Test
    fun `la lune suit le mois hebreu`() {
        assertTrue(CielContinu.lune(1).eclairee < 0.02 && CielContinu.lune(2).eclairee < 0.06 && CielContinu.lune(2).croissante)
        assertEquals(0.5, CielContinu.lune(8).eclairee, 0.08)
        assertTrue(CielContinu.lune(15).eclairee > 0.98)
        assertTrue(!CielContinu.lune(22).croissante)
        assertEquals(0.5, CielContinu.lune(23).eclairee, 0.1)
        assertTrue(CielContinu.lune(29).eclairee < 0.04)
    }

    // --- L'arc ------------------------------------------------------------------------------

    private val d = 2.625f
    private val largeur = 411 * d
    private val jauge = PlanCiel.Zone(75.5f * d, 180 * d, 335.5f * d, 440 * d)
    private val textes = listOf(PlanCiel.Zone(24 * d, 64 * d, 387 * d, 160 * d), PlanCiel.Zone(24 * d, 444 * d, 387 * d, 520 * d))
    private val r = 14 * d
    private val couronne = r * PlanCiel.COURONNE

    private fun arc(p: Double, h: Double) = PlanCiel.arc(p, h, jauge, largeur, r, couronne, textes, d)

    @Test
    fun `le soleil se leve a gauche et se couche a droite, derriere les anneaux a midi`() {
        val lever = arc(0.0, 0.0)!!
        assertTrue(lever[0] < jauge.gauche && lever[1] <= jauge.bas - couronne + 0.1f)
        val coucher = arc(1.0, 0.0)!!
        assertTrue(coucher[0] > jauge.droite)
        val midi = arc(0.5, 0.6)!!
        assertEquals((jauge.gauche + jauge.droite) / 2, midi[0], 0.5f)
        // Il monte avec sa hauteur, sans jamais sortir de la hauteur des anneaux.
        var avant = Float.MAX_VALUE
        for (k in 0..20) {
            val y = arc(0.2, k / 20.0)!![1]
            assertTrue(y <= avant && y - couronne >= jauge.haut - 0.1f && y + couronne <= jauge.bas + 0.1f)
            avant = y
        }
        // Il s'attarde dans les marges : au premier quart du jour, encore à gauche des anneaux.
        assertTrue(arc(0.2, 0.3)!![0] < jauge.gauche + r)
        // De gauche à droite, toujours.
        var x = -1f
        for (k in 0..40) { val n = arc(k / 40.0, 0.3)!![0]; assertTrue(n >= x); x = n }
    }

    @Test
    fun `il longe les anneaux au lieu de s y cacher, sauf vers midi`() {
        // Un jour sans lieu (levé à 6 h 30, couché à 18 h 30), minute par minute : le centre du
        // soleil n'entre dans le disque des anneaux qu'une heure et demie au plus, autour de midi ;
        // à 10 h, 11 h 30, 13 h 30 et 15 h, on le voit (il y était caché de 10 h à 15 h).
        val cx = (jauge.gauche + jauge.droite) / 2
        val cy = (jauge.haut + jauge.bas) / 2
        val rayonAnneaux = (jauge.droite - jauge.gauche) / 2
        fun dehors(heure: Double): Boolean {
            val p = Soleil.parHeure(heure)
            val rr = CielContinu.rayonSoleil(p.hauteur) * d
            val a = PlanCiel.arc(p.progresJour, CielContinu.elevationDessinee(p.hauteur), jauge, largeur, rr, rr * PlanCiel.COURONNE, textes, d)!!
            return hypot(a[0] - cx, a[1] - cy) > rayonAnneaux
        }
        val caches = (6 * 60 + 35..18 * 60 + 25).filter { !dehors(it / 60.0) }
        assertTrue("caché ${caches.size} minutes", caches.size <= 90 && caches.all { abs(it - 12 * 60 - 30) <= 45 })
        assertTrue(dehors(10.0) && dehors(15.0) && dehors(11.5) && dehors(13.5))
    }

    @Test
    fun `sur un ecran etroit, l astre s arrete au bord au lieu de disparaitre`() {
        // 320 dp de large, des anneaux de 290 dp : 15 dp de marge, moins que le disque.
        val etroit = PlanCiel.Zone(15 * d, 180 * d, 305 * d, 440 * d)
        var x = -1f
        for (k in 0..40) {
            val p = PlanCiel.arc(k / 40.0, 0.2, etroit, 320 * d, r, couronne, emptyList(), d)
            assertNotNull("progrès ${k / 40.0}", p)
            assertTrue(p!![0] >= r - 0.01f && p[0] <= 320 * d - r + 0.01f && p[0] >= x)
            x = p[0]
        }
        assertEquals(r, PlanCiel.arc(0.0, 0.0, etroit, 320 * d, r, couronne, emptyList(), d)!![0], 0.01f)
    }

    @Test
    fun `jamais sous un texte`() {
        // Un texte posé à côté des anneaux : l'astre ne s'y montre pas.
        val gene = textes + PlanCiel.Zone(0f, 300 * d, 70 * d, 340 * d)
        assertNull(PlanCiel.arc(0.0, 0.3, jauge, largeur, r, couronne, gene, d))
        assertNotNull(PlanCiel.arc(1.0, 0.3, jauge, largeur, r, couronne, gene, d))
    }
}
