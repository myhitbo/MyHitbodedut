#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif
import Foundation

/// La recherche dans toute l'application (RechercheGlobale.kt) : le siddour, les livres, la halakha
/// (Yalkout Yossef, Ben Ich 'Haï) et les hilloulot, d'un seul champ ; sans voyelles, te'amim,
/// guillemets, balises ni accents, sans tenir compte de la casse.
///
/// Android relit et normalise tout à chaque frappe ; iOS interroge un index (PORTAGE.md § 2.2.10),
/// `Contenu/recherche.sqlite`, que l'export a construit avec la même normalisation
/// (tools/export_contenu/recherche.py). Les règles de résultat ne changent pas : un résultat par
/// prière ou par livre (le titre, sinon le premier bloc qui contient la recherche), 30 par sorte,
/// le même extrait. Les vecteurs du Kotlin (`vecteurs_recherche.json`) jugent les deux côtés.
public enum RechercheGlobale {

    public enum Sorte: String, Sendable, CaseIterable {
        case siddour, livre, halakha, hilloula
    }

    public struct Resultat: Sendable, Equatable, CustomStringConvertible {
        public let sorte: Sorte
        /// La prière ou le livre ; pour la halakha et les hilloulot, la recherche telle que tapée (comme Android).
        public let id: String
        public let titre: String
        public let extrait: String

        public init(sorte: Sorte, id: String, titre: String, extrait: String) {
            self.sorte = sorte
            self.id = id
            self.titre = titre
            self.extrait = extrait
        }

        public var description: String { "[\(sorte.rawValue), \(id), \(titre), \(extrait)]" }
    }

    public static let parSorte = 30

    /// Où chercher : tout, ou seulement les prières, les halakhot, les livres ou les hilloulot.
    public enum Portee: String, Sendable, CaseIterable {
        case tout, tefilot, halakhot, sefarim, hilloulot

        public var sortes: Set<Sorte> {
            switch self {
            case .tout: Set(Sorte.allCases)
            case .tefilot: [.siddour]
            case .halakhot: [.halakha]
            case .sefarim: [.livre]
            case .hilloulot: [.hilloula]
            }
        }
    }

    // MARK: Les normalisations d'Android, à la lettre

