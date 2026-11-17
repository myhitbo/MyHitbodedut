import Foundation

/// La hilloula du jour (Hilloulot.kt, demande du 11/10) : `hilloulot.json`, construit par
/// tools/hilloulot_construction.py depuis Wikipédia hébreu et החכם היומי. Avec les deux liens de la carte
/// du jour : la page du jour de החכם היומי, et la halakha du jour de halachayomit.co.il, dont le texte
/// n'est pas repris. Les biographies d'autres sources sont à part (`hilloulot_bios/<mois>.json`), pour
/// que la carte du jour reste légère.
///
/// Reste à l'app : `table(context)`, `tableComplete` et `tableCompleteOuPlusTard` (la lecture des
/// fichiers, une fois, hors du fil principal) ; ici les règles, sur une table déjà lue.
///
/// Le juge : `Tests/Vecteurs/hilloulot.json`, écrit par le code d'Android (tools/vecteurs_ios/VecteursHilloulot.kt).
public enum Hilloulot {

    /// Un tsaddik et sa hilloula.
    public struct Hilloula: Sendable, Equatable {
        public let he: String
        public let fr: String?
        public let en: String?
        public let annee: String
        /// « w » Wikipédia, « h » החכם היומי, « m » MyTzadik, « l » המאיר לארץ, « i » Hidabroot, « e » תורת אמת.
        public let sources: String
        public let doute: String?
        /// La première phrase de l'article de Wikipédia hébreu (CC BY-SA), s'il existe.
        public let description: String?
        /// Le titre de cet article.
        public let article: String?
        /// Les biographies d'autres sources, reprises avec leur accord (12/10).
        public let bios: [Bio]
        /// L'article de Hidabroot sur ce tsaddik : un lien seulement.
        public let hidabroot: String?

        public init(he: String, fr: String?, en: String?, annee: String, sources: String, doute: String?,
                    description: String? = nil, article: String? = nil, bios: [Bio] = [], hidabroot: String? = nil) {
            self.he = he
            self.fr = fr
            self.en = en
            self.annee = annee
            self.sources = sources
            self.doute = doute
            self.description = description
            self.article = article
            self.bios = bios
            self.hidabroot = hidabroot
        }

        /// `copy(bios = …)`.
        public func avec(bios: [Bio]) -> Hilloula {
            Hilloula(he: he, fr: fr, en: en, annee: annee, sources: sources, doute: doute,
                     description: description, article: article, bios: bios, hidabroot: hidabroot)
        }
    }

    /// Une biographie, mot pour mot, et sa source : « m » MyTzadik, « l » המאיר לארץ.
    public struct Bio: Sendable, Equatable {
        public let source: String
        public let texte: String
        public let lien: String?

        public init(source: String, texte: String, lien: String?) {
            self.source = source
            self.texte = texte
            self.lien = lien
        }
    }

    /// Les hilloulot de chaque clé « mois-jour » (« 7-30 », « adar2-7 »). Kotlin garde l'ordre du fichier,
    /// qu'un dictionnaire de Swift ne garde pas : `recherche` range par rang dans l'année, et à rang égal
    /// (des clés mal formées seulement) par clé.
    public typealias Table = [String: [Hilloula]]

    // MARK: Lecture

    /// La table de `hilloulot.json` : `{"jours": {"7-1": [{"he": …, "fr": …, "a": …, "s": …}, …], …}}`.
    /// Lève, comme `JSONObject` d'Android, si le texte n'est pas du JSON ou s'il y manque une clé obligatoire.
    public static func parse(_ json: String) throws -> Table {
        let racine = try ObjetJSON(texte: json)
        guard let valeurJours = racine["jours"], case .objet(let jours) = valeurJours else {
            throw ErreurJSON(position: 0, raison: "« jours » absent, ou pas un objet")
        }
        var table: Table = [:]
        for (cle, valeur) in jours.paires {
            guard case .tableau(let liste) = valeur else {
                throw ErreurJSON(position: 0, raison: "jour « \(cle) » : un tableau attendu")
            }
            var hilloulot: [Hilloula] = []
            hilloulot.reserveCapacity(liste.count)
            for element in liste {
                guard case .objet(let o) = element else {
                    throw ErreurJSON(position: 0, raison: "jour « \(cle) » : un objet attendu")
                }
                let h = try hilloula(o)
                hilloulot.append(h)
            }
            table[cle] = hilloulot
        }
        return table
    }

