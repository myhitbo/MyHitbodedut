import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le planificateur branché sur le centre de notifications (PORTAGE.md § 2.2.2) : ce qui est en attente est
/// exactement le plan (critère de la tâche 19), une notification qui n'est plus du plan est retirée, celles des
/// autres ne sont pas touchées ; « Plus tard » (Reminder.snooze), le trophée annoncé noté une fois
/// (ReminderReceiver.tropheeProche), la réponse à une notification ; puis les adresses des gestes venus d'hors de
/// l'app (LienApp) et ce que montre la Live Activity (SessionService.runningText).
@Suite("Le planificateur des notifications")
@MainActor
struct PlanificateurNotificationsTests {

    private struct Banc {
        let planificateur: PlanificateurNotifications
        let magasin: Magasin
        let centre: FauxCentreNotifications
        let horloge: HorlogeFixe
    }

    private static func jour(_ iso: String) throws -> JourCivil {
        try #require(JourCivil(iso: iso))
    }

    private static func banc(_ reglages: Reglages, journal: Journal = Journal(), a dateHeure: DateHeure) -> Banc {
        let magasin = Magasin.enMemoire(Enregistrement(journal: journal, reglages: reglages))
        let horloge = HorlogeFixe(dateHeure, fuseau: .utc)
        let centre = FauxCentreNotifications()
        return Banc(planificateur: PlanificateurNotifications(magasin: magasin, horloge: horloge, centre: centre),
                    magasin: magasin, centre: centre, horloge: horloge)
    }

    /// Les rappels à 8 h et 20 h, Birkat haLevana éteint : seuls les rappels de hitbodedout.
    private static func rappels(_ heures: [Int] = [480, 1200]) -> Reglages {
        var r = Reglages()
        r.setReminderEnabled(true)
        r.setReminderTimes(heures)
        r.setLevanaRappel(false)
        return r
    }

    @Test func lAttenteEstLePlan() async throws {
        let j = try Self.jour("2026-11-16")
        let b = Self.banc(Self.rappels(), a: DateHeure(j, heure: 10))
        await b.centre.poserAutre("celebration")
        await b.centre.poser([DemandeNotification(identifiant: "rappel-1", instant: 0, titre: Libelle("reminder_title"),
                                                  lignes: [], categorie: nil, lien: .accueil, trophee: nil)])
        await b.planificateur.replanifier()

        let attendu = PlanNotifications.planifier(reglages: b.magasin.reglages, journal: b.magasin.journal,
                                                  volRappels: [], maintenant: b.horloge.maintenant, fuseau: .utc)
        let poses = Set(await b.centre.enAttente().filter(PlanificateurNotifications.possede))
        #expect(poses == Set(attendu.map(\.identifiant)))
        #expect(b.planificateur.plan.map(\.identifiant) == attendu.map(\.identifiant))
        #expect(attendu.count <= PlanNotifications.limite)
        // Le premier rappel : ce soir à 20 h, avec « Commencer » et « Plus tard ».
        let premier = try #require(b.planificateur.plan.first)
        #expect(premier.instant == Fuseau.utc.millis(DateHeure(j, heure: 20)))
        #expect(premier.categorie == DemandeNotification.categorieRappel)
        #expect(premier.titre == Libelle("reminder_title"))
        #expect(premier.lien == .accueil)
        // L'ancien rappel est retiré ; la notification d'un autre reste.
        let attente = await b.centre.enAttente()
        #expect(!attente.contains("rappel-1"))
        #expect(attente.contains("celebration"))
        #expect(b.planificateur.passages == 1)
    }

    @Test func eteintsPlusRienDuPlan() async throws {
        let j = try Self.jour("2026-11-16")
        let b = Self.banc(Self.rappels(), a: DateHeure(j, heure: 10))
        await b.planificateur.replanifier()
        #expect(!(await b.centre.enAttente()).isEmpty)
        try await b.magasin.modifierReglages { $0.setReminderEnabled(false) }
        await b.planificateur.replanifier(b.magasin.reglages)
        #expect(await b.centre.enAttente().isEmpty)
        #expect(b.planificateur.plan.isEmpty)
    }

