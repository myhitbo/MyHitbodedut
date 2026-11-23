import Foundation
import Testing
import Coeur
@testable import Ecrans

/// L'écran des rappels (RemindersActivity.kt) : le résumé du bandeau, l'interrupteur et la demande des
/// notifications (DemandeNotifications.kt : la question tant qu'iOS ne l'a pas posée, puis les Réglages d'iOS),
/// l'avertissement d'un rappel muet (PermissionRules.rappelMuet), les heures ajoutées, changées et retirées, chaque
/// changement replanifié (Reminder.reschedule).
@Suite("Les rappels")
@MainActor
struct RappelsModeleTests {

    private struct Banc {
        let modele: RappelsModele
        let magasin: Magasin
        let notificateur: FauxNotificateur
        let rappels: PresentationRappelsEnMemoire
    }

    private static func banc(_ reglages: Reglages = Reglages(), accordee: Bool = true,
                             dejaRefusee: Bool = false) -> Banc {
        let magasin = Magasin.enMemoire(Enregistrement(reglages: reglages))
        let notificateur = FauxNotificateur(accordee: accordee, dejaRefusee: dejaRefusee)
        let rappels = PresentationRappelsEnMemoire()
        return Banc(modele: RappelsModele(magasin: magasin, notificateur: notificateur, rappels: rappels),
                    magasin: magasin, notificateur: notificateur, rappels: rappels)
    }

    private static func actifs(_ heures: [Int]) -> Reglages {
        var r = Reglages()
        r.setReminderEnabled(true)
        r.setReminderTimes(heures)
        return r
    }

    private static func vaut(_ h: (heure: Int, minute: Int), _ heure: Int, _ minute: Int) -> Bool {
        h.heure == heure && h.minute == minute
    }

    @Test func leResumeDuBandeau() {
        #expect(Self.banc().modele.resume == Libelle("reminders_off"))
        #expect(Self.banc(Self.actifs([])).modele.resume == Libelle("reminders_none"))
        #expect(Self.banc(Self.actifs([480, 1200])).modele.resume
                == Libelle.pluriel("reminders_count", quantite: 2, .entier(2)))
        #expect(Self.banc().modele.titre == Libelle("reminders_title"))
        #expect(Self.banc().modele.image == "char_pointing")
    }

    @Test func lesHeuresTrieesEtSansDoublon() {
        let modele = Self.banc(Self.actifs([1200, 480, 480])).modele
        #expect(modele.heures.map(\.minutes) == [480, 1200])
        #expect(modele.heures[1].heure == 20 && modele.heures[1].minute == 0)
        // Sans liste écrite, l'heure unique d'avant (7 h).
        #expect(Self.banc().modele.heures.map(\.minutes) == [Reglages.defaultReminder])
    }

    @Test func allumerDemandeLesNotificationsPuisReplanifie() async throws {
        let b = Self.banc(accordee: false)
        let route = try await b.modele.basculer(true)
        #expect(route == nil)
        #expect(b.magasin.reglages.reminderEnabled)
        #expect(await b.notificateur.demandes == 1)
        #expect(await b.rappels.replanifications.count == 1)
        // Refusées : le rappel est muet, l'écran le dit.
        #expect(b.modele.permissionManquante)
        #expect(b.modele.permissionTexte == Libelle("reminders_permission_missing"))
        // Le toucher suivant ne repose pas la question : les Réglages d'iOS.
        let ensuite = await b.modele.demanderNotifications()
        #expect(ensuite == .reglagesNotifications)
        #expect(b.modele.routes == [.reglagesNotifications])
        b.modele.routeOuverte()
        #expect(b.modele.routes.isEmpty)
        #expect(await b.notificateur.demandes == 1)
    }

    @Test func dejaRefuseesLesReglagesDIOSAussitot() async throws {
        let b = Self.banc(accordee: false, dejaRefusee: true)
        let route = try await b.modele.basculer(true)
        #expect(route == .reglagesNotifications)
        #expect(await b.notificateur.demandes == 0)
    }

    @Test func accordeesRienNEstDemande() async throws {
        let b = Self.banc()
        try await b.modele.basculer(true)
        #expect(await b.notificateur.demandes == 0)
        #expect(!b.modele.permissionManquante)
        // Éteint, aucun avertissement même sans notifications.
        let c = Self.banc(accordee: false)
        await c.modele.apparaitre()
        #expect(!c.modele.notificationsAccordees)
        #expect(!c.modele.permissionManquante)
        try await c.modele.basculer(false)
        #expect(await c.notificateur.demandes == 0)
        #expect(await c.rappels.replanifications.count == 1)
    }

    @Test func ajouterChangerRetirer() async throws {
        let b = Self.banc(Self.actifs([480]))
        // L'ajout s'ouvre sur la dernière heure réglée.
        b.modele.ouvrirAjout()
        #expect(b.modele.dialogue == .ajout)
        #expect(Self.vaut(b.modele.heureInitiale(.ajout), 8, 0))
        try await b.modele.valider(heure: 21, minute: 15)
        #expect(b.modele.dialogue == nil)
        #expect(b.magasin.reglages.reminderTimes == [480, 21 * 60 + 15])

        // Changer la première : elle cède la place, la liste se trie.
        b.modele.ouvrirChangement(b.modele.heures[0])
        #expect(Self.vaut(b.modele.heureInitiale(.changement(rang: 0)), 8, 0))
        try await b.modele.valider(heure: 22, minute: 0)
        #expect(b.magasin.reglages.reminderTimes == [21 * 60 + 15, 22 * 60])

        // Une heure déjà réglée ne se double pas.
        b.modele.ouvrirAjout()
        try await b.modele.valider(heure: 22, minute: 0)
        #expect(b.magasin.reglages.reminderTimes == [21 * 60 + 15, 22 * 60])

        try await b.modele.retirer(b.modele.heures[0])
        #expect(b.magasin.reglages.reminderTimes == [22 * 60])
        try await b.modele.retirer(b.modele.heures[0])
        #expect(b.magasin.reglages.reminderTimes.isEmpty)
        #expect(b.modele.resume == Libelle("reminders_none"))
        // Sans heure, l'ajout part de 7 h.
        #expect(Self.vaut(b.modele.heureInitiale(.ajout), 7, 0))
        #expect(await b.rappels.replanifications.count == 5)

        // Sans dialogue ouvert, rien n'est validé.
        try await b.modele.valider(heure: 9, minute: 0)
        #expect(b.magasin.reglages.reminderTimes.isEmpty)
    }

    @Test func leDiagnosticEstLePlan() {
        let demande = DemandeNotification(identifiant: "rappel-1", instant: 1, titre: Libelle("reminder_title"),
                                          lignes: [], categorie: "rappel", lien: .accueil, trophee: nil)
        let magasin = Magasin.enMemoire()
        let modele = RappelsModele(magasin: magasin, notificateur: FauxNotificateur(),
                                   rappels: PresentationRappelsEnMemoire(), plan: { [demande] })
        #expect(modele.diagnostic == [demande])
        #expect(modele.diagnosticTitre == Libelle("rappels_diagnostic"))
        #expect(Self.banc().modele.diagnostic.isEmpty)
    }

    @Test func leTropheeToutProche() async throws {
        let b = Self.banc()
        #expect(b.modele.trophee == b.magasin.reglages.rappelTropheeProche)
        try await b.modele.basculerTrophee(false)
        #expect(!b.magasin.reglages.rappelTropheeProche)
        #expect(await b.rappels.replanifications.count == 1)
    }
}
