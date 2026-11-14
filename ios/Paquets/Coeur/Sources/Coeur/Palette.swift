import Foundation

// Le système visuel (Apparence.kt, res/values*/palettes.xml) : 13 jetons de couleur, 6 fonds ×
// 6 accents, de jour et de nuit, lus dans Contenu/palettes.json, où l'export les a déjà résolus
// couche par couche (tools/export_contenu, étape 4). Swift pur : l'app en tire ses `Color`.

/// Une couleur opaque.
public struct Couleur: Sendable, Hashable {
    public let rouge: UInt8, vert: UInt8, bleu: UInt8

    public init(rouge: UInt8, vert: UInt8, bleu: UInt8) {
        self.rouge = rouge
        self.vert = vert
        self.bleu = bleu
    }

    /// `#RRGGBB`, ou `#AARRGGBB` d'Android dont seules les six dernières positions comptent
    /// (comme PaletteTest) ; nil pour toute autre écriture.
    public init?(hex: String) {
        guard hex.hasPrefix("#"), hex.count == 7 || hex.count == 9,
              let valeur = UInt32(hex.suffix(6), radix: 16) else { return nil }
        self.init(rouge: UInt8(valeur >> 16 & 0xFF), vert: UInt8(valeur >> 8 & 0xFF), bleu: UInt8(valeur & 0xFF))
    }

    public static let blanc = Couleur(rouge: 255, vert: 255, bleu: 255)
    public static let noir = Couleur(rouge: 0, vert: 0, bleu: 0)

    public var hex: String {
        "#" + [rouge, vert, bleu].map { octet in
            let s = String(octet, radix: 16, uppercase: true)
            return s.count == 1 ? "0" + s : s
        }.joined()
    }

    /// La luminance relative de WCAG 2.
    public var luminance: Double {
        func lineaire(_ octet: UInt8) -> Double {
            let c = Double(octet) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lineaire(rouge) + 0.7152 * lineaire(vert) + 0.0722 * lineaire(bleu)
    }

    /// Le rapport de contraste de WCAG 2, de 1 à 21 : 4,5 pour le texte courant, 7 pour l'encre.
    public static func contraste(_ a: Couleur, _ b: Couleur) -> Double {
        let x = a.luminance, y = b.luminance
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}

/// Les couleurs réglables, sous les noms de colors.xml.
public enum Jeton: String, Sendable, CaseIterable {
    case brand, brandDark = "brand_dark", mint, onBrand = "on_brand", onPlate = "on_plate",
         stageSoft = "stage_soft", dayDone = "day_done"
    case paper, card, line, ink, muted, dayTodo = "day_todo"

    /// Les jetons de l'accent (boutons, titres, bandeaux) ; les autres sont ceux du fond.
    public var deLAccent: Bool {
        switch self {
        case .brand, .brandDark, .mint, .onBrand, .onPlate, .stageSoft, .dayDone: true
        case .paper, .card, .line, .ink, .muted, .dayTodo: false
        }
    }

    /// Les plaques claires sous les illustrations, et l'encre qui s'y pose : jamais de bascule la nuit.
    public static let fixes: [Jeton] = [.brandDark, .mint, .onPlate, .stageSoft, .dayDone]
}

/// Le fond, les cartes et l'encre (Apparence.Fond), dans l'ordre de l'écran.
public enum Fond: String, Sendable, CaseIterable {
    case vert, blanc, sable, bleu, rose, contraste

    public static func de(_ cle: String?) -> Fond { cle.flatMap(Fond.init(rawValue:)) ?? .vert }
}

/// Les boutons, les titres et les bandeaux (Apparence.Accent), dans l'ordre de l'écran.
public enum Accent: String, Sendable, CaseIterable {
    case vert, bleu, violet, bordeaux, ambre, turquoise

    public static func de(_ cle: String?) -> Accent { cle.flatMap(Accent.init(rawValue:)) ?? .vert }
}

/// Les treize couleurs d'une combinaison.
public struct Palette: Sendable, Equatable {
    private let couleurs: [Jeton: Couleur]

    init?(_ hex: [String: String]) {
        var couleurs: [Jeton: Couleur] = [:]
        for jeton in Jeton.allCases {
            guard let valeur = hex[jeton.rawValue], let couleur = Couleur(hex: valeur) else { return nil }
            couleurs[jeton] = couleur
        }
        self.couleurs = couleurs
    }

    /// Toujours défini : une palette incomplète n'est pas lue.
    public subscript(_ jeton: Jeton) -> Couleur { couleurs[jeton] ?? .noir }
}

/// `palettes.json` : chaque fond avec chaque accent, de jour et de nuit.
public struct Palettes: Sendable {
    private let parCle: [String: Palette]

    private static func cle(_ fond: Fond, _ accent: Accent, nuit: Bool) -> String {
        "\(nuit ? "nuit" : "jour")/\(fond.rawValue)/\(accent.rawValue)"
    }

    private struct Fichier: Decodable {
        let jetons: [String]
        let modes: [String: [String: [String: String]]]
    }

    /// Refuse un fichier où manque un jeton, une combinaison ou un des deux moments, ou qui en a
    /// de plus : l'app n'a jamais à deviner une couleur.
    public static func lire(_ donnees: Data) throws -> Palettes {
        let fichier = try JSONDecoder().decode(Fichier.self, from: donnees)
        guard fichier.jetons == Jeton.allCases.map(\.rawValue), Set(fichier.modes.keys) == ["jour", "nuit"] else {
            throw ErreurContenu.malForme("palettes.json : jetons ou moments")
        }
        var parCle: [String: Palette] = [:]
        for nuit in [false, true] {
            let combinaisons = fichier.modes[nuit ? "nuit" : "jour"] ?? [:]
            guard combinaisons.count == Fond.allCases.count * Accent.allCases.count else {
                throw ErreurContenu.malForme("palettes.json : \(combinaisons.count) combinaisons")
            }
            for fond in Fond.allCases {
                for accent in Accent.allCases {
                    let nom = "\(fond.rawValue)/\(accent.rawValue)"
                    guard let hex = combinaisons[nom], let palette = Palette(hex) else {
                        throw ErreurContenu.malForme("palettes.json : \(nom)")
                    }
                    parCle[cle(fond, accent, nuit: nuit)] = palette
                }
            }
        }
        return Palettes(parCle: parCle)
    }

    /// Toujours définie : `lire` a vérifié les 72 combinaisons.
    public func palette(fond: Fond, accent: Accent, nuit: Bool) -> Palette {
        guard let palette = parCle[Palettes.cle(fond, accent, nuit: nuit)] else {
            preconditionFailure("palette absente : \(fond) / \(accent)")
        }
        return palette
    }
}
