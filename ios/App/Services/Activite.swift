import ActivityKit
import Coeur
import Ecrans
import Foundation

// La Live Activity de la séance (tâche 17, PORTAGE.md § 2.2.1), l'adaptateur d'`ActiviteEnDirect` (Services.swift)
// sur ActivityKit : la notification permanente de SessionService.kt, sur l'écran verrouillé et dans l'île
// dynamique. `SeanceEnCours` la montre quand elle commence à suivre une séance (au début, ou reprise au lancement)
// et la retire quand la séance est close ou abandonnée ; son dessin est dans l'extension des widgets
// (SeanceActivite.swift), ses attributs dans Widgets/Commun.
//
// Refusée dans les Réglages d'iOS, elle ne se montre pas, et la séance court pareil.

struct ActiviteSysteme: ActiviteEnDirect {
    let traducteur: Traducteur

    func commencer(debut: Int64, fin: Int64) async throws {
        try await commencer(SeanceAffichee(debut: debut, fin: fin, compteur: .reste, ouverte: false))
    }

    func commencer(_ seance: SeanceAffichee) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let etat = SeanceAttributs.ContentState(
            debut: Date(timeIntervalSince1970: TimeInterval(seance.debut) / 1000),
            fin: Date(timeIntervalSince1970: TimeInterval(seance.fin) / 1000),
            decompte: seance.decompte,
            texteMasque: seance.texteMasque.map { traducteur.texte($0) })
        // Passée la fin prévue, iOS la montre comme dépassée : l'app la clôt à son retour (SeanceEnCours.actualiser).
        let contenu = ActivityContent(state: etat, staleDate: etat.fin)
        // Une séance reprise (réconciliation) garde la Live Activity déjà posée.
        let deja = Activity<SeanceAttributs>.activities
        if let premiere = deja.first {
            await premiere.update(contenu)
            for autre in deja.dropFirst() {
                await autre.end(nil, dismissalPolicy: .immediate)
            }
            return
        }
        let attributs = SeanceAttributs(titre: traducteur.texte(seance.titre), terminer: traducteur.texte(seance.terminer))
        _ = try Activity<SeanceAttributs>.request(attributes: attributs, content: contenu, pushType: nil)
    }

    func terminer() async {
        await SeanceAttributs.retirerTout()
    }
}
