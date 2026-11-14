import Foundation
import Testing
@testable import Coeur

/// AdresseTest d'Android, porté : le bravo de fin de séance et le 'hazak d'une séance annulée, puis
/// la part d'Adresse.kt dans `Tests/Vecteurs/guidee.json`. L'hébreu se lit dans le catalogue exporté
/// (Localizable.xcstrings) au lieu de values-iw/strings.xml ; les mots attendus sont recopiés
/// d'AdresseTest.kt par programme.
@Suite("Adresse")
struct AdresseTests {

    private struct Vecteurs: Decodable {
        struct AdresseLue: Decodable {
            let membre: String
            let cle: String
            let bravo: String
            let nom: String
            let hazak: String
            let bravoDe: String
            let hazakDe: String
        }
        struct Neutre: Decodable {
            let bravo: String
            let hazak: String
        }
        struct Lecture: Decodable {
            let cle: String?
            let adresse: String?
        }

        let adresses: [AdresseLue]
        let adresseNeutre: Neutre
        let adressesLues: [Lecture]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/guidee.json"))
    }

    @Test func uneCleInconnueOuVideResteSansChoix() {
        let m = Adresse.parse("m")
        let f = Adresse.parse("f")
        let vide = Adresse.parse("")
        let absente = Adresse.parse(nil)
        let inconnue = Adresse.parse("x")
        #expect(m == Adresse.homme)
        #expect(f == Adresse.femme)
        #expect(vide == nil)
        #expect(absente == nil)
        #expect(inconnue == nil)
    }

    /// Sans choix, ni « Tsadik » ni « 'Hazak » : deviner le genre se tromperait pour quelqu'un.
    @Test func chaqueFormeASesPropresMotsEtLAbsenceDeChoixResteNeutre() {
        let bravos = [Adresse.bravo(Adresse.homme), Adresse.bravo(Adresse.femme), Adresse.bravo(nil)]
        let hazaks = [Adresse.hazak(Adresse.homme), Adresse.hazak(Adresse.femme), Adresse.hazak(nil)]
        let bravosDistincts = Set(bravos).count
        let hazaksDistincts = Set(hazaks).count
        let bravoNeutre = Adresse.bravo(nil)
        let hazakNeutre = Adresse.hazak(nil)
        #expect(bravosDistincts == 3)
        #expect(hazaksDistincts == 3)
        #expect(bravoNeutre == "celebration_neutral")
        #expect(hazakNeutre == "annulation_neutral")
    }

    @Test func lHebreuAccordeLeMotAuGenre() throws {
        let he = try Catalogue.lire().simples("he")
        let attendus: [(cle: String, mot: String)] = [
            ("celebration_tsadik", "צדיק"),
            ("celebration_tsadeket", "צדקת"),
            ("annulation_hazak", "חזק!"),
            ("annulation_hizki", "חזקי!"),
        ]
        for (cle, mot) in attendus {
            let texte = he[cle] ?? ""
            let contient = texte.contientUnites(mot)
            #expect(contient, "\(cle) devrait contenir « \(mot) » : « \(texte) »")
        }
    }

    /// Chaque clé que l'adresse nomme existe dans les trois langues.
    @Test func chaqueMotNommeExisteDansLesTroisLangues() throws {
        var cles = [Adresse.bravo(nil), Adresse.hazak(nil)]
        for adresse in Adresse.allCases {
            cles += [adresse.bravo, adresse.nom, adresse.hazak]
        }
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for cle in cles {
                let presente = chaines[cle] != nil
                #expect(presente, "\(langue) : « \(cle) » manquant")
            }
        }
    }

    @Test func lesVecteursDeLaJVMSontRejoues() throws {
        let v = try vecteurs()
        let formes = Adresse.allCases
        let n = formes.count
        let lues = v.adresses.count
        #expect(n == lues, "nombre de formes")
        for (adresse, lue) in zip(formes, v.adresses) {
            let bravoDe = Adresse.bravo(adresse)
            let hazakDe = Adresse.hazak(adresse)
            #expect(adresse.cle == lue.cle, "\(lue.membre) : clé")
            #expect(adresse.bravo == lue.bravo, "\(lue.membre) : bravo")
            #expect(adresse.nom == lue.nom, "\(lue.membre) : nom")
            #expect(adresse.hazak == lue.hazak, "\(lue.membre) : hazak")
            #expect(bravoDe == lue.bravoDe, "\(lue.membre) : Adresse.bravo")
            #expect(hazakDe == lue.hazakDe, "\(lue.membre) : Adresse.hazak")
        }
        let bravoNeutre = Adresse.bravo(nil)
        let hazakNeutre = Adresse.hazak(nil)
        #expect(bravoNeutre == v.adresseNeutre.bravo)
        #expect(hazakNeutre == v.adresseNeutre.hazak)
        for lecture in v.adressesLues {
            let rendue = Adresse.parse(lecture.cle)?.cle
            let ou = lecture.cle ?? "nil"
            #expect(rendue == lecture.adresse, "parse(« \(ou) »)")
        }
    }
}
