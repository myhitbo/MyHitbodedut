import ActivityKit
import Coeur
import Ecrans
import Foundation
import Observation

/// La séance sur l'écran verrouillé et dans l'île dynamique (ActivityKit, PORTAGE.md § 2.2.1) : l'`ActiviteEnDirect`
/// de `SeanceEnCours`, à la place de la notification permanente de SessionService.kt.
///
/// - `commencer` montre la séance (`Activity.request`), ou met à jour celle qui est déjà montrée (une séance reprise
///   par `reconcilier` après que l'app a été tuée : sa Live Activity, elle, est restée) ;
/// - tant qu'elle est montrée, l'adaptateur suit les réglages du magasin : « Masquer le décompte » ou le filtre de
///   concentration qui change pendant la séance se voit aussitôt (`update`), et rien n'est renvoyé si l'état montré
///   ne change pas : le décompte tourne seul (`Text(timerInterval:)`), sans mise à jour à la seconde ;
/// - `terminer` retire toute Live Activity de la séance (`end`, sur-le-champ).
///
/// Ce qui est montré se décide dans Ecrans (`SeanceActivite`, testé sous Linux) ; ici, les textes sont traduits
/// dans la langue de l'app, que l'extension n'a pas (Widgets/ActiviteSeanceAttributs.swift).
///
/// iOS ne laisse commencer une Live Activity qu'avec l'app au premier plan (ce que sont `commencer` et le retour au
/// premier plan) et si l'utilisateur ne les a pas éteintes (Réglages → MyHitbodedut → Activités en direct) : sinon
/// `commencer` lève, et la séance court pareil (`SeanceEnCours.demarrer` l'attrape).
@MainActor
final class SystemeActiviteEnDirect: ActiviteEnDirect {

    private let magasin: Magasin
    private let traducteur: Traducteur
    /// Le début et la fin montrés (millisecondes Unix), nil quand rien n'est montré.
    private var bornes: (debut: Int64, fin: Int64)?
    /// Le dernier état envoyé à ActivityKit.
    private var montre: ActiviteSeanceAttributs.ContentState?
    /// Une observation des réglages est en place (`withObservationTracking` ne prévient qu'une fois).
    private var observe = false

    init(magasin: Magasin, traducteur: Traducteur) {
        self.magasin = magasin
        self.traducteur = traducteur
    }

    func commencer(debut: Int64, fin: Int64) async throws {
        bornes = (debut: debut, fin: fin)
        guard let etat = etatPresent() else {
            bornes = nil
            throw ActiviteSeanceKit.Impossible()
        }
        observer()
        do {
            try await ActiviteSeanceKit.montrer(etat)
        } catch {
            bornes = nil
            montre = nil
            throw error
        }
        // Pendant la demande, la séance a pu finir (`terminer` n'avait alors rien à retirer) ou ses réglages changer
        // (l'observation n'avait rien à mettre à jour) : ce qui est montré se remet d'accord avec la séance.
        guard bornes != nil else {
            await ActiviteSeanceKit.toutRetirer()
            return
        }
        montre = etat
        if let present = etatPresent(), present != etat {
            montre = present
            await ActiviteSeanceKit.actualiser(present)
        }
    }

    func terminer() async {
        bornes = nil
        montre = nil
        await ActiviteSeanceKit.toutRetirer()
    }

    // MARK: L'état

    /// L'état de la séance montrée, d'après les réglages présents ; nil sans séance ou sans rien de montré.
    private func etatPresent() -> ActiviteSeanceAttributs.ContentState? {
        guard let bornes,
              let regle = SeanceActivite.pour(reglages: magasin.reglages, debut: bornes.debut, fin: bornes.fin)
        else { return nil }
        return ActiviteSeanceAttributs.ContentState(regle, traducteur: traducteur)
    }

    /// Suit les réglages du magasin tant qu'une séance est montrée.
    private func observer() {
        guard !observe else { return }
        observe = true
        withObservationTracking {
            _ = self.magasin.reglages
        } onChange: {
            Task { @MainActor in await self.reglagesChanges() }
        }
    }

    /// Les réglages ont changé : l'état est renvoyé s'il a changé. Une séance close ne renvoie rien (`terminer`
    /// suit, et retire la Live Activity).
    private func reglagesChanges() async {
        observe = false
        guard bornes != nil else { return }
        observer()
        guard let etat = etatPresent(), etat != montre else { return }
        montre = etat
        await ActiviteSeanceKit.actualiser(etat)
    }
}

extension ActiviteSeanceAttributs.ContentState {

