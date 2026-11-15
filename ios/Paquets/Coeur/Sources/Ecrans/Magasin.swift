import Foundation
import Observation
import Coeur

/// Ce qu'une persistance garde : le journal et les réglages (`journal.json` et `reglages.json` du groupe
/// d'apps, PORTAGE.md § 3.2 ; les deux fichiers de préférences d'Android, Store.kt).
public struct Enregistrement: Sendable, Equatable {
    public var journal: Journal
    public var reglages: Reglages

    public init(journal: Journal = Journal(), reglages: Reglages = Reglages()) {
        self.journal = journal
        self.reglages = reglages
    }
}

/// Où le `Magasin` lit et écrit. Dans l'app, les fichiers du groupe d'apps (l'acteur `Depot` de Coeur, par un
/// adaptateur qui viendra à son intégration) ; dans les tests et les aperçus, la mémoire. Une écriture ne rend
/// la main qu'une fois faite, ou en levant.
public protocol Persistance: Sendable {
    func lire() async throws -> Enregistrement
    func enregistrer(journal: Journal) async throws
    func enregistrer(reglages: Reglages) async throws
}

/// Une persistance en mémoire, pour les tests et les aperçus : elle garde ce qu'on lui écrit et compte les
/// écritures faites ; `faireEchouer` simule un disque qui refuse.
public actor PersistanceEnMemoire: Persistance {

    /// L'erreur d'une écriture ou d'une lecture refusée.
    public struct Echec: Error, Equatable, Sendable {
        public init() {}
    }

    public private(set) var enregistrement: Enregistrement
    /// Les écritures du journal réussies.
    public private(set) var ecrituresJournal = 0
    /// Les écritures des réglages réussies.
    public private(set) var ecrituresReglages = 0
    private var refuse = false

    public init(_ enregistrement: Enregistrement = Enregistrement()) {
        self.enregistrement = enregistrement
    }

    /// Vrai : toute lecture et toute écriture lèvent `Echec`, jusqu'à `faireEchouer(false)`.
    public func faireEchouer(_ oui: Bool) {
        refuse = oui
    }

    public func lire() throws -> Enregistrement {
        if refuse { throw Echec() }
        return enregistrement
    }

    public func enregistrer(journal: Journal) throws {
        if refuse { throw Echec() }
        enregistrement.journal = journal
        ecrituresJournal += 1
    }

    public func enregistrer(reglages: Reglages) throws {
        if refuse { throw Echec() }
        enregistrement.reglages = reglages
        ecrituresReglages += 1
    }
}

/// Le journal et les réglages de l'app, que les écrans lisent et changent (Store.kt d'Android). Un changement
/// se voit tout de suite, puis s'écrit par la `Persistance` injectée ; les écritures d'un même fichier se
/// suivent dans l'ordre des changements, si bien que le dernier écrit est toujours le dernier fait.
///
/// Une écriture qui échoue rend son erreur à qui a fait le changement ; le changement reste en mémoire, et la
/// prochaine écriture du même fichier l'emportera. Un changement qui ne change rien n'écrit rien.
@MainActor
@Observable
public final class Magasin {

    /// Les journées, leurs notes et le prénom.
    public private(set) var journal: Journal
    /// Les réglages, sous les noms de clés d'Android.
    public private(set) var reglages: Reglages

    private let persistance: any Persistance
    /// La dernière écriture lancée de chaque fichier : la suivante l'attend.
    @ObservationIgnored private var ecritureJournal: Task<Void, any Error>?
    @ObservationIgnored private var ecritureReglages: Task<Void, any Error>?

    public init(persistance: any Persistance, enregistrement: Enregistrement = Enregistrement()) {
        self.persistance = persistance
        journal = enregistrement.journal
        reglages = enregistrement.reglages
    }

    /// Le magasin de ce que la persistance garde.
    public static func charger(_ persistance: any Persistance) async throws -> Magasin {
        let lu = try await persistance.lire()
        return Magasin(persistance: persistance, enregistrement: lu)
    }

    /// Un magasin en mémoire, pour les aperçus et les tests qui n'en lisent pas les écritures.
    public static func enMemoire(_ enregistrement: Enregistrement = Enregistrement()) -> Magasin {
        Magasin(persistance: PersistanceEnMemoire(enregistrement), enregistrement: enregistrement)
    }

    /// Change le journal, puis l'écrit ; rend ce que rend le changement.
    @discardableResult
    public func modifierJournal<Resultat>(_ changement: (inout Journal) -> Resultat) async throws -> Resultat {
        var copie = journal
        let resultat = changement(&copie)
        guard copie != journal else { return resultat }
        journal = copie
        try await ecrire(journal: copie).value
        return resultat
    }

    /// Change les réglages, puis les écrit ; rend ce que rend le changement (`figeInIsrael`,
    /// `takePendingCelebration`…).
    @discardableResult
    public func modifierReglages<Resultat>(_ changement: (inout Reglages) -> Resultat) async throws -> Resultat {
        var copie = reglages
        let resultat = changement(&copie)
        guard copie != reglages else { return resultat }
        reglages = copie
        try await ecrire(reglages: copie).value
        return resultat
    }

    /// Relit ce que la persistance garde, une fois les écritures en cours finies : après un import, ou ce
    /// qu'une extension a changé.
    public func recharger() async throws {
        if let ecritureJournal { _ = await ecritureJournal.result }
        if let ecritureReglages { _ = await ecritureReglages.result }
        let lu = try await persistance.lire()
        journal = lu.journal
        reglages = lu.reglages
    }

    /// Lance l'écriture du journal derrière la précédente. Sans suspension : deux changements faits l'un après
    /// l'autre s'écrivent dans cet ordre.
    private func ecrire(journal: Journal) -> Task<Void, any Error> {
        let precedente = ecritureJournal
        let persistance = self.persistance
        let ecriture = Task {
            if let precedente { _ = await precedente.result }
            try await persistance.enregistrer(journal: journal)
        }
        ecritureJournal = ecriture
        return ecriture
    }

    private func ecrire(reglages: Reglages) -> Task<Void, any Error> {
        let precedente = ecritureReglages
        let persistance = self.persistance
        let ecriture = Task {
            if let precedente { _ = await precedente.result }
            try await persistance.enregistrer(reglages: reglages)
        }
        ecritureReglages = ecriture
        return ecriture
    }
}
