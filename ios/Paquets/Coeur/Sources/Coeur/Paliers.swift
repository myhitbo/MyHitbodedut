/// Les paliers d'objectifs (Paliers.kt, יעדים, demande du 11/10) : après chaque palier atteint, le
/// suivant. Six pistes, chacune avec son échelle :
///
///  - SERIE : jours d'affilée (un jour exempté ne casse pas, comme la série) ;
///  - JOUR, SEMAINE, MOIS : minutes de la journée, de la semaine (dimanche à samedi) et du mois hébreu en
///    cours ; elles repartent à chaque période ;
///  - CUMUL : minutes de toute la pratique ;
///  - JOURS : jours de pratique, en tout.
///
/// L'échelle part bas (le premier pas doit être à portée), se resserre là où l'on hésite, s'espace
/// ensuite ; quelques jalons parlent d'eux-mêmes : 18 (חי), 40 jours, 613. Au-delà du dernier palier, un
/// pas régulier. Le palier du jour inclut l'objectif quotidien réglé, pour que l'atteindre compte.
///
/// Les minutes sont des `Int` de Kotlin : leurs sommes tiennent sur 32 bits et débordent sans lever, comme
/// sur Android. Les avancées sont en simple précision. Jugé par `Tests/Vecteurs/paliers.json`
/// (tools/vecteurs_ios/VecteursPaliers.kt).
public enum Paliers {

    /// Le nom de chaque cas est celui de l'énumération Kotlin (`name`) ; `cle` est celle des marques.
    public enum Piste: String, Sendable, CaseIterable {
        case serie = "SERIE"
        case jour = "JOUR"
        case semaine = "SEMAINE"
        case mois = "MOIS"
        case cumul = "CUMUL"
        case jours = "JOURS"

        public var cle: String {
            switch self {
            case .serie: return "serie"
            case .jour: return "jour"
            case .semaine: return "semaine"
            case .mois: return "mois"
            case .cumul: return "cumul"
            case .jours: return "jours"
            }
        }
    }

    /// Les paliers de base d'une piste, dans l'ordre.
    private static func base(_ piste: Piste) -> [Int] {
        switch piste {
        case .serie: return [3, 7, 14, 18, 21, 30, 40, 50, 70, 100, 150, 180, 250, 365]
        case .jour: return [10, 15, 20, 30, 45, 60, 90, 120]
        case .semaine: return [30, 60, 90, 120, 180, 240, 300, 420, 600, 840]
        case .mois: return [60, 120, 180, 300, 450, 600, 900, 1200, 1800, 2400, 3000, 3600]
        case .cumul:
            return [60, 180, 300, 600, 1080, 1500, 2160, 3000, 4320, 6000, 9000, 12000, 18000, 24000, 30000,
                    36000, 48000, 60000]
        case .jours: return [1, 3, 7, 10, 18, 30, 40, 50, 70, 100, 150, 180, 250, 365, 500, 613, 800, 1000]
        }
    }

    /// Le pas d'une piste au-delà de son dernier palier.
    private static func pas(_ piste: Piste) -> Int {
        switch piste {
        case .serie: return 365
        case .jour: return 60
        case .semaine: return 300
        case .mois: return 1200
        case .cumul: return 12000
        case .jours: return 250
        }
    }

    /// L'échelle d'une piste jusqu'à couvrir `jusqua` ; JOUR y ajoute l'objectif quotidien.
    public static func echelle(_ piste: Piste, jusqua: Int, objectifJour: Int = 0) -> [Int] {
        var liste = base(piste)
        if piste == .jour && objectifJour > 0 && !liste.contains(objectifJour) { liste.append(objectifJour) }
        liste.sort()
        let ecart = pas(piste)
        while let dernier = liste.last, dernier <= jusqua { liste.append(dernier + ecart) }
        return liste
    }

    public struct Etat: Hashable, Sendable {
        public let piste: Piste
        public let valeur: Int
        /// Le dernier palier atteint, 0 s'il n'y en a pas encore.
        public let atteint: Int
        /// Le palier visé : le premier au-dessus de la valeur.
        public let prochain: Int
        /// Combien de paliers sont atteints.
        public let rang: Int

