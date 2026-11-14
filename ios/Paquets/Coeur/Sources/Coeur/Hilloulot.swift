import Foundation

/// La hilloula du jour (Hilloulot.kt, demande du 11/10) : `hilloulot.json`, construit par
/// tools/hilloulot_construction.py depuis Wikipédia hébreu et החכם היומי ; avec les deux liens de la carte
/// du jour, la page du jour de החכם היומי et la halakha du jour de halachayomit.co.il, dont le texte n'est
/// pas repris. Les biographies d'autres sources sont à part (`hilloulot_bios/<mois>.json`, découpé par
/// l'export) : la carte du jour reste légère. Leur lecture hors du fil principal est l'affaire de l'écran.
public enum Hilloulot {

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

        public init(he: String, fr: String? = nil, en: String? = nil, annee: String = "", sources: String = "",
                    doute: String? = nil, description: String? = nil, article: String? = nil, bios: [Bio] = [],
                    hidabroot: String? = nil) {
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

        func avec(bios: [Bio]) -> Hilloula {
            Hilloula(he: he, fr: fr, en: en, annee: annee, sources: sources, doute: doute, description: description,
                     article: article, bios: bios, hidabroot: hidabroot)
        }
    }

    /// Une biographie, mot pour mot, et sa source : « m » MyTzadik, « l » המאיר לארץ.
    public struct Bio: Sendable, Equatable {
        public let source: String
        public let texte: String
        public let lien: String?
    }

    /// Les hilloulot par clé « mois-jour », dans l'ordre du fichier.
    public struct Table: Sendable {
        public let jours: TableOrdonnee<[Hilloula]>
        /// Pour la recherche : les noms de chaque hilloula sans voyelles ni accents, clé par clé.
        let noms: [String: [(he: String, fr: String?, en: String?)]]

        public init(jours: TableOrdonnee<[Hilloula]>) {
            self.init(jours: jours, noms: jours.valeurs.mapValues { liste in
                liste.map { (he: RechercheGlobale.nu($0.he), fr: $0.fr.map(RechercheGlobale.nu), en: $0.en.map(RechercheGlobale.nu)) }
            })
        }

        init(jours: TableOrdonnee<[Hilloula]>, noms: [String: [(he: String, fr: String?, en: String?)]]) {
            self.jours = jours
            self.noms = noms
        }

        public subscript(cle: String) -> [Hilloula]? { jours[cle] }
        public var cles: [String] { jours.cles }
    }

    public static func parse(_ json: String) throws -> Table {
        let jours = try ObjetJSON(texte: json).objet("jours") ?? ObjetJSON()
        return Table(jours: TableOrdonnee(jours.cles.map { cle in
            (cle, jours.objets(cle).map { o in
                Hilloula(he: o.texte("he"), fr: o.texteOuNil("fr"), en: o.texteOuNil("en"), annee: o.texte("a"),
                         sources: o.texte("s"), doute: o.texteOuNil("d"), description: o.texteOuNil("t"),
                         article: o.texteOuNil("w"), hidabroot: o.texteOuNil("i"))
            })
        }))
    }

    /// Les clés d'un jour hébreu (`mois` de KosherJava, NISSAN = 1 … ADAR_II = 13). Un « adar » sans
    /// précision se dit en Adar II les années embolismiques (Choul'han Aroukh O.H. 568:7) ; en Adar I pour
    /// les Ashkénazes, comme le Rema l'y note (« וכן המנהג », audit du 16/10). Un 30 absent cette année
    /// (`dernierJour` le 29), le 29.
    public static func cles(mois: Int, jour: Int, embolismique: Bool, dernierJour: Bool, ashkenaz: Bool = false) -> [String] {
        let m: [String]
        if mois == 12 && !embolismique { m = ["adar", "adar1", "adar2"] }
        else if mois == 12 { m = ashkenaz ? ["adar", "adar1"] : ["adar1"] }
        else if mois == 13 { m = ashkenaz ? ["adar2"] : ["adar", "adar2"] }
        else { m = [String(mois)] }
        let jours = jour == 29 && dernierJour ? [29, 30] : [jour]
        return m.flatMap { k in jours.map { "\(k)-\($0)" } }
    }

