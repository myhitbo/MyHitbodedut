import Foundation

/// La saisie rapide d'un vol (SaisieVol.kt, 04/11) : une phrase comme on la dirait — « El Al Lyon TLV demain
/// 11h », « LY 382 de Paris à Tel Aviv le 12/11 à 9h40 », « מחר ב־11 טיסת אל על מליון לתל אביב » — ou le
/// texte d'un billet, d'un courriel, d'une carte d'embarquement. Tout se lit sur le téléphone, sans réseau :
/// ce qui est sûr remplit le formulaire, le reste reste à saisir. Même logique que vol.js (lirePhrase).
///
/// Les tables (compagnies, villes, mois, jours, mots) sont recopiées par programme de SaisieVol.kt. Les
/// expressions régulières sont celles de Kotlin, `\s` écrit en toutes lettres (les blancs de la JVM : ICU y
/// compterait l'espace insécable). Jugé par `Tests/Vecteurs/vol_suite.json` (VecteursVolSuite.kt), sections
/// « saisie », « heures », « durees ».
public enum SaisieVol {

    /// `LocalTime` de Kotlin, à la minute : l'heure d'un billet, sans date ni fuseau.
    public struct Heure: Sendable, Hashable, Comparable, CustomStringConvertible {
        public let heure: Int
        public let minute: Int

        public init(_ heure: Int, _ minute: Int) {
            self.heure = heure
            self.minute = minute
        }

        public var minutesDuJour: Int { heure * 60 + minute }

        /// « 09:40 », comme `LocalTime.toString()` à la minute.
        public var description: String { deuxChiffres(heure) + ":" + deuxChiffres(minute) }

        public static func < (gauche: Heure, droite: Heure) -> Bool {
            gauche.minutesDuJour < droite.minutesDuJour
        }

        private func deuxChiffres(_ n: Int) -> String {
            (n < 10 ? "0" : "") + String(n)
        }
    }

    public struct Proposition: Sendable, Hashable {
        public var numero: String?
        /// Le code IATA de la compagnie, s'il a été reconnu (numéro ou nom).
        public var compagnie: String?
        public var depart: Vol.Aeroport?
        public var arrivee: Vol.Aeroport?
        public var date: JourCivil?
        public var heureDepart: Heure?
        public var heureArrivee: Heure?
        /// La date d'arrivée, si le texte en donne une autre que celle du départ.
        public var dateArrivee: JourCivil?

        public init(numero: String? = nil, compagnie: String? = nil, depart: Vol.Aeroport? = nil, arrivee: Vol.Aeroport? = nil,
                    date: JourCivil? = nil, heureDepart: Heure? = nil, heureArrivee: Heure? = nil, dateArrivee: JourCivil? = nil) {
            self.numero = numero
            self.compagnie = compagnie
            self.depart = depart
            self.arrivee = arrivee
            self.date = date
            self.heureDepart = heureDepart
            self.heureArrivee = heureArrivee
            self.dateArrivee = dateArrivee
        }

        public var vide: Bool {
            numero == nil && depart == nil && arrivee == nil && date == nil && heureDepart == nil
        }
    }

    /// Une compagnie : son nom (latin, hébreu) et son code IATA.
    public struct Compagnie: Sendable, Hashable {
        public let nom: String
        public let code: String
    }

