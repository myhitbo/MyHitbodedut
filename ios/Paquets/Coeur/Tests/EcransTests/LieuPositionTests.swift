import Foundation
import Testing
import Coeur
@testable import Ecrans

/// La position gardée (ChoixLieu.kt) : arrondie au kilomètre (PositionSol, examen du 14/11) ; faute de position
/// fraîche, la dernière connue, dite (ChoixLieu.ancienne), sauf, sans bruit, une position vieille de plus de deux
/// heures quand le lieu est périmé par un changement de fuseau (02/11).
@Suite("Choix du lieu : la position gardée")
@MainActor
struct LieuPositionTests {

    private func fabriquer(_ reglages: Reglages = Reglages(), reponse: ReponseLocalisation) throws
        -> (LieuModele, Magasin) {
        let jour = try #require(JourCivil(iso: "2026-10-12"))
        let telephone = try #require(Fuseau("Asia/Jerusalem"))
        let horloge = HorlogeFixe(DateHeure(jour, heure: 12), fuseau: telephone)
        let magasin = Magasin.enMemoire(Enregistrement(reglages: reglages))
        let modele = LieuModele(magasin: magasin, contenus: ZmanimEssais.contenus, localisation: FausseLocalisation(reponse),
                                autorisation: LieuAutorisationFausse(permise: true), horloge: horloge,
                                traducteur: try ZmanimEssais.traducteur())
        return (modele, magasin)
    }

    /// Un lieu « Ma position » pris à Paris, dans le fuseau de Paris : périmé pour un téléphone à Jérusalem.
    private func perime() -> Reglages {
        var reglages = Reglages()
        let quitte = Zmanim.Lieu(nom: "Ma position", latitude: 48.86, longitude: 2.35, fuseau: "Europe/Paris")
        reglages.setLieuZmanim(quitte, ville: nil, maintenant: 0)
        return reglages
    }

    @Test func auKilometrePres() async throws {
        #expect(PositionSol.arrondie(31.78456) == 31.78)
        #expect(PositionSol.arrondie(35.2051) == 35.21)
        #expect(PositionSol.arrondie(-0.125) == -0.12)
        let (modele, magasin) = try fabriquer(reponse: .position(PositionApprochee(latitude: 31.78456, longitude: 35.2049)))
        try await modele.maPosition()
        let lieu = try #require(magasin.reglages.lieuZmanim)
        #expect(lieu.latitude == 31.78)
        #expect(lieu.longitude == 35.20)
    }

    @Test func laDerniereConnueEstDite() async throws {
        let position = PositionApprochee(latitude: 31.78, longitude: 35.20)
        let (modele, magasin) = try fabriquer(reponse: .ancienne(position, age: 5 * 3_600_000))
        try await modele.maPosition()
        #expect(modele.message == .ancienne)
        #expect(modele.message?.long == true)
        #expect(modele.message?.libelle == Libelle("zmanim_position_ancienne"))
        let nom = magasin.reglages.lieuZmanim?.nom
        #expect(nom == "Ma position · près de Jérusalem")
    }

    @Test func sansBruitUneVieillePositionNeRemplacePasUnLieuPerime() async throws {
        let position = PositionApprochee(latitude: 31.78, longitude: 35.20)
        let (vieille, magasin) = try fabriquer(perime(), reponse: .ancienne(position, age: 3 * 3_600_000))
        try await vieille.rafraichir()
        #expect(vieille.message == nil)
        #expect(magasin.reglages.lieuZmanim?.nom == "Ma position")
        // Une position connue d'une heure, elle, le remplace, sans rien dire.
        let (recente, autre) = try fabriquer(perime(), reponse: .ancienne(position, age: 3_600_000))
        try await recente.rafraichir()
        #expect(recente.message == nil)
        #expect(autre.reglages.lieuZmanim?.nom == "Ma position · près de Jérusalem")
    }
}
