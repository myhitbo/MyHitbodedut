import Foundation

/// La sauvegarde chiffrée par mot de passe (Coffre.kt d'Android, web/src/js/coffre.js du site ; audit
/// de sécurité du 12/11/2026). La clé vient du mot de passe (NFC, en UTF-8) par PBKDF2-HMAC-SHA256, le
/// texte est chiffré en AES-256-GCM, dont le sceau de 128 bits garantit aussi l'intégrité. Même format
/// sur les trois plateformes :
///
///     { "format": "myhitbodedut-chiffre", "version": 1, "kdf": "PBKDF2-HMAC-SHA256",
///       "iterations": 600000, "salt": …, "iv": …, "data": … }   salt, iv et data (chiffré puis sceau) en base64
///
/// Ni CryptoKit ni CommonCrypto n'existent sous Linux, où `Coeur` se teste : SHA-256, PBKDF2, AES et GCM
/// sont écrits ici, en Swift seul, d'après FIPS 180-4, RFC 8018, FIPS 197 et NIST SP 800-38D. Jugés par
/// `web/test/vecteur_coffre.json` (lu et réécrit octet pour octet), que Coffre.kt et coffre.js relisent.
public enum Coffre {
    public static let format = "myhitbodedut-chiffre"
    /// Celui d'Android et du site : la dérivation prend de l'ordre d'une seconde.
    public static let iterations = 600_000
    static let kdf = "PBKDF2-HMAC-SHA256"
    /// Un fichier fabriqué ne fait pas tourner le téléphone sans fin, ni ne ramène la clé à presque rien.
    static let iterationsMin = 100_000
    static let iterationsMax = 5_000_000

    /// `Coffre.estChiffre` : le fichier lu est-il une sauvegarde chiffrée ?
    public static func estChiffre(_ texte: String) -> Bool {
        guard let o = try? ObjetJSON(texte: texte) else { return false }
        return o.texte("format") == format
    }

    /// `Coffre.chiffrer` : un sel et un vecteur d'initialisation neufs à chaque appel.
    /// `iterations` ne se règle que dans les tests (100 000 au moins).
    public static func chiffrer(_ texte: String, motDePasse: String, iterations: Int = Coffre.iterations) -> String {
        var hasard = SystemRandomNumberGenerator()
        let sel = (0..<16).map { _ in UInt8.random(in: 0...255, using: &hasard) }
        let iv = (0..<12).map { _ in UInt8.random(in: 0...255, using: &hasard) }
        return chiffrer(texte, motDePasse: motDePasse, iterations: iterations, sel: sel, iv: iv)
    }

    /// Le chiffrement à sel et vecteur donnés : ce que les tests comparent au fichier du site.
    static func chiffrer(_ texte: String, motDePasse: String, iterations: Int, sel: [UInt8], iv: [UInt8]) -> String {
        let gcm = AESGCM(cle: cle(motDePasse, sel: sel, iterations: iterations))
        let (chiffre, sceau) = gcm.sceller(Array(texte.utf8), iv: iv)
        return ObjetJSON([
            ("format", .chaine(format)), ("version", .entier(1)), ("kdf", .chaine(kdf)),
            ("iterations", .entier(Int64(iterations))), ("salt", .chaine(Base64Java.coder(sel))),
            ("iv", .chaine(Base64Java.coder(iv))), ("data", .chaine(Base64Java.coder(chiffre + sceau))),
        ]).texte(indentation: 2)
    }

    /// `Coffre.dechiffrer` : le texte en clair, ou nil (mot de passe faux, fichier abîmé ou fabriqué).
    public static func dechiffrer(_ texte: String, motDePasse: String) -> String? {
        guard let r = try? ObjetJSON(texte: texte),
              r.texte("format") == format, r.entier("version") == 1, r.texte("kdf") == kdf else { return nil }
        let iterations = r.entier("iterations")
        guard (iterationsMin...iterationsMax).contains(iterations) else { return nil }
        // getString : la clé doit exister ; une autre valeur qu'une chaîne est lue comme texte.
        func octets(_ cle: String) -> [UInt8]? { r.a(cle) ? Base64Java.decoder(r.texte(cle)) : nil }
        guard let sel = octets("salt"), let iv = octets("iv"), let data = octets("data"),
              sel.count >= 16, iv.count == 12, data.count >= 16 else { return nil }
        let gcm = AESGCM(cle: cle(motDePasse, sel: sel, iterations: iterations))
        guard let clair = gcm.ouvrir(Array(data.dropLast(16)), sceau: Array(data.suffix(16)), iv: iv) else { return nil }
        // String(octets, UTF_8) de Java : une suite mal formée devient U+FFFD, sans échec.
        return String(decoding: clair, as: UTF8.self)
    }

