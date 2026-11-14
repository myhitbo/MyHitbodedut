import Foundation
import Testing
@testable import Coeur

/// Libelle face à Android : toutes les chaînes à marqueurs et tous les pluriels du catalogue exporté,
/// mis en forme dans les trois langues comme `getString` et `getQuantityString` les écrivent
/// (`Tests/Vecteurs/libelles.json`, produit par tools/vecteurs_ios/VecteursLibelles.kt). Le même test
/// juge la conversion des marqueurs par l'export (%1$s → %1$@, %2$02d → %2$02lld).
@Suite("Libellés")
struct LibelleTests {

    private struct Valeur: Decodable {
        let texte: String?
        let entier: Int?
    }

    private struct Cas: Decodable {
        let cle: String
        let quantite: Int?
        let arguments: [Valeur]
        let textes: [String: String?]
    }

    private struct Fichier: Decodable {
        let simples: [Cas]
        let pluriels: [Cas]
    }

    /// Le catalogue exporté, lu comme Android lit ses ressources : ce qu'une langue ne traduit pas
    /// retombe sur le français ; un pluriel traduit garde ses seules formes.
    private struct Lecteur {
        let simples: [String: [String: String]]
        let pluriels: [String: [String: String]]

        init(_ catalogue: Catalogue) {
            var simples: [String: [String: String]] = [:]
            var pluriels: [String: [String: String]] = [:]
            for langue in Catalogue.langues {
                simples[langue] = catalogue.simples(langue)
                pluriels[langue] = catalogue.pluriels(langue)
            }
            self.simples = simples
            self.pluriels = pluriels
        }

        func texte(_ libelle: Libelle, langue: String) -> String? {
            let ici = simples[langue] ?? [:]
            let francais = simples["fr"] ?? [:]
            let formesIci = pluriels[langue] ?? [:]
            let formesFrancaises = pluriels["fr"] ?? [:]
            return libelle.texte(
                langue: langue,
                chaine: { cle in ici[cle] ?? francais[cle] },
                pluriel: { cle, forme in
                    let traduit = formesIci.keys.contains { $0.hasPrefix(cle + "[") }
                    return (traduit ? formesIci : formesFrancaises)["\(cle)[\(forme)]"]
                })
        }
    }

    @Test func toutesLesChainesCommeAndroid() throws {
        let fichier = try JSONDecoder().decode(
            Fichier.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/libelles.json"))
        let lecteur = try Lecteur(Catalogue.lire())
        var comparees = 0
        for cas in fichier.simples + fichier.pluriels {
            let arguments = cas.arguments.map { valeur -> Libelle.Argument in
                if let entier = valeur.entier { return .entier(entier) }
                return .texte(valeur.texte ?? "")
            }
            let libelle = Libelle(cle: cas.cle, arguments: arguments, quantite: cas.quantite)
            for (langue, attendu) in cas.textes.sorted(by: { $0.key < $1.key }) {
                let obtenu = lecteur.texte(libelle, langue: langue)
                #expect(obtenu == attendu, "\(libelle) en \(langue)")
                comparees += 1
            }
        }
        let attendues = (fichier.simples.count + fichier.pluriels.count) * Catalogue.langues.count
        #expect(comparees == attendues)
        let simples = fichier.simples.count
        #expect(simples > 150, "trop peu de chaînes à marqueurs : \(simples)")
    }

    @Test func formesDuPluriel() {
        let francais = [0, 1, 2, 5].map { Libelle.forme($0, langue: "fr") }
        #expect(francais == ["one", "one", "other", "other"])
        let anglais = [0, 1, 2, 5].map { Libelle.forme($0, langue: "en") }
        #expect(anglais == ["other", "one", "other", "other"])
        let hebreu = [0, 1, 2, 5, 20].map { Libelle.forme($0, langue: "he") }
        #expect(hebreu == ["other", "one", "two", "other", "other"])
        let iw = Libelle.forme(2, langue: "iw")
        #expect(iw == "two")
    }

    /// `String.format` de Java : positions, ordre ordinaire indépendant des positions, largeur, signe.
    @Test func miseEnFormeCommeJava() {
        let minutes = Libelle.mettreEnForme("%1$lld h %2$02lld", [.entier(1), .entier(5)])
        #expect(minutes == "1 h 05")
        let melange = Libelle.mettreEnForme("%2$@ %@ %@", [.texte("a"), .texte("b")])
        #expect(melange == "b a b")
        let pourcent = Libelle.mettreEnForme("%1$lld\u{202F}%%", [.entier(80)])
        #expect(pourcent == "80\u{202F}%")
        let negatif = Libelle.mettreEnForme("%03d", [.entier(-5)])
        #expect(negatif == "-05")
        let large = Libelle.mettreEnForme("[%5s][%-4@]", [.texte("ab"), .texte("c")])
        #expect(large == "[   ab][c   ]")
        let nombreEnTexte = Libelle.mettreEnForme("%1$@", [.entier(42)])
        #expect(nombreEnTexte == "42")
        let manquant = Libelle.mettreEnForme("%2$@", [.texte("a")])
        #expect(manquant == nil)
        let texteEnNombre = Libelle.mettreEnForme("%d", [.texte("a")])
        #expect(texteEnNombre == nil)
        let inconnu = Libelle.mettreEnForme("%f", [.entier(1)])
        #expect(inconnu == nil)
    }

    /// Sans argument, le gabarit est rendu tel quel (`getString(id)`), `%%` compris ; un libellé dans un
    /// autre se résout dans la même langue ; une clé absente rend nil.
    @Test func resolution() {
        let gabarits = ["brut": "100 %%", "dans": "Dans %1$@.", "duree": "%1$lld min"]
        let formes = ["jours[one]": "%1$lld jour", "jours[other]": "%1$lld jours"]
        func texte(_ libelle: Libelle, _ langue: String = "fr") -> String? {
            libelle.texte(langue: langue, chaine: { gabarits[$0] }, pluriel: { formes["\($0)[\($1)]"] })
        }
        let brut = texte(Libelle("brut"))
        #expect(brut == "100 %%")
        let imbrique = texte(Libelle("dans", .libelle(Libelle("duree", .entier(20)))))
        #expect(imbrique == "Dans 20 min.")
        let zero = texte(.pluriel("jours", quantite: 0, .entier(0)))
        #expect(zero == "0 jour")
        let deux = texte(.pluriel("jours", quantite: 2, .entier(2)), "he")
        #expect(deux == "2 jours", "la forme « two » absente retombe sur « other »")
        let absente = texte(Libelle("absente"))
        #expect(absente == nil)
        let decrit = Libelle("dans", .texte("x"), .entier(3)).description
        #expect(decrit == "dans(« x », 3)")
    }
}
