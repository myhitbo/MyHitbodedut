// La sauvegarde d'Android devant la JVM : Store.importJson et Store.exportJson sur un Theatre. Chaque
// scénario part d'un état (posé par les setters de Store, par un texte du journal posé à la main ou par
// un premier import), importe un fichier, puis dit ce qu'Android rend : le nombre de journées importées
// (null : fichier invalide), les préférences des deux fichiers avant et après, l'export complet (sans la
// ligne « exported_at », qui dépend de l'heure), les jours de pause, les applications bloquées et le
// prénom. SauvegardeTests de Coeur les rejoue sur Sauvegarde.importer et Sauvegarde.exporter.
//
// importJson lit la date du jour (LocalDate.now(), figée par bouchons/Horloge.kt au 1er janvier 2026) :
// les journées des fichiers sont loin dans le passé (acceptées), en 2999 (refusées), ou à la frontière,
// aujourd'hui (accepté) et demain (refusé). Le fuseau du téléphone, qui fige in_israel (Store.inIsrael),
// est celui du scénario (« fuseau » : UTC, ou Asia/Jerusalem), à midi le même jour. Les adaptations
// d'iOS (PORTAGE.md § 3.5) n'y figurent pas : un morceau qui n'est pas livré sur iOS, une valeur
// d'apparence inconnue, journal_plus, le JSON relâché (apostrophes, clés nues) qu'org.json accepte et
// que Coeur refuse. Les morceaux nommés ici sont livrés sur iOS (ios/Ressources/Contenu/musique.json).

import android.content.Context
import com.myhitbodedut.Adresse
import com.myhitbodedut.Apparence
import com.myhitbodedut.JournalPlus
import com.myhitbodedut.Store
import com.myhitbodedut.Theme
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZoneOffset

object VecteursSauvegarde : Generateur {
    override val fichier = "sauvegarde.json"

    private const val JOURNAL = "myhitbodedut-journal"
    private const val REGLAGES = "myhitbodedut"

    /** Les morceaux livrés sur iOS que les scénarios nomment. */
    private val morceauxLivres = listOf("hamelech_basade", "yanuka_nigoun_3", "shpayer_beyond")

    private class Scenario(val nom: String, val fichier: String, val depart: (Theatre) -> Unit = {}) {
        /** Le fuseau du téléphone. */
        var zone: ZoneId = ZoneOffset.UTC

        fun dans(z: ZoneId): Scenario {
            zone = z
            return this
        }
    }

    private val jerusalem: ZoneId = ZoneId.of("Asia/Jerusalem")

    // --- Les états ---------------------------------------------------------------------------------

    /** Une préférence : [clé, type, valeur] ; un ensemble est trié par unités UTF-16 (String.compareTo). */
    private fun prefs(t: Theatre): List<List<Any?>> = t.prefs(REGLAGES).valeurs.map { (cle, valeur) ->
        when (valeur) {
            is Int -> listOf(cle, "int", valeur)
            is Long -> listOf(cle, "long", valeur)
            is Boolean -> listOf(cle, "bool", valeur)
            is String -> listOf(cle, "string", valeur)
            is Float -> listOf(cle, "float", valeur.toDouble())
            is Set<*> -> listOf(cle, "set", valeur.map { it as String }.sorted())
            else -> error("préférence d'un type inattendu : $cle")
        }
    }

    private val clesDuJournal = setOf("days", "journal_plus", "first_name", "days_corrompu")

    private fun journal(t: Theatre): Map<String, Any?> {
        val valeurs = t.prefs(JOURNAL).valeurs
        check(clesDuJournal.containsAll(valeurs.keys)) { "clé inattendue du journal : ${valeurs.keys}" }
        return linkedMapOf("days" to valeurs["days"] as String?, "journal_plus" to valeurs["journal_plus"] as String?,
            "first_name" to valeurs["first_name"] as String?, "days_corrompu" to valeurs["days_corrompu"] as String?)
    }

    private fun etat(t: Theatre): Map<String, Any?> = linkedMapOf("prefs" to prefs(t), "journal" to journal(t))

    /** L'export d'Android sans la ligne « exported_at » : la ligne entière, virgule comprise, s'en va. */
    private fun export(c: Context): String {
        val lignes = Store.exportJson(c).split("\n")
        val sans = lignes.filterNot { it.startsWith("  \"exported_at\": ") }
        check(sans.size == lignes.size - 1) { "exported_at introuvable" }
        return sans.joinToString("\n")
    }

