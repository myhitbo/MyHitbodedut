import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Les onglets : l'ordre et les titres de la barre d'Android (res/menu/nav_main.xml, lu en place ; trois lieux
/// depuis la refonte du 13/11), des titres traduits dans toutes les langues du catalogue, une icône chacun, et
/// l'onglet du lancement tiré du réglage « ecran_ouverture » (Zmanim s'ouvre par-dessus le Jour).
@Suite("Onglets")
struct OngletsTests {

    @Test func lOrdreEtLesClesDeLaBarreDAndroid() throws {
        let onglets = Onglet.allCases
        #expect(onglets == [.aujourdhui, .textes, .chemin])
        let cles = onglets.map(\.cle)
        #expect(cles == ["nav_today", "nav_texts", "nav_chemin"])
        let octets = try Fichiers.donnees("android/app/src/main/res/menu/nav_main.xml")
        let menu = String(decoding: octets, as: UTF8.self)
        let identifiants = ExpressionReguliere(#"android:id="@\+id/([a-z_]+)""#).toutes(menu).map { $0.groupes[1] }
        // Le Chemin garde l'identifiant de l'ancien Journal.
        #expect(identifiants == ["nav_today", "nav_texts", "nav_journal"])
        let titres = ExpressionReguliere(#"android:title="@string/([a-z_]+)""#).toutes(menu).map { $0.groupes[1] }
        #expect(titres == cles)
    }

    @Test func chaqueTitreEstTraduitDansToutesLesLangues() throws {
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
        #expect(titres == ["היום", "ספרייה", "הדרך"])
    }

    @Test func uneIconeParOnglet() {
        let symboles = Onglet.allCases.map(\.symbole)
        #expect(symboles == ["house", "book.closed", "point.topleft.down.curvedto.point.bottomright.up"])
        let distincts = Set(symboles).count
        #expect(distincts == Onglet.allCases.count)
        let identifiants = Onglet.allCases.map(\.id)
        #expect(identifiants == ["aujourdhui", "textes", "chemin"])
    }

    @Test func lOngletDuLancementSuitLeReglage() throws {
        // Rien de réglé : Aujourd'hui (Store.ouverture).
        let parDefaut = Onglet.initial(Reglages())
        #expect(parDefaut == .aujourdhui)
        var reglages = Reglages()
        #expect(!Onglet.zmanimParDessus(Reglages()))
        let cas: [(Reglages.Ouverture, Onglet, Bool)] = [(.aujourdhui, .aujourdhui, false), (.textes, .textes, false),
                                                         (.zmanim, .aujourdhui, true)]
        for (ouverture, onglet, parDessus) in cas {
            reglages.setOuverture(ouverture)
            let initial = Onglet.initial(reglages)
            #expect(initial == onglet, "\(ouverture.rawValue)")
            let zmanim = Onglet.zmanimParDessus(reglages)
            #expect(zmanim == parDessus, "\(ouverture.rawValue)")
            // Le libellé du choix dans les réglages est le titre de l'onglet, ou celui des zmanim (Store.Ouverture).
            #expect(ouverture.libelle == (parDessus ? "nav_zmanim" : onglet.cle))
        }
        // Ouverte pour écrire la note d'une séance : la note d'abord, pas les zmanim (MainActivity.onCreate).
        let pourUneNote = Onglet.zmanimParDessus(reglages, pourUneNote: true)
        #expect(!pourUneNote)
        // Une valeur inconnue (d'une version future) : Aujourd'hui.
        let future = try Reglages(texte: #"{"ecran_ouverture":"calendrier"}"#)
        let inconnue = Onglet.initial(future)
        #expect(inconnue == .aujourdhui)
    }
}
