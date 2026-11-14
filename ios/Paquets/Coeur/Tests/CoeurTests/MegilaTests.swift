import Foundation
import Testing
@testable import Coeur

/// MegilaTest d'Android, porté : la Méguila d'Esther dans le siddour (13/10, SiddurMoment.megila),
/// sous Arvit la nuit qui ouvre Pourim, sous Cha'harit le jour ; le 15 Adar dans une ville murée, le
/// vendredi 14 quand le 15 est un Chabbat (Pourim mechoulach, 5785). Rien n'y reste à Android. Puis
/// les vecteurs de la JVM (siddur_jour.json) : six années autour de Pourim, dont deux mechoulach.
@Suite("Méguila")
struct MegilaTests {

    private func megila(_ moment: String, _ date: String, _ muree: Bool) -> Bool {
        SiddurMoment.megila(moment, aujourdhui: .du(date), israel: false, mukafChoma: muree)
    }

    @Test func villeOuverte14AdarII5787() {
        #expect(megila("arvit", "2027-03-22", false))
        #expect(megila("chaharit", "2027-03-23", false))
        #expect(!megila("minha", "2027-03-23", false))
        #expect(!megila("chaharit", "2027-03-24", false))
        #expect(!megila("arvit", "2027-03-23", false))
    }

    @Test func villeMuree15AdarII5787() {
        #expect(!megila("chaharit", "2027-03-23", true))
        #expect(megila("arvit", "2027-03-23", true))
        #expect(megila("chaharit", "2027-03-24", true))
    }

    @Test func pourimMechoulach5785VilleMureeLeVendredi14() {
        #expect(megila("arvit", "2025-03-13", true))
        #expect(megila("chaharit", "2025-03-14", true))
        #expect(!megila("chaharit", "2025-03-15", true))
        #expect(megila("chaharit", "2025-03-14", false))
    }

    // MARK: Les vecteurs de la JVM (tools/vecteurs_ios/VecteursSiddurJour.kt)

    private struct Vecteurs: Decodable {
        struct Moment: Decodable {
            struct Jour: Decodable {
                let date: String
                /// Pour chaque moment, puis Israël (faux, vrai), puis ville murée (faux, vrai).
                let reponses: [Bool]
            }

            let moments: [String?]
            let megila: [Jour]
        }

        let moment: Moment
    }

    @Test func autourDePourimSixAnnees() throws {
        let v = try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/siddur_jour.json"))
        #expect(v.moment.megila.count == 42)
        var ecarts: [String] = []
        for jour in v.moment.megila {
            var lues: [Bool] = []
            for m in v.moment.moments {
                for israel in [false, true] {
                    for muree in [false, true] {
                        lues.append(SiddurMoment.megila(m, aujourdhui: .du(jour.date), israel: israel, mukafChoma: muree))
                    }
                }
            }
            if lues != jour.reponses { ecarts.append("\(jour.date) : \(lues) au lieu de \(jour.reponses)") }
        }
        let rapport = ecarts.joined(separator: "\n    ")
        #expect(ecarts.isEmpty, "\(ecarts.count) jours diffèrent :\n    \(rapport)")
    }
}
