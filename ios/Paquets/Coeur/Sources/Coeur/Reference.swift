/// Les références de source (Reference.kt). Pour l'instant les nombres en lettres hébraïques, que
/// le titre d'une halakha du Ben Ich Haï porte (« אות י״ב ») ; la traduction des noms de livres
/// viendra avec les écrans qui les montrent (Contenu/tables.json, `references.livres`).
public enum Reference {

    private static let unites = Array(" אבגדהוזחט")
    private static let dizaines = Array(" יכלמנסעפצ")
    private static let centaines = Array(" קרש")

    /// רע, רעב, רעד, רעה, רצח, שד, שמד : l'usage les écrit à l'envers.
    private static let inverses: [Int: String] = [
        270: "ער", 272: "ערב", 274: "ערד", 275: "ערה", 298: "רחצ", 304: "דש", 344: "שדמ",
    ]

    /// Un nombre en lettres hébraïques, de 1 à 999 : כ״ה, תל״ז, ז׳. 15 et 16 s'écrivent ט״ו et ט״ז ;
    /// hors de 1 à 999, les chiffres. Jugé sur les 999 valeurs du Kotlin (tables.json).
    public static func lettres(_ n: Int) -> String {
        if n <= 0 || n >= 1000 { return String(n) }
        if let inverse = inverses[n] {
            var c = Array(inverse)
            c.insert("״", at: c.count - 1)
            return String(c)
        }
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
        case 15: b += ["ט", "ו"]
        case 16: b += ["ט", "ז"]
        default:
            if reste >= 10 { b.append(dizaines[reste / 10]) }
            if reste % 10 > 0 { b.append(unites[reste % 10]) }
        }
        if b.count == 1 { return String(b) + "׳" }
        b.insert("״", at: b.count - 1)
        return String(b)
    }
}
