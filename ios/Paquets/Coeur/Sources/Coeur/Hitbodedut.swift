// La hitbodedout guidée (Hitbodedut.kt d'Android) : cinq temps, et le parcours de l'un à l'autre.
// Les intitulés hébreux sont recopiés du Kotlin octet pour octet, points-voyelles compris, par
// programme et non à la main. Les chaînes et les images portent les noms d'Android : R.string.x et
// R.drawable.x deviennent « x » (Localizable.xcstrings, ios/Ressources/Images).

/// Un temps de la hitbodedout guidée.
public struct Mouvement: Sendable, Equatable {
    public let cle: String
    public let he: String
    /// La clé de son titre dans les chaînes.
    public let titre: String
    /// La clé de son invitation dans les chaînes.
    public let invite: String
    /// Le nom de son image.
    public let illustration: String
    /// D'où vient ce temps. Ils ne viennent pas tous du même endroit.
    public let source: String
}

/// Les cinq temps. Les quatre premiers sont ceux que Likoutei Moharan II, 25 énumère, dans l'ordre où
/// le chapitre les nomme ; l'action de grâce n'est pas dans ce chapitre et ne se réclame donc pas de
/// lui : elle vient du Rambam, Hilkhot Tefila I, 2, qui la place là où elle est, après la demande.
/// Les citations, et le pourquoi, sont en tête de Hitbodedut.kt.
///
/// Rien n'oblige : le guide est éteint par défaut, on passe d'un temps à l'autre quand on veut.
public enum Hitbodedut {

    /// Le chapitre d'où viennent les quatre premiers temps, dans la graphie française des données
    /// (Reference.localise la rend en anglais et en hébreu).
    public static let sourceLikoutei = "Likoutei Moharan II, 25"

    /// Celui d'où vient l'action de grâce, qui n'est pas dans ce chapitre.
    public static let sourceRambam = "Rambam, Hilkhot Tefila 1:2"

    public static let mouvements: [Mouvement] = [
        Mouvement(cle: "sihah", he: "לְפָרֵשׁ שִׂיחָתוֹ", titre: "hitbodedut_sihah",
                  invite: "hitbodedut_sihah_invite", illustration: "char_open_arms", source: sourceLikoutei),
        Mouvement(cle: "harata", he: "חֲרָטָה וּתְשׁוּבָה עַל הֶעָבָר", titre: "hitbodedut_harata",
                  invite: "hitbodedut_harata_invite", illustration: "char_thinking", source: sourceLikoutei),
        Mouvement(cle: "bakasha", he: "בַּקָּשַׁת תַחֲנוּנִים", titre: "hitbodedut_bakasha",
                  invite: "hitbodedut_bakasha_invite", illustration: "char_praying", source: sourceLikoutei),
        Mouvement(cle: "torah", he: "לַעֲשׂוֹת מֵהַתּוֹרָה תְּפִלָּה", titre: "hitbodedut_torah",
                  invite: "hitbodedut_torah_invite", illustration: "char_torah", source: sourceLikoutei),
        Mouvement(cle: "hodaa", he: "נוֹתֵן שֶׁבַח וְהוֹדָיָה", titre: "hitbodedut_hodaa",
                  invite: "hitbodedut_hodaa_invite", illustration: "char_praise", source: sourceRambam),
    ]

    /// L'indice du dernier temps.
    public static let dernier: Int = mouvements.count - 1

    /// Le temps à cet indice, ramené dans les bornes plutôt que de rompre.
    public static func mouvement(_ index: Int) -> Mouvement {
        mouvements[min(max(index, 0), dernier)]
    }

    /// `(index + 1).coerceIn(0, DERNIER)`. Kotlin le calcule sur 32 bits et déborde pour Int.MAX_VALUE
    /// (il y rend 0) ; ici rien ne déborde, et le suivant d'un indice au-delà du dernier est le dernier.
    public static func suivant(_ index: Int) -> Int {
        index >= dernier ? dernier : max(index + 1, 0)
    }

    /// `(index - 1).coerceIn(0, DERNIER)`, sans le débordement de Kotlin pour Int.MIN_VALUE (il y rend
    /// le dernier) : le précédent d'un indice en deçà du premier est le premier.
    public static func precedent(_ index: Int) -> Int {
        index <= 0 ? 0 : min(index - 1, dernier)
    }

    public static func estPremier(_ index: Int) -> Bool {
        index <= 0
    }

    public static func estDernier(_ index: Int) -> Bool {
        index >= dernier
    }
}
