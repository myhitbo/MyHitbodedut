import Foundation
import Testing
@testable import Coeur

/// PlaqueTest d'Android, porté : un toucher fait tourner la plaque du centre des anneaux (04/10) et montre vos
/// chiffres, face après face, puis revient au hassid. Le test de l'accueil qui lit `MainActivity.kt` et son layout
/// reste à Android ; les libellés des faces sont cherchés dans le catalogue exporté.
@Suite("Plaque")
struct PlaqueTests {

    @Test func lesFacesSeSuiventEtReviennentAuHassid() {
        var face = Plaque.Face.hassid
        var vues: [Plaque.Face] = []
        for _ in Plaque.Face.allCases {
            face = Plaque.suivante(face)
            vues.append(face)
        }
        #expect(vues.last == .hassid)
        #expect(Set(vues) == Set(Plaque.Face.allCases))
        #expect(vues.first == .jour)
    }

    @Test func chaqueAnneauASaFace() {
        for quel in Anneaux.Quel.allCases {
            #expect(Plaque.pour(quel).anneau == quel)
        }
        #expect(Plaque.pour(.serie) == .serie)
        #expect(Plaque.Face.total.anneau == nil)
    }

    @Test func laMoyenneDUnJourDePratique() {
        #expect(Plaque.moyenne(totalMinutes: 0, jours: 0) == 0)
        #expect(Plaque.moyenne(totalMinutes: 50, jours: 3) == 17)
        #expect(Plaque.moyenne(totalMinutes: 200, jours: 10) == 20)
    }

    private let lundi = JourCivil.du("2026-09-28")

    @Test func laMeilleureSerieNeCassePasSurUnJourExempte() {
        // Lundi à mercredi faits, jeudi exempté, vendredi fait, samedi manqué, dimanche fait.
        let faits = Set([0, 1, 2, 4, 6].map { lundi.plus(jours: $0) })
        let jeudi = lundi.plus(jours: 3)
        let avecJeudi = Plaque.meilleureSerie(faits) { $0 == jeudi }
        #expect(avecJeudi == 4)
        let sansExemption = Plaque.meilleureSerie(faits) { _ in false }
        #expect(sansExemption == 3)
        let aucun = Plaque.meilleureSerie([]) { _ in false }
        #expect(aucun == 0)
        let un = Plaque.meilleureSerie([lundi]) { _ in false }
        #expect(un == 1)
    }

    @Test func lesFacesParlentLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        let cles = ["plaque_jour", "plaque_semaine", "plaque_meilleure", "plaque_total", "plaque_moyenne", "plaque_serie",
                    "plaque_jours"]
        for langue in Catalogue.langues {
            // « plaque_serie » et « plaque_jours » sont des pluriels (<plurals> d'Android).
            let chaines = catalogue.simples(langue)
            let pluriels = catalogue.pluriels(langue)
            for cle in cles {
                let present = chaines[cle] != nil || pluriels["\(cle)[other]"] != nil
                #expect(present, "\(langue) : \(cle)")
            }
        }
    }
}
