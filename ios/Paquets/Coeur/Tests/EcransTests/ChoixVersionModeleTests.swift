import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le choix de la version (ChoixVersionActivity.kt) : quatre cartes, la version actuelle cochée, un choix retenu, et
/// le retour sans choix qui garde Classique au premier lancement. Sur iOS, un accueil pas encore porté le dit.
@Suite("Modèle du choix de la version")
@MainActor
struct ChoixVersionModeleTests {

    @Test func quatreCartesClassiqueCochee() {
        let m = ChoixVersionModele(magasin: Magasin.enMemoire())
        let versions = m.cartes.map(\.version)
        #expect(versions == [.classique, .serenite, .bento, .pile])
        let cochees = m.cartes.filter(\.choisie).map(\.version)
        #expect(cochees == [.classique])
        let portees = m.cartes.filter(\.portee).map(\.version)
        #expect(portees == [.classique])
        #expect(m.titre == Libelle("version_choix_titre"))
    }

    @Test func choisirRetientLaVersion() async throws {
        let magasin = Magasin.enMemoire()
        let m = ChoixVersionModele(magasin: magasin)
        try await m.choisir(.serenite)
        #expect(magasin.reglages.versionApp == .serenite)
        #expect(m.ferme)
        #expect(m.message == Libelle("ios_version_a_venir"))
        let cochees = m.cartes.filter(\.choisie).map(\.version)
        #expect(cochees == [.serenite])
        m.messageMontre()
        try await m.choisir(.classique)
        #expect(m.message == nil)
    }

    @Test func fermerSansChoisirGardeClassiqueUneFois() async throws {
        var r = Reglages()
        r.setOnboarded()
        let magasin = Magasin.enMemoire(Enregistrement(reglages: r))
        #expect(ChoixVersionModele.aProposer(magasin.reglages))
        let m = ChoixVersionModele(magasin: magasin)
        try await m.fermerSansChoisir()
        #expect(magasin.reglages.versionApp == .classique)
        #expect(!ChoixVersionModele.aProposer(magasin.reglages))
        // Une version déjà choisie n'est pas remplacée par un retour.
        try await magasin.modifierReglages { $0.setVersionApp(.pile) }
        try await ChoixVersionModele(magasin: magasin).fermerSansChoisir()
        #expect(magasin.reglages.versionApp == .pile)
    }

    /// La ligne des réglages nomme la version choisie et mène au choix.
    @Test func laLigneDesReglages() async throws {
        let m = ReglagesModele(apercu: Enregistrement())
        #expect(m.titreVersionApp == Libelle("settings_version"))
        #expect(m.versionApp == Libelle("version_classique"))
        #expect(m.routeVersionApp == .choixVersion)
    }
}
