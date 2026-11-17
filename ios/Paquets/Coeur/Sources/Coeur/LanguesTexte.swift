import Foundation

/// Les langues d'un texte à lire (LanguesTexte.kt, 04/11) : hébreu seul, français seul, anglais seul,
/// ou deux langues l'une sous l'autre. C'est un choix de lecteur, fait dans la barre de lecture ; il vaut
/// pour les textes qui ont une traduction (Tehilim, le Tikoun, Esther, Chir HaChirim, le 'hizouk). Un
/// texte sans traduction reste en hébreu, et le dit.
///
/// Par défaut, celui de la langue de l'application : l'hébreu seul en hébreu, l'hébreu et la traduction
/// en français et en anglais — la règle d'avant (RegleLangue, 22/09), inchangée tant qu'on ne choisit rien.
///
/// Restent à Android : `mode(context)`, qui lit le choix enregistré (le mode d'iOS s'en déduit par
/// `Mode(rawValue:)`, puis `defaut`), et les vues d'une traduction (`vueTraduction`, `vueMarquee`).
public enum LanguesTexte {

    /// Les six façons de lire ; la valeur brute est la clé enregistrée (`cle` d'Android).
    public enum Mode: String, Sendable, CaseIterable {
        case he
        case fr
        case en
        case heFr = "he+fr"
        case heEn = "he+en"
        case frEn = "fr+en"

        public var cle: String { rawValue }

        /// Les langues montrées, dans l'ordre.
        public var langues: [String] {
            switch self {
            case .he: ["he"]
            case .fr: ["fr"]
            case .en: ["en"]
            case .heFr: ["he", "fr"]
            case .heEn: ["he", "en"]
            case .frEn: ["fr", "en"]
            }
        }

        /// Le nom de la chaîne qui le nomme (R.string.langues_…).
        public var libelle: String {
            switch self {
            case .he: "langues_he"
            case .fr: "langues_fr"
            case .en: "langues_en"
            case .heFr: "langues_he_fr"
            case .heEn: "langues_he_en"
            case .frEn: "langues_fr_en"
            }
        }
    }

    /// Le mode d'une langue d'application, comparée telle quelle (« en-US » n'est pas « en »).
    public static func defaut(_ langueApp: String) -> Mode {
        if langueApp.egalUnites("he") || langueApp.egalUnites("iw") { return .he }
        if langueApp.egalUnites("en") { return .heEn }
        if langueApp.egalUnites("fr") { return .heFr }
        // L'espagnol et l'arabe tunisien (17/11) : les textes n'y sont pas traduits, l'hébreu seul.
        return .he
    }

    /// Les textes à montrer, dans l'ordre du mode : (langue, texte). Une traduction absente ou blanche
    /// est sautée ; s'il ne reste rien, l'hébreu seul.
    public static func textes(_ mode: Mode, _ he: String, _ fr: String?, _ en: String?) -> [(langue: String, texte: String)] {
        var tous: [(langue: String, texte: String)] = []
        for langue in mode.langues {
            if langue.egalUnites("he") {
                tous.append((langue: "he", texte: he))
            } else if langue.egalUnites("fr") {
                if let fr, !fr.estBlanc { tous.append((langue: "fr", texte: fr)) }
            } else {
                if let en, !en.estBlanc { tous.append((langue: "en", texte: en)) }
            }
        }
        if tous.isEmpty { return [(langue: "he", texte: he)] }
        return tous
    }

    /// Le mode veut une traduction que ce texte n'a pas.
    public static func manque(_ mode: Mode, aTraduction: Bool) -> Bool {
        !aTraduction && mode.langues.contains { !$0.egalUnites("he") }
    }
}
