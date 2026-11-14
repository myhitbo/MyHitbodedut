import Foundation
import Testing
@testable import Coeur

/// IlanotTest d'Android, porté : Birkat haIlanot (14/10, SiddurMoment.ilanot), en Nissan au nord, en
/// Eloul et Tichri au sud (sources dans moisIlanotSud). Rien n'y reste à Android. Puis les vecteurs de
/// la JVM (siddur_jour.json) : un jour sur deux de 2026 et 2027, huit latitudes, dont l'équateur et nil.
@Suite("Birkat haIlanot")
struct IlanotTests {

    private let jerusalem = 31.77
    private let melbourne = -37.81

    @Test func nissanAuNordPasAuSud() {
        let nissan = JourCivil.du("2027-04-10") // 3 Nissan 5787
        #expect(SiddurMoment.ilanot(nissan, latitude: jerusalem))
        #expect(SiddurMoment.ilanot(nissan, latitude: nil))
        #expect(!SiddurMoment.ilanot(nissan, latitude: melbourne))
    }

    @Test func eloulEtTichriAuSudPasAuNord() {
        let tichri = JourCivil.du("2026-09-20") // 9 Tichri 5787
        let eloul = JourCivil.du("2027-09-05") // Eloul 5787
        let hechvan = JourCivil.du("2026-10-25")
        #expect(SiddurMoment.ilanot(tichri, latitude: melbourne))
        #expect(SiddurMoment.ilanot(eloul, latitude: melbourne))
        #expect(!SiddurMoment.ilanot(hechvan, latitude: melbourne))
        #expect(!SiddurMoment.ilanot(tichri, latitude: jerusalem))
    }

    // MARK: Les vecteurs de la JVM (tools/vecteurs_ios/VecteursSiddurJour.kt)

    private struct Vecteurs: Decodable {
        struct Moment: Decodable {
            let latitudes: [Double?]
            /// La date, puis « V » ou « F » pour chaque latitude.
            let ilanot: [[String]]
            /// moisIlanotSud(0 … 14).
            let moisIlanotSud: [Bool]
        }

        let moment: Moment
    }

    @Test func unJourSurDeuxSurDeuxAnsEtHuitLatitudes() throws {
        let v = try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/siddur_jour.json"))
        let latitudes = v.moment.latitudes
        #expect(v.moment.ilanot.count == 365)
        var ecarts: [String] = []
        for ligne in v.moment.ilanot {
            let date = try #require(ligne.first), attendu = try #require(ligne.last)
            var lu = ""
            for latitude in latitudes { lu += SiddurMoment.ilanot(.du(date), latitude: latitude) ? "V" : "F" }
            if lu != attendu { ecarts.append("\(date) : \(lu) au lieu de \(attendu)") }
        }
        let rapport = ecarts.prefix(20).joined(separator: "\n    ")
        #expect(ecarts.isEmpty, "\(ecarts.count) jours diffèrent, dont\n    \(rapport)")
        let mois = (0...14).map { SiddurMoment.moisIlanotSud($0) }
        #expect(mois == v.moment.moisIlanotSud)
    }
}
