import Foundation

// Le JSON comme le `org.json` d'Android le lit et l'écrit : la sauvegarde s'échange avec Android et
// le site (PORTAGE.md § 3.4 à 3.6), et les règles de lecture d'Android sont plus souples que celles
// de `JSONDecoder` : un nombre écrit en chaîne, un décimal tronqué, un booléen écrit « true ».
// `JSONDecoder` ne garde pas non plus l'ordre des clés, que la sauvegarde écrite doit respecter.
//
// Lecture : le JSON strict (RFC 8259), plus trois souplesses d'Android gardées parce qu'elles ne
// coûtent rien : la marque d'ordre des octets en tête, ce qui suit l'objet racine (ignoré), les
// caractères de contrôle bruts dans une chaîne. Les autres (apostrophes, clés nues, commentaires,
// nombres octaux) sont refusées : aucun des trois programmes qui écrivent la sauvegarde n'en produit.
// Jugé par `Tests/Vecteurs/socle.json`, sections « json », « jsonEcrit », « nombresLus », « nombresEcrits ».

/// Une valeur JSON. Les objets gardent l'ordre de leurs clés.
public enum JSON: Sendable, Equatable {
    case nul
    case booleen(Bool)
    /// Un nombre écrit sans fraction ni exposant, tant qu'il tient en 64 bits : `Integer` ou `Long` d'Android.
    case entier(Int64)
    /// Tout autre nombre : `Double` d'Android.
    case decimal(Double)
    case chaine(String)
    case tableau([JSON])
    case objet(ObjetJSON)
}

/// Une faute de lecture : où, en octets depuis le début du texte, et pourquoi.
public struct ErreurJSON: Error, Equatable, Sendable {
    public let position: Int
    public let raison: String
}

/// Un objet JSON : `JSONObject` d'Android, clés gardées dans l'ordre où elles ont été écrites.
public struct ObjetJSON: Sendable, Equatable {
    /// Les clés, dans l'ordre.
    public private(set) var cles: [String] = []
    private var valeurs: [String: JSON] = [:]

    public init() {}

    /// Les paires dans l'ordre. Une clé répétée garde sa première place et prend la dernière valeur, comme Android.
    public init(_ paires: [(String, JSON)]) {
        for (cle, valeur) in paires {
            self[cle] = valeur
        }
    }

    public var count: Int { cles.count }
    public var estVide: Bool { cles.isEmpty }

    /// Les paires, dans l'ordre des clés.
    public var paires: [(cle: String, valeur: JSON)] {
        cles.map { (cle: $0, valeur: valeurs[$0] ?? JSON.nul) }
    }

    /// `opt(cle)` et `put(cle, valeur)`. Une clé neuve se range à la fin ; `nil` retire la clé.
    public subscript(cle: String) -> JSON? {
        get {
            valeurs[cle]
        }
        set {
            if let nouvelle = newValue {
                if valeurs.updateValue(nouvelle, forKey: cle) == nil {
                    cles.append(cle)
                }
            } else if valeurs.removeValue(forKey: cle) != nil {
                cles.removeAll { $0 == cle }
            }
        }
    }

    // MARK: Lecture tolérante, comme org.json sur Android

    /// `has(cle)`.
    public func a(_ cle: String) -> Bool {
        valeurs[cle] != nil
    }

    /// `isNull(cle)` : la clé manque, ou vaut `null`.
    public func estNul(_ cle: String) -> Bool {
        guard let valeur = valeurs[cle] else { return true }
        return valeur == JSON.nul
    }

    /// `optInt(cle, defaut)` : un nombre (tronqué), ou une chaîne qui se lit comme un nombre.
    public func entier(_ cle: String, defaut: Int = 0) -> Int {
        guard let valeur = valeurs[cle]?.commeEntier else { return defaut }
        return Int(valeur)
    }

    /// `optLong(cle, defaut)`.
    public func long(_ cle: String, defaut: Int64 = 0) -> Int64 {
        valeurs[cle]?.commeLong ?? defaut
    }

    /// `optDouble(cle, defaut)` ; Android rend NaN par défaut.
    public func double(_ cle: String, defaut: Double = Double.nan) -> Double {
        valeurs[cle]?.commeDouble ?? defaut
    }

