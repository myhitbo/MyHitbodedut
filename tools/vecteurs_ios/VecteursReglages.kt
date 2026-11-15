// Les réglages d'Android devant la JVM : ce que rendent par défaut les accesseurs de Store qui ne font
// que lire ou écrire une préférence, ce qu'ils relisent après une écriture (dans les bornes, aux
// bornes, au-delà, absurde) ou d'une préférence posée à la main, et ce que contient alors le fichier
// de préférences « myhitbodedut ». ReglagesTests de Coeur les rejoue sur Reglages, dont l'objet JSON
// garde les mêmes clés, dans le même ordre.
//
// Tout s'écrit comme org.json d'Android l'écrit : les préférences en un objet, clés dans l'ordre où
// elles ont été posées, un ensemble de chaînes (StringSet) en tableau trié, un Float en Double exact ;
// les valeurs relues en un objet {accesseur: valeur} ; les arguments d'une opération en un tableau.
// Les valeurs relues le sont sur une copie des préférences : inIsrael, qui fige la valeur du fuseau au
// premier accès, n'y écrit pas. Rien ne dépend de l'heure qu'il est : l'instant que setLieuZmanim
// inscrit est remplacé par celui que donne le cas, et la JVM tourne en UTC (le fuseau du téléphone).

import android.content.Context
import com.myhitbodedut.Adresse
import com.myhitbodedut.Apparence
import com.myhitbodedut.Levana
import com.myhitbodedut.LocalizedText
import com.myhitbodedut.Nusah
import com.myhitbodedut.PoliceHebraique
import com.myhitbodedut.Store
import com.myhitbodedut.Ville
import com.myhitbodedut.Zmanim
import java.util.TimeZone
import org.json.JSONArray
import org.json.JSONObject

object VecteursReglages : Generateur {
    override val fichier = "reglages.json"

    private const val PREFS = "myhitbodedut"

    /** Une valeur de préférence, d'argument ou d'accesseur, telle qu'org.json l'écrit. */
    private fun json(v: Any?): Any = when (v) {
        null -> JSONObject.NULL
        is Set<*> -> JSONArray(v.map { it as String }.sorted())
        is List<*> -> JSONArray().apply { v.forEach { put(json(it)) } }
        is Float -> v.toDouble()
        is Store.SourceHalakha -> v.cle
        is Store.Ouverture -> v.cle
        is Nusah -> v.cle
        is Apparence.Mode -> v.cle
        is Apparence.Fond -> v.cle
        is Apparence.Accent -> v.cle
        is Adresse -> v.cle
        is PoliceHebraique.Police -> v.cle
        is Levana.Usage -> v.cle
        is Zmanim.Lieu -> JSONObject().put("nom", v.nom).put("latitude", v.latitude).put("longitude", v.longitude)
            .put("altitude", v.altitude).put("fuseau", v.fuseau)
        is Store.Celebration -> JSONObject().put("minutes", v.minutes).put("dateNote", v.dateNote ?: JSONObject.NULL)
        else -> v
    }

    /** Le fichier de préférences « myhitbodedut », clés dans leur ordre. */
    private fun prefs(t: Theatre): String {
        val o = JSONObject()
        for ((cle, valeur) in t.prefs(PREFS).valeurs) o.put(cle, json(valeur))
        return o.toString()
    }

    private fun copie(t: Theatre): Theatre = Theatre().also { c ->
        for ((nom, p) in t.toutesLesPrefs) c.prefs(nom).valeurs.putAll(p.valeurs)
    }

