// La sauvegarde d'Android devant iOS (tâche 7, ios/PORTAGE.md § 3.9). Les fichiers d'or de
// ios/Paquets/Coeur/Tests/Vecteurs/sauvegarde/ sont importés par Store.importJson dans un téléphone
// neuf (Theatre), puis exportés par Store.exportJson ; une sauvegarde chiffrée passe d'abord par
// Coffre.dechiffrer. Les tests Swift rejouent chaque cas et doivent rendre les mêmes comptes, le même
// export et les mêmes historiques de réglage.
//
// Rien ne dépend du jour où l'on lance l'oracle : les journées des fichiers sont passées ou en 2099 ;
// l'instant d'export est retiré ; le jour de l'import, qui date les historiques (HistoriqueReglage),
// est écrit « AUJOURDHUI ». Ce qu'Android range dans un HashSet (jours de pause, applications
// bloquées) est trié, et les journées et le journal enrichi le sont par date : iOS les écrit ainsi.

import com.myhitbodedut.Coffre
import com.myhitbodedut.Store
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.time.LocalDate

object VecteursSauvegarde : Generateur {
    override val fichier = "sauvegarde.json"

    private val dossier: File get() = File(DEPOT, "ios/Paquets/Coeur/Tests/Vecteurs/sauvegarde")

    private fun lu(nom: String): String = File(dossier, nom).readText(Charsets.UTF_8)

    /** Ce qui n'est pas une sauvegarde : Store.importJson rend null, rien n'est écrit. */
    private val refuses = listOf(
        "", "   ", "pas du json", "[]", "\"myhitbodedut\"", """{"format":"autre","days":{}}""",
        """{"days":{"2020-01-01":{"minutes":5}}}""", """{"format":"MyHitbodedut"}""", """{"format":["myhitbodedut"]}""",
        """{"format":"myhitbodedut-chiffre","version":1}""", """{"format":"myhitbodedut","days":{""",
    )

    /** Les historiques datés par l'import : dans les préférences, hors de l'export. */
    private val historiques = listOf("pause_shabbat_histoire", "in_israel_histoire")

    /** L'export, rendu comparable d'un jour et d'une plateforme à l'autre. */
    fun normalise(export: String): JSONObject {
        val o = JSONObject(export)
        o.remove("exported_at")
        for (cle in listOf("days", "journal_plus")) {
            val objet = o.optJSONObject(cle) ?: continue
            val trie = JSONObject()
            objet.keys().asSequence().toList().sorted().forEach { trie.put(it, objet.get(it)) }
            o.put(cle, trie)
        }
        for (cle in listOf("paused_dates", "blocked_apps")) {
            val a = o.optJSONArray(cle) ?: continue
            o.put(cle, JSONArray((0 until a.length()).map { a.getString(it) }.sorted()))
        }
        return o
    }

    /** Un téléphone neuf, les fichiers importés à la suite. */
    fun importes(textes: List<String>): Pair<List<Int?>, Theatre> {
        val t = Theatre()
        return textes.map { Store.importJson(t.contexte, it) } to t
    }

    fun resultat(textes: List<String>): LinkedHashMap<String, Any?> {
        val (comptes, t) = importes(textes)
        val brut = Store.exportJson(t.contexte)
        val aujourdhui = LocalDate.now().toString()
        val prefs = t.prefs("myhitbodedut")
        return linkedMapOf(
            "comptes" to comptes,
            "export" to normalise(brut).toString(2),
            "historiques" to historiques.associateWith { (prefs.valeurs[it] as String?)?.replace(aujourdhui, "AUJOURDHUI") },
            "brut" to brut,
        )
    }