    /// `optBoolean(cle, defaut)` : un booléen, ou « true » et « false » écrits en chaîne, sans égard à la casse.
    public func booleen(_ cle: String, defaut: Bool = false) -> Bool {
        valeurs[cle]?.commeBooleen ?? defaut
    }

    /// `optString(cle, defaut)` : une chaîne, ou le texte de toute autre valeur. Comme sur Android,
    /// `null` rend la chaîne « null » : c'est à l'appelant de s'en garder (`Json.nullable`).
    public func texte(_ cle: String, defaut: String = "") -> String {
        valeurs[cle]?.commeTexte ?? defaut
    }

    /// `optJSONObject(cle)`.
    public func objet(_ cle: String) -> ObjetJSON? {
        if case .objet(let o)? = valeurs[cle] { return o }
        return nil
    }

    /// `optJSONArray(cle)`.
    public func tableau(_ cle: String) -> [JSON]? {
        if case .tableau(let t)? = valeurs[cle] { return t }
        return nil
    }

    /// `JSONObject(texte)` d'Android, pour du JSON strict : la racine doit être un objet ; ce qui le suit est ignoré.
    public init(texte: String) throws {
        var lecteur = LecteurJSON(texte)
        guard case .objet(let o) = try lecteur.valeur(0) else {
            throw ErreurJSON(position: 0, raison: "la racine n'est pas un objet")
        }
        self = o
    }

    /// `toString()` d'Android, ou `toString(indentation)`.
    public func texte(indentation: Int? = nil) -> String {
        JSON.objet(self).texte(indentation: indentation)
    }
}

// MARK: Conversions d'une valeur, comme org.json sur Android

extension JSON {

    /// `JSON.toInteger` : un entier (ramené à 32 bits comme le fait `intValue`), un décimal tronqué,
    /// ou une chaîne lue par `Double.parseDouble` puis tronquée.
    public var commeEntier: Int32? {
        switch self {
        case .entier(let n): return Int32(truncatingIfNeeded: n)
        case .decimal(let d): return Kotlin.versInt32(d)
        case .chaine(let s):
            guard let d = Java.parseDouble(s) else { return nil }
            return Kotlin.versInt32(d)
        case .nul, .booleen, .tableau, .objet: return nil
        }
    }

    /// `JSON.toLong`.
    public var commeLong: Int64? {
        switch self {
        case .entier(let n): return n
        case .decimal(let d): return Kotlin.versLong(d)
        case .chaine(let s):
            guard let d = Java.parseDouble(s) else { return nil }
            return Kotlin.versLong(d)
        case .nul, .booleen, .tableau, .objet: return nil
        }
    }

    /// `JSON.toDouble`.
    public var commeDouble: Double? {
        switch self {
        case .entier(let n): return Double(n)
        case .decimal(let d): return d
        case .chaine(let s): return Java.parseDouble(s)
        case .nul, .booleen, .tableau, .objet: return nil
        }
    }

    /// `JSON.toBoolean`.
    public var commeBooleen: Bool? {
        switch self {
        case .booleen(let b): return b
        case .chaine(let s):
            let minuscules = s.lowercased()
            if minuscules == "true" { return true }
            if minuscules == "false" { return false }
            return nil
        case .nul, .entier, .decimal, .tableau, .objet: return nil
        }
    }

    /// `JSON.toString` : la chaîne, ou le texte de la valeur ; `null` rend « null ».
    public var commeTexte: String {
        switch self {
        case .chaine(let s): return s
        case .nul: return "null"
        case .booleen(let b): return b ? "true" : "false"
        case .entier(let n): return String(n)
        case .decimal(let d): return Java.texte(d)
        case .tableau, .objet: return texte()
        }
    }
}

/// Les accès tolérants de `JSONArray` : un rang hors du tableau rend la valeur par défaut.
extension Array where Element == JSON {

    /// `isNull(rang)`.
    public func estNul(_ rang: Int) -> Bool {
        !indices.contains(rang) || self[rang] == JSON.nul
    }

    /// `optInt(rang, defaut)`.
    public func entier(_ rang: Int, defaut: Int = 0) -> Int {
        guard indices.contains(rang), let valeur = self[rang].commeEntier else { return defaut }
        return Int(valeur)
    }

    /// `optLong(rang, defaut)`.
    public func long(_ rang: Int, defaut: Int64 = 0) -> Int64 {
        guard indices.contains(rang), let valeur = self[rang].commeLong else { return defaut }
        return valeur
    }

