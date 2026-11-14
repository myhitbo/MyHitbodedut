// Les illustrations du personnage (Character.kt d'Android ; le nom Character est pris en Swift).
// Les images portent les noms d'Android : R.drawable.x devient « x » (ios/Ressources/Images).

/// Les poses du personnage, réparties par moment de la journée. Le choix est stable sur une journée
/// entière et change le lendemain, pour que l'app paraisse vivante sans jamais clignoter sous les
/// yeux. Android lit le jour dans l'horloge (`LocalDate.now()`) ; ici l'appelant le donne, jour civil
/// du téléphone.
public enum Poses {

    /// Appel à la pratique, sur l'écran de garde.
    private static let appel = [
        "char_praise",
        "char_pointing",
        "char_walking",
        "char_tehilim",
        "char_thinking",
        "char_welcome",
        "char_open_arms",
    ]

    /// Pendant la séance : seul, tourné vers le haut. char_arms_raised était une copie exacte de
    /// char_open_arms (audit 1.390) : supprimée, la même image reste ici sous son seul nom. Les mains
    /// levées, la louange, depuis la demande du 13/10.
    private static let pendant = [
        "char_open_arms",
        "char_praying",
        "char_standing_back",
        "char_praise",
    ]

    /// Après la séance, ou journée déjà validée.
    private static let joie = [
        "char_dancing_joy",
        "char_dancing",
        "char_guitar",
        "char_thumbs_up",
        "char_open_arms",
    ]

    public static let journal = "char_writing"
    public static let study = "char_torah"
    public static let reading = "char_tehilim"

    /// Le Tikoun HaKlali : dix psaumes, livre en main.
    public static let tehilim = "char_tehilim"

    /// Les deux natures d'entrée de la bibliothèque. Une source se tient devant le livre ; un
    /// article est un texte qu'on a écrit.
    public static func ofLibraryEntry(_ entree: EntreeBibliotheque) -> String {
        switch entree {
        case .source: return "char_torah"
        case .article: return "char_writing"
        }
    }

    /// L'illustration d'une carte de 'hizouk, choisie par le moment plutôt que par le jour : ici
    /// l'image dit ce qu'on est en train de vivre, elle ne doit donc pas tourner comme les autres.
    public static func ofMoment(_ moment: Moment) -> String {
        switch moment {
        // On se présente, les mains ouvertes.
        case .ouverture: return "char_open_arms"
        // Les mots ne viennent pas : assis, en attente.
        case .blocage: return "char_praying"
        // Sur le pas de la porte, le téléphone à la main.
        case .porte: return "char_pointing"
        // Reprendre la route après une rupture ; plus le personnage qui marche (13/10).
        case .relance: return "char_thinking"
        // La séance s'achève : on remercie.
        case .cloture: return "char_praise"
        // Le lieu et le moment : seul, assis face au paysage (planche du 11/10).
        case .lieu: return "scene_nature"
        // À la demande : les bras ouverts, comme on vient chercher.
        case .demande: return "char_open_arms"
        }
    }

    /// Au centre de l'anneau : tant que la hitbodedout du jour reste à faire, celui qui accueille
    /// (13/10) ; une fois faite, la joie du jour.
    public static func greeting(_ done: Bool, jour: JourCivil) -> String {
        done ? duJour(joie, sel: 3, jour) : "char_welcome"
    }

    public static func call(_ jour: JourCivil) -> String {
        duJour(appel, sel: 1, jour)
    }

    public static func during(_ jour: JourCivil) -> String {
        duJour(pendant, sel: 2, jour)
    }

    public static func joy(_ jour: JourCivil) -> String {
        duJour(joie, sel: 3, jour)
    }

    /// `LocalDate.toEpochDay()` : le numéro julien moins celui du 1er janvier 1970.
    private static let jourJulien1970 = 2_440_588

    /// ofDay : le numéro du jour depuis le 1er janvier 1970, décalé de sept jours par sel, pour que
    /// deux réserves ne tournent pas d'un même pas ; le reste est pris du côté positif, avant 1970
    /// comme après.
    private static func duJour(_ reserve: [String], sel: Int, _ jour: JourCivil) -> String {
        let numero = jour.jourJulien - jourJulien1970 + sel * 7
        return reserve[Kotlin.floorMod(numero, reserve.count)]
    }
}