    /** Les accesseurs en lecture, sous le nom que Reglages leur donne ; « :fuseau » nomme le fuseau du téléphone. */
    private val lecteurs = LinkedHashMap<String, (Context) -> Any?>().apply {
        fun l(nom: String, f: (Context) -> Any?) { put(nom, f) }
        l("windowStart") { Store.windowStart(it) }
        l("windowEnd") { Store.windowEnd(it) }
        l("snoozeMinutes") { Store.snoozeMinutes(it) }
        l("snoozedUntil") { Store.snoozedUntil(it) }
        l("targetMinutes") { Store.targetMinutes(it) }
        l("dailyGoal") { Store.dailyGoal(it) }
        l("shabbatMode") { Store.shabbatMode(it) }
        l("inIsrael:UTC") { Store.inIsrael(it) }
        l("pausedDates") { Store.pausedDates(it) }
        l("blockedApps") { Store.blockedApps(it) }
        l("isEnabled") { Store.isEnabled(it) }
        l("reminderEnabled") { Store.reminderEnabled(it) }
        l("reminderMinutes") { Store.reminderMinutes(it) }
        l("reminderTimes") { Store.reminderTimes(it) }
        l("reminderSnoozedUntil") { Store.reminderSnoozedUntil(it) }
        l("hideCountdown") { Store.hideCountdown(it) }
        l("guidedHitbodedut") { Store.guidedHitbodedut(it) }
        l("nePasDeranger") { Store.nePasDeranger(it) }
        l("filtreAvantSeance") { Store.filtreAvantSeance(it) }
        l("ambiance") { Store.ambiance(it) }
        l("musicEnabled") { Store.musicEnabled(it) }
        l("musicTrackId") { Store.musicTrackId(it) }
        l("musicShuffle") { Store.musicShuffle(it) }
        l("musicNow") { Store.musicNow(it) }
        l("musicVolume") { Store.musicVolume(it) }
        l("musicUserTracks") { Store.musicUserTracks(it) }
        l("musicNames") { Store.musicNames(it) }
        l("hasOnboarded") { Store.hasOnboarded(it) }
        l("adresse") { Store.adresse(it) }
        l("langueApp") { Store.langueApp(it) }
        l("langueRepli") { Store.langueRepli(it) }
        l("modeApparence") { Store.modeApparence(it) }
        l("fond") { Store.fond(it) }
        l("accent") { Store.accent(it) }
        l("lectureEchelle") { Store.lectureEchelle(it) }
        l("lecturePolice") { Store.lecturePolice(it) }
        l("lectureLangues") { Store.lectureLangues(it) }
        l("lectureSombre") { Store.lectureSombre(it) }
        l("lectureMasquee") { Store.lectureMasquee(it) }
        l("siddurNusah") { Store.siddurNusah(it) }
        l("sansTahanounFinTichri") { Store.sansTahanounFinTichri(it) }
        l("calendrierCivil") { Store.calendrierCivil(it) }
        l("allumage") { Store.allumage(it) }
        l("boussoleRose") { Store.boussoleRose(it) }
        l("boussoleCarte") { Store.boussoleCarte(it) }
        l("volRappelsActifs") { Store.volRappelsActifs(it) }
        l("suiviDirect") { Store.suiviDirect(it) }
        l("volIndicatif") { Store.volIndicatif(it) }
        l("volRappelVu") { Store.volRappelVu(it) }
        l("lieuZmanim") { Store.lieuZmanim(it) }
        l("lieuDepuis") { Store.lieuDepuis(it) }
        l("lieuVille") { Store.lieuVille(it) }
        l("lieuPerime:UTC") { Store.lieuPerime(it, "UTC") }
        l("lieuPerime:Europe/Paris") { Store.lieuPerime(it, "Europe/Paris") }
        l("lieuAlertes:UTC") { Store.lieuAlertes(it) }
        l("lieuAlertes:Europe/Paris") { if (Store.lieuPerime(it, "Europe/Paris")) null else Store.lieuZmanim(it) }
        l("mukafChoma") { Store.mukafChoma(it) }
        l("hemisphereSud") { Store.hemisphereSud(it) }
        l("hilloulotAffichees") { Store.hilloulotAffichees(it) }
        l("halakhaAffichee") { Store.halakhaAffichee(it) }
        l("sourceHalakha") { Store.sourceHalakha(it) }
        l("levanaAffichee") { Store.levanaAffichee(it) }
        l("levanaUsage") { Store.levanaUsage(it) }
        l("levanaRappel") { Store.levanaRappel(it) }
        l("levanaRappelSoir") { Store.levanaRappelSoir(it) }
        l("ouverture") { Store.ouverture(it) }
        l("anneauxFetes") { Store.anneauxFetes(it) }
        l("paliersVus") { Store.paliersVus(it) }
        l("paliersNotifies") { Store.paliersNotifies(it) }
        l("tropheesVus") { Store.tropheesVus(it) }
        l("tropheesNotifies") { Store.tropheesNotifies(it) }
        l("tropheesProchesSignales") { Store.tropheesProchesSignales(it) }
        l("gradeVu") { Store.gradeVu(it) }
        l("bilanVu") { Store.bilanVu(it) }
        l("rappelTropheeProche") { Store.rappelTropheeProche(it) }
        l("hasPendingCelebration") { Store.hasPendingCelebration(it) }
    }

    private fun texteOuNul(a: JSONArray, i: Int): String? = if (a.isNull(i)) null else a.getString(i)
    private fun chaines(a: JSONArray, i: Int): Set<String> = a.getJSONArray(i).let { t -> (0 until t.length()).map { t.getString(it) }.toSet() }

