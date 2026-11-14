// Comment l'application s'adresse à qui la tient : tsadik ou tsadeket (Adresse.kt d'Android).

/// La forme d'adresse choisie. Tant que rien n'est choisi, la valeur est nil (la sauvegarde écrit
/// une clé vide, PORTAGE.md § 3.3) et le « bravo » de fin de séance reste neutre : deviner le genre
/// à partir d'un prénom se tromperait pour quelqu'un, et se tromper sur ce mot-là gâcherait le
/// compliment. Les valeurs brutes sont les clés d'Android.
public enum Adresse: String, Sendable, CaseIterable {
    case homme = "m"
    case femme = "f"

    public var cle: String {
        rawValue
    }

    /// La clé du « bravo » de fin de séance.
    public var bravo: String {
        switch self {
        case .homme: return "celebration_tsadik"
        case .femme: return "celebration_tsadeket"
        }
    }

    /// La clé du nom de la forme, dans les réglages.
    public var nom: String {
        switch self {
        case .homme: return "adresse_tsadik"
        case .femme: return "adresse_tsadeket"
        }
    }

    /// Après une séance annulée : 'hazak ou 'hizki.
    public var hazak: String {
        switch self {
        case .homme: return "annulation_hazak"
        case .femme: return "annulation_hizki"
        }
    }

    /// Une clé inconnue ou vide rend nil : la sauvegarde d'une autre version ne rompt rien. La
    /// comparaison est celle de Kotlin, unité UTF-16 par unité.
    public static func parse(_ cle: String?) -> Adresse? {
        guard let cle else { return nil }
        return allCases.first { $0.cle.egalUnites(cle) }
    }

    /// Le « bravo » de fin de séance ; sans choix, le neutre.
    public static func bravo(_ adresse: Adresse?) -> String {
        adresse?.bravo ?? "celebration_neutral"
    }

    /// Le mot d'après une séance annulée ; sans choix, le neutre.
    public static func hazak(_ adresse: Adresse?) -> String {
        adresse?.hazak ?? "annulation_neutral"
    }
}