    /// PBKDF2WithHmacSHA256 de Java sur `PBEKeySpec(motDePasse NFC)` : 256 bits.
    static func cle(_ motDePasse: String, sel: [UInt8], iterations: Int) -> [UInt8] {
        SHA256.pbkdf2(Array(motDePasse.precomposedStringWithCanonicalMapping.utf8), sel: sel, iterations: iterations)
    }
}

// MARK: - Base64

/// `java.util.Base64` (le codeur de base, celui de Coffre.kt) : l'alphabet standard, « = » de bourrage
/// à l'écriture ; à la lecture, le bourrage est facultatif, tout autre signe (blancs compris) est refusé.
enum Base64Java {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)

    static func coder(_ octets: [UInt8]) -> String {
        var sortie: [UInt8] = []
        sortie.reserveCapacity((octets.count + 2) / 3 * 4)
        var i = 0
        while i < octets.count {
            let a = UInt32(octets[i])
            let b = i + 1 < octets.count ? UInt32(octets[i + 1]) : 0
            let c = i + 2 < octets.count ? UInt32(octets[i + 2]) : 0
            let n = a << 16 | b << 8 | c
            sortie.append(alphabet[Int(n >> 18 & 63)])
            sortie.append(alphabet[Int(n >> 12 & 63)])
            sortie.append(i + 1 < octets.count ? alphabet[Int(n >> 6 & 63)] : UInt8(ascii: "="))
            sortie.append(i + 2 < octets.count ? alphabet[Int(n & 63)] : UInt8(ascii: "="))
            i += 3
        }
        return String(decoding: sortie, as: UTF8.self)
    }

    private static func valeur(_ c: UInt8) -> UInt32? {
        switch c {
        case UInt8(ascii: "A")...UInt8(ascii: "Z"): return UInt32(c - UInt8(ascii: "A"))
        case UInt8(ascii: "a")...UInt8(ascii: "z"): return UInt32(c - UInt8(ascii: "a")) + 26
        case UInt8(ascii: "0")...UInt8(ascii: "9"): return UInt32(c - UInt8(ascii: "0")) + 52
        case UInt8(ascii: "+"): return 62
        case UInt8(ascii: "/"): return 63
        default: return nil
        }
    }

    static func decoder(_ texte: String) -> [UInt8]? {
        let u = Array(texte.utf8)
        var sortie: [UInt8] = []
        var bits: UInt32 = 0
        var n = 0
        var i = 0
        while i < u.count {
            if u[i] == UInt8(ascii: "=") {
                // « xx== » ou « xxx= », et rien après.
                if n == 2, i + 2 == u.count, u[i + 1] == UInt8(ascii: "=") { break }
                if n == 3, i + 1 == u.count { break }
                return nil
            }
            guard let v = valeur(u[i]) else { return nil }
            bits = bits << 6 | v
            n += 1
            if n == 4 {
                sortie.append(UInt8(truncatingIfNeeded: bits >> 16))
                sortie.append(UInt8(truncatingIfNeeded: bits >> 8))
                sortie.append(UInt8(truncatingIfNeeded: bits))
                bits = 0
                n = 0
            }
            i += 1
        }
        switch n {
        case 0: break
        case 2: sortie.append(UInt8(truncatingIfNeeded: bits >> 4))
        case 3:
            sortie.append(UInt8(truncatingIfNeeded: bits >> 10))
            sortie.append(UInt8(truncatingIfNeeded: bits >> 2))
        default: return nil
        }
        return sortie
    }
}

