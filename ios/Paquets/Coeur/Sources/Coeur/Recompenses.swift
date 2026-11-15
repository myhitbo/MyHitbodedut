import Foundation

/// `Paliers.kt` : les paliers d'objectifs (יעדים, demande du 11/10). Après chaque palier atteint, le suivant ;
/// six pistes, chacune son échelle, puis un pas régulier. Les échelles sont recopiées de Kotlin et confrontées
/// à `tables.json` (écrit par la JVM) dans les tests. Jugé par `Tests/Vecteurs/recompenses.json`.
public enum Paliers {

    public enum Piste: String, Sendable, CaseIterable {
        case serie, jour, semaine, mois, cumul, jours

        public var cle: String { rawValue }
    }

    /// L'échelle de base et le pas au-delà, par piste.
    static func base(_ piste: Piste) -> ([Int], Int) {
        switch piste {
        case .serie: ([3, 7, 14, 18, 21, 30, 40, 50, 70, 100, 150, 180, 250, 365], 365)
        case .jour: ([10, 15, 20, 30, 45, 60, 90, 120], 60)
        case .semaine: ([30, 60, 90, 120, 180, 240, 300, 420, 600, 840], 300)
        case .mois: ([60, 120, 180, 300, 450, 600, 900, 1200, 1800, 2400, 3000, 3600], 1200)
        case .cumul: ([60, 180, 300, 600, 1080, 1500, 2160, 3000, 4320, 6000, 9000, 12000, 18000, 24000, 30000, 36000,
                       48000, 60000], 12000)
        case .jours: ([1, 3, 7, 10, 18, 30, 40, 50, 70, 100, 150, 180, 250, 365, 500, 613, 800, 1000], 250)
        }
    }

    /// L'échelle d'une piste jusqu'à couvrir `jusqua` ; la piste du jour y ajoute l'objectif quotidien.
    public static func echelle(_ piste: Piste, jusqua: Int, objectifJour: Int = 0) -> [Int] {
        let (paliers, pas) = base(piste)
        var liste = paliers
        if piste == .jour && objectifJour > 0 && !liste.contains(objectifJour) { liste.append(objectifJour) }
        liste.sort()
        while let dernier = liste.last, dernier <= jusqua { liste.append(dernier + pas) }
        return liste
    }

    public struct Etat: Sendable, Equatable {
        public let piste: Piste
        public let valeur: Int
        /// Le dernier palier atteint, 0 s'il n'y en a pas encore.
        public let atteint: Int
        /// Le palier visé : le premier au-dessus de la valeur.
        public let prochain: Int
        /// Combien de paliers sont atteints.
        public let rang: Int

        public var reste: Int { prochain - valeur }

        /// De 0 à 1 : la valeur rapportée au prochain palier, en simple précision comme Kotlin.
        public var avancee: Float { min(max(Float(valeur) / Float(prochain), 0), 1) }
    }

    public static func etat(_ piste: Piste, _ valeur: Int, objectifJour: Int = 0) -> Etat {
        let v = max(valeur, 0)
        let e = echelle(piste, jusqua: v, objectifJour: objectifJour)
        let faits = e.filter { $0 <= v }
        return Etat(piste: piste, valeur: v, atteint: faits.last ?? 0, prochain: e.first { $0 > v } ?? v + 1,
                    rang: faits.count)
    }

    /// Ce que la pratique donne : les minutes par jour fait.
    public struct Bilan: Sendable, Equatable {
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

        public var debutSemaine: JourCivil { aujourdhui.plus(jours: 1 - aujourdhui.jourDeSemaine) }

        public func entre(_ debut: JourCivil, _ fin: JourCivil? = nil) -> Int {
            let borne = fin ?? aujourdhui
            return minutes.filter { $0.key >= debut && $0.key <= borne }.values.reduce(0, +)
        }
    }

    public static func etats(_ b: Bilan) -> [Etat] {
        [etat(.serie, b.serie),
         etat(.jour, b.minutes[b.aujourdhui] ?? 0, objectifJour: b.objectifJour),
         etat(.semaine, b.entre(b.debutSemaine)),
         etat(.mois, b.entre(b.debutMoisHebreu)),
         etat(.cumul, b.minutes.values.reduce(0, +)),
         etat(.jours, b.minutes.count)]
    }

