import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le choix de la version (ChoixVersionActivity.kt) : quatre cartes, la version actuelle cochée, un choix retenu, et
/// le retour sans choix qui garde Classique au premier lancement.
@Suite("Modèle du choix de la version")
@MainActor
struct ChoixVersionModeleTests {

    @Test func quatreCartesClassiqueCochee() {
        let m = ChoixVersionModele(magasin: Magasin.enMemoire())
        let versions = m.cartes.map(\.version)
        #expect(versions == [.classique, .serenite, .bento, .pile])
        let cochees = m.cartes.filter(\.choisie).map(\.version)
        #expect(cochees == [.classique])
        let apercus = m.cartes.map(\.apercu)
        #expect(apercus == VersionApp.allCases.map(\.apercu))
        #expect(m.titre == Libelle("version_choix_titre"))
    }

    @Test func choisirRetientLaVersion() async throws {
        let magasin = Magasin.enMemoire()
        let m = ChoixVersionModele(magasin: magasin)
        try await m.choisir(.serenite)
        #expect(magasin.reglages.versionApp == .serenite)
        #expect(m.ferme)
        // Les quatre accueils sont portés : l'app montre aussitôt celui qui est choisi.
        #expect(VersionApp.accueil(magasin.reglages) == .serenite)
        let cochees = m.cartes.filter(\.choisie).map(\.version)
        #expect(cochees == [.serenite])
        try await m.choisir(.classique)
        #expect(VersionApp.accueil(magasin.reglages) == .classique)
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

    /// MainActivity.onResume : au retour de la présentation, ou à la première ouverture après la mise à jour, l'accueil
    /// propose le choix de la version, une fois, tant qu'aucune n'est retenue ; jamais avant la présentation.
    @Test func lAccueilProposeLeChoixApresLaPresentation() async throws {
        let magasin = Magasin.enMemoire()
        let jour = try #require(JourCivil(iso: "2026-11-16"))
        let accueil = AccueilModele(magasin: magasin, contenus: ContenusApp(dossier: Fichiers.contenu),
                                    horloge: HorlogeFixe(DateHeure(jour, heure: 10), fuseau: .utc), langue: "fr",
                                    barriere: false, melange: { $0 })
        await accueil.apparaitre()
        #expect(accueil.routes == [.presentation])
        accueil.routeOuverte()
        // La présentation vue : le choix, une fois, même si l'accueil repasse avant qu'il soit fait.
        try await magasin.modifierReglages { $0.setOnboarded() }
        await accueil.apparaitre()
        await accueil.apparaitre()
        #expect(accueil.routes == [.choixVersion])
        accueil.routeOuverte()
        // Revenir sans choisir garde Classique : la question ne revient plus.
        try await ChoixVersionModele(magasin: magasin).fermerSansChoisir()
        await accueil.apparaitre()
        #expect(accueil.routes.isEmpty)
        // Tout recommencer efface la version : après la présentation, le choix revient.
        try await magasin.modifierReglages { $0 = Reglages() }
        try await magasin.modifierReglages { $0.setOnboarded() }
        await accueil.apparaitre()
        #expect(accueil.routes == [.choixVersion])
    }

    /// La ligne des réglages nomme la version choisie et mène au choix.
    @Test func laLigneDesReglages() async throws {
        let m = ReglagesModele(apercu: Enregistrement())
        #expect(m.titreVersionApp == Libelle("settings_version"))
        #expect(m.versionApp == Libelle("version_classique"))
        #expect(m.routeVersionApp == .choixVersion)
    }
}
