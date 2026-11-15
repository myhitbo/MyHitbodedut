import Foundation

// Hitbodedut.kt et QuestionsBlocage.kt : la hitbodedout guidée en cinq temps, et les questions de « Je ne sais
// pas quoi dire ». Les ressources d'Android deviennent des noms : clés du catalogue de chaînes, images de
// `ios/Ressources/Images`. Jugé par HitbodedutTests et QuestionsBlocageTests, par `tables.json` (les temps tels
// que le Kotlin les déclare) et par la section « hitbodedut » de `Tests/Vecteurs/textes.json`.

/// `Mouvement` : un temps de la hitbodedout guidée.
public struct Mouvement: Sendable, Equatable {
    public let cle: String
    public let he: String
    /// La clé du titre dans le catalogue de chaînes.
    public let titre: String
    /// La clé de l'invite dans le catalogue de chaînes.
    public let invite: String
    /// Le nom de l'image (`ios/Ressources/Images/<nom>.webp`).
    public let illustration: String
    /// D'où vient ce temps. Ils ne viennent pas tous du même endroit.
    public let source: String

    public init(cle: String, he: String, titre: String, invite: String, illustration: String, source: String) {
        self.cle = cle
        self.he = he
        self.titre = titre
        self.invite = invite
        self.illustration = illustration
        self.source = source
    }
}

/// `Hitbodedut` : la hitbodedout guidée.
///
/// Rester seul une heure devant un silence est une épreuve, et beaucoup s'arrêtent non par manque de volonté mais
/// faute de savoir par quoi continuer. Cinq temps y répondent, et ils ne sont pas inventés. Les quatre premiers
/// sont ceux que Likoutei Moharan II, 25 énumère, dans l'ordre où ce chapitre les nomme. L'action de grâce n'est
/// pas dans ce chapitre et ne se réclame donc pas de lui : elle vient de la règle générale de la prière chez le
/// Rambam, Hilkhot Tefila I, 2, qui la place précisément là, après la demande. Chaque temps porte sa propre
/// source, affichée avec lui (Hitbodedut.kt en cite les mots).
///
/// Rien ici n'oblige : le guide est éteint par défaut, on passe d'un temps à l'autre quand on veut, et on peut
/// n'en faire aucun.
public enum Hitbodedut {

    /// Le chapitre d'où viennent les quatre premiers temps. Graphie française des données, comme les références
    /// de chizuk.json : `Reference.localise` la rend en anglais et en hébreu (lot textes 2, 04/10).
    public static let sourceLikoutei = "Likoutei Moharan II, 25"

    /// Et celui d'où vient l'action de grâce, qui n'est pas dans ce chapitre.
    public static let sourceRambam = "Rambam, Hilkhot Tefila 1:2"

    public static let mouvements: [Mouvement] = [
        Mouvement(cle: "sihah", he: "לְפָרֵשׁ שִׂיחָתוֹ", titre: "hitbodedut_sihah",
                  invite: "hitbodedut_sihah_invite", illustration: "char_open_arms", source: Hitbodedut.sourceLikoutei),
        Mouvement(cle: "harata", he: "חֲרָטָה וּתְשׁוּבָה עַל הֶעָבָר", titre: "hitbodedut_harata",
                  invite: "hitbodedut_harata_invite", illustration: "char_thinking", source: Hitbodedut.sourceLikoutei),
        Mouvement(cle: "bakasha", he: "בַּקָּשַׁת תַחֲנוּנִים", titre: "hitbodedut_bakasha",
                  invite: "hitbodedut_bakasha_invite", illustration: "char_praying", source: Hitbodedut.sourceLikoutei),
        Mouvement(cle: "torah", he: "לַעֲשׂוֹת מֵהַתּוֹרָה תְּפִלָּה", titre: "hitbodedut_torah",
                  invite: "hitbodedut_torah_invite", illustration: "char_torah", source: Hitbodedut.sourceLikoutei),
        Mouvement(cle: "hodaa", he: "נוֹתֵן שֶׁבַח וְהוֹדָיָה", titre: "hitbodedut_hodaa",
                  invite: "hitbodedut_hodaa_invite", illustration: "char_praise", source: Hitbodedut.sourceRambam),
    ]

    /// `DERNIER` : l'indice du dernier temps.
    public static let dernier = Hitbodedut.mouvements.count - 1

    /// Le temps à cet indice, ramené dans les bornes plutôt que de rompre.
    public static func mouvement(_ index: Int) -> Mouvement { mouvements[borne(index)] }

    /// `(index + 1).coerceIn(0, DERNIER)`.
    public static func suivant(_ index: Int) -> Int { index >= dernier ? dernier : borne(index + 1) }

    /// `(index - 1).coerceIn(0, DERNIER)`.
    public static func precedent(_ index: Int) -> Int { index <= 0 ? 0 : borne(index - 1) }

    public static func estPremier(_ index: Int) -> Bool { index <= 0 }

    public static func estDernier(_ index: Int) -> Bool { index >= dernier }

    private static func borne(_ index: Int) -> Int { min(max(index, 0), dernier) }
}

/// `QuestionsBlocage` : « Je ne sais pas quoi dire » (propositions 3 et 15 de la feuille de route, 19/10). Au lieu
/// d'un seul texte, des questions, une à la fois.
///
/// Elles suivent « מה אומרים? » du guide du propriétaire (textes/guide_hitbodedut.md, חלק יד) : remercier,
/// raconter, dire ce qu'on ressent, demander le matériel puis le spirituel, faire son 'heshbon nefesh, demander
/// pardon, une petite décision, l'avenir, et finir en remerciant.
public enum QuestionsBlocage {

    /// `QUESTIONS` : les clés du catalogue de chaînes, dans l'ordre.
    public static let questions = [
        "question_merci", "question_raconter", "question_ressenti", "question_besoins", "question_force",
        "question_bilan", "question_pardon", "question_decision", "question_demain", "question_fin",
    ]

    /// La suivante ; après la dernière, on recommence.
    public static func suivante(_ i: Int) -> Int { i < 0 ? 0 : (i % questions.count + 1) % questions.count }
}