    private fun rejoue(s: Scenario): Map<String, Any?> {
        // Le même jour, à midi, dans le fuseau du scénario : aujourd'hui reste le 1er janvier 2026.
        Horloge.regler(LocalDateTime.of(2026, 1, 1, 12, 0), s.zone)
        val fuseau = Horloge.fuseau().id
        val t = Theatre()
        val c = t.contexte
        s.depart(t)
        val avant = etat(t)
        val importe = Store.importJson(c, s.fichier)
        // L'état d'abord : exportJson fige in_israel s'il ne l'est pas encore.
        val apres = etat(t)
        val texte = export(c)
        return linkedMapOf("nom" to s.nom, "fuseau" to fuseau, "avant" to avant, "fichier" to s.fichier, "importe" to importe,
            "apres" to apres, "export" to texte, "pausedDates" to Store.pausedDates(c).sorted(),
            "blockedApps" to Store.blockedApps(c).sorted(), "firstName" to Store.firstName(c))
    }

    // --- Les états de départ -----------------------------------------------------------------------

    private fun jours(t: Theatre, texte: String) {
        t.prefs(JOURNAL).valeurs["days"] = texte
    }

    /** Un état ordinaire : deux journées, une durée, une pause, une application. */
    private val ordinaire: (Theatre) -> Unit = { t ->
        val c = t.contexte
        jours(t, """{"2025-04-01":{"minutes":20,"note":"ici","themes":["gratitude"]},"2025-04-02":{"minutes":0,"note":"seule","note_seule":true}}""")
        Store.setTargetMinutes(c, 25)
        Store.setInIsrael(c, true)
        Store.togglePausedDate(c, "2025-04-03")
        Store.setBlockedApps(c, setOf("com.whatsapp"))
        Store.setFirstName(c, "Moshe")
    }

    /** Tous les réglages posés par les setters de Store, autrement que leur défaut. */
    private val reglagesPoses: (Theatre) -> Unit = { t ->
        val c = t.contexte
        Store.setWindow(c, 1200, 300)
        Store.setSnoozeMinutes(c, 30)
        Store.setTargetMinutes(c, 40)
        Store.setDailyGoal(c, 50)
        Store.setShabbatMode(c, false)
        Store.setInIsrael(c, true)
        Store.setReminderEnabled(c, true)
        Store.setReminderTimes(c, listOf(900, 300))
        Store.setFirstName(c, "  \u05D9\u05B9\u05D0\u05B5\u05DC  ")
        Store.setHideCountdown(c, true)
        Store.setGuidedHitbodedut(c, true)
        Store.setMusicEnabled(c, false)
        Store.setMusicVolume(c, 35)
        Store.setMusicShuffle(c, true)
        Store.setMusicTrackId(c, "yanuka_nigoun_3")
        Store.setAdresse(c, Adresse.FEMME)
        Store.setModeApparence(c, Apparence.Mode.SOMBRE)
        Store.setFond(c, Apparence.Fond.ROSE)
        Store.setAccent(c, Apparence.Accent.AMBRE)
        Store.togglePausedDate(c, "2025-05-01")
        Store.togglePausedDate(c, "2024-12-25")
        Store.setBlockedApps(c, setOf("com.instagram.android", "com.whatsapp", "org.telegram.messenger"))
    }

    /** L'export d'un téléphone : on y pose [depart], et le fichier est ce qu'Android en écrit. */
    private fun exportDe(depart: (Theatre) -> Unit): String {
        val t = Theatre()
        depart(t)
        return Store.exportJson(t.contexte)
    }

    // --- Les fichiers ------------------------------------------------------------------------------

    private const val F = """"format":"myhitbodedut","version":1"""

    private val android = """{$F,"exported_at":"2025-09-28T10:00:00Z",""" +
        """"days":{"2025-09-28":{"minutes":45,"note":"","themes":["famille"]},"2025-09-20":{"minutes":60,"note":"là"}},""" +
        """"settings":{"window_start":360,"window_end":660,"snooze_minutes":15,"target_minutes":30,"daily_goal_minutes":0,""" +
        """"pause_shabbat":true,"in_israel":true,"reminder_enabled":true,"reminder_minutes":420,"reminder_times":[420,1260],""" +
        """"first_name":"Hillel","hide_countdown":true,"guided_hitbodedut":true,"music_enabled":false,"music_volume":40,""" +
        """"music_shuffle":true,"music_track":"hamelech_basade","adresse":"f","apparence_mode":"sombre","apparence_fond":"sable",""" +
        """"apparence_accent":"violet"},"paused_dates":["2025-09-30"],"blocked_apps":["com.exemple"]}"""