    /// Le palier mis en avant à l'accueil : parmi la série, le jour, la semaine et le mois, celui dont on est le
    /// plus près ; à égalité, le premier (`maxByOrNull`).
    public static func aLaUne(_ etats: [Etat]) -> Etat? {
        var meilleur: Etat?
        for e in etats where [.serie, .jour, .semaine, .mois].contains(e.piste) {
            if let m = meilleur, !(e.avancee > m.avancee) { continue }
            meilleur = e
        }
        return meilleur
    }

    /// Les marques des paliers atteints : une fois pour toutes pour la série, le cumul et les jours ; par période
    /// pour le jour, la semaine et le mois.
    public static func marques(_ etats: [Etat], _ b: Bilan) -> Set<String> {
        var resultat = Set<String>()
        for e in etats {
            let periode: String
            switch e.piste {
            case .jour: periode = ":\(b.aujourdhui.iso)"
            case .semaine: periode = ":\(b.debutSemaine.iso)"
            case .mois: periode = ":\(b.debutMoisHebreu.iso)"
            case .serie, .cumul, .jours: periode = ""
            }
            for p in echelle(e.piste, jusqua: e.valeur, objectifJour: b.objectifJour) where p <= e.valeur {
                resultat.insert("\(e.piste.cle)\(periode):\(p)")
            }
        }
        return resultat
    }

    /// Les paliers atteints depuis la dernière visite : l'état de chaque piste qui a une marque neuve.
    public static func nouveaux(_ etats: [Etat], _ b: Bilan, vus: Set<String>) -> [Etat] {
        let neuves = Set(marques(etats, b).subtracting(vus).map { $0.avantUnites(":") })
        return etats.filter { neuves.contains($0.piste.cle) }
    }

    /// Les records : meilleur jour, meilleure semaine (du dimanche), meilleur mois (hébreu, par `moisDe`).
    public struct Records: Sendable, Equatable {
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
        var semaines: [JourCivil: Int] = [:]
        var mois: [String: Int] = [:]
        for (jour, m) in minutes {
            semaines[jour.plus(jours: 1 - jour.jourDeSemaine), default: 0] += m
            mois[moisDe(jour), default: 0] += m
        }
        return Records(jour: minutes.values.max() ?? 0, semaine: semaines.values.max() ?? 0, mois: mois.values.max() ?? 0)
    }
}

/// `Trophees.kt` : onze familles à niveaux (12/10), le métal qui monte, le chemin du plus facile au plus dur
/// (15/10), le grade, les dates de gain rejouées jour après jour (16/10), le Tikoun (04/11). Les familles sont
/// recopiées de Kotlin et confrontées à `tables.json`. Jugé par `Tests/Vecteurs/recompenses.json`.
public enum Trophees {

    public enum Metal: String, Sendable, CaseIterable, Comparable {
        case bronze = "BRONZE", argent = "ARGENT", or = "OR", platine = "PLATINE"

        var rang: Int { Metal.allCases.firstIndex(of: self) ?? 0 }

        public static func < (a: Metal, b: Metal) -> Bool { a.rang < b.rang }
    }

    /// L'objet (12/10) ; clé de `trophees_formes.json`.
    public enum Forme: String, Sendable, CaseIterable {
        case coupe, ecusson, etoile, rosette, medaille, pieces, cristal, gemme, kinor
    }

    public enum Famille: String, Sendable, CaseIterable {
        case premierPas = "premier_pas", seanceLongue = "seance_longue", jours, serie, heures, semaines
        case erevChabbat = "erev_chabbat", retour, plume, tikkun
        case tikkunSerie = "tikkun_serie"

        public var cle: String { rawValue }

        /// La clé de l'icône au trait (variante B, 16/10) : celle de la famille.
        public var icone: String { rawValue }

        /// Le nom de l'énumération Kotlin (`PREMIER_PAS`).
        public var nom: String { rawValue.uppercased() }

        var rang: Int { Famille.allCases.firstIndex(of: self) ?? 0 }