    /// Le même, depuis les octets du fichier (UTF-8).
    public static func parse(_ donnees: Data) throws -> Table {
        try parse(String(decoding: donnees, as: UTF8.self))
    }

    private static func hilloula(_ o: ObjetJSON) throws -> Hilloula {
        // getString("he") : toute valeur présente se lit en texte (`null` en « null ») ; absente, elle lève.
        guard let he = o["he"] else { throw ErreurJSON(position: 0, raison: "« he » absent") }
        return Hilloula(he: he.commeTexte, fr: nullable(o, "fr"), en: nullable(o, "en"), annee: o.texte("a"),
                        sources: o.texte("s"), doute: nullable(o, "d"), description: nullable(o, "t"),
                        article: nullable(o, "w"), hidabroot: nullable(o, "i"))
    }

    /// `Json.nullable` : nil pour une clé absente, `null` ou blanche ; sinon le texte de la valeur.
    private static func nullable(_ o: ObjetJSON, _ cle: String) -> String? {
        if !o.a(cle) || o.estNul(cle) { return nil }
        let valeur = o.texte(cle)
        return valeur.estBlanc ? nil : valeur
    }

    // MARK: Le jour

    /// Les clés d'un jour hébreu (`mois` de KosherJava, nissan = 1 … adar II = 13). Un « adar » sans
    /// précision se dit en Adar II les années embolismiques (Choul'han Aroukh OH 568:7) ; en Adar I pour les
    /// Ashkénazes, comme le Rema l'y note (« וכן המנהג », audit du 16/10). Un 30 absent cette année
    /// (`dernierJour` le 29), le 29.
    public static func cles(_ mois: Int, _ jour: Int, embolismique: Bool, dernierJour: Bool, ashkenaz: Bool = false) -> [String] {
        let m: [String]
        if mois == 12 && !embolismique {
            m = ["adar", "adar1", "adar2"]
        } else if mois == 12 {
            m = ashkenaz ? ["adar", "adar1"] : ["adar1"]
        } else if mois == 13 {
            m = ashkenaz ? ["adar2"] : ["adar", "adar2"]
        } else {
            m = [String(mois)]
        }
        let jours = jour == 29 && dernierJour ? [29, 30] : [jour]
        let base = m.flatMap { k in jours.map { "\(k)-\($0)" } }
        // Le 30 Adar n'existe qu'en Adar I (audit du 16/11) : une année embolismique, « adar-30 » vaut le 30 Adar I
        // dans tous les rites (Kitsour Yalkut Yosef 40:22), jamais le 29 Adar II. Une année simple, en Ashkenaz, le
        // 30 Chevat, premier jour de Roch 'Hodech Adar (Michna Beroura 568:42) ; en Edot et en Sfard, le 29 Adar.
        let trente = ["adar-30", "adar1-30"]
        if embolismique && mois == 13 { return base.filter { $0 != "adar-30" } }
        if embolismique && mois == 12 && jour == 30 && !base.contains("adar-30") { return base + ["adar-30"] }
        if !embolismique && ashkenaz && mois == 12 { return base.filter { !trente.contains($0) } }
        if !embolismique && ashkenaz && mois == 11 && jour == 30 { return base + trente }
        return base
    }

    /// L'ordre d'un jour (04/11, « très mal organisé ») : d'abord les mieux connus, ceux que le plus de
    /// sources donnent ; à nombre de sources égal, ceux dont rien n'est mis en doute, puis ceux qui ont une
    /// notice (THILLOULOT-03). À
    /// égalité, l'ordre du fichier (le tri de Kotlin est stable : le rang départage). La carte du jour en
    /// montre les cinq premiers.
    public static func duJour(_ table: Table, _ cles: [String]) -> [Hilloula] {
        let toutes = cles.flatMap { table[$0] ?? [] }
        var rangees: [(cle: (Int, Int, Int, Int), hilloula: Hilloula)] = []
        rangees.reserveCapacity(toutes.count)
        for (i, h) in toutes.enumerated() {
            rangees.append((cle: (-h.sources.utf16.count, h.doute != nil ? 1 : 0, h.description == nil ? 1 : 0, i), hilloula: h))
        }
        rangees.sort { $0.cle < $1.cle }
        return rangees.map { $0.hilloula }
    }

