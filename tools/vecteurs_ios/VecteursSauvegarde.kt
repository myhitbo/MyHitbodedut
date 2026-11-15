// La sauvegarde d'Android devant iOS (tâche 7, PORTAGE.md § 3.9) : des fichiers forgés importés par
// Store.importJson dans un téléphone neuf (Theatre), puis l'export de Store.exportJson. Les dates sont
// dans le passé lointain ou en 2099, pour que le jour où l'on lance l'oracle ne change rien ; l'instant
// d'export est retiré, et les ensembles (jours de pause, applications bloquées) sont triés : Android les
// garde dans un HashSet.

import com.myhitbodedut.Store
import org.json.JSONArray
import org.json.JSONObject

object VecteursSauvegarde : Generateur {
    override val fichier = "sauvegarde.json"

    private val longue = "n".repeat(5000)

    private val forge = """
        {"format":"myhitbodedut","version":1,"exported_at":"2020-01-01T00:00:00Z",
         "days":{
           "2020-03-01":{"minutes":20,"note":"Dehors.","themes":["gratitude","parnassa"]},
           "2020-03-02":{"minutes":0,"note":"Pas pu.","note_seule":true},
           "2020-03-03":{"minutes":"25","note":"En chaîne."},
           "2020-03-04":{"minutes":20.7},
           "2020-03-05":{"minutes":-5,"note":"$longue"},
           "2020-03-06":{"minutes":5000,"themes":["","inconnu","famille"]},
           "2020-03-07":{"minutes":15,"note_seule":"true"},
           "2026-9-5":{"minutes":10},
           "2020-02-30":{"minutes":10},
           "2099-01-01":{"minutes":10},
           "2020-03-08":"pas un objet"
         },
         "settings":{"window_start":"300","window_end":2000,"snooze_minutes":500,"target_minutes":0,
           "daily_goal_minutes":500,"pause_shabbat":"false","in_israel":true,"reminder_enabled":true,
           "reminder_minutes":1260,"first_name":"   Avraham Yitzhak Yaakov Moshe Aharon David Shlomo   ",
           "hide_countdown":true,"guided_hitbodedut":"true","music_enabled":false,"music_volume":150,
           "music_shuffle":true,"music_track":"yanuka_nigoun_3","adresse":"f","apparence_mode":"sombre",
           "apparence_fond":"sable","apparence_accent":"bordeaux"},
         "paused_dates":["2020-01-10","2020-1-11","2020-01-12"],
         "blocked_apps":["com.whatsapp","","com.instagram.android"]}
    """.trimIndent()

    private val premier = """
        {"format":"myhitbodedut","version":1,
         "days":{"2021-05-01":{"minutes":10,"note":"","themes":["famille"]},
                 "2021-05-02":{"minutes":30,"note":"Ici.","note_seule":true},
                 "2021-05-03":{"minutes":5,"note":"","note_seule":true}},
         "settings":{"reminder_times":[1260,420,420,-3,3000],"window_start":400,"window_end":700},
         "paused_dates":["2021-01-01"],"blocked_apps":["com.a"]}
    """.trimIndent()

    private val second = """
        {"format":"myhitbodedut","version":1,
         "days":{"2021-05-01":{"minutes":25,"note":"Là-bas.","themes":["gratitude","famille"]},
                 "2021-05-02":{"minutes":12,"note":"Autre.","note_seule":false},
                 "2021-05-03":{"minutes":7,"note":"Seule.","note_seule":true},
                 "2021-05-04":{"minutes":40}},
         "settings":{"music_track":"","apparence_mode":"","adresse":"x","first_name":"Sarah"},
         "paused_dates":["2021-01-02","pas une date"],"blocked_apps":["com.b","com.a"]}
    """.trimIndent()

    private val web = """
        {"format":"myhitbodedut","version":1,"exported_at":"2022-02-02T10:00:00.123Z",
         "days":{"2022-02-01":{"minutes":15,"note":"Du site."}},
         "settings":{"target_minutes":20,"daily_goal_minutes":0,"pause_shabbat":true,"in_israel":false,
           "music_enabled":true,"music_volume":40,"music_shuffle":false,"music_track":"hamelech_basade",
           "first_name":"","hide_countdown":false,"guided_hitbodedut":false,"adresse":"m",
           "apparence_mode":"clair","apparence_fond":"bleu","apparence_accent":"turquoise"},
         "paused_dates":[],"blocked_apps":[],
         "journal_plus":{"2022-02-01":{"avant":2,"apres":4,"gratitude":"La santé.","travail":"La patience."}}}
    """.trimIndent()

    private val refuses = listOf("", "pas du json", "[]", """{"format":"autre","days":{}}""", """{"days":{"2020-01-01":{"minutes":5}}}""")

    /** Un téléphone neuf, les fichiers importés à la suite : les comptes rendus et l'export. */
    private fun cas(nom: String, fichiers: List<String>): Map<String, Any?> {
        val c = Theatre().contexte
        val comptes = fichiers.map { Store.importJson(c, it) }
        val export = JSONObject(Store.exportJson(c))
        export.remove("exported_at")
        for (cle in listOf("paused_dates", "blocked_apps")) {
            val a = export.getJSONArray(cle)
            export.put(cle, JSONArray((0 until a.length()).map { a.getString(it) }.sorted()))
        }
        return linkedMapOf("nom" to nom, "fichiers" to fichiers, "comptes" to comptes, "export" to export.toString())
    }

    override fun produire(): Map<String, Any?> {
        val forgeExporte = cas("forge", listOf(forge))["export"] as String
        return linkedMapOf(
            "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursSauvegarde.kt"),
            "cas" to listOf(
                cas("neuf", emptyList()),
                cas("forge", listOf(forge)),
                cas("fusion", listOf(premier, second)),
                cas("web", listOf(web)),
                cas("refuses", refuses),
                // L'aller-retour : l'export d'Android, relu par un téléphone neuf, rend le même export.
                cas("aller-retour", listOf(forgeExporte)),
            ),
        )
    }
}