        public var seuils: [Int] {
            switch self {
            case .premierPas: [1, 2, 3, 4, 5]
            case .seanceLongue: [10, 15, 20, 30, 40, 45, 50, 60, 75, 90, 105, 120, 150, 180]
            case .jours: [7, 10, 15, 18, 20, 30, 40, 45, 50, 60, 70, 80, 90, 100, 120, 150, 180, 200, 250, 300, 365, 400,
                          500, 613]
            case .serie: [3, 5, 7, 10, 15, 18, 20, 30, 40, 45, 50, 60, 70, 80, 90, 100]
            case .heures: [1, 2, 5, 10, 15, 20, 25, 30, 40, 45, 50, 60, 75, 100, 150, 200, 250, 300]
            case .semaines: [1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 26, 30, 40, 45, 52]
            case .erevChabbat: [1, 4, 12, 26, 52]
            case .retour: [1, 3, 5, 10]
            case .plume: [1, 10, 25, 50, 100, 150]
            case .tikkun: [1, 3, 7, 10, 18, 26, 40, 50, 70, 100, 150, 200]
            case .tikkunSerie: [3, 7, 10, 18, 30, 40, 70, 100]
            }
        }

        public var forme: Forme {
            switch self {
            case .premierPas: .rosette
            case .seanceLongue, .plume: .coupe
            case .jours: .medaille
            case .serie: .etoile
            case .heures: .pieces
            case .semaines: .ecusson
            case .erevChabbat: .cristal
            case .retour: .gemme
            case .tikkun, .tikkunSerie: .kinor
            }
        }
    }

    /// Un niveau atteint : `rang` de 1 au nombre de seuils de la famille.
    public struct Niveau: Sendable, Hashable {
        public let famille: Famille
        public let rang: Int

        public init(_ famille: Famille, _ rang: Int) {
            self.famille = famille
            self.rang = rang
        }

        public var cle: String { "\(famille.cle):\(rang)" }
        public var seuil: Int { famille.seuils[rang - 1] }
        public var metal: Metal { Trophees.metal(famille, rang) }
    }

    /// Le métal d'un rang : un quart de la famille par métal ; une famille d'un seul niveau est de bronze.
    public static func metal(_ f: Famille, _ rang: Int) -> Metal {
        let n = f.seuils.count
        if n == 1 { return .bronze }
        return Metal.allCases[min(max((rang - 1) * 4 / n, 0), 3)]
    }

    /// Ce que les trophées regardent : les minutes par jour fait, les notes écrites, la meilleure série, et les
    /// jours où le Tikoun HaKlali a été dit en entier.
    public struct Pratique: Sendable, Equatable {
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

    /// La plus longue suite de jours consécutifs.
    public static func plusLongueSuite(_ jours: Set<JourCivil>) -> Int {
        var meilleure = 0
        var courante = 0
        var avant: JourCivil?
        for d in jours.sorted() {
            if let a = avant, d.jourJulien - a.jourJulien == 1 { courante += 1 } else { courante = 1 }
            meilleure = max(meilleure, courante)
            avant = d
        }
        return meilleure
    }

    /// Les semaines pleines : six jours faits, du dimanche au vendredi.
    public static func semainesPleines(_ jours: Set<JourCivil>) -> Int {
        jours.filter { d in d.jourDeSemaine == 1 && (0...5).allSatisfy { jours.contains(d.plus(jours: $0)) } }.count
    }

    /// Les retours : un jour de pratique après plus de sept jours sans.
    public static func retours(_ jours: Set<JourCivil>) -> Int {
        let tries = jours.sorted()
        return zip(tries, tries.dropFirst()).filter { paire in paire.1.jourJulien - paire.0.jourJulien > 7 }.count
    }

    /// La valeur que la famille compte. Un jour validé compte, même à 0 min.
    public static func valeur(_ p: Pratique, _ f: Famille) -> Int {
        let jours = Set(p.minutes.keys)
        switch f {
        case .premierPas: return min(jours.count, 5)
        case .seanceLongue: return p.minutes.values.max() ?? 0
        case .jours: return jours.count
        case .serie: return p.meilleureSerie
        case .heures: return p.minutes.values.reduce(0, +) / 60
        case .semaines: return semainesPleines(jours)
        case .erevChabbat: return jours.filter { $0.jourDeSemaine == 6 }.count
        case .retour: return retours(jours)
        case .plume: return p.notes
        case .tikkun: return p.tikkun.count
        case .tikkunSerie: return plusLongueSuite(p.tikkun)
        }
    }