    /// L'ordre d'un jour (04/11) : d'abord les mieux connus, ceux que le plus de sources donnent, puis ceux
    /// qui ont une notice ; ceux dont la date est mise en doute en dernier. À égalité, l'ordre du fichier.
    public static func duJour(_ table: Table, _ cles: [String]) -> [Hilloula] {
        let tous = cles.flatMap { table[$0] ?? [] }
        func ordre(_ h: Hilloula) -> (Int, Int, Int) {
            (h.doute != nil ? 1 : 0, -h.sources.utf16.count, h.description == nil ? 1 : 0)
        }
        return tous.enumerated().sorted { a, b in
            let oa = ordre(a.element), ob = ordre(b.element)
            return oa != ob ? oa < ob : a.offset < b.offset
        }.map { $0.element }
    }

    /// Le rang d'une clé « mois-jour » dans l'année, de Tichri à Eloul (Adar I, puis Adar, puis Adar II).
    public static func rangDansLAnnee(_ cle: String) -> Int {
        let parties = cle.components(separatedBy: "-")
        let m = parties[0], j = parties.count > 1 ? parties[1] : ""
        let mois: Int
        switch m {
        case "adar1": mois = 6
        case "adar": mois = 7
        case "adar2": mois = 8
        default: mois = Int(m).map { $0 >= 7 ? $0 - 6 : $0 + 8 } ?? 20
        }
        return mois * 100 + (Int(j) ?? 0)
    }

    /// Cycle de Méton : 7 années embolismiques sur 19 (3, 6, 8, 11, 14, 17, 19).
    public static func embolismique(_ annee: Int) -> Bool { (7 * annee + 1) % 19 < 7 }

    public static func pour(_ table: Table, _ date: JourCivil, enIsrael: Bool, ashkenaz: Bool = false) -> [Hilloula] {
        duJour(table, clesPour(date, enIsrael: enIsrael, ashkenaz: ashkenaz))
    }

    /// Les clés de hilloulot.json d'un jour civil. Le jour hébreu ne dépend pas du lieu : `enIsrael` est
    /// gardé pour l'appel d'Android.
    public static func clesPour(_ date: JourCivil, enIsrael: Bool, ashkenaz: Bool = false) -> [String] {
        let j = CalendrierJuif.dateJuive(date)
        let dernier = CalendrierJuif.dateJuive(date.plus(jours: 1)).jour == 1
        return cles(mois: j.mois, jour: j.jour, embolismique: embolismique(j.annee), dernierJour: dernier, ashkenaz: ashkenaz)
    }

    /// Le prochain jour civil, à partir de `depuis`, où tombe la clé (« Voir ce jour » d'un résultat de
    /// recherche, 04/11) ; trois ans au plus, pour Adar II ; nil sinon.
    public static func prochainJour(_ cle: String, depuis: JourCivil, enIsrael: Bool, ashkenaz: Bool = false) -> JourCivil? {
        (0..<(3 * 385)).lazy.map { depuis.plus(jours: $0) }
            .first { clesPour($0, enIsrael: enIsrael, ashkenaz: ashkenaz).contains(cle) }
    }

    private static let mois: [String: String] = [
        "1": "ניסן", "2": "אייר", "3": "סיון", "4": "תמוז", "5": "אב", "6": "אלול",
        "7": "תשרי", "8": "חשון", "9": "כסלו", "10": "טבת", "11": "שבט",
        "adar": "אדר", "adar1": "אדר א׳", "adar2": "אדר ב׳",
    ]

    /// « 7-30 » → « ל׳ תשרי ».
    public static func dateDe(_ cle: String) -> String {
        let parties = cle.components(separatedBy: "-")
        let m = parties[0], j = parties.count > 1 ? parties[1] : ""
        return "\(Reference.lettres(Int(j) ?? 0)) \(mois[m] ?? m)"
    }

