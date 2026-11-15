import Foundation
import Testing
@testable import Coeur

/// ChabbatAlerteTest d'Android, porté : « Chabbat dans 3 h » (13/10), trois heures avant l'allumage du vendredi qui
/// vient. Le message est cherché dans le catalogue exporté plutôt que dans les strings.xml d'Android.
@Suite("ChabbatAlerte")
struct ChabbatAlerteTests {

    private func zone() throws -> Fuseau { try #require(Fuseau("Asia/Jerusalem")) }

    private func le(_ iso: String, _ h: Int, _ m: Int, _ fuseau: Fuseau) -> DateHeureZonee {
        DateHeureZonee(DateHeure(JourCivil.du(iso), heure: h, minute: m), fuseau: fuseau)
    }

    @Test func leMardiLAlerteEstVendrediTroisHeuresAvantLAllumage() throws {
        let z = try zone()
        let allumage = { (d: JourCivil) -> DateHeureZonee? in DateHeureZonee(DateHeure(d, heure: 17, minute: 45), fuseau: z) }
        let alerte = ChabbatAlerte.prochaine(le("2026-10-13", 9, 0, z), allumage: allumage)
        #expect(alerte == le("2026-10-16", 14, 45, z))
    }

    @Test func leVendrediAvantLAlerteCEstCeVendrediApresLeSuivant() throws {
        let z = try zone()
        let allumage = { (d: JourCivil) -> DateHeureZonee? in DateHeureZonee(DateHeure(d, heure: 17, minute: 45), fuseau: z) }
        let avant = ChabbatAlerte.prochaine(le("2026-10-16", 10, 0, z), allumage: allumage)
        #expect(avant == le("2026-10-16", 14, 45, z))
        let apres = ChabbatAlerte.prochaine(le("2026-10-16", 15, 0, z), allumage: allumage)
        #expect(apres == le("2026-10-23", 14, 45, z))
    }

    @Test func sansHeureDAllumageRienNEstProgramme() throws {
        let z = try zone()
        let alerte = ChabbatAlerte.prochaine(le("2026-10-13", 9, 0, z)) { _ in nil }
        #expect(alerte == nil)
    }

    @Test func leMessageEstDansLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for cle in ["chabbat_alerte_titre", "chabbat_alerte_texte"] {
                #expect(chaines[cle] != nil, "\(langue) : \(cle)")
            }
        }
    }
}
