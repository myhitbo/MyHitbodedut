// Le planificateur de notifications d'iOS devant la JVM : ce que les récepteurs d'Android montreraient, jour
// après jour, à partir d'un même état (réglages, journal, rappels du vol) et d'un même « maintenant ». Android
// pose une alarme à la fois et décide quand elle sonne ; ici chaque alarme est suivie jusqu'au bout, l'heure
// figée (bouchons/Horloge.kt) avancée à l'instant de chaque déclenchement, et l'on note ce qui s'affiche :
//
// - le rappel de hitbodedout (Reminder.reschedule, puis ReminderReceiver) : le prochain instant de
//   ReminderRule.prochainDeclenchement, ou le report s'il tombe avant ; au déclenchement le report est
//   consommé, et la notification ne s'affiche que si les rappels sont actifs, qu'aucune séance ne court et que
//   ReminderRule.shouldNotify le permet (Store.isDone, isExempt, isEveOfRestDay, à l'heure du déclenchement),
//   sur dix jours civils à partir d'aujourd'hui ;
// - « Chabbat dans 3 h » : ChabbatAlerte.prochaine, quatre fois de suite, l'allumage de Zmanim (KosherJava) ;
// - Birkat haLevana : LevanaAlerte.prochain, six fois de suite, l'heure de LevanaAlerte.heure ;
// - le vol : la sélection de VolAlerte.programmer (recopiée : sa tolérance est privée) et VolAlerte.dus ;
// - la phrase du trophée tout proche (ReminderReceiver.tropheeProche, privée : recopiée).
//
// Les zmanim demandés (allumage des vendredis, sortie des étoiles des soirs de Levana) sont écrits avec la
// réponse : PlanNotificationsTests les rend au planificateur de Swift sans rien recalculer. VueJour.usageLevana
// (un écran, non compilé) est recopiée en une ligne. Les réglages sont écrits avant qu'aucune règle ne les lise
// (Store.inIsrael fige la valeur au premier accès), clés triées, comme VecteursStore.

import android.content.Context
import com.myhitbodedut.ChabbatAlerte
import com.myhitbodedut.Levana
import com.myhitbodedut.LevanaAlerte
import com.myhitbodedut.ReminderRule
import com.myhitbodedut.Store
import com.myhitbodedut.Trophees
import com.myhitbodedut.VolAlerte
import com.myhitbodedut.VolRappels
import com.myhitbodedut.Zmanim
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime
import kotlin.random.Random
import org.json.JSONArray
import org.json.JSONObject

object VecteursPlan : Generateur {
    override val fichier = "plan.json"

    private const val PREFS = "myhitbodedut"
    private const val JOURNAL = "myhitbodedut-journal"
    private const val MINUTE = 60_000L

    /** Les jours civils de rappels que le planificateur d'iOS programme d'avance (PORTAGE.md § 2.2.2). */
    private const val JOURS = 10
    private const val CHABBATS = 4
    private const val SOIRS = 6
    private const val VOL_MAX = 40
    /** VolAlerte.TOLERANCE_MS, privée. */
    private const val TOLERANCE_VOL = 20 * MINUTE

    private val LIEUX = listOf(
        Zmanim.Lieu("Jérusalem", 31.76904, 35.21633, 0.0, "Asia/Jerusalem"),
        Zmanim.Lieu("Paris", 48.85341, 2.3488, 0.0, "Europe/Paris"),
        Zmanim.Lieu("New York", 40.71427, -74.00597, 0.0, "America/New_York"),
        Zmanim.Lieu("Melbourne", -37.814, 144.96332, 0.0, "Australia/Melbourne"),
        Zmanim.Lieu("Tromsø", 69.6492, 18.9553, 0.0, "Europe/Oslo"),
    )
    private val FUSEAUX = listOf("Asia/Jerusalem", "Europe/Paris", "America/New_York", "Australia/Melbourne", "Europe/Oslo", "UTC")

