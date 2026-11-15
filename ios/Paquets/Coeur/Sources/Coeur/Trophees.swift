/// Les trophées (Trophees.kt, demande du 11/10, à niveaux depuis le 12/10) : onze familles qui regardent la
/// forme de la pratique — la plus longue séance d'un jour, les jours, la série, les heures, les semaines
/// pleines, les vendredis, les retours après une pause, le journal, le Tikoun HaKlali (04/11). Chacune monte
/// par niveaux, et la médaille change de métal en montant : bronze, argent, or, platine. Les seuils reprennent
/// des nombres qui parlent d'eux-mêmes (7, 18, 40, 70, 100, 613), avec des paliers intermédiaires à chaque
/// dizaine et quinzaine (12/10) ; choix de l'application, sans source à citer.
///
/// Les minutes sont des `Int` de Kotlin : leurs sommes tiennent sur 32 bits et débordent sans lever, comme
/// sur Android. Les fractions sont en simple précision. Jugé par `Tests/Vecteurs/trophees.json`
/// (tools/vecteurs_ios/VecteursTrophees.kt).
public enum Trophees {

    /// Le métal de la médaille : où l'on en est dans la famille, à l'œil. Le nom de chaque cas est celui de
    /// l'énumération Kotlin.
    public enum Metal: String, Sendable, CaseIterable {
        case bronze = "BRONZE"
        case argent = "ARGENT"
        case or = "OR"
        case platine = "PLATINE"

        /// Le rang dans l'énumération Kotlin (`ordinal`).
        public var ordinal: Int { Metal.allCases.firstIndex(of: self) ?? 0 }
    }

    /// L'objet (12/10, d'après les planches envoyées) : pas que des pièces. `cle` : clé de
    /// trophees_formes.json.
    public enum Forme: String, Sendable, CaseIterable {
        case coupe = "COUPE"
        case ecusson = "ECUSSON"
        case etoile = "ETOILE"
        case rosette = "ROSETTE"
        case medaille = "MEDAILLE"
        case pieces = "PIECES"
        case cristal = "CRISTAL"
        case gemme = "GEMME"
        case kinor = "KINOR"

        public var cle: String {
            switch self {
            case .coupe: return "coupe"
            case .ecusson: return "ecusson"
            case .etoile: return "etoile"
            case .rosette: return "rosette"
            case .medaille: return "medaille"
            case .pieces: return "pieces"
            case .cristal: return "cristal"
            case .gemme: return "gemme"
            case .kinor: return "kinor"
            }
        }
    }

    /// Les familles, dans l'ordre de Kotlin ; le nom de chaque cas est celui de l'énumération Kotlin.
    public enum Famille: String, Sendable, CaseIterable {
        case premierPas = "PREMIER_PAS"
        case seanceLongue = "SEANCE_LONGUE"
        case jours = "JOURS"
        case serie = "SERIE"
        case heures = "HEURES"
        case semaines = "SEMAINES"
        case erevChabbat = "EREV_CHABBAT"
        case retour = "RETOUR"
        case plume = "PLUME"
        // Le Tikoun HaKlali (04/11) : les lectures complètes, puis les jours d'affilée ; la harpe de David.
        case tikkun = "TIKKUN"
        case tikkunSerie = "TIKKUN_SERIE"

        public var cle: String {
            switch self {
            case .premierPas: return "premier_pas"
            case .seanceLongue: return "seance_longue"
            case .jours: return "jours"
            case .serie: return "serie"
            case .heures: return "heures"
            case .semaines: return "semaines"
            case .erevChabbat: return "erev_chabbat"
            case .retour: return "retour"
            case .plume: return "plume"
            case .tikkun: return "tikkun"
            case .tikkunSerie: return "tikkun_serie"
            }
        }

        /// La clé de l'icône au trait dans trophees_formes.json (variante B choisie le 16/10) : celle de la
        /// famille, pour chacune.
        public var icone: String { cle }

        public var seuils: [Int] {
            switch self {
            case .premierPas: return [1, 2, 3, 4, 5]
            case .seanceLongue: return [10, 15, 20, 30, 40, 45, 50, 60, 75, 90, 105, 120, 150, 180]
            case .jours:
                return [7, 10, 15, 18, 20, 30, 40, 45, 50, 60, 70, 80, 90, 100, 120, 150, 180, 200, 250, 300, 365, 400,
                        500, 613]
            case .serie: return [3, 5, 7, 10, 15, 18, 20, 30, 40, 45, 50, 60, 70, 80, 90, 100]
            case .heures: return [1, 2, 5, 10, 15, 20, 25, 30, 40, 45, 50, 60, 75, 100, 150, 200, 250, 300]
            case .semaines: return [1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 26, 30, 40, 45, 52]
            case .erevChabbat: return [1, 4, 12, 26, 52]
            case .retour: return [1, 3, 5, 10]
            case .plume: return [1, 10, 25, 50, 100, 150]
            case .tikkun: return [1, 3, 7, 10, 18, 26, 40, 50, 70, 100, 150, 200]
            case .tikkunSerie: return [3, 7, 10, 18, 30, 40, 70, 100]
            }
        }

