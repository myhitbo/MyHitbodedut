package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId

/**
 * Birkat haLevana (13/10) : la fenêtre de 'Hechvan 5787, de sept jours après le
 * molad jusqu'à la mi-mois, est du 18 au 25 octobre 2026 au soir — ce qu'affiche
 * CalJ pour Jérusalem (capture du propriétaire, 14/10).
 */
class LevanaTest {

    private val zone = ZoneId.of("Asia/Jerusalem")

    @Test
    fun `Hechvan 5787 du 18 au 25 octobre`() {
        val f = Levana.fenetre(LocalDate.of(2026, 10, 14), zone)
        assertEquals(LocalDate.of(2026, 10, 18), f.premierSoir(zone))
        assertEquals(LocalDate.of(2026, 10, 25), f.dernierSoir(zone))
        assertEquals(Levana.Etat.Dans(4), Levana.etat(f, LocalDate.of(2026, 10, 14), zone))
        assertEquals(Levana.Etat.CeSoir, Levana.etat(f, LocalDate.of(2026, 10, 18), zone))
        assertEquals(Levana.Etat.DernierSoir, Levana.etat(f, LocalDate.of(2026, 10, 25), zone))
        assertTrue(Levana.part(f, f.debut) < Levana.part(f, f.fin))
    }

    // Audit du 12/11, FCALENDRIER-03 : quand la fenêtre se ferme l'après-midi, le dernier soir est la veille.
    @Test
    fun `Kislev 5787, la mi-mois tombe l apres-midi du 24 novembre a Paris, dernier soir le 23`() {
        val paris = ZoneId.of("Europe/Paris")
        for (usage in listOf(Levana.Usage.TROIS_MI_MOIS, Levana.Usage.SEPT_MI_MOIS)) {
            val f = Levana.fenetre(LocalDate.of(2026, 11, 20), paris, usage)
            assertEquals(LocalDate.of(2026, 11, 23), f.dernierSoir(paris))
            // Le soir du 24 (tsét à 17 h 53) la fenêtre est fermée (15 h 28) : plus de « dernier soir ».
            assertTrue(f.fin.isBefore(Levana.soir(LocalDate.of(2026, 11, 24), paris)))
            assertEquals(Levana.Etat.DernierSoir, Levana.etat(f, LocalDate.of(2026, 11, 23), paris))
            assertEquals(Levana.Etat.CeSoir, Levana.etat(f, LocalDate.of(2026, 11, 22), paris))
            // Le 24, c'est déjà la fenêtre suivante.
            assertTrue(Levana.etat(Levana.fenetre(LocalDate.of(2026, 11, 24), paris, usage), LocalDate.of(2026, 11, 24), paris) is Levana.Etat.Dans)
        }
        // Quinze jours : la fin est à 21 h 06 à Paris, le dernier soir reste le 24 ; à New York (15 h 06), le 23.
        assertEquals(LocalDate.of(2026, 11, 24), Levana.fenetre(LocalDate.of(2026, 11, 20), paris, Levana.Usage.SEPT_QUINZE).dernierSoir(paris))
        val ny = ZoneId.of("America/New_York")
        assertEquals(LocalDate.of(2026, 11, 23), Levana.fenetre(LocalDate.of(2026, 11, 20), ny, Levana.Usage.SEPT_QUINZE).dernierSoir(ny))
    }

    @Test
    fun `la fenetre passee, celle du mois suivant`() {
        val f = Levana.fenetre(LocalDate.of(2026, 10, 26), zone)
        assertTrue(f.premierSoir(zone).isAfter(LocalDate.of(2026, 11, 1)))
        assertTrue(Levana.etat(f, LocalDate.of(2026, 10, 26), zone) is Levana.Etat.Dans)
    }

    // Revue du 14/10 sur le texte (Choulhan Aroukh O.H. 426 ; Michna Beroura 426), mêmes valeurs que le web.

