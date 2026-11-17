import Foundation
import Testing
@testable import Coeur

/// Le choix de la langue (LanguesTest.kt), et `Tests/Vecteurs/interface_a.json` rejoué. Restent à Android le
/// câblage du bouton des réglages (SettingsActivity), le service qui garde le choix sous Android 13 et la
/// déclaration des langues au système (manifeste, locales_config.xml) : sur iOS, la langue de l'app se choisit
/// dans les Réglages du système (PORTAGE.md § 2.2.7). « Un téléphone dont aucune langue n'est livrée passe en
/// anglais » éprouve LangueApp.repli (Langue.kt, une autre grappe) et le code du lancement : sur iOS, ce repli
/// est natif (région de développement « en », PORTAGE.md).
@Suite("Langues")
struct LanguesTests {

    private struct Vecteurs: Decodable {
        struct Lue: Decodable {
            let etiquette: String
            let nom: String
        }
        struct Normalisation: Decodable {
            let etiquette: String?
            let normalise: String
            let nomDe: String
            let indexDe: Int
        }

        let languesToutes: [Lue]
        let languesDefaut: String
        let langues: [Normalisation]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/interface_a.json"))
    }

    /// עברית, English, Français ; puis, depuis le 17/11, l'espagnol et l'arabe tunisien (Langues.kt).
    @Test func lesCinqLanguesSontOffertesDansLOrdreDemande() {
        let etiquettes = Langues.toutes.map { $0.etiquette }
        let noms = Langues.toutes.map { $0.nom }
        #expect(etiquettes == ["iw", "en", "fr", "es", "ar-TN"])
        #expect(noms == ["עברית", "English", "Français", "Español", "تونسي"])
    }

    @Test func chaqueLangueEstNommeeDansSaPropreLangue() {
        // « Hébreu » écrit en français ne se lit pas par qui cherche l'hébreu.
        let hebreu = Langues.nomDe("iw")
        let anglais = Langues.nomDe("en")
        let francais = Langues.nomDe("fr")
        #expect(hebreu == "עברית")
        #expect(anglais == "English")
        #expect(francais == "Français")
    }

    @Test func heEtIwDesignentLaMemeLangue() {
        // « he » est le code actuel, « iw » celui qu'Android rend encore. Les confondre afficherait le
        // français à qui a choisi l'hébreu.
        let he = Langues.normalise("he")
        let iw = Langues.normalise("iw")
        let heIL = Langues.normalise("he-IL")
        let iwIL = Langues.normalise("iw_IL")
        let index = Langues.indexDe("he")
        #expect(he == "iw")
        #expect(iw == "iw")
        #expect(heIL == "iw")
        #expect(iwIL == "iw")
        #expect(index == 0)
    }

    @Test func uneEtiquetteRegionaleOuInconnueNeFaitPasDeraillerLeChoix() {
        let frCA = Langues.normalise("fr-CA")
        let enUS = Langues.normalise("en-US")
        let de = Langues.normalise("de")
        let nul = Langues.normalise(nil)
        let vide = Langues.normalise("")
        let index = Langues.indexDe("de")
        let dansLaListe = Langues.toutes.indices.contains(index)
        #expect(frCA == "fr")
        #expect(enUS == "en")
        #expect(de == Langues.defaut)
        #expect(nul == Langues.defaut)
        #expect(vide == Langues.defaut)
        #expect(dansLaListe, "un index hors liste ferait planter la liste de choix")
    }

    /// Chaque langue offerte a ses chaînes : sur iOS, dans le catalogue exporté, où l'hébreu se nomme « he »
    /// et non « iw » comme le dossier values-iw d'Android, et l'arabe tunisien « ar » (values-ar-rTN).
    @Test func chaqueLangueOfferteASonDossierDeRessources() throws {
        let catalogue = try Catalogue.lire()
        for langue in Langues.toutes {
            let code = langue.etiquette == "iw" ? "he" : langue.etiquette.avantUnites("-")
            let n = catalogue.simples(code).count
            #expect(n > 0, "on propose « \(langue.nom) » sans livrer ses chaînes (\(code))")
        }
    }

    /// Les langues, entrée par entrée et unité par unité, dans l'ordre d'Android.
    @Test func lesLanguesSontCellesDAndroid() throws {
        let v = try vecteurs()
        let n = Langues.toutes.count
        let lues = v.languesToutes.count
        let defaut = Langues.defaut
        #expect(n == lues, "nombre de langues")
        #expect(defaut == v.languesDefaut)
        for (ici, lue) in zip(Langues.toutes, v.languesToutes) {
            let etiquette = ici.etiquette.egalUnites(lue.etiquette)
            let nom = ici.nom.egalUnites(lue.nom)
            #expect(etiquette, "\(lue.etiquette)")
            #expect(nom, "\(lue.etiquette) : \(lue.nom)")
        }
    }

    /// Des étiquettes de toutes formes (régionales, en capitales, vides, nil, inconnues, hors ASCII), comme
    /// Android les ramène.
    @Test func chaqueEtiquetteSeRameneCommeSurAndroid() throws {
        let v = try vecteurs()
        let n = v.langues.count
        #expect(n > 50, "étiquettes lues")
        for c in v.langues {
            let contexte = c.etiquette.map { "« \($0) »" } ?? "nil"
            let normalise = Langues.normalise(c.etiquette)
            let nom = Langues.nomDe(c.etiquette)
            let index = Langues.indexDe(c.etiquette)
            #expect(normalise == c.normalise, "\(contexte) : normalise")
            #expect(nom == c.nomDe, "\(contexte) : nomDe")
            #expect(index == c.indexDe, "\(contexte) : indexDe")
        }
    }
}