        public var forme: Forme {
            switch self {
            case .premierPas: return .rosette
            case .seanceLongue, .plume: return .coupe
            case .jours: return .medaille
            case .serie: return .etoile
            case .heures: return .pieces
            case .semaines: return .ecusson
            case .erevChabbat: return .cristal
            case .retour: return .gemme
            case .tikkun, .tikkunSerie: return .kinor
            }
        }

        /// Le rang dans l'énumération Kotlin (`ordinal`).
        public var ordinal: Int { Famille.allCases.firstIndex(of: self) ?? 0 }
    }

    /// Un niveau atteint : `rang` de 1 au nombre de seuils de la famille.
    public struct Niveau: Hashable, Sendable {
        public let famille: Famille
        public let rang: Int

        public init(famille: Famille, rang: Int) {
            self.famille = famille
            self.rang = rang
        }

        /// « famille:rang », la clé des trophées vus et des dates de gain.
        public var cle: String { famille.cle + ":" + String(rang) }

        /// Le seuil du niveau ; comme sur Android, un rang hors de la famille n'en a pas (l'accès s'arrête).
        public var seuil: Int { famille.seuils[rang - 1] }

        public var metal: Metal { Trophees.metal(famille, rang) }
    }

    /// Le métal d'un rang : un quart de la famille par métal ; une famille d'un seul niveau est de bronze. Le
    /// calcul suit les 32 bits de Kotlin, pour un rang hors de la famille.
    public static func metal(_ f: Famille, _ rang: Int) -> Metal {
        let nombre = f.seuils.count
        if nombre == 1 { return .bronze }
        let produit = (Int32(truncatingIfNeeded: rang) &- 1) &* 4
        let i = min(max(Int(produit / Int32(nombre)), 0), 3)
        return Metal.allCases[i]
    }

    /// Ce que les trophées regardent : les minutes par jour fait, les notes écrites, la meilleure série ; et
    /// les jours où le Tikoun HaKlali a été dit en entier (04/11).
    public struct Pratique: Hashable, Sendable {
        public let minutes: [JourCivil: Int]
        public let notes: Int
        public let meilleureSerie: Int
        public let tikkun: Set<JourCivil>

        public init(minutes: [JourCivil: Int], notes: Int, meilleureSerie: Int, tikkun: Set<JourCivil> = []) {
            self.minutes = minutes
            self.notes = notes
            self.meilleureSerie = meilleureSerie
            self.tikkun = tikkun
        }
    }

    /// Une somme comme `sum()` de Kotlin : sur 32 bits, qui déborde sans lever.
    private static func somme<S: Sequence>(_ valeurs: S) -> Int where S.Element == Int {
        var total: Int32 = 0
        for v in valeurs { total = total &+ Int32(truncatingIfNeeded: v) }
        return Int(total)
    }

    /// `dayOfWeek == FRIDAY` (`jourDeSemaine` va de 1, dimanche, à 7, samedi).
    private static func estVendredi(_ d: JourCivil) -> Bool { d.jourDeSemaine == 6 }

    /// Le dimanche de la semaine d'un jour.
    private static func dimanche(_ d: JourCivil) -> JourCivil { d.plus(jours: 1 - d.jourDeSemaine) }

    /// La plus longue suite de jours consécutifs.
    public static func plusLongueSuite(_ jours: Set<JourCivil>) -> Int {
        var meilleure = 0
        var courante = 0
        var avant: JourCivil?
        for d in jours.sorted() {
            if let a = avant, d.jourJulien - a.jourJulien == 1 {
                courante += 1
            } else {
                courante = 1
            }
            meilleure = max(meilleure, courante)
            avant = d
        }
        return meilleure
    }

    /// Les semaines pleines : six jours faits, du dimanche au vendredi.
    public static func semainesPleines(_ jours: Set<JourCivil>) -> Int {
        var nombre = 0
        for d in jours where d.jourDeSemaine == 1 {
            var pleine = true
            for i in 1...5 where !jours.contains(d.plus(jours: i)) {
                pleine = false
                break
            }
            if pleine { nombre += 1 }
        }
        return nombre
    }

