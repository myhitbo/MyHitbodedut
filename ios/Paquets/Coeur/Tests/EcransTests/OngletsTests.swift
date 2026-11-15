import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Les onglets : l'ordre et les titres de la barre d'Android (res/menu/nav_main.xml, lu en place), des titres
/// traduits dans les trois langues du catalogue, une icône chacun, et l'onglet du lancement tiré du réglage
/// « ecran_ouverture ».
@Suite("Onglets")
struct OngletsTests {

    @Test func lOrdreEtLesClesDeLaBarreDAndroid() throws {
        let onglets = Onglet.allCases
        #expect(onglets == [.aujourdhui, .textes, .zmanim, .journal, .reglages])
        let cles = onglets.map(\.cle)
        #expect(cles == ["nav_today", "nav_texts", "nav_zmanim", "nav_journal", "settings_title"])
        let octets = try Fichiers.donnees("android/app/src/main/res/menu/nav_main.xml")
        let menu = String(decoding: octets, as: UTF8.self)
        let identifiants = ExpressionReguliere(#"android:id="@\+id/([a-z_]+)""#).toutes(menu).map { $0.groupes[1] }
        #expect(identifiants == ["nav_today", "nav_texts", "nav_zmanim", "nav_journal", "nav_settings"])
        let titres = ExpressionReguliere(#"android:title="@string/([a-z_]+)""#).toutes(menu).map { $0.groupes[1] }
        #expect(titres == cles)
    }

    @Test func chaqueTitreEstTraduitDansLesTroisLangues() throws {
        let catalogue = try CatalogueBrut.lire()
        for onglet in Onglet.allCases {
            for langue in Traducteur.langues {
                let titre = catalogue.valeur(onglet.cle, langue: langue)
                let vide = titre?.isEmpty ?? true
                #expect(!vide, "\(onglet.cle) sans titre en \(langue)")
            }
        }
        let octets = try Fichiers.catalogue()
        let hebreu = try Traducteur(catalogue: octets, langue: "he")
        let titres = Onglet.allCases.map { hebreu.texte(cle: $0.cle) }
        #expect(titres == ["היום", "ספרייה", "זמנים", "יומן", "הגדרות"])
    }

    @Test func uneIconeParOnglet() {
        let symboles = Onglet.allCases.map(\.symbole)
        #expect(symboles == ["house", "book.closed", "clock", "pencil.line", "slider.horizontal.3"])
        let distincts = Set(symboles).count
        #expect(distincts == Onglet.allCases.count)
        let identifiants = Onglet.allCases.map(\.id)
        #expect(identifiants == ["aujourdhui", "textes", "zmanim", "journal", "reglages"])
    }

    @Test func lOngletDuLancementSuitLeReglage() throws {
        // Rien de réglé : Aujourd'hui (Store.ouverture).
        let parDefaut = Onglet.initial(Reglages())
        #expect(parDefaut == .aujourdhui)
        var reglages = Reglages()
        let cas: [(Reglages.Ouverture, Onglet)] = [(.aujourdhui, .aujourdhui), (.textes, .textes), (.zmanim, .zmanim)]
        for (ouverture, onglet) in cas {
            reglages.setOuverture(ouverture)
            let initial = Onglet.initial(reglages)
            #expect(initial == onglet, "\(ouverture.rawValue)")
            // Le libellé du choix dans les réglages est le titre de l'onglet.
            #expect(ouverture.libelle == onglet.cle)
        }
        // Une valeur inconnue (d'une version future) : Aujourd'hui.
        let future = try Reglages(texte: #"{"ecran_ouverture":"calendrier"}"#)
        let inconnue = Onglet.initial(future)
        #expect(inconnue == .aujourdhui)
    }
}
