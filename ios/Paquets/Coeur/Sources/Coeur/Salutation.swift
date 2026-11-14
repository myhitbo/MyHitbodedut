// La salutation de l'accueil selon l'heure (Salutation.kt d'Android).
//
// « Bonjour Avraham » à trois heures du matin ou à dix heures du soir sonnait faux (demande du
// 30/09). Le français dit « bonjour » jusqu'au soir, puis « bonsoir » ; l'anglais et l'hébreu
// distinguent aussi l'après-midi. Les trois moments sont donc gardés, chaque langue les nomme à sa
// façon dans ses chaînes. La nuit, jusqu'à 5 h, reste le soir : on ne souhaite pas « bonne nuit » à
// quelqu'un qu'on accueille. L'heure (0 à 23) se passe en argument, jamais lue dans l'horloge.

public enum Salutation {

    public enum Partie: Sendable, CaseIterable {
        case matin
        case apresMidi
        case soir
    }

    /// De 5 h à midi le matin, de midi à 18 h l'après-midi, le reste le soir.
    public static func partie(_ heure: Int) -> Partie {
        switch heure {
        case 5..<12: return .matin
        case 12..<18: return .apresMidi
        default: return .soir
        }
    }

    /// La clé du mot du moment, sous la prière de l'heure (proposition 7 de la feuille de route,
    /// 19/10) : quatre moments, la nuit comprise cette fois, car ce n'est plus une salutation mais
    /// une invitation.
    public static func mot(_ heure: Int) -> String {
        switch heure {
        case 5..<12: return "moment_mot_matin"
        case 12..<18: return "moment_mot_journee"
        case 18..<23: return "moment_mot_soir"
        default: return "moment_mot_nuit"
        }
    }

    /// La clé de la salutation de l'accueil, qui prend le prénom en argument.
    public static func chaine(_ heure: Int) -> String {
        switch partie(heure) {
        case .matin: return "hero_greeting_morning"
        case .apresMidi: return "hero_greeting_afternoon"
        case .soir: return "hero_greeting_evening"
        }
    }
}