    /// La recherche par nom, sans voyelles ni guillemets, en hébreu, en français ou en anglais, avec ou
    /// sans accents, dans toute l'année, de Tichri à Eloul (04/11).
    public static func recherche(_ table: Table, _ texte: String) -> [(cle: String, hilloula: Hilloula)] {
        let q = RechercheGlobale.nu(texte.rogne)
        if q.utf16.count < 2 { return [] }
        var trouvees: [(cle: String, hilloula: Hilloula, rang: Int)] = []
        for (cle, liste) in table.jours.paires {
            let noms = table.noms[cle] ?? []
            for (i, h) in liste.enumerated() where i < noms.count {
                let n = noms[i]
                if n.he.contientUnites(q) || (n.fr?.contientUnites(q) ?? false) || (n.en?.contientUnites(q) ?? false) {
                    trouvees.append((cle: cle, hilloula: h, rang: rangDansLAnnee(cle)))
                }
            }
        }
        // sortedBy de Kotlin : stable, à rang égal l'ordre du fichier.
        return trouvees.enumerated().sorted { a, b in
            a.element.rang != b.element.rang ? a.element.rang < b.element.rang : a.offset < b.offset
        }.map { (cle: $0.element.cle, hilloula: $0.element.hilloula) }
    }

    private static let hexadecimal = Array("0123456789ABCDEF")

    /// L'article de Wikipédia hébreu (`URLEncoder.encode` de Java, les espaces devenues « _ »).
    public static func lienArticle(_ titre: String) -> String {
        var encode = ""
        for octet in titre.replacingOccurrences(of: " ", with: "_").utf8 {
            switch octet {
            case UInt8(ascii: "a")...UInt8(ascii: "z"), UInt8(ascii: "A")...UInt8(ascii: "Z"),
                 UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "."), UInt8(ascii: "-"), UInt8(ascii: "*"), UInt8(ascii: "_"):
                encode.append(Character(Unicode.Scalar(octet)))
            case UInt8(ascii: " "):
                encode.append("+")
            default:
                encode.append("%")
                encode.append(hexadecimal[Int(octet >> 4)])
                encode.append(hexadecimal[Int(octet & 15)])
            }
        }
        return "https://he.wikipedia.org/wiki/" + encode
    }

    /// La page du jour de החכם היומי, qui prend la date civile.
    public static func lienHyomi(_ date: JourCivil) -> String {
        "https://hyomi.org.il/day.php?month1=0&dd=\(date.jour)&mm=\(date.mois)&yy=\(date.annee)"
    }

    /// La halakha du jour, dans la langue de l'application (le site a he, fr, en).
    public static func lienHalakha(_ langue: String) -> String {
        let l = langue.lowercased()
        let code = l.hasPrefix("he") || l.hasPrefix("iw") ? "he" : l.hasPrefix("en") ? "en" : "fr"
        return "https://halachayomit.co.il/\(code)/default.aspx"
    }

    /// Les biographies d'autres sources, à part pour que la carte du jour reste légère : par jour, une
    /// entrée par hilloula, dans le même ordre (`0` quand elle n'en a pas). Un fichier par mois suffit :
    /// les jours qu'il ne nomme pas restent tels quels.
    public static func avecBios(_ table: Table, _ json: String) throws -> Table {
        let bios = try ObjetJSON(texte: json)
        let jours = table.jours.transforme { cle, liste -> [Hilloula] in
            guard let b = bios.tableau(cle) else { return liste }
            return liste.enumerated().map { paire -> Hilloula in
                guard let x = b.tableau(paire.offset) else { return paire.element }
                return paire.element.avec(bios: x.indices.compactMap { j -> Bio? in
                    guard let y = x.tableau(j) else { return nil }
                    let lien = y.texte(2)
                    return Bio(source: y.texte(0), texte: y.texte(1), lien: lien.estBlanc ? nil : lien)
                })
            }
        }
        return Table(jours: jours, noms: table.noms)
    }

    /// La table du jour, lue dans les contenus exportés.
    public static func table(_ lire: LecteurContenu) throws -> Table {
        guard let donnees = try lire("hilloulot.json") else { throw ErreurContenu.absent("hilloulot.json") }
        return try parse(String(decoding: donnees, as: UTF8.self))
    }

    /// La table avec les biographies, pour l'écran des hilloulot seulement : un fichier par mois.
    public static func tableComplete(_ lire: LecteurContenu) throws -> Table {
        var t = try table(lire)
        var vus = Set<String>()
        for cle in t.cles {
            let m = cle.components(separatedBy: "-")[0]
            guard vus.insert(m).inserted, let donnees = try lire("hilloulot_bios/\(m).json") else { continue }
            t = try avecBios(t, String(decoding: donnees, as: UTF8.self))
        }
        return t
    }
}