    /// Kotlin Char.isWhitespace : Character.isWhitespace ou Character.isSpaceChar.
    static func estBlanc(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0x09...0x0D, 0x1C...0x1F: return true
        default:
            switch s.properties.generalCategory {
            case .spaceSeparator, .lineSeparator, .paragraphSeparator: return true
            default: return false
            }
        }
    }

    /// String.trim() de Kotlin.
    static func trim(_ t: String) -> String {
        let s = Array(t.unicodeScalars)
        var debut = 0, fin = s.count
        while debut < fin && estBlanc(s[debut]) { debut += 1 }
        while fin > debut && estBlanc(s[fin - 1]) { fin -= 1 }
        var resultat = String.UnicodeScalarView()
        resultat.append(contentsOf: s[debut..<fin])
        return String(resultat)
    }

    /// String.isBlank() de Kotlin.
    static func estVide(_ t: String) -> Bool { t.unicodeScalars.allSatisfy(estBlanc) }

    private static func estAccent(_ v: UInt32) -> Bool { (0x0300...0x036F).contains(v) || v == 0x2019 || v == 0x2018 }
    private static func estMaqaf(_ v: UInt32) -> Bool { v == 0x05BE || v == 0x05C0 }
    /// Voyelles, te'amim et signes (U+0591…U+05C7), guillemets, apostrophe, gershayim, geresh.
    private static func estPoint(_ v: UInt32) -> Bool {
        (0x0591...0x05C7).contains(v) || v == 0x22 || v == 0x27 || v == 0x05F4 || v == 0x05F3
    }
    /// `\s` de java.util.regex sur Android, qui tourne sur ICU : la propriété White_Space (l'insécable,
    /// l'espace fine… ; pas U+001C à U+001F, que `trim` ôte pourtant aux bords).
    private static func estEspaceAndroid(_ s: Unicode.Scalar) -> Bool { s.properties.isWhitespace }

    private static func chaine(_ s: [Unicode.Scalar]) -> String {
        var v = String.UnicodeScalarView()
        v.append(contentsOf: s)
        return String(v)
    }

    /// RechercheGlobale.nu, étape par étape et dans le même ordre : décomposition (NFD), accents et
    /// apostrophes typographiques ôtés, balises `<…>` en espace, maqaf et paseq en espace, voyelles
    /// et guillemets ôtés, espaces (ceux d'Android) ramenés à un seul, bords ôtés, minuscules.
    public static func nu(_ t: String) -> String {
        let a = Array(t.decomposedStringWithCanonicalMapping.unicodeScalars).filter { !estAccent($0.value) }
        // <[^>]+> : de chaque « < », jusqu'au premier « > » qui suit, s'il y a au moins un signe entre eux.
        var prochain = [Int](repeating: -1, count: a.count + 1)
        for i in stride(from: a.count - 1, through: 0, by: -1) {
            prochain[i] = a[i] == ">" ? i : prochain[i + 1]
        }
        var b: [Unicode.Scalar] = []
        b.reserveCapacity(a.count)
        var i = 0
        while i < a.count {
            if a[i] == "<", i + 1 < a.count, prochain[i + 1] > i + 1 {
                b.append(" ")
                i = prochain[i + 1] + 1
            } else {
                b.append(a[i])
                i += 1
            }
        }
        var c: [Unicode.Scalar] = []
        c.reserveCapacity(b.count)
        var dansEspace = false
        for s in b {
            // Le maqaf et le paseq d'abord : ils sont dans la plage des points, mais valent une espace.
            if estMaqaf(s.value) || estEspaceAndroid(s) {
                if !dansEspace { c.append(" ") }
                dansEspace = true
            } else if !estPoint(s.value) {
                c.append(s)
                dansEspace = false
            }
        }
        return minuscules(trim(chaine(c)))
    }

    /// String.lowercase() de Kotlin (toLowerCase(Locale.ROOT)) : la correspondance complète de chaque
    /// signe. Le sigma final du grec n'est pas tenu ; il n'y a pas de grec dans les contenus.
    static func minuscules(_ t: String) -> String {
        var v = String.UnicodeScalarView()
        for s in t.unicodeScalars { v.append(contentsOf: s.properties.lowercaseMapping.unicodeScalars) }
        return String(v)
    }

    /// La normalisation de YalkutYosef.recherche et de Halakha.recherche : maqaf et paseq en espace,
    /// voyelles et guillemets ôtés ; ni casse, ni balises, ni espaces.
    public static func nuHalakha(_ t: String) -> String {
        chaine(t.unicodeScalars.compactMap { s in
            if estMaqaf(s.value) { return " " }
            return estPoint(s.value) ? nil : s
        })
    }

    /// Une quarantaine de caractères autour de la trouvaille, dans le texte déjà normalisé [nu] :
    /// trente avant, cinquante après, sur les unités UTF-16 comme String.substring de Kotlin.
    public static func extrait(nu t: String, _ q: String) -> String {
        let u = Array(t.utf16), w = Array(q.utf16)
        var i = 0
        if !w.isEmpty, u.count >= w.count {
            i = (0...(u.count - w.count)).first { k in u[k..<(k + w.count)].elementsEqual(w) } ?? 0
        }
        let debut = max(i - 30, 0)
        let fin = min(i + w.count + 50, u.count)
        let milieu = trim(String(decoding: u[debut..<max(fin, debut)], as: UTF16.self))
        return (debut > 0 ? "…" : "") + milieu + (i + w.count + 50 < u.count ? "…" : "")
    }

    /// Comme `extrait(nu:_:)`, d'un texte brut.
    public static func extrait(_ texte: String, _ q: String) -> String { extrait(nu: nu(texte), q) }

    /// LocalizedText.forLanguage : le français ou l'anglais s'ils sont remplis, sinon l'hébreu.
    static func pourLangue(he: String, fr: String, en: String, _ langue: String) -> String {
        switch langue {
        case "fr": estVide(fr) ? he : fr
        case "en": estVide(en) ? he : en
        default: he
        }
    }

    /// YalkutYosef.source : « ילקוט יוסף · סימן א - … · סעיף ב ».
    public static func sourceYalkut(siman: String, lettre: String) -> String {
        (["ילקוט יוסף", siman] + (lettre.isEmpty ? [] : ["סעיף \(lettre)"])).joined(separator: " · ")
    }

    /// HalakhaActivity.source : « בן איש חי · שנה ראשונה · בראשית · אות א׳ ».
    public static func sourceBenIshHai(annee: Int, numero: Int, section: String) -> String {
        ["בן איש חי", annee == 1 ? "שנה ראשונה" : "שנה שנייה", section, "אות \(Reference.lettres(numero))"]
            .joined(separator: " · ")
    }

    /// RechercheGlobale.resultatHilloula : le nom dans la langue de l'interface quand il existe ;
    /// l'hébreu, isolé (FSI … PDI), passe alors sous le nom, avec l'année.
    static func resultatHilloula(_ texte: String, he: String, fr: String?, en: String?, annee: String,
                                 langue: String) -> Resultat {
        let choisi = langue.hasPrefix("en") ? en : langue.hasPrefix("fr") ? fr : nil
        let traduit = choisi.flatMap { estVide($0) ? nil : $0 }
        let extrait = [traduit.map { _ in "\u{2068}\(he)\u{2069}" }, estVide(annee) ? nil : annee]
            .compactMap { $0 }.joined(separator: " · ")
        return Resultat(sorte: .hilloula, id: texte, titre: traduit ?? he, extrait: extrait)
    }
}

