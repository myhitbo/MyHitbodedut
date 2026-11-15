import Foundation
import Testing
import Coeur
@testable import Ecrans

/// L'écran des conseils (TipsActivity.kt) : le bandeau, les dix cartes dans l'ordre, leurs chaînes et leurs
/// images, qui suivent l'adresse. La table elle-même est jugée dans CoeurTests (TipsTests).
@Suite("Modèle des conseils")
@MainActor
struct ConseilsModeleTests {

    @Test func leBandeauPorteLeTitreEtLIndication() {
        let modele = ConseilsModele.apercu()
        #expect(modele.titre == Libelle("tips_title"))
        #expect(modele.indication == Libelle("tips_hint"))
    }

    @Test func lesDixConseilsDansLOrdre() {
        let lignes = ConseilsModele.apercu().lignes
        #expect(lignes.count == 10)
        let numeros = lignes.map { $0.numero }
        #expect(numeros == Array(1...10))
        // Le rang en chiffres ASCII, comme `number.toString()`, quelle que soit la langue.
        let textes = lignes.map { $0.numeroTexte }
        let attendus = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
        #expect(textes == attendus)
        for ligne in lignes {
            let titre = Libelle("tip_\(ligne.numero)_title")
            let corps = Libelle("tip_\(ligne.numero)_body")
            #expect(ligne.titre == titre)
            #expect(ligne.corps == corps)
        }
        let identifiants = lignes.map { $0.id }
        #expect(Set(identifiants).count == 10)
    }

    /// Sans choix, ou צדיק, les images de Tips.kt telles quelles.
    @Test func lesImagesDuHassidSansChoix() {
        let hassid = Tips.all.map { $0.art }
        let sansChoix = ConseilsModele.apercu().lignes.map { $0.illustration }
        #expect(sansChoix == hassid)
        let tsadik = ConseilsModele.apercu(adresse: .homme).lignes.map { $0.illustration }
        #expect(tsadik == hassid)
        #expect(sansChoix.first == "char_walking")
    }

    /// Pour צדקת, chaque image prend sa pose féminine (Personnage.pour).
    @Test func lesImagesSuiventTsadeket() {
        let feminines = Tips.all.map { Personnage.feminin($0.art) }
        let tsadeket = ConseilsModele.apercu(adresse: .femme).lignes.map { $0.illustration }
        #expect(tsadeket == feminines)
        #expect(tsadeket.first == "char_f_walking")
        let hassid = Tips.all.map { $0.art }
        for (feminine, pose) in zip(tsadeket, hassid) {
            #expect(feminine != pose, "« \(pose) » sans pose féminine")
        }
    }

    /// L'adresse est lue à chaque fois : un choix fait ailleurs (les réglages) change les images ici.
    @Test func unChoixFaitAilleursChangeLesImagesIci() async throws {
        let magasin = Magasin.enMemoire()
        let modele = ConseilsModele(magasin: magasin)
        #expect(modele.adresse == nil)
        let avant = modele.lignes[0].illustration
        #expect(avant == "char_walking")
        try await magasin.modifierReglages { $0.setAdresse(Adresse.femme.cle) }
        #expect(modele.adresse == Adresse.femme)
        let apres = modele.lignes[0].illustration
        #expect(apres == "char_f_walking")
    }

    @Test func lesChainesDesConseilsSontAuCatalogueDansLesTroisLangues() throws {
        let catalogue = try CatalogueBrut.lire()
        let modele = ConseilsModele.apercu()
        var cles = [modele.titre.cle, modele.indication.cle]
        for ligne in modele.lignes {
            cles += [ligne.titre.cle, ligne.corps.cle]
        }
        #expect(cles.count == 22)
        for cle in cles {
            for langue in Traducteur.langues {
                let valeur = catalogue.valeur(cle, langue: langue) ?? ""
                #expect(!valeur.isEmpty, "« \(cle) » manque en \(langue)")
            }
        }
    }

    @Test func lesImagesDesConseilsSontLivrees() throws {
        let dossier = Fichiers.racine.appendingPathComponent("ios/Ressources/Images")
        let fichiers = try FileManager.default.contentsOfDirectory(atPath: dossier.path)
        let noms = Set(fichiers.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent })
        for conseil in Tips.all {
            for nom in [conseil.art, Personnage.feminin(conseil.art)] {
                #expect(noms.contains(nom), "« \(nom) » n'est pas livrée")
            }
        }
    }
}
