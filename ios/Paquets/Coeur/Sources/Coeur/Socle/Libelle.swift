import Foundation

// Les chaînes de l'interface comme Android les écrit : `getString(R.string.x, args…)` et
// `getQuantityString(R.plurals.x, n, args…)`. Une règle portée ne met rien en forme elle-même : elle
// rend un `Libelle`, la clé (le nom de la ressource d'Android, qui est aussi celui du catalogue
// d'iOS) et ses arguments, que l'écran résout dans la langue de l'app. `texte(langue:chaine:pluriel:)`
// fait cette résolution sans Foundation de Darwin : tests sous Linux, extensions, widgets.
// Jugé par `Tests/Vecteurs/libelles.json` (toutes les chaînes à marqueurs du catalogue, trois langues).

/// Une chaîne de l'interface désignée par sa clé, avec ses arguments.
public struct Libelle: Sendable, Hashable, CustomStringConvertible {

    /// Une valeur glissée dans la chaîne.
    public enum Argument: Sendable, Hashable {
        /// Pour `%1$@` (`%1$s` sur Android).
        case texte(String)
        /// Pour `%1$lld` (`%1$d` sur Android), largeur comprise : `%2$02lld`.
        case entier(Int)
        /// Une autre chaîne de l'interface, résolue dans la même langue (« 1 h 30 » dans un rappel).
        case libelle(Libelle)
    }

    /// Le nom de la ressource : « gate_window_detail ».
    public let cle: String
    public let arguments: [Argument]
    /// La quantité qui choisit la forme d'un pluriel ; nil pour une chaîne simple.
    public let quantite: Int?

    /// `getString(R.string.cle, arguments…)`.
    public init(_ cle: String, _ arguments: Argument...) {
        self.init(cle: cle, arguments: arguments, quantite: nil)
    }

    public init(cle: String, arguments: [Argument], quantite: Int?) {
        self.cle = cle
        self.arguments = arguments
        self.quantite = quantite
    }

    /// `getQuantityString(R.plurals.cle, quantite, arguments…)` : la quantité choisit la forme, elle
    /// n'est insérée que si elle figure aussi parmi les arguments, comme sur Android.
    public static func pluriel(_ cle: String, quantite: Int, _ arguments: Argument...) -> Libelle {
        Libelle(cle: cle, arguments: arguments, quantite: quantite)
    }

    public var description: String {
        let valeurs = arguments.map { argument -> String in
            switch argument {
            case .texte(let texte): "« \(texte) »"
            case .entier(let entier): String(entier)
            case .libelle(let libelle): libelle.description
            }
        }
        let quantiteLue = quantite.map { "[\($0)]" } ?? ""
        return cle + quantiteLue + (valeurs.isEmpty ? "" : "(" + valeurs.joined(separator: ", ") + ")")
    }
}

extension Libelle {

    /// La forme d'un pluriel pour une quantité entière, selon les règles de CLDR des langues de l'app :
    /// « one » (0 et 1 en français, 1 ailleurs), « two » (2 en hébreu), sinon « other » ; en espagnol « many »
    /// pour les millions ronds ; en arabe « zero », « one », « two », « few » (3 à 10 sur cent), « many » (11 à 99).
    public static func forme(_ quantite: Int, langue: String) -> String {
        switch langue {
        case "fr": quantite == 0 || quantite == 1 ? "one" : "other"
        case "he", "iw": quantite == 1 ? "one" : (quantite == 2 ? "two" : "other")
        // L'espagnol et l'arabe (17/11), les règles de CLDR sur des entiers.
        case "es": quantite == 1 ? "one" : (quantite != 0 && quantite % 1_000_000 == 0 ? "many" : "other")
        case "ar":
            switch quantite {
            case 0: "zero"
            case 1: "one"
            case 2: "two"
            default:
                switch ((quantite % 100) + 100) % 100 {
                case 3...10: "few"
                case 11...99: "many"
                default: "other"
                }
            }
        default: quantite == 1 ? "one" : "other"
        }
    }

