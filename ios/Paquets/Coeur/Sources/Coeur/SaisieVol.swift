import Foundation

/// Une heure du jour, sans date ni fuseau : `LocalTime` à la minute.
public struct HeureMinute: Sendable, Equatable, CustomStringConvertible {
    public let heure: Int
    public let minute: Int

    public init(_ heure: Int, _ minute: Int) {
        self.heure = heure
        self.minute = minute
    }

    /// « 09:40 », comme `LocalTime.toString`.
    public var description: String { String(format: "%02d:%02d", heure, minute) }
}

/// La saisie rapide d'un vol (SaisieVol.kt, 04/11) : une phrase comme on la dirait (« El Al Lyon TLV
/// demain 11h », « LY 382 de Paris à Tel Aviv le 12/11 à 9h40 », « מחר ב־11 טיסת אל על מליון לתל
/// אביב ») ou le texte d'un billet. Tout se lit sur le téléphone, sans réseau : ce qui est sûr remplit
/// le formulaire, le reste reste à saisir. Même logique que vol.js (lirePhrase).
public enum SaisieVol {

    public struct Proposition: Sendable, Equatable {
        public var numero: String?
        /// Le code IATA de la compagnie, s'il a été reconnu (numéro ou nom).
        public var compagnie: String?
        public var depart: Vol.Aeroport?
        public var arrivee: Vol.Aeroport?
        public var date: JourCivil?
        public var heureDepart: HeureMinute?
        public var heureArrivee: HeureMinute?
        /// La date d'arrivée, si le texte en donne une autre que celle du départ.
        public var dateArrivee: JourCivil?

        public var vide: Bool { numero == nil && depart == nil && arrivee == nil && date == nil && heureDepart == nil }
    }

    /// Les compagnies les plus courantes, par leur nom (latin, hébreu) → code IATA, dans l'ordre d'Android.
    public static let compagnies: [(nom: String, code: String)] = [
        ("el al", "LY"), ("elal", "LY"), ("אל על", "LY"), ("arkia", "IZ"), ("ארקיע", "IZ"), ("israir", "6H"), ("ישראייר", "6H"),
        ("air haifa", "H9"), ("air france", "AF"), ("transavia", "TO"), ("easyjet", "U2"), ("easy jet", "U2"), ("wizz", "W6"),
        ("wizz air", "W6"), ("ryanair", "FR"), ("lufthansa", "LH"), ("swiss", "LX"), ("british airways", "BA"), ("klm", "KL"),
        ("delta", "DL"), ("united", "UA"), ("american airlines", "AA"), ("turkish", "TK"), ("turkish airlines", "TK"),
        ("aegean", "A3"), ("ita", "AZ"), ("ita airways", "AZ"), ("iberia", "IB"), ("air europa", "UX"), ("emirates", "EK"),
        ("etihad", "EY"), ("flydubai", "FZ"), ("brussels airlines", "SN"), ("austrian", "OS"), ("lot", "LO"), ("air canada", "AC"),
        ("ethiopian", "ET"), ("vueling", "VY"), ("volotea", "V7"), ("tap", "TP"), ("air portugal", "TP"), ("finnair", "AY"),
        ("sas", "SK"), ("aeroflot", "SU"), ("air india", "AI"), ("cathay", "CX"), ("qatar", "QR"), ("qatar airways", "QR"),
        ("eurowings", "EW"), ("pegasus", "PC"), ("bluebird", "BZ"), ("smartwings", "QS"), ("corsair", "SS"), ("air corsica", "XK"),
        ("air senegal", "HC"), ("royal air maroc", "AT"), ("tunisair", "TU"), ("egyptair", "MS"), ("jet2", "LS"),
    ]

    /// Les villes à plusieurs aéroports : celui qu'on prend quand seule la ville est dite.
    private static let principal: [String: String] = [
        "paris": "CDG", "london": "LHR", "londres": "LHR", "new york": "JFK", "milan": "MXP", "milano": "MXP",
        "rome": "FCO", "roma": "FCO", "moscow": "SVO", "moscou": "SVO", "tokyo": "NRT", "berlin": "BER",
        "bruxelles": "BRU", "brussels": "BRU", "tel aviv": "TLV", "tel aviv yafo": "TLV", "chicago": "ORD",
        "washington": "IAD", "montreal": "YUL", "toronto": "YYZ", "istanbul": "IST", "stockholm": "ARN",
        "bangkok": "BKK", "dubai": "DXB", "lyon": "LYS", "nice": "NCE", "marseille": "MRS", "geneve": "GVA",
        "geneva": "GVA", "bale": "BSL", "basel": "BSL", "eilat": "ETM", "buenos aires": "EZE", "sao paulo": "GRU",
        "los angeles": "LAX", "miami": "MIA", "venise": "VCE", "venice": "VCE", "barcelone": "BCN", "madrid": "MAD",
        "athenes": "ATH", "athens": "ATH", "kiev": "KBP", "kyiv": "KBP", "varsovie": "WAW", "warsaw": "WAW",
        "פריז": "CDG", "לונדון": "LHR", "ניו יורק": "JFK", "תל אביב": "TLV", "אילת": "ETM", "ליון": "LYS",
        "מרסיי": "MRS", "ניס": "NCE", "רומא": "FCO", "מילאנו": "MXP", "ברלין": "BER",
    ]