// MARK: - SHA-256, HMAC, PBKDF2

/// SHA-256 (FIPS 180-4), sur des mots de 32 bits ; PBKDF2-HMAC-SHA256 (RFC 8018) pour une clé de 32
/// octets, avec les états intérieur et extérieur du HMAC calculés une fois : deux compressions par tour.
enum SHA256 {
    private static let k: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ]
    static let initial: [UInt32] = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]

    private static func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 { x >> n | x << (32 - n) }

    /// Une compression : l'état après le bloc de seize mots ; `w` est un tampon de 64 mots, réutilisé.
    static func compresser(_ etat: [UInt32], _ bloc: [UInt32], _ w: inout [UInt32]) -> [UInt32] {
        for t in 0..<16 { w[t] = bloc[t] }
        for t in 16..<64 {
            let s0 = rotr(w[t - 15], 7) ^ rotr(w[t - 15], 18) ^ (w[t - 15] >> 3)
            let s1 = rotr(w[t - 2], 17) ^ rotr(w[t - 2], 19) ^ (w[t - 2] >> 10)
            w[t] = w[t - 16] &+ s0 &+ w[t - 7] &+ s1
        }
        var a = etat[0], b = etat[1], c = etat[2], d = etat[3], e = etat[4], f = etat[5], g = etat[6], h = etat[7]
        for t in 0..<64 {
            let t1 = h &+ (rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)) &+ ((e & f) ^ (~e & g)) &+ k[t] &+ w[t]
            let t2 = (rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)) &+ ((a & b) ^ (a & c) ^ (b & c))
            h = g
            g = f
            f = e
            e = d &+ t1
            d = c
            c = b
            b = a
            a = t1 &+ t2
        }
        return [etat[0] &+ a, etat[1] &+ b, etat[2] &+ c, etat[3] &+ d, etat[4] &+ e, etat[5] &+ f, etat[6] &+ g, etat[7] &+ h]
    }

    static func mots(_ octets: ArraySlice<UInt8>) -> [UInt32] {
        var m: [UInt32] = []
        m.reserveCapacity(octets.count / 4)
        var i = octets.startIndex
        while i + 3 < octets.endIndex {
            m.append(UInt32(octets[i]) << 24 | UInt32(octets[i + 1]) << 16 | UInt32(octets[i + 2]) << 8 | UInt32(octets[i + 3]))
            i += 4
        }
        return m
    }

    static func octets(_ mots: [UInt32]) -> [UInt8] {
        mots.flatMap { [UInt8(truncatingIfNeeded: $0 >> 24), UInt8(truncatingIfNeeded: $0 >> 16),
                        UInt8(truncatingIfNeeded: $0 >> 8), UInt8(truncatingIfNeeded: $0)] }
    }

    /// Le condensé de `message`, à partir de `etat` (après `dejaLus` octets déjà compressés).
    static func hacher(_ message: [UInt8], depuis etat: [UInt32] = initial, dejaLus: Int = 0) -> [UInt32] {
        var m = message
        let bits = UInt64(dejaLus + message.count) * 8
        m.append(0x80)
        while m.count % 64 != 56 { m.append(0) }
        for decalage in stride(from: 56, through: 0, by: -8) { m.append(UInt8(truncatingIfNeeded: bits >> UInt64(decalage))) }
        var w = [UInt32](repeating: 0, count: 64)
        var e = etat
        var debut = 0
        while debut < m.count {
            e = compresser(e, mots(m[debut..<(debut + 64)]), &w)
            debut += 64
        }
        return e
    }

    /// PBKDF2-HMAC-SHA256, un seul bloc de sortie (32 octets) : T₁ = U₁ ⊕ … ⊕ Uₙ.
    static func pbkdf2(_ motDePasse: [UInt8], sel: [UInt8], iterations: Int) -> [UInt8] {
        var cle = motDePasse.count > 64 ? octets(hacher(motDePasse)) : motDePasse
        while cle.count < 64 { cle.append(0) }
        var w = [UInt32](repeating: 0, count: 64)
        let interieur = compresser(initial, mots(cle.map { $0 ^ 0x36 }[...]), &w)
        let exterieur = compresser(initial, mots(cle.map { $0 ^ 0x5c }[...]), &w)
        var u = hacher(octets(hacher(sel + [0, 0, 0, 1], depuis: interieur, dejaLus: 64)), depuis: exterieur, dejaLus: 64)
        var somme = u
        // Un message de 32 octets après le bloc de la clé : le bourrage tient dans le même bloc (768 bits).
        let fin: [UInt32] = [0x8000_0000, 0, 0, 0, 0, 0, 0, 768]
        if iterations > 1 {
            for _ in 1..<iterations {
                let dedans = compresser(interieur, u + fin, &w)
                u = compresser(exterieur, dedans + fin, &w)
                for i in 0..<8 { somme[i] ^= u[i] }
            }
        }
        return octets(somme)
    }
}