    /// Les compagnies les plus courantes, par leur nom → code IATA, dans l'ordre de Kotlin.
    public static let compagnies: [Compagnie] = [
        Compagnie(nom: "el al", code: "LY"), Compagnie(nom: "elal", code: "LY"), Compagnie(nom: "אל על", code: "LY"), Compagnie(nom: "arkia", code: "IZ"), Compagnie(nom: "ארקיע", code: "IZ"), Compagnie(nom: "israir", code: "6H"),
        Compagnie(nom: "ישראייר", code: "6H"), Compagnie(nom: "air haifa", code: "H9"), Compagnie(nom: "air france", code: "AF"), Compagnie(nom: "transavia", code: "TO"), Compagnie(nom: "easyjet", code: "U2"),
        Compagnie(nom: "easy jet", code: "U2"), Compagnie(nom: "wizz", code: "W6"), Compagnie(nom: "wizz air", code: "W6"), Compagnie(nom: "ryanair", code: "FR"), Compagnie(nom: "lufthansa", code: "LH"),
        Compagnie(nom: "swiss", code: "LX"), Compagnie(nom: "british airways", code: "BA"), Compagnie(nom: "klm", code: "KL"), Compagnie(nom: "delta", code: "DL"), Compagnie(nom: "united", code: "UA"),
        Compagnie(nom: "american airlines", code: "AA"), Compagnie(nom: "turkish", code: "TK"), Compagnie(nom: "turkish airlines", code: "TK"), Compagnie(nom: "aegean", code: "A3"), Compagnie(nom: "ita", code: "AZ"),
        Compagnie(nom: "ita airways", code: "AZ"), Compagnie(nom: "iberia", code: "IB"), Compagnie(nom: "air europa", code: "UX"), Compagnie(nom: "emirates", code: "EK"), Compagnie(nom: "etihad", code: "EY"),
        Compagnie(nom: "flydubai", code: "FZ"), Compagnie(nom: "brussels airlines", code: "SN"), Compagnie(nom: "austrian", code: "OS"), Compagnie(nom: "lot", code: "LO"), Compagnie(nom: "air canada", code: "AC"),
        Compagnie(nom: "ethiopian", code: "ET"), Compagnie(nom: "vueling", code: "VY"), Compagnie(nom: "volotea", code: "V7"), Compagnie(nom: "tap", code: "TP"), Compagnie(nom: "air portugal", code: "TP"),
        Compagnie(nom: "finnair", code: "AY"), Compagnie(nom: "sas", code: "SK"), Compagnie(nom: "aeroflot", code: "SU"), Compagnie(nom: "air india", code: "AI"), Compagnie(nom: "cathay", code: "CX"), Compagnie(nom: "qatar", code: "QR"),
        Compagnie(nom: "qatar airways", code: "QR"), Compagnie(nom: "eurowings", code: "EW"), Compagnie(nom: "pegasus", code: "PC"), Compagnie(nom: "bluebird", code: "BZ"), Compagnie(nom: "smartwings", code: "QS"),
        Compagnie(nom: "corsair", code: "SS"), Compagnie(nom: "air corsica", code: "XK"), Compagnie(nom: "air senegal", code: "HC"), Compagnie(nom: "royal air maroc", code: "AT"),
        Compagnie(nom: "tunisair", code: "TU"), Compagnie(nom: "egyptair", code: "MS"), Compagnie(nom: "jet2", code: "LS")
    ]

    /// Les villes à plusieurs aéroports : celui qu'on prend quand seule la ville est dite. On peut toujours
    /// toucher la tuile pour en choisir un autre.
    private static let principal: [String: String] = [
        "paris": "CDG", "london": "LHR", "londres": "LHR", "new york": "JFK", "milan": "MXP",
        "milano": "MXP", "rome": "FCO", "roma": "FCO", "moscow": "SVO", "moscou": "SVO", "tokyo": "NRT",
        "berlin": "BER", "bruxelles": "BRU", "brussels": "BRU", "tel aviv": "TLV", "tel aviv yafo": "TLV",
        "chicago": "ORD", "washington": "IAD", "montreal": "YUL", "toronto": "YYZ", "istanbul": "IST",
        "stockholm": "ARN", "bangkok": "BKK", "dubai": "DXB", "lyon": "LYS", "nice": "NCE",
        "marseille": "MRS", "geneve": "GVA", "geneva": "GVA", "bale": "BSL", "basel": "BSL",
        "eilat": "ETM", "buenos aires": "EZE", "sao paulo": "GRU", "los angeles": "LAX", "miami": "MIA",
        "venise": "VCE", "venice": "VCE", "barcelone": "BCN", "madrid": "MAD", "athenes": "ATH",
        "athens": "ATH", "kiev": "KBP", "kyiv": "KBP", "varsovie": "WAW", "warsaw": "WAW", "פריז": "CDG",
        "לונדון": "LHR", "ניו יורק": "JFK", "תל אביב": "TLV", "אילת": "ETM", "ליון": "LYS",
        "מרסיי": "MRS", "ניס": "NCE", "רומא": "FCO", "מילאנו": "MXP", "ברלין": "BER"
    ]

