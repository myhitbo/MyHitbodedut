import Foundation

// Le socle : ce que Kotlin et Java calculent autrement que Swift, là où les règles d'Android en
// dépendent. Chaque fonction est jugée par `Tests/Vecteurs/socle.json`, écrit par la JVM elle-même
// (tools/vecteurs_ios/VecteursSocle.kt) : aucune valeur attendue n'est recopiée à la main.

/// Arithmétique, arrondis et hasard de Kotlin.
public enum Kotlin {

    // MARK: Entiers

    /// `Math.floorMod` : le reste a le signe du diviseur. `%` garde celui du dividende, en Kotlin comme en Swift.
    public static func floorMod(_ a: Int, _ b: Int) -> Int {
        let reste = a % b
        return (reste != 0 && (reste < 0) != (b < 0)) ? reste + b : reste
    }

    /// `Math.floorDiv` : le quotient arrondi vers moins l'infini. `/` tronque vers zéro, en Kotlin comme en Swift.
    public static func floorDiv(_ a: Int, _ b: Int) -> Int {
        let quotient = a / b
        return (a % b != 0 && (a < 0) != (b < 0)) ? quotient - 1 : quotient
    }

    /// `String.hashCode()` de Java : sur les unités UTF-16, en 32 bits qui débordent.
    public static func hashCode(_ texte: String) -> Int32 {
        var h: Int32 = 0
        for unite in texte.utf16 {
            h = h &* 31 &+ Int32(unite)
        }
        return h
    }

    // MARK: Arrondis

    /// `Double.roundToLong()` et `Math.round(double)` : l'entier le plus proche, les demis vers plus l'infini.
    /// Swift éloigne les demis de zéro : −2,5 y donne −3, ici −2. NaN donne 0, comme `Math.round`.
    public static func arrondiLong(_ x: Double) -> Int64 {
        if x.isNaN { return 0 }
        let bas = x.rounded(.down)
        return versLong(x - bas >= 0.5 ? bas + 1 : bas)
    }

    /// `Double.roundToInt()` : comme `arrondiLong`, borné aux 32 bits d'un `Int` de Kotlin.
    public static func arrondi(_ x: Double) -> Int {
        Int(versInt32(Double(arrondiLong(x))))
    }

    /// `Math.round(float)` : le calcul se fait en simple précision, comme dans `Plaque.moyenne`.
    public static func arrondiFlottant(_ x: Float) -> Int {
        if x.isNaN { return 0 }
        let bas = x.rounded(.down)
        return Int(versInt32(Double(x - bas >= 0.5 ? bas + 1 : bas)))
    }

    /// `Double.toInt()` : vers zéro, borné à 32 bits, NaN donne 0. `Int(x)` de Swift s'arrête hors bornes.
    public static func versInt32(_ x: Double) -> Int32 {
        if x.isNaN { return 0 }
        if x >= 2_147_483_647 { return Int32.max }
        if x <= -2_147_483_648 { return Int32.min }
        return Int32(x)
    }