    private val hebreu = "\u05E8\u05B4\u05D1\u05BC\u05D5\u05B9\u05E0\u05D5\u05B9 \u05E9\u05B6\u05C1\u05DC \u05E2\u05D5\u05B9\u05DC\u05B8\u05DD"

    /** Un grand fichier : 80 journées dans le désordre, dont certaines déjà présentes ici. */
    private val grand: String = run {
        val days = StringBuilder()
        for (i in 0 until 80) {
            val jour = LocalDate.of(2023, 1, 1).plusDays(((i * 53) % 400).toLong())
            if (i > 0) days.append(',')
            days.append("\"$jour\":{\"minutes\":${(i * 17) % 130},\"note\":\"${if (i % 3 == 0) "" else "Jour $i — ${hebreu.take(i % 25)}"}\"")
            if (i % 4 == 1) days.append(",\"themes\":[\"${Theme.values()[i % 10].cle}\",\"${Theme.values()[(i + 3) % 10].cle}\"]")
            if (i % 7 == 2) days.append(",\"note_seule\":true")
            days.append('}')
        }
        """{$F,"days":{$days}}"""
    }

    private val departGrand: (Theatre) -> Unit = { t ->
        val o = StringBuilder()
        for (i in 0 until 20) {
            val jour = LocalDate.of(2023, 1, 1).plusDays((i * 20).toLong())
            if (i > 0) o.append(',')
            o.append("\"$jour\":{\"minutes\":${i * 7},\"note\":\"${if (i % 2 == 0) "déjà $i" else ""}\"")
            if (i % 3 == 0) o.append(",\"themes\":[\"${Theme.values()[i % 10].cle}\"]")
            if (i % 5 == 0) o.append(",\"note_seule\":true")
            o.append('}')
        }
        jours(t, "{$o}")
    }

