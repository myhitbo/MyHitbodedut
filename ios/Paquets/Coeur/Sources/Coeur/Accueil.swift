import Foundation

/// `Salutation.kt` : la salutation de l'accueil selon l'heure (demande du 30/09), et le mot du moment
/// (proposition 7, 19/10). Rend des clés du catalogue de chaînes ; la nuit, jusqu'à 5 h, reste le soir.
public enum Salutation {

    public enum Partie: String, Sendable, CaseIterable {
        case matin = "MATIN", apresMidi = "APRES_MIDI", soir = "SOIR"
    }

    public static func partie(_ heure: Int) -> Partie {
        switch heure {
        case 5..<12: .matin
        case 12..<18: .apresMidi
        default: .soir
        }
    }

    /// Le mot du moment, sous la prière de l'heure : quatre moments, la nuit comprise.
    public static func mot(_ heure: Int) -> String {
        switch heure {
        case 5..<12: "moment_mot_matin"
        case 12..<18: "moment_mot_journee"
        case 18..<23: "moment_mot_soir"
        default: "moment_mot_nuit"
        }
    }

    public static func chaine(_ heure: Int) -> String {
        switch partie(heure) {
        case .matin: "hero_greeting_morning"
        case .apresMidi: "hero_greeting_afternoon"
        case .soir: "hero_greeting_evening"
        }
    }
}

/// `Character.kt` : les illustrations du personnage, par moment de la journée, sous leur nom d'image
/// (`ios/Ressources/Images`). Le choix est stable sur une journée et change le lendemain ; le jour est passé
/// en argument.
public enum ImagesDuPersonnage {

    /// Appel à la pratique, sur l'écran de garde.
    static let appels = ["char_praise", "char_pointing", "char_walking", "char_tehilim", "char_thinking", "char_welcome",
                         "char_open_arms"]

    /// Pendant la séance : seul, tourné vers le haut.
    static let pendants = ["char_open_arms", "char_praying", "char_standing_back", "char_praise"]

    /// Après la séance, ou journée déjà validée.
    static let joies = ["char_dancing_joy", "char_dancing", "char_guitar", "char_thumbs_up", "char_open_arms"]

    public static let journal = "char_writing"
    public static let etude = "char_torah"
    public static let lecture = "char_tehilim"
    /// Le Tikoun HaKlali : dix psaumes, livre en main.
    public static let tehilim = "char_tehilim"

    /// Au centre de l'anneau : tant que la hitbodedout du jour reste à faire, celui qui accueille (13/10).
    public static func accueil(faite: Bool, jour: JourCivil) -> String {
        faite ? duJour(joies, 3, jour) : "char_welcome"
    }

    public static func appel(_ jour: JourCivil) -> String { duJour(appels, 1, jour) }

    public static func pendant(_ jour: JourCivil) -> String { duJour(pendants, 2, jour) }

    public static func joie(_ jour: JourCivil) -> String { duJour(joies, 3, jour) }

    /// Les deux natures d'entrée de la bibliothèque : une source se tient devant le livre, un article est un texte
    /// qu'on a écrit.
    public static func entree(_ e: EntreeBibliotheque) -> String {
        switch e {
        case .source: "char_torah"
        case .article: "char_writing"
        }
    }

    /// L'illustration d'une carte de 'hizouk, choisie par le moment plutôt que par le jour.
    public static func moment(_ m: Moment) -> String {
        switch m {
        case .ouverture: "char_open_arms"
        case .blocage: "char_praying"
        case .porte: "char_pointing"
        case .relance: "char_thinking"
        case .cloture: "char_praise"
        case .lieu: "scene_nature"
        case .demande: "char_open_arms"
        }
    }

    /// `ofDay` : le jour depuis 1970, décalé d'une semaine par sel.
    static func duJour(_ images: [String], _ sel: Int, _ jour: JourCivil) -> String {
        images[Kotlin.floorMod(jour.jourJulien - 2_440_588 + sel * 7, images.count)]
    }
}
