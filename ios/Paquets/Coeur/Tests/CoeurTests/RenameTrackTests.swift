import Foundation
import Testing
@testable import Coeur

/// RenameTrackTest d'Android : renommer un morceau depuis l'application. Les cas qui lisent le gabarit
/// d'une ligne (item_track.xml), l'écran de la musique (MusicActivity.kt) ou le texte de MusicLibrary.kt
/// restent à Android (« le bouton et l'appui long ouvrent tous deux le renommage » entier, et la part
/// « gabarit » ou « code » des autres) ; ce qu'ils gardaient se vérifie ici par des valeurs : le nom donné
/// prime sur le titre livré, rien n'est pré-rempli tant qu'on n'a rien nommé, un nom vide efface
/// l'entrée, et les chaînes de l'écran existent dans les trois langues du catalogue.
@Suite("RenameTrack")
struct RenameTrackTests {

    private let livre = "hamelech_basade"

    private func titreLivre(_ id: String) -> MusicLibrary.Titre {
        let cle = MusiquePlay.morceaux.first { $0.id == id }?.titleRes ?? "?"
        return .libelle(Libelle(cle))
    }

    @Test func chaqueMorceauPorteUnBoutonDeRenommageVisible() throws {
        // Le bouton lui-même est dans le gabarit d'Android ; sa description pour l'accessibilité, ici.
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let texte = catalogue.simples(langue)["music_rename"] ?? ""
            #expect(!texte.blanc, "\(langue) : music_rename")
        }
    }

    @Test func leTitreLivreNEstPasRecopieDansLeChamp() {
        // Le champ reprend le nom déjà donné, ou rien : le titre livré n'est qu'une indication.
        var e = MusicLibrary.Etat()
        let avant = MusicLibrary.customName(e, id: livre)
        #expect(avant == nil)
        let indication = MusicLibrary.byId(e, livre)?.title
        let attendue = titreLivre(livre)
        #expect(indication == attendue)
        MusicLibrary.rename(&e, id: livre, title: "Mon niggoun")
        let apres = MusicLibrary.customName(e, id: livre)
        #expect(apres == "Mon niggoun")
    }

    @Test func onPeutRevenirAuTitreDOrigine() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let texte = catalogue.simples(langue)["music_rename_reset"] ?? ""
            #expect(!texte.blanc, "\(langue) : music_rename_reset")
        }
        // Un nom vide efface l'entrée, sinon le retour en arrière ne ferait rien.
        var e = MusicLibrary.Etat()
        MusicLibrary.rename(&e, id: livre, title: "Mon niggoun")
        MusicLibrary.rename(&e, id: livre, title: "")
        #expect(e.names == "{}")
        let nom = MusicLibrary.customName(e, id: livre)
        #expect(nom == nil)
        let titre = MusicLibrary.byId(e, livre)?.title
        let attendu = titreLivre(livre)
        #expect(titre == attendu)
        MusicLibrary.rename(&e, id: livre, title: "Mon niggoun")
        MusicLibrary.rename(&e, id: livre, title: "   ")
        #expect(e.names == "{}")
    }

    @Test func leRenommageVautAussiPourLesMorceauxLivres() {
        var e = MusicLibrary.Etat()
        MusicLibrary.rename(&e, id: livre, title: "Mon niggoun")
        let titre = MusicLibrary.byId(e, livre)?.title
        let attendu = MusicLibrary.Titre.nom("Mon niggoun")
        #expect(titre == attendu)
        let estLivre = MusicLibrary.byId(e, livre)?.isBundled
        #expect(estLivre == true)
    }

    @Test func lAideDeLEcranDitOuEstLeRenommageDansLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        let mots = [("fr", "crayon"), ("en", "pencil"), ("he", "העיפרון")]
        for (langue, mot) in mots {
            let ligne = catalogue.simples(langue)["music_library_hint"]
            let texte = try #require(ligne, "music_library_hint absent en \(langue)")
            #expect(texte.contient(mot), "l'aide en \(langue) ne désigne pas le bouton : « \(texte) »")
        }
    }
}