    /// Les mots de trois lettres qui ne sont pas des codes d'aéroport dans une phrase.
    private static let motsCourants: Set<String> = [
        "les", "des", "vol", "par", "sur", "pour", "une", "est", "and", "the", "for", "via", "dep", "arr", "seat",
        "gate", "you", "are", "air", "new", "bus", "car", "jet", "fly", "pax", "ref", "tax", "fee", "eur", "usd",
        "ils", "son", "ses", "mon", "mes", "ton", "nos", "vos", "aux", "pas", "que", "qui", "oui", "non", "lun",
        "mar", "mer", "jeu", "ven", "sam", "dim", "tue", "wed", "thu", "fri", "sat", "sun", "jan", "fev", "feb",
        "avr", "apr", "mai", "may", "jun", "jul", "aou", "aug", "sep", "oct", "nov", "dec", "bag", "row", "pnr",
        "age", "end", "all"
    ]

    private static let mois: [String: Int] = [
        "janvier": 1, "janv": 1, "jan": 1, "january": 1, "ינואר": 1, "fevrier": 2, "fevr": 2, "fev": 2, "february": 2,
        "feb": 2, "פברואר": 2, "mars": 3, "march": 3, "מרץ": 3, "מרס": 3, "avril": 4, "avr": 4, "april": 4, "apr": 4,
        "אפריל": 4, "mai": 5, "may": 5, "מאי": 5, "juin": 6, "june": 6, "jun": 6, "יוני": 6, "juillet": 7, "juil": 7,
        "july": 7, "jul": 7, "יולי": 7, "aout": 8, "august": 8, "aug": 8, "אוגוסט": 8, "septembre": 9, "sept": 9,
        "sep": 9, "september": 9, "ספטמבר": 9, "octobre": 10, "oct": 10, "october": 10, "אוקטובר": 10, "novembre": 11,
        "nov": 11, "november": 11, "נובמבר": 11, "decembre": 12, "dec": 12, "december": 12, "דצמבר": 12
    ]

    /// Le jour de la semaine, numéroté comme `JourCivil.jourDeSemaine` (1 = dimanche … 7 = samedi).
    private static let jours: [String: Int] = [
        "lundi": 2, "monday": 2, "שני": 2, "mardi": 3, "tuesday": 3, "שלישי": 3, "mercredi": 4, "wednesday": 4,
        "רביעי": 4, "jeudi": 5, "thursday": 5, "חמישי": 5, "vendredi": 6, "friday": 6, "שישי": 6, "samedi": 7,
        "saturday": 7, "שבת": 7, "dimanche": 1, "sunday": 1, "ראשון": 1
    ]

    /// Les mots qui annoncent l'arrivée (« vers Lyon », « לתל אביב » se lit par la lettre ל).
    private static let vers: Set<String> = [
        "vers", "pour", "a", "to", "destination", "arrivee", "arrival", "arr", "→", "->"
    ]
    private static let de: Set<String> = [
        "de", "depuis", "from", "depart", "departure", "dep"
    ]

    /// `\s` de la JVM : espace, tabulation, saut de ligne, U+000B, U+000C, retour chariot.
    private static let blanc = "[ \\t\\n\\x{0B}\\f\\r]"

