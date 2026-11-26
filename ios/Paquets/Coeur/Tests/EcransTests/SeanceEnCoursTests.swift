import Foundation
import Synchronization
import Testing
import Coeur
@testable import Ecrans

/// Une horloge que le test avance : la séance court pendant qu'on la regarde.
final class SeanceHorlogeReglable: Horloge {
    let fuseau: Fuseau
    private let instant: Mutex<Int64>
    /// L'horloge monotone (le temps depuis le démarrage), si l'essai en veut une.
    private let depuisDemarrage: Mutex<Int64?>

    init(_ dateHeure: DateHeure, fuseau: Fuseau = .utc, monotone: Bool = false) {
        self.fuseau = fuseau
        instant = Mutex(fuseau.millis(dateHeure))
        depuisDemarrage = Mutex(monotone ? 3_600_000 : nil)
    }

    var maintenant: Int64 {
        instant.withLock { $0 }
    }

    var monotone: HorlogeMonotone {
        depuisDemarrage.withLock { $0 }.map { HorlogeMonotone(millis: $0, demarrage: 12) } ?? .absente
    }

    /// Le temps passe : l'heure murale et l'horloge monotone avancent ensemble.
    func avancer(heures: Int64 = 0, minutes: Int64 = 0, secondes: Int64 = 0) {
        let pas = ((heures * 60 + minutes) * 60 + secondes) * 1_000
        instant.withLock { $0 += pas }
        depuisDemarrage.withLock { if let t = $0 { $0 = t + pas } }
    }

    /// L'heure du téléphone change (heure d'hiver, voyage, réglage à la main) : seule l'heure murale bouge.
    func changerHeure(minutes: Int64) {
        instant.withLock { $0 += minutes * 60_000 }
    }
}

/// Les aides des tests de la séance, du bravo et de la note.
enum SeanceOutils {
    static func jour(_ iso: String) throws -> JourCivil {
        try #require(JourCivil(iso: iso))
    }

    static func paris() throws -> Fuseau {
        try #require(Fuseau("Europe/Paris"))
    }
}

/// La séance qui tourne (SessionService.kt) : son début, sa fin d'elle-même, « Terminer », « Abandonner », la
/// séance précédente close par la suivante, la réconciliation au retour, l'inscription au jour du début, les
/// services (musique, Live Activity, son de fin) qui la suivent. Les critères des tâches 16 et 17 de la feuille
/// de route qui se vérifient par des valeurs.
///
/// Restent au test d'interface et aux captures : la Live Activity réelle et son bouton « Terminer » (AppIntent),
/// la notification de fin programmée (tâche 17), le son réellement joué.
@Suite("La séance en cours")
@MainActor
struct SeanceEnCoursTests {

    private struct Banc {
        let seance: SeanceEnCours
        let magasin: Magasin
        let horloge: SeanceHorlogeReglable
        let persistance: PersistanceEnMemoire
        let musique: SeanceFausseMusique
        let activite: FausseActiviteEnDirect
        let son: FauxLecteurSon
    }

    private static func banc(_ dateHeure: DateHeure, fuseau: Fuseau = .utc,
                             reglages: Reglages = Reglages(), journal: Journal = Journal(),
                             monotone: Bool = false) -> Banc {
        let enregistrement = Enregistrement(journal: journal, reglages: reglages)
        let persistance = PersistanceEnMemoire(enregistrement)
        let magasin = Magasin(persistance: persistance, enregistrement: enregistrement)
        let horloge = SeanceHorlogeReglable(dateHeure, fuseau: fuseau, monotone: monotone)
        let musique = SeanceFausseMusique()
        let activite = FausseActiviteEnDirect()
        let son = FauxLecteurSon()
        let seance = SeanceEnCours(magasin: magasin, horloge: horloge, musique: musique, activite: activite, son: son)
        return Banc(seance: seance, magasin: magasin, horloge: horloge, persistance: persistance, musique: musique,
                    activite: activite, son: son)
    }

    /// Le même magasin, repris par un processus neuf (l'app tuée puis relancée) : rien ne suit plus la séance.
    private static func relance(_ banc: Banc) -> SeanceEnCours {
        SeanceEnCours(magasin: banc.magasin, horloge: banc.horloge, musique: banc.musique, activite: banc.activite)
    }

    // MARK: « Continuer ? » (24/11) et l'horloge de la séance