    /// Le rang d'une clé « mois-jour » dans l'année, de Tichri à Eloul (Adar I, puis Adar, puis Adar II).
    /// Le calcul se fait sur 32 bits, comme l'`Int` de Kotlin, débordements compris. Une clé sans tiret,
    /// qui fait lever Kotlin, prend ici le jour 0.
    public static func rangDansLAnnee(_ cle: String) -> Int {
        let p = parties(cle)
        let m = p[0]
        let j = p.count > 1 ? p[1] : ""
        let mois: Int32
        if m.egalUnites("adar1") {
            mois = 6
        } else if m.egalUnites("adar") {
            mois = 7
        } else if m.egalUnites("adar2") {
            mois = 8
        } else if let n = Int32(m) {
            mois = n >= 7 ? n &- 6 : n &+ 8
        } else {
            mois = 20
        }
        return Int(mois &* 100 &+ (Int32(j) ?? 0))
    }

    /// Cycle de Méton : 7 années embolismiques sur 19 (3, 6, 8, 11, 14, 17, 19). Sur 32 bits, comme Kotlin.
    public static func embolismique(_ annee: Int) -> Bool {
        let a = Int32(truncatingIfNeeded: annee)
        return (7 &* a &+ 1) % 19 < 7
    }

    public static func pour(_ table: Table, date: JourCivil, enIsrael: Bool, ashkenaz: Bool = false) -> [Hilloula] {
        duJour(table, clesPour(date, enIsrael: enIsrael, ashkenaz: ashkenaz))
    }

    /// Les clés de hilloulot.json d'un jour civil.
    public static func clesPour(_ date: JourCivil, enIsrael: Bool, ashkenaz: Bool = false) -> [String] {
        let j = CalendrierJuif.jour(date, enIsrael: enIsrael)
        let lendemain = CalendrierJuif.jour(date.plus(jours: 1), enIsrael: enIsrael)
        return clesDu(j, lendemain: lendemain, ashkenaz: ashkenaz)
    }

    private static func clesDu(_ j: CalendrierJuif.Jour, lendemain: CalendrierJuif.Jour, ashkenaz: Bool) -> [String] {
        cles(j.moisHebreu, j.jourHebreu, embolismique: embolismique(j.anneeHebraique),
             dernierJour: lendemain.jourHebreu == 1, ashkenaz: ashkenaz)
    }

    /// Le prochain jour civil, à partir de `depuis`, où tombe la clé (« Voir ce jour » d'un résultat de
    /// recherche, 04/11) ; trois ans au plus, pour Adar II ; nil sinon. Le lendemain d'un jour sert au jour
    /// suivant : le même calcul que `clesPour`, une fois par jour.
    public static func prochainJour(_ cle: String, depuis: JourCivil, enIsrael: Bool, ashkenaz: Bool = false) -> JourCivil? {
        var d = depuis
        var jour = CalendrierJuif.jour(d, enIsrael: enIsrael)
        for _ in 0..<(3 * 385) {
            let lendemain = CalendrierJuif.jour(d.plus(jours: 1), enIsrael: enIsrael)
            let c = clesDu(jour, lendemain: lendemain, ashkenaz: ashkenaz)
            if c.contains(where: { $0.egalUnites(cle) }) { return d }
            d = d.plus(jours: 1)
            jour = lendemain
        }
        return nil
    }

    private static let nomsDesMois: [String: String] = [
        "1": "ניסן", "2": "אייר", "3": "סיון", "4": "תמוז", "5": "אב", "6": "אלול",
        "7": "תשרי", "8": "חשון", "9": "כסלו", "10": "טבת", "11": "שבט",
        "adar": "אדר", "adar1": "אדר א׳", "adar2": "אדר ב׳",
    ]

    /// « 7-30 » → « ל׳ תשרי ». Un jour qui ne se lit pas comme un nombre, qui fait lever Kotlin, reste ici écrit tel quel.
    public static func dateDe(_ cle: String) -> String {
        let p = parties(cle)
        let m = p[0]
        let j = p.count > 1 ? p[1] : ""
        let jour = Int32(j).map { lettres(Int($0)) } ?? j
        return "\(jour) \(nomsDesMois[m] ?? m)"
    }

    // MARK: La recherche

