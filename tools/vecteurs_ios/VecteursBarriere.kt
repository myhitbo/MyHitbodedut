// La carte d'état de la barrière (GateStatus.kt) : le titre et la couleur de chaque état (noms de
// ressources), puis le détail tel que l'écran l'écrit, dans les trois langues, pour 0, 1, 2, 3 et 51
// applications et quelques fenêtres (de jour, de nuit, bornes de formatMinutes).
//
// `evaluate` n'a pas d'oracle ici : Permissions.allGranted lit Android (canDrawOverlays rend faux sur la
// JVM). Ses sous-règles (fenetreFaite, isExempt, isSnoozed, inWindow) ont leurs vecteurs dans store.json.

import com.myhitbodedut.GateState
import com.myhitbodedut.GateStatus
import com.myhitbodedut.Store

object VecteursBarriere : Generateur {
    override val fichier = "barriere.json"

    private val langues = listOf("fr", "en", "he")
    private val nombres = listOf(0, 1, 2, 3, 51)
    private val fenetres = listOf(6 * 60 to 11 * 60, 21 * 60 to 2 * 60, 0 to 1439, 600 to 600, 23 * 60 + 59 to 5)

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursBarriere.kt"),
        // Les huit états d'Android, dans l'ordre de l'énumération.
        "etats" to GateState.values().map { etat ->
            linkedMapOf(
                "etat" to etat.name,
                "titre" to Identifiants.entree(GateStatus.titleOf(etat)),
                "couleur" to Identifiants.entree(GateStatus.colorOf(etat)),
            )
        },
        // Le détail résolu sur un Theatre : une ligne par langue, fenêtre et nombre d'applications, un texte
        // par état dans l'ordre de l'énumération.
        "details" to langues.flatMap { langue ->
            fenetres.flatMap { (debut, fin) ->
                nombres.map { combien ->
                    val theatre = Theatre(langue)
                    val contexte = theatre.contexte
                    Store.setBlockedApps(contexte, (1..combien).map { "app.numero$it" }.toSet())
                    Store.setWindow(contexte, debut, fin)
                    linkedMapOf(
                        "langue" to langue,
                        "debut" to debut,
                        "fin" to fin,
                        "applications" to combien,
                        "textes" to GateState.values().map { GateStatus.detailOf(contexte, it) },
                    )
                }
            }
        },
    )
}