    /** Un état de départ : ce que le téléphone a enregistré, et quand on planifie. */
    private class Config(
        val nom: String,
        val zone: ZoneId,
        val maintenant: LocalDateTime,
        /** Préférences « myhitbodedut » posées telles quelles (Boolean, Int, Long, String, Set<String>). */
        val prefs: Map<String, Any>,
        /** Les jours faits : décalage depuis aujourd'hui → minutes. */
        val faits: Map<Int, Int> = emptyMap(),
        /** Les rappels du vol : décalage en millisecondes depuis maintenant, type, prière, limite (décalage), omer. */
        val vol: List<VolRappels.Rappel> = emptyList(),
    )

    private fun millis(z: ZonedDateTime): Long = z.toInstant().toEpochMilli()
    private fun vu(t: Long, zone: ZoneId): ZonedDateTime = Instant.ofEpochMilli(t).atZone(zone)

    /** Les réglages écrits, clés triées, comme org.json les écrit ; un StringSet en tableau trié. */
    private fun prefsTexte(t: Theatre): String {
        val valeurs = t.prefs(PREFS).valeurs
        val o = JSONObject()
        for (cle in valeurs.keys.sorted()) {
            val v = valeurs[cle]
            o.put(cle, if (v is Set<*>) JSONArray(v.map { it as String }.sorted()) else v)
        }
        return o.toString()
    }

    private fun lieuPrefs(lieu: Zmanim.Lieu, ville: Long?): Map<String, Any> = buildMap {
        put("lieu_nom", lieu.nom)
        put("lieu_latitude", lieu.latitude.toString())
        put("lieu_longitude", lieu.longitude.toString())
        put("lieu_altitude", lieu.altitude.toString())
        put("lieu_fuseau", lieu.fuseau)
        if (ville != null) put("lieu_ville", ville)
    }

    /** Le rappel de hitbodedout, alarme après alarme, sur JOURS jours civils. */
    private fun rappels(c: Context, debut: Long, zone: ZoneId): List<List<Any?>> {
        val res = mutableListOf<List<Any?>>()
        if (!Store.reminderEnabled(c)) return res
        val dernier = vu(debut, zone).toLocalDate().plusDays((JOURS - 1).toLong())
        val heures = Store.reminderTimes(c)
        var t = debut
        var report = Store.reminderSnoozedUntil(c)
        for (garde in 0 until 2000) {
            val regle = ReminderRule.prochainDeclenchement(vu(t, zone), heures)?.let(::millis)
            var quand = regle
            var reporte = false
            if (report > t && (regle == null || report < regle)) {
                quand = report
                reporte = true
            }
            if (quand == null || vu(quand, zone).toLocalDate().isAfter(dernier)) break
            // Le report est consommé à chaque déclenchement (ReminderReceiver.onReceive).
            report = 0L
            Horloge.regler(quand, zone)
            val heure = LocalTime.ofInstant(Instant.ofEpochMilli(quand), zone)
            val jour = Horloge.aujourdhui()
            val permis = !Store.isSessionRunning(c) && ReminderRule.shouldNotify(
                nowMinutes = heure.hour * 60 + heure.minute,
                doneToday = Store.isDone(c),
                todayIsRestDay = Store.isExempt(c, jour),
                tomorrowIsRestDay = Store.isEveOfRestDay(c, jour),
                sunsetMinutes = null,
            )
            if (permis) res += listOf(quand, if (reporte) "reporte" else "rappel")
            t = quand
        }
        Horloge.regler(debut, zone)
        return res
    }

    /** ReminderReceiver.tropheeProche, sans noter le trophée. */
    private fun trophee(c: Context): Map<String, Any?>? {
        if (!Store.rappelTropheeProche(c)) return null
        val p = Store.pratique(c)
        val n = Trophees.proche(p) ?: return null
        if (n.cle in Store.tropheesProchesSignales(c)) return null
        return linkedMapOf("cle" to n.cle, "famille" to n.famille.name, "seuil" to n.seuil, "reste" to n.seuil - Trophees.valeur(p, n.famille))
    }

    private fun chabbat(c: Context, debut: Long, zone: ZoneId, allumages: MutableMap<String, Long?>): List<Long> {
        val lieu = Store.lieuAlertes(c) ?: return emptyList()
        val minutes = Store.allumage(c)
        val res = mutableListOf<Long>()
        var t = debut
        for (k in 0 until CHABBATS) {
            val q = ChabbatAlerte.prochaine(vu(t, zone)) { d ->
                val z = Zmanim.allumage(lieu, d, minutes).local
                allumages[d.toString()] = z?.let(::millis)
                z
            } ?: break
            res += millis(q)
            t = millis(q)
        }
        return res
    }

