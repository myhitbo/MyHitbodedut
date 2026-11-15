// Les dix repères de la hitbodedout (Tips.kt d'Android). L'écran qui les montre (TipsActivity) reste à
// Android. Les ressources portent les noms d'Android : R.string.x devient la clé « x » du catalogue
// (Localizable.xcstrings), R.drawable.x l'image « x » (ios/Ressources/Images).

/// Un conseil : son rang, son titre, son texte, et l'illustration qui lui va.
public struct Tip: Sendable, Hashable {
    public let number: Int
    /// La clé de la chaîne du titre.
    public let titleRes: String
    /// La clé de la chaîne du texte.
    public let bodyRes: String
    /// Le nom de l'image.
    public let art: String

    public init(number: Int, titleRes: String, bodyRes: String, art: String) {
        self.number = number
        self.titleRes = titleRes
        self.bodyRes = bodyRes
        self.art = art
    }
}

/// Les dix repères de la hitbodedout, dans l'ordre.
public enum Tips {

    /// Recopiés par programme de Tips.kt ; les tests les comparent entrée par entrée à `interface_a.json`.
    public static let all: [Tip] = [
        Tip(number: 1, titleRes: "tip_1_title", bodyRes: "tip_1_body", art: "char_walking"),
        Tip(number: 2, titleRes: "tip_2_title", bodyRes: "tip_2_body", art: "char_thinking"),
        Tip(number: 3, titleRes: "tip_3_title", bodyRes: "tip_3_body", art: "char_open_arms"),
        Tip(number: 4, titleRes: "tip_4_title", bodyRes: "tip_4_body", art: "char_standing_back"),
        Tip(number: 5, titleRes: "tip_5_title", bodyRes: "tip_5_body", art: "char_tehilim"),
        Tip(number: 6, titleRes: "tip_6_title", bodyRes: "tip_6_body", art: "char_writing"),
        Tip(number: 7, titleRes: "tip_7_title", bodyRes: "tip_7_body", art: "char_praise"),
        Tip(number: 8, titleRes: "tip_8_title", bodyRes: "tip_8_body", art: "char_praying"),
        Tip(number: 9, titleRes: "tip_9_title", bodyRes: "tip_9_body", art: "char_standing_back"),
        Tip(number: 10, titleRes: "tip_10_title", bodyRes: "tip_10_body", art: "char_open_arms"),
    ]
}