    public static func lire(_ texte: String, _ aeroports: [Vol.Aeroport], _ aujourdhui: JourCivil) -> Proposition {
        let prepare = texte.remplacantUnites("\u{2192}", par: " \u{2192} ").remplacantUnites("->", par: " \u{2192} ")
            .remplacantUnites("\u{2708}", par: " ")
        let plie = Aeroports.plier(prepare)
        let mots = decoupe(plie)

        let num = numero(plie)
        var compagnie: String?
        if let num, let n = RouteVol.normaliser(num), n.code.utf16.count == 2 { compagnie = n.code }
        if compagnie == nil {
            compagnie = compagniesTriees.first { $0.motif.presente(dans: plie) }?.code
        }

        // Qualifié : le paramètre `aeroports` cache la fonction du même nom.
        let (depart, arrivee) = SaisieVol.aeroports(mots, aeroports, num)
        let leger = marques.remplace(texte.formeNFD, par: "").lowercased()
        let (date, dateArrivee) = dates(plie, leger, mots, aujourdhui)
        let h = heures(leger, numero: num)
        return Proposition(numero: num, compagnie: compagnie, depart: depart, arrivee: arrivee, date: date,
                           heureDepart: h.count > 0 ? h[0] : nil, heureArrivee: h.count > 1 ? h[1] : nil,
                           dateArrivee: dateArrivee)
    }

    private static let marques = ExpressionReguliere("\\p{M}")

    /// `split(' ').filter { it.isNotEmpty() }` : sur l'espace seul, unité par unité.
    private static func decoupe(_ s: String) -> [String] {
        var res: [String] = []
        var cour: [UInt16] = []
        for u in s.utf16 {
            if u == 0x20 {
                if !cour.isEmpty { res.append(Unites.texte(cour)) }
                cour = []
            } else {
                cour.append(u)
            }
        }
        if !cour.isEmpty { res.append(Unites.texte(cour)) }
        return res
    }

    /// Le numéro de vol : deux caractères (ou trois lettres) puis 1 à 4 chiffres, collés ou non.
    private static let motifNumero = ExpressionReguliere(
        "(?<![a-z0-9])([a-z]{2,3}|[a-z][0-9]|[0-9][a-z])" + blanc + "?([0-9]{1,4})([a-z]?)(?![a-z0-9:h/])(?!" + blanc +
            "?(?:jan|fe|mar|av|ap|mai|may|juin|jun|juil|jul|ao|aug|sep|oct|nov|dec))")

    /// « à 11 », « le 12 » ne sont pas des numéros de vol.
    private static let pasNumero: Set<String> = ["a", "le", "la", "de", "du", "au", "et", "on", "at", "\u{05D1}", "the"]

    /// « gate B12 », « porte A3 » : la porte, pas le vol.
    private static let avantPorte = ExpressionReguliere("(?:gate|porte|door|terminal|\u{05E9}\u{05E2}\u{05E8})" + blanc + "*$")

    private static func numero(_ plie: String) -> String? {
        for m in motifNumero.toutes(plie) {
            let code = m.groupes[1]
            if pasNumero.contains(code) || motsCourants.contains(code) { continue }
            // « 4h 25m », « 5h45 » sont des durées ou des heures, pas des numéros (audit du 12/11, FVOL-04) : seul
            // « 6H » (Israir) est un code « chiffre + h », suivi d'un vrai numéro, pas de deux chiffres de minutes.
            let u = Array(code.utf16)
            if u.count == 2 && u[1] == 0x68 && u[0] >= 0x30 && u[0] <= 0x39 {
                let chiffres = m.groupes[2]
                let minutes = chiffres.utf16.count == 2 && entier(chiffres) < 60 && m.groupes[3].isEmpty
                if !(code == "6h" && !minutes) { continue }
            }
            if avantPorte.presente(dans: plie.unites(0, m.plage.lowerBound)) { continue }
            let brut = code + m.groupes[2] + m.groupes[3]
            if RouteVol.normaliser(brut) != nil { return brut.uppercased() }
        }
        return nil
    }

    /// Les compagnies, le nom le plus long d'abord (`sortedByDescending`, stable), chacune avec le motif
    /// de `contientMot` : le nom plié, entre deux blancs ou aux bords du texte.
    private struct CompagnieCherchee: Sendable {
        let code: String
        let motif: ExpressionReguliere
    }

    private static let compagniesTriees: [CompagnieCherchee] = compagnies.enumerated()
        .sorted { (-$0.element.nom.utf16.count, $0.offset) < (-$1.element.nom.utf16.count, $1.offset) }
        .map { CompagnieCherchee(code: $0.element.code,
                                 motif: ExpressionReguliere("(^|" + blanc + ")\\Q" + Aeroports.plier($0.element.nom) + "\\E(" + blanc + "|$)")) }

