package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId
import java.time.ZonedDateTime

/** Les dix améliorations du 14/10 : ce qui se teste sans écran. */
class DixAmeliorationsTest {

    private val zone = ZoneId.of("Asia/Jerusalem")

    @Test
    fun `rappel Levana jamais avant l ouverture de la fenetre`() {
        val paris = ZoneId.of("Europe/Paris")
        // 12/11/2026, usage 3 jours : tsét à 18 h 04, mais la fenêtre ne s'ouvre qu'à 21 h 06.
        val heure = { d: LocalDate -> d.atTime(18, 4).atZone(paris) }
        val (q, s) = LevanaAlerte.prochain(ZonedDateTime.of(2026, 11, 12, 9, 0, 0, 0, paris), Levana.Usage.TROIS_MI_MOIS, heure)!!
        assertEquals(LevanaAlerte.Soir.PREMIER, s)
        assertEquals(Levana.fenetre(LocalDate.of(2026, 11, 12), paris, Levana.Usage.TROIS_MI_MOIS).debut, q.toInstant())
        assertTrue(q.hour >= 21)
    }

    @Test
    fun `rappel Levana, premier soir puis motsae Chabbat puis dernier`() {
        val heure = { d: LocalDate -> d.atTime(19, 0).atZone(zone) }
        val (q1, s1) = LevanaAlerte.prochain(ZonedDateTime.of(2026, 10, 14, 9, 0, 0, 0, zone), Levana.Usage.TROIS_MI_MOIS, heure)!!
        assertEquals(LocalDate.of(2026, 10, 14), q1.toLocalDate()); assertEquals(LevanaAlerte.Soir.PREMIER, s1)
        val (q2, s2) = LevanaAlerte.prochain(q1.plusMinutes(1), Levana.Usage.TROIS_MI_MOIS, heure)!!
        assertEquals(LocalDate.of(2026, 10, 17), q2.toLocalDate()); assertEquals(LevanaAlerte.Soir.MOTSAE, s2)
        val (q3, s3) = LevanaAlerte.prochain(q2.plusMinutes(1), Levana.Usage.TROIS_MI_MOIS, heure)!!
        assertEquals(LocalDate.of(2026, 10, 25), q3.toLocalDate()); assertEquals(LevanaAlerte.Soir.DERNIER, s3)
        // Après le dernier soir : le premier soir du mois suivant.
        val (q4, s4) = LevanaAlerte.prochain(q3.plusMinutes(1), Levana.Usage.TROIS_MI_MOIS, heure)!!
        assertTrue(q4.toLocalDate().isAfter(LocalDate.of(2026, 11, 5))); assertEquals(LevanaAlerte.Soir.PREMIER, s4)
    }