    /// Le texte dans `langue`, mis en forme comme le fait Android. `chaine(cle)` rend le gabarit d'une
    /// chaîne simple, `pluriel(cle, forme)` celui d'une forme de pluriel (la forme « other » sert à défaut
    /// de celle de la quantité). Sans argument, le gabarit est rendu tel quel, `%%` compris, comme
    /// `getString(id)`. Nil si une clé manque ou si le gabarit demande un argument absent.
    public func texte(langue: String, chaine: (String) -> String?, pluriel: (String, String) -> String?) -> String? {
        let gabarit: String?
        if let quantite {
            gabarit = pluriel(cle, Libelle.forme(quantite, langue: langue)) ?? pluriel(cle, "other")
        } else {
            gabarit = chaine(cle)
        }
        guard let gabarit else { return nil }
        if arguments.isEmpty { return gabarit }
        var valeurs: [Argument] = []
        for argument in arguments {
            if case .libelle(let interieur) = argument {
                guard let texte = interieur.texte(langue: langue, chaine: chaine, pluriel: pluriel) else { return nil }
                valeurs.append(.texte(texte))
            } else {
                valeurs.append(argument)
            }
        }
        return Libelle.mettreEnForme(gabarit, valeurs)
    }

    /// `String.format` de Java sur les marqueurs du catalogue : `%%`, `%@` et `%s` (un texte), `%lld`,
    /// `%ld` et `%d` (un entier), avec une position (`%2$…`), le drapeau `0` ou `-` et une largeur
    /// (`%2$02lld`). Comme Java, les marqueurs sans position prennent les arguments dans l'ordre, sans
    /// tenir compte de ceux qui en ont une. Nil pour un marqueur inconnu ou un argument absent.
    public static func mettreEnForme(_ gabarit: String, _ arguments: [Argument]) -> String? {
        let unites = Array(gabarit.unicodeScalars)
        var sortie = String.UnicodeScalarView()
        var ordinaire = 0
        var i = 0
        while i < unites.count {
            let c = unites[i]
            if c != "%" {
                sortie.append(c)
                i += 1
                continue
            }
            i += 1
            guard i < unites.count else { return nil }
            if unites[i] == "%" {
                sortie.append("%")
                i += 1
                continue
            }
            // Une position « 12$ », puis les drapeaux, la largeur, la longueur et le type.
            var nombre = 0
            var chiffres = 0
            var j = i
            while j < unites.count, let chiffre = chiffreDe(unites[j]) {
                nombre = nombre * 10 + chiffre
                chiffres += 1
                j += 1
            }
            var position: Int?
            if chiffres > 0, j < unites.count, unites[j] == "$" {
                position = nombre
                i = j + 1
            }
            var zeros = false
            var aGauche = false
            while i < unites.count, unites[i] == "0" || unites[i] == "-" {
                if unites[i] == "0" { zeros = true } else { aGauche = true }
                i += 1
            }
            var largeur = 0
            while i < unites.count, let chiffre = chiffreDe(unites[i]) {
                largeur = largeur * 10 + chiffre
                i += 1
            }
            while i < unites.count, unites[i] == "l" { i += 1 }
            guard i < unites.count else { return nil }
            let type = unites[i]
            i += 1
            let rang: Int
            if let position {
                rang = position
            } else {
                ordinaire += 1
                rang = ordinaire
            }
            guard rang >= 1, rang <= arguments.count else { return nil }
            let texte: String
            switch (type, arguments[rang - 1]) {
            case ("@", .texte(let valeur)), ("s", .texte(let valeur)):
                texte = valeur
            case ("@", .entier(let valeur)), ("s", .entier(let valeur)):
                texte = String(valeur)
            case ("d", .entier(let valeur)):
                texte = ecrireEntier(valeur, largeur: zeros && !aGauche ? largeur : 0)
            default:
                return nil
            }
            let manque = largeur - texte.unicodeScalars.count
            if manque > 0 && !(zeros && type == "d" && !aGauche) {
                let blancs = String(repeating: " ", count: manque)
                sortie.append(contentsOf: (aGauche ? texte + blancs : blancs + texte).unicodeScalars)
            } else {
                sortie.append(contentsOf: texte.unicodeScalars)
            }
        }
        return String(sortie)
    }

    private static func chiffreDe(_ c: Unicode.Scalar) -> Int? {
        c.value >= 0x30 && c.value <= 0x39 ? Int(c.value - 0x30) : nil
    }

    /// Un entier en chiffres ASCII, complété de zéros après le signe jusqu'à `largeur` (`%05d` de Java).
    private static func ecrireEntier(_ valeur: Int, largeur: Int) -> String {
        let chiffres = String(valeur.magnitude)
        let signe = valeur < 0 ? "-" : ""
        let manque = largeur - signe.count - chiffres.count
        return signe + (manque > 0 ? String(repeating: "0", count: manque) : "") + chiffres
    }
}