/// L'index de la recherche, ouvert en lecture seule (le fichier est dans le paquet de l'app).
public final class IndexRecherche: @unchecked Sendable {
    // @unchecked : la connexion est ouverte en mode sérialisé (SQLITE_OPEN_FULLMUTEX), chaque
    // requête prépare et libère sa propre instruction.

    public struct Erreur: Error, CustomStringConvertible {
        public let description: String
    }

    private let base: OpaquePointer

    public init(chemin: URL) throws {
        var b: OpaquePointer?
        // immutable=1 : le fichier ne change jamais ; SQLite n'y pose ni verrou ni journal.
        let uri = chemin.absoluteString + "?immutable=1"
        let code = sqlite3_open_v2(uri, &b, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_URI, nil)
        guard code == SQLITE_OK, let ouverte = b else {
            let message = b.map { String(cString: sqlite3_errmsg($0)) } ?? "code \(code)"
            sqlite3_close_v2(b)
            throw Erreur(description: "index de recherche illisible (\(chemin.path)) : \(message)")
        }
        base = ouverte
        let version = try lignes("SELECT valeur FROM meta WHERE cle = 'version'", []) { $0.texte(0) }
        guard version == ["1"] else { throw Erreur(description: "index de recherche : version \(version), 1 attendue") }
    }

    deinit { sqlite3_close_v2(base) }

    /// RechercheGlobale.chercher : [texte] tel que tapé, [langue] de l'interface, [rite] du siddour.
    public func chercher(_ texte: String, langue: String, rite: Nusah,
                         portee: RechercheGlobale.Portee = .tout) throws -> [RechercheGlobale.Resultat] {
        typealias R = RechercheGlobale
        let q = R.nu(R.trim(texte))
        guard q.utf16.count >= 2 else { return [] }
        let s = portee.sortes
        var resultats: [R.Resultat] = []
        if s.contains(.siddour) { resultats += try recueil(rite.rawValue, q, .siddour, langue) }
        if s.contains(.livre) { resultats += try recueil("livres", q, .livre, langue) }
        if s.contains(.halakha) {
            let q2 = R.nuHalakha(R.trim(texte))
            if q2.utf16.count >= 2 {
                resultats += try lignes("""
                    SELECT siman, lettre, nu_texte FROM yalkut
                    WHERE instr(nu2_texte, ?1) > 0 OR instr(nu2_siman, ?1) > 0 ORDER BY rowid LIMIT \(R.parSorte)
                    """, [q2]) {
                    R.Resultat(sorte: .halakha, id: texte, titre: R.sourceYalkut(siman: $0.texte(0), lettre: $0.texte(1)),
                               extrait: R.extrait(nu: $0.texte(2), q))
                }
                resultats += try lignes("""
                    SELECT annee, numero, section, nu_texte FROM ben_ish_hai
                    WHERE instr(nu2_texte, ?1) > 0 ORDER BY rowid LIMIT \(R.parSorte)
                    """, [q2]) {
                    R.Resultat(sorte: .halakha, id: texte,
                               titre: R.sourceBenIshHai(annee: $0.entier(0), numero: $0.entier(1), section: $0.texte(2)),
                               extrait: R.extrait(nu: $0.texte(3), q))
                }
            }
        }
        if s.contains(.hilloula) {
            resultats += try lignes("""
                SELECT he, fr, en, annee FROM hilloulot
                WHERE instr(nu_he, ?1) > 0 OR instr(nu_fr, ?1) > 0 OR instr(nu_en, ?1) > 0
                ORDER BY rang, rowid LIMIT \(R.parSorte)
                """, [q]) {
                R.resultatHilloula(texte, he: $0.texte(0), fr: $0.texteOuNil(1), en: $0.texteOuNil(2),
                                   annee: $0.texte(3), langue: langue)
            }
        }
        return resultats
    }

