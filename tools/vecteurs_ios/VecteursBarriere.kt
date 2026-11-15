// La barrière, le planificateur et les vignettes (tâche 12) devant la JVM : la règle du rappel
// (ReminderRule), l'alerte « Chabbat dans 3 h » (ChabbatAlerte), le rappel de Birkat haLevana
// (LevanaAlerte), la prière du moment et la jauge des vignettes (ZmanimWidget, ZmanimVignette) sur les
// vrais zmanim de cinq lieux, puis ce que Store.kt décide pour la barrière : les jours exemptés, la
// fenêtre, le report, et les titres, couleurs et détails de GateStatus dans les trois langues.
//
// GateStatus.evaluate ne se lance pas ici : Permissions.allGranted y répond toujours non
// (Settings.canDrawOverlays rend faux dans l'android.jar docile). Son ordre est porté ligne pour ligne
// et jugé par les tests de Barriere ; chacun de ses prédicats est jugé ici.
//
// Store.inWindow et Store.isSnoozed lisent l'horloge : la fenêtre est posée autour de la minute qu'il
// est (décalages a et b), et ce qui est écrit ne dépend que de a et b ; le report, que de sa durée.

import com.myhitbodedut.ChabbatAlerte
import com.myhitbodedut.GateState
import com.myhitbodedut.GateStatus
import com.myhitbodedut.JournalPlus
import com.myhitbodedut.DayRecord
import com.myhitbodedut.Levana
import com.myhitbodedut.LevanaAlerte
import com.myhitbodedut.RechercheGlobale
import com.myhitbodedut.ReminderRule
import com.myhitbodedut.Store
import com.myhitbodedut.Zmanim
import com.myhitbodedut.ZmanimVignette
import com.myhitbodedut.ZmanimWidget
import java.time.Duration
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.YearMonth
import java.time.ZoneId
import java.time.ZonedDateTime

object VecteursBarriere : Generateur {
    override val fichier = "barriere.json"

