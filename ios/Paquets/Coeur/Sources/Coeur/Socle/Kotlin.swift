import Foundation

// Le socle : ce que Kotlin et Java calculent autrement que Swift, là où les règles d'Android en
// dépendent. Sous-ensemble de `Socle/Kotlin.swift` de la demande de fusion #29, recopié à l'identique :
// la sauvegarde n'a besoin que de ceci. La #29, réunie à cette ligne, apporte le reste et ses vecteurs.

/// Arithmétique de Kotlin.
public enum Kotlin {

    /// `Double.toInt()` : vers zéro, borné à 32 bits, NaN donne 0. `Int(x)` de Swift s'arrête hors bornes.
    public static func versInt32(_ x: Double) -> Int32 {
        if x.isNaN { return 0 }
        if x >= 2_147_483_647 { return Int32.max }
        if x <= -2_147_483_648 { return Int32.min }
        return Int32(x)
    }

    /// `Double.toLong()` : vers zéro, borné à 64 bits, NaN donne 0.
    public static func versLong(_ x: Double) -> Int64 {
        if x.isNaN { return 0 }
        if x >= 0x1p63 { return Int64.max }
        if x < -0x1p63 { return Int64.min }
        return Int64(x)
    }

    // MARK: Blancs

    /// `Char.isWhitespace()` de Kotlin : les séparateurs d'Unicode (Zs, Zl, Zp, l'insécable comprise) et les
    /// caractères de contrôle U+0009 à U+000D et U+001C à U+001F. U+0085 n'en est pas, à la différence de Swift.
    public static func estEspace(_ unite: UInt16) -> Bool {
        switch unite {
        case 0x0009...0x000D, 0x001C...0x001F, 0x0020, 0x00A0, 0x1680, 0x2000...0x200A,
             0x2028, 0x2029, 0x202F, 0x205F, 0x3000:
            return true
        default:
            return false
        }
    }
}

public enum Java {

    /// `Double.parseDouble` : `nil` là où Java lève `NumberFormatException`.
    /// Java rogne les blancs ASCII, accepte « 1. », « .5 », « +5 », un suffixe `d` ou `f`, « NaN » et
    /// « Infinity » écrits ainsi ; il refuse « nan », « inf », les chiffres non ASCII. Les flottants
    /// hexadécimaux (« 0x1p3 »), que Java lit aussi, ne sont pas lus ici.
    public static func parseDouble(_ texte: String) -> Double? {
        let octets = Array(texte.utf8)
        var debut = 0
        var fin = octets.count
        while debut < fin && octets[debut] <= 0x20 { debut += 1 }
        while fin > debut && octets[fin - 1] <= 0x20 { fin -= 1 }
        var i = debut
        var signe = ""
        if i < fin && (octets[i] == 0x2B || octets[i] == 0x2D) {
            if octets[i] == 0x2D { signe = "-" }
            i += 1
        }
        let reste = octets[i..<fin]
        if reste.elementsEqual("NaN".utf8) { return Double.nan }
        if reste.elementsEqual("Infinity".utf8) { return signe.isEmpty ? Double.infinity : -Double.infinity }

        func chiffres() -> String {
            let depart = i
            while i < fin && octets[i] >= 0x30 && octets[i] <= 0x39 { i += 1 }
            return String(decoding: octets[depart..<i], as: UTF8.self)
        }
        let entiers = chiffres()
        var fraction = ""
        if i < fin && octets[i] == 0x2E {
            i += 1
            fraction = chiffres()
        }
        if entiers.isEmpty && fraction.isEmpty { return nil }
        var exposant = ""
        if i < fin && (octets[i] == 0x65 || octets[i] == 0x45) {
            i += 1
            var signeExposant = ""
            if i < fin && (octets[i] == 0x2B || octets[i] == 0x2D) {
                if octets[i] == 0x2D { signeExposant = "-" }
                i += 1
            }
            let valeur = chiffres()
            if valeur.isEmpty { return nil }
            exposant = "e" + signeExposant + valeur
        }
        // Le suffixe de type de Java : « 20d », « 20f ».
        if i < fin && (octets[i] == 0x64 || octets[i] == 0x44 || octets[i] == 0x66 || octets[i] == 0x46) { i += 1 }
        if i != fin { return nil }
        // Une forme que Swift lit à coup sûr : des chiffres de part et d'autre du point.
        let canonique = signe + (entiers.isEmpty ? "0" : entiers) + "." + (fraction.isEmpty ? "0" : fraction) + exposant
        return Double(canonique)
    }

    /// Les chiffres significatifs les plus courts qui redonnent `x` (fini, strictement positif), et
    /// l'exposant `e` tel que x = 0,c₁c₂…cₙ × 10ᵉ. Ce sont les chiffres de la description de Swift,
    /// les mêmes que ceux de `Double.toString` de Java (sauf pour les tout derniers sous-normaux,
    /// que Java écrit sur deux chiffres : « 4.9E-324 »).
    static func chiffres(_ x: Double) -> (chiffres: [UInt8], exposant: Int) {
        var mantisse = "\(x)"
        var exposant = 0
        if let e = mantisse.firstIndex(where: { $0 == "e" || $0 == "E" }) {
            exposant = Int(mantisse[mantisse.index(after: e)...]) ?? 0
            mantisse = String(mantisse[..<e])
        }
        var liste: [UInt8] = []
        var avantLePoint = 0
        var pointVu = false
        for octet in mantisse.utf8 {
            if octet == 0x2E {
                pointVu = true
            } else if octet >= 0x30 && octet <= 0x39 {
                liste.append(octet - 0x30)
                if !pointVu { avantLePoint += 1 }
            }
        }
        exposant += avantLePoint
        var zerosDeTete = 0
        while zerosDeTete < liste.count - 1 && liste[zerosDeTete] == 0 { zerosDeTete += 1 }
        liste.removeFirst(zerosDeTete)
        exposant -= zerosDeTete
        while liste.count > 1 && liste[liste.count - 1] == 0 { liste.removeLast() }
        return (liste, exposant)
    }

    private static func texte(_ chiffres: ArraySlice<UInt8>) -> String {
        String(decoding: chiffres.map { $0 + 0x30 }, as: UTF8.self)
    }

    /// `Double.toString` de Java : « 1000.0 », « 0.01 », « 1.0E10 », « 1.2345678901234567E19 », « -0.0 », « NaN ».
    public static func texte(_ x: Double) -> String {
        if x.isNaN { return "NaN" }
        if x.isInfinite { return x < 0 ? "-Infinity" : "Infinity" }
        let signe = x.sign == .minus ? "-" : ""
        if x == 0 { return signe + "0.0" }
        let (c, e) = chiffres(x.magnitude)
        let n = c.count
        if e > 0 && e < 8 {
            // De 1 à 9 999 999 et des poussières : l'écriture décimale, avec au moins un chiffre après le point.
            let entiers = n >= e ? texte(c[0..<e]) : texte(c[0..<n]) + String(repeating: "0", count: e - n)
            let fraction = n > e ? texte(c[e..<n]) : "0"
            return signe + entiers + "." + fraction
        }
        if e <= 0 && e > -3 {
            // De 0,001 à moins de 1.
            return signe + "0." + String(repeating: "0", count: -e) + texte(c[0..<n])
        }
        let suite = n > 1 ? texte(c[1..<n]) : "0"
        return signe + texte(c[0..<1]) + "." + suite + "E" + String(e - 1)
    }
}