    /// Les mots de trois lettres qui ne sont pas des codes d'aéroport dans une phrase.
    private static let mots: Set<String> = [
        "les", "des", "vol", "par", "sur", "pour", "une", "est", "and", "the", "for", "via", "dep", "arr", "seat", "gate",
        "you", "are", "air", "new", "bus", "car", "jet", "fly", "pax", "ref", "tax", "fee", "eur", "usd", "ils",
        "son", "ses", "mon", "mes", "ton", "nos", "vos", "aux", "pas", "que", "qui", "oui", "non", "lun", "mar", "mer",
        "jeu", "ven", "sam", "dim", "tue", "wed", "thu", "fri", "sat", "sun", "jan", "fev", "feb", "avr", "apr",
        "mai", "may", "jun", "jul", "aou", "aug", "sep", "oct", "nov", "dec", "bag", "row", "pnr", "age", "end", "all",
    ]

    private static let moisParNom: [String: Int] = [
        "janvier": 1, "janv": 1, "jan": 1, "january": 1, "ינואר": 1,
        "fevrier": 2, "fevr": 2, "fev": 2, "february": 2, "feb": 2, "פברואר": 2,
        "mars": 3, "march": 3, "מרץ": 3, "מרס": 3,
        "avril": 4, "avr": 4, "april": 4, "apr": 4, "אפריל": 4,
        "mai": 5, "may": 5, "מאי": 5,
        "juin": 6, "june": 6, "jun": 6, "יוני": 6,
        "juillet": 7, "juil": 7, "july": 7, "jul": 7, "יולי": 7,
        "aout": 8, "august": 8, "aug": 8, "אוגוסט": 8,
        "septembre": 9, "sept": 9, "sep": 9, "september": 9, "ספטמבר": 9,
        "octobre": 10, "oct": 10, "october": 10, "אוקטובר": 10,
        "novembre": 11, "nov": 11, "november": 11, "נובמבר": 11,
        "decembre": 12, "dec": 12, "december": 12, "דצמבר": 12,
    ]

    /// Le jour de la semaine, 1 = dimanche … 7 = samedi (`JourCivil.jourDeSemaine`).
    private static let joursParNom: [String: Int] = [
        "lundi": 2, "monday": 2, "שני": 2,
        "mardi": 3, "tuesday": 3, "שלישי": 3,
        "mercredi": 4, "wednesday": 4, "רביעי": 4,
        "jeudi": 5, "thursday": 5, "חמישי": 5,
        "vendredi": 6, "friday": 6, "שישי": 6,
        "samedi": 7, "saturday": 7, "שבת": 7,
        "dimanche": 1, "sunday": 1, "ראשון": 1,
    ]

    /// Les mots qui annoncent l'arrivée (« vers Lyon » ; « לתל אביב » se lit par la lettre ל), puis le départ.
    private static let vers: Set<String> = ["vers", "pour", "a", "to", "destination", "arrivee", "arrival", "arr", "→", "->"]
    private static let de: Set<String> = ["de", "depuis", "from", "depart", "departure", "dep"]

    /// `\s` de Java, sans drapeau : les six blancs ASCII.
    private static let s = "[ \\t\\n\\u000B\\f\\r]"

    private static let numeroDeVol = ExpressionReguliere(
        "(?<![a-z0-9])([a-z]{2,3}|[a-z][0-9]|[0-9][a-z])\(s)?([0-9]{1,4})([a-z]?)(?![a-z0-9:h/])"
            + "(?!\(s)?(?:jan|fe|mar|av|ap|mai|may|juin|jun|juil|jul|ao|aug|sep|oct|nov|dec))")
    private static let pasUnCode: Set<String> = ["a", "le", "la", "de", "du", "au", "et", "on", "at", "ב", "the"]
    private static let marques = ExpressionReguliere("\\p{M}")