// MARK: - AES-256, GCM

/// AES-256 (FIPS 197), le chiffrement d'un bloc seulement : GCM n'en demande pas davantage.
struct AES256 {
    private static let sbox: [UInt8] = [
        0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
        0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
        0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
        0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
        0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
        0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
        0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
        0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
        0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
        0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
        0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
        0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
        0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
        0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
        0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
        0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16,
    ]

    /// Les quinze clés de tour, bout à bout (240 octets).
    private let cles: [UInt8]

    private static func xtime(_ b: UInt8) -> UInt8 { b & 0x80 != 0 ? (b << 1) ^ 0x1B : b << 1 }

    init(cle: [UInt8]) {
        precondition(cle.count == 32, "AES-256 : une clé de 32 octets")
        var w = cle
        var rcon: UInt8 = 1
        for i in 8..<60 {
            var t = Array(w[(4 * (i - 1))..<(4 * i)])
            if i % 8 == 0 {
                t = [AES256.sbox[Int(t[1])] ^ rcon, AES256.sbox[Int(t[2])], AES256.sbox[Int(t[3])], AES256.sbox[Int(t[0])]]
                rcon = AES256.xtime(rcon)
            } else if i % 8 == 4 {
                t = t.map { AES256.sbox[Int($0)] }
            }
            for j in 0..<4 { w.append(w[4 * (i - 8) + j] ^ t[j]) }
        }
        cles = w
    }

    /// L'état est rangé colonne par colonne : l'octet de la ligne r, colonne c, est en r + 4c.
    func chiffrer(_ bloc: [UInt8]) -> [UInt8] {
        var s = [UInt8](repeating: 0, count: 16)
        for i in 0..<16 { s[i] = bloc[i] ^ cles[i] }
        var t = [UInt8](repeating: 0, count: 16)
        for tour in 1...14 {
            // SubBytes et ShiftRows d'un trait : la ligne r tourne de r colonnes vers la gauche.
            for c in 0..<4 {
                for r in 0..<4 { t[r + 4 * c] = AES256.sbox[Int(s[r + 4 * ((c + r) % 4)])] }
            }
            if tour < 14 {
                // MixColumns.
                for c in 0..<4 {
                    let a0 = t[4 * c], a1 = t[4 * c + 1], a2 = t[4 * c + 2], a3 = t[4 * c + 3]
                    let x = a0 ^ a1 ^ a2 ^ a3
                    s[4 * c] = a0 ^ x ^ AES256.xtime(a0 ^ a1)
                    s[4 * c + 1] = a1 ^ x ^ AES256.xtime(a1 ^ a2)
                    s[4 * c + 2] = a2 ^ x ^ AES256.xtime(a2 ^ a3)
                    s[4 * c + 3] = a3 ^ x ^ AES256.xtime(a3 ^ a0)
                }
            } else {
                s = t
            }
            for i in 0..<16 { s[i] ^= cles[16 * tour + i] }
        }
        return s
    }
}

/// AES-256-GCM (NIST SP 800-38D) : vecteur d'initialisation de 96 bits, sans données associées,
/// sceau de 128 bits ; un bloc de 128 bits se tient en deux mots de 64 bits, de poids fort d'abord.
struct AESGCM {
    private let aes: AES256
    private let h: (UInt64, UInt64)