        public init(piste: Piste, valeur: Int, atteint: Int, prochain: Int, rang: Int) {
            self.piste = piste
            self.valeur = valeur
            self.atteint = atteint
            self.prochain = prochain
            self.rang = rang
        }

        /// Sur les 32 bits de Kotlin : seul un état bâti à la main peut y déborder.
        public var reste: Int {
            Int(Int32(truncatingIfNeeded: prochain) &- Int32(truncatingIfNeeded: valeur))
        }

        /// De 0 à 1 : la valeur rapportée au prochain palier (30 min sur 1 h : à moitié). Comptée depuis le
        /// dernier palier atteint, la barre restait vide à 30 min sur 1 h, sous « encore 30 min » (capture du
        /// 15/10, « incompréhensible »). Bornée comme par `coerceIn(0f, 1f)` : NaN et -0,0 passent tels quels.
        public var avancee: Float {
            let f = Float(valeur) / Float(prochain)
            if f < 0 { return 0 }
            if f > 1 { return 1 }
            return f
        }
    }

    public static func etat(_ piste: Piste, valeur: Int, objectifJour: Int = 0) -> Etat {
        let v = max(valeur, 0)
        let e = echelle(piste, jusqua: v, objectifJour: objectifJour)
        var atteint = 0
        var rang = 0
        for p in e where p <= v {
            atteint = p
            rang += 1
        }
        // L'échelle couvre toujours la valeur : son dernier palier la dépasse.
        let prochain = e.first(where: { $0 > v }) ?? v + 1
        return Etat(piste: piste, valeur: v, atteint: atteint, prochain: prochain, rang: rang)
    }

    /// Ce que la pratique donne : minutes par jour fait.
    public struct Bilan: Hashable, Sendable {
        public let aujourdhui: JourCivil
        public let minutes: [JourCivil: Int]
        public let serie: Int
        public let debutMoisHebreu: JourCivil
        public let objectifJour: Int

        public init(aujourdhui: JourCivil, minutes: [JourCivil: Int], serie: Int, debutMoisHebreu: JourCivil,
                    objectifJour: Int) {
            self.aujourdhui = aujourdhui
            self.minutes = minutes
            self.serie = serie
            self.debutMoisHebreu = debutMoisHebreu
            self.objectifJour = objectifJour
        }

        /// Le dimanche de la semaine d'aujourd'hui (`jourDeSemaine` vaut 1 le dimanche).
        public var debutSemaine: JourCivil { aujourdhui.plus(jours: 1 - aujourdhui.jourDeSemaine) }

        /// Les minutes de `debut` à aujourd'hui, bornes comprises.
        public func entre(_ debut: JourCivil) -> Int { entre(debut, aujourdhui) }

        /// Les minutes de `debut` à `fin`, bornes comprises ; rien si `fin` précède `debut`.
        public func entre(_ debut: JourCivil, _ fin: JourCivil) -> Int {
            var total: Int32 = 0
            for (jour, m) in minutes where debut <= jour && jour <= fin {
                total = total &+ Int32(truncatingIfNeeded: m)
            }
            return Int(total)
        }
    }

    /// Une somme comme `sum()` de Kotlin : sur 32 bits, qui déborde sans lever.
    private static func somme<S: Sequence>(_ valeurs: S) -> Int where S.Element == Int {
        var total: Int32 = 0
        for v in valeurs { total = total &+ Int32(truncatingIfNeeded: v) }
        return Int(total)
    }

    public static func etats(_ b: Bilan) -> [Etat] {
        [
            etat(.serie, valeur: b.serie),
            etat(.jour, valeur: b.minutes[b.aujourdhui] ?? 0, objectifJour: b.objectifJour),
            etat(.semaine, valeur: b.entre(b.debutSemaine)),
            etat(.mois, valeur: b.entre(b.debutMoisHebreu)),
            etat(.cumul, valeur: somme(b.minutes.values)),
            etat(.jours, valeur: b.minutes.count),
        ]
    }