    @Test
    fun `trois usages, Hechvan 5787`() {
        val trois = Levana.fenetre(LocalDate.of(2026, 10, 14), zone, Levana.Usage.TROIS_MI_MOIS)
        assertEquals(LocalDate.of(2026, 10, 14), trois.premierSoir(zone))
        assertEquals(LocalDate.of(2026, 10, 25), trois.dernierSoir(zone))
        val quinze = Levana.fenetre(LocalDate.of(2026, 10, 14), zone, Levana.Usage.SEPT_QUINZE)
        assertEquals(LocalDate.of(2026, 10, 18), quinze.premierSoir(zone))
        // Quinze jours depuis le molad : plus tard que la mi-mois (14 j 18 h 22 min).
        assertTrue(quinze.fin.isAfter(trois.fin))
        assertEquals(java.time.Duration.ofDays(15), java.time.Duration.between(quinze.molad, quinze.fin))
    }

    @Test
    fun `motsae Chabbat conseille avant le 10`() {
        val trois = Levana.fenetre(LocalDate.of(2026, 10, 14), zone, Levana.Usage.TROIS_MI_MOIS)
        // Samedi 17/10 : sa nuit est le 8 'Hechvan.
        assertEquals(LocalDate.of(2026, 10, 17), Levana.motsaeChabbat(trois, LocalDate.of(2026, 10, 14), zone))
        // Sept jours : le premier samedi (24/10) a sa nuit le 15, rien de conseillé.
        val sept = Levana.fenetre(LocalDate.of(2026, 10, 14), zone, Levana.Usage.SEPT_MI_MOIS)
        assertEquals(null, Levana.motsaeChabbat(sept, LocalDate.of(2026, 10, 14), zone))
    }

    @Test
    fun `pas avant Kippour ni Ticha beAv`() {
        val tichri = Levana.fenetre(LocalDate.of(2026, 9, 15), zone, Levana.Usage.TROIS_MI_MOIS)
        assertEquals(LocalDate.of(2026, 9, 21), tichri.premierSoir(zone)) // Kippour 5787 : lundi 21/9
        assertEquals(Levana.Restriction.KIPPOUR, tichri.restriction)
        val av = Levana.fenetre(LocalDate.of(2026, 7, 20), zone, Levana.Usage.TROIS_MI_MOIS)
        assertEquals(LocalDate.of(2026, 7, 23), av.premierSoir(zone)) // 9 Av 5786 : jeudi 23/7
        assertEquals(Levana.Restriction.TISHA_BEAV, av.restriction)
    }

    // --- Audit du 16/11 (mêmes valeurs que web/test/levana.test.mjs) ---------------------------------

    private val jer = Zmanim.Lieu("Jérusalem", 31.76904, 35.21633, 0.0, "Asia/Jerusalem")
    private val parisLieu = Zmanim.Lieu("Paris", 48.85341, 2.3488, 0.0, "Europe/Paris")
    private fun fen(iso: String, lieu: Zmanim.Lieu, usage: Levana.Usage): Levana.Fenetre {
        val z = ZoneId.of(lieu.fuseau)
        return Levana.fenetre(LocalDate.parse(iso), z, usage, Levana.Horaires.du(lieu, z))
    }

    @Test
    fun `audit du 16-11, le dernier soir d apres la tset`() {
        for (usage in listOf(Levana.Usage.SEPT_QUINZE, Levana.Usage.SEPT_NUIT_QUINZE)) {
            assertEquals(LocalDate.of(2025, 12, 4), fen("2025-12-03", parisLieu, usage).dernier)
            assertEquals(LocalDate.of(2025, 12, 4), fen("2025-12-03", jer, usage).dernier)
            assertEquals(LocalDate.of(2026, 2, 1), fen("2026-01-30", jer, usage).dernier)
        }
        assertEquals(LocalDate.of(2026, 5, 30), fen("2026-05-28", parisLieu, Levana.Usage.TROIS_MI_MOIS).dernier)
    }