    private fun levana(c: Context, debut: Long, zoneTel: ZoneId, tsets: MutableMap<String, Long?>): List<List<Any?>> {
        if (!Store.levanaRappel(c)) return emptyList()
        val zone = Store.lieuAlertes(c)?.fuseau?.let { runCatching { ZoneId.of(it) }.getOrNull() } ?: zoneTel
        // VueJour.usageLevana (un écran) : l'usage choisi, sinon celui du noussa'h.
        val usage = Store.levanaUsage(c) ?: Levana.Usage.duNusah(Store.siddurNusah(c).cle)
        val vraie = LevanaAlerte.heure(c, zone)
        val heure = { d: LocalDate ->
            Store.lieuAlertes(c)?.let { lieu ->
                tsets[d.toString()] = Zmanim.jour(lieu, d).firstOrNull { it.cle == "tset" }?.local?.let(::millis)
            }
            vraie(d)
        }
        val res = mutableListOf<List<Any?>>()
        var t = debut
        for (k in 0 until SOIRS) {
            val (q, soir) = LevanaAlerte.prochain(vu(t, zone), usage, heure) ?: break
            res += listOf(millis(q), soir.name)
            t = millis(q)
        }
        return res
    }

    private fun vol(c: Context, debut: Long): List<List<Any?>> {
        if (!Store.volRappelsActifs(c)) return emptyList()
        val rappels = Store.volRappels(c)
        var dejaVu = Store.volRappelVu(c)
        var t = debut
        val res = mutableListOf<List<Any?>>()
        while (res.size < VOL_MAX) {
            val prochain = rappels.map { it.instant.toEpochMilli() }.filter { it > dejaVu && it > t - TOLERANCE_VOL }.minOrNull() ?: break
            val declenchement = maxOf(prochain, t)
            val dus = VolAlerte.dus(rappels, dejaVu, declenchement)
            if (dus.isEmpty()) break
            dus.forEach { res += listOf(declenchement, it.type.name, it.instant.toEpochMilli()) }
            dejaVu = dus.maxOf { it.instant.toEpochMilli() }
            t = declenchement
        }
        return res
    }

    private fun produire(cfg: Config): Map<String, Any?> {
        val zone = cfg.zone
        val debut = millis(cfg.maintenant.atZone(zone))
        Horloge.regler(debut, zone)
        val t = Theatre()
        val c = t.contexte
        t.prefs(PREFS).valeurs.putAll(cfg.prefs)
        val aujourdhui = Horloge.aujourdhui()
        val days = JSONObject()
        for ((decalage, minutes) in cfg.faits.entries.sortedBy { it.key }) {
            days.put(aujourdhui.plusDays(decalage.toLong()).toString(), JSONObject().put("minutes", minutes).put("note", ""))
        }
        t.prefs(JOURNAL).valeurs["days"] = days.toString()
        if (cfg.vol.isNotEmpty()) Store.setVolRappels(c, cfg.vol)
        val prefs = prefsTexte(t)
        val volEcrits = cfg.vol.map { r ->
            listOf(r.type.name, r.instant.toEpochMilli(), r.priere, r.limite?.toEpochMilli(), r.omer)
        }
        val allumages = sortedMapOf<String, Long?>()
        val tsets = sortedMapOf<String, Long?>()
        val r = rappels(c, debut, zone)
        val tr = trophee(c)
        val ch = chabbat(c, debut, zone, allumages)
        val lv = levana(c, debut, zone, tsets)
        val vo = vol(c, debut)
        Horloge.regler(debut, zone)
        // Ce que Store dit des jours de rappels : exempté, veille d'un jour chômé, fait (« 1 » ou « 0 » chacun).
        val drapeaux = { b: Boolean -> if (b) "1" else "0" }
        val jours = linkedMapOf<String, String>()
        for (k in 0 until JOURS) {
            val d = aujourdhui.plusDays(k.toLong())
            jours[d.toString()] = drapeaux(Store.isExempt(c, d)) + drapeaux(Store.isEveOfRestDay(c, d)) + drapeaux(Store.isDone(c, d.toString()))
        }
        return linkedMapOf(
            "nom" to cfg.nom,
            "fuseau" to zone.id,
            "maintenant" to debut,
            "prefs" to prefs,
            "days" to days.toString(),
            "volRappels" to volEcrits,
            "jours" to jours,
            "rappels" to r,
            "trophee" to tr,
            "allumages" to allumages,
            "chabbat" to ch,
            "tsets" to tsets,
            "levana" to lv,
            "vol" to vo,
        )
    }