    /// La recherche par nom, sans voyelles ni guillemets (`RechercheGlobale.nu`), dans toute l'année, de
    /// Tichri à Eloul (04/11) ; dans un même jour, l'ordre du fichier.
    public static func recherche(_ table: Table, texte: String) -> [(cle: String, hilloula: Hilloula)] {
        let q = RechercheGlobale.nu(texte.rogne)
        if q.utf16.count < 2 { return [] }
        var trouvees: [(rang: Int, cle: String, indice: Int, hilloula: Hilloula)] = []
        for (cle, liste) in table {
            let rang = rangDansLAnnee(cle)
            for (i, h) in liste.enumerated() where contient(h, q) {
                trouvees.append((rang: rang, cle: cle, indice: i, hilloula: h))
            }
        }
        trouvees.sort { a, b in
            if a.rang != b.rang { return a.rang < b.rang }
            if !a.cle.egalUnites(b.cle) { return a.cle.utf16.lexicographicallyPrecedes(b.cle.utf16) }
            return a.indice < b.indice
        }
        return trouvees.map { (cle: $0.cle, hilloula: $0.hilloula) }
    }

    /// Le nom hébreu, puis le français et l'anglais s'ils existent, contiennent `q` une fois mis à nu.
    private static func contient(_ h: Hilloula, _ q: String) -> Bool {
        if RechercheGlobale.nu(h.he).contientUnites(q) { return true }
        if let fr = h.fr, RechercheGlobale.nu(fr).contientUnites(q) { return true }
        if let en = h.en, RechercheGlobale.nu(en).contientUnites(q) { return true }
        return false
    }

    // MARK: Les liens

    /// L'article de Wikipédia hébreu : le titre, espaces en « _ », encodé comme `URLEncoder.encode(…, "UTF-8")`.
    public static func lienArticle(_ titre: String) -> String {
        let chiffres = Array("0123456789ABCDEF".utf8)
        var octets = Array("https://he.wikipedia.org/wiki/".utf8)
        for o in titre.remplacantUnites(" ", par: "_").utf8 {
            switch o {
            case 0x30...0x39, 0x41...0x5A, 0x61...0x7A, 0x2D, 0x2E, 0x5F, 0x2A:
                octets.append(o)
            case 0x20:
                octets.append(0x2B)
            default:
                octets.append(0x25)
                octets.append(chiffres[Int(o >> 4)])
                octets.append(chiffres[Int(o & 0x0F)])
            }
        }
        return String(decoding: octets, as: UTF8.self)
    }

    /// La page du jour de החכם היומי, qui prend la date civile.
    public static func lienHyomi(_ date: JourCivil) -> String {
        "https://hyomi.org.il/day.php?month1=0&dd=\(date.jour)&mm=\(date.mois)&yy=\(date.annee)"
    }

    /// La halakha du jour, dans la langue de l'application (le site a he, fr, en).
    public static func lienHalakha(_ langue: String) -> String {
        let l = langue.lowercased()
        let code: String
        if l.commenceParUnites("he") || l.commenceParUnites("iw") {
            code = "he"
        } else if l.commenceParUnites("en") || l.commenceParUnites("es") {
            // Le site n'a ni l'espagnol ni l'arabe : l'anglais pour l'un, le français, lu en Tunisie, pour l'autre.
            code = "en"
        } else {
            code = "fr"
        }
        return "https://halachayomit.co.il/\(code)/default.aspx"
    }

    // MARK: Les biographies

    /// Le fichier exporté qui porte les biographies d'une clé : un par mois (tools/export_contenu),
    /// `hilloulot_bios/7.json` pour « 7-30 ».
    public static func fichierDesBios(_ cle: String) -> String {
        "hilloulot_bios/\(parties(cle)[0]).json"
    }

