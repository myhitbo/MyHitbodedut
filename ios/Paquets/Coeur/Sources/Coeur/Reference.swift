import Foundation

/// Une référence de source (« Likoutei Moharan II, 25 ») dans la langue de l'interface (Reference.kt).
///
/// Les données portent la graphie française. Affichée telle quelle, elle restait française en anglais
/// et latine en hébreu, contre la règle « en hébreu, rien que de l'hébreu » (audit des traductions,
/// 28/09). Les livres cités sont peu nombreux : on remplace le nom du livre, les numéros restent.
///
/// L'anglais reprend les graphies des chaînes anglaises (Likutei, Sihot, Hayei, Shivhei) ; l'hébreu,
/// les titres usuels avec leurs guerchayim. `localise(context, ref)` d'Android, qui lit la langue de
/// l'appareil, reste à l'app : ici la langue est passée. Les littéraux hébreux sont recopiés du Kotlin
/// octet pour octet ; chaque lettre y est une seule unité UTF-16.
public enum Reference {

    private struct Livre: Sendable {
        let fr: String
        let en: String
        let he: String
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

    /// Un nombre écrit en chiffres ASCII, comme `\d` de la JVM (sans UNICODE_CHARACTER_CLASS) : les
    /// chiffres arabes ou pleine chasse ne sont pas des numéros.
    private static let paire = ExpressionReguliere("([0-9]+):([0-9]+)")
    private static let nombre = ExpressionReguliere("[0-9]+")

    /// La langue est passée plutôt que lue, pour que la règle se teste sans appareil.
    public static func localise(_ ref: String, _ langue: String) -> String {
        let cible = RegleLangue.normalise(langue)
        let anglais = cible.egalUnites("en")
        if !anglais && !cible.egalUnites("he") { return ref }
        var texte = ref
        // Chaque livre à son tour, sur le texte déjà remplacé, comme la boucle d'Android.
        for livre in livres {
            if texte.commenceParUnites(livre.fr) {
                texte = (anglais ? livre.en : livre.he) + texte.sansPremieresUnites(livre.fr.utf16.count)
            }
        }
        // L'espace avant le point-virgule est une typographie française.
        texte = texte.remplacantUnites(" ; ", par: "; ")
        // En hébreu, les numéros en lettres (choix du propriétaire, 28/09) :
        // « משלי 24:16 » devient « משלי כ״ד, ט״ז ».
        if !anglais {
            texte = paire.remplace(texte) { c in numero(c.groupes[1]) + ", " + numero(c.groupes[2]) }
            texte = nombre.remplace(texte) { c in numero(c.valeur) }
        }
        return texte
    }

    /// `toInt()` puis `lettres` : « 007 » vaut 7. Au-delà de ce qu'un entier tient, Android lèverait
    /// (NumberFormatException) ; ici les chiffres restent tels quels.
    private static func numero(_ chiffres: String) -> String {
        guard let n = Int(chiffres) else { return chiffres }
        return lettres(n)
    }

    /// Un nombre en lettres hébraïques, de 1 à 999 : כ״ה, תל״ז, ז׳. 15 et 16 s'écrivent ט״ו et ט״ז,
    /// pour ne pas former le Nom ; les nombres de `inverses` sont inversés pour ne pas former un mot de
    /// mauvais augure (Si'hot HaRan 275 s'affichait « רע״ה »). Hors de 1 … 999, ses chiffres.
    public static func lettres(_ n: Int) -> String {
        if n <= 0 || n >= 1000 { return String(n) }
        if let inverse = inverses[n] { return avecGuerchayim(Array(inverse.utf16)) }
        var b: [UInt16] = []
        var reste = n
        while reste >= 400 {
            b.append(contentsOf: "ת".utf16)
            reste -= 400
        }
        if reste >= 100 {
            b.append(centaines[reste / 100])
            reste %= 100
        }
        switch reste {
        case 15: b.append(contentsOf: "טו".utf16)
        case 16: b.append(contentsOf: "טז".utf16)
        default:
            if reste >= 10 { b.append(dizaines[reste / 10]) }
            if reste % 10 > 0 { b.append(unitesHebraiques[reste % 10]) }
        }
        if b.count == 1 { return Unites.texte(b) + "׳" }
        return avecGuerchayim(b)
    }

    /// Le guerchayim avant la dernière lettre.
    private static func avecGuerchayim(_ suite: [UInt16]) -> String {
        var avec = suite
        avec.insert(contentsOf: "״".utf16, at: avec.count - 1)
        return Unites.texte(avec)
    }

    /// Une lettre par rang, en unités UTF-16 (le rang 0 est un blanc qui ne sert pas).
    private static let unitesHebraiques: [UInt16] = Array(" אבגדהוזחט".utf16)
    private static let dizaines: [UInt16] = Array(" יכלמנסעפצ".utf16)
    private static let centaines: [UInt16] = Array(" קרש".utf16)

    /// רע, רעב, רעד, רעה, רצח, שד, שמד : l'usage les écrit à l'envers.
    private static let inverses: [Int: String] = [
        270: "ער", 272: "ערב", 274: "ערד", 275: "ערה", 298: "רחצ", 304: "דש", 344: "שדמ",
    ]

    /// Vrai si la référence est déjà dans une forme que l'anglais et l'hébreu savent rendre.
    public static func connue(_ ref: String) -> Bool {
        livres.contains { ref.commenceParUnites($0.fr) }
    }
}