    /// Un aéroport trouvé dans la phrase : `role` −1 départ, 1 arrivée, 0 inconnu.
    private struct Trouve {
        let a: Vol.Aeroport
        let pos: Int
        let role: Int
    }

    /// Les aéroports dans l'ordre où ils sont dits ; « de X », « vers Y », « ל־Y », « מ־X » l'emportent sur
    /// l'ordre. On essaie les groupes de trois, deux puis un mot.
    private static func aeroports(_ mots: [String], _ liste: [Vol.Aeroport], _ numero: String?) -> (Vol.Aeroport?, Vol.Aeroport?) {
        var trouves: [Trouve] = []
        var pris = [Bool](repeating: false, count: mots.count)
        for n in [3, 2, 1] where mots.count >= n {
            for i in 0...(mots.count - n) {
                if pris[i..<(i + n)].contains(true) { continue }
                var gram = mots[i..<(i + n)].joined(separator: " ")
                var role = 0
                // L'hébreu colle « מ » (de) et « ל » (vers) au nom : on essaie sans.
                var a = trouver(gram, liste, n)
                if a == nil && (gram.commenceParUnites("\u{05DE}") || gram.commenceParUnites("\u{05DC}")) {
                    a = trouver(gram.sansPremieresUnites(1), liste, n)
                    if a != nil { role = gram.commenceParUnites("\u{05DC}") ? 1 : -1 }
                    gram = gram.sansPremieresUnites(1)
                }
                guard let trouve = a else { continue }
                if let numero, egalSansCasse(gram, numero) { continue }
                if role == 0 && i > 0 {
                    let avant = mots[i - 1]
                    if vers.contains(avant) {
                        role = 1
                    } else if de.contains(avant) {
                        role = -1
                    }
                }
                for k in i..<(i + n) { pris[k] = true }
                if !trouves.contains(where: { $0.a == trouve }) { trouves.append(Trouve(a: trouve, pos: i, role: role)) }
            }
        }
        // `sortBy` stable : la position, puis l'ordre de découverte.
        let tries = trouves.enumerated().sorted { ($0.element.pos, $0.offset) < ($1.element.pos, $1.offset) }.map { $0.element }
        let dep = tries.first { $0.role == -1 } ?? tries.first { $0.role == 0 }
        let arr = tries.first { $0.role == 1 && $0.pos != dep?.pos } ?? tries.first { $0.pos != dep?.pos && $0.role == 0 }
        return (dep?.a, arr?.a)
    }

    /// `equals(autre, ignoreCase = true)` de Kotlin, pour un numéro de vol (lettres latines et chiffres).
    private static func egalSansCasse(_ a: String, _ b: String) -> Bool {
        a.utf16.count == b.utf16.count && a.uppercased().egalUnites(b.uppercased())
    }

    /// Un nom de ville exact, ou un code IATA (pas un mot courant de trois lettres).
    private static func trouver(_ gram: String, _ liste: [Vol.Aeroport], _ n: Int) -> Vol.Aeroport? {
        let longueur = gram.utf16.count
        if longueur < 3 { return nil }
        if n == 1 && (motsCourants.contains(gram) || vers.contains(gram) || de.contains(gram) || mois[gram] != nil || jours[gram] != nil) {
            return nil
        }
        if let iata = principal[gram], let a = Aeroports.parIata(liste, iata) { return a }
        if n == 1 && longueur == 3 && !motsCourants.contains(gram) && gram.utf16.allSatisfy({ $0 >= 0x61 && $0 <= 0x7A }) {
            if let a = Aeroports.parIata(liste, gram.uppercased()) { return a }
        }
        return Aeroports.exact(liste, gram)
    }

    // MARK: Dates

