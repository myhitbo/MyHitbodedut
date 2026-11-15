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

    /** Les fichiers d'or (PORTAGE.md § 3.9), lus là où les tests Swift les lisent aussi. */
    private fun or(nom: String): String = java.io.File(DEPOT, "ios/Paquets/Coeur/Tests/Sauvegardes/$nom").readText()

    private val forge = or("android-v1-forge.json")
    private val web = or("web-v1.json")

    private val premier = """
        {"format":"myhitbodedut","version":1,
         "days":{"2021-05-01":{"minutes":10,"note":"","themes":["famille","famille","zivoug"]},
                 "2021-05-02":{"minutes":30,"note":"Ici.","note_seule":true},
                 "2021-05-03":{"minutes":5,"note":"","note_seule":true}},
         "settings":{"reminder_times":[1260,420,420,-3,3000],"window_start":400,"window_end":700},
         "paused_dates":["2021-01-01"],"blocked_apps":["com.a"]}
    """.trimIndent()

    private val second = """
        {"format":"myhitbodedut","version":1,
         "days":{"2021-05-01":{"minutes":25,"note":"Là-bas.","themes":["gratitude","famille","gratitude"]},
                 "2021-05-02":{"minutes":12,"note":"Autre.","note_seule":false},
                 "2021-05-03":{"minutes":7,"note":"Seule.","note_seule":true},
                 "2021-05-04":{"minutes":40}},
         "settings":{"music_track":"","apparence_mode":"","adresse":"x","first_name":"Sarah"},
         "paused_dates":["2021-01-02","pas une date"],"blocked_apps":["com.b","com.a"]}
    """.trimIndent()

    private val refuses = listOf("", "pas du json", "[]", """{"format":"autre","days":{}}""", """{"days":{"2020-01-01":{"minutes":5}}}""",
        """{"format":"MyHitbodedut"}""", """{"format":null}""", """{"format":"myhitbodedut","days":{"2020-01-01":{"minutes":5}}""")

    /** Le prénom coupé à 40 : « take(40) » laisse un blanc au bout, que firstName() retire à la lecture. */
    private val prenom = """{"format":"myhitbodedut","settings":{"first_name":"  Abcdefghijklmnopqrstuvwxyzabcdefghijklm nopq"}}"""

    /** Les heures de rappel : en chaînes, décimales, nulles, hors du jour ; puis une liste vide, qui ne change rien. */
    private val rappels = listOf(
        """{"format":"myhitbodedut","settings":{"reminder_times":["420","1260.5",2000,null,-1],"reminder_minutes":600}}""",
        """{"format":"myhitbodedut","settings":{"reminder_times":[],"reminder_minutes":600}}""",
        """{"format":"myhitbodedut","settings":{"reminder_minutes":"615"}}""",
    )

    /** Une marque d'ordre des octets en tête, et du texte après l'objet : Android les passe. */
    private val bords = listOf(
        "\uFEFF{\"format\":\"myhitbodedut\",\"days\":{\"2021-06-01\":{\"minutes\":5}}}",
        """{"format":"myhitbodedut","days":{"2021-06-02":{"minutes":6}}} et la suite""",
        """{"format":"myhitbodedut","days":{"2021-06-03":{"minutes":7}},"days":{"2021-06-04":{"minutes":8}}}""",
    )

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
                cas("prenom", listOf(prenom)),
                cas("rappels", rappels),
                cas("bords", bords),
                // L'aller-retour : l'export d'Android, relu par un téléphone neuf, rend le même export.
                cas("aller-retour", listOf(forgeExporte)),
            ),
        )
    }
}
