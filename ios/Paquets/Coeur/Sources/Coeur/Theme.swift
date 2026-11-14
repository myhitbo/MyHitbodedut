// Le sujet d'une séance (Theme.kt d'Android, et ses règles, ThemeRules).

/// Le sujet d'une séance : de quoi on vient parler.
///
/// Il est facultatif, et c'est une décision, pas un oubli : obliger à choisir un sujet ajouterait un
/// obstacle là où il faut en retirer. « Aucun » s'écrit par l'absence de valeur (nil), jamais par un
/// membre de cette liste. `autre` n'est pas « aucun » : c'est un sujet choisi, qui n'est simplement
/// pas dans la liste.
///
/// Les valeurs brutes sont les clés d'Android, celles que le journal et la sauvegarde portent
/// (PORTAGE.md § 3.3) : les renommer effacerait le passé. Une clé inconnue, venue d'une version plus
/// récente, n'est pas perdue pour autant : la journée garde ses clés telles quelles (des chaînes),
/// seule leur lecture en sujet rend nil.
public enum Theme: String, Sendable, CaseIterable {
    case emotions
    case gratitude
    case decisions
    case famille
    case zivoug
    case parnassa
    case avoda
    case difficultes
    case croissance
    case autre

    /// La clé inscrite dans le journal.
    public var cle: String {
        rawValue
    }

    /// La clé de son libellé dans les chaînes.
    public var titre: String {
        switch self {
        case .emotions: return "theme_emotions"
        case .gratitude: return "theme_gratitude"
        case .decisions: return "theme_decisions"
        case .famille: return "theme_famille"
        case .zivoug: return "theme_zivoug"
        case .parnassa: return "theme_parnassa"
        case .avoda: return "theme_avoda"
        case .difficultes: return "theme_difficultes"
        case .croissance: return "theme_croissance"
        case .autre: return "theme_autre"
        }
    }
}

/// Ce qu'on peut dire des sujets, sans appareil.
public enum ThemeRules {

    /// Un sujet, et le nombre de fois qu'il revient (la paire `Theme to Int` de Kotlin).
    public struct Frequence: Sendable, Equatable {
        public let theme: Theme
        public let nombre: Int

        public init(_ theme: Theme, _ nombre: Int) {
            self.theme = theme
            self.nombre = nombre
        }
    }

    /// Retrouve un sujet par sa clé, à l'unité UTF-16 près comme `==` de Kotlin. Une clé absente,
    /// vide ou blanche (au sens de `isBlank`) ne vaut aucun sujet ; une clé inconnue rend nil
    /// plutôt que de rompre.
    public static func parse(_ cle: String?) -> Theme? {
        guard let cle, !cle.estBlanc else { return nil }
        return Theme.allCases.first { $0.cle.egalUnites(cle) }
    }

    /// Les sujets les plus fréquents, du plus au moins. À égalité, l'ordre de la liste des sujets
    /// tranche (le tri de Kotlin est stable), pour que deux appels rendent la même chose. Les clés
    /// que `parse` ne reconnaît pas ne comptent pas. Un plafond négatif rend une liste vide, là où
    /// Kotlin lève une exception (`take` d'un nombre négatif).
    public static func frequents(_ cles: [String], max: Int = 4) -> [Frequence] {
        let sujets = Theme.allCases
        var comptes = [Int](repeating: 0, count: sujets.count)
        for cle in cles {
            guard let theme = parse(cle), let rang = sujets.firstIndex(of: theme) else { continue }
            comptes[rang] += 1
        }
        let rangs = sujets.indices.filter { comptes[$0] > 0 }.sorted { a, b in
            comptes[a] != comptes[b] ? comptes[a] > comptes[b] : a < b
        }
        return rangs.prefix(Swift.max(0, max)).map { Frequence(sujets[$0], comptes[$0]) }
    }
}