    /// `optDouble(rang, defaut)`.
    public func double(_ rang: Int, defaut: Double = Double.nan) -> Double {
        guard indices.contains(rang), let valeur = self[rang].commeDouble else { return defaut }
        return valeur
    }

    /// `optBoolean(rang, defaut)`.
    public func booleen(_ rang: Int, defaut: Bool = false) -> Bool {
        guard indices.contains(rang), let valeur = self[rang].commeBooleen else { return defaut }
        return valeur
    }

    /// `optString(rang, defaut)`.
    public func texte(_ rang: Int, defaut: String = "") -> String {
        indices.contains(rang) ? self[rang].commeTexte : defaut
    }

    /// `optJSONObject(rang)`.
    public func objet(_ rang: Int) -> ObjetJSON? {
        if indices.contains(rang), case .objet(let o) = self[rang] { return o }
        return nil
    }

    /// `optJSONArray(rang)`.
    public func tableau(_ rang: Int) -> [JSON]? {
        if indices.contains(rang), case .tableau(let t) = self[rang] { return t }
        return nil
    }
}

// MARK: Lecture

extension JSON {

    /// Lit une valeur JSON qui occupe tout le texte, aux blancs près.
    public static func lire(_ texte: String) throws -> JSON {
        var lecteur = LecteurJSON(texte)
        let valeur = try lecteur.valeur(0)
        try lecteur.fin()
        return valeur
    }
}

struct LecteurJSON {
    private let octets: [UInt8]
    private var i = 0

    /// Au-delà, un fichier hostile ferait déborder la pile.
    private static let profondeurMax = 200

    init(_ texte: String) {
        octets = Array(texte.utf8)
        // Android saute la marque d'ordre des octets (U+FEFF) en tête.
        if octets.count >= 3 && octets[0] == 0xEF && octets[1] == 0xBB && octets[2] == 0xBF {
            i = 3
        }
    }

    private func erreur(_ raison: String) -> ErreurJSON {
        ErreurJSON(position: i, raison: raison)
    }

    private mutating func sauteBlancs() {
        while i < octets.count && (octets[i] == 0x20 || octets[i] == 0x09 || octets[i] == 0x0A || octets[i] == 0x0D) {
            i += 1
        }
    }

    /// Rien d'autre que des blancs jusqu'à la fin.
    mutating func fin() throws {
        sauteBlancs()
        if i < octets.count { throw erreur("texte après la valeur") }
    }

    mutating func valeur(_ profondeur: Int) throws -> JSON {
        sauteBlancs()
        guard i < octets.count else { throw erreur("fin inattendue") }
        switch octets[i] {
        case 0x7B:  // {
            return .objet(try objet(profondeur))
        case 0x5B:  // [
            return .tableau(try tableau(profondeur))
        case 0x22:  // "
            return .chaine(try chaine())
        case 0x74:  // t
            try mot("true")
            return .booleen(true)
        case 0x66:  // f
            try mot("false")
            return .booleen(false)
        case 0x6E:  // n
            try mot("null")
            return .nul
        case 0x2D, 0x30...0x39:  // - ou un chiffre
            return try nombre()
        default:
            throw erreur("valeur attendue")
        }
    }

    private mutating func mot(_ attendu: String) throws {
        let lettres = Array(attendu.utf8)
        guard i + lettres.count <= octets.count, octets[i..<(i + lettres.count)].elementsEqual(lettres) else {
            throw erreur("« \(attendu) » attendu")
        }
        i += lettres.count
    }

    private mutating func objet(_ profondeur: Int) throws -> ObjetJSON {
        guard profondeur < LecteurJSON.profondeurMax else { throw erreur("imbrication trop profonde") }
        i += 1
        var resultat = ObjetJSON()
        sauteBlancs()
        if i < octets.count && octets[i] == 0x7D {
            i += 1
            return resultat
        }
        while true {
            sauteBlancs()
            guard i < octets.count, octets[i] == 0x22 else { throw erreur("clé attendue") }
            let cle = try chaine()
            sauteBlancs()
            guard i < octets.count, octets[i] == 0x3A else { throw erreur("deux-points attendus") }
            i += 1
            resultat[cle] = try valeur(profondeur + 1)
            sauteBlancs()
            guard i < octets.count else { throw erreur("objet non fermé") }
            if octets[i] == 0x2C {
                i += 1
            } else if octets[i] == 0x7D {
                i += 1
                return resultat
            } else {
                throw erreur("virgule ou accolade attendue")
            }
        }
    }