    /// La question tombe dix secondes avant la fin, une fois ; « Oui, 5 min de plus » repart de la fin prévue, la Live
    /// Activity et l'alarme suivent ; la séance prolongée s'inscrit pour toute sa durée.
    @Test func continuerCinqMinutesDePlus() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        let minuterie = FausseMinuterie()
        var r = b.magasin.reglages
        MinuterieReglage.poser(true, dans: &r)
        let avecAlarme = r
        try await b.magasin.modifierReglages { $0 = avecAlarme }
        let seance = SeanceEnCours(magasin: b.magasin, horloge: b.horloge, activite: b.activite, minuterie: minuterie)
        let debut = b.horloge.maintenant
        try await seance.commencer(minutes: 15)
        #expect(Store.sessionPas(reglages: b.magasin.reglages) == 15)
        #expect(seance.questionSuite == nil)
        // Onze secondes avant la fin : pas encore.
        b.horloge.avancer(minutes: 14, secondes: 49)
        try await seance.actualiser()
        #expect(seance.questionSuite == nil)
        #expect(Store.suiteEtat(reglages: b.magasin.reglages) == Store.suiteAucune)
        // Dix secondes avant : posée, avec ses quatre réponses.
        b.horloge.avancer(secondes: 1)
        try await seance.actualiser()
        #expect(Store.suiteEtat(reglages: b.magasin.reglages) == Store.suitePosee)
        let reponses = try #require(seance.questionSuite)
        #expect(reponses.map(\.minutes) == [5, 15, SessionRule.ouverte, nil])
        #expect(reponses.map(\.libelle) == [
            Libelle("session_suite_oui_plus", .libelle(Store.formatDuration(5))),
            Libelle("session_suite_oui_plus", .libelle(Store.formatDuration(15))),
            Libelle("session_suite_oui_sans_fin"), Libelle("session_suite_non")])
        // Oui, 5 minutes de plus.
        try await seance.continuer(minutes: 5)
        #expect(seance.fin == debut + 20 * 60_000)
        #expect(seance.duree == 20)
        #expect(seance.questionSuite == nil)
        #expect(seance.reponsesSuite == 1)
        #expect(Store.suiteEtat(reglages: b.magasin.reglages) == Store.suiteAucune)
        let montree = await b.activite.seance
        #expect(montree?.fin == debut + 20 * 60_000)
        #expect(await minuterie.posee == debut + 20 * 60_000)
        // La question revient avant la nouvelle fin ; sans réponse, la séance va à son terme et s'inscrit en entier.
        b.horloge.avancer(minutes: 5)
        try await seance.actualiser()
        #expect(seance.questionSuite != nil)
        b.horloge.avancer(secondes: 10)
        try await seance.actualiser()
        #expect(!seance.enCours)
        #expect(b.magasin.journal.record(jour)?.minutes == 20)
    }

    /// « Oui, sans fin » : la séance devient ouverte ; « Non » : la question ne revient pas, la séance va à son terme.
    @Test func continuerSansFinOuNon() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        try await b.seance.commencer(minutes: 5)
        b.horloge.avancer(minutes: 4, secondes: 55)
        try await b.seance.actualiser()
        // Une durée de 5 minutes : pas de « même durée » en double.
        #expect(b.seance.questionSuite?.map(\.minutes) == [5, SessionRule.ouverte, nil])
        try await b.seance.continuer(minutes: SessionRule.ouverte)
        #expect(b.seance.ouverte)
        #expect(b.seance.fin == 0)
        b.horloge.avancer(minutes: 20)
        try await b.seance.actualiser()
        #expect(b.seance.enCours)
        #expect(b.seance.questionSuite == nil)
        try await b.seance.terminer()
        #expect(b.magasin.journal.record(jour)?.minutes == 24)

        let n = Self.banc(DateHeure(jour, heure: 12))
        try await n.seance.commencer(minutes: 10)
        n.horloge.avancer(minutes: 9, secondes: 52)
        try await n.seance.actualiser()
        try await n.seance.nePasContinuer()
        #expect(Store.suiteEtat(reglages: n.magasin.reglages) == Store.suiteNon)
        #expect(n.seance.questionSuite == nil)
        n.horloge.avancer(secondes: 4)
        try await n.seance.actualiser()
        #expect(n.seance.questionSuite == nil)
        n.horloge.avancer(secondes: 4)
        try await n.seance.actualiser()
        #expect(n.magasin.journal.record(jour)?.minutes == 10)
    }

    /// L'option éteinte, aucune question ; une réponse arrivée après la fin ne prolonge rien.
    @Test func sansOptionPasDeQuestionEtUneReponseTardiveNeProlongePas() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        var r = Reglages()
        r.setProposerSuite(false)
        let b = Self.banc(DateHeure(jour, heure: 10), reglages: r)
        try await b.seance.commencer(minutes: 10)
        b.horloge.avancer(minutes: 9, secondes: 55)
        try await b.seance.actualiser()
        #expect(b.seance.questionSuite == nil)
        #expect(Store.suiteEtat(reglages: b.magasin.reglages) == Store.suiteAucune)
        // Après la fin, sans tour entre-temps : la réponse ne prolonge pas, la séance s'inscrit pour sa durée.
        b.horloge.avancer(minutes: 1)
        try await b.seance.continuer(minutes: 5)
        #expect(b.seance.fin == b.seance.debut + 10 * 60_000)
        try await b.seance.actualiser()
        #expect(b.magasin.journal.record(jour)?.minutes == 10)
    }

    /// Décision du 24/11 : l'heure du téléphone recule d'une heure en pleine séance ; elle dure toujours ses vingt
    /// minutes réelles, sur l'écran, la Live Activity et au journal.
    @Test func lHeureDuTelephoneChangeLaSeanceNon() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10), monotone: true)
        try await b.seance.commencer(minutes: 20)
        let debut = b.seance.debut
        b.horloge.avancer(minutes: 10)
        b.horloge.changerHeure(minutes: -60)
        try await b.seance.actualiser()
        #expect(b.seance.enCours)
        #expect(b.seance.maintenantSeance == debut + 10 * 60_000)
        #expect(b.seance.texteEnCours == Libelle("session_remaining", .libelle(Store.formatDuration(10))))
        // La fin, à l'heure murale nouvelle : dans dix minutes.
        #expect(b.seance.murale(b.seance.fin) == b.horloge.maintenant + 10 * 60_000)
        b.horloge.avancer(minutes: 9, secondes: 59)
        try await b.seance.actualiser()
        #expect(b.seance.enCours)
        b.horloge.avancer(secondes: 1)
        try await b.seance.actualiser()
        #expect(!b.seance.enCours)
        #expect(b.magasin.journal.record(jour)?.minutes == 20)
    }

    /// Relecture du 23/11 : « Tout effacer » pendant une séance ; le tour suivant ne trouve plus rien à suivre, la
    /// musique s'arrête avec elle, rien ne s'inscrit.
    @Test func toutEffacerPendantUneSeanceArreteSaMusique() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        try await b.seance.commencer(minutes: 20)
        #expect(b.musique.seanceEnCours)
        try await b.magasin.modifierJournal { $0 = Journal() }
        try await b.magasin.modifierReglages { $0 = Reglages() }
        try await b.seance.actualiser()
        #expect(!b.musique.seanceEnCours)
        #expect(!b.seance.suivie)
        #expect(b.magasin.journal.record(jour) == nil)
    }

    // MARK: Une séance qui va à son terme

    @Test func uneSeanceDUneMinuteSInscritASonTerme() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        let debut = b.horloge.maintenant
        try await b.seance.commencer(minutes: 1)

        #expect(b.seance.enCours)
        #expect(b.seance.enregistree)
        #expect(b.seance.suivie)
        #expect(b.seance.debut == debut)
        #expect(b.seance.fin == debut + 60_000)
        #expect(b.seance.duree == 1)
        #expect(b.musique.seanceEnCours)
        let montree = await b.activite.seance
        #expect(montree?.debut == debut)
        #expect(montree?.fin == debut + 60_000)

        // 59 secondes : rien ne se clôt.
        b.horloge.avancer(secondes: 59)
        try await b.seance.actualiser()
        #expect(b.seance.enCours)
        #expect(b.magasin.journal.record(jour) == nil)

        // Le terme : la journée est inscrite, le bravo attend, tout s'arrête.
        b.horloge.avancer(secondes: 1)
        try await b.seance.actualiser()
        #expect(!b.seance.enCours)
        #expect(!b.seance.enregistree)
        #expect(!b.seance.suivie)
        #expect(b.magasin.journal.record(jour)?.minutes == 1)
        #expect(b.magasin.journal.isDone(jour))
        #expect(b.magasin.reglages.hasPendingCelebration)
        #expect(b.seance.inscriptions == 1)
        #expect(!b.musique.seanceEnCours)
        #expect(b.musique.terminees == 1)
        // Un tuple n'est pas Equatable : la comparaison à nil se fait hors de #expect (comme ServicesTests).
        let retiree = await b.activite.seance == nil
        #expect(retiree)

        // Écrit sur le disque.
        let ecrit = await b.persistance.enregistrement
        #expect(ecrit.journal.record(jour)?.minutes == 1)
        #expect(!Store.hasSessionRecord(reglages: ecrit.reglages))

        // Un second tour ne réinscrit rien.
        b.horloge.avancer(secondes: 5)
        try await b.seance.actualiser()
        #expect(b.magasin.journal.record(jour)?.minutes == 1)
    }

    @Test func leBravoAttendAvecLeJourDeLaNote() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        try await b.seance.commencer(minutes: 5)
        b.horloge.avancer(minutes: 5)
        try await b.seance.actualiser()
        var reglages = b.magasin.reglages
        let attente = Store.takePendingCelebration(reglages: &reglages)
        #expect(attente == Reglages.Celebration(minutes: 5, dateNote: "2026-11-16"))
    }

    // MARK: Le jour du début

    @Test func uneSeanceCommenceeA23h59SInscritLaVeille() async throws {
        let paris = try SeanceOutils.paris()
        let veille = try SeanceOutils.jour("2026-11-15")
        let lendemain = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(veille, heure: 23, minute: 59), fuseau: paris)
        try await b.seance.commencer(minutes: 5)
        b.horloge.avancer(minutes: 5)
        try await b.seance.actualiser()
        #expect(b.horloge.aujourdhui == lendemain)
        #expect(b.magasin.journal.record(veille)?.minutes == 5)
        #expect(b.magasin.journal.record(lendemain) == nil)
        var reglages = b.magasin.reglages
        #expect(Store.takePendingCelebration(reglages: &reglages)?.dateNote == "2026-11-15")
    }

    @Test func terminerApresMinuitInscritAussiLaVeille() async throws {
        let paris = try SeanceOutils.paris()
        let veille = try SeanceOutils.jour("2026-11-15")
        let b = Self.banc(DateHeure(veille, heure: 23, minute: 59), fuseau: paris)
        try await b.seance.commencer(minutes: 30)
        b.horloge.avancer(minutes: 3, secondes: 10)
        try await b.seance.terminer()
        #expect(b.magasin.journal.record(veille)?.minutes == 3)
    }

    // MARK: La fin constatée tard

    @Test func vingtMinutesConstateesTroisHeuresPlusTardParLaReconciliation() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        try await b.seance.commencer(minutes: 20)
        b.horloge.avancer(heures: 3)
        // L'app a été tuée : un processus neuf reprend la séance au lancement.
        let neuve = Self.relance(b)
        #expect(!neuve.suivie)
        try await neuve.reconcilier()
        #expect(b.magasin.journal.record(jour)?.minutes == 20)
        #expect(!neuve.enregistree)
        #expect(b.magasin.reglages.hasPendingCelebration)
        #expect(neuve.inscriptions == 1)
    }

    @Test func vingtMinutesConstateesTroisHeuresPlusTardParLeTour() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        try await b.seance.commencer(minutes: 20)
        // L'app a dormi : le premier tour au retour clôt la séance.
        b.horloge.avancer(heures: 3)
        try await b.seance.actualiser()
        #expect(b.magasin.journal.record(jour)?.minutes == 20)
    }

    @Test func vingtMinutesCommenceesLeSoirConstateesLeLendemain() async throws {
        let paris = try SeanceOutils.paris()
        let veille = try SeanceOutils.jour("2026-11-15")
        let lendemain = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(veille, heure: 23, minute: 50), fuseau: paris)
        try await b.seance.commencer(minutes: 20)
        b.horloge.avancer(heures: 3)
        let neuve = Self.relance(b)
        try await neuve.reconcilier()
        #expect(b.magasin.journal.record(veille)?.minutes == 20)
        #expect(b.magasin.journal.record(lendemain) == nil)
    }

    @Test func uneSeanceMinuteeEncoreEnCoursEstReprise() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        try await b.seance.commencer(minutes: 20)
        b.horloge.avancer(minutes: 5)
        let neuve = Self.relance(b)
        try await neuve.reconcilier()
        #expect(neuve.suivie)
        #expect(neuve.enCours)
        #expect(b.magasin.journal.record(jour) == nil)
        #expect(b.musique.commencees == 2)
    }

    @Test func laReconciliationNeFaitRienSansSeance() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        try await b.seance.reconcilier()
        #expect(!b.seance.suivie)
        #expect(b.musique.commencees == 0)
        let ecritures = await b.persistance.ecrituresReglages
        #expect(ecritures == 0)
    }

    // MARK: La séance sans durée

    @Test func uneSeanceSansDureeOublieeEstPlafonneeA240() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 8))
        try await b.seance.commencer(minutes: SessionRule.ouverte)
        #expect(b.seance.ouverte)
        #expect(b.seance.fin == 0)
        #expect(b.seance.compteur == .ecoule)
        // La Live Activity court jusqu'au plafond.
        let montree = await b.activite.seance
        #expect(montree?.fin == b.seance.debut + 240 * 60_000)

        b.horloge.avancer(heures: 5)
        let neuve = Self.relance(b)
        try await neuve.reconcilier()
        #expect(b.magasin.journal.record(jour)?.minutes == 240)
        #expect(!neuve.enregistree)
    }

    @Test func uneSeanceSansDureeSuivieEtArreteeTardEstPlafonnee() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 8))
        try await b.seance.commencer(minutes: SessionRule.ouverte)
        b.horloge.avancer(heures: 6)
        try await b.seance.actualiser()
        // Suivie, elle court jusqu'au geste qui l'arrête…
        #expect(b.seance.enCours)
        try await b.seance.terminer()
        // … et n'inscrit pas plus que le plafond.
        #expect(b.magasin.journal.record(jour)?.minutes == 240)
    }

    @Test func uneSeanceSansDureeDeDeuxHeuresEstReprise() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 8))
        try await b.seance.commencer(minutes: SessionRule.ouverte)
        b.horloge.avancer(heures: 2)
        let neuve = Self.relance(b)
        try await neuve.reconcilier()
        #expect(neuve.suivie)
        #expect(neuve.enCours)
        #expect(b.magasin.journal.record(jour) == nil)
    }

    // MARK: Terminer, abandonner

    @Test func terminerAvantUneMinutePleineNInscritRien() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        try await b.seance.commencer(minutes: 20)
        b.horloge.avancer(secondes: 59)
        try await b.seance.terminer()
        #expect(!b.seance.enregistree)
        #expect(!b.seance.suivie)
        #expect(b.magasin.journal.record(jour) == nil)
        #expect(!b.magasin.reglages.hasPendingCelebration)
        #expect(b.seance.inscriptions == 0)
        #expect(b.musique.terminees == 1)
    }

    @Test func terminerApresTroisMinutesEtDemieInscritTrois() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        try await b.seance.commencer(minutes: 20)
        b.horloge.avancer(minutes: 3, secondes: 30)
        try await b.seance.terminer()
        #expect(b.magasin.journal.record(jour)?.minutes == 3)
        #expect(b.magasin.reglages.hasPendingCelebration)
    }

    @Test func lesMinutesSAjoutentAuxSeancesDuJour() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        try await b.seance.commencer(minutes: 5)
        b.horloge.avancer(minutes: 5)
        try await b.seance.actualiser()
        b.horloge.avancer(heures: 2)
        try await b.seance.commencer(minutes: 10)
        b.horloge.avancer(minutes: 10)
        try await b.seance.actualiser()
        #expect(b.magasin.journal.record(jour)?.minutes == 15)
    }

    @Test func unAbandonNInscritRien() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        try await b.seance.commencer(minutes: 20)
        b.horloge.avancer(minutes: 12)
        try await b.seance.abandonner()
        #expect(!b.seance.enregistree)
        #expect(!b.seance.suivie)
        #expect(b.magasin.journal.record(jour) == nil)
        #expect(!b.magasin.reglages.hasPendingCelebration)
        #expect(!b.musique.seanceEnCours)
        // Un tuple n'est pas Equatable : la comparaison à nil se fait hors de #expect (comme ServicesTests).
        let retiree = await b.activite.seance == nil
        #expect(retiree)
        let ecrit = await b.persistance.enregistrement
        #expect(ecrit.journal.record(jour) == nil)
    }

    // MARK: Une séance qui en remplace une autre

    @Test func commencerClotLaPrecedenteEtInscritSesMinutes() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        try await b.seance.commencer(minutes: 20)
        b.horloge.avancer(minutes: 7)
        try await b.seance.commencer(minutes: 10)
        #expect(b.magasin.journal.record(jour)?.minutes == 7)
        #expect(b.magasin.reglages.hasPendingCelebration)
        #expect(b.seance.enCours)
        #expect(b.seance.duree == 10)
        #expect(b.seance.debut == b.horloge.maintenant)
    }

    @Test func commencerApresUneSeanceEchueLInscrit() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        try await b.seance.commencer(minutes: 15)
        b.horloge.avancer(heures: 1)
        let neuve = Self.relance(b)
        try await neuve.commencer(minutes: 5)
        #expect(b.magasin.journal.record(jour)?.minutes == 15)
        #expect(neuve.duree == 5)
    }

    @Test func commencerApresMoinsDUneMinuteNInscritRien() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        try await b.seance.commencer(minutes: 20)
        b.horloge.avancer(secondes: 30)
        try await b.seance.commencer(minutes: 10)
        #expect(b.magasin.journal.record(jour) == nil)
        #expect(!b.magasin.reglages.hasPendingCelebration)
    }

    // MARK: Le sujet

    @Test func leSujetSInscritAvecLaJourneeEtResteChoisi() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        var reglages = Reglages()
        SeanceSujet.poser(.gratitude, dans: &reglages)
        let b = Self.banc(DateHeure(jour, heure: 10), reglages: reglages)
        #expect(b.seance.sujet == .gratitude)
        try await b.seance.commencer(minutes: 2)
        b.horloge.avancer(minutes: 2)
        try await b.seance.actualiser()
        #expect(b.magasin.journal.record(jour)?.themes == ["gratitude"])
        #expect(b.seance.sujet == .gratitude)
    }

    @Test func leSujetSeLitEtSEcritSousLaCleDAndroid() {
        var reglages = Reglages()
        #expect(SeanceSujet.lire(reglages) == nil)
        SeanceSujet.poser(.famille, dans: &reglages)
        #expect(reglages.brut["session_theme"] == .chaine("famille"))
        #expect(SeanceSujet.lire(reglages) == .famille)
        SeanceSujet.poser(nil, dans: &reglages)
        #expect(reglages.brut["session_theme"] == nil)
        let inconnu = Reglages(brut: ObjetJSON([("session_theme", .chaine("plus_tard"))]))
        #expect(SeanceSujet.lire(inconnu) == nil)
        let blanc = Reglages(brut: ObjetJSON([("session_theme", .chaine("  "))]))
        #expect(SeanceSujet.lire(blanc) == nil)
    }

    // MARK: Le texte de la Live Activity

    @Test func leTexteEnCoursSuitLeCompteur() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        try await b.seance.commencer(minutes: 20)
        b.horloge.avancer(secondes: 30)
        // 19 min 30 s restent : arrondies à la minute supérieure.
        #expect(b.seance.texteEnCours == Libelle("session_remaining", .libelle(Libelle("duration_minutes", .entier(20)))))
        #expect(b.seance.titreEnCours == Libelle("session_running_title"))

        try await b.seance.commencer(minutes: SessionRule.ouverte)
        b.horloge.avancer(minutes: 65)
        #expect(b.seance.texteEnCours == Libelle("session_elapsed", .libelle(Libelle("duration_hours_minutes",
                                                                                       .entier(1), .entier(5)))))
        try await b.magasin.modifierReglages { $0.setHideCountdown(true) }
        #expect(b.seance.compteur == .masque)
        #expect(b.seance.texteEnCours == Libelle("session_running_hidden"))
    }

    // MARK: Le son de fin

    @Test func leSonDeFinSonneAuTermeDUnDecompteMasque() async throws {
        var reglages = Reglages()
        reglages.setHideCountdown(true)
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10), reglages: reglages)
        try await b.seance.commencer(minutes: 1)
        b.horloge.avancer(minutes: 1, secondes: 1)
        try await b.seance.actualiser()
        let joues = await b.son.joues
        #expect(joues == [SeanceEnCours.sonDeFin])
    }

    @Test func leSonDeFinNeSonnePasSansDecompteMasque() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        try await b.seance.commencer(minutes: 1)
        b.horloge.avancer(minutes: 1)
        try await b.seance.actualiser()
        let joues = await b.son.joues
        #expect(joues.isEmpty)
    }

    @Test func leSonDeFinNeSonnePasAQuiArreteLuiMeme() async throws {
        var reglages = Reglages()
        reglages.setHideCountdown(true)
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10), reglages: reglages)
        try await b.seance.commencer(minutes: 10)
        b.horloge.avancer(minutes: 2)
        try await b.seance.terminer()
        let joues = await b.son.joues
        #expect(joues.isEmpty)
    }

    @Test func leSonDeFinNeSonnePasDesHeuresTropTard() async throws {
        var reglages = Reglages()
        reglages.setHideCountdown(true)
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10), reglages: reglages)
        try await b.seance.commencer(minutes: 10)
        b.horloge.avancer(heures: 1)
        try await b.seance.actualiser()
        let joues = await b.son.joues
        #expect(joues.isEmpty)
        #expect(b.magasin.journal.record(jour)?.minutes == 10)
    }

    // MARK: Les paliers et trophées notifiés

    @Test func uneSeanceInscriteRetientLesPaliersEtTropheesNotifies() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        #expect(b.magasin.reglages.paliersNotifies == nil)
        try await b.seance.commencer(minutes: 1)
        b.horloge.avancer(minutes: 1)
        try await b.seance.actualiser()
        #expect(b.magasin.reglages.paliersNotifies != nil)
        #expect(b.magasin.reglages.tropheesNotifies != nil)
    }

    /// Celebrations.notification : la toute première fois rien n'est fêté ; une fois les trophées regardés, le
    /// premier pas d'une séance inscrite programme « Mazal tov ! ».
    @Test func unTropheeNeufProgrammeMazalTov() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let horloge = SeanceHorlogeReglable(DateHeure(jour, heure: 10))

        let jamais = FauxNotificateur()
        let premiere = SeanceEnCours(magasin: Magasin.enMemoire(), horloge: horloge, notificateur: jamais)
        try await premiere.commencer(minutes: 1)
        horloge.avancer(minutes: 1)
        try await premiere.actualiser()
        let rien = await jamais.prevues
        #expect(rien.isEmpty)

        var reglages = Reglages()
        reglages.setTropheesNotifies([])
        let notificateur = FauxNotificateur()
        let seance = SeanceEnCours(magasin: Magasin.enMemoire(Enregistrement(reglages: reglages)), horloge: horloge,
                                   notificateur: notificateur)
        try await seance.commencer(minutes: 1)
        horloge.avancer(minutes: 1)
        try await seance.actualiser()
        let prevues = await notificateur.prevues
        let identifiants = prevues.map { $0.identifiant }
        #expect(identifiants == [SeanceEnCours.identifiantFete])
        #expect(prevues.first?.titre == Libelle("celebration_titre"))
        #expect(prevues.first?.instant == horloge.maintenant)
    }

    // MARK: Une écriture refusée

    @Test func uneEcritureRefuseeNArretePasLaSeance() async throws {
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = Self.banc(DateHeure(jour, heure: 10))
        await b.persistance.faireEchouer(true)
        // Comme MagasinTests : un do/catch plutôt que `#expect(throws:)` sur une fermeture qui capture le modèle.
        var refuse = false
        do {
            try await b.seance.commencer(minutes: 1)
        } catch is PersistanceEnMemoire.Echec {
            refuse = true
        }
        #expect(refuse)
        #expect(b.seance.enCours)
        #expect(b.seance.suivie)
        b.horloge.avancer(minutes: 1)
        refuse = false
        do {
            try await b.seance.actualiser()
        } catch is PersistanceEnMemoire.Echec {
            refuse = true
        }
        #expect(refuse)
        // Le changement se voit quand même, et ne se refait pas.
        #expect(b.magasin.journal.record(jour)?.minutes == 1)
        #expect(!b.seance.enregistree)
        await b.persistance.faireEchouer(false)
        try await b.seance.actualiser()
        #expect(b.magasin.journal.record(jour)?.minutes == 1)
    }
}