    /// Le rang atteint dans une famille : 0 tant que le premier seuil manque.
    public static func rang(_ p: Pratique, _ f: Famille) -> Int {
        let v = valeur(p, f)
        return f.seuils.filter { v >= $0 }.count
    }

    /// Tous les niveaux atteints, chacun pour soi.
    public static func gagnes(_ p: Pratique) -> Set<Niveau> {
        var resultat = Set<Niveau>()
        for f in Famille.allCases {
            let r = rang(p, f)
            if r > 0 { for k in 1...r { resultat.insert(Niveau(f, k)) } }
        }
        return resultat
    }

    /// Le coût d'un niveau : le nombre de jours qu'il faut, à un quart d'heure par jour (choix de l'application).
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
        case .tikkun: return s * 2.0
        case .tikkunSerie: return s * 3.0
        }
    }

    /// Le chemin (15/10) : tous les niveaux de toutes les familles, du plus facile au plus dur ; à coût égal,
    /// l'ordre des familles, puis celui des seuils (le tri de Kotlin est stable).
    public static let chemin: [Niveau] = {
        let tous = Famille.allCases.flatMap { f in f.seuils.indices.map { Niveau(f, $0 + 1) } }
        return tous.sorted { a, b in
            let ca = cout(a.famille, a.seuil), cb = cout(b.famille, b.seuil)
            if ca != cb { return ca < cb }
            if a.famille != b.famille { return a.famille.rang < b.famille.rang }
            return a.rang < b.rang
        }
    }()

    public static func gagne(_ p: Pratique, _ n: Niveau) -> Bool { valeur(p, n.famille) >= n.seuil }

    /// Le grade (15/10) : bronze, argent dès le 10ᵉ trophée, or dès le 25ᵉ, platine dès le 50ᵉ.
    public static let seuilsGrades = [0, 10, 25, 50]

    public static func grade(_ compte: Int) -> Metal {
        Metal.allCases[max(seuilsGrades.filter { compte >= $0 }.count - 1, 0)]
    }

    /// De 0 à 1 vers une étape, en simple précision.
    public static func fraction(_ p: Pratique, _ n: Niveau) -> Float {
        Float(min(valeur(p, n.famille), n.seuil)) / Float(n.seuil)
    }

    /// Le prochain trophée : parmi ceux à gagner, le plus près d'être atteint ; à égalité, le plus facile, puis
    /// le premier du chemin (`maxWithOrNull` garde le premier des égaux).
    public static func prochain(_ p: Pratique) -> Niveau? {
        var meilleur: (niveau: Niveau, fraction: Float, cout: Double)?
        for n in chemin where !gagne(p, n) {
            let f = fraction(p, n), c = cout(n.famille, n.seuil)
            if let m = meilleur, !(f > m.fraction || (f == m.fraction && c < m.cout)) { continue }
            meilleur = (n, f, c)
        }
        return meilleur?.niveau
    }

    /// Les `k` trophées à gagner les plus avancés ; à égalité, les plus faciles, puis l'ordre du chemin.
    public static func plusProches(_ p: Pratique, k: Int = 3) -> [Niveau] {
        let candidats = chemin.enumerated().filter { !gagne(p, $0.element) }
            .map { (rang: $0.offset, niveau: $0.element, fraction: fraction(p, $0.element),
                    cout: cout($0.element.famille, $0.element.seuil)) }
        let tries = candidats.sorted { a, b in
            if a.fraction != b.fraction { return a.fraction > b.fraction }
            if a.cout != b.cout { return a.cout < b.cout }
            return a.rang < b.rang
        }
        return tries.prefix(max(k, 0)).map { $0.niveau }
    }

    /// Le prochain trophée, s'il est tout proche : à un dixième du seuil, ou à une unité pour les petits seuils.
    public static func proche(_ p: Pratique) -> Niveau? {
        guard let n = prochain(p) else { return nil }
        let reste = n.seuil - valeur(p, n.famille)
        return reste >= 1 && reste <= max(1, n.seuil / 10) ? n : nil
    }

    /// Le jour où chaque niveau a été gagné (16/10) : l'historique rejoué jour après jour, incrémentalement, avec les
    /// règles de `valeur` et de `Plaque.meilleureSerie` (un jour exempté ne compte pas et ne casse pas).
    public static func datesGain(_ minutes: [JourCivil: Int], notes: Set<JourCivil>, tikkun: Set<JourCivil> = [],
                                 exempte: (JourCivil) -> Bool) -> [String: JourCivil] {
        var resultat: [String: JourCivil] = [:]
        var restants: [Famille: [Niveau]] = [:]
        for n in chemin { restants[n.famille, default: []].append(n) }
        for f in restants.keys { restants[f]?.sort { $0.seuil < $1.seuil } }
        var faits = Set<JourCivil>()
        var jours = 0, plusLongue = 0, total = 0, vendredis = 0, nbRetours = 0
        var semaines = 0, notesVues = 0, courante = 0, meilleure = 0
        var precedent: JourCivil?
        var dimanchesPleins = Set<JourCivil>()
        var tikkunN = 0, tikkunSuite = 0, tikkunMeilleure = 0
        var tikkunAvant: JourCivil?
        let tous = Set(minutes.keys).union(notes).union(tikkun).sorted()
        for d in tous {
            if notes.contains(d) { notesVues += 1 }
            if tikkun.contains(d) {
                tikkunN += 1
                if let a = tikkunAvant, d.jourJulien - a.jourJulien == 1 { tikkunSuite += 1 } else { tikkunSuite = 1 }
                tikkunMeilleure = max(tikkunMeilleure, tikkunSuite)
                tikkunAvant = d
            }
            if let m = minutes[d] {
                faits.insert(d)
                jours += 1
                total += m
                plusLongue = max(plusLongue, m)
                if d.jourDeSemaine == 6 { vendredis += 1 }
                if let avant = precedent, d.jourJulien - avant.jourJulien > 7 { nbRetours += 1 }
                // La série : les jours entre le précédent et celui-ci doivent tous être exemptés.
                if let avant = precedent, (1..<max(d.jourJulien - avant.jourJulien, 1)).allSatisfy({ exempte(avant.plus(jours: $0)) }) {
                    courante += 1
                } else {
                    courante = 1
                }
                meilleure = max(meilleure, courante)
                precedent = d
                let dimanche = d.plus(jours: 1 - d.jourDeSemaine)
                if !dimanchesPleins.contains(dimanche) && (0...5).allSatisfy({ faits.contains(dimanche.plus(jours: $0)) }) {
                    dimanchesPleins.insert(dimanche)
                    semaines += 1
                }
            }
            for f in Famille.allCases {
                guard var niveaux = restants[f] else { continue }
                let v: Int
                switch f {
                case .premierPas: v = min(jours, 5)
                case .seanceLongue: v = plusLongue
                case .jours: v = jours
                case .serie: v = meilleure
                case .heures: v = total / 60
                case .semaines: v = semaines
                case .erevChabbat: v = vendredis
                case .retour: v = nbRetours
                case .plume: v = notesVues
                case .tikkun: v = tikkunN
                case .tikkunSerie: v = tikkunMeilleure
                }
                while let premier = niveaux.first, premier.seuil <= v {
                    resultat[premier.cle] = d
                    niveaux.removeFirst()
                }
                restants[f] = niveaux.isEmpty ? nil : niveaux
            }
            if restants.isEmpty { break }
        }
        return resultat
    }

    /// Où l'on en est vers le niveau suivant ; au sommet, le dernier seuil.
    public struct Progres: Sendable, Equatable {
        public let valeur: Int
        public let cible: Int

        public var fraction: Float { cible <= 0 ? 1 : Float(min(valeur, cible)) / Float(cible) }
    }

    public static func progres(_ p: Pratique, _ f: Famille) -> Progres {
        let r = rang(p, f)
        return Progres(valeur: valeur(p, f), cible: f.seuils[min(r, f.seuils.count - 1)])
    }

    /// Les niveaux gagnés depuis la dernière fois, le plus haut de chaque famille ; rien la première fois (`vus`
    /// nil), ni quand `vus` date d'avant les niveaux (des clés sans « : »). Du plus haut métal au plus bas, puis
    /// du plus haut rang ; à égalité, l'ordre des familles.
    public static func nouveaux(_ gagnes: Set<Niveau>, vus: Set<String>?) -> [Niveau] {
        guard let vus else { return [] }
        if !vus.isEmpty && !vus.contains(where: { $0.contientUnites(":") }) { return [] }
        var hauts: [Famille: Niveau] = [:]
        for n in gagnes where !vus.contains(n.cle) {
            if let h = hauts[n.famille], h.rang >= n.rang { continue }
            hauts[n.famille] = n
        }
        return hauts.values.sorted { a, b in
            let ca = a.metal.rang * 100 + a.rang, cb = b.metal.rang * 100 + b.rang
            if ca != cb { return ca > cb }
            return a.famille.rang < b.famille.rang
        }
    }
}