    private mutating func tableau(_ profondeur: Int) throws -> [JSON] {
        guard profondeur < LecteurJSON.profondeurMax else { throw erreur("imbrication trop profonde") }
        i += 1
        var resultat: [JSON] = []
        sauteBlancs()
        if i < octets.count && octets[i] == 0x5D {
            i += 1
            return resultat
        }
        while true {
            resultat.append(try valeur(profondeur + 1))
            sauteBlancs()
            guard i < octets.count else { throw erreur("tableau non fermé") }
            if octets[i] == 0x2C {
                i += 1
            } else if octets[i] == 0x5D {
                i += 1
                return resultat
            } else {
                throw erreur("virgule ou crochet attendu")
            }
        }
    }

    private mutating func chaine() throws -> String {
        i += 1  // le guillemet ouvrant
        var sortie: [UInt8] = []
        while true {
            guard i < octets.count else { throw erreur("chaîne non fermée") }
            let octet = octets[i]
            i += 1
            if octet == 0x22 {
                return String(decoding: sortie, as: UTF8.self)
            }
            if octet != 0x5C {
                sortie.append(octet)
                continue
            }
            guard i < octets.count else { throw erreur("échappement inachevé") }
            let echappe = octets[i]
            i += 1
            switch echappe {
            case 0x22, 0x5C, 0x2F: sortie.append(echappe)
            case 0x62: sortie.append(0x08)
            case 0x66: sortie.append(0x0C)
            case 0x6E: sortie.append(0x0A)
            case 0x72: sortie.append(0x0D)
            case 0x74: sortie.append(0x09)
            case 0x75:
                let scalaire = try echappementUnicode()
                UTF8.encode(scalaire) { sortie.append($0) }
            default:
                throw erreur("échappement inconnu")
            }
        }
    }

    /// Après « \u » : quatre chiffres hexadécimaux, et la seconde moitié d'une paire si elle suit.
    /// Une moitié restée seule devient U+FFFD.
    private mutating func echappementUnicode() throws -> Unicode.Scalar {
        let remplacement = Unicode.Scalar(0xFFFD as UInt16) ?? "?"
        let premiere = try quatreHexa()
        if UTF16.isTrailSurrogate(premiere) { return remplacement }
        if !UTF16.isLeadSurrogate(premiere) { return Unicode.Scalar(premiere) ?? remplacement }
        guard i + 1 < octets.count, octets[i] == 0x5C, octets[i + 1] == 0x75 else { return remplacement }
        let retour = i
        i += 2
        let seconde = try quatreHexa()
        guard UTF16.isTrailSurrogate(seconde) else {
            i = retour
            return remplacement
        }
        let valeur = 0x10000 + ((UInt32(premiere) - 0xD800) << 10) + (UInt32(seconde) - 0xDC00)
        return Unicode.Scalar(valeur) ?? remplacement
    }

    private mutating func quatreHexa() throws -> UInt16 {
        guard i + 4 <= octets.count else { throw erreur("échappement \\u inachevé") }
        var valeur: UInt16 = 0
        for _ in 0..<4 {
            let octet = octets[i]
            let chiffre: UInt16
            switch octet {
            case 0x30...0x39: chiffre = UInt16(octet - 0x30)
            case 0x41...0x46: chiffre = UInt16(octet - 0x41 + 10)
            case 0x61...0x66: chiffre = UInt16(octet - 0x61 + 10)
            default: throw erreur("chiffre hexadécimal attendu")
            }
            valeur = valeur << 4 | chiffre
            i += 1
        }
        return valeur
    }

    private func chiffre(_ position: Int) -> Bool {
        position < octets.count && octets[position] >= 0x30 && octets[position] <= 0x39
    }