    private static let apresDemain = ExpressionReguliere("apres demain|after tomorrow|\u{05DE}\u{05D7}\u{05E8}\u{05EA}\u{05D9}\u{05D9}\u{05DD}")
    private static let demain = ExpressionReguliere("(^|" + blanc + ")(demain|tomorrow|\u{05DE}\u{05D7}\u{05E8})(" + blanc + "|$)")
    private static let ceJour = ExpressionReguliere("(^|" + blanc + ")(aujourd hui|aujourdhui|today|ce soir|tonight|" +
        "\u{05D4}\u{05D9}\u{05D5}\u{05DD}|\u{05D4}\u{05E2}\u{05E8}\u{05D1})(" + blanc + "|$)")
    private static let dateIso = ExpressionReguliere("(?<![0-9])([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})(?![0-9])")
    private static let dateChiffree = ExpressionReguliere("(?<![0-9:./])([0-9]{1,2})[/.]([0-9]{1,2})(?:[/.]([0-9]{2,4}))?(?![0-9:])")
    private static let jourMois = ExpressionReguliere("(?<![0-9])([0-9]{1,2})(?:er)?" + blanc + "+([a-z\\u05D0-\\u05EA]+)(?:" + blanc +
        "+([0-9]{4}))?")
    private static let moisJour = ExpressionReguliere("([a-z]+)" + blanc + "+([0-9]{1,2})(?![0-9:h])(?:" + blanc + "+([0-9]{4}))?")

    /// La date du vol, et celle de l'arrivée si une seconde est donnée.
    private static func dates(_ plie: String, _ leger: String, _ mots: [String], _ aujourdhui: JourCivil) -> (JourCivil?, JourCivil?) {
        var trouvees: [(pos: Int, date: JourCivil)] = []
        func ajoute(_ pos: Int, _ d: JourCivil?) {
            if let d { trouvees.append((pos, d)) }
        }
        // Relatifs. « après demain » avant « demain ».
        if let m = apresDemain.trouve(plie) { ajoute(m.plage.lowerBound, aujourdhui.plus(jours: 2)) }
        if trouvees.isEmpty, let m = demain.trouve(plie) { ajoute(m.plage.lowerBound, aujourdhui.plus(jours: 1)) }
        if let m = ceJour.trouve(plie) { ajoute(m.plage.lowerBound, aujourdhui) }
        // 12/11, 12.11.2026, 2026-11-12 : sur le texte où la ponctuation reste. Les positions de ce texte et du
        // texte plié diffèrent un peu ; elles ne servent qu'à l'ordre.
        for m in dateIso.toutes(leger) {
            ajoute(m.plage.lowerBound, date(entier(m.groupes[1]), entier(m.groupes[2]), entier(m.groupes[3])))
        }
        for m in dateChiffree.toutes(leger) {
            let j = entier(m.groupes[1])
            let mo = entier(m.groupes[2])
            if m.groupes[3].isEmpty {
                ajoute(m.plage.lowerBound, prochaine(aujourdhui, mo, j))
            } else {
                let an = entier(m.groupes[3])
                ajoute(m.plage.lowerBound, date(an < 100 ? 2000 + an : an, mo, j))
            }
        }
        // 12 novembre, 12 nov 2026, nov 12
        for m in jourMois.toutes(plie) {
            guard let mo = mois[m.groupes[2]] ?? mois[sansPrefixe(m.groupes[2], "\u{05D1}")] else { continue }
            let j = entier(m.groupes[1])
            ajoute(m.plage.lowerBound, m.groupes[3].isEmpty ? prochaine(aujourdhui, mo, j) : date(entier(m.groupes[3]), mo, j))
        }
        for m in moisJour.toutes(plie) {
            guard let mo = mois[m.groupes[1]] else { continue }
            let j = entier(m.groupes[2])
            ajoute(m.plage.lowerBound, m.groupes[3].isEmpty ? prochaine(aujourdhui, mo, j) : date(entier(m.groupes[3]), mo, j))
        }
        // Un jour de la semaine seul : le prochain (aujourd'hui compris). La position est alors le rang du mot.
        if trouvees.isEmpty {
            for (i, m) in mots.enumerated() {
                guard let jour = jours[m] ?? jours[sansPrefixe(m, "\u{05D1}")] else { continue }
                // En hébreu, le nom du jour suit « יום » (« שני » est aussi « deuxième »), sauf שבת.
                let hebreu = m.utf16.contains { $0 >= 0x05D0 && $0 <= 0x05EA }
                let precedent = i > 0 ? mots[i - 1] : ""
                let apresYom = precedent.egalUnites("\u{05D9}\u{05D5}\u{05DD}") || precedent.egalUnites("\u{05D1}\u{05D9}\u{05D5}\u{05DD}")
                if hebreu && !m.egalUnites("\u{05E9}\u{05D1}\u{05EA}") && !m.egalUnites("\u{05D1}\u{05E9}\u{05D1}\u{05EA}") && !apresYom {
                    continue
                }
                trouvees.append((i, aujourdhui.plus(jours: Kotlin.floorMod(jour - aujourdhui.jourDeSemaine, 7))))
            }
        }
        // `sortedBy` stable, puis `distinct`.
        let triees = trouvees.enumerated().sorted { ($0.element.pos, $0.offset) < ($1.element.pos, $1.offset) }
        var distinctes: [JourCivil] = []
        for t in triees where !distinctes.contains(t.element.date) { distinctes.append(t.element.date) }
        return (distinctes.count > 0 ? distinctes[0] : nil, distinctes.count > 1 ? distinctes[1] : nil)
    }