    /// L'état que la Live Activity reçoit : la règle d'Ecrans, ses textes traduits dans la langue de l'app.
    init(_ regle: SeanceActivite, traducteur: Traducteur) {
        let decompte: ActiviteSeanceAttributs.Decompte
        switch regle.decompte {
        case .reste: decompte = .reste
        case .ecoule: decompte = .ecoule
        case .masque: decompte = .masque
        }
        self.init(decompte: decompte,
                  concentration: regle.concentration,
                  debut: Date(timeIntervalSince1970: Double(regle.debut) / 1000),
                  fin: Date(timeIntervalSince1970: Double(regle.fin) / 1000),
                  titre: traducteur.texte(SeanceActivite.titre),
                  legende: traducteur.texte(regle.legende),
                  legendeConcentration: traducteur.texte(SeanceActivite.legendeConcentration),
                  terminer: traducteur.texte(SeanceActivite.terminer),
                  echue: traducteur.texte(SeanceActivite.echue),
                  droiteAGauche: traducteur.langue == "he")
    }
}

/// Les appels à ActivityKit, hors de l'acteur principal (`@concurrent`, que la concurrence « abordable » soit active
/// ou non) : `Activity` n'est pas `Sendable`, il ne quitte donc jamais la fonction qui le lit (`Activity.activities`),
/// et seul l'état, `Sendable`, y entre.
enum ActiviteSeanceKit {

    /// Les Live Activities sont éteintes pour l'app, ou il n'y a pas de séance à montrer.
    struct Impossible: Error, Sendable {}

    /// Montre l'état : met à jour la Live Activity de la séance si elle existe (une seule ; d'éventuelles autres,
    /// restées d'une vie d'avant, se retirent), sinon en demande une. Lève si iOS la refuse.
    @concurrent static func montrer(_ etat: ActiviteSeanceAttributs.ContentState) async throws {
        let contenu = ActivityContent(state: etat, staleDate: etat.fin)
        let vivantes = Activity<ActiviteSeanceAttributs>.activities.filter { activite in
            activite.activityState == .active || activite.activityState == .stale
        }
        if let premiere = vivantes.first {
            await premiere.update(contenu)
            for autre in vivantes.dropFirst() {
                await autre.end(nil, dismissalPolicy: .immediate)
            }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw Impossible() }
        _ = try Activity<ActiviteSeanceAttributs>.request(attributes: ActiviteSeanceAttributs(), content: contenu)
    }

    /// Met à jour la Live Activity montrée, sans en demander une (un changement de réglage, l'app au fond).
    @concurrent static func actualiser(_ etat: ActiviteSeanceAttributs.ContentState) async {
        let contenu = ActivityContent(state: etat, staleDate: etat.fin)
        for activite in Activity<ActiviteSeanceAttributs>.activities {
            await activite.update(contenu)
        }
    }

    /// Retire toute Live Activity de la séance, sur-le-champ.
    @concurrent static func toutRetirer() async {
        for activite in Activity<ActiviteSeanceAttributs>.activities {
            await activite.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Le filtre de concentration change (`ConcentrationRelais`) : la Live Activity montrée masque ou rend son
    /// décompte, sans relire les réglages ni les textes. Sert quand iOS lance l'app pour le seul filtre, sans que le
    /// magasin soit lu : l'adaptateur, qui suit le magasin, ne le verrait pas.
    @concurrent static func concentration(_ masquer: Bool) async {
        for activite in Activity<ActiviteSeanceAttributs>.activities {
            let present = activite.content
            guard present.state.concentration != masquer else { continue }
            var etat = present.state
            etat.concentration = masquer
            await activite.update(ActivityContent(state: etat, staleDate: present.staleDate))
        }
    }
}

/// Le chemin de « Terminer maintenant » (l'intention de la Live Activity, `ActiviteSeanceTerminer`) jusqu'à la séance
/// de l'app. Le système exécute l'intention dans le processus de l'app : si l'app est lancée, la séance partagée
/// (posée par `Lancement.charger`) se termine, avec la musique, le bravo et l'écran de séance ouvert. Si iOS a lancé
/// le processus pour la seule intention, aucune scène ne paraît et le magasin n'est pas lu : la séance se termine
/// alors sur les fichiers, qu'une séance neuve lit, et la Live Activity, que personne ne suit, se retire.
@MainActor
enum ActiviteSeanceRelais {

    /// La séance partagée de l'app (`PartageApp.seance`), posée une fois le magasin lu ; nil avant.
    static var seance: SeanceEnCours?

    static func terminer() async throws {
        if let seance {
            try await seance.terminer()
            return
        }
        let lu = try await Magasin.charger(ServicesApp.persistance())
        let seule = SeanceEnCours(magasin: lu, horloge: HorlogeSysteme())
        try await seule.terminer()
        await ActiviteSeanceKit.toutRetirer()
        // Le lancement a pu lire ses fichiers pendant ce temps, avant la clôture : sa séance se termine aussi (elle
        // s'inscrit sur son propre journal, qui n'avait pas encore celle-ci : une seule inscription au bout).
        if let vivante = seance {
            try await vivante.terminer()
        }
    }
}