    /// Les biographies d'autres sources (`hilloulot_bios`), à part pour que la carte du jour reste légère :
    /// par jour, une entrée par hilloula, dans le même ordre ; `[source, texte, lien]` chacune, ou 0. Les clés
    /// absentes du fichier gardent leurs hilloulot telles quelles : les fichiers de chaque mois s'appliquent
    /// l'un après l'autre. Lève, comme Android, si le texte n'est pas un objet JSON ou si une biographie
    /// n'est pas un tableau d'au moins deux valeurs.
    public static func avecBios(_ table: Table, _ json: String) throws -> Table {
        let bios = try ObjetJSON(texte: json)
        var complete: Table = [:]
        for (cle, liste) in table {
            guard let b = bios.tableau(cle) else {
                complete[cle] = liste
                continue
            }
            var nouvelle: [Hilloula] = []
            nouvelle.reserveCapacity(liste.count)
            for (i, h) in liste.enumerated() {
                guard let x = b.tableau(i) else {
                    nouvelle.append(h)
                    continue
                }
                var lues: [Bio] = []
                lues.reserveCapacity(x.count)
                for element in x {
                    guard case .tableau(let y) = element else {
                        throw ErreurJSON(position: 0, raison: "biographie de « \(cle) » : un tableau attendu")
                    }
                    let source = try chaine(y, 0, cle)
                    let texte = try chaine(y, 1, cle)
                    let lien = y.texte(2)
                    lues.append(Bio(source: source, texte: texte, lien: lien.estBlanc ? nil : lien))
                }
                nouvelle.append(h.avec(bios: lues))
            }
            complete[cle] = nouvelle
        }
        return complete
    }

    /// Le même, depuis les octets d'un fichier (UTF-8).
    public static func avecBios(_ table: Table, _ donnees: Data) throws -> Table {
        try avecBios(table, String(decoding: donnees, as: UTF8.self))
    }

    /// `getString(rang)` de `JSONArray` : toute valeur présente se lit en texte ; hors du tableau, il lève.
    private static func chaine(_ y: [JSON], _ rang: Int, _ cle: String) throws -> String {
        guard y.indices.contains(rang) else {
            throw ErreurJSON(position: 0, raison: "biographie de « \(cle) » : pas de valeur au rang \(rang)")
        }
        return y[rang].commeTexte
    }

    // MARK: Aides

    /// `split("-")` de Kotlin, unité par unité : les morceaux vides gardés, un au moins.
    private static func parties(_ cle: String) -> [String] {
        var resultat: [String] = []
        var courant: [UInt16] = []
        for u in cle.utf16 {
            if u == 0x2D {
                resultat.append(Unites.texte(courant))
                courant.removeAll()
            } else {
                courant.append(u)
            }
        }
        resultat.append(Unites.texte(courant))
        return resultat
    }

    /// `Reference.lettres` (Reference.kt), dont `dateDe` a seul besoin ici : un nombre de 1 à 999 en lettres
    /// hébraïques, « א׳ », « י״ד », 15 et 16 en « ט״ו », « ט״ז » ; les nombres de `inverses` à l'envers, pour
    /// ne pas former un mot de mauvais augure ; hors de 1 … 999, ses chiffres. Chaque lettre est une unité
    /// UTF-16 sans signe qui s'y joigne.
    private static func lettres(_ n: Int) -> String {
        if n <= 0 || n >= 1000 { return String(n) }
        if let inverse = inverses[n] {
            var l = Array(inverse.utf16)
            l.insert(guershayim, at: l.count - 1)
            return Unites.texte(l)
        }
        var b: [UInt16] = []
        var reste = n
        while reste >= 400 {
            b.append(0x05EA)
            reste -= 400
        }
        if reste >= 100 {
            b.append(lettresCentaines[reste / 100])
            reste %= 100
        }
        switch reste {
        case 15: b.append(contentsOf: [0x05D8, 0x05D5])
        case 16: b.append(contentsOf: [0x05D8, 0x05D6])
        default:
            if reste >= 10 { b.append(lettresDizaines[reste / 10]) }
            if reste % 10 > 0 { b.append(lettresUnites[reste % 10]) }
        }
        if b.count == 1 { return Unites.texte(b + [gueresh]) }
        b.insert(guershayim, at: b.count - 1)
        return Unites.texte(b)
    }

    /// ׳ et ״.
    private static let gueresh: UInt16 = 0x05F3
    private static let guershayim: UInt16 = 0x05F4

    private static let lettresUnites = Array(" אבגדהוזחט".utf16)
    private static let lettresDizaines = Array(" יכלמנסעפצ".utf16)
    private static let lettresCentaines = Array(" קרש".utf16)

    /// רע, רעב, רעד, רעה, רצח, שד, שמד : l'usage les écrit à l'envers.
    private static let inverses: [Int: String] = [
        270: "ער", 272: "ערב", 274: "ערד", 275: "ערה", 298: "רחצ", 304: "דש", 344: "שדמ",
    ]
}
