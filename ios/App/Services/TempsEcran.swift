import Barriere
import Coeur
import Ecrans
import Foundation
import Observation
import UIKit
import UserNotifications
#if !SANS_BARRIERE
import DeviceActivity
import FamilyControls
import ManagedSettings
#endif

// La barrière « Je suis avec Hachem » côté app (PORTAGE.md § 2.1) : l'adaptateur des services d'Ecrans pour Temps
// d'écran (`TempsEcran`, `ReglagesBarriereSysteme`, `BarriereSysteme`). Il tient le rôle de GateService et de
// Permissions.kt : à chaque ouverture, chaque retour au premier plan et chaque changement du journal ou des réglages
// (une séance commencée, la journée validée, un réglage), il verse la boîte des extensions au journal, réécrit
// l'instantané (barriere/etat.json), met les deux magasins d'accord avec la règle et refait les rendez-vous de la
// surveillance. Les extensions font de même à leurs rendez-vous, l'app fermée. Dans la construction SANS_BARRIERE,
// le même type ne fait rien et le dit.

#if !SANS_BARRIERE

@MainActor
final class TempsEcranApp: TempsEcran, ReglagesBarriereSysteme, BarriereSysteme {

    /// Pourquoi l'app se synchronise : seul un retour (l'app rouverte, la carte rafraîchie) peut constater un bouclier
    /// désaccordé ; après un changement fait dans l'app, l'écart entre le magasin et la règle est attendu.
    enum Raison {
        case retour
        case changement
    }

    private let magasin: Magasin
    private let horloge: any Horloge
    private let traducteur: Traducteur
    private let paquet: URL
    private let fichiers: FichiersBarriere?
    /// La palette de l'apparence choisie, de jour, pour les couleurs du bouclier.
    private let palettes: Palettes?
    /// Ouvre la séance : « Commencer » a été touché sur le bouclier (onStartSession).
    var commencer: (@MainActor () -> Void)?

    /// Le magasin `barriere` tel qu'il était avant la dernière correction de l'app ; nil sans désaccord constaté.
    private var desaccord: Bool?
    private var synchronisation: Task<Void, Never>?
    private var differee: Task<Void, Never>?
    private var retour: (any NSObjectProtocol)?

    init(magasin: Magasin, horloge: any Horloge, traducteur: Traducteur, paquet: URL, palettes: Palettes?) {
        self.magasin = magasin
        self.horloge = horloge
        self.traducteur = traducteur
        self.paquet = paquet
        self.palettes = palettes
        fichiers = FichiersBarriere.duGroupe()
    }

    /// La palette de l'apparence choisie, de jour.
    var palette: Palette? {
        let reglages = magasin.reglages
        return palettes?.palette(fond: reglages.fond, accent: reglages.accent, nuit: false)
    }