    init(cle: [UInt8]) {
        let a = AES256(cle: cle)
        aes = a
        h = AESGCM.moities(a.chiffrer([UInt8](repeating: 0, count: 16)))
    }

    private static func moities(_ b: [UInt8]) -> (UInt64, UInt64) {
        var hi: UInt64 = 0, lo: UInt64 = 0
        for i in 0..<8 { hi = hi << 8 | UInt64(b[i]) }
        for i in 8..<16 { lo = lo << 8 | UInt64(b[i]) }
        return (hi, lo)
    }

    private static func octets(_ x: UInt64) -> [UInt8] {
        stride(from: 56, through: 0, by: -8).map { UInt8(truncatingIfNeeded: x >> UInt64($0)) }
    }

    /// Le produit dans GF(2¹²⁸), bit de poids fort du premier octet d'abord (l'ordre de GCM).
    private static func multiplier(_ x: (UInt64, UInt64), _ y: (UInt64, UInt64)) -> (UInt64, UInt64) {
        var zh: UInt64 = 0, zl: UInt64 = 0
        var vh = y.0, vl = y.1
        for i in 0..<128 {
            let bit = i < 64 ? (x.0 >> UInt64(63 - i)) & 1 : (x.1 >> UInt64(127 - i)) & 1
            if bit == 1 {
                zh ^= vh
                zl ^= vl
            }
            let dernier = vl & 1
            vl = vl >> 1 | vh << 63
            vh >>= 1
            if dernier == 1 { vh ^= 0xE100_0000_0000_0000 }
        }
        return (zh, zl)
    }

    /// Le compteur : le vecteur suivi du numéro du bloc, sur 32 bits ; les données commencent à 2.
    private func ctr(_ donnees: [UInt8], iv: [UInt8]) -> [UInt8] {
        var sortie: [UInt8] = []
        sortie.reserveCapacity(donnees.count)
        var compteur: UInt32 = 2
        var debut = 0
        while debut < donnees.count {
            let k = aes.chiffrer(iv + [UInt8(truncatingIfNeeded: compteur >> 24), UInt8(truncatingIfNeeded: compteur >> 16),
                                       UInt8(truncatingIfNeeded: compteur >> 8), UInt8(truncatingIfNeeded: compteur)])
            let fin = min(debut + 16, donnees.count)
            for i in debut..<fin { sortie.append(donnees[i] ^ k[i - debut]) }
            compteur &+= 1
            debut = fin
        }
        return sortie
    }

    /// Le sceau du chiffré `c` : GHASH(c, longueurs) ⊕ E(K, J₀).
    private func sceau(_ c: [UInt8], iv: [UInt8]) -> [UInt8] {
        var y: (UInt64, UInt64) = (0, 0)
        var debut = 0
        while debut < c.count {
            var b = Array(c[debut..<min(debut + 16, c.count)])
            while b.count < 16 { b.append(0) }
            let m = AESGCM.moities(b)
            y = AESGCM.multiplier((y.0 ^ m.0, y.1 ^ m.1), h)
            debut += 16
        }
        // Les longueurs en bits : 0 pour les données associées, puis celle du chiffré.
        y = AESGCM.multiplier((y.0, y.1 ^ UInt64(c.count) * 8), h)
        let t0 = AESGCM.moities(aes.chiffrer(iv + [0, 0, 0, 1]))
        return AESGCM.octets(y.0 ^ t0.0) + AESGCM.octets(y.1 ^ t0.1)
    }

    func sceller(_ clair: [UInt8], iv: [UInt8]) -> (chiffre: [UInt8], sceau: [UInt8]) {
        let c = ctr(clair, iv: iv)
        return (c, sceau(c, iv: iv))
    }

    /// Le clair, ou nil si le sceau ne correspond pas (comparé en temps constant).
    func ouvrir(_ chiffre: [UInt8], sceau attendu: [UInt8], iv: [UInt8]) -> [UInt8]? {
        let s = sceau(chiffre, iv: iv)
        guard attendu.count == 16 else { return nil }
        var ecart: UInt8 = 0
        for i in 0..<16 { ecart |= s[i] ^ attendu[i] }
        return ecart == 0 ? ctr(chiffre, iv: iv) : nil
    }
}