    private fun scenarios(): List<Scenario> = listOf(
        // Les cas d'import des tests du site (web/test), sur des dates loin dans le passé.
        Scenario("site : une sauvegarde Android se relit", android) { t ->
            jours(t, """{"2025-09-28":{"minutes":30,"note":"ici","themes":["gratitude"]}}""")
        },
        Scenario("site : pas du json", "pas du json", ordinaire),
        Scenario("site : un autre format", """{"format":"autre"}""", ordinaire),
        Scenario("site : dates fausses ou à venir, valeurs bornées",
            """{$F,"days":{"2026-13-45":{"minutes":10},"x":{"minutes":10},"2999-01-01":{"minutes":10},""" +
                """"2025-09-20":{"minutes":-5,"note":"${"a".repeat(5000)}"}},""" +
                """"settings":{"target_minutes":0,"music_volume":500,"snooze_minutes":15},"paused_dates":["2026-02-30","2025-09-21"]}"""),
        Scenario("site : le fond contraste, une année lointaine",
            """{$F,"days":{"0202-01-01":{"minutes":5}},"settings":{"apparence_fond":"contraste"}}"""),
        Scenario("site : une note seule fait l'aller-retour", exportDe { t -> Store.setNote(t.contexte, "2025-10-10", "une pensée") }),
        Scenario("site : la lecture aléatoire passe par la sauvegarde", exportDe { t -> Store.setMusicShuffle(t.contexte, true) }),
        Scenario("site : une lecture aléatoire qui n'est pas un booléen ne change rien",
            """{"format":"myhitbodedut","days":{},"settings":{"music_shuffle":"oui"}}""") { t -> Store.setMusicShuffle(t.contexte, true) },
        Scenario("site : le guide passe par la sauvegarde", exportDe { t -> Store.setGuidedHitbodedut(t.contexte, true) }),
        Scenario("site : le guide éteint par la sauvegarde", """{$F,"days":{},"settings":{"guided_hitbodedut":false}}""") { t ->
            Store.setGuidedHitbodedut(t.contexte, true)
        },
        Scenario("site : sans la clé, le guide reste", """{$F,"days":{},"settings":{"target_minutes":20}}""") { t ->
            Store.setGuidedHitbodedut(t.contexte, true)
        },
        Scenario("site : un fichier sans journal_plus s'importe comme avant", """{$F,"days":{}}"""),
        Scenario("site : un fichier du site, sans réglages de la barrière",
            """{$F,"exported_at":"2025-11-02T10:00:00.000Z","days":{"2025-11-01":{"minutes":15,"note":"web"}},"settings":{""" +
                """"target_minutes":20,"daily_goal_minutes":0,"pause_shabbat":true,"in_israel":false,"guided_hitbodedut":false,""" +
                """"first_name":"","hide_countdown":false,"music_enabled":true,"music_volume":60,"music_shuffle":false,"music_track":"",""" +
                """"adresse":"","apparence_mode":"auto","apparence_fond":"vert","apparence_accent":"vert"},"paused_dates":[],"blocked_apps":["com.whatsapp"]}""",
            reglagesPoses),

        // Les fichiers refusés : rien ne change.
        Scenario("refus : texte vide", "", ordinaire),
        Scenario("refus : un tableau", "[]", ordinaire),
        Scenario("refus : null", "null", ordinaire),
        Scenario("refus : une chaîne", "\"myhitbodedut\"", ordinaire),
        Scenario("refus : sans format", """{"version":1,"days":{"2025-01-01":{"minutes":5}}}""", ordinaire),
        Scenario("refus : format en capitales", """{"format":"MyHitbodedut","days":{"2025-01-01":{"minutes":5}}}""", ordinaire),
        Scenario("refus : format précédé d'un blanc", """{"format":" myhitbodedut"}""", ordinaire),
        Scenario("refus : format null", """{"format":null}""", ordinaire),
        Scenario("refus : format nombre", """{"format":1}""", ordinaire),
        Scenario("refus : objet inachevé", """{"format":"myhitbodedut","days":{"2025-01-01":{"minutes":5}}""", ordinaire),
        Scenario("refus : virgule finale", """{"format":"myhitbodedut",}""", ordinaire),

        // Les fichiers acceptés à la marge.
        Scenario("format seul", """{"format":"myhitbodedut"}""", ordinaire),
        Scenario("suivi de texte", """{"format":"myhitbodedut","days":{"2025-01-01":{"minutes":5}}} poubelle""", ordinaire),
        Scenario("marque d'ordre des octets", "\uFEFF{\"format\":\"myhitbodedut\",\"days\":{\"2025-01-02\":{\"minutes\":6}}}", ordinaire),
        Scenario("blancs autour", " \n\t{ \"format\" : \"myhitbodedut\" , \"days\" : { \"2025-01-03\" : { \"minutes\" : 7 } } } \n", ordinaire),
        Scenario("format répété, le dernier compte", """{"format":"autre","format":"myhitbodedut","days":{"2025-01-04":{"minutes":8}}}"""),
        Scenario("fichier Android vide", """{$F,"exported_at":"2026-09-28T10:00:00Z","days":{},"settings":{},"paused_dates":[],"blocked_apps":[]}"""),
        Scenario("la veille et aujourd'hui acceptés, demain non",
            """{$F,"days":{"2026-01-02":{"minutes":3},"2026-01-01":{"minutes":2},"2025-12-31":{"minutes":1}}}"""),

        // Les journées.
        Scenario("clés de date mal formées",
            """{$F,"days":{"2025-1-01":{"minutes":1},"2025-02-29":{"minutes":2},"2024-02-29":{"minutes":3}," 2025-10-02":{"minutes":4},""" +
                """"2025-10-03 ":{"minutes":5},"+2025-10-04":{"minutes":6},"20251005":{"minutes":7},"2025-10-06T00:00":{"minutes":8},""" +
                """"":{"minutes":9},"\uFF12\uFF10\uFF12\uFF15-10-07":{"minutes":10},"2025-10-00":{"minutes":11},"2025-04-31":{"minutes":12},""" +
                """"0000-02-29":{"minutes":13},"0001-01-01":{"minutes":14},"-0001-01-01":{"minutes":15},"+10000-01-01":{"minutes":16},""" +
                """"9999-12-31":{"minutes":17},"2999-12-31":{"minutes":18},"1999-12-31":{"minutes":19},"2025-12-31":{"minutes":20},"x":{"minutes":21}}}"""),
        Scenario("journées qui ne sont pas des objets",
            """{$F,"days":{"2025-08-01":5,"2025-08-02":"x","2025-08-03":null,"2025-08-04":[],"2025-08-05":{},"2025-08-06":true,"2025-08-07":{"minutes":7}}}"""),
        Scenario("days n'est pas un objet", """{$F,"days":[{"2025-08-01":{"minutes":5}}]}""", ordinaire),
        Scenario("days est une chaîne", """{$F,"days":"{\"2025-08-01\":{\"minutes\":5}}"}""", ordinaire),
        Scenario("minutes hors bornes et nombres en chaînes",
            """{$F,"days":{"2025-03-01":{"minutes":-5},"2025-03-02":{"minutes":0},"2025-03-03":{"minutes":1440},"2025-03-04":{"minutes":1441},""" +
                """"2025-03-05":{"minutes":99999},"2025-03-06":{"minutes":3000000000},"2025-03-07":{"minutes":1e10},"2025-03-08":{"minutes":-1e10},""" +
                """"2025-03-09":{"minutes":"20"},"2025-03-10":{"minutes":"  12  "},"2025-03-11":{"minutes":"1e3"},"2025-03-12":{"minutes":20.7},""" +
                """"2025-03-13":{"minutes":-0.5},"2025-03-14":{"minutes":"abc"},"2025-03-15":{"minutes":true},"2025-03-16":{"minutes":null},""" +
                """"2025-03-17":{"minutes":[1]},"2025-03-18":{"minutes":{}},"2025-03-19":{"minutes":"0x10"},"2025-03-20":{"minutes":"2147483648"},""" +
                """"2025-03-21":{"minutes":-2147483649},"2025-03-22":{"minutes":12345678901234567890},"2025-03-23":{"minutes":"-0"},""" +
                """"2025-03-24":{"minutes":1439.999},"2025-03-25":{"minutes":"1440.9"},"2025-03-26":{"note":"sans minutes"}}}"""),
        Scenario("notes de toutes sortes",
            """{$F,"days":{"2025-02-01":{"minutes":1,"note":null},"2025-02-02":{"minutes":1,"note":5},"2025-02-03":{"minutes":1,"note":true},""" +
                """"2025-02-04":{"minutes":1,"note":{"a":1}},"2025-02-05":{"minutes":1,"note":[1,"b"]},"2025-02-06":{"minutes":1,"note":1.50},""" +
                """"2025-02-07":{"minutes":1,"note":1e2},"2025-02-08":{"minutes":1,"note":"\u00E9t\u00E9 \/ \"cit\u00E9\" \\ \u0001 \u2028 \t \uD83D\uDE00"},""" +
                """"2025-02-09":{"minutes":1,"note":"$hebreu"},"2025-02-10":{"minutes":1,"note":-0},"2025-02-11":{"minutes":1,"note":12345678901234567890},""" +
                """"2025-02-12":{"minutes":1,"note":"${"\\u05D0\\u05B8".repeat(300)}"},"2025-02-13":{"minutes":1,"note":"${"b".repeat(3999)}é"},""" +
                """"2025-02-14":{"minutes":1,"note":"   "},"2025-02-15":{"minutes":1}}}"""),
        Scenario("sujets de toutes sortes",
            """{$F,"days":{"2025-02-20":{"minutes":1,"themes":[]},"2025-02-21":{"minutes":1,"themes":["gratitude"]},"2025-02-22":{"minutes":1,"themes":["","  ","x"]},""" +
                """"2025-02-23":{"minutes":1,"themes":[null]},"2025-02-24":{"minutes":1,"themes":[1,true,{"a":1},2.5]},"2025-02-25":{"minutes":1,"themes":"gratitude"},""" +
                """"2025-02-26":{"minutes":1,"themes":[["a"]]},"2025-02-27":{"minutes":1,"themes":["famille","famille"," famille"]},""" +
                """"2025-02-28":{"minutes":1,"themes":["\u00E9","e\u0301","\u00A0","\u200B"]},"2025-03-01":{"minutes":1,"themes":{"0":"x"}}}}"""),
        Scenario("note seule de toutes sortes",
            """{$F,"days":{"2025-01-10":{"note_seule":true},"2025-01-11":{"note_seule":false},"2025-01-12":{"note_seule":"true"},"2025-01-13":{"note_seule":"TRUE"},""" +
                """"2025-01-14":{"note_seule":"yes"},"2025-01-15":{"note_seule":1},"2025-01-16":{"note_seule":null},"2025-01-17":{"note_seule":"False"}}}"""),
        Scenario("une date répétée dans le fichier", """{$F,"days":{"2025-08-10":{"minutes":1},"2025-08-11":{"minutes":2},"2025-08-10":{"minutes":3}}}"""),
        Scenario("fusion d'un jour déjà présent",
            """{$F,"days":{"2025-06-06":{"minutes":7,"note":"nouveau"},"2025-06-01":{"minutes":45,"note":"","themes":["famille","gratitude"]},""" +
                """"2025-06-02":{"minutes":0,"note":"là","note_seule":true},"2025-06-03":{"minutes":5,"note":"fichier","themes":["famille","famille","zivoug"]},""" +
                """"2025-06-04":{"minutes":3,"note":"","note_seule":true},"2025-06-05":{"minutes":15,"note":"y","themes":["a"]},""" +
                """"2025-05-31":{"minutes":2,"note":"avant"},"2025-06-07":{"minutes":1,"note":"","themes":["é"]}}}""") { t ->
            jours(t, """{"2025-06-01":{"minutes":20,"note":"ici","themes":["gratitude"]},"2025-06-02":{"minutes":0,"note":"seule ici","note_seule":true},""" +
                """"2025-06-03":{"minutes":10,"note":" \t ","themes":["famille"]},"2025-06-04":{"minutes":5,"note":""},""" +
                """"2025-06-05":{"minutes":0,"note":"x","note_seule":true},"2025-06-07":{"minutes":30,"note":"","themes":["e\u0301"]}}""")
        },
        Scenario("fusion : la séance la plus longue reste", """{$F,"days":{"2025-04-01":{"minutes":5,"note":"autre","themes":["gratitude","emotions"]}}}""", ordinaire),
        Scenario("le journal d'ici est illisible", """{$F,"days":{"2025-07-01":{"minutes":9,"note":"repris"}}}""") { t -> jours(t, "{pas du json") },
        Scenario("le journal d'ici a une clé fausse", """{$F,"days":{"2025-07-03":{"minutes":3}}}""") { t ->
            jours(t, """{"2025-13-01":{"minutes":1},"2025-07-02":{"minutes":2},"2025-07-04":"x"}""")
        },
        Scenario("un grand fichier", grand, departGrand),

        // Les réglages.
        Scenario("settings n'est pas un objet", """{$F,"settings":"x"}""", reglagesPoses),
        Scenario("settings est un tableau", """{$F,"settings":[{"target_minutes":20}]}""", reglagesPoses),
        Scenario("settings vide sur un téléphone neuf", """{$F,"settings":{}}"""),
        Scenario("settings vide sur des réglages posés", """{$F,"settings":{}}""", reglagesPoses),
        Scenario("réglages hors bornes, par en dessous",
            """{$F,"settings":{"window_start":-1,"window_end":1440,"snooze_minutes":0,"target_minutes":0,"daily_goal_minutes":-5,"music_volume":-3,""" +
                """"reminder_minutes":-1}}""", reglagesPoses),
        Scenario("réglages hors bornes, par au-dessus",
            """{$F,"settings":{"window_start":0,"window_end":1439,"snooze_minutes":241,"target_minutes":300,"daily_goal_minutes":241,"music_volume":101,""" +
                """"reminder_minutes":1440}}"""),
        Scenario("réglages en chaînes et en décimaux",
            """{$F,"settings":{"window_start":"600","window_end":20.7,"snooze_minutes":"  9 ","target_minutes":"20","daily_goal_minutes":"15",""" +
                """"music_volume":"45.9","reminder_minutes":"480"}}""", reglagesPoses),
        Scenario("réglages illisibles : on garde ceux d'ici",
            """{$F,"settings":{"window_start":"abc","window_end":null,"snooze_minutes":true,"target_minutes":[],"daily_goal_minutes":null,""" +
                """"music_volume":{},"pause_shabbat":"oui","in_israel":2,"reminder_enabled":null,"music_enabled":"vrai","music_shuffle":0}}""", reglagesPoses),
        Scenario("réglages extrêmes",
            """{$F,"settings":{"window_start":3000000000,"window_end":1e10,"snooze_minutes":-1e10,"target_minutes":12345678901234567890,""" +
                """"daily_goal_minutes":"2147483648","music_volume":-2147483649}}"""),
        Scenario("booléens en chaînes",
            """{$F,"settings":{"pause_shabbat":"false","in_israel":"TRUE","reminder_enabled":"True","hide_countdown":"oui","guided_hitbodedut":"true",""" +
                """"music_enabled":"FALSE","music_shuffle":"true"}}"""),
        Scenario("cacher le décompte : la clé seule suffit à l'éteindre", """{$F,"settings":{"hide_countdown":null,"guided_hitbodedut":5}}""", reglagesPoses),
        Scenario("in_israel absent des deux côtés", """{$F,"settings":{"target_minutes":20}}"""),
        Scenario("in_israel absent du fichier, posé ici", """{$F,"settings":{"target_minutes":20}}""") { t -> Store.setInIsrael(t.contexte, true) },
        Scenario("sans settings, in_israel reste à figer", """{$F,"days":{"2025-01-05":{"minutes":5}}}"""),
        Scenario("Jérusalem : in_israel absent des deux côtés", """{$F,"settings":{"target_minutes":20}}""").dans(jerusalem),
        Scenario("Jérusalem : in_israel déjà posé à faux", """{$F,"settings":{"target_minutes":20}}""") { t ->
            Store.setInIsrael(t.contexte, false)
        }.dans(jerusalem),
        Scenario("Jérusalem : sans settings, in_israel reste à figer", """{$F,"days":{"2025-01-05":{"minutes":5}}}""").dans(jerusalem),
        Scenario("rappels : reminder_minutes sans reminder_times", """{$F,"settings":{"reminder_minutes":480}}""") { t ->
            Store.setReminderTimes(t.contexte, listOf(300, 900))
        },
        Scenario("rappels : liste vide, reminder_minutes ignoré", """{$F,"settings":{"reminder_times":[],"reminder_minutes":480}}""") { t ->
            Store.setReminderTimes(t.contexte, listOf(300, 900))
        },
        Scenario("rappels : liste à trier, doublons, hors bornes",
            """{$F,"settings":{"reminder_times":[1260,420,420,1440,-1,"600",null,3.7,"x",true],"reminder_minutes":100}}""") { t ->
            Store.setReminderTimes(t.contexte, listOf(300, 900))
        },
        Scenario("rappels : liste sans heure valable", """{$F,"settings":{"reminder_times":[1440,-5,"x"],"reminder_minutes":480}}""") { t ->
            Store.setReminderTimes(t.contexte, listOf(300, 900))
        },
        Scenario("rappels : liste écrite en chaîne", """{$F,"settings":{"reminder_times":"420,1260","reminder_minutes":1500}}""") { t ->
            Store.setReminderTimes(t.contexte, listOf(300, 900))
        },
        Scenario("rappels : liste null, reminder_minutes en chaîne", """{$F,"settings":{"reminder_times":null,"reminder_minutes":"480"}}"""),
        Scenario("rappels : sur un téléphone neuf, une liste", """{$F,"settings":{"reminder_times":[1260,420]}}"""),
        Scenario("prénom rogné", """{$F,"settings":{"first_name":"  Hillel  "}}""", ordinaire),
        Scenario("prénom long", """{$F,"settings":{"first_name":"${"a".repeat(50)}"}}""", ordinaire),
        Scenario("prénom null", """{$F,"settings":{"first_name":null}}""", ordinaire),
        Scenario("prénom nombre", """{$F,"settings":{"first_name":5}}""", ordinaire),
        Scenario("prénom vide", """{$F,"settings":{"first_name":""}}""", ordinaire),
        Scenario("prénom absent", """{$F,"settings":{"target_minutes":25}}""", ordinaire),
        Scenario("pr\u00E9nom h\u00E9breu vocalis\u00E9", """{$F,"settings":{"first_name":"\u05DE\u05B9\u05E9\u05B6\u05C1\u05D4 \u05D1\u05BC\u05B6\u05DF \u05D9\u05B4\u05E9\u05B0\u05C1\u05E8\u05B8\u05D0\u05B5\u05DC \u05D4\u05B7\u05DB\u05BC\u05B9\u05D4\u05B5\u05DF \u05DE\u05B4\u05D9\u05B0\u05BC\u05E8\u05D5\u05BC\u05E9\u05B8\u05C1\u05DC\u05B7\u05D9\u05B4\u05DD"}}"""),
        Scenario("adresse et apparence connues",
            """{$F,"settings":{"adresse":"m","apparence_mode":"clair","apparence_fond":"bleu","apparence_accent":"turquoise"}}""", reglagesPoses),
        Scenario("adresse inconnue, apparence vide",
            """{$F,"settings":{"adresse":"x","apparence_mode":"","apparence_fond":"   ","apparence_accent":""}}""", reglagesPoses),
        Scenario("adresse en capitale", """{$F,"settings":{"adresse":"F"}}""", reglagesPoses),
        Scenario("adresse vide", """{$F,"settings":{"adresse":""}}""", reglagesPoses),
        Scenario("adresse null", """{$F,"settings":{"adresse":null}}""", reglagesPoses),
        Scenario("adresse sur un téléphone neuf", """{$F,"settings":{"adresse":"f","apparence_mode":"sombre","apparence_fond":"contraste","apparence_accent":"bordeaux"}}"""),
        Scenario("morceau livré", """{$F,"settings":{"music_track":"shpayer_beyond"}}""", reglagesPoses),
        Scenario("morceau blanc", """{$F,"settings":{"music_track":"   "}}""", reglagesPoses),
        Scenario("morceau vide", """{$F,"settings":{"music_track":""}}""", reglagesPoses),

        // Les jours de pause et les applications.
        Scenario("pauses et applications réunies",
            """{$F,"paused_dates":["2025-05-02","2025-02-30",null,5,"2025-05-01","2025-05-02"," 2025-05-03"],""" +
                """"blocked_apps":["com.b","","  ",null,"com.instagram.android","com.b",5]}""") { t ->
            reglagesPoses(t)
            Store.togglePausedDate(t.contexte, "pas une date")
            Store.setBlockedApps(t.contexte, Store.blockedApps(t.contexte) + setOf("", " "))
        },
        Scenario("pauses et applications vides", """{$F,"paused_dates":[],"blocked_apps":[]}""") { t ->
            reglagesPoses(t)
            Store.togglePausedDate(t.contexte, "pas une date")
            Store.setBlockedApps(t.contexte, Store.blockedApps(t.contexte) + setOf(""))
        },
        Scenario("pauses et applications qui ne sont pas des tableaux", """{$F,"paused_dates":"2025-05-02","blocked_apps":{"a":"com.b"}}""") { t ->
            reglagesPoses(t)
            Store.togglePausedDate(t.contexte, "pas une date")
        },
        Scenario("pauses et applications sur un téléphone neuf", """{$F,"paused_dates":["2025-05-02"],"blocked_apps":["com.b"]}"""),

        // Les allers-retours : le fichier est ce qu'Android écrit.
        Scenario("aller-retour vers un téléphone neuf", exportDe { t ->
            reglagesPoses(t)
            jours(t, """{"2025-03-02":{"minutes":15,"note":"deux","themes":["famille","parnassa"]},"2025-03-01":{"minutes":0,"note":"seule","note_seule":true}}""")
            JournalPlus.ecrire(t.contexte, "2025-03-01", JournalPlus.Plus(2, 4, "merci", "la patience"))
        }),
        Scenario("aller-retour vers un téléphone déjà rempli", exportDe { t ->
            ordinaire(t)
            Store.setNote(t.contexte, "2025-04-05", "note")
        }, reglagesPoses),
        Scenario("aller-retour d'un téléphone neuf", exportDe { }, reglagesPoses),
        Scenario("deux imports de suite", """{$F,"days":{"2025-04-01":{"minutes":50,"note":"fichier","themes":["autre"]}},"settings":{"target_minutes":12}}""") { t ->
            Store.importJson(t.contexte, android)
            Store.importJson(t.contexte, """{$F,"days":{"2025-04-01":{"minutes":10,"note":""}},"settings":{"music_track":"hamelech_basade"}}""")
        },
    )

    override fun produire(): Map<String, Any?> {
        Horloge.regler(LocalDateTime.of(2026, 1, 1, 12, 0), ZoneOffset.UTC)
        return linkedMapOf(
            "_meta" to linkedMapOf("source" to "tools/vecteurs_ios/VecteursSauvegarde.kt", "aujourdhui" to Horloge.aujourdhui(ZoneOffset.UTC).toString(),
                "fuseau" to Horloge.fuseau().id, "morceauxLivres" to morceauxLivres),
            "scenarios" to scenarios().map(::rejoue),
        )
    }
}