/// `Celebrations` (Confettis.kt), la règle seulement : ce qui est neuf depuis la dernière visite — un trophée
/// d'abord, sinon le plus haut palier neuf — et l'état à retenir ensuite. Le texte, la fiche, les confettis et
/// la notification viendront avec les écrans (tâches 16 et 20).
public enum Celebrations {

    public struct Neuf: Sendable, Equatable {
        public let trophee: Trophees.Niveau?
        public let palier: Paliers.Etat?
        /// Les marques des paliers et les clés des trophées gagnés : ce qu'on retient une fois la fête faite.
        public let marques: Set<String>
        public let trophees: Set<String>
    }

    public static func neuf(_ bilan: Paliers.Bilan, _ pratique: Trophees.Pratique, paliersVus: Set<String>?,
                            tropheesVus: Set<String>?) -> Neuf {
        let etats = Paliers.etats(bilan)
        let gagnes = Trophees.gagnes(pratique)
        let trophee = Trophees.nouveaux(gagnes, vus: tropheesVus).first
        var palier: Paliers.Etat?
        if let vus = paliersVus {
            // `maxByOrNull { it.rang }` : le premier des plus hauts rangs.
            for e in Paliers.nouveaux(etats, bilan, vus: vus) where palier.map({ e.rang > $0.rang }) ?? true {
                palier = e
            }
        }
        return Neuf(trophee: trophee, palier: trophee == nil ? palier : nil, marques: Paliers.marques(etats, bilan),
                    trophees: Set(gagnes.map { $0.cle }))
    }
}