    @Test
    fun `widget, la priere du moment et sa limite`() {
        val j = LocalDate.of(2026, 10, 14)
        fun t(h: Int, m: Int) = j.atTime(h, m).atZone(zone)
        val horaires = mapOf("szt_gra" to t(10, 30), "minha_gedola" to t(12, 20), "chkia" to t(17, 50), "chatsot_layla" to t(23, 40))
        assertEquals(ZmanimWidget.Moment("chaharit", t(10, 30)), ZmanimWidget.prochaine(horaires, t(7, 0)))
        assertEquals(ZmanimWidget.Moment("minha", t(17, 50)), ZmanimWidget.prochaine(horaires, t(13, 0)))
        assertEquals(ZmanimWidget.Moment("arvit", t(23, 40)), ZmanimWidget.prochaine(horaires, t(19, 0)))
        assertEquals(ZmanimWidget.Moment("arvit", null), ZmanimWidget.prochaine(horaires, t(23, 50)))
        // De la fin de Cha'harit à min'ha guedola, aucune prière ouverte : Min'ha annoncée avec son
        // début (13/11, audit du 12/11, FVOL-05 : « Min'ha » s'affichait dès 10:30, avant 'hatsot).
        assertEquals(ZmanimWidget.Moment("minha", t(17, 50), debut = t(12, 20)), ZmanimWidget.prochaine(horaires, t(10, 30)))
        assertEquals(ZmanimWidget.Moment("minha", t(17, 50), debut = t(12, 20)), ZmanimWidget.prochaine(horaires, t(12, 19)))
        assertEquals(ZmanimWidget.Moment("minha", t(17, 50)), ZmanimWidget.prochaine(horaires, t(12, 20)))
        // La jauge de Min'ha part de min'ha guedola.
        assertEquals(t(12, 20), ZmanimVignette.debut("minha", horaires))
        // Sans min'ha guedola connue, l'ancienne règle ; celle du lendemain (après la chki'a) ne ferme pas Min'ha.
        assertEquals(ZmanimWidget.Moment("minha", t(17, 50)), ZmanimWidget.prochaine(horaires - "minha_gedola", t(11, 0)))
        assertEquals(ZmanimWidget.Moment("minha", t(17, 50)), ZmanimWidget.prochaine(horaires + ("minha_gedola" to t(12, 20).plusDays(1)), t(13, 0)))
        // Après minuit, avant l'aube : encore Arvit (jusqu'au milieu de la nuit d'hier s'il n'est pas passé).
        val nuit = mapOf("alot" to t(5, 20), "szt_gra" to t(10, 30), "chkia" to t(17, 50), "chatsot_layla" to t(23, 40).plusMinutes(70))
        assertEquals(ZmanimWidget.Moment("arvit", t(0, 50)), ZmanimWidget.prochaine(nuit, t(0, 20)))
        assertEquals(ZmanimWidget.Moment("arvit", null), ZmanimWidget.prochaine(nuit, t(2, 0)))
        assertEquals(ZmanimWidget.Moment("chaharit", t(10, 30)), ZmanimWidget.prochaine(nuit, t(6, 0)))
        // Sans aube (Londres au solstice, FCALENDRIER-08) : michéyakir, puis le lever, bornent la nuit, et la jauge part de là.
        val sansAube = nuit - "alot" + ("misheyakir" to t(5, 40)) + ("netz" to t(6, 10))
        assertEquals(ZmanimWidget.Moment("arvit", t(0, 50)), ZmanimWidget.prochaine(sansAube, t(0, 20)))
        assertEquals(ZmanimWidget.Moment("chaharit", t(10, 30)), ZmanimWidget.prochaine(sansAube, t(6, 0)))
        assertEquals(t(5, 40), ZmanimVignette.debut("chaharit", sansAube))
        assertEquals(ZmanimWidget.Moment("arvit", t(0, 50)), ZmanimWidget.prochaine(sansAube - "misheyakir", t(0, 20)))
        assertEquals(t(6, 10), ZmanimVignette.debut("chaharit", sansAube - "misheyakir"))
    }

    @Test
    fun `recherche, sans voyelles ni balises`() {
        assertEquals("ברוך אתה", RechercheGlobale.nu("<b>בָּרוּךְ</b> אַתָּה"))
        val s = Siddur(emptyList(), listOf(SiddurTexte("t", "g", LocalizedText("עלינו", "Alénou", "Aleinu"), "",
            listOf(SiddurSection("", listOf(SiddurBloc("וַאֲנַחְנוּ כּוֹרְעִים", false)))))))
        assertEquals("t", RechercheGlobale.dansRecueil(s, RechercheGlobale.nu("כורעים"), RechercheGlobale.Sorte.SIDDOUR, "fr").single().id)
        assertEquals("t", RechercheGlobale.dansRecueil(s, RechercheGlobale.nu("alénou"), RechercheGlobale.Sorte.SIDDOUR, "fr").single().id)
        // Sans accents ni apostrophe typographique (29/10) : « alenou », « hachahar ».
        assertEquals("t", RechercheGlobale.dansRecueil(s, RechercheGlobale.nu("Alenou"), RechercheGlobale.Sorte.SIDDOUR, "fr").single().id)
        assertEquals("birkot hachahar prieres", RechercheGlobale.nu("Birkot hacha’har Prières"))
        assertEquals("ירושלם", RechercheGlobale.nu("יְרוּשָׁלַ\u200Dִם"))  // FLECTURE-17 : U+200D ne coupe plus le mot
        assertTrue(RechercheGlobale.dansRecueil(s, "שבת", RechercheGlobale.Sorte.SIDDOUR, "fr").isEmpty())
    }

    @Test
    fun `journal, les minutes du mois et le resume`() {
        val jours = mapOf(
            "2026-10-01" to DayRecord("2026-10-01", 20, ""),
            "2026-10-03" to DayRecord("2026-10-03", 0, "note", noteSeule = true),
            "2026-10-31" to DayRecord("2026-10-31", 45, ""),
        )
        val m = JournalPlus.minutesDuMois(jours, YearMonth.of(2026, 10))
        assertEquals(31, m.size); assertEquals(20, m[0]); assertEquals(0, m[2]); assertEquals(45, m[30])
        assertEquals("\u2066🙁 → 🙂\u2069\nG : merci", JournalPlus.resume(JournalPlus.Plus(2, 4, "merci"), "G"))
        assertEquals("", JournalPlus.resume(JournalPlus.Plus(), "G"))
    }
}