    private val lieux = listOf(
        Zmanim.Lieu("Jérusalem", 31.76904, 35.21633, 0.0, "Asia/Jerusalem"),
        Zmanim.Lieu("Paris", 48.85341, 2.3488, 0.0, "Europe/Paris"),
        Zmanim.Lieu("New York", 40.71427, -74.00597, 0.0, "America/New_York"),
        Zmanim.Lieu("Melbourne", -37.814, 144.96332, 0.0, "Australia/Melbourne"),
        Zmanim.Lieu("Tromsø", 69.6492, 18.9553, 0.0, "Europe/Oslo"),
    )
    private fun lieu(nom: String) = lieux.first { it.nom == nom }
    private fun ms(z: ZonedDateTime?): Any = z?.toInstant()?.toEpochMilli() ?: "-"
    private fun nom(id: Int): String = Identifiants.nom(id)

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf(
            "source" to "tools/vecteurs_ios/VecteursBarriere.kt",
            "lieux" to lieux.map { listOf(it.nom, it.latitude, it.longitude, it.fuseau) },
        ),
        // « maintenant|fait|repos|veille|coucher » → ReminderRule.shouldNotify (1 ou 0), « - » sans coucher.
        "regle" to regle(),
        // « maintenant|heures » → ReminderRule.minutesUntilNext, « - » sans heure.
        "prochaines" to prochaines(),
        // « lieu|minutes d'allumage|fuseau du téléphone|maintenant » → ChabbatAlerte.prochaine (ms), sur
        // Zmanim.allumage ; un an tous les 151 heures, et cinq secondes de part et d'autre de vingt alertes.
        "chabbat" to chabbat(),
        // Le premier rappel de Birkat haLevana, puis chacun depuis le précédent (LevanaAlerte.prochain, avec
        // LevanaAlerte.heure : tsét du lieu, sinon 20 h) : « lieu|usage|maintenant|quand|soir ».
        "levana" to levana(),
        // Les vignettes sur les vrais zmanim : « lieu|maintenant|prière|limite|début|écoulé|jour hébreu|
        // prochain changement » (ZmanimWidget.prochaine, ZmanimVignette.debut, ecoule, jourHebreuAffiche,
        // prochainChangement sur les horaires d'aujourd'hui et de demain, sans minuit du téléphone).
        "vignettes" to vignettes(),
        // La prière du moment sur des horaires forgés à Jérusalem et à Paris : « fuseau|clés présentes|
        // maintenant|prière|limite » ; alot 05:20, szt_gra 10:30, chkia 17:50, chatsot_layla 00:50 le lendemain.
        "prieres" to prieres(),
        // « début|fin|maintenant » (ms, « - » pour null) → ZmanimVignette.ecoule.
        "ecoules" to ecoules(),
        // Store.isExempt et Store.isEveOfRestDay du 1er septembre 2026 au 31 octobre 2027 : un chiffre par jour,
        // 1 exempté + 2 veille de jour chômé ; pour Chabbat oui ou non, Israël ou non, et trois jours en pause.
        "exemptions" to exemptions(),
        // Store.inWindow : « a|b|dedans », la fenêtre posée de (minute qu'il est + a) à (+ b), modulo 1440 ;
        // puis des fenêtres brutes qui ne dépendent pas de l'heure : « début|fin|dedans ».
        "fenetres_relatives" to fenetresRelatives(),
        "fenetres_brutes" to fenetresBrutes(),
        // Store.snooze pour chaque durée proposée : « durée|écart juste|reporté », puis « Je l'ai déjà faite »
        // (Store.addSession(0)) : la journée faite à 0 minute, le report levé, la fenêtre honorée.
        "reports" to reports(),
        "defauts" to defauts(),
        // GateStatus : « état|titre|couleur », puis les détails dans les trois langues.
        "etats" to GateState.entries.map { listOf(it.name, nom(GateStatus.titleOf(it)), nom(GateStatus.colorOf(it))) },
        "details" to details(),
        // DixAmeliorationsTest : RechercheGlobale.extrait, JournalPlus.resume et minutesDuMois.
        "extraits" to extraits(),
        "resumes" to resumes(),
        "mois" to mois(),
    )

    private fun regle(): List<String> {
        val lignes = mutableListOf<String>()
        val instants = listOf(-1, 0, 1, 359, 719, 720, 721, 1119, 1120, 1121, 1439, 1440)
        val couchers = listOf(null, 0, 720, 1120, 1440)
        for (m in instants) for (f in listOf(false, true)) for (r in listOf(false, true)) for (v in listOf(false, true)) for (c in couchers) {
            val n = ReminderRule.shouldNotify(m, f, r, v, c)
            lignes += listOf(m, b(f), b(r), b(v), c ?: "-", b(n)).joinToString("|")
        }
        return lignes
    }

    private fun b(v: Boolean) = if (v) 1 else 0

    private fun prochaines(): List<String> {
        val listes = listOf(listOf(7 * 60, 13 * 60, 21 * 60), listOf(7 * 60, 21 * 60), listOf(7 * 60), emptyList(),
            listOf(21 * 60, 7 * 60, 7 * 60, -30, 1450, 13 * 60), listOf(0, 8 * 60, 23 * 60 + 59), listOf(1439), listOf(0),
            listOf(-1, 1440, 2000))
        val instants = (0 until 1440 step 97) + listOf(-1, 0, 419, 420, 421, 1259, 1260, 1439, 1440, 1500)
        return listes.flatMap { h -> instants.map { m -> listOf(m, h.joinToString(","), ReminderRule.minutesUntilNext(m, h) ?: "-").joinToString("|") } }
    }

    private fun chabbat(): List<String> {
        val lignes = mutableListOf<String>()
        val cas = listOf(Triple("Jérusalem", 40, "Asia/Jerusalem"), Triple("Paris", 18, "Europe/Paris"),
            Triple("New York", 18, "America/New_York"), Triple("Melbourne", 18, "Australia/Melbourne"),
            Triple("Tromsø", 18, "Europe/Oslo"), Triple("New York", 22, "Asia/Tokyo"))
        for ((n, minutes, tel) in cas) {
            val l = lieu(n)
            val allumage = { d: LocalDate -> Zmanim.allumage(l, d, minutes).local }
            val depart = ZonedDateTime.of(2026, 9, 1, 0, 0, 0, 0, ZoneId.of(tel))
            for (k in 0 until 60) {
                val m = depart.plusHours(151L * k)
                lignes += listOf(n, minutes, tel, ms(m), ms(ChabbatAlerte.prochaine(m, allumage))).joinToString("|")
            }
        }
        // Les bornes : cinq secondes avant et après l'alerte de vingt vendredis à Paris.
        val paris = lieu("Paris")
        val allumage = { d: LocalDate -> Zmanim.allumage(paris, d, 18).local }
        var m = ZonedDateTime.of(2026, 10, 1, 0, 0, 0, 0, ZoneId.of("Europe/Paris"))
        repeat(20) {
            val a = ChabbatAlerte.prochaine(m, allumage)!!
            for (d in listOf(-5L, 5L)) {
                val t = a.plusSeconds(d)
                lignes += listOf("Paris", 18, "Europe/Paris", ms(t), ms(ChabbatAlerte.prochaine(t, allumage))).joinToString("|")
            }
            m = a.plusDays(1)
        }
        return lignes
    }

    private fun levana(): List<String> {
        val lignes = mutableListOf<String>()
        for (n in listOf("Jérusalem", "Paris", "Tromsø", "-")) {
            val t = Theatre()
            val zone = if (n == "-") ZoneId.of("Europe/Paris") else ZoneId.of(lieu(n).fuseau)
            if (n != "-") {
                // Une ville de la liste : le lieu n'est jamais périmé, quel que soit le fuseau de la machine.
                val l = lieu(n)
                t.prefs("myhitbodedut").edit().putString("lieu_nom", l.nom).putString("lieu_latitude", l.latitude.toString())
                    .putString("lieu_longitude", l.longitude.toString()).putString("lieu_fuseau", l.fuseau)
                    .putLong("lieu_ville", 1L).apply()
            }
            val heure = LevanaAlerte.heure(t.contexte, zone)
            for (u in Levana.Usage.entries) {
                var m = ZonedDateTime.of(2026, 9, 1, 9, 0, 0, 0, zone)
                repeat(36) {
                    val p = LevanaAlerte.prochain(m, u, heure)
                    lignes += listOf(n, u.cle, ms(m), ms(p?.first), p?.second?.name ?: "-").joinToString("|")
                    if (p == null) return@repeat
                    m = p.first
                }
            }
        }
        return lignes
    }

    private fun vignettes(): List<String> {
        val lignes = mutableListOf<String>()
        val jours = listOf(LocalDate.of(2026, 3, 29), LocalDate.of(2026, 6, 21), LocalDate.of(2026, 11, 2), LocalDate.of(2026, 12, 21))
        for (l in lieux) {
            val zone = ZoneId.of(l.fuseau)
            for (d in jours) {
                val aujourdhui = Zmanim.jour(l, d)
                val horaires = aujourdhui.associate { it.cle to it.local }
                val tous = (aujourdhui + Zmanim.jour(l, d.plusDays(1))).map { it.local }
                val instants = (0 until 15).map { d.atStartOfDay(zone).plusMinutes(97L * it) }.toMutableList()
                for (cle in listOf("alot", "szt_gra", "chkia", "tset", "chatsot_layla")) {
                    horaires[cle]?.let { z -> instants += z.minusSeconds(5); instants += z.plusSeconds(5) }
                }
                for (m in instants.filter { it.toLocalDate() == d }.sortedBy { it.toInstant() }) {
                    val (priere, limite) = ZmanimWidget.prochaine(horaires, m)
                    val debut = ZmanimVignette.debut(priere, horaires)
                    val jour = ZmanimVignette.jourHebreuAffiche(m, horaires["tset"])
                    lignes += listOf(l.nom, ms(m), priere, ms(limite), ms(debut), ZmanimVignette.ecoule(debut, limite, m), jour,
                        ms(ZmanimVignette.prochainChangement(tous, m))).joinToString("|")
                }
            }
        }
        return lignes
    }

    private fun prieres(): List<String> {
        val lignes = mutableListOf<String>()
        for ((fuseau, jour) in listOf("Asia/Jerusalem" to LocalDate.of(2026, 10, 14), "Europe/Paris" to LocalDate.of(2026, 3, 29))) {
            val z = ZoneId.of(fuseau)
            fun t(h: Int, m: Int) = jour.atTime(h, m).atZone(z)
            val tous = linkedMapOf("alot" to t(5, 20), "szt_gra" to t(10, 30), "chkia" to t(17, 50), "chatsot_layla" to t(23, 40).plusMinutes(70))
            val instants = listOf(t(0, 20), t(0, 49), t(0, 50), t(2, 0), t(5, 19), t(5, 20), t(6, 0), t(10, 29), t(10, 30), t(13, 0),
                t(17, 49), t(17, 50), t(19, 0), t(23, 50))
            for (masque in 0 until 16) {
                val horaires = tous.entries.filterIndexed { i, _ -> masque and (1 shl i) != 0 }.associate { it.key to it.value }
                for (m in instants) {
                    val (p, limite) = ZmanimWidget.prochaine(horaires, m)
                    lignes += listOf(fuseau, horaires.keys.joinToString(","), ms(m), p, ms(limite)).joinToString("|")
                }
            }
        }
        // Le milieu de la nuit d'hier tombe dans l'heure qui n'existe pas (Paris, passage à l'heure d'été).
        val paris = ZoneId.of("Europe/Paris")
        val nuit = mapOf("alot" to ZonedDateTime.of(2026, 3, 29, 5, 0, 0, 0, paris), "chatsot_layla" to ZonedDateTime.of(2026, 3, 30, 2, 30, 0, 0, paris))
        for (h in listOf(1, 3, 4)) {
            val m = ZonedDateTime.of(2026, 3, 29, h, 0, 0, 0, paris)
            val (p, limite) = ZmanimWidget.prochaine(nuit, m)
            lignes += listOf("Europe/Paris", "alot,chatsot_layla*", ms(m), p, ms(limite)).joinToString("|")
        }
        return lignes
    }

    private fun ecoules(): List<String> {
        val z = ZoneId.of("Asia/Jerusalem")
        val debut = ZonedDateTime.of(2026, 10, 14, 5, 20, 0, 0, z)
        val fins = listOf(null, -1000L, 0L, 999L, 1000L, 1500L, 3_600_000L, 36_000_000L)
        val instants = listOf(-3_600_000L, -1500L, -1L, 0L, 1L, 999L, 1000L, 1500L, 1_800_000L, 3_599_999L, 3_600_000L, 18_000_000L, 36_000_000L, 39_600_000L)
        val lignes = mutableListOf<String>()
        for (f in fins) for (m in instants) {
            val fin = f?.let { debut.plusNanos(it * 1_000_000L) }
            val t = debut.plusNanos(m * 1_000_000L)
            lignes += listOf(ms(debut), ms(fin), ms(t), ZmanimVignette.ecoule(debut, fin, t)).joinToString("|")
        }
        lignes += listOf("-", ms(debut), ms(debut), ZmanimVignette.ecoule(null, debut, debut)).joinToString("|")
        return lignes
    }

    private fun exemptions(): List<Any?> {
        val debut = LocalDate.of(2026, 9, 1)
        val fin = LocalDate.of(2027, 10, 31)
        val pauses = listOf("2026-11-03", "2027-04-22", "2026-12-31")
        return listOf(true to false, true to true, false to false, false to true).map { (chabbat, israel) ->
            val t = Theatre()
            val c = t.contexte
            Store.setShabbatMode(c, chabbat)
            Store.setInIsrael(c, israel)
            pauses.forEach { Store.togglePausedDate(c, it) }
            val sb = StringBuilder()
            var d = debut
            while (!d.isAfter(fin)) {
                sb.append((if (Store.isExempt(c, d)) 1 else 0) + (if (Store.isEveOfRestDay(c, d)) 2 else 0))
                d = d.plusDays(1)
            }
            listOf(chabbat, israel, pauses, debut.toString(), sb.toString())
        }
    }

    /** La minute qu'il est, relue après coup : si elle a changé pendant l'appel, on recommence. */
    private fun aLaMinute(appel: (Int) -> Boolean): Boolean {
        while (true) {
            val avant = LocalTime.now().let { it.hour * 60 + it.minute }
            val r = appel(avant)
            val apres = LocalTime.now().let { it.hour * 60 + it.minute }
            if (avant == apres) return r
        }
    }

    private fun fenetresRelatives(): List<String> {
        val c = Theatre().contexte
        val decalages = listOf(-600, -61, -1, 0, 1, 61, 600, 1439)
        return decalages.flatMap { a ->
            decalages.map { bb ->
                val r = aLaMinute { m ->
                    Store.setWindow(c, Math.floorMod(m + a, 1440), Math.floorMod(m + bb, 1440))
                    Store.inWindow(c)
                }
                listOf(a, bb, b(r)).joinToString("|")
            }
        }
    }

    private fun fenetresBrutes(): List<String> {
        val c = Theatre().contexte
        return listOf(0 to 1440, 1440 to 0, -5 to 2000, 0 to 0, 720 to 720, 1440 to 1440, 2000 to -5, -10 to -20).map { (s, e) ->
            Store.setWindow(c, s, e)
            listOf(s, e, b(Store.inWindow(c))).joinToString("|")
        }
    }

    private fun reports(): List<Any?> {
        val c = Theatre().contexte
        val lignes = mutableListOf<Any?>()
        for (m in listOf(5, 10, 15, 30, 60)) {
            Store.setSnoozeMinutes(c, m)
            val avant = System.currentTimeMillis()
            Store.snooze(c)
            val apres = System.currentTimeMillis()
            val jusqua = Store.snoozedUntil(c)
            val juste = jusqua - avant >= m * 60_000L && jusqua - apres <= m * 60_000L
            lignes.add(listOf("report", m, juste, Store.isSnoozed(c)))
        }
        // « Je l'ai déjà faite », sur un téléphone neuf ; recommencé si minuit passe pendant l'appel.
        var faite: List<Any?>
        var nuit: List<Any?>
        do {
            val jour = LocalDate.now()
            val t = Theatre().contexte
            Store.setSnoozeMinutes(t, 15)
            Store.snooze(t)
            Store.setWindow(t, 6 * 60, 11 * 60)
            Store.addSession(t, 0)
            val r = Store.record(t)
            faite = listOf("deja_faite", r?.minutes, r?.faite, Store.isDone(t), Store.isSnoozed(t), Store.snoozedUntil(t), Store.fenetreFaite(t))
            Store.setWindow(t, 21 * 60, 2 * 60)
            nuit = listOf("deja_faite_nuit", Store.fenetreFaite(t))
        } while (LocalDate.now() != jour)
        lignes.add(faite)
        lignes.add(nuit)
        Store.clearSnooze(c)
        lignes.add(listOf("leve", Store.snoozedUntil(c), Store.isSnoozed(c)))
        return lignes
    }

    private fun defauts(): Map<String, Any?> {
        val c = Theatre().contexte
        return linkedMapOf("debut" to Store.windowStart(c), "fin" to Store.windowEnd(c), "report" to Store.snoozeMinutes(c),
            "actif" to Store.isEnabled(c), "applications" to Store.blockedApps(c).size, "reporte_jusqua" to Store.snoozedUntil(c),
            "chabbat" to Store.shabbatMode(c), "rappel_actif" to Store.reminderEnabled(c), "rappels" to Store.reminderTimes(c),
            "rappel_reporte" to Store.reminderSnoozedUntil(c), "levana_rappel" to Store.levanaRappel(c),
            "allumage" to Store.allumage(c), "report_rappel" to com.myhitbodedut.Reminder.SNOOZE_MINUTES,
            "avance_chabbat" to ChabbatAlerte.AVANCE_HEURES, "sans_coucher" to ReminderRule.NO_SUNSET_CUTOFF_MINUTES)
    }

    private fun details(): List<Any?> {
        val lignes = mutableListOf<Any?>()
        for (langue in listOf("fr", "en", "he")) {
            for ((s, e) in listOf(6 * 60 to 11 * 60, 21 * 60 to 2 * 60)) for (n in listOf(1, 2, 3, 11)) {
                val t = Theatre(langue)
                val c = t.contexte
                Store.setWindow(c, s, e)
                Store.setBlockedApps(c, (1..n).map { "app.$it" }.toSet())
                for (etat in GateState.entries) {
                    if (etat != GateState.ARMED && etat != GateState.OUTSIDE_WINDOW && (n != 1 || s != 6 * 60)) continue
                    if (etat == GateState.OUTSIDE_WINDOW && n != 1) continue
                    lignes.add(listOf(langue, etat.name, n, s, e, GateStatus.detailOf(c, etat)))
                }
            }
        }
        return lignes
    }

    private fun extraits(): List<Any?> {
        val textes = listOf("וַאֲנַחְנוּ כּוֹרְעִים וּמִשְׁתַּחֲוִים וּמוֹדִים לִפְנֵי מֶלֶךְ מַלְכֵי הַמְּלָכִים הַקָּדוֹשׁ בָּרוּךְ הוּא",
            "<b>בָּרוּךְ</b> אַתָּה", "Birkot hacha’har Prières du matin, avant tout le reste de la journée, pour commencer",
            "court", "")
        val recherches = listOf("כורעים", "ברוך", "hachahar", "court", "absent", "", "הוא", "journee")
        return textes.flatMap { t -> recherches.map { q -> listOf(t, q, RechercheGlobale.extrait(t, q)) } }
    }

    private fun resumes(): List<Any?> {
        val plus = listOf(JournalPlus.Plus(2, 4, "merci"), JournalPlus.Plus(), JournalPlus.Plus(0, 5, "", "patience"),
            JournalPlus.Plus(6, 0, "  ", "x"), JournalPlus.Plus(1, 1, "a", "b"), JournalPlus.Plus(-1, 3))
        return plus.flatMap { p ->
            listOf("" to "", "Famille, Gratitude" to "T").map { (sujets, travail) ->
                listOf(p.avant, p.apres, p.gratitude, p.travail, sujets, travail, JournalPlus.resume(p, "G", travail, sujets))
            }
        }
    }

    private fun mois(): List<Any?> {
        val jours = mapOf(
            "2026-10-01" to DayRecord("2026-10-01", 20, ""),
            "2026-10-03" to DayRecord("2026-10-03", 0, "note", noteSeule = true),
            "2026-10-31" to DayRecord("2026-10-31", 45, ""),
            "2028-02-29" to DayRecord("2028-02-29", 12, ""),
            "2028-02-01" to DayRecord("2028-02-01", 0, ""),
            "2026-11-01" to DayRecord("2026-11-01", 7, ""),
        )
        return listOf(YearMonth.of(2026, 10), YearMonth.of(2026, 11), YearMonth.of(2028, 2), YearMonth.of(2027, 2)).map { m ->
            listOf(m.year, m.monthValue, JournalPlus.minutesDuMois(jours, m))
        }
    }
}
