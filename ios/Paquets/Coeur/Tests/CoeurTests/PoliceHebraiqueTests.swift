import Foundation
import Testing
@testable import Coeur

/// La police des textes saints en hébreu (PoliceHebraiqueTest.kt) : livrée avec sa licence, sur les fichiers
/// d'iOS (ios/Ressources/Polices, copiés de res/font et d'assets/licences), puis la table des signes absents
/// et leur masquage rejoués de `Tests/Vecteurs/interface_a.json`. Restent à Android la famille de polices
/// (res/font/hebreu_serif.xml), la police des lignes d'état de l'accueil (activity_main.xml) et « chaque écran
/// de texte saint pose la police », qui lit le code des écrans et leurs mises en page.
@Suite("PoliceHebraique")
struct PoliceHebraiqueTests {

    private struct Vecteurs: Decodable {
        struct Lue: Decodable {
            let nom: String
            let cle: String
            let libelle: String
            let absents: [UInt16]?
            let remplacements: [UInt16]?
        }
        struct Masquage: Decodable {
            let nom: String
            let texte: [UInt16]
            let polices: [String: [UInt16]]
        }

        let polices: [Lue]
        let teamim: [UInt16]
        let masquages: [Masquage]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/interface_a.json"))
    }

    private func livre(_ chemin: String) throws -> Data {
        try Depot.donnees("ios/Ressources/Polices/" + chemin)
    }

    private func licence(_ nom: String) throws -> String {
        let donnees = try livre("licences/" + nom)
        return String(decoding: donnees, as: UTF8.self)
    }

    @Test func laPoliceEstLivreeAvecSaLicence() throws {
        for nom in ["hebreu_serif_regular.ttf", "hebreu_serif_bold.ttf"] {
            let taille = try livre(nom).count
            #expect(taille > 10_000, "\(nom) absent")
        }
        let texte = try licence("OFL-NotoSerifHebrew.txt")
        let ofl = texte.contient("SIL Open Font License")
        #expect(ofl)
    }

    @Test func lesLignesDEtatDeLAccueilSontEnVarelaRoundLivreeAvecSaLicence() throws {
        let taille = try livre("varela_round.ttf").count
        #expect(taille > 100_000)
        let texte = try licence("OFL-VarelaRound.txt")
        let ofl = texte.contient("SIL Open Font License")
        #expect(ofl)
    }

    /// Les sept polices dans l'ordre d'Android, leur clé, leur libellé et leurs signes absents, signe par signe.
    @Test func lesPolicesSontCellesDAndroid() throws {
        let v = try vecteurs()
        let polices = PoliceHebraique.Police.allCases
        let n = polices.count
        let lues = v.polices.count
        #expect(n == 7)
        #expect(n == lues, "nombre de polices")
        for (ici, lue) in zip(polices, v.polices) {
            let signes = PoliceHebraique.absents(ici).map { Array($0.utf16) }
            #expect(ici.cle == lue.cle, "\(lue.nom)")
            #expect(ici.libelle == lue.libelle, "\(lue.nom) : libellé")
            #expect(signes == lue.absents, "\(lue.nom) : signes absents")
            // Le Masque d'Android remplace chacun de ses signes par U+034F.
            let remplacements = lue.remplacements ?? []
            let joints = [UInt16](repeating: 0x034F, count: signes?.count ?? 0)
            #expect(remplacements == joints, "\(lue.nom) : remplacements")
        }
    }

    /// Les réglages n'admettent que les clés de ces polices, dans leur ordre, la première par défaut
    /// (`Store.lecturePolice` sur Android, `Reglages.lecturePolice` ici).
    @Test func lesReglagesAdmettentLesClesDesPolices() {
        let cles = PoliceHebraique.Police.allCases.map { $0.cle }
        let admises = Reglages.polices
        #expect(admises == cles)
    }

    @Test func lesTeamimSontCeuxDAndroid() throws {
        let v = try vecteurs()
        let ici = Array(PoliceHebraique.teamim.utf16)
        let n = ici.count
        #expect(ici == v.teamim)
        #expect(n == 31, "les 31 טעמים")
    }

    /// Le masquage, unité par unité, sur tout le bloc hébreu et sur de vrais textes du siddour et des
    /// hilloulot : ce que la vue d'Android affiche dans chaque police.
    @Test func leMasquageEstCeluiDAndroid() throws {
        let v = try vecteurs()
        let n = v.masquages.count
        #expect(n > 5, "échantillons lus")
        for m in v.masquages {
            let texte = String(decoding: m.texte, as: UTF16.self)
            let relu = Array(texte.utf16)
            #expect(relu == m.texte, "\(m.nom) : texte relu")
            for police in PoliceHebraique.Police.allCases {
                let attendu = try #require(m.polices[police.cle], "\(m.nom) : \(police.cle) absente des vecteurs")
                let masque = Array(PoliceHebraique.masque(texte, police: police).utf16)
                #expect(masque == attendu, "\(m.nom) : \(police.cle)")
            }
        }
    }

    /// Chaque police a son nom dans les trois langues du catalogue.
    @Test func chaquePoliceASonLibelleDansLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let simples = catalogue.simples(langue)
            for police in PoliceHebraique.Police.allCases {
                let present = simples[police.libelle] != nil
                #expect(present, "\(langue) : « \(police.libelle) » manquant")
            }
        }
    }
}