    @Test
    fun `audit du 16-11, Edot jusqu a la nuit du 15 incluse, jamais la nuit du 16`() {
        assertEquals(Levana.Usage.SEPT_NUIT_QUINZE, Levana.Usage.duNusah("edot"))
        assertEquals(LocalDate.of(2024, 10, 17), fen("2024-10-14", jer, Levana.Usage.SEPT_QUINZE).dernier)
        assertEquals(LocalDate.of(2024, 10, 16), fen("2024-10-14", jer, Levana.Usage.SEPT_NUIT_QUINZE).dernier)
        assertEquals(LocalDate.of(2027, 2, 20), fen("2027-02-18", parisLieu, Levana.Usage.SEPT_QUINZE).dernier)
        assertEquals(LocalDate.of(2027, 2, 21), fen("2027-02-18", parisLieu, Levana.Usage.SEPT_NUIT_QUINZE).dernier)
        for (lieu in listOf(jer, parisLieu)) for (m in 0L until 24L) {
            val d = LocalDate.of(2026, 1, 3).plusMonths(m)
            val f = fen(d.toString(), lieu, Levana.Usage.SEPT_NUIT_QUINZE)
            assertTrue("$d : ${f.dernier}", com.kosherjava.zmanim.hebrewcalendar.JewishCalendar(f.dernier.plusDays(1)).jewishDayOfMonth <= 15)
        }
    }

    @Test
    fun `audit du 16-11, ni Chabbat ni Yom tov sauf le dernier soir`() {
        val jz = ZoneId.of("Asia/Jerusalem")
        val pz = ZoneId.of("Europe/Paris")
        val edot = fen("2026-04-24", jer, Levana.Usage.SEPT_NUIT_QUINZE)
        assertEquals(Levana.Etat.PasCeSoir(Levana.Chome.CHABBAT), Levana.etat(edot, LocalDate.of(2026, 4, 24), jz, true))
        assertEquals(LocalDate.of(2026, 4, 25), Levana.premierPossible(edot, jz, true))
        // Le rappel du premier soir passe au samedi soir.
        assertEquals(LocalDate.of(2026, 4, 25) to LevanaAlerte.Soir.PREMIER, LevanaAlerte.soirs(edot, LocalDate.of(2026, 4, 20), jz, true).first())
        assertEquals(Levana.Etat.PasCeSoir(Levana.Chome.CHABBAT),
            Levana.etat(fen("2027-06-11", parisLieu, Levana.Usage.TROIS_MI_MOIS), LocalDate.of(2027, 6, 11), pz, false))
        val chavouot = fen("2029-05-20", parisLieu, Levana.Usage.TROIS_MI_MOIS)
        assertEquals(Levana.Etat.PasCeSoir(Levana.Chome.YOM_TOV), Levana.etat(chavouot, LocalDate.of(2029, 5, 20), pz, false))
        assertEquals(Levana.Etat.CeSoir, Levana.etat(chavouot, LocalDate.of(2029, 5, 20), pz, true))
        var vus = 0
        for (m in 0L until 36L) {
            val f = fen(LocalDate.of(2026, 1, 1).plusMonths(m).toString(), jer, Levana.Usage.TROIS_MI_MOIS)
            if (f.dernier.dayOfWeek == java.time.DayOfWeek.FRIDAY) { vus++; assertEquals(Levana.Etat.DernierSoir, Levana.etat(f, f.dernier, jz, true)) }
        }
        assertTrue(vus > 0)
    }

    @Test
    fun `audit du 16-11, sortie du 9 Av a la tset et 10 Tevet`() {
        val av = fen("2026-07-20", parisLieu, Levana.Usage.TROIS_MI_MOIS)
        assertEquals(Levana.Restriction.TISHA_BEAV, av.restriction)
        assertTrue(!av.debut.isBefore(java.time.Instant.parse("2026-07-23T20:30:00Z")))
        assertTrue(Levana.sortieDeJeune(LocalDate.of(2025, 12, 30), false))
        assertTrue(Levana.sortieDeJeune(LocalDate.of(2026, 12, 20), false))
        assertTrue(!Levana.sortieDeJeune(LocalDate.of(2025, 12, 29), false))
        assertTrue(!Levana.sortieDeJeune(LocalDate.of(2026, 9, 21), false)) // Kippour
    }

    @Test
    fun `la lune nouvelle, au premier quartier, pleine`() {
        fun a(iso: String) = java.time.Instant.parse(iso)
        assertTrue(Levana.phase(a("2026-10-10T12:00:00Z")).eclairage < 0.01)
        val quartier = Levana.phase(a("2026-10-18T12:00:00Z"))
        assertTrue(quartier.eclairage in 0.4..0.6 && quartier.croissante)
        assertTrue(Levana.phase(a("2026-10-26T12:00:00Z")).eclairage > 0.99)
    }
}