    /// RechercheGlobale.dansRecueil : le titre d'abord, puis le premier bloc qui contient la recherche.
    private func recueil(_ recueil: String, _ q: String, _ sorte: RechercheGlobale.Sorte,
                         _ langue: String) throws -> [RechercheGlobale.Resultat] {
        typealias R = RechercheGlobale
        // La colonne du titre dans la langue : une des trois, jamais une valeur tapée.
        let colonne = langue == "fr" ? "nu_fr" : langue == "en" ? "nu_en" : "nu_he"
        let titre = "(instr(t.nu_he, ?1) > 0 OR instr(t.\(colonne), ?1) > 0)"
        let trouves = try lignes("""
            SELECT t.id, t.titre_he, t.titre_fr, t.titre_en, \(titre),
              CASE WHEN \(titre) THEN NULL ELSE (SELECT b.nu FROM blocs b
                WHERE b.rowid BETWEEN t.debut AND t.fin AND instr(b.nu, ?1) > 0 ORDER BY b.rowid LIMIT 1) END
            FROM textes t WHERE t.recueil = ?2 ORDER BY t.rang
            """, [q, recueil], limite: R.parSorte) { l -> R.Resultat? in
            let he = l.texte(1)
            if l.entier(4) != 0 {
                let traduit = R.pourLangue(he: he, fr: l.texte(2), en: l.texte(3), langue)
                return R.Resultat(sorte: sorte, id: l.texte(0), titre: he, extrait: traduit != he ? traduit : "")
            }
            return l.texteOuNil(5).map { R.Resultat(sorte: sorte, id: l.texte(0), titre: he, extrait: R.extrait(nu: $0, q)) }
        }
        return trouves
    }

    /// Une ligne de résultat, lue colonne par colonne.
    struct Ligne {
        let instruction: OpaquePointer

        func texte(_ i: Int32) -> String { texteOuNil(i) ?? "" }

        /// Sur toute sa longueur : un texte peut porter U+0000 (un bloc du Kitsour en finit un),
        /// que `String(cString:)` prendrait pour la fin.
        func texteOuNil(_ i: Int32) -> String? {
            guard let debut = sqlite3_column_text(instruction, i) else { return nil }
            let longueur = Int(sqlite3_column_bytes(instruction, i))
            return String(decoding: UnsafeBufferPointer(start: debut, count: longueur), as: UTF8.self)
        }

        func entier(_ i: Int32) -> Int { Int(sqlite3_column_int64(instruction, i)) }
    }

    /// Exécute [sql] avec ses paramètres (?1, ?2…) et garde ce que [lire] rend de chaque ligne, nil
    /// écarté ; s'arrête à [limite] valeurs : les lignes suivantes ne sont pas calculées.
    private func lignes<T>(_ sql: String, _ parametres: [String], limite: Int = .max,
                           _ lire: (Ligne) throws -> T?) throws -> [T] {
        var i: OpaquePointer?
        guard sqlite3_prepare_v2(base, sql, -1, &i, nil) == SQLITE_OK, let instruction = i else {
            throw Erreur(description: "index de recherche : \(String(cString: sqlite3_errmsg(base)))")
        }
        defer { sqlite3_finalize(instruction) }
        // SQLITE_TRANSIENT : SQLite copie le texte, que Swift ne garde que le temps de l'appel.
        let transitoire = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (n, p) in parametres.enumerated() {
            sqlite3_bind_text(instruction, Int32(n + 1), p, -1, transitoire)
        }
        var resultat: [T] = []
        while resultat.count < limite {
            let code = sqlite3_step(instruction)
            if code == SQLITE_DONE { break }
            guard code == SQLITE_ROW else {
                throw Erreur(description: "index de recherche : \(String(cString: sqlite3_errmsg(base)))")
            }
            if let valeur = try lire(Ligne(instruction: instruction)) { resultat.append(valeur) }
        }
        return resultat
    }
}