    private fun cas(nom: String, fichiers: List<String>, textes: List<String> = fichiers.map(::lu), exact: Boolean = false): Map<String, Any?> {
        val r = resultat(textes)
        val brut = r.remove("brut") as String
        val sortie = linkedMapOf<String, Any?>("nom" to nom)
        if (fichiers.isNotEmpty()) sortie["fichiers"] = fichiers else sortie["textes"] = textes
        sortie.putAll(r)
        // L'export tel qu'Android l'écrit, sans sa ligne « exported_at » : iOS doit rendre les mêmes octets.
        if (exact) sortie["texte"] = brut.lines().filterNot { it.trimStart().startsWith("\"exported_at\"") }.joinToString("\n")
        return sortie
    }

    override fun produire(): Map<String, Any?> {
        // La sauvegarde chiffrée par le site (web/test/vecteur_coffre.json), relue par Coffre.dechiffrer.
        val vecteur = JSONObject(File(DEPOT, "web/test/vecteur_coffre.json").readText(Charsets.UTF_8))
        val chiffre = vecteur.getJSONObject("chiffre").toString()
        val clair = Coffre.dechiffrer(chiffre, vecteur.getString("mot_de_passe"))
        check(clair == vecteur.getString("clair")) { "Coffre ne relit pas web/test/vecteur_coffre.json" }
        check(Coffre.dechiffrer(chiffre, vecteur.getString("mot_de_passe") + " ") == null) { "Coffre accepte un mot de passe faux" }

        // L'instant d'export, seul à changer d'une passe à l'autre, est fixé : la JVM l'écrit à la nanoseconde.
        fun exporte(nom: String) = Store.exportJson(importes(listOf(lu(nom))).second.contexte)
            .replace(Regex("\"exported_at\": \"[^\"]*\""), "\"exported_at\": \"2000-01-01T00:00:00Z\"")
        val exportV1 = exporte("android-v1-forge.json")
        val exportV2 = exporte("android-v2-forge.json")
        return linkedMapOf(
            "_meta" to mapOf("source" to "tools/vecteurs_ios/generateurs/VecteursSauvegarde.kt"),
            "cas" to listOf(
                cas("neuf", emptyList(), emptyList()),
                cas("android-v1-forge", listOf("android-v1-forge.json")),
                cas("android-v2-forge", listOf("android-v2-forge.json"), exact = true),
                cas("fusion", listOf("fusion-1.json", "fusion-2.json")),
                cas("web-v2", listOf("web-v2.json")),
                cas("refuses", emptyList(), refuses),
                cas("chiffre", emptyList(), listOf(clair!!)),
                // L'aller-retour : l'export d'Android, relu par un téléphone neuf, rend le même export.
                cas("aller-retour-v1", emptyList(), listOf(exportV1)),
                cas("aller-retour-v2", emptyList(), listOf(exportV2)),
            ),
            "coffre" to linkedMapOf(
                "fichier" to "web/test/vecteur_coffre.json",
                "estChiffre" to listOf(chiffre, clair, "pas du json", "", """{"format":"myhitbodedut-chiffre"}""")
                    .map { listOf(it, Coffre.estChiffre(it)) },
            ),
        )
    }
}

/**
 * La sauvegarde réelle du propriétaire (P7), hors du dépôt : `gradle reelle -Pfichier=… -Psortie=…`.
 * Chiffrée, son mot de passe est lu dans SAUVEGARDE_REELLE_MDP (jamais sur la ligne de commande).
 * Écrit dans [args] [1] ce qu'Android en fait dans un téléphone neuf, que le test Swift compare.
 */
fun main(args: Array<String>) {
    val texte = File(args[0]).readText(Charsets.UTF_8)
    val clair = if (Coffre.estChiffre(texte)) {
        val mdp = System.getenv("SAUVEGARDE_REELLE_MDP") ?: error("sauvegarde chiffrée : SAUVEGARDE_REELLE_MDP absent")
        Coffre.dechiffrer(texte, mdp) ?: error("sauvegarde chiffrée : mot de passe faux ou fichier abîmé")
    } else texte
    val r = VecteursSauvegarde.resultat(listOf(clair))
    r.remove("brut")
    Ecrit.fichier(File(args[1]), r)
    println("${args[0]} → ${args[1]} : ${r["comptes"]} journées")
}