    @Test func laJourneeFaiteTaitLesRappelsDuJour() async throws {
        let j = try Self.jour("2026-11-16")
        var journal = Journal()
        var reglages = Self.rappels()
        Store.addSession(journal: &journal, reglages: &reglages, minutes: 20, note: nil, theme: nil, date: j,
                         millis: Fuseau.utc.millis(DateHeure(j, heure: 9)), fuseau: .utc)
        let b = Self.banc(reglages, journal: journal, a: DateHeure(j, heure: 10))
        await b.planificateur.replanifier()
        let premier = try #require(b.planificateur.plan.first)
        // Rien ce soir : demain à 8 h.
        #expect(premier.instant == Fuseau.utc.millis(DateHeure(j.plus(jours: 1), heure: 8)))
    }

    @Test func plusTardReporteDeTrenteMinutes() async throws {
        let j = try Self.jour("2026-11-16")
        let b = Self.banc(Self.rappels(), a: DateHeure(j, heure: 10))
        try await b.planificateur.reporter()
        let fin = b.horloge.maintenant + 30 * 60_000
        #expect(b.magasin.reglages.reminderSnoozedUntil == fin)
        #expect(await b.centre.enAttente().contains("rappel-reporte-" + String(fin)))
    }

    @Test func leTropheeAnnonceEstNoteUneFois() async throws {
        let j = try Self.jour("2026-11-16")
        let b = Self.banc(Self.rappels(), a: DateHeure(j, heure: 10))
        await b.centre.poser([DemandeNotification(identifiant: "rappel-5", instant: 0, titre: Libelle("reminder_title"),
                                                  lignes: [], categorie: nil, lien: .accueil, trophee: "SERIE:2")])
        await b.centre.paraitre("rappel-5")
        await b.planificateur.replanifier()
        #expect(b.magasin.reglages.tropheesProchesSignales.contains("SERIE:2"))
        // La journée faite : le rappel paru quitte le centre.
        await b.planificateur.retirerRappelParu()
        #expect(await b.centre.tropheesParus().isEmpty)
    }

    @Test func leVolFaitRepasserLePlanificateur() async throws {
        let j = try Self.jour("2026-11-16")
        let b = Self.banc(Self.rappels(), a: DateHeure(j, heure: 10))
        await b.planificateur.retirer(prefixe: VolNotifications.prefixe)
        #expect(b.planificateur.passages == 1)
    }

    @Test func uneNotificationDuPlanDevientUneDemande() {
        let levana = NotificationPlanifiee(identifiant: "levana-2026-11-20-premier", instant: 5,
                                           titre: Libelle("levana_rappel_premier"), texte: Libelle("levana_rappel_texte"),
                                           categorie: .levana, texteSiddur: "birkat_halevana")
        let demande = DemandeNotification(levana)
        #expect(demande.lien == .siddour("birkat_halevana"))
        #expect(demande.categorie == nil)
        #expect(demande.lignes == [Libelle("levana_rappel_texte")])
        let rappel = NotificationPlanifiee(identifiant: "rappel-7", instant: 7, titre: Libelle("reminder_title"),
                                           texte: Libelle("reminder_text"), suite: Libelle("rappel_trophee_proche"),
                                           categorie: .rappel, actions: [.commencer, .plusTard], trophee: "SERIE:1")
        let r = DemandeNotification(rappel)
        #expect(r.categorie == "rappel")
        #expect(r.lignes == [Libelle("reminder_text"), Libelle("rappel_trophee_proche")])
        #expect(r.trophee == "SERIE:1")
        #expect(r.lien == .accueil)
    }

