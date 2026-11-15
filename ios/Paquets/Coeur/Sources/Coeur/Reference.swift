import Foundation

/// Les références des textes (Reference.kt) : une référence de source (« Likoutei Moharan II, 25 ») dans la
/// langue de l'interface, et les nombres en lettres hébraïques. Les données portent la graphie française ; on
/// remplace le nom du livre, les numéros restent (en lettres en hébreu).
public enum Reference {

    private struct Livre: Sendable {
        let fr: String, en: String, he: String
    }

    /// Du plus long au plus court : « Likoutei Moharan II » avant « … I ».
    private static let livres: [Livre] = [
        Livre(fr: "Likoutei Etsot, Hit'hazkout ", en: "Likutei Etsot, Strengthening ", he: "ליקוטי עצות, התחזקות "),
        Livre(fr: "Likoutei Etsot, Hitbodedout ", en: "Likutei Etsot, Hitbodedut ", he: "ליקוטי עצות, התבודדות "),
        Livre(fr: "Likoutei Etsot, Téfila ", en: "Likutei Etsot, Prayer ", he: "ליקוטי עצות, תפילה "),
        Livre(fr: "Rambam, Hilkhot Tefila ", en: "Rambam, Hilchot Tefillah ", he: "רמב״ם, הלכות תפילה "),
        Livre(fr: "Likoutei Moharan II, ", en: "Likutei Moharan II, ", he: "ליקוטי מוהר״ן תניינא, "),
        Livre(fr: "Likoutei Moharan I, ", en: "Likutei Moharan I, ", he: "ליקוטי מוהר״ן, "),
        Livre(fr: "Likoutei Tefilot II, ", en: "Likutei Tefilot II, ", he: "ליקוטי תפילות ב, "),
        Livre(fr: "Likoutei Tefilot I, ", en: "Likutei Tefilot I, ", he: "ליקוטי תפילות א, "),
        Livre(fr: "Si'hot HaRan ", en: "Sichot HaRan ", he: "שיחות הר״ן "),
        Livre(fr: "'Hayé Moharan ", en: "Chayei Moharan ", he: "חיי מוהר״ן "),
        Livre(fr: "Chiv'hei HaRan ", en: "Shivchei HaRan ", he: "שבחי הר״ן "),
        Livre(fr: "Tehilim ", en: "Tehillim ", he: "תהילים "),
        Livre(fr: "Michlé ", en: "Mishlei ", he: "משלי "),
        Livre(fr: "Eikha ", en: "Eicha ", he: "איכה "),
        Livre(fr: "Chmouel I ", en: "I Samuel ", he: "שמואל א "),
        Livre(fr: "Yechayahou ", en: "Isaiah ", he: "ישעיהו "),
        Livre(fr: "Hochéa ", en: "Hosea ", he: "הושע "),
        Livre(fr: "Bisdei Yaar, chap. ", en: "Bisdei Yaar, ch. ", he: "בשדי יער, פרק "),
    ]

    private static let versetChiffre = ExpressionReguliere("([0-9]+):([0-9]+)")
    private static let chiffres = ExpressionReguliere("[0-9]+")

    /// La référence dans la langue passée ; en français (ou toute autre langue), telle quelle.
    public static func localise(_ ref: String, _ langue: String) -> String {
        let cible = RegleLangue.normalise(langue)
        guard cible == "en" || cible == "he" else { return ref }
        var texte = ref
        for livre in livres where texte.commenceParUnites(livre.fr) {
            texte = (cible == "en" ? livre.en : livre.he) + texte.sansPremieresUnites(livre.fr.utf16.count)
        }
        // L'espace avant le point-virgule est une typographie française.
        texte = texte.remplacantUnites(" ; ", par: "; ")
        // En hébreu, les numéros en lettres : « משלי 24:16 » devient « משלי כ״ד, ט״ז ».
        if cible == "he" {
            texte = versetChiffre.remplace(texte) { m in
                "\(lettres(Kotlin.versIntOuNil(m.groupes[1]) ?? 0)), \(lettres(Kotlin.versIntOuNil(m.groupes[2]) ?? 0))"
            }
            texte = chiffres.remplace(texte) { m in lettres(Kotlin.versIntOuNil(m.valeur) ?? 0) }
        }
        return texte
    }

    /// Vrai si la référence est déjà dans une forme que l'anglais et l'hébreu savent rendre.
    public static func connue(_ ref: String) -> Bool { livres.contains { ref.commenceParUnites($0.fr) } }

    private static let unites = Array(" אבגדהוזחט")
    private static let dizaines = Array(" יכלמנסעפצ")
    private static let centaines = Array(" קרש")

    /// רע, רעב, רעד, רעה, רצח, שד, שמד : l'usage les écrit à l'envers.
    private static let inverses: [Int: String] = [
        270: "ער", 272: "ערב", 274: "ערד", 275: "ערה",
        298: "רחצ", 304: "דש", 344: "שדמ",
    ]

    /// Un nombre en lettres hébraïques, de 1 à 999 : כ״ה, תל״ז, ז׳. 15 et 16 s'écrivent ט״ו et ט״ז, pour
    /// ne pas former le Nom ; les nombres de `inverses` sont inversés pour ne pas former un mot de mauvais
    /// augure (Si'hot HaRan 275 s'affichait « רע״ה »). Hors de 1 à 999, le nombre en chiffres.
    public static func lettres(_ n: Int) -> String {
        if n <= 0 || n >= 1000 { return String(n) }
        if let inverse = inverses[n] { return avecGuerchayim(Array(inverse)) }
        var b: [Character] = []
        var reste = n
        while reste >= 400 {
            b.append("ת")
            reste -= 400
        }
        if reste >= 100 {
            b.append(centaines[reste / 100])
            reste %= 100
        }
        switch reste {
        case 15: b.append(contentsOf: "טו")
        case 16: b.append(contentsOf: "טז")
        default:
            if reste >= 10 { b.append(dizaines[reste / 10]) }
            if reste % 10 > 0 { b.append(unites[reste % 10]) }
        }
        return b.count == 1 ? String(b) + "׳" : avecGuerchayim(b)
    }

    /// Le guerchayim (״) avant la dernière lettre.
    private static func avecGuerchayim(_ lettres: [Character]) -> String {
        var l = lettres
        l.insert("״", at: l.count - 1)
        return String(l)
    }
}