    /** Les opérations, sous le nom de la fonction de Reglages ; une clé passe par la lecture de l'énumération, comme l'écran. */
    private val operations = LinkedHashMap<String, (Context, JSONArray) -> Any?>().apply {
        fun o(nom: String, f: (Context, JSONArray) -> Any?) { put(nom, f) }
        o("setWindow") { c, a -> Store.setWindow(c, a.getInt(0), a.getInt(1)) }
        o("setSnoozeMinutes") { c, a -> Store.setSnoozeMinutes(c, a.getInt(0)) }
        o("clearSnooze") { c, _ -> Store.clearSnooze(c) }
        o("setTargetMinutes") { c, a -> Store.setTargetMinutes(c, a.getInt(0)) }
        o("setDailyGoal") { c, a -> Store.setDailyGoal(c, a.getInt(0)) }
        o("setShabbatMode") { c, a -> Store.setShabbatMode(c, a.getBoolean(0)) }
        o("setInIsrael") { c, a -> Store.setInIsrael(c, a.getBoolean(0)) }
        o("figeInIsrael:UTC") { c, _ -> Store.inIsrael(c) }
        o("togglePausedDate") { c, a -> Store.togglePausedDate(c, a.getString(0)) }
        o("setBlockedApps") { c, a -> Store.setBlockedApps(c, chaines(a, 0)) }
        o("setEnabled") { c, a -> Store.setEnabled(c, a.getBoolean(0)) }
        o("setReminderEnabled") { c, a -> Store.setReminderEnabled(c, a.getBoolean(0)) }
        o("setReminderMinutes") { c, a -> Store.setReminderMinutes(c, a.getInt(0)) }
        o("setReminderTimes") { c, a -> Store.setReminderTimes(c, a.getJSONArray(0).let { t -> (0 until t.length()).map { t.getInt(it) } }) }
        o("setReminderSnoozedUntil") { c, a -> Store.setReminderSnoozedUntil(c, a.getLong(0)) }
        o("setHideCountdown") { c, a -> Store.setHideCountdown(c, a.getBoolean(0)) }
        o("setGuidedHitbodedut") { c, a -> Store.setGuidedHitbodedut(c, a.getBoolean(0)) }
        o("setNePasDeranger") { c, a -> Store.setNePasDeranger(c, a.getBoolean(0)) }
        o("setFiltreAvantSeance") { c, a -> Store.setFiltreAvantSeance(c, if (a.isNull(0)) null else a.getInt(0)) }
        o("setAmbiance") { c, a -> Store.setAmbiance(c, a.getString(0)) }
        o("setMusicEnabled") { c, a -> Store.setMusicEnabled(c, a.getBoolean(0)) }
        o("setMusicTrackId") { c, a -> Store.setMusicTrackId(c, texteOuNul(a, 0)) }
        o("setMusicShuffle") { c, a -> Store.setMusicShuffle(c, a.getBoolean(0)) }
        o("setMusicNow") { c, a -> Store.setMusicNow(c, texteOuNul(a, 0)) }
        o("setMusicVolume") { c, a -> Store.setMusicVolume(c, a.getInt(0)) }
        o("setMusicUserTracks") { c, a -> Store.setMusicUserTracks(c, a.getString(0)) }
        o("setMusicNames") { c, a -> Store.setMusicNames(c, a.getString(0)) }
        o("setOnboarded") { c, _ -> Store.setOnboarded(c) }
        o("setAdresse") { c, a -> Store.setAdresse(c, Adresse.parse(texteOuNul(a, 0))) }
        o("setLangueApp") { c, a -> Store.setLangueApp(c, a.getString(0)) }
        o("setLangueRepli") { c, a -> Store.setLangueRepli(c, a.getBoolean(0)) }
        o("setModeApparence") { c, a -> Store.setModeApparence(c, Apparence.Mode.parse(a.getString(0))) }
        o("setFond") { c, a -> Store.setFond(c, Apparence.Fond.parse(a.getString(0))) }
        o("setAccent") { c, a -> Store.setAccent(c, Apparence.Accent.parse(a.getString(0))) }
        o("setLectureEchelle") { c, a -> Store.setLectureEchelle(c, a.getDouble(0).toFloat()) }
        o("setLecturePolice") { c, a ->
            val cle = a.getString(0)
            Store.setLecturePolice(c, PoliceHebraique.Police.entries.firstOrNull { it.cle == cle } ?: PoliceHebraique.Police.SERIF)
        }
        o("setLectureLangues") { c, a -> Store.setLectureLangues(c, a.getString(0)) }
        o("setLectureSombre") { c, a -> Store.setLectureSombre(c, a.getBoolean(0)) }
        o("setLectureMasquee") { c, a -> Store.setLectureMasquee(c, a.getBoolean(0)) }
        o("setSiddurNusah") { c, a -> Store.setSiddurNusah(c, Nusah.de(a.getString(0))) }
        o("setSansTahanounFinTichriSfard") { c, a -> Store.setSansTahanounFinTichriSfard(c, a.getBoolean(0)) }
        o("setCalendrierCivil") { c, a -> Store.setCalendrierCivil(c, a.getBoolean(0)) }
        o("setAllumage") { c, a -> Store.setAllumage(c, a.getInt(0)) }
        o("setBoussoleRose") { c, a -> Store.setBoussoleRose(c, a.getBoolean(0)) }
        o("setBoussoleCarte") { c, a -> Store.setBoussoleCarte(c, a.getBoolean(0)) }
        o("setVolRappelsActifs") { c, a -> Store.setVolRappelsActifs(c, a.getBoolean(0)) }
        o("setSuiviDirect") { c, a -> Store.setSuiviDirect(c, a.getBoolean(0)) }
        o("setVolIndicatif") { c, a -> Store.setVolIndicatif(c, a.getString(0)) }
        o("setVolRappelVu") { c, a -> Store.setVolRappelVu(c, a.getLong(0)) }
        // [nom, latitude, longitude, altitude, fuseau, identifiant de la ville ou null, pays de la ville, instant].
        o("setLieuZmanim") { c, a ->
            val lieu = Zmanim.Lieu(a.getString(0), a.getDouble(1), a.getDouble(2), a.getDouble(3), a.getString(4))
            val ville = if (a.isNull(5)) null else Ville(a.getLong(5), LocalizedText("", lieu.nom, ""), a.getString(6),
                lieu.latitude, lieu.longitude, lieu.altitude, lieu.fuseau)
            Store.setLieuZmanim(c, lieu, ville)
            // L'instant de l'enregistrement est celui de l'horloge : on le remplace par celui du cas, à sa place.
            val p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE) as PrefsMemoire
            check(p.valeurs.containsKey("lieu_t")) { "setLieuZmanim n'inscrit plus lieu_t" }
            p.valeurs["lieu_t"] = a.getLong(7)
        }
        o("setHilloulotAffichees") { c, a -> Store.setHilloulotAffichees(c, a.getBoolean(0)) }
        o("setHalakhaAffichee") { c, a -> Store.setHalakhaAffichee(c, a.getBoolean(0)) }
        o("setSourceHalakha") { c, a ->
            val cle = a.getString(0)
            Store.setSourceHalakha(c, Store.SourceHalakha.values().first { it.cle == cle })
        }
        o("setLevanaAffichee") { c, a -> Store.setLevanaAffichee(c, a.getBoolean(0)) }
        o("setLevanaUsage") { c, a ->
            val cle = texteOuNul(a, 0)
            Store.setLevanaUsage(c, Levana.Usage.values().firstOrNull { it.cle == cle })
        }
        o("setLevanaRappel") { c, a -> Store.setLevanaRappel(c, a.getBoolean(0)) }
        o("setLevanaRappelSoir") { c, a -> Store.setLevanaRappelSoir(c, a.getString(0)) }
        o("setOuverture") { c, a ->
            val cle = a.getString(0)
            Store.setOuverture(c, Store.Ouverture.values().first { it.cle == cle })
        }
        o("setAnneauxFetes") { c, a -> Store.setAnneauxFetes(c, chaines(a, 0)) }
        o("setPaliersVus") { c, a -> Store.setPaliersVus(c, chaines(a, 0)) }
        o("setPaliersNotifies") { c, a -> Store.setPaliersNotifies(c, chaines(a, 0)) }
        o("setTropheesVus") { c, a -> Store.setTropheesVus(c, chaines(a, 0)) }
        o("setTropheesNotifies") { c, a -> Store.setTropheesNotifies(c, chaines(a, 0)) }
        o("setTropheesProchesSignales") { c, a -> Store.setTropheesProchesSignales(c, chaines(a, 0)) }
        o("setGradeVu") { c, a -> Store.setGradeVu(c, a.getInt(0)) }
        o("setBilanVu") { c, a -> Store.setBilanVu(c, a.getString(0)) }
        o("setRappelTropheeProche") { c, a -> Store.setRappelTropheeProche(c, a.getBoolean(0)) }
        o("setPendingCelebration") { c, a -> Store.setPendingCelebration(c, a.getInt(0), texteOuNul(a, 1)) }
        o("takePendingCelebration") { c, _ -> Store.takePendingCelebration(c) }
    }

    /** Les opérations qui rendent une valeur. */
    private val rendent = setOf("figeInIsrael:UTC", "takePendingCelebration")

    private class Cas(val nom: String, val relus: List<String>, val depart: Map<String, Any>, val etapes: List<Pair<String, List<Any?>>>)

    private fun cas(nom: String, relus: List<String>, depart: Map<String, Any>, vararg etapes: Pair<String, List<Any?>>) =
        Cas(nom, relus, depart, etapes.toList())

    /** Une écriture par valeur, chacune sur les préférences [depart]. */
    private fun chaque(op: String, relus: List<String>, valeurs: List<Any?>, depart: Map<String, Any> = emptyMap()): List<Cas> =
        valeurs.map { v -> Cas("$op($v)", relus, depart, listOf(op to listOf(v))) }

    private val booleens = listOf(true, false)

    private val lieux = listOf(
        "lieuZmanim", "lieuDepuis", "lieuVille", "lieuPerime:UTC", "lieuPerime:Europe/Paris",
        "lieuAlertes:UTC", "lieuAlertes:Europe/Paris", "mukafChoma", "hemisphereSud", "inIsrael:UTC",
    )

    private fun ecritures(): List<Cas> = buildList {
        val fenetre = listOf("windowStart", "windowEnd")
        for ((a, b) in listOf(360 to 660, 0 to 1439, -1 to 1440, 1320 to 120, 660 to 360, 0 to 0, 99_999 to -99_999,
            Int.MAX_VALUE to Int.MIN_VALUE)) {
            add(cas("setWindow($a, $b)", fenetre, emptyMap(), "setWindow" to listOf(a, b)))
        }
        // La fin déjà posée garde sa place, le début se range après elle.
        add(cas("setWindow sur une fin posée", fenetre, mapOf("window_end" to 700, "autre" to "x"), "setWindow" to listOf(300, 800)))
        addAll(chaque("setSnoozeMinutes", listOf("snoozeMinutes"), listOf(0, 1, 15, 240, 241, -5, 100_000)))
        add(cas("clearSnooze", listOf("snoozedUntil"), emptyMap(), "clearSnooze" to emptyList()))
        add(cas("clearSnooze après un report", listOf("snoozedUntil"), mapOf("snoozed_until" to 1_700_000_000_000L), "clearSnooze" to emptyList()))
        addAll(chaque("setTargetMinutes", listOf("targetMinutes", "dailyGoal"), listOf(0, 1, 15, 240, 241, -1)))
        addAll(chaque("setDailyGoal", listOf("dailyGoal", "targetMinutes"), listOf(-1, 0, 1, 30, 240, 241, 100_000)))
        addAll(chaque("setDailyGoal", listOf("dailyGoal"), listOf(0, 20), depart = mapOf("target_minutes" to 0)))
        addAll(chaque("setDailyGoal", listOf("dailyGoal"), listOf(0, 20), depart = mapOf("target_minutes" to -30)))
        addAll(chaque("setShabbatMode", listOf("shabbatMode"), booleens))
        addAll(chaque("setInIsrael", listOf("inIsrael:UTC"), booleens))
        add(cas("figeInIsrael sans valeur", listOf("inIsrael:UTC"), emptyMap(), "figeInIsrael:UTC" to emptyList()))
        add(cas("figeInIsrael déjà posé", listOf("inIsrael:UTC"), mapOf("in_israel" to true), "figeInIsrael:UTC" to emptyList()))
        add(cas("togglePausedDate", listOf("pausedDates"), emptyMap(),
            "togglePausedDate" to listOf("2026-10-01"), "togglePausedDate" to listOf("2026-09-30"),
            "togglePausedDate" to listOf("2026-10-01"), "togglePausedDate" to listOf("pas une date"),
            "togglePausedDate" to listOf(""), "togglePausedDate" to listOf("2026-09-30")))
        add(cas("setBlockedApps", listOf("blockedApps"), emptyMap(),
            "setBlockedApps" to listOf(listOf("com.whatsapp", "com.instagram.android")), "setBlockedApps" to listOf(listOf("b", "a", "b", "")),
            "setBlockedApps" to listOf(emptyList<String>())))
        addAll(chaque("setEnabled", listOf("isEnabled"), booleens))
        addAll(chaque("setReminderEnabled", listOf("reminderEnabled"), booleens))
        val rappels = listOf("reminderMinutes", "reminderTimes")
        addAll(chaque("setReminderMinutes", rappels, listOf(-1, 0, 420, 1439, 1440, 5000)))
        addAll(chaque("setReminderTimes", rappels, listOf(emptyList<Int>(), listOf(420), listOf(1260, 420, 1260), listOf(-1, 0, 1439, 1440),
            listOf(5000), listOf(1439, 0, 720, 0))))
        // Une heure seule posée par une version d'avant la liste : reprise telle quelle, sans contrôle.
        addAll(chaque("setReminderTimes", rappels, listOf(listOf(600)), depart = mapOf("reminder_minutes" to 5000)))
        addAll(chaque("setReminderSnoozedUntil", listOf("reminderSnoozedUntil"), listOf(0L, 1_700_000_000_000L, -1L, Long.MAX_VALUE)))
        addAll(chaque("setHideCountdown", listOf("hideCountdown"), booleens))
        addAll(chaque("setGuidedHitbodedut", listOf("guidedHitbodedut"), booleens))
        addAll(chaque("setNePasDeranger", listOf("nePasDeranger"), booleens))
        addAll(chaque("setFiltreAvantSeance", listOf("filtreAvantSeance"), listOf(null, 0, 3, -1, -7)))
        addAll(chaque("setFiltreAvantSeance", listOf("filtreAvantSeance"), listOf(null), depart = mapOf("filtre_avant_seance" to 2)))
        addAll(chaque("setAmbiance", listOf("ambiance"), listOf("silence", "pluie", "", "inconnue")))
        addAll(chaque("setMusicEnabled", listOf("musicEnabled"), booleens))
        addAll(chaque("setMusicTrackId", listOf("musicTrackId"), listOf(null, "", "hamelech_basade", "content://media/external/audio/1")))
        addAll(chaque("setMusicTrackId", listOf("musicTrackId"), listOf(null), depart = mapOf("music_track" to "ianir_1")))
        addAll(chaque("setMusicShuffle", listOf("musicShuffle"), booleens))
        addAll(chaque("setMusicNow", listOf("musicNow"), listOf(null, "", "shpayer_2")))
        addAll(chaque("setMusicNow", listOf("musicNow"), listOf(null), depart = mapOf("music_now" to "shpayer_2")))
        addAll(chaque("setMusicVolume", listOf("musicVolume"), listOf(-1, 0, 1, 50, 99, 100, 101, -100_000, 100_000, Int.MIN_VALUE, Int.MAX_VALUE)))
        addAll(chaque("setMusicUserTracks", listOf("musicUserTracks"), listOf("[]", "[{\"uri\":\"content://x\"}]", "")))
        addAll(chaque("setMusicNames", listOf("musicNames"), listOf("{}", "{\"a\":\"Nigoun\"}", "")))
        add(cas("setOnboarded", listOf("hasOnboarded"), emptyMap(), "setOnboarded" to emptyList()))
        add(cas("setOnboarded après la v1.96", listOf("hasOnboarded"), mapOf("onboarded" to true, "onboarded_version" to 1),
            "setOnboarded" to emptyList()))
        addAll(chaque("setAdresse", listOf("adresse"), listOf("m", "f", null, "x", "M", "")))
        addAll(chaque("setAdresse", listOf("adresse"), listOf(null, "x"), depart = mapOf("adresse" to "f")))
        addAll(chaque("setLangueApp", listOf("langueApp"), listOf("", "he", "fr-FR,en")))
        addAll(chaque("setLangueRepli", listOf("langueRepli"), booleens))
        addAll(chaque("setModeApparence", listOf("modeApparence"), listOf("auto", "clair", "sombre", "SOMBRE", "", "nuit")))
        addAll(chaque("setFond", listOf("fond"), Apparence.Fond.values().map { it.cle } + listOf("VERT", "", "noir")))
        addAll(chaque("setAccent", listOf("accent"), Apparence.Accent.values().map { it.cle } + listOf("Bleu", "", "or")))
        addAll(chaque("setLectureEchelle", listOf("lectureEchelle"), listOf(0f, 0.5f, 0.79f, 0.8f, 1f, 1.1f, 1.3f, 2f, 2.01f, 2.5f, -1f,
            Float.MAX_VALUE, Float.MIN_VALUE)))
        addAll(chaque("setLecturePolice", listOf("lecturePolice"), PoliceHebraique.Police.entries.map { it.cle } + listOf("SERIF", "", "mono")))
        addAll(chaque("setLectureLangues", listOf("lectureLangues"), listOf("he", "he+fr", "fr+en", "", "xx")))
        addAll(chaque("setLectureSombre", listOf("lectureSombre"), booleens))
        addAll(chaque("setLectureMasquee", listOf("lectureMasquee"), booleens))
        val siddour = listOf("siddurNusah", "sansTahanounFinTichri")
        addAll(chaque("setSiddurNusah", siddour, Nusah.values().map { it.cle } + listOf("EDOT", "", "sfard")))
        for (nusah in Nusah.values()) {
            addAll(chaque("setSansTahanounFinTichriSfard", siddour, booleens, depart = mapOf("siddur_nusah" to nusah.cle)))
        }
        addAll(chaque("setCalendrierCivil", listOf("calendrierCivil"), booleens))
        addAll(chaque("setAllumage", listOf("allumage"), listOf(17, 18, 19, 20, 22, 30, 40, 41, 0, -18, 1000)))
        addAll(chaque("setBoussoleRose", listOf("boussoleRose"), booleens))
        addAll(chaque("setBoussoleCarte", listOf("boussoleCarte"), booleens))
        addAll(chaque("setVolRappelsActifs", listOf("volRappelsActifs"), booleens))
        addAll(chaque("setSuiviDirect", listOf("suiviDirect"), booleens))
        addAll(chaque("setVolIndicatif", listOf("volIndicatif"), listOf("ELY1", "", " LY 315 ")))
        addAll(chaque("setVolRappelVu", listOf("volRappelVu"), listOf(0L, 1_760_000_000_000L, -1L, Long.MAX_VALUE)))
        // [nom, latitude, longitude, altitude, fuseau, ville ou null, pays, instant].
        for (args in listOf(
            listOf("Jérusalem", 31.76904, 35.21633, 786.0, "Asia/Jerusalem", 281184L, "IL", 1_760_000_000_000L),
            listOf("Ma position", 31.78, 35.22, 0.0, "Asia/Jerusalem", null, "", 1_760_000_000_001L),
            listOf("Ma position", 48.8566, 2.3522, 35.0, "Europe/Paris", null, "", 1_762_000_000_000L),
            listOf("Paris", 48.85341, 2.3488, 42.0, "Europe/Paris", 2988507L, "FR", 1L),
            listOf("Sydney", -33.86785, 151.20732, 58.0, "Australia/Sydney", 2147714L, "AU", 0L),
            listOf("Tel Aviv", 32.08088, 34.78057, 15.0, "Asia/Jerusalem", null, "", 1_700_000_000_000L),
            listOf("", 0.0, 0.0, 0.0, "UTC", null, "", 2L),
            listOf("Nord", 90.0, -180.0, -10.5, "UTC", 1L, "IL", 3L),
        )) {
            add(cas("setLieuZmanim(${args[0]}, ${args[4]})", lieux, emptyMap(), "setLieuZmanim" to args))
        }
        addAll(chaque("setHilloulotAffichees", listOf("hilloulotAffichees"), booleens))
        addAll(chaque("setHalakhaAffichee", listOf("halakhaAffichee"), booleens))
        addAll(chaque("setSourceHalakha", listOf("sourceHalakha"), Store.SourceHalakha.values().map { it.cle }))
        addAll(chaque("setLevanaAffichee", listOf("levanaAffichee"), booleens))
        addAll(chaque("setLevanaUsage", listOf("levanaUsage"), Levana.Usage.values().map { it.cle } + listOf(null, "", "TROIS_MI_MOIS")))
        addAll(chaque("setLevanaUsage", listOf("levanaUsage"), listOf(null, "x"), depart = mapOf("levana_usage" to "sept_quinze")))
        addAll(chaque("setLevanaRappel", listOf("levanaRappel"), booleens))
        addAll(chaque("setLevanaRappelSoir", listOf("levanaRappelSoir"), listOf("2026-10-14", "")))
        addAll(chaque("setOuverture", listOf("ouverture"), Store.Ouverture.values().map { it.cle }))
        val marques = listOf(emptyList<String>(), listOf("serie_7"), listOf("mois:2026-10", "jour:2026-10-01", "mois:2026-10"))
        addAll(chaque("setAnneauxFetes", listOf("anneauxFetes"), marques))
        addAll(chaque("setPaliersVus", listOf("paliersVus"), marques))
        addAll(chaque("setPaliersNotifies", listOf("paliersNotifies"), marques))
        addAll(chaque("setTropheesVus", listOf("tropheesVus"), marques))
        addAll(chaque("setTropheesNotifies", listOf("tropheesNotifies"), marques))
        addAll(chaque("setTropheesProchesSignales", listOf("tropheesProchesSignales"), marques))
        addAll(chaque("setGradeVu", listOf("gradeVu"), listOf(-1, 0, 5, -8)))
        addAll(chaque("setBilanVu", listOf("bilanVu"), listOf("2026-10-11", "")))
        addAll(chaque("setRappelTropheeProche", listOf("rappelTropheeProche"), booleens))
        val bravo = listOf("hasPendingCelebration")
        add(cas("célébration", bravo, emptyMap(),
            "takePendingCelebration" to emptyList(), "setPendingCelebration" to listOf(20, null),
            "setPendingCelebration" to listOf(-5, "2026-10-01"), "takePendingCelebration" to emptyList(),
            "takePendingCelebration" to emptyList(), "setPendingCelebration" to listOf(45, "2026-10-02"),
            "setPendingCelebration" to listOf(30, null), "takePendingCelebration" to emptyList()))
        // Une clé qu'aucun accesseur ne lit reste à sa place, quoi qu'on écrive autour.
        add(cas("clés inconnues gardées", listOf("snoozeMinutes", "pausedDates", "musicTrackId"),
            linkedMapOf("vol_numero" to "LY315", "snooze_minutes" to 20, "cle_future" to 7L, "chizuk_bag_ouverture" to "a\nb",
                "paused_dates" to linkedSetOf("2026-10-02", "2026-10-01"), "music_track" to "ianir_3"),
            "setSnoozeMinutes" to listOf(30), "togglePausedDate" to listOf("2026-10-01"), "setMusicTrackId" to listOf(null),
            "setMusicTrackId" to listOf("ianir_4"), "setShabbatMode" to listOf(false)))
    }

    /** Des préférences posées à la main, et ce que leurs accesseurs en lisent. */
    private fun lectures(): List<Pair<Map<String, Any>, List<String>>> = buildList {
        fun lis(relus: List<String>, vararg departs: Map<String, Any>) { for (d in departs) add(d to relus) }
        for (v in listOf(-1, 0, 17, 18, 19, 20, 21, 22, 30, 40, 41, 1000)) lis(listOf("allumage"), mapOf("allumage_minutes" to v))
        for (v in listOf(0f, 0.5f, 0.79f, 0.8f, 0.81f, 1f, 1.1f, 1.5f, 1.99f, 2f, 2.01f, 10f, -1f, -0f, Float.MAX_VALUE, Float.MIN_VALUE, 1e-30f)) {
            lis(listOf("lectureEchelle"), mapOf("lecture_echelle" to v))
        }
        for (v in listOf("edot", "sefard", "ashkenaz", "EDOT", "", " edot", "sfard", "inconnu")) {
            for (sfard in booleens) {
                lis(listOf("siddurNusah", "sansTahanounFinTichri"), mapOf("siddur_nusah" to v, "sans_tahanoun_fin_tichri_sfard" to sfard))
            }
        }
        for (v in listOf("yalkut", "ben_ish_hai", "les_deux", "YALKUT", "BEN_ISH_HAI", "", "deux")) lis(listOf("sourceHalakha"), mapOf("halakha_source" to v))
        for (v in listOf("aujourdhui", "textes", "zmanim", "TEXTES", "", "accueil")) lis(listOf("ouverture"), mapOf("ecran_ouverture" to v))
        for (v in listOf("auto", "clair", "sombre", "Clair", "", "nuit")) lis(listOf("modeApparence"), mapOf("apparence_mode" to v))
        for (v in Apparence.Fond.values().map { it.cle } + listOf("Rose", " vert", "")) lis(listOf("fond"), mapOf("apparence_fond" to v))
        for (v in Apparence.Accent.values().map { it.cle } + listOf("AMBRE", "ambre ", "")) lis(listOf("accent"), mapOf("apparence_accent" to v))
        for (v in listOf("m", "f", "M", "F", "", " m", "mf", "homme")) lis(listOf("adresse"), mapOf("adresse" to v))
        for (v in PoliceHebraique.Police.entries.map { it.cle } + listOf("Serif", "", "rashi")) lis(listOf("lecturePolice"), mapOf("lecture_police" to v))
        for (v in Levana.Usage.values().map { it.cle } + listOf("", "SEPT_QUINZE")) lis(listOf("levanaUsage"), mapOf("levana_usage" to v))
        val rappels = listOf("reminderTimes", "reminderMinutes")
        for (v in listOf("420", "420,1260", " 1260 , 420 ", "", ",", ",,420,", "abc", "420,abc,1260", "-1,0,1439,1440", "1260,420,1260",
            "+60", "06", "0060", "\u0663\u0660\u0660", "\uff11\uff12\uff10", "1e3", "420.5", "2147483647,2147483648", "-0", "60\t,\u00a090",
            "\u200b60", "420,", "\u2007 30 \u3000")) {
            lis(rappels, mapOf("reminder_times" to v), mapOf("reminder_minutes" to 300, "reminder_times" to v))
        }
        for (v in listOf(-5, 0, 300, 1439, 1440, 5000)) lis(rappels, mapOf("reminder_minutes" to v))
        for (v in booleens) lis(listOf("inIsrael:UTC"), mapOf("in_israel" to v))
        for ((regle, duree) in listOf(0 to 15, 0 to 0, 0 to -5, 30 to 15, -3 to 20, 1 to 240, 300 to 1)) {
            lis(listOf("dailyGoal"), mapOf("daily_goal_minutes" to regle, "target_minutes" to duree))
        }
        lis(listOf("dailyGoal"), mapOf("daily_goal_minutes" to 0), mapOf("target_minutes" to 0), mapOf("daily_goal_minutes" to 25))
        for (v in listOf(-1, 0, 1, 2, 5, -5)) lis(listOf("filtreAvantSeance"), mapOf("filtre_avant_seance" to v))
        for (v in listOf(-1, 0, 3, -2)) lis(listOf("gradeVu"), mapOf("grade_vu" to v))
        val ensembles = listOf("paliersVus", "paliersNotifies", "tropheesVus", "tropheesNotifies", "anneauxFetes", "tropheesProchesSignales")
        lis(ensembles, mapOf("paliers_vus" to linkedSetOf<String>(), "trophees_vus" to linkedSetOf("b", "a"), "anneaux_fetes" to linkedSetOf("z", "y", "Z"),
            "trophees_proches_signales" to linkedSetOf("é", "e", "f")))
        for (v in listOf(0, 1, 2, 3)) lis(listOf("hasOnboarded"), mapOf("onboarded_version" to v))
        lis(listOf("hasPendingCelebration"), mapOf("celebration_minutes" to 0), mapOf("celebration_date" to "2026-10-01"))
        lis(listOf("musicUserTracks", "musicNames", "ambiance", "musicTrackId", "levanaRappelSoir", "bilanVu", "lectureLangues", "langueApp"),
            mapOf("music_user_tracks" to "", "music_names" to "x", "ambiance" to "", "music_track" to "", "levana_rappel_soir" to "",
                "bilan_vu" to "", "lecture_langues" to "", "langue_app" to " he "))
        // Le lieu : des nombres gardés en texte, lus par toDoubleOrNull.
        for (lat in listOf("31.7683", " 31.7683 ", "31,7683", "", "abc", "1e1", "-33.8688", "+2.35", "2.35d", "2.35f", ".5", "5.", "-0", "1_0",
            "\u0663\u0661")) {
            lis(lieux, mapOf("lieu_latitude" to lat, "lieu_longitude" to "35.2137", "lieu_fuseau" to "Asia/Jerusalem"))
        }
        lis(lieux,
            mapOf("lieu_latitude" to "31.7683", "lieu_longitude" to "35.2137"),
            mapOf("lieu_latitude" to "31.7683", "lieu_fuseau" to "Asia/Jerusalem"),
            mapOf("lieu_longitude" to "35.2137", "lieu_fuseau" to "Asia/Jerusalem"),
            mapOf("lieu_nom" to "Kotel", "lieu_latitude" to "31.7767", "lieu_longitude" to "35.2345", "lieu_altitude" to "abc", "lieu_fuseau" to "Asia/Jerusalem"),
            mapOf("lieu_nom" to "Kotel", "lieu_latitude" to "31.7767", "lieu_longitude" to "35.2345", "lieu_altitude" to "740.5", "lieu_fuseau" to "UTC",
                "lieu_ville" to -1L, "lieu_t" to 1_760_000_000_000L),
            mapOf("lieu_latitude" to "31.7767", "lieu_longitude" to "35.2345", "lieu_fuseau" to "UTC", "lieu_ville" to 281184L),
            mapOf("lieu_latitude" to "48.85", "lieu_longitude" to "2.35", "lieu_fuseau" to "Europe/Paris", "lieu_ville" to 2988507L),
            mapOf("lieu_latitude" to "-37.81", "lieu_longitude" to "144.96", "lieu_fuseau" to "Australia/Melbourne"),
            mapOf("lieu_ville" to 281184L),
            mapOf("lieu_latitude" to "31.70", "lieu_longitude" to "35.20", "lieu_fuseau" to "Asia/Jerusalem"),
            mapOf("lieu_latitude" to "31.80", "lieu_longitude" to "35.16", "lieu_fuseau" to "Asia/Jerusalem"),
            mapOf("lieu_latitude" to "31.7767", "lieu_longitude" to "35.26", "lieu_fuseau" to "Asia/Jerusalem"),
        )
    }

    private fun theatre(depart: Map<String, Any>): Theatre = Theatre().also { it.prefs(PREFS).valeurs.putAll(depart) }

    private fun relus(t: Theatre, noms: List<String>): String {
        val contexte = copie(t).contexte
        val o = JSONObject()
        for (nom in noms) o.put(nom, json(lecteurs.getValue(nom)(contexte)))
        return o.toString()
    }

    private fun rejoue(c: Cas): Map<String, Any?> {
        val t = theatre(c.depart)
        val depart = prefs(t)
        val etapes = c.etapes.map { (op, args) ->
            val a = JSONArray().apply { args.forEach { put(json(it)) } }
            val rendu = operations.getValue(op)(t.contexte, a)
            linkedMapOf("op" to op, "args" to a.toString(),
                "rendu" to if (op in rendent) JSONObject().put("v", json(rendu)).toString() else null,
                "relu" to relus(t, c.relus), "prefs" to prefs(t))
        }
        return linkedMapOf("nom" to c.nom, "depart" to depart, "etapes" to etapes)
    }

    override fun produire(): Map<String, Any?> {
        check(TimeZone.getDefault().id == "UTC") { "la JVM des vecteurs doit tourner en UTC (fuseau du téléphone)" }
        val neuf = Theatre()
        val defauts = relus(neuf, lecteurs.keys.toList())
        // Le premier accès à inIsrael fige la valeur du fuseau du téléphone.
        Store.inIsrael(neuf.contexte)
        return linkedMapOf(
            "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursReglages.kt"),
            "defauts" to linkedMapOf("relu" to defauts, "prefsApresInIsrael" to prefs(neuf)),
            "ecritures" to ecritures().map(::rejoue),
            "lectures" to lectures().map { (depart, noms) ->
                val t = theatre(depart)
                linkedMapOf("prefs" to prefs(t), "relu" to relus(t, noms))
            },
        )
    }
}