    @Test func laReponseAUneNotification() {
        #expect(PlanificateurNotifications.reponse(action: "commencer", lien: .accueil) == .ouvrir(.seance(demarrer: true)))
        #expect(PlanificateurNotifications.reponse(action: "plus_tard", lien: .accueil) == .reporter)
        #expect(PlanificateurNotifications.reponse(action: PlanificateurNotifications.actionEcartee, lien: nil) == .rien)
        #expect(PlanificateurNotifications.reponse(action: "com.apple.UNNotificationDefaultActionIdentifier",
                                                   lien: .siddour("hagomel")) == .ouvrir(.siddour("hagomel")))
        #expect(PlanificateurNotifications.reponse(action: "com.apple.UNNotificationDefaultActionIdentifier",
                                                   lien: nil) == .ouvrir(.accueil))
        #expect(PlanificateurNotifications.possede("rappel-reporte-12"))
        #expect(PlanificateurNotifications.possede("vol-0-OMER-5"))
        #expect(!PlanificateurNotifications.possede("celebration"))
    }

    // MARK: Les adresses

    @Test func lesAdressesAllerEtRetour() {
        let liens: [LienApp] = [.accueil, .zmanim, .boussole, .calendrier, .rappels, .seance(demarrer: false),
                                .seance(demarrer: true), .terminerSeance, .siddour("birkat_halevana"), .vol]
        for lien in liens {
            #expect(LienApp(url: lien.url) == lien, "\(lien.url)")
            #expect(LienApp(texte: lien.url.absoluteString) == lien)
        }
        #expect(LienApp.seance(demarrer: true).url.absoluteString == "myhitbodedut://seance?demarrer=1")
        #expect(LienApp.siddour("arvit").url.absoluteString == "myhitbodedut://siddour/arvit")
        #expect(LienApp(texte: "https://example.org/zmanim") == nil)
        #expect(LienApp(texte: "myhitbodedut://inconnu") == nil)
        #expect(LienApp(texte: "myhitbodedut://siddour") == nil)
    }

    // MARK: La Live Activity

    @Test func laLiveActivityMontreLeCompteur() async throws {
        let j = try Self.jour("2026-11-16")
        let magasin = Magasin.enMemoire()
        let horloge = HorlogeFixe(DateHeure(j, heure: 10), fuseau: .utc)
        let activite = FausseActiviteEnDirect()
        let seance = SeanceEnCours(magasin: magasin, horloge: horloge, activite: activite)

        try await seance.commencer(minutes: 20)
        let minutee = try #require(await activite.affichee)
        #expect(minutee.debut == horloge.maintenant)
        #expect(minutee.fin == horloge.maintenant + 20 * 60_000)
        #expect(minutee.compteur == .reste && minutee.decompte && !minutee.ouverte)
        #expect(minutee.texteMasque == nil)
        #expect(minutee.titre == Libelle("session_running_title"))
        #expect(minutee.terminer == Libelle("session_finish_now"))

        try await seance.abandonner()
        #expect(await activite.affichee == nil)

        // Sans durée : le temps passé, jusqu'au plafond de 240 minutes.
        try await seance.commencer(minutes: SessionRule.ouverte)
        let ouverte = try #require(await activite.affichee)
        #expect(ouverte.compteur == .ecoule && !ouverte.decompte && ouverte.ouverte)
        #expect(ouverte.fin == horloge.maintenant + Int64(SessionRule.plafondOuverte) * 60_000)
        try await seance.abandonner()

        // Compteur masqué : une phrase sans chiffre.
        try await magasin.modifierReglages { $0.setHideCountdown(true) }
        try await seance.commencer(minutes: 15)
        let masquee = try #require(await activite.affichee)
        #expect(masquee.compteur == .masque)
        #expect(masquee.texteMasque == Libelle("session_running_hidden"))
        try await seance.abandonner()
        try await seance.commencer(minutes: SessionRule.ouverte)
        #expect(await activite.affichee?.texteMasque == Libelle("session_running_open_hidden"))
    }
}
