import Foundation

// Tehilim.kt : le livre entier (tehilim.json), ses portions, et les deux cycles qui le disent en un
// mois ou en une semaine. Jugé par TehilimTests (TehilimTest d'Android) et par `Tests/Vecteurs/textes.json`
// (tools/vecteurs_ios/VecteursTextes.kt) : jour hébreu et longueur du mois de chaque jour de 1950 à 2099,
// portions, versets d'une portion, traductions.

/// `Tehilim` : le livre de Tehilim entier (demande du 04/10), 150 psaumes et 2 527 versets, dans l'édition et
/// selon les conventions du Tikoun (le bloc `_meta` de tehilim.json dit la source et la vérification).
public struct Tehilim: Sendable, Equatable, Decodable {

    /// `Tehilim.PSAUMES`.
    public static let nombreDePsaumes = 150

    /// Les versets de chaque psaume : `psaumes[0]` est le psaume 1.
    public let psaumes: [[String]]
    /// Langue (« fr », « en ») → les versets traduits, rangés comme `psaumes` (04/11).
    public let traductions: [String: [[String]]]

    public init(psaumes: [[String]], traductions: [String: [[String]]] = [:]) {
        self.psaumes = psaumes
        self.traductions = traductions
    }

    /// `TehilimLoader.parse` : « psaumes » est exigé ; « traductions » ({fr, en} → {edition, psaumes}) est
    /// facultatif, et une langue sans « psaumes » est laissée de côté.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Cle.self)
        psaumes = try c.decode([[String]].self, forKey: Cle("psaumes"))
        var lues: [String: [[String]]] = [:]
        if let t = try? c.nestedContainer(keyedBy: Cle.self, forKey: Cle("traductions")) {
            for langue in t.allKeys {
                guard let o = try? t.nestedContainer(keyedBy: Cle.self, forKey: langue),
                      let versets = try? o.decode([[String]].self, forKey: Cle("psaumes")) else { continue }
                lues[langue.stringValue] = versets
            }
        }
        traductions = lues
    }

    /// `TehilimLoader.parse`, sur le contenu de tehilim.json.
    public static func lire(_ donnees: Data) throws -> Tehilim {
        try JSONDecoder().decode(Tehilim.self, from: donnees)
    }

    /// Les versets du psaume `numero` (1 à 150), dans l'ordre ; aucun hors du livre.
    public func versets(_ numero: Int) -> [String] {
        guard numero >= 1, numero <= psaumes.count else { return [] }
        return psaumes[numero - 1]
    }

    /// La traduction (« fr », « en ») du verset `verset` du psaume `numero` ; nil sans traduction, hors du
    /// livre, ou si elle est blanche (04/11).
    public func traduction(_ langue: String, psaume numero: Int, verset: Int) -> String? {
        guard let livre = traductions[langue], numero >= 1, numero <= livre.count else { return nil }
        let versets = livre[numero - 1]
        guard verset >= 1, verset <= versets.count else { return nil }
        let texte = versets[verset - 1]
        return texte.estBlanc ? nil : texte
    }

    public var versetsTotal: Int { psaumes.reduce(0) { $0 + $1.count } }
}

/// `Portion` : un passage du livre, du psaume `debut` au psaume `fin`. Seul le psaume 119, trop long pour un
/// jour, se coupe en deux, d'où les bornes de versets.
public struct Portion: Sendable, Hashable, CustomStringConvertible {
    public let debut: Int
    public let fin: Int
    public let debutVerset: Int
    /// nil : jusqu'au dernier verset du psaume `fin`.
    public let finVerset: Int?

    public init(_ debut: Int, _ fin: Int, _ debutVerset: Int = 1, _ finVerset: Int? = nil) {
        self.debut = debut
        self.fin = fin
        self.debutVerset = debutVerset
        self.finVerset = finVerset
    }

    /// `a..b` de Kotlin, en demi-ouvert : vide quand `b` précède `a`, comme un `IntRange` vide, là où un
    /// `ClosedRange` de Swift s'arrêterait.
    private static func intervalle(_ a: Int, _ b: Int) -> Range<Int> {
        if b < a { return a..<a }
        return a..<(b == Int.max ? b : b + 1)
    }

    /// `psaumes` (`debut..fin`).
    public var psaumes: Range<Int> { Portion.intervalle(debut, fin) }

    /// Les versets à lire dans `psaume`, qui en compte `total`.
    public func versets(_ psaume: Int, total: Int) -> Range<Int> {
        Portion.intervalle(psaume == debut ? debutVerset : 1, psaume == fin ? (finVerset ?? total) : total)
    }

    /// Vrai si la portion ne prend qu'une partie d'un psaume (119:1-96).
    public var partielle: Bool { debut == fin && (debutVerset > 1 || finVerset != nil) }

    /// `toString()` d'une data class de Kotlin, pour les messages des tests.
    public var description: String {
        "Portion(debut=\(debut), fin=\(fin), debutVerset=\(debutVerset), finVerset=\(finVerset.map { String($0) } ?? "null"))"
    }
}

/// `CycleTehilim` : les deux façons traditionnelles de dire tout le livre, en un mois, une portion par jour du
/// mois hébraïque, ou en une semaine, du dimanche au Chabbat. Découpages relevés le 04/10/2026 et recoupés sur
/// plusieurs sources indépendantes (hebcal.com, tehilim.co, tehillim-online.com, tehillimforall.com).
public enum CycleTehilim {