    /// Commence à suivre le journal, les réglages et les retours au premier plan, et se synchronise une première fois.
    func demarrer() {
        observer()
        retour = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil,
                                                        queue: .main) { [weak self] _ in
            let moi = self
            Task { @MainActor in await moi?.synchroniser(.retour) }
        }
        // La première, une seconde après l'ouverture : la racine est alors à l'écran, et la séance que « Commencer » a
        // demandée s'ouvre dans sa pile.
        Task {
            try? await Task.sleep(for: .seconds(1))
            await synchroniser(.retour)
        }
    }

    /// Un changement du journal ou des réglages : une synchronisation, un instant plus tard (plusieurs changements de
    /// suite n'en font qu'une).
    private func observer() {
        withObservationTracking {
            _ = magasin.journal
            _ = magasin.reglages
        } onChange: { [weak self] in
            let moi = self
            Task { @MainActor in
                moi?.observer()
                moi?.differer()
            }
        }
    }

    private func differer() {
        differee?.cancel()
        differee = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await synchroniser(.changement)
        }
    }

    // MARK: L'état du système

    private var autorisee: Bool {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved, .approvedWithDataAccess: true
        case .notDetermined, .denied: false
        @unknown default: false
        }
    }

    private var selectionEnregistree: SelectionEnregistree? {
        fichiers?.lireSelection()
    }

    private static var appareil: String {
        UIDevice.current.identifierForVendor?.uuidString ?? ""
    }

    // MARK: TempsEcran

    func demanderAutorisation() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            // Refusée, ou la feuille fermée : l'état relu le dit.
        }
        await synchroniser(.changement)
        return autorisee
    }

    /// Lève tout (réinitialiser l'app, PORTAGE.md § 2.1.9) : les deux magasins vidés, plus aucun rendez-vous.
    func leverBoucliers() async {
        for nom in NomMagasin.allCases {
            TempsEcranCommun.lever(nom)
        }
        DeviceActivityCenter().stopMonitoring()
        if let fichiers {
            let quand = EtatBarriere.horodatage(millis: horloge.maintenant, fuseau: horloge.fuseau)
            try? fichiers.journaliser([Evenement(quand: quand, genre: .levee, detail: AgentBarriere.app.rawValue)])
        }
    }

    // MARK: ReglagesBarriereSysteme

    /// Ce que l'app constate, juste après s'être synchronisée (la surveillance réinscrite si elle manquait, le bouclier
    /// remis d'accord) : l'autorisation, la sélection faite sur cet iPhone, la surveillance inscrite, son dernier signe
    /// de vie, et le bouclier tel qu'il était s'il a fallu le corriger.
    func constat() async -> Constat {
        await synchroniser(.retour)
        let centre = DeviceActivityCenter()
        let journal = fichiers?.journal() ?? []
        return Constat(autorise: autorisee,
                       selectionValide: selectionEnregistree.map { $0.valable(sur: TempsEcranApp.appareil) },
                       surveillanceInscrite: centre.activities.contains(TempsEcranCommun.nom(.fenetre)),
                       dernierReveil: Boite.dernierSigneDeVie(journal),
                       magasinActif: desaccord)
    }

    func nombreDeJetons() async -> Int {
        selectionEnregistree?.nombreDeJetons ?? 0
    }

    /// « Relancer le mode » : la surveillance réinscrite de zéro.
    func relancer() async {
        DeviceActivityCenter().stopMonitoring([TempsEcranCommun.nom(.fenetre), TempsEcranCommun.nom(.minuit)])
        await synchroniser(.changement)
    }

    // MARK: BarriereSysteme

    func autorise() async -> Bool {
        autorisee
    }

    func selection() async -> SelectionResume {
        guard let s = selectionEnregistree else { return SelectionResume() }
        return SelectionResume(applications: s.applications, categories: s.categories, sites: s.sites)
    }

    /// L'essai réel : l'instantané porte l'essai, le magasin `essai` retient les applications choisies, et la
    /// surveillance le lève à sa fin (ou « Fermer l'aperçu »).
    func essayer() async -> Int64? {
        guard autorisee, fichiers != nil, (selectionEnregistree?.nombreDeJetons ?? 0) > 0 else { return nil }
        let debut = horloge.maintenant
        let essai = Etat.Essai(debut: debut, fin: debut + 2 * 60_000)
        await synchroniser(.changement, essai: essai)
        return TempsEcranCommun.estPose(.essai) ? essai.fin : nil
    }

    func journal() async -> [Evenement] {
        await synchroniser(.changement)
        return fichiers?.journal() ?? []
    }

    // MARK: La sélection

    /// La sélection à montrer dans le sélecteur d'Apple.
    func selectionActuelle() -> FamilyActivitySelection {
        guard let fichiers, let choisie = TempsEcranCommun.selection(fichiers) else {
            return FamilyActivitySelection(includeEntireCategory: true)
        }
        return choisie
    }

    /// Enregistre la sélection (onPause → Store.setBlockedApps), avec l'appareil où elle a été faite, puis se
    /// synchronise : les boucliers suivent tout de suite.
    @discardableResult
    func enregistrer(_ selection: FamilyActivitySelection) async -> SelectionResume {
        let resume = SelectionResume(applications: selection.applicationTokens.count,
                                     categories: selection.categoryTokens.count, sites: selection.webDomainTokens.count)
        guard let fichiers, let jetons = try? JSONEncoder().encode(selection) else { return resume }
        try? fichiers.ecrire(SelectionEnregistree(jetons: jetons, appareil: TempsEcranApp.appareil,
                                                  applications: resume.applications, categories: resume.categories,
                                                  sites: resume.sites))
        // Une sélection changée : le bouclier posé avec l'ancienne prend la nouvelle.
        if TempsEcranCommun.estPose(.barriere) {
            TempsEcranCommun.poser(.barriere, selection: selection)
        }
        await synchroniser(.changement)
        return resume
    }

    // MARK: La synchronisation

    /// Une synchronisation à la fois : la suivante attend la précédente.
    func synchroniser(_ raison: Raison, essai: Etat.Essai? = nil) async {
        let precedente = synchronisation
        let tache = Task { @MainActor in
            await precedente?.value
            await self.faire(raison, essai: essai)
        }
        synchronisation = tache
        await tache.value
    }

    private func faire(_ raison: Raison, essai demande: Etat.Essai?) async {
        guard let fichiers else { return }
        try? fichiers.preparer()
        let millis = horloge.maintenant
        let fuseau = horloge.fuseau
        let maintenant = EtatBarriere.horodatage(millis: millis, fuseau: fuseau)

        // 1. La boîte : ce que les extensions ont fait, l'app fermée.
        let boite = fichiers.lireBoite()
        let ancien = fichiers.lireEtat()
        let barriereAvant = TempsEcranCommun.estPose(.barriere)
        let desaccordConstate = raison == .retour && autorisee
            && Planification.desaccord(ancien: ancien, evenements: boite.evenements, maintenant: maintenant,
                                       barriereActif: barriereAvant)
        desaccord = desaccordConstate ? barriereAvant : nil
        var versement = EtatBarriere.Versement()
        if !boite.evenements.isEmpty {
            let evenements = boite.evenements
            // Les réglages d'abord (le report, l'instant de la séance), puis le journal : verser deux fois ne change rien.
            try? await magasin.modifierReglages { reglages in
                var journal = magasin.journal
                _ = EtatBarriere.verser(evenements, journal: &journal, reglages: &reglages, maintenant: millis, fuseau: fuseau)
            }
            try? await magasin.modifierJournal { journal in
                var reglages = magasin.reglages
                versement = EtatBarriere.verser(evenements, journal: &journal, reglages: &reglages, maintenant: millis,
                                                fuseau: fuseau)
            }
        }

        // 2. L'instantané, que les extensions liront.
        var essai = demande ?? ancien?.avec(boite.evenements).essai
        if let e = essai, e.fin <= millis { essai = nil }
        let selection = selectionEnregistree
        let traducteur = self.traducteur
        let etat = EtatBarriere.etat(journal: magasin.journal, reglages: magasin.reglages, millis: millis, fuseau: fuseau,
                                     nombreDeJetons: selection?.nombreDeJetons ?? 0, palette: palette, essai: essai,
                                     textes: { traducteur.texte($0) })
        _ = try? fichiers.ecrire(etat)
        copierImages(etat.bouclier.apparence, fichiers: fichiers)

        // 3. La boîte versée passe au journal de la barrière.
        var notes = boite.evenements
        try? fichiers.retirerLu(octets: boite.octets)

        // 4. Les magasins et les rendez-vous, si Temps d'écran est autorisé (sinon le système refuserait tout).
        if autorisee {
            let changes = TempsEcranCommun.appliquer(Planification.voulus(etat, maintenant: maintenant), fichiers: fichiers)
            notes += TempsEcranCommun.evenements(changes, agent: desaccordConstate ? .correction : .app, quand: maintenant)
            let plan = Planification.plan(etat, maintenant: maintenant)
            let resultat = TempsEcranCommun.planifier(plan)
            if resultat.demarrees.contains(.fenetre) {
                notes.append(Evenement(quand: maintenant, genre: .inscrite))
            }
        }
        try? fichiers.journaliser(notes)

        // 5. « Commencer » touché sur le bouclier : la séance (onStartSession), et la notification de repli retirée.
        if versement.commencer {
            let centre = UNUserNotificationCenter.current()
            centre.removePendingNotificationRequests(withIdentifiers: [PlanBouclier.notification])
            centre.removeDeliveredNotifications(withIdentifiers: [PlanBouclier.notification])
            commencer?()
        }
    }

    /// Les images du personnage que le bouclier montre, copiées du paquet de l'app à côté de l'instantané : le paquet de
    /// l'extension ne les a pas.
    private func copierImages(_ apparence: ApparenceBouclier, fichiers: FichiersBarriere) {
        for nom in [apparence.iconeAppel, apparence.iconeSeance, apparence.iconeJoie] where !nom.isEmpty {
            let cible = fichiers.image(nom)
            guard !FileManager.default.fileExists(atPath: cible.path) else { continue }
            try? FileManager.default.copyItem(at: paquet.appending(path: "Images").appending(path: nom), to: cible)
        }
    }
}

#else

/// La construction SANS_BARRIERE (§ 2.1.11) : ni Temps d'écran, ni extensions. Rien n'est demandé ni posé.
@MainActor
final class TempsEcranApp: TempsEcran, ReglagesBarriereSysteme, BarriereSysteme {
    var commencer: (@MainActor () -> Void)?
    var palette: Palette? { nil }

    init(magasin: Magasin, horloge: any Horloge, traducteur: Traducteur, paquet: URL, palettes: Palettes?) {}

    func demarrer() {}
    func demanderAutorisation() async -> Bool { false }
    func leverBoucliers() async {}
    func constat() async -> Constat { Constat(autorise: false) }
    func nombreDeJetons() async -> Int { 0 }
    func autorise() async -> Bool { false }
    func selection() async -> SelectionResume { SelectionResume() }
    func essayer() async -> Int64? { nil }
    func journal() async -> [Evenement] { [] }
}

#endif