    /// `a < b` comme `compareTo` d'un `Float` sur la JVM : NaN dépasse tout, -0,0 passe sous 0,0.
    private static func avantJava(_ a: Float, _ b: Float) -> Bool {
        if a < b { return true }
        if a > b { return false }
        let gauche = a.isNaN ? Int32(0x7FC0_0000) : Int32(bitPattern: a.bitPattern)
        let droite = b.isNaN ? Int32(0x7FC0_0000) : Int32(bitPattern: b.bitPattern)
        return gauche < droite
    }

    /// Le palier à mettre en avant à l'accueil : parmi la série, le jour, la semaine et le mois, celui dont
    /// on est le plus près ; à égalité, le premier de la liste (la série dans `etats`). nil là où Kotlin
    /// lève : aucune de ces quatre pistes dans la liste.
    public static func aLaUne(_ etats: [Etat]) -> Etat? {
        var meilleur: Etat?
        for e in etats where e.piste == .serie || e.piste == .jour || e.piste == .semaine || e.piste == .mois {
            if let m = meilleur, !avantJava(m.avancee, e.avancee) { continue }
            meilleur = e
        }
        return meilleur
    }

    /// Les marques des paliers atteints : une fois pour toutes pour la série, le cumul et les jours ; par
    /// période pour le jour, la semaine et le mois (le palier de 30 min se fête chaque jour où on
    /// l'atteint). Les dates s'écrivent comme `LocalDate.toString()` (`JourCivil.iso`).
    public static func marques(_ etats: [Etat], _ b: Bilan) -> Set<String> {
        var resultat = Set<String>()
        for e in etats {
            let periode: String
            switch e.piste {
            case .jour: periode = ":" + b.aujourdhui.iso
            case .semaine: periode = ":" + b.debutSemaine.iso
            case .mois: periode = ":" + b.debutMoisHebreu.iso
            case .serie, .cumul, .jours: periode = ""
            }
            for p in echelle(e.piste, jusqua: e.valeur, objectifJour: b.objectifJour) where p <= e.valeur {
                resultat.insert(e.piste.cle + periode + ":" + String(p))
            }
        }
        return resultat
    }

    /// Les paliers atteints depuis la dernière visite : le plus haut de chaque piste, dans l'ordre de
    /// `etats`. Une marque est faite de lettres ASCII, de chiffres et de signes : l'égalité de Swift (à
    /// l'équivalence canonique près) y est celle de Kotlin.
    public static func nouveaux(_ etats: [Etat], _ b: Bilan, vus: Set<String>) -> [Etat] {
        var neuves = Set<String>()
        for m in marques(etats, b).subtracting(vus) { neuves.insert(m.avantUnites(":")) }
        return etats.filter { neuves.contains($0.piste.cle) }
    }

    /// Les records : meilleure semaine, meilleur mois (mois hébreu, par `moisDe`), meilleur jour.
    public struct Records: Hashable, Sendable {
        public let jour: Int
        public let semaine: Int
        public let mois: Int

        public init(jour: Int, semaine: Int, mois: Int) {
            self.jour = jour
            self.semaine = semaine
            self.mois = mois
        }
    }

    public static func records(_ minutes: [JourCivil: Int], moisDe: (JourCivil) -> String) -> Records {
        var semaines: [JourCivil: Int32] = [:]
        var mois: [String: Int32] = [:]
        for (jour, m) in minutes {
            let dimanche = jour.plus(jours: 1 - jour.jourDeSemaine)
            semaines[dimanche, default: 0] &+= Int32(truncatingIfNeeded: m)
            mois[moisDe(jour), default: 0] &+= Int32(truncatingIfNeeded: m)
        }
        let semaine = semaines.values.max().map { Int($0) } ?? 0
        let meilleurMois = mois.values.max().map { Int($0) } ?? 0
        return Records(jour: minutes.values.max() ?? 0, semaine: semaine, mois: meilleurMois)
    }
}