    public static func lire(_ texte: String, aeroports: [Vol.Aeroport], aujourdhui: JourCivil) -> Proposition {
        let plie = Aeroports.plier(texte.replacingOccurrences(of: "→", with: " → ").replacingOccurrences(of: "->", with: " → ")
            .replacingOccurrences(of: "✈", with: " "))
        let mots = plie.components(separatedBy: " ").filter { !$0.isEmpty }

        // Le numéro de vol : deux caractères (ou trois lettres) puis 1 à 4 chiffres, collés ou non.
        var numero: String?
        for m in numeroDeVol.toutes(plie) {
            let code = m.groupes[1]
            // « à 11 », « le 12 » ne sont pas des numéros de vol.
            if pasUnCode.contains(code) || SaisieVol.mots.contains(code) { continue }
            let brut = code + m.groupes[2] + m.groupes[3]
            if RouteVol.normaliser(brut) != nil {
                numero = brut.uppercased()
                break
            }
        }

        var compagnie = numero.flatMap { RouteVol.normaliser($0)?.code }.flatMap { $0.utf16.count == 2 ? $0 : nil }
        if compagnie == nil {
            // sortedByDescending sur la longueur du nom : stable, à longueur égale l'ordre de la liste.
            let parLongueur = compagnies.enumerated().sorted {
                ($0.element.nom.utf16.count, -$0.offset) > ($1.element.nom.utf16.count, -$1.offset)
            }
            compagnie = parLongueur.first { contientMot(plie, Aeroports.plier($0.element.nom)) }?.element.code
        }

        let (depart, arrivee) = trouverAeroports(mots, aeroports, numero)
        let leger = marques.remplace(texte.formeNFD, par: "").lowercased()
        let (date, dateArrivee) = dates(plie, leger, mots, aujourdhui)
        let h = heures(leger)
        return Proposition(numero: numero, compagnie: compagnie, depart: depart, arrivee: arrivee, date: date,
                           heureDepart: h.first, heureArrivee: h.count > 1 ? h[1] : nil, dateArrivee: dateArrivee)
    }

    private static func contientMot(_ texte: String, _ mot: String) -> Bool {
        ExpressionReguliere("(^|\(s))" + NSRegularExpression.escapedPattern(for: mot) + "(\(s)|$)").presente(dans: texte)
    }

    private struct Trouve: Equatable {
        let a: Vol.Aeroport
        let pos: Int
        /// -1 départ, 1 arrivée, 0 inconnu.
        let role: Int
    }

    /// Les aéroports dans l'ordre où ils sont dits ; « de X », « vers Y », « ל־Y », « מ־X » l'emportent sur
    /// l'ordre. On essaie les groupes de trois, deux puis un mot.
    private static func trouverAeroports(_ mots: [String], _ aeroports: [Vol.Aeroport], _ numero: String?) -> (Vol.Aeroport?, Vol.Aeroport?) {
        var trouves: [Trouve] = []
        var pris = [Bool](repeating: false, count: mots.count)
        for n in stride(from: 3, through: 1, by: -1) where mots.count >= n {
            for i in 0...(mots.count - n) {
                if (i..<(i + n)).contains(where: { pris[$0] }) { continue }
                var gram = mots[i..<(i + n)].joined(separator: " ")
                var role = 0
                // L'hébreu colle « מ » (de) et « ל » (vers) au nom : on essaie sans.
                var a = trouver(gram, aeroports, n)
                if a == nil && (gram.commenceParUnites("מ") || gram.commenceParUnites("ל")) {
                    a = trouver(gram.sansPremieresUnites(1), aeroports, n)
                    if a != nil { role = gram.commenceParUnites("ל") ? 1 : -1 }
                    gram = gram.sansPremieresUnites(1)
                }
                guard let aeroport = a else { continue }
                if let numero, gram.lowercased() == numero.lowercased() { continue }
                if role == 0, i > 0 {
                    let avant = mots[i - 1]
                    role = vers.contains(avant) ? 1 : de.contains(avant) ? -1 : 0
                }
                for k in i..<(i + n) { pris[k] = true }
                if !trouves.contains(where: { $0.a == aeroport }) { trouves.append(Trouve(a: aeroport, pos: i, role: role)) }
            }
        }
        trouves = trouves.enumerated().sorted { ($0.element.pos, $0.offset) < ($1.element.pos, $1.offset) }.map { $0.element }
        let dep = trouves.first { $0.role == -1 } ?? trouves.first { $0.role == 0 }
        let arr = trouves.first { $0.role == 1 && $0 != dep } ?? trouves.first { $0 != dep && $0.role == 0 }
        return (dep?.a, arr?.a)
    }

