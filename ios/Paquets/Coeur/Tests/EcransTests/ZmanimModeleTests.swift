import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le modèle de l'onglet Zmanim s'en tient à ce que rendent les règles de Coeur. C'est aussi la
/// preuve que les modèles d'écran (Observation, acteur principal) se construisent et se testent sous Linux.
@Suite("Modèle de l'onglet Zmanim")
@MainActor
struct ZmanimModeleTests {

    private let jerusalem = Zmanim.Lieu(nom: "Jérusalem", latitude: 31.76904, longitude: 35.21633, fuseau: "Asia/Jerusalem")

    @Test func sansLieuAucunHoraire() throws {
        let jour = try #require(JourCivil(iso: "2026-11-13"))
        let modele = ZmanimModele(lieu: nil, jour: jour, enIsrael: true)
        let horaires = modele.horaires
        #expect(horaires.isEmpty)
    }

    @Test func lesHorairesSontCeuxDeJourAffiche() throws {
        let vendredi = try #require(JourCivil(iso: "2026-11-13"))
        let modele = ZmanimModele(lieu: jerusalem, jour: vendredi, enIsrael: true)
        let obtenus = modele.horaires.map { $0.cle }
        let attendus = JourAffiche.horaires(lieu: jerusalem, date: vendredi, enIsrael: true,
                                            minutes: Zmanim.allumageDefaut).map { $0.cle }
        #expect(obtenus == attendus)
        // Un vendredi, l'allumage s'ajoute aux quinze zmanim du profil.
        let allumage = obtenus.contains("allumage")
        #expect(allumage)
        #expect(obtenus.count == Zmanim.profil.count + 1)
    }

    @Test func leJourAvanceEtRecule() throws {
        let jour = try #require(JourCivil(iso: "2026-12-31"))
        let modele = ZmanimModele(lieu: jerusalem, jour: jour, enIsrael: false)
        modele.jourSuivant()
        #expect(modele.jour.iso == "2027-01-01")
        modele.jourPrecedent()
        modele.jourPrecedent()
        #expect(modele.jour.iso == "2026-12-30")
        let hebreu = modele.jourHebreu
        #expect(hebreu.date == modele.jour)
    }
}
