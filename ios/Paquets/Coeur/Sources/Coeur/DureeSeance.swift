/// Les durées de séance proposées, et la durée réglable (DureeSeance.kt).
///
/// Demande du propriétaire, 28/09 : 5, 10, 15, 30 minutes, 1 h, 1 h 30, ou un temps choisi. La même
/// liste partout — accueil, réglages, écran de séance — pour qu'une durée vue à un endroit se
/// retrouve à l'autre. Ici la part pure ; les deux dialogues d'Android (`choisir`, `saisir`)
/// reviendront avec les écrans. Jugée par `Tests/Vecteurs/seance.json`
/// (tools/vecteurs_ios/VecteursSeance.kt).
public enum DureeSeance {

    public static let proposees: [Int] = [5, 10, 15, 30, 60, 90]

    // Dans ce type, `min` et `max` sont ces deux bornes, non les fonctions de Swift.
    public static let min = 1
    public static let max = 240

    /// La saisie de la boîte « Durée réglable… » : le nombre s'il est entre 1 et 240 minutes, nil sinon
    /// (FACCUEIL-15). 0 ou 999 ne sont plus ramenés en silence : la boîte reste ouverte et le dit.
    public static func valide(_ texte: String) -> Int? {
        guard let valeur = entier(texte.rogne), valeur >= DureeSeance.min, valeur <= DureeSeance.max else { return nil }
        return valeur
    }

    /// Le nombre saisi, ramené entre 1 et 240 minutes ; nil si ce n'est pas un nombre.
    public static func lire(_ texte: String) -> Int? {
        guard let valeur = entier(texte.rogne) else { return nil }
        if valeur < DureeSeance.min { return DureeSeance.min }
        if valeur > DureeSeance.max { return DureeSeance.max }
        return valeur
    }

    // MARK: `toIntOrNull()` de Kotlin

    /// `String.toIntOrNull()` : un signe ASCII facultatif, puis des chiffres décimaux, ceux de toute
    /// écriture (« ٢٥ » se lit 25 comme « 25 » : le pavé numérique d'un clavier arabe, persan ou
    /// hindi écrit les siens). nil pour un texte vide, un signe seul, tout autre caractère, ou un
    /// nombre qui ne tient pas dans les 32 bits d'un `Int` de Kotlin ; `Int(…)` de Swift ne lit que
    /// les chiffres ASCII, et jusqu'à 64 bits.
    private static func entier(_ texte: String) -> Int? {
        let unites = Array(texte.utf16)
        guard let premiere = unites.first else { return nil }
        var negatif = false
        var debut = 0
        if premiere < 0x30 {
            // Avant « 0 », Kotlin n'admet qu'un signe, et il lui faut des chiffres.
            if unites.count == 1 { return nil }
            if premiere == 0x2D {
                negatif = true
            } else if premiere != 0x2B {
                return nil
            }
            debut = 1
        }
        // De −2³¹ à 2³¹ − 1 : la valeur absolue d'un nombre négatif va un cran plus loin.
        let limite: Int64 = negatif ? 2_147_483_648 : 2_147_483_647
        var valeur: Int64 = 0
        for unite in unites[debut...] {
            guard let chiffre = valeurDuChiffre(unite) else { return nil }
            valeur = valeur * 10 + Int64(chiffre)
            if valeur > limite { return nil }
        }
        return Int(negatif ? -valeur : valeur)
    }

    /// Le zéro de chaque suite de dix chiffres décimaux du plan de base d'Unicode (catégorie Nd) :
    /// ASCII, arabes, persans, n'ko, devanagari, bengalis, gurmukhi, gujaratis, oriya, tamouls, télougous,
    /// kannada, malayalam, cinghalais, thaïs, lao, tibétains, birmans (deux suites), khmers, mongols,
    /// limbu, taï lü, taï tham (deux suites), balinais, soundanais, lepcha, ol tchiki, vaï, saurashtra,
    /// kayah li, javanais, birmans taï laing, cham, meitei, pleine chasse. Hors du plan de base, Kotlin
    /// lit deux moitiés de paire et ne reconnaît aucun chiffre. Les vecteurs rejouent chaque unité du
    /// plan de base, avant et après un chiffre (Unicode 15 de Java 21).
    private static let zeros: [UInt16] = [
        0x0030, 0x0660, 0x06F0, 0x07C0, 0x0966, 0x09E6, 0x0A66, 0x0AE6, 0x0B66, 0x0BE6, 0x0C66, 0x0CE6,
        0x0D66, 0x0DE6, 0x0E50, 0x0ED0, 0x0F20, 0x1040, 0x1090, 0x17E0, 0x1810, 0x1946, 0x19D0, 0x1A80,
        0x1A90, 0x1B50, 0x1BB0, 0x1C40, 0x1C50, 0xA620, 0xA8D0, 0xA900, 0xA9D0, 0xA9F0, 0xAA50, 0xABF0,
        0xFF10,
    ]

    /// `Character.digit(unite, 10)` de Java : la valeur d'un chiffre décimal, ou nil.
    private static func valeurDuChiffre(_ unite: UInt16) -> Int? {
        for zero in zeros {
            if unite >= zero && unite - zero < 10 {
                return Int(unite - zero)
            }
        }
        return nil
    }
}