    /// Un nom de ville exact, ou un code IATA (pas un mot courant de trois lettres).
    private static func trouver(_ gram: String, _ aeroports: [Vol.Aeroport], _ n: Int) -> Vol.Aeroport? {
        if gram.utf16.count < 3 { return nil }
        if n == 1 && (mots.contains(gram) || vers.contains(gram) || de.contains(gram) || moisParNom[gram] != nil || joursParNom[gram] != nil) {
            return nil
        }
        if let iata = principal[gram], let a = Aeroports.parIata(aeroports, iata) { return a }
        if n == 1 && gram.utf16.count == 3 && !mots.contains(gram) && gram.utf16.allSatisfy({ (0x61...0x7A).contains($0) }) {
            if let a = Aeroports.parIata(aeroports, gram.uppercased()) { return a }
        }
        return Aeroports.exact(aeroports, gram)
    }

    private static let apresDemain = ExpressionReguliere("apres demain|after tomorrow|מחרתיים")
    private static let demain = ExpressionReguliere("(^|\(s))(demain|tomorrow|מחר)(\(s)|$)")
    private static let aujourdhuiMot = ExpressionReguliere("(^|\(s))(aujourd hui|aujourdhui|today|ce soir|tonight|היום|הערב)(\(s)|$)")
    private static let iso = ExpressionReguliere("(?<![0-9])([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})(?![0-9])")
    private static let chiffree = ExpressionReguliere("(?<![0-9:./])([0-9]{1,2})[/.]([0-9]{1,2})(?:[/.]([0-9]{2,4}))?(?![0-9:])")
    private static let jourMois = ExpressionReguliere("(?<![0-9])([0-9]{1,2})(?:er)?\(s)+([a-z\\u05D0-\\u05EA]+)(?:\(s)+([0-9]{4}))?")
    private static let moisJour = ExpressionReguliere("([a-z]+)\(s)+([0-9]{1,2})(?![0-9:h])(?:\(s)+([0-9]{4}))?")

    /// La date du vol, et celle de l'arrivée si une seconde est donnée.
    private static func dates(_ plie: String, _ leger: String, _ mots: [String], _ aujourdhui: JourCivil) -> (JourCivil?, JourCivil?) {
        var trouvees: [(Int, JourCivil)] = []
        func ajoute(_ pos: Int, _ d: JourCivil?) { if let d { trouvees.append((pos, d)) } }
        // Relatifs. « après demain » avant « demain ».
        if let m = apresDemain.trouve(plie) { ajoute(m.plage.lowerBound, aujourdhui.plus(jours: 2)) }
        if trouvees.isEmpty, let m = demain.trouve(plie) { ajoute(m.plage.lowerBound, aujourdhui.plus(jours: 1)) }
        if let m = aujourdhuiMot.trouve(plie) { ajoute(m.plage.lowerBound, aujourdhui) }
        // 12/11, 12.11.2026, 2026-11-12 : sur le texte où la ponctuation reste ; les positions ne servent qu'à l'ordre.
        for m in iso.toutes(leger) {
            ajoute(m.plage.lowerBound, date(Int(m.groupes[1]), Int(m.groupes[2]), Int(m.groupes[3])))
        }
        for m in chiffree.toutes(leger) {
            let j = Int(m.groupes[1]), mo = Int(m.groupes[2])
            let an = Int(m.groupes[3]).map { $0 < 100 ? 2000 + $0 : $0 }
            ajoute(m.plage.lowerBound, an != nil ? date(an, mo, j) : prochaine(aujourdhui, mo, j))
        }
        // 12 novembre, 12 nov 2026, nov 12
        for m in jourMois.toutes(plie) {
            let nom = m.groupes[2]
            let sansBet = nom.commenceParUnites("ב") ? nom.sansPremieresUnites(1) : nom
            guard let mo = moisParNom[nom] ?? moisParNom[sansBet] else { continue }
            let an = Int(m.groupes[3])
            ajoute(m.plage.lowerBound, an != nil ? date(an, mo, Int(m.groupes[1])) : prochaine(aujourdhui, mo, Int(m.groupes[1])))
        }
        for m in moisJour.toutes(plie) {
            guard let mo = moisParNom[m.groupes[1]] else { continue }
            let an = Int(m.groupes[3])
            ajoute(m.plage.lowerBound, an != nil ? date(an, mo, Int(m.groupes[2])) : prochaine(aujourdhui, mo, Int(m.groupes[2])))
        }
        // Un jour de la semaine seul : le prochain (aujourd'hui compris).
        if trouvees.isEmpty {
            for (i, m) in mots.enumerated() {
                let sansBet = m.commenceParUnites("ב") ? m.sansPremieresUnites(1) : m
                guard let jour = joursParNom[m] ?? joursParNom[sansBet] else { continue }
                // En hébreu, le nom du jour suit « יום » (« שני » est aussi « deuxième »), sauf שבת.
                let hebreu = m.utf16.contains { (0x05D0...0x05EA).contains($0) }
                let precedent = i > 0 ? mots[i - 1] : nil
                if hebreu && m != "שבת" && m != "בשבת" && precedent != "יום" && precedent != "ביום" { continue }
                trouvees.append((i, aujourdhui.plus(jours: Kotlin.floorMod(jour - aujourdhui.jourDeSemaine, 7))))
            }
        }
        var tri: [JourCivil] = []
        for (_, d) in trouvees.enumerated().sorted(by: { ($0.element.0, $0.offset) < ($1.element.0, $1.offset) }).map({ $0.element })
        where !tri.contains(d) {
            tri.append(d)
        }
        return (tri.first, tri.count > 1 ? tri[1] : nil)
    }

