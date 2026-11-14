import Foundation

/// Les références des textes (Reference.kt). Ici, les nombres en lettres hébraïques, dont les hilloulot
/// ont besoin (tâche 11) ; la mise en forme des références viendra avec la bibliothèque (tâche 9).
public enum Reference {

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