    // --- Les états -------------------------------------------------------------------------------------

    private fun base(heures: String, vararg plus: Pair<String, Any>): Map<String, Any> =
        linkedMapOf<String, Any>("reminder_on" to true, "reminder_times" to heures).apply { putAll(plus) }

    /** Les cas des tests neufs (ROADMAP tâche 12), écrits à la main. */
    private fun choisis(): List<Config> {
        val paris = ZoneId.of("Europe/Paris")
        val jerusalem = ZoneId.of("Asia/Jerusalem")
        val ny = ZoneId.of("America/New_York")
        // Le mercredi 14 octobre 2026, 8 h : un vendredi et un Chabbat dans les dix jours.
        val mercredi = LocalDateTime.of(2026, 10, 14, 8, 0)
        val parisLieu = lieuPrefs(LIEUX[1], 2988507L)
        val ms = { z: ZoneId, d: LocalDateTime -> millis(d.atZone(z)) }
        return listOf(
            Config("trois-heures", paris, mercredi, base("420,780,1260")),
            Config("trois-heures-sans-chabbat", paris, mercredi, base("420,780,1260", "pause_shabbat" to false)),
            Config("journee-faite", paris, mercredi, base("420,780,1260"), faits = mapOf(0 to 20)),
            Config("hier-fait", paris, mercredi, base("420,780,1260"), faits = mapOf(-1 to 20)),
            Config("seance-minutee", paris, mercredi.withHour(12).withMinute(50), base("420,780,800,1260",
                "session_started_at" to ms(paris, mercredi.withHour(12).withMinute(45)),
                "session_ends_at" to ms(paris, mercredi.withHour(13).withMinute(30)), "session_target" to 45)),
            Config("seance-ouverte", paris, mercredi.withHour(12).withMinute(50), base("420,780,1260",
                "session_started_at" to ms(paris, mercredi.withHour(12).withMinute(45)), "session_target" to 0)),
            Config("seance-finie", paris, mercredi.withHour(14), base("420,780,1260",
                "session_started_at" to ms(paris, mercredi.withHour(12)), "session_ends_at" to ms(paris, mercredi.withHour(12).withMinute(20)),
                "session_target" to 20)),
            Config("report-5", paris, mercredi.withHour(9), base("420,780,1260",
                "reminder_snoozed_until" to ms(paris, mercredi.withHour(9).withMinute(5)))),
            Config("report-15", paris, mercredi.withHour(9), base("420,780,1260",
                "reminder_snoozed_until" to ms(paris, mercredi.withHour(9).withMinute(15)))),
            Config("report-apres-le-rappel", paris, mercredi.withHour(12).withMinute(50), base("420,780,1260",
                "reminder_snoozed_until" to ms(paris, mercredi.withHour(13).withMinute(20)))),
            Config("report-passe", paris, mercredi.withHour(9), base("420,780,1260",
                "reminder_snoozed_until" to ms(paris, mercredi.withHour(8).withMinute(30)))),
            Config("report-sans-heures", paris, mercredi.withHour(9), base("",
                "reminder_snoozed_until" to ms(paris, mercredi.withHour(9).withMinute(15)))),
            Config("report-un-jour-fait", paris, mercredi.withHour(9), base("420,780,1260",
                "reminder_snoozed_until" to ms(paris, mercredi.withHour(9).withMinute(15))), faits = mapOf(0 to 15)),
            Config("rappels-eteints", paris, mercredi, linkedMapOf("reminder_on" to false, "reminder_times" to "420,1260")),
            Config("heure-unique-d-avant", paris, mercredi, linkedMapOf("reminder_on" to true, "reminder_minutes" to 1200)),
            Config("vingt-quatre-heures", paris, mercredi,
                base((0 until 24).joinToString(",") { (it * 60 + 15).toString() })),
            Config("israel-rosh-hashana", jerusalem, LocalDateTime.of(2026, 9, 9, 6, 0), base("360,720,1080")),
            Config("diaspora-souccot", ny, LocalDateTime.of(2026, 9, 24, 6, 0), base("360,690,719,720,1080")),
            Config("changement-d-heure", paris, LocalDateTime.of(2026, 3, 27, 1, 0), base("150,200,1260", "pause_shabbat" to false)),
            Config("heure-double", paris, LocalDateTime.of(2026, 10, 24, 1, 0), base("150,1260", "pause_shabbat" to false)),
            Config("pause-voyage", paris, mercredi, base("420,1260", "paused_dates" to setOf("2026-10-15", "2026-10-16", "pas-une-date"))),
            Config("tout", paris, mercredi, base("420,780,1260") + parisLieu + mapOf("allumage_minutes" to 30, "levana_usage" to "trois_mi_mois",
                "vol_rappel_vu" to ms(paris, mercredi.withHour(9))), vol = volExemple(ms(paris, mercredi))),
            Config("lieu-perime", ny, mercredi, base("420") + lieuPrefs(LIEUX[1], null)),
            Config("lieu-du-telephone", paris, mercredi, base("420") + lieuPrefs(LIEUX[1], null)),
            Config("polaire", ZoneId.of("Europe/Oslo"), LocalDateTime.of(2026, 12, 2, 10, 0), base("600") + lieuPrefs(LIEUX[4], 3133880L)),
            Config("levana-sans-lieu", jerusalem, LocalDateTime.of(2026, 11, 10, 22, 0), base("") + mapOf("siddur_nusah" to "edot")),
            Config("levana-eteinte", jerusalem, mercredi, base("") + lieuPrefs(LIEUX[0], 281184L) + mapOf("levana_rappel" to false)),
            Config("trophee-signale", paris, mercredi, base("420") + mapOf("trophees_proches_signales" to setOf("PREMIER_PAS:1"))),
            Config("trophee-tu", paris, mercredi, base("420") + mapOf("rappel_trophee_proche" to false)),
        )
    }