    /// `Double.toInt()`, rendu en `Int` de Swift.
    public static func versInt(_ x: Double) -> Int {
        Int(versInt32(x))
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

/// `kotlin.random.Random(seed)` : le générateur XorWow de Kotlin, pour retrouver sur iOS les tirages
/// qu'Android fait d'une même graine (mélange de la musique, étincelles d'un trophée).
public struct HasardKotlin: Sendable {
    private var x: Int32
    private var y: Int32
    private var z: Int32
    private var w: Int32
    private var v: Int32
    private var addend: Int32

    /// `Random(seed: Int)`.
    public init(graine: Int32) {
        self.init(graine1: graine, graine2: graine >> 31)
    }

    /// `Random(seed: Long)`.
    public init(graineLongue: Int64) {
        self.init(graine1: Int32(truncatingIfNeeded: graineLongue),
                  graine2: Int32(truncatingIfNeeded: graineLongue >> 32))
    }

    private init(graine1: Int32, graine2: Int32) {
        x = graine1
        y = graine2
        z = 0
        w = 0
        v = ~graine1
        addend = (graine1 << 10) ^ Int32(bitPattern: UInt32(bitPattern: graine2) >> 4)
        // Comme Kotlin : les 64 premiers tirages sont jetés.
        for _ in 0..<64 {
            _ = nextInt()
        }
    }

    /// `nextInt()` : 32 bits.
    public mutating func nextInt() -> Int32 {
        var t = x
        t ^= Int32(bitPattern: UInt32(bitPattern: t) >> 2)
        x = y
        y = z
        z = w
        let v0 = v
        w = v0
        t = (t ^ (t << 1)) ^ v0 ^ (v0 << 4)
        v = t
        addend = addend &+ 362_437
        return t &+ addend
    }

    /// `nextBits(n)` : les `n` bits de poids fort d'un tirage, `n` de 0 à 32.
    private mutating func nextBits(_ bits: Int) -> Int32 {
        let tirage = nextInt()
        if bits <= 0 { return 0 }
        if bits >= 32 { return tirage }
        return Int32(bitPattern: UInt32(bitPattern: tirage) >> (32 - bits))
    }

    /// `nextInt(until)` : de 0 inclus à `borne` exclue.
    public mutating func nextInt(jusqua borne: Int32) -> Int32 {
        nextInt(de: 0, jusqua: borne)
    }

    /// `nextInt(from, until)` : de `debut` inclus à `fin` exclue.
    public mutating func nextInt(de debut: Int32, jusqua fin: Int32) -> Int32 {
        precondition(fin > debut, "intervalle vide")
        let n = fin &- debut
        if n > 0 || n == Int32.min {
            let tirage: Int32
            if n & (0 &- n) == n {
                // Une puissance de deux : les bits de poids fort suffisent.
                tirage = nextBits(31 - n.leadingZeroBitCount)
            } else {
                var bits: Int32
                var valeur: Int32
                repeat {
                    bits = Int32(bitPattern: UInt32(bitPattern: nextInt()) >> 1)
                    valeur = bits % n
                } while bits &- valeur &+ (n &- 1) < 0
                tirage = valeur
            }
            return debut &+ tirage
        }
        // L'étendue dépasse 31 bits : on tire jusqu'à tomber dedans.
        while true {
            let tirage = nextInt()
            if tirage >= debut && tirage < fin { return tirage }
        }
    }

    /// `nextLong()`.
    public mutating func nextLong() -> Int64 {
        let haut = Int64(nextInt())
        let bas = Int64(nextInt())
        return (haut << 32) &+ bas
    }

    /// `nextBoolean()`.
    public mutating func nextBoolean() -> Bool {
        nextBits(1) != 0
    }

    /// `nextDouble()` : dans [0, 1[.
    public mutating func nextDouble() -> Double {
        let haut = Int64(nextBits(26))
        let bas = Int64(nextBits(27))
        return Double((haut << 27) &+ bas) / 0x1p53
    }

    /// `nextFloat()` : dans [0, 1[.
    public mutating func nextFloat() -> Float {
        Float(nextBits(24)) / 0x1p24
    }

    /// `shuffled(random)` : le mélange de Fisher-Yates tel que Kotlin l'écrit, du dernier au deuxième.
    public mutating func melange<T>(_ liste: [T]) -> [T] {
        var resultat = liste
        if resultat.count < 2 { return resultat }
        for i in stride(from: resultat.count - 1, through: 1, by: -1) {
            let j = Int(nextInt(jusqua: Int32(i + 1)))
            resultat.swapAt(i, j)
        }
        return resultat
    }

    /// `random(random)` : un élément d'une liste qui n'est pas vide.
    public mutating func tirage<T>(_ liste: [T]) -> T {
        liste[Int(nextInt(jusqua: Int32(liste.count)))]
    }
}

/// Les nombres comme Java les lit et les écrit.
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

    /// `String.format(Locale.ROOT, "%.<decimales>f", x)` : Java arrondit les demis en s'éloignant de zéro,
    /// sur l'écriture décimale la plus courte du nombre (0,15 y donne « 0.2 », 2,675 « 2.68 »), là où
    /// `String(format:)` arrondit la valeur binaire exacte (« 0.1 », « 2.67 »).
    public static func format(_ x: Double, decimales: Int) -> String {
        if x.isNaN { return "NaN" }
        if x.isInfinite { return x < 0 ? "-Infinity" : "Infinity" }
        let signe = x.sign == .minus ? "-" : ""
        let places = max(0, decimales)
        var c: [UInt8] = []
        var e = 0
        if x != 0 {
            (c, e) = chiffres(x.magnitude)
        }
        // Les chiffres gardés : ceux de la partie entière (e) et `places` chiffres de fraction.
        let gardes = e + places
        var retenus: [UInt8]
        if gardes < 0 {
            retenus = []
        } else if gardes >= c.count {
            retenus = c + [UInt8](repeating: 0, count: gardes - c.count)
        } else {
            retenus = Array(c[0..<gardes])
            if c[gardes] >= 5 {
                // Le demi monte : la retenue remonte de chiffre en chiffre.
                var k = gardes - 1
                var retenue = true
                while retenue && k >= 0 {
                    if retenus[k] == 9 {
                        retenus[k] = 0
                        k -= 1
                    } else {
                        retenus[k] += 1
                        retenue = false
                    }
                }
                if retenue {
                    retenus.insert(1, at: 0)
                    e += 1
                }
            }
        }
        // `retenus` porte e chiffres entiers (e peut être négatif ou nul) puis `places` chiffres de fraction.
        var entiers: [UInt8] = []
        var fraction: [UInt8] = []
        if e > 0 {
            entiers = Array(retenus[0..<min(e, retenus.count)])
            fraction = retenus.count > e ? Array(retenus[e...]) : []
        } else {
            fraction = [UInt8](repeating: 0, count: min(-e, places)) + retenus
        }
        if entiers.isEmpty { entiers = [0] }
        while fraction.count < places { fraction.append(0) }
        if fraction.count > places { fraction = Array(fraction[0..<places]) }
        let partieEntiere = texte(entiers[...])
        return places == 0 ? signe + partieEntiere : signe + partieEntiere + "." + texte(fraction[...])
    }
}