/// `BilanSemaine.kt` (16/10) : à la première ouverture de la semaine, ce que la semaine écoulée (dimanche → samedi)
/// a donné. Une semaine vide ne fait pas de bilan.
public enum BilanSemaine {

    public struct Bilan: Sendable, Equatable {
        /// Le dimanche de la semaine écoulée.
        public let debut: JourCivil
        public let minutes: Int
        public let jours: Int
        /// Les minutes de la semaine d'avant.
        public let precedente: Int
        /// La meilleure semaine jusque-là : seulement s'il y en avait une avant.
        public let record: Bool
        public let trophees: [Trophees.Niveau]

        public var ecart: Int { minutes - precedente }
    }

    public static func debutSemaine(_ d: JourCivil) -> JourCivil { d.plus(jours: 1 - d.jourDeSemaine) }

    /// Le bilan de la semaine écoulée vue depuis `aujourdhui` ; nil si elle n'a rien compté.
    public static func precedente(_ aujourdhui: JourCivil, minutes: [JourCivil: Int], dates: [String: JourCivil]) -> Bilan? {
        let debut = debutSemaine(aujourdhui).plus(jours: -7)
        let fin = debut.plus(jours: 6)
        func entre(_ a: JourCivil, _ b: JourCivil) -> [JourCivil: Int] { minutes.filter { $0.key >= a && $0.key <= b } }
        let semaine = entre(debut, fin)
        let total = semaine.values.reduce(0, +)
        guard total > 0 else { return nil }
        var avant: [JourCivil: Int] = [:]
        for (jour, m) in minutes where jour < debut { avant[debutSemaine(jour), default: 0] += m }
        let meilleureAvant = avant.values.max() ?? 0
        let trophees = Trophees.chemin.filter { n in dates[n.cle].map { $0 >= debut && $0 <= fin } ?? false }
        return Bilan(debut: debut, minutes: total, jours: semaine.count,
                     precedente: entre(debut.plus(jours: -7), debut.plus(jours: -1)).values.reduce(0, +),
                     record: meilleureAvant > 0 && total > meilleureAvant, trophees: trophees)
    }
}