    /// Les retours : un jour de pratique après au moins sept jours sans.
    public static func retours(_ jours: Set<JourCivil>) -> Int {
        var nombre = 0
        var avant: JourCivil?
        for d in jours.sorted() {
            if let a = avant, d.jourJulien - a.jourJulien > 7 { nombre += 1 }
            avant = d
        }
        return nombre
    }

    /// La valeur que la famille compte : minutes, jours, heures, semaines, vendredis, retours, notes.
    public static func valeur(_ p: Pratique, _ f: Famille) -> Int {
        // Un jour validé compte, même à 0 min (« Terminer » avant la première minute, déjà fait) : comme la série.
        switch f {
        case .premierPas: return min(p.minutes.count, 5)
        case .seanceLongue: return p.minutes.values.max() ?? 0
        case .jours: return p.minutes.count
        case .serie: return p.meilleureSerie
        case .heures: return somme(p.minutes.values) / 60
        case .semaines: return semainesPleines(Set(p.minutes.keys))
        case .erevChabbat:
            var vendredis = 0
            for d in p.minutes.keys where estVendredi(d) { vendredis += 1 }
            return vendredis
        case .retour: return retours(Set(p.minutes.keys))
        case .plume: return p.notes
        case .tikkun: return p.tikkun.count
        case .tikkunSerie: return plusLongueSuite(p.tikkun)
        }
    }

    /// Combien de seuils une valeur atteint.
    private static func compte(_ v: Int, _ f: Famille) -> Int {
        var n = 0
        for s in f.seuils where v >= s { n += 1 }
        return n
    }

    /// Le rang atteint dans une famille : 0 tant que le premier seuil manque.
    public static func rang(_ p: Pratique, _ f: Famille) -> Int { compte(valeur(p, f), f) }

    /// Tous les niveaux atteints, chacun pour soi (une famille au rang 3 a gagné 1, 2 et 3).
    public static func gagnes(_ p: Pratique) -> Set<Niveau> {
        var resultat = Set<Niveau>()
        for f in Famille.allCases {
            let r = rang(p, f)
            if r < 1 { continue }
            for i in 1...r { resultat.insert(Niveau(famille: f, rang: i)) }
        }
        return resultat
    }

    /// Le chemin (15/10, « fais un système plus simple ») : tous les niveaux de toutes les familles en une
    /// seule liste, du plus facile au plus dur. Chaque étape est un petit objectif (« 3 jours d'affilée »,
    /// « 1 heure en tout ») ; l'écran montre les gagnées et celles à venir, dans cet ordre. Le coût estime le
    /// nombre de jours qu'il faut, à raison d'un quart d'heure par jour ; choix de l'application.
    public static func cout(_ f: Famille, _ seuil: Int) -> Double {
        let s = Double(seuil)
        switch f {
        case .premierPas, .jours: return s
        case .seanceLongue: return s / 2.0
        case .serie: return s * 1.5
        case .heures: return s * 4.0
        case .semaines: return s * 8.0
        case .erevChabbat: return s * 7.0
        case .retour: return s * 30.0 + 10
        case .plume: return s * 1.3
        // Dix psaumes, plus rares qu'une séance : deux jours par lecture, trois par jour d'affilée.
        case .tikkun: return s * 2.0
        case .tikkunSerie: return s * 3.0
        }
    }

    /// Trié par coût, puis par famille : dans une famille les coûts croissent strictement, la clé ne se
    /// répète donc jamais et l'ordre ne dépend pas de la stabilité du tri.
    public static let chemin: [Niveau] = {
        var tous: [Niveau] = []
        for f in Famille.allCases {
            for r in 1...f.seuils.count { tous.append(Niveau(famille: f, rang: r)) }
        }
        return tous.sorted { a, b in
            let coutA = Trophees.cout(a.famille, a.seuil)
            let coutB = Trophees.cout(b.famille, b.seuil)
            if coutA != coutB { return coutA < coutB }
            return a.famille.ordinal < b.famille.ordinal
        }
    }()

    public static func gagne(_ p: Pratique, _ n: Niveau) -> Bool { valeur(p, n.famille) >= n.seuil }

    /// Le grade (15/10, « les matériaux sont mélangés ») : un seul matériau à la fois, selon le `compte` de
    /// trophées gagnés — bronze, argent dès le 10ᵉ, or dès le 25ᵉ, platine dès le 50ᵉ. Le k-ième trophée
    /// gagné (de 1) prend le matériau de grade(k).
    public static let seuilsGrades: [Int] = [0, 10, 25, 50]

