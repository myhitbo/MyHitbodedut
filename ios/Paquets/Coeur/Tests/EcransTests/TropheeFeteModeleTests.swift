import Foundation
import Testing
import Coeur
@testable import Ecrans

/// La fête de l'accueil (Celebrations.ecran et FicheTrophee.feter, Confettis.kt). Critère de la tâche 20 : avec
/// un journal forgé, un trophée neuf est fêté une fois à l'accueil, et rien n'est fêté au tout premier passage.
@Suite("Fête des trophées à l'accueil")
@MainActor
struct TropheeFeteModeleTests {

    /// Six jours de dix minutes, sans deux jours de suite ni vendredi : cinq « premiers pas », une séance de
    /// dix minutes, une heure en tout ; pas encore « 7 jours de pratique ».
    private static let sixJours: [(String, Int)] = [
        ("2026-11-01", 10), ("2026-11-03", 10), ("2026-11-05", 10),
        ("2026-11-08", 10), ("2026-11-10", 10), ("2026-11-12", 10),
    ]

    private func fabriquer(_ journal: Journal) throws -> (TropheeFeteModele, Magasin, PersistanceEnMemoire) {
        let enregistrement = Enregistrement(journal: journal)
        let persistance = PersistanceEnMemoire(enregistrement)
        let magasin = Magasin(persistance: persistance, enregistrement: enregistrement)
        let horloge = try PaliersModeleTests.horloge()
        return (TropheeFeteModele(magasin: magasin, horloge: horloge), magasin, persistance)
    }

    /// Une séance aujourd'hui (lundi 16 novembre 2026).
    private func seanceAujourdhui(_ magasin: Magasin, minutes: Int) async throws {
        let aujourdhui = try PaliersModeleTests.jour(PaliersModeleTests.aujourdhui)
        try await magasin.modifierJournal { $0.addSession(minutes: minutes, date: aujourdhui) }
    }

    @Test func rienNEstFeteAuToutPremierPassage() async throws {
        // Une installation qui a déjà de l'historique : dix jours, une vingtaine de trophées.
        let (fete, _, persistance) = try fabriquer(PaliersModeleTests.dixJours())
        try await fete.passer()
        #expect(fete.fiches.isEmpty)
        #expect(fete.ficheCourante == nil)
        #expect(fete.palier == nil)
        #expect(fete.etincelles == nil)
        // Ce qui est gagné est retenu : la prochaine fois, seul le neuf sera fêté.
        let reglages = await persistance.enregistrement.reglages
        let pratique = try PaliersModeleTests.pratique(PaliersModeleTests.dixJours())
        let gagnes = PaliersModeleTests.cles(pratique)
        #expect(reglages.tropheesVus == gagnes)
        let paliersVus = reglages.paliersVus
        #expect(paliersVus != nil)
    }

