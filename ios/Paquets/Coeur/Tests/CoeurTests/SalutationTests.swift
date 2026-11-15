import Foundation
import Testing
@testable import Coeur

/// SalutationTest d'Android, porté : « Bonjour Avraham » à 3 h du matin (capture du 30/09), la salutation suit
/// l'heure ; le mot du moment (19/10). Les chaînes sont lues dans le catalogue exporté, où `%1$s` d'Android
/// s'écrit `%1$@` ; la vérification que `MainActivity.kt` et `AccueilMoment.kt` appellent la règle reste à Android.
@Suite("Salutation")
struct SalutationTests {

    @Test func bonjourLeJourBonsoirLeSoirEtLaNuit() {
        let cas: [(Int, Salutation.Partie)] = [
            (5, .matin), (11, .matin), (12, .apresMidi), (17, .apresMidi),
            (18, .soir), (22, .soir), (0, .soir), (3, .soir), (4, .soir),
        ]
        for (h, attendu) in cas {
            #expect(Salutation.partie(h) == attendu, "\(h) h")
        }
    }

    @Test func chaqueLangueNommeLesTroisMomentsEtLeFrancaisDitBonsoir() throws {
        let catalogue = try Catalogue.lire()
        let soirs = [("fr", "Bonsoir, %1$@"), ("en", "Good evening, %1$@"), ("he", "ערב טוב, %1$@")]
        for (langue, soir) in soirs {
            let chaines = catalogue.simples(langue)
            for cle in ["hero_greeting_morning", "hero_greeting_afternoon"] {
                #expect(chaines[cle] != nil, "\(langue) : \(cle) manque")
            }
            #expect(chaines["hero_greeting_evening"] == soir, "\(langue) : soir")
        }
        let francais = catalogue.simples("fr")
        for h in 0..<24 {
            #expect(francais[Salutation.chaine(h)] != nil, "\(h) h")
        }
    }

    /// Le mot du moment (proposition 7, 19/10) : matin, journée, soir, et la nuit.
    @Test func leMotDuMomentCouvreLesQuatreMoments() throws {
        #expect(Salutation.mot(5) == "moment_mot_matin")
        #expect(Salutation.mot(12) == "moment_mot_journee")
        #expect(Salutation.mot(18) == "moment_mot_soir")
        #expect(Salutation.mot(23) == "moment_mot_nuit")
        #expect(Salutation.mot(2) == "moment_mot_nuit")
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for h in 0..<24 { #expect(chaines[Salutation.mot(h)] != nil, "\(langue) : \(h) h") }
        }
    }
}