    /// Des chiffres ASCII que le motif a déjà vérifiés (au plus quatre) : `toInt()`.
    private static func entier(_ chiffres: String) -> Int {
        Int(chiffres) ?? 0
    }

    /// `removePrefix` de Kotlin.
    private static func sansPrefixe(_ s: String, _ prefixe: String) -> String {
        s.commenceParUnites(prefixe) ? s.sansPremieresUnites(prefixe.utf16.count) : s
    }

    /// `LocalDate.of`, nil pour une date qui n'existe pas.
    private static func date(_ an: Int, _ mois: Int, _ jour: Int) -> JourCivil? {
        JourCivil(annee: an, mois: mois, jour: jour)
    }

    /// Le prochain jour/mois à venir (ou d'il y a moins d'une semaine : un billet relu après coup).
    private static func prochaine(_ aujourdhui: JourCivil, _ mois: Int, _ jour: Int) -> JourCivil? {
        guard let d = date(aujourdhui.annee, mois, jour) else { return nil }
        return d < aujourdhui.plus(jours: -7) ? date(aujourdhui.annee + 1, mois, jour) : d
    }

    // MARK: Heures

    private static let motifHeure = ExpressionReguliere(
        "(?<![0-9])([01]?[0-9]|2[0-3])(?:" + blanc + "?h" + blanc + "?([0-5][0-9])?|:([0-5][0-9])(?:" + blanc + "?(am|pm))?|" + blanc +
            "?(am|pm))(?![0-9])" +
            "|(?<![a-z\\u05D0-\\u05EA])(?:\u{05D1}\u{05E9}\u{05E2}\u{05D4}|a|\u{00E0}|at|vers)" + blanc + "([01]?[0-9]|2[0-3])(?![0-9/:.]|" +
            blanc + "?h|" + blanc + "?am|" + blanc + "?pm)")
    private static let avantHeure = ExpressionReguliere("boarding|embarquement|gate|porte|\u{05E2}\u{05DC}\u{05D9}\u{05D9}\u{05D4}|" +
        "\u{05E9}\u{05E2}\u{05E8}|fermeture|closes")

    private static let departAvant = ExpressionReguliere("depart[a-z]*|dep(?![a-z])|decollage|takeoff|" +
        "\u{05D4}\u{05DE}\u{05E8}\u{05D0}\u{05D4}")
    private static let dureeAvant = ExpressionReguliere("(?:duree|duration|flight time|temps de vol|\u{05DE}\u{05E9}\u{05DA}|" +
        "\u{05D6}\u{05DE}\u{05DF} \u{05D8}\u{05D9}\u{05E1}\u{05D4})" + blanc + "*[:\\-\u{2013}]?" + blanc + "*$")
    private static let minutesApres = ExpressionReguliere("^" + blanc + "?m(?:in|n)?(?![a-z])")
    private static let deuxPoints = ExpressionReguliere("(?<![0-9])[0-9]{1,2}:[0-5][0-9]")