    /// Un compte négatif, où Android lève (indice -1), donne le bronze.
    public static func grade(_ compte: Int) -> Metal {
        var atteints = 0
        for s in seuilsGrades where compte >= s { atteints += 1 }
        return Metal.allCases[max(atteints - 1, 0)]
    }

    /// De 0 à 1 vers une étape. Le seuil est toujours positif et la valeur entière : ni NaN ni zéro négatif.
    public static func fraction(_ p: Pratique, _ n: Niveau) -> Float {
        Float(min(valeur(p, n.famille), n.seuil)) / Float(n.seuil)
    }

    /// Une étape à gagner, avec ce qui la classe.
    private struct Candidat {
        let niveau: Niveau
        let fraction: Float
        let cout: Double
        /// Sa place dans le chemin.
        let place: Int
    }

    private static func aGagner(_ p: Pratique) -> [Candidat] {
        var candidats: [Candidat] = []
        for (place, n) in chemin.enumerated() where !gagne(p, n) {
            candidats.append(Candidat(niveau: n, fraction: fraction(p, n), cout: cout(n.famille, n.seuil), place: place))
        }
        return candidats
    }

    /// Le prochain trophée : parmi ceux à gagner, le plus près d'être atteint ; à égalité, le plus facile ;
    /// à égalité encore, le premier du chemin (`maxWithOrNull` garde le premier des plus grands).
    public static func prochain(_ p: Pratique) -> Niveau? {
        var meilleur: Candidat?
        for c in aGagner(p) {
            if let m = meilleur {
                let plusGrand = c.fraction > m.fraction || (c.fraction == m.fraction && c.cout < m.cout)
                if !plusGrand { continue }
            }
            meilleur = c
        }
        return meilleur?.niveau
    }

    /// Les plus proches (16/10) : les `k` trophées à gagner les plus avancés ; à égalité, les plus faciles,
    /// puis l'ordre du chemin (le tri de Kotlin est stable). Un `k` négatif, où Android lève, ne rend rien.
    public static func plusProches(_ p: Pratique, k: Int = 3) -> [Niveau] {
        let tries = aGagner(p).sorted { a, b in
            if a.fraction != b.fraction { return a.fraction > b.fraction }
            if a.cout != b.cout { return a.cout < b.cout }
            return a.place < b.place
        }
        return tries.prefix(max(k, 0)).map { $0.niveau }
    }

    /// Le prochain trophée, s'il est tout proche (16/10) : à un dixième du seuil, ou à une unité pour les
    /// petits seuils (« 7 jours d'affilée » à 6). Le rappel du jour le dit.
    public static func proche(_ p: Pratique) -> Niveau? {
        guard let n = prochain(p) else { return nil }
        let reste = n.seuil - valeur(p, n.famille)
        return reste >= 1 && reste <= max(1, n.seuil / 10) ? n : nil
    }