    /// `MOIS` : du 1er au 30 du mois.
    public static let mois: [Portion] = [
        Portion(1, 9), Portion(10, 17), Portion(18, 22), Portion(23, 28), Portion(29, 34),
        Portion(35, 38), Portion(39, 43), Portion(44, 48), Portion(49, 54), Portion(55, 59),
        Portion(60, 65), Portion(66, 68), Portion(69, 71), Portion(72, 76), Portion(77, 78),
        Portion(79, 82), Portion(83, 87), Portion(88, 89), Portion(90, 96), Portion(97, 103),
        Portion(104, 105), Portion(106, 107), Portion(108, 112), Portion(113, 118),
        Portion(119, 119, 1, 96), Portion(119, 119, 97, 176),
        Portion(120, 134), Portion(135, 139), Portion(140, 144), Portion(145, 150),
    ]

    /// `SEMAINE` : du dimanche au Chabbat.
    public static let semaine: [Portion] = [
        Portion(1, 29), Portion(30, 50), Portion(51, 72), Portion(73, 89),
        Portion(90, 106), Portion(107, 119), Portion(120, 150),
    ]

    /// La portion du `jour` (1 à 30) d'un mois hébraïque de `longueur` jours. Un mois de 29 jours dit le 29 les
    /// deux dernières portions, pour finir le livre avec le mois.
    public static func duMois(_ jour: Int, longueur: Int) -> Portion {
        if jour >= 29 && longueur == 29 { return Portion(140, 150) }
        return mois[min(max(jour, 1), 30) - 1]
    }

    /// `deLaSemaine(DayOfWeek)` : la portion du jour `jourDeSemaine`, 1 = dimanche … 7 = samedi comme
    /// `JourCivil.jourDeSemaine` ; un nombre hors de 1 à 7 est ramené par le reste de sa division par 7.
    public static func deLaSemaine(jourDeSemaine: Int) -> Portion {
        semaine[(Kotlin.floorMod(jourDeSemaine, 7) + 6) % 7]
    }

    /// La portion du jour de la semaine de `date`.
    public static func deLaSemaine(_ date: JourCivil) -> Portion {
        deLaSemaine(jourDeSemaine: date.jourDeSemaine)
    }

    /// Le jour du mois hébraïque et la longueur de ce mois (`JewishCalendar(date)` : `jewishDayOfMonth`,
    /// `daysInJewishMonth`), pour la date civile : le jour change ici à minuit, pas au coucher du soleil.
    public static func jourHebreu(_ date: JourCivil) -> (jour: Int, longueur: Int) {
        Arithmetique.jour(date)
    }

    /// Le calendrier hébreu par son arithmétique, molad et reports de Roch Hachana, comme `JewishDate` de
    /// KosherJava. Le calendrier hébreu de Foundation (celui d'ICU, que lit `CalendrierJuif.dateJuive`) donne
    /// trente jours à 'Hechvan 5806 et décale d'un jour d'octobre 2045 à novembre 2046 ; KosherJava, lui, suit la
    /// règle. Jugé jour par jour de 1950 à 2099 par `Tests/Vecteurs/textes.json`. Les jours se comptent en jours
    /// fixes (R.D. : 1 est le 1er janvier de l'an 1 du grégorien proleptique).
    private enum Arithmetique {

        /// Le jour fixe du 1er Tichri de l'an 1.
        static let epoque = -1_373_427

        static func embolismique(_ annee: Int) -> Bool { Kotlin.floorMod(7 * annee + 1, 19) < 7 }

        /// Les jours écoulés de l'an 1 au molad de Tichri de `annee`, reporté d'un jour quand il tombe un
        /// dimanche, un mercredi ou un vendredi (lo ADU Rosh).
        static func ecoules(_ annee: Int) -> Int {
            let mois = Kotlin.floorDiv(235 * annee - 234, 19)
            let parties = 12_084 + 13_753 * mois
            let jours = 29 * mois + Kotlin.floorDiv(parties, 25_920)
            return Kotlin.floorMod(3 * (jours + 1), 7) < 3 ? jours + 1 : jours
        }

        /// Le jour fixe de Roch Hachana de `annee`, les deux reports qui gardent l'année entre 353 et 385 jours compris.
        static func rochHachana(_ annee: Int) -> Int {
            let avant = ecoules(annee - 1), ici = ecoules(annee), apres = ecoules(annee + 1)
            let report = apres - ici == 356 ? 2 : (ici - avant == 382 ? 1 : 0)
            return epoque + ici + report
        }

        /// La longueur du mois `mois` (numérotation de KosherJava : NISSAN = 1 … ADAR = 12, ADAR_II = 13).
        static func longueur(_ mois: Int, _ annee: Int) -> Int {
            switch mois {
            case 2, 4, 6, 10, 13:
                return 29
            case 12:
                return embolismique(annee) ? 30 : 29
            case 8, 9:
                // 'Hechvan est long dans une année de 355 ou 385 jours, Kislev court dans une de 353 ou 383.
                let reste = Kotlin.floorMod(rochHachana(annee + 1) - rochHachana(annee), 10)
                return mois == 8 ? (reste == 5 ? 30 : 29) : (reste == 3 ? 29 : 30)
            default:
                return 30
            }
        }

        static func jour(_ date: JourCivil) -> (jour: Int, longueur: Int) {
            let fixe = date.jourJulien - 1_721_425
            var annee = date.annee + 3761
            while rochHachana(annee) > fixe { annee -= 1 }
            while rochHachana(annee + 1) <= fixe { annee += 1 }
            var reste = fixe - rochHachana(annee)
            let ordre = [7, 8, 9, 10, 11, 12] + (embolismique(annee) ? [13] : []) + [1, 2, 3, 4, 5, 6]
            for mois in ordre {
                let jours = longueur(mois, annee)
                if reste < jours { return (reste + 1, jours) }
                reste -= jours
            }
            // Inatteignable : l'année est faite de ses mois, et `reste` est plus petit que sa longueur.
            return (reste + 1, 29)
        }
    }
}
