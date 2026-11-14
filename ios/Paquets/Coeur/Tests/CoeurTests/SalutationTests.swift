import Foundation
import Testing
@testable import Coeur

/// SalutationTest d'Android, porté (« Bonjour Avraham » à 3 h du matin, capture du 30/09 : la
/// salutation suit l'heure), puis la part de Salutation.kt dans `Tests/Vecteurs/guidee.json`. Les
/// chaînes se lisent dans le catalogue exporté, où le « %1$s » d'Android s'écrit « %1$@ » ; les
/// attendus sont recopiés de SalutationTest.kt par programme. Restent à Android les deux lectures du
/// code de ses écrans (Salutation.chaine dans MainActivity.kt, Salutation.mot dans AccueilMoment.kt).
@Suite("Salutation")
struct SalutationTests {

    private struct Vecteurs: Decodable {
        struct Heure: Decodable {
            let heure: Int
            /// Le nom du membre de Salutation.Partie en Kotlin.
            let partie: String
            let mot: String
            let chaine: String
        }

        let heures: [Heure]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/guidee.json"))
    }

    /// Les membres de Salutation.Partie, par leur nom en Kotlin.
    private static let parties: [String: Salutation.Partie] = [
        "MATIN": .matin,
        "APRES_MIDI": .apresMidi,
        "SOIR": .soir,
    ]

    @Test func bonjourLeJourBonsoirLeSoirEtLaNuit() {
        let cas: [(heure: Int, partie: Salutation.Partie)] = [
            (5, .matin), (11, .matin),
            (12, .apresMidi), (17, .apresMidi),
            (18, .soir), (22, .soir),
            (0, .soir), (3, .soir), (4, .soir),
        ]
        for (heure, attendue) in cas {
            let partie = Salutation.partie(heure)
            #expect(partie == attendue, "\(heure) h")
        }
    }

    @Test func chaqueLangueNommeLesTroisMomentsEtLeFrancaisDitBonsoir() throws {
        let soirs: [(langue: String, soir: String)] = [
            ("fr", "Bonsoir, %1$@"),
            ("en", "Good evening, %1$@"),
            ("he", "ערב טוב, %1$@"),
        ]
        let catalogue = try Catalogue.lire()
        for (langue, soir) in soirs {
            let chaines = catalogue.simples(langue)
            for cle in ["hero_greeting_morning", "hero_greeting_afternoon"] {
                let presente = chaines[cle] != nil
                #expect(presente, "\(langue) : \(cle) manque")
            }
            let ecrit = chaines["hero_greeting_evening"] ?? ""
            let identique = ecrit.egalUnites(soir)
            #expect(identique, "\(langue) : soir, « \(ecrit) »")
        }
        // Le soir de l'accueil est bien la chaîne que le test vient de lire.
        let soir = Salutation.chaine(20)
        #expect(soir == "hero_greeting_evening")
    }

    /// Le mot du moment (proposition 7, 19/10) : matin, journée, soir, et la nuit.
    @Test func leMotDuMomentCouvreLesQuatreMoments() {
        let cas: [(heure: Int, mot: String)] = [
            (5, "moment_mot_matin"),
            (12, "moment_mot_journee"),
            (18, "moment_mot_soir"),
            (23, "moment_mot_nuit"),
            (2, "moment_mot_nuit"),
        ]
        for (heure, attendu) in cas {
            let mot = Salutation.mot(heure)
            #expect(mot == attendu, "\(heure) h")
        }
    }

    /// Chaque clé que la salutation nomme, à toute heure, existe dans les trois langues.
    @Test func chaqueCleNommeeExisteDansLesTroisLangues() throws {
        var cles = Set<String>()
        for heure in 0..<24 {
            cles.insert(Salutation.mot(heure))
            cles.insert(Salutation.chaine(heure))
        }
        let nombre = cles.count
        #expect(nombre == 7)
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for cle in cles.sorted() {
                let presente = chaines[cle] != nil
                #expect(presente, "\(langue) : « \(cle) » manquant")
            }
        }
    }

    @Test func lesVecteursDeLaJVMSontRejoues() throws {
        let v = try vecteurs()
        for h in v.heures {
            let attendue = try #require(Self.parties[h.partie], "partie inconnue : \(h.partie)")
            let partie = Salutation.partie(h.heure)
            let mot = Salutation.mot(h.heure)
            let chaine = Salutation.chaine(h.heure)
            #expect(partie == attendue, "\(h.heure) h : partie")
            #expect(mot == h.mot, "\(h.heure) h : mot")
            #expect(chaine == h.chaine, "\(h.heure) h : chaîne")
        }
    }
}