    /// Le jour où chaque niveau a été gagné (16/10) : l'historique rejoué jour après jour, le premier jour où
    /// la pratique atteint le seuil. `notes` : les jours qui portent une note ; `exempt` : les jours qui ne
    /// cassent pas la série (`Plaque.meilleureSerie`), demandé comme sur Android, pour les jours entre deux
    /// jours faits, dans l'ordre, jusqu'au premier qui ne l'est pas.
    public static func datesGain(_ minutes: [JourCivil: Int], _ notes: Set<JourCivil>, tikkun: Set<JourCivil> = [],
                                 exempt: (JourCivil) -> Bool) -> [String: JourCivil] {
        // Le rejeu est incrémental (16/10) : chaque valeur avance jour après jour, sans rien recalculer —
        // rejouer la pratique entière à chaque jour gelait l'accueil. Mêmes règles que valeur() et
        // Plaque.meilleureSerie (un jour exempté ne compte pas et ne casse pas).
        var resultat: [String: JourCivil] = [:]
        let familles = Famille.allCases
        // Pour chaque famille, combien de ses niveaux sont déjà datés (ils se gagnent dans l'ordre des seuils).
        var dates = [Int](repeating: 0, count: familles.count)
        var restantes = familles.count
        var faits = Set<JourCivil>()
        var jours = 0
        var plusLongue = 0
        var total: Int32 = 0
        var vendredis = 0
        var retours = 0
        var semaines = 0
        var notesVues = 0
        var courante = 0
        var meilleure = 0
        var precedent: JourCivil?
        var semainesPleines = Set<JourCivil>()
        var tikkunN = 0
        var tikkunSuite = 0
        var tikkunMeilleure = 0
        var tikkunAvant: JourCivil?
        for d in Set(minutes.keys).union(notes).union(tikkun).sorted() {
            if notes.contains(d) { notesVues += 1 }
            if tikkun.contains(d) {
                tikkunN += 1
                if let a = tikkunAvant, d.jourJulien - a.jourJulien == 1 {
                    tikkunSuite += 1
                } else {
                    tikkunSuite = 1
                }
                tikkunMeilleure = max(tikkunMeilleure, tikkunSuite)
                tikkunAvant = d
            }
            if let m = minutes[d] {
                faits.insert(d)
                jours += 1
                total = total &+ Int32(truncatingIfNeeded: m)
                plusLongue = max(plusLongue, m)
                if estVendredi(d) { vendredis += 1 }
                if let avant = precedent {
                    if d.jourJulien - avant.jourJulien > 7 { retours += 1 }
                    // La série : les jours entre le précédent et celui-ci doivent tous être exemptés.
                    var tousExemptes = true
                    var entre = avant.plus(jours: 1)
                    while entre < d {
                        if !exempt(entre) {
                            tousExemptes = false
                            break
                        }
                        entre = entre.plus(jours: 1)
                    }
                    courante = tousExemptes ? courante + 1 : 1
                } else {
                    courante = 1
                }
                meilleure = max(meilleure, courante)
                precedent = d
                let debut = dimanche(d)
                if !semainesPleines.contains(debut) {
                    var pleine = true
                    for i in 0...5 where !faits.contains(debut.plus(jours: i)) {
                        pleine = false
                        break
                    }
                    if pleine {
                        semainesPleines.insert(debut)
                        semaines += 1
                    }
                }
            }
            for (i, f) in familles.enumerated() {
                let seuils = f.seuils
                if dates[i] >= seuils.count { continue }
                let v: Int
                switch f {
                case .premierPas: v = min(jours, 5)
                case .seanceLongue: v = plusLongue
                case .jours: v = jours
                case .serie: v = meilleure
                case .heures: v = Int(total / 60)
                case .semaines: v = semaines
                case .erevChabbat: v = vendredis
                case .retour: v = retours
                case .plume: v = notesVues
                case .tikkun: v = tikkunN
                case .tikkunSerie: v = tikkunMeilleure
                }
                while dates[i] < seuils.count && seuils[dates[i]] <= v {
                    dates[i] += 1
                    resultat[Niveau(famille: f, rang: dates[i]).cle] = d
                }
                if dates[i] == seuils.count { restantes -= 1 }
            }
            if restantes == 0 { break }
        }
        return resultat
    }

    /// Où l'on en est vers le niveau suivant ; au sommet, le dernier seuil.
    public struct Progres: Hashable, Sendable {
        public let valeur: Int
        public let cible: Int

        public init(valeur: Int, cible: Int) {
            self.valeur = valeur
            self.cible = cible
        }

        public var fraction: Float { cible <= 0 ? 1 : Float(min(valeur, cible)) / Float(cible) }
    }

    public static func progres(_ p: Pratique, _ f: Famille) -> Progres {
        let r = rang(p, f)
        let seuils = f.seuils
        return Progres(valeur: valeur(p, f), cible: seuils[min(r, seuils.count - 1)])
    }

    /// Les niveaux gagnés depuis la dernière fois, le plus haut de chaque famille d'abord ; rien la première
    /// fois (`vus` nil), ni quand `vus` date d'avant les niveaux (des clés sans « : ») : pas de pluie de vieux
    /// trophées. À égalité de métal et de rang, l'ordre des familles : celui où Kotlin parcourt les gagnés
    /// que rend `gagnes`. Une clé est faite de lettres ASCII, de chiffres et de signes : l'égalité de Swift
    /// (à l'équivalence canonique près) y est celle de Kotlin.
    public static func nouveaux(_ gagnes: Set<Niveau>, vus: Set<String>?) -> [Niveau] {
        guard let vus else { return [] }
        if !vus.isEmpty && !vus.contains(where: { $0.utf16.contains(0x3A) }) { return [] }
        var plusHauts: [Famille: Niveau] = [:]
        for n in gagnes where !vus.contains(n.cle) {
            if let deja = plusHauts[n.famille], deja.rang >= n.rang { continue }
            plusHauts[n.famille] = n
        }
        return plusHauts.values.sorted { a, b in
            let poidsA = a.metal.ordinal * 100 + a.rang
            let poidsB = b.metal.ordinal * 100 + b.rang
            if poidsA != poidsB { return poidsA > poidsB }
            return a.famille.ordinal < b.famille.ordinal
        }
    }
}