    private static func date(_ an: Int?, _ mois: Int?, _ jour: Int?) -> JourCivil? {
        guard let an, let mois, let jour else { return nil }
        return JourCivil(annee: an, mois: mois, jour: jour)
    }

    /// Le prochain jour/mois à venir (ou d'il y a moins d'une semaine : un billet relu après coup).
    private static func prochaine(_ aujourdhui: JourCivil, _ mois: Int?, _ jour: Int?) -> JourCivil? {
        guard let d = date(aujourdhui.annee, mois, jour) else { return nil }
        return d < aujourdhui.plus(jours: -7) ? date(aujourdhui.annee + 1, mois, jour) : d
    }

    private static let heure = ExpressionReguliere(
        "(?<![0-9])([01]?[0-9]|2[0-3])(?:\(s)?h\(s)?([0-5][0-9])?|:([0-5][0-9])(?:\(s)?(am|pm))?|\(s)?(am|pm))(?![0-9])"
            + "|(?<![a-z\\u05D0-\\u05EA])(?:בשעה|a|à|at|vers)\(s)([01]?[0-9]|2[0-3])(?![0-9/:.]|\(s)?h|\(s)?am|\(s)?pm)")
    private static let embarquement = ExpressionReguliere("boarding|embarquement|gate|porte|עלייה|שער|fermeture|closes")

    /// Les heures, dans l'ordre : « 11h », « 11h30 », « 11:30 », « 11 am », « 11pm », « à 11 », « בשעה 11 ».
    /// Celles de l'embarquement ou de la fermeture de la porte, qu'un billet donne avant le départ, sont écartées.
    public static func heures(_ leger: String) -> [HeureMinute] {
        heure.toutes(leger).compactMap { m -> HeureMinute? in
            let debut = m.plage.lowerBound
            if embarquement.presente(dans: leger.unites(max(0, debut - 24), debut)) { return nil }
            let g = m.groupes
            if !g[6].isEmpty { return Int(g[6]).map { HeureMinute($0, 0) } }
            guard var h = Int(g[1]) else { return nil }
            let minute = Int(g[2].isEmpty ? (g[3].isEmpty ? "0" : g[3]) : g[2]) ?? 0
            let apm = g[4].isEmpty ? g[5] : g[4]
            if apm == "pm" && h < 12 { h += 12 }
            if apm == "am" && h == 12 { h = 0 }
            return HeureMinute(h, minute)
        }
    }

    /// La durée de vol estimée quand le billet ne donne pas l'arrivée, en minutes : la distance à 820 km/h,
    /// plus 30 minutes de roulage et de montée, au quart d'heure le plus proche. Une estimation, dite comme telle.
    public static func dureeEstimee(_ depart: Vol.Aeroport, _ arrivee: Vol.Aeroport) -> Int {
        let km = Vol.distanceKm(depart.latitude, depart.longitude, arrivee.latitude, arrivee.longitude)
        let minutes = Kotlin.arrondiLong(km / 820.0 * 60.0 + 30.0)
        return Int((minutes + 7) / 15 * 15)
    }
}