    private fun volExemple(t: Long): List<VolRappels.Rappel> = listOf(
        VolRappels.Rappel(VolRappels.Type.TEFILAT_HADEREKH, Instant.ofEpochMilli(t - 30 * MINUTE), "chaharit", Instant.ofEpochMilli(t + 60 * MINUTE)),
        VolRappels.Rappel(VolRappels.Type.PRIERE_FIN, Instant.ofEpochMilli(t + 30 * MINUTE), "chaharit", Instant.ofEpochMilli(t + 60 * MINUTE)),
        VolRappels.Rappel(VolRappels.Type.PRIERE, Instant.ofEpochMilli(t + 5 * 60 * MINUTE), "minha", Instant.ofEpochMilli(t + 9 * 60 * MINUTE)),
        VolRappels.Rappel(VolRappels.Type.PRIERE, Instant.ofEpochMilli(t + 10 * 60 * MINUTE), "arvit", null),
        VolRappels.Rappel(VolRappels.Type.OMER, Instant.ofEpochMilli(t + 10 * 60 * MINUTE + 30_000), omer = 12),
    )

    /** Des états tirés au sort, graines fixes. */
    private fun tire(k: Int): Config {
        val r = Random(7300 + k)
        val zone = ZoneId.of(FUSEAUX[r.nextInt(FUSEAUX.size)])
        val jour = LocalDate.of(2026, 1, 1).plusDays(r.nextInt(730).toLong())
        val maintenant = jour.atTime(r.nextInt(24), r.nextInt(60))
        val debut = millis(maintenant.atZone(zone))
        val p = linkedMapOf<String, Any>()
        p["reminder_on"] = r.nextInt(5) != 0
        when (r.nextInt(6)) {
            0 -> p["reminder_minutes"] = r.nextInt(1440)
            1 -> Unit
            else -> p["reminder_times"] = List(r.nextInt(8)) {
                when (r.nextInt(12)) { 0 -> -5; 1 -> 1440 + r.nextInt(100); 2 -> 719; 3 -> 720; else -> r.nextInt(1440) }
            }.joinToString(",")
        }
        if (r.nextInt(4) == 0) p["pause_shabbat"] = false
        if (r.nextBoolean()) p["in_israel"] = r.nextBoolean()
        if (r.nextInt(3) == 0) p["paused_dates"] = List(1 + r.nextInt(4)) { jour.plusDays(r.nextInt(12).toLong()).toString() }.toSet()
        val l = r.nextInt(7)
        if (l < LIEUX.size) {
            p.putAll(lieuPrefs(LIEUX[l], if (r.nextInt(3) == 0) null else 1000L + l))
            if (r.nextInt(3) == 0) p["allumage_minutes"] = listOf(18, 20, 22, 30, 40, 25)[r.nextInt(6)]
        }
        if (r.nextInt(4) == 0) p["levana_rappel"] = false
        if (r.nextBoolean()) p["levana_usage"] = listOf("trois_mi_mois", "sept_mi_mois", "sept_quinze", "inconnu")[r.nextInt(4)]
        if (r.nextBoolean()) p["siddur_nusah"] = listOf("edot", "sefard", "ashkenaz")[r.nextInt(3)]
        if (r.nextInt(3) == 0) p["target_minutes"] = listOf(5, 15, 20, 60, 90)[r.nextInt(5)]
        if (r.nextInt(4) == 0) {
            val depuis = debut - r.nextInt(120) * MINUTE
            val duree = listOf(0, 10, 30, 60, 240)[r.nextInt(5)]
            p["session_started_at"] = depuis
            p["session_target"] = duree
            if (duree > 0) p["session_ends_at"] = depuis + duree * MINUTE
        }
        if (r.nextInt(3) == 0) p["reminder_snoozed_until"] = debut + listOf(5, 15, 30, -10, 600)[r.nextInt(5)] * MINUTE
        if (r.nextInt(5) == 0) p["rappel_trophee_proche"] = false
        if (r.nextInt(5) == 0) p["trophees_proches_signales"] = setOf("PREMIER_PAS:1", "JOURS:1")
        val faits = linkedMapOf<Int, Int>()
        repeat(r.nextInt(6)) { faits[-r.nextInt(8)] = 5 + r.nextInt(40) }
        if (r.nextInt(3) == 0) faits[0] = 10 + r.nextInt(30)
        val vol = mutableListOf<VolRappels.Rappel>()
        if (r.nextInt(3) == 0) {
            if (r.nextInt(4) == 0) p["vol_rappels_actifs"] = false
            if (r.nextInt(3) == 0) p["vol_rappel_vu"] = debut + (r.nextInt(120) - 60) * MINUTE
            var t = debut - r.nextInt(60) * MINUTE
            repeat(r.nextInt(24)) {
                t += if (r.nextInt(4) == 0) r.nextInt(61) * 1000L else r.nextInt(240) * MINUTE
                val type = VolRappels.Type.values()[r.nextInt(4)]
                val priere = listOf("chaharit", "minha", "arvit", null)[r.nextInt(4)]
                val limite = if (r.nextBoolean()) Instant.ofEpochMilli(t + r.nextInt(300) * MINUTE) else null
                vol += VolRappels.Rappel(type, Instant.ofEpochMilli(t), priere, limite, if (type == VolRappels.Type.OMER) 1 + r.nextInt(49) else 0)
            }
        }
        return Config("tire-$k", zone, maintenant, p, faits, vol.sortedBy { it.instant })
    }

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to linkedMapOf(
            "source" to "tools/vecteurs_ios/VecteursPlan.kt",
            "jours" to JOURS, "chabbats" to CHABBATS, "soirs" to SOIRS, "toleranceVol" to TOLERANCE_VOL,
        ),
        "cas" to (choisis() + (0 until 60).map(::tire)).map(::produire),
    )
}
