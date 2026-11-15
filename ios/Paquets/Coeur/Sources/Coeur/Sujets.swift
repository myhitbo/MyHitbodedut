import Foundation

/// `Theme.kt` : le sujet d'une séance, de quoi on vient parler. Il est facultatif, et c'est une décision :
/// « aucun » s'écrit par l'absence de valeur (nil), jamais par un membre de cette liste. AUTRE est un sujet
/// choisi, simplement absent de la liste. Les clés partent dans le journal : les renommer effacerait le passé.
public enum Theme: String, Sendable, CaseIterable {
    case emotions, gratitude, decisions, famille, zivoug, parnassa, avoda, difficultes, croissance, autre

    public var cle: String { rawValue }

    /// La clé du libellé dans le catalogue de chaînes.
    public var titre: String { "theme_" + rawValue }
}

/// `ThemeRules` : ce qu'on peut dire des sujets, sans appareil.
public enum ThemeRules {

    /// Un sujet et le nombre de séances qui l'ont porté.
    public struct Frequence: Sendable, Equatable {
        public let theme: Theme
        public let compte: Int

        public init(_ theme: Theme, _ compte: Int) {
            self.theme = theme
            self.compte = compte
        }
    }

    /// Retrouve un sujet par sa clé ; une clé vide, blanche ou inconnue rend nil plutôt que de rompre : un journal
    /// exporté d'une version plus récente peut porter un sujet que celle-ci ne connaît pas encore.
    public static func parse(_ cle: String?) -> Theme? {
        guard let cle, !cle.estBlanc else { return nil }
        return Theme.allCases.first { $0.cle.egalUnites(cle) }
    }

    /// Les sujets les plus fréquents, du plus au moins ; à égalité, l'ordre de la liste tranche.
    public static func frequents(_ cles: [String], max: Int = 4) -> [Frequence] {
        var comptes = [Int](repeating: 0, count: Theme.allCases.count)
        for cle in cles {
            if let t = parse(cle), let rang = Theme.allCases.firstIndex(of: t) { comptes[rang] += 1 }
        }
        let tries = comptes.indices.filter { comptes[$0] > 0 }.sorted { (comptes[$0], -$0) > (comptes[$1], -$1) }
        return tries.prefix(Swift.max(max, 0)).map { Frequence(Theme.allCases[$0], comptes[$0]) }
    }
}

/// `Adresse.kt` : comment l'application s'adresse à qui la tient, צדיק ou צדקת. Tant que rien n'est choisi,
/// le bravo de fin de séance reste neutre : deviner le genre à partir d'un prénom se tromperait pour quelqu'un.
/// Rend des clés du catalogue de chaînes.
public enum Adresse: String, Sendable, CaseIterable {
    case homme = "m", femme = "f"

    public var cle: String { rawValue }

    public var bravo: String { self == .homme ? "celebration_tsadik" : "celebration_tsadeket" }

    public var nom: String { self == .homme ? "adresse_tsadik" : "adresse_tsadeket" }

    /// Après une séance annulée : חזק ou חזקי.
    public var hazak: String { self == .homme ? "annulation_hazak" : "annulation_hizki" }

    /// Une clé inconnue ou vide rend nil : la sauvegarde d'une autre version ne rompt rien.
    public static func parse(_ cle: String?) -> Adresse? {
        guard let cle else { return nil }
        return allCases.first { $0.cle.egalUnites(cle) }
    }

    public static func bravo(pour adresse: Adresse?) -> String { adresse?.bravo ?? "celebration_neutral" }

    public static func hazak(pour adresse: Adresse?) -> String { adresse?.hazak ?? "annulation_neutral" }
}