    /// Les heures, dans l'ordre : « 11h », « 11h30 », « 11:30 », « 11 am », « 11pm », « à 11 », « בשעה 11 ».
    /// Sont écartées (audit du 12/11, FVOL-04) : celles de l'embarquement ou de la fermeture de la porte, qu'un
    /// billet donne avant le départ, sauf si « départ » est plus près que « gate » (« Boarding 5:20 gate B12
    /// Departure 6:05 ») ; les durées (« Durée 4h25 », « 4h 25m ») ; les chiffres du numéro de vol déjà lu
    /// (`numero`, « 6H 123 ») ; et, dès qu'une forme « HH:MM » figure dans le texte, les formes « 4h25 », qui sont
    /// alors des durées. `leger` : le texte sans marques (NFD), en minuscules.
    public static func heures(_ leger: String, numero: String? = nil) -> [Heure] {
        var texte = leger
        if let numero {
            let motif = numero.lowercased().map { NSRegularExpression.escapedPattern(for: String($0)) }
                .joined(separator: blanc + "?")
            texte = ExpressionReguliere("(?<![a-z0-9])" + motif + "(?![0-9])").remplace(leger, par: " ")
        }
        let avecDeuxPoints = deuxPoints.presente(dans: texte)
        let longueur = texte.utf16.count
        var res: [Heure] = []
        for m in motifHeure.toutes(texte) {
            let debut = m.plage.lowerBound
            let avant = texte.unites(debut - 24, debut)
            let g = m.groupes
            if dureeAvant.presente(dans: avant) { continue }
            if minutesApres.presente(dans: texte.unites(m.plage.upperBound, longueur)) { continue }
            if avecDeuxPoints && g[3].isEmpty && g[4].isEmpty && g[5].isEmpty && g[6].isEmpty { continue }
            if let porte = avantHeure.toutes(avant).last {
                let depart = departAvant.toutes(avant).last?.plage.lowerBound ?? -1
                if depart < porte.plage.lowerBound { continue }
            }
            if !g[6].isEmpty {
                res.append(Heure(entier(g[6]), 0))
                continue
            }
            var h = entier(g[1])
            let min = entier(g[2].isEmpty ? (g[3].isEmpty ? "0" : g[3]) : g[2])
            let apm = g[4].isEmpty ? g[5] : g[4]
            if apm == "pm" && h < 12 { h += 12 }
            if apm == "am" && h == 12 { h = 0 }
            res.append(Heure(h, min))
        }
        return res
    }

    /// Une date sans heure (code-barres, « demain ») : l'ancien vol n'est pas repris, l'heure se choisit (FVOL-03).
    public static func dateSansHeure(_ p: Proposition) -> Bool {
        p.date != nil && p.heureDepart == nil
    }

    /// Le vol ne se calcule et ne s'enregistre seul que si tout vient du texte ou du billet : ni une arrivée
    /// estimée d'après la distance, ni un jour repris de l'ancien vol (FVOL-03). Sinon on remplit les tuiles.
    public static func calculAutomatique(_ p: Proposition, arriveeEstimee: Bool) -> Bool {
        !arriveeEstimee && p.date != nil
    }

    /// La durée de vol estimée quand le billet ne donne pas l'arrivée, en millisecondes : la distance à
    /// 820 km/h, plus 30 minutes de roulage et de montée, au quart d'heure le plus proche. Une estimation,
    /// dite comme telle à l'écran.
    public static func dureeEstimee(_ depart: Vol.Aeroport, _ arrivee: Vol.Aeroport) -> Int64 {
        let km = Vol.distanceKm(depart.latitude, depart.longitude, arrivee.latitude, arrivee.longitude)
        let minutes = Kotlin.arrondiLong(km / 820.0 * 60.0 + 30.0)
        // Au quart d'heure le plus proche : une estimation ne doit pas avoir l'air précise.
        return ((minutes + 7) / 15) * 15 * 60_000
    }
}