    private mutating func nombre() throws -> JSON {
        let debut = i
        if octets[i] == 0x2D { i += 1 }
        guard chiffre(i) else { throw erreur("chiffre attendu") }
        if octets[i] == 0x30 {
            i += 1
        } else {
            while chiffre(i) { i += 1 }
        }
        var entier = true
        if i < octets.count && octets[i] == 0x2E {
            entier = false
            i += 1
            guard chiffre(i) else { throw erreur("chiffre attendu après le point") }
            while chiffre(i) { i += 1 }
        }
        if i < octets.count && (octets[i] == 0x65 || octets[i] == 0x45) {
            entier = false
            i += 1
            if i < octets.count && (octets[i] == 0x2B || octets[i] == 0x2D) { i += 1 }
            guard chiffre(i) else { throw erreur("chiffre attendu dans l'exposant") }
            while chiffre(i) { i += 1 }
        }
        let texte = String(decoding: octets[debut..<i], as: UTF8.self)
        if entier, let n = Int64(texte) { return .entier(n) }
        guard let d = Double(texte) else { throw erreur("nombre illisible") }
        return .decimal(d)
    }
}

// MARK: Écriture

extension JSON {

    /// Le texte JSON, écrit comme `JSONObject.toString()` d'Android : sans blanc, « / » échappé.
    /// Avec `indentation`, comme `toString(indentation)` : un élément par ligne, « clé: valeur ».
    public func texte(indentation: Int? = nil) -> String {
        var sortie = ""
        let retrait = indentation.map { String(repeating: " ", count: max(0, $0)) }
        ecrire(&sortie, retrait, 0)
        return sortie
    }

    private func ecrire(_ sortie: inout String, _ retrait: String?, _ niveau: Int) {
        switch self {
        case .nul:
            sortie += "null"
        case .booleen(let b):
            sortie += b ? "true" : "false"
        case .entier(let n):
            sortie += String(n)
        case .decimal(let d):
            sortie += JSON.texteDuNombre(d)
        case .chaine(let s):
            JSON.ecrireChaine(s, &sortie)
        case .tableau(let elements):
            sortie += "["
            for (rang, element) in elements.enumerated() {
                if rang > 0 { sortie += "," }
                JSON.ligne(&sortie, retrait, niveau + 1)
                element.ecrire(&sortie, retrait, niveau + 1)
            }
            if !elements.isEmpty { JSON.ligne(&sortie, retrait, niveau) }
            sortie += "]"
        case .objet(let o):
            sortie += "{"
            for (rang, paire) in o.paires.enumerated() {
                if rang > 0 { sortie += "," }
                JSON.ligne(&sortie, retrait, niveau + 1)
                JSON.ecrireChaine(paire.cle, &sortie)
                sortie += retrait == nil ? ":" : ": "
                paire.valeur.ecrire(&sortie, retrait, niveau + 1)
            }
            if !o.estVide { JSON.ligne(&sortie, retrait, niveau) }
            sortie += "}"
        }
    }

    private static func ligne(_ sortie: inout String, _ retrait: String?, _ niveau: Int) {
        guard let retrait else { return }
        sortie += "\n"
        for _ in 0..<niveau {
            sortie += retrait
        }
    }

    /// `JSONObject.numberToString` : un décimal sans fraction s'écrit comme un entier, le zéro négatif « -0 ».
    /// Android refuse d'écrire NaN et l'infini : ils deviennent `null`.
    static func texteDuNombre(_ d: Double) -> String {
        if !d.isFinite { return "null" }
        if d == 0 && d.sign == .minus { return "-0" }
        let entier = Kotlin.versLong(d)
        if Double(entier) == d { return String(entier) }
        return Java.texte(d)
    }

    /// Une chaîne entre guillemets, échappée comme `JSONStringer` d'Android.
    static func ecrireChaine(_ texte: String, _ sortie: inout String) {
        sortie += "\""
        for scalaire in texte.unicodeScalars {
            switch scalaire.value {
            case 0x22: sortie += "\\\""
            case 0x5C: sortie += "\\\\"
            case 0x2F: sortie += "\\/"
            case 0x09: sortie += "\\t"
            case 0x08: sortie += "\\b"
            case 0x0A: sortie += "\\n"
            case 0x0D: sortie += "\\r"
            case 0x0C: sortie += "\\f"
            case 0x00...0x1F:
                let hexa = String(scalaire.value, radix: 16)
                sortie += "\\u" + String(repeating: "0", count: 4 - hexa.count) + hexa
            default:
                sortie.unicodeScalars.append(scalaire)
            }
        }
        sortie += "\""
    }
}
