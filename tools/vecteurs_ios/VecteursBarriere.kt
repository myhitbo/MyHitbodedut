// La carte d'état de la barrière (GateStatus.kt) : le titre et la couleur de chaque état (noms de
// ressources), puis le détail tel que l'écran l'écrit, dans les trois langues, pour 0, 1, 2, 3 et 51
// applications et quelques fenêtres (de jour, de nuit, bornes de formatMinutes).
//
// `evaluate` lit Android (Permissions.allGranted, le service) ; sa règle, GateRule (13/11, FPRODUIT-01), est
// ici : l'état et le geste de la pastille pour chaque combinaison de faits, la fenêtre (début compris, fin
// exclue, fenêtres de nuit), le service et la pastille de l'accueil. Les sous-règles des faits (fenetreFaite,
// isExempt, isSnoozed, inWindow) ont leurs vecteurs dans store.json.

import com.myhitbodedut.GateFaits
import com.myhitbodedut.GateRule
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
                "pastille" to Identifiants.entree(GateStatus.pastilleDe(etat)),
            )
        },
        // [active, accès, applications, service, séance, faite, exempte, reportée, dans la fenêtre, état, geste] :
        // chaque combinaison, pour 0 et 2 applications.
        "regle" to (0 until 512).map { bits ->
            fun b(i: Int) = (bits shr i) and 1 == 1
            val f = GateFaits(active = b(0), accesAccordes = b(1), applications = if (b(2)) 2 else 0, serviceVivant = b(3),
                seanceEnCours = b(4), faite = b(5), exempte = b(6), reportee = b(7), dansLaFenetre = b(8))
            listOf(f.active, f.accesAccordes, f.applications, f.serviceVivant, f.seanceEnCours, f.faite, f.exempte, f.reportee,
                f.dansLaFenetre, GateRule.etat(f).name, GateRule.geste(f).name)
        },
        // [minutes, début, fin, dans la fenêtre, fin d'une fenêtre de nuit].
        "fenetre" to listOf(0, 1, 119, 120, 121, 359, 360, 361, 659, 660, 1259, 1260, 1261, 1439).flatMap { m ->
            fenetres.map { (debut, fin) -> listOf(m, debut, fin, GateRule.dansLaFenetre(m, debut, fin), GateRule.finDeFenetreDeNuit(m, debut, fin)) }
        },
        // [avec la barrière, active, accès, le service doit tourner].
        "service" to (0 until 8).map { bits ->
            val (a, b, c) = Triple(bits and 1 == 1, bits and 2 == 2, bits and 4 == 4)
            listOf(a, b, c, GateRule.doitTourner(a, b, c))
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