    @Test func unTropheeNeufEstFeteUneFois() async throws {
        let journal = try PaliersModeleTests.journal(Self.sixJours)
        let (fete, magasin, persistance) = try fabriquer(journal)
        try await fete.passer()
        #expect(fete.fiches.isEmpty)

        // Le septième jour : « 7 jours de pratique », et rien d'autre.
        try await seanceAujourdhui(magasin, minutes: 10)
        try await fete.passer()
        let jours = Trophees.Niveau(famille: .jours, rang: 1)
        let niveaux = fete.fiches.map { $0.niveau }
        #expect(niveaux == [jours])
        #expect(fete.palier == nil)
        let fiche = try #require(fete.ficheCourante)
        #expect(fiche.feter && fiche.confettis && fiche.gagne && fiche.retourner)
        let p = try PaliersModeleTests.pratique(magasin.journal)
        let faits = Trophees.chemin.filter { Trophees.gagne(p, $0) }
        let rang = try #require(faits.firstIndex(of: jours)) + 1
        #expect(fiche.rangGlobal == rang)
        #expect(fiche.metal == Trophees.grade(rang))
        let aujourdhui = try PaliersModeleTests.jour(PaliersModeleTests.aujourdhui)
        #expect(fiche.etat == .gagne(sous: .gagneLe(aujourdhui),
                                     grade: Libelle("trophee_detail_grade", .libelle(TropheeTextes.metal(Trophees.grade(rang))),
                                                    .entier(rang))))
        fete.fermerFiche()
        #expect(fete.ficheCourante == nil)

        // Une fois : ni au passage suivant, ni après un relancement.
        try await fete.passer()
        #expect(fete.fiches.isEmpty)
        let enregistrement = await persistance.enregistrement
        let horloge = try PaliersModeleTests.horloge()
        let relance = TropheeFeteModele(magasin: Magasin(persistance: persistance, enregistrement: enregistrement),
                                        horloge: horloge)
        try await relance.passer()
        #expect(relance.fiches.isEmpty)
        #expect(relance.palier == nil)
    }

    @Test func plusieursTropheesNeufsSOuvrentLUnApresLAutre() async throws {
        let journal = try PaliersModeleTests.journal(Self.sixJours)
        let (fete, magasin, _) = try fabriquer(journal)
        try await fete.passer()
        // Une longue séance aujourd'hui : le septième jour, et de plus longues séances.
        try await seanceAujourdhui(magasin, minutes: 45)
        try await fete.passer()
        let p = try PaliersModeleTests.pratique(magasin.journal)
        let pratiqueAvant = try PaliersModeleTests.pratique(PaliersModeleTests.journal(Self.sixJours))
        let avant = PaliersModeleTests.cles(pratiqueAvant)
        let attendus = Trophees.nouveaux(Trophees.gagnes(p), vus: avant)
        try #require(attendus.count >= 2)
        let niveaux = fete.fiches.map { $0.niveau }
        #expect(niveaux == attendus)
        // Une à une : chaque fermeture ouvre la suivante.
        for attendu in attendus {
            #expect(fete.ficheCourante?.niveau == attendu)
            fete.fermerFiche()
        }
        #expect(fete.ficheCourante == nil)
    }

    @Test func unPalierSeulFaitDesEtincellesDuGrade() async throws {
        // Une séance de 200 minutes et quatre d'une minute : tous les trophées de séance longue sont déjà là.
        let journal = try PaliersModeleTests.journal([
            ("2026-11-03", 200), ("2026-11-05", 1), ("2026-11-08", 1), ("2026-11-10", 1), ("2026-11-12", 1),
        ])
        let (fete, magasin, _) = try fabriquer(journal)
        try await fete.passer()
        #expect(fete.palier == nil)
        // Dix minutes aujourd'hui : le palier de 10 min du jour, sans trophée neuf.
        try await seanceAujourdhui(magasin, minutes: 10)
        try await fete.passer()
        #expect(fete.fiches.isEmpty)
        #expect(fete.palier == Libelle("palier_nouveau", .libelle(Libelle("palier_jour")),
                                       .libelle(Libelle("duration_minutes", .entier(10)))))
        let p = try PaliersModeleTests.pratique(magasin.journal)
        #expect(fete.etincelles == Trophees.grade(Trophees.gagnes(p).count))
        #expect(fete.fetesPalier == 1)
        fete.palierMontre()
        #expect(fete.palier == nil)
        // Le même palier ne revient pas.
        try await fete.passer()
        #expect(fete.palier == nil)
        #expect(fete.fetesPalier == 1)
    }

    @Test func ceQuiEstVuAuxPaliersNEstPasRefeteALAccueil() async throws {
        let journal = try PaliersModeleTests.journal(Self.sixJours)
        let (fete, magasin, _) = try fabriquer(journal)
        try await fete.passer()
        try await seanceAujourdhui(magasin, minutes: 10)
        // L'écran des paliers est ouvert avant l'accueil : il montre le neuf et le retient.
        let horloge = try PaliersModeleTests.horloge()
        let paliers = PaliersModele(magasin: magasin, horloge: horloge)
        try await paliers.ouvrir()
        let neufs = paliers.neufs
        #expect(neufs == ["jours:1"])
        try await fete.passer()
        #expect(fete.fiches.isEmpty)
        #expect(fete.palier == nil)
    }

    @Test func uneEcritureRefuseeLaisseLaFetePrete() async throws {
        let journal = try PaliersModeleTests.journal(Self.sixJours)
        let (fete, magasin, persistance) = try fabriquer(journal)
        try await fete.passer()
        try await seanceAujourdhui(magasin, minutes: 10)
        await persistance.faireEchouer(true)
        await #expect(throws: PersistanceEnMemoire.Echec()) { try await fete.passer() }
        #expect(fete.fiches.count == 1)
    }
}
