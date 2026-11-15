import Foundation

/// Les zmanim en vol (Vol.kt, 28/10), phase 1 : hors ligne, sur la route prévue. Rien ne quitte le
/// téléphone. L'avion est placé sur l'arc de grand cercle entre les deux aéroports, à vitesse constante
/// entre les heures prévues ; avant le décollage, il est au départ, après l'atterrissage, à l'arrivée.
/// Un zman a lieu en vol à l'instant t où le zman du point sous l'avion vaut t : t = zman(position(t)),
/// celui du moteur (Zmanim.jour, au niveau de la mer). Choix et limites : ZMANIM.md, « En vol ».
/// Tout est en UTC, en millisecondes Unix ; les fuseaux ne servent qu'à lire les heures du billet.
public enum Vol {

    /// Un aéroport de `aeroports.json` (tools/aeroports_construction.py).
    public struct Aeroport: Sendable, Equatable {
        public let iata: String
        public let nom: String
        public let ville: String
        public let pays: String
        public let latitude: Double
        public let longitude: Double
        /// Fuseau IANA de l'aéroport : celui des heures du billet.
        public let fuseau: String
        /// Le nom par langue (« he », « fr » ; Wikidata), pour l'affichage.
        public let noms: [String: String]
        /// Les autres noms cherchés : ceux de `noms` et des lieux desservis.
        public let alias: [String]
        /// Les mêmes champs pliés (Aeroports.plier), une fois pour toutes : la recherche ne replie rien.
        let plies: Plies

        struct Plies: Sendable, Equatable {
            let iata: String, ville: String, nom: String, alias: [String]
        }

        public init(iata: String, nom: String, ville: String, pays: String, latitude: Double, longitude: Double,
                    fuseau: String, noms: [String: String] = [:], alias: [String] = []) {
            self.iata = iata
            self.nom = nom
            self.ville = ville
            self.pays = pays
            self.latitude = latitude
            self.longitude = longitude
            self.fuseau = fuseau
            self.noms = noms
            self.alias = alias
            plies = Plies(iata: Aeroports.plier(iata), ville: Aeroports.plier(ville), nom: Aeroports.plier(nom),
                          alias: alias.map(Aeroports.plier))
        }

        /// `copy(fuseau = …)`.
        public func avec(fuseau: String) -> Aeroport {
            Aeroport(iata: iata, nom: nom, ville: ville, pays: pays, latitude: latitude, longitude: longitude,
                     fuseau: fuseau, noms: noms, alias: alias)
        }
    }

    /// Un instant et la position de l'avion.
    public struct Point: Sendable, Equatable {
        public let instant: Int64
        public let latitude: Double
        public let longitude: Double

        public init(instant: Int64, latitude: Double, longitude: Double) {
            self.instant = instant
            self.latitude = latitude
            self.longitude = longitude
        }
    }

    /// Le GPS du téléphone, ou la position reçue du suivi en direct (SuiviVol).
    public enum SourceReleve: Sendable { case gps, direct }

    /// Le vol tel qu'on le saisit : numéro (affiché seulement), aéroports et heures prévues.
    public struct Plan: Sendable, Equatable {
        public var numero: String
        public var depart: Aeroport
        public var arrivee: Aeroport
        public var decollage: Int64
        public var atterrissage: Int64
        /// Un relevé pris en vol : la route passe par lui (deux grands cercles).
        public var releve: Point?
        public var sourceReleve: SourceReleve

        public init(numero: String, depart: Aeroport, arrivee: Aeroport, decollage: Int64, atterrissage: Int64,
                    releve: Point? = nil, sourceReleve: SourceReleve = .gps) {
            self.numero = numero
            self.depart = depart
            self.arrivee = arrivee
            self.decollage = decollage
            self.atterrissage = atterrissage
            self.releve = releve
            self.sourceReleve = sourceReleve
        }
    }

    /// Le relevé compte s'il tombe entre le décollage et l'atterrissage prévus.
    public static func releveUtilisable(_ plan: Plan) -> Bool {
        guard let r = plan.releve else { return false }
        return r.instant > plan.decollage && r.instant < plan.atterrissage
    }

    public enum Invalide: Sendable { case memeAeroport, arriveeAvantDepart, tropLong, fuseauInconnu }

    /// Plus long qu'aucun vol régulier : une erreur de saisie (date d'arrivée, AM/PM).
    public static let dureeMax: Int64 = 22 * 3_600_000

    public static func verifier(_ plan: Plan) -> Invalide? {
        if plan.depart.iata == plan.arrivee.iata { return .memeAeroport }
        if plan.atterrissage <= plan.decollage { return .arriveeAvantDepart }
        if plan.atterrissage - plan.decollage > dureeMax { return .tropLong }
        if zone(plan.depart.fuseau) == nil || zone(plan.arrivee.fuseau) == nil { return .fuseauInconnu }
        return nil
    }

    /// Un fuseau que l'appareil ne connaît pas rend nil plutôt que d'échouer.
    public static func zone(_ fuseau: String) -> Fuseau? { Fuseau(fuseau) }

    /// L'heure du billet (heure locale de l'aéroport) en instant ; nil si le fuseau est inconnu.
    public static func instant(_ local: DateHeure, _ aeroport: Aeroport) -> Int64? { zone(aeroport.fuseau)?.millis(local) }

    /// La position prévue à `t` : grand cercle, vitesse constante ; à l'aéroport hors du vol. Avec un relevé
    /// en vol : du départ au relevé, puis du relevé à l'arrivée, chaque tronçon à vitesse constante.
    public static func position(_ plan: Plan, _ t: Int64) -> Point {
        if let r = plan.releve, releveUtilisable(plan) {
            return t > r.instant
                ? arc(r.latitude, r.longitude, plan.arrivee.latitude, plan.arrivee.longitude, r.instant, plan.atterrissage, t)
                : arc(plan.depart.latitude, plan.depart.longitude, r.latitude, r.longitude, plan.decollage, r.instant, t)
        }
        return arc(plan.depart.latitude, plan.depart.longitude, plan.arrivee.latitude, plan.arrivee.longitude,
                   plan.decollage, plan.atterrissage, t)
    }

    private static func arc(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double,
                            _ debut: Int64, _ fin: Int64, _ t: Int64) -> Point {
        let total = Double(fin - debut)
        let f = min(max(Double(t - debut) / total, 0), 1)
        let a = vecteur(lat1, lon1), b = vecteur(lat2, lon2)
        let omega = acos(min(max(a[0] * b[0] + a[1] * b[1] + a[2] * b[2], -1), 1))
        let p = omega < 1e-9 ? a : (0..<3).map { i in (sin((1 - f) * omega) * a[i] + sin(f * omega) * b[i]) / sin(omega) }
        let lat = asin(min(max(p[2], -1), 1)) * (180 / Double.pi)
        let lon = atan2(p[1], p[0]) * (180 / Double.pi)
        return Point(instant: t, latitude: lat, longitude: lon)
    }

    private static func vecteur(_ lat: Double, _ lon: Double) -> [Double] {
        let la = lat * (Double.pi / 180), lo = lon * (Double.pi / 180)
        return [cos(la) * cos(lo), cos(la) * sin(lo), sin(la)]
    }

    /// La distance du grand cercle, en kilomètres (haversine, rayon moyen : comme Villes.distanceKm).
    public static func distanceKm(_ plan: Plan) -> Double {
        distanceKm(plan.depart.latitude, plan.depart.longitude, plan.arrivee.latitude, plan.arrivee.longitude)
    }

    public static func distanceKm(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        Villes.distanceKm(lat1, lon1, lat2, lon2)
    }

    /// Le décalage de l'heure solaire moyenne au point, arrondi à l'heure (fuseau nautique). Il choisit
    /// seulement quel jour civil demander au moteur ; les zmanim n'en dépendent pas.
    public static func decalageNautique(_ longitude: Double) -> Int { min(max(Kotlin.arrondi(longitude / 15), -12), 12) }

    /// « Etc/GMT-3 » pour UTC+3 : le signe des fuseaux Etc est inversé (tzdb).
    public static func fuseauNautique(_ longitude: Double) -> String {
        let n = decalageNautique(longitude)
        return n == 0 ? "Etc/GMT" : n > 0 ? "Etc/GMT-\(n)" : "Etc/GMT+\(-n)"
    }

    /// Le lieu du moteur pour le point sous l'avion, au niveau de la mer comme tout le profil.
    public static func lieuSous(_ p: Point) -> Zmanim.Lieu {
        Zmanim.Lieu(nom: "", latitude: p.latitude, longitude: p.longitude, altitude: 0, fuseau: fuseauNautique(p.longitude))
    }

    /// Un zman sur la route : l'instant, et où est l'avion à cet instant.
    public struct Evenement: Sendable, Equatable {
        public let cle: String
        public let instant: Int64
        public let latitude: Double
        public let longitude: Double
        /// De combien cet horaire bouge si le vol part 30 min plus tard (avec un relevé, si l'arrivée a
        /// 30 min de retard), en millisecondes ; nil sans correspondant.
        public let ecartSiRetard: Int64?
    }

    /// Ce que l'écran doit dire de la donnée, sans conseil : des faits.
    public enum Reserve: String, Sendable, CaseIterable {
        /// La route passe au-delà de 60° de latitude.
        case hauteLatitude = "haute_latitude"
        /// Un zman n'a pas lieu sur une partie de la route (soleil de minuit, nuit polaire).
        case absent
        /// Le moteur a échoué en un point.
        case erreur
        /// L'avion va plus vite que le soleil vers l'ouest : un zman repasse à rebours.
        case aRebours = "a_rebours"
    }

    /// Le passage du méridien de 180° : la date locale (fuseau nautique) passe de `avant` à `apres`.
    public struct LigneDate: Sendable, Equatable {
        public let instant: Int64
        public let avant: JourCivil
        public let apres: JourCivil
    }

    /// La route prévue seule, ou recalée sur un relevé pris en vol (GPS ou suivi en direct).
    public enum Fiabilite: String, Sendable {
        case routePrevue = "route_prevue"
        case releveGps = "releve_gps"
        case releveDirect = "releve_direct"
    }

    public struct Calcul: Sendable, Equatable {
        public let plan: Plan
        /// Tous les zmanim de la fenêtre (30 h avant le décollage à 30 h après l'atterrissage), dans l'ordre.
        public let evenements: [Evenement]
        public let reserves: Set<Reserve>
        public let lignesDate: [LigneDate]

        public var fiabilite: Fiabilite {
            if !releveUtilisable(plan) { return .routePrevue }
            return plan.sourceReleve == .direct ? .releveDirect : .releveGps
        }

        /// Les zmanim entre le décollage et l'atterrissage.
        public var enVol: [Evenement] { evenements.filter { $0.instant >= plan.decollage && $0.instant <= plan.atterrissage } }
    }

    public static let marge: Int64 = 30 * 3_600_000
    private static let pasVol: Int64 = 5 * 60_000
    private static let pasSol: Int64 = 60 * 60_000
    private static let appariementS = 3 * 3600.0
    private static let toleranceS = 0.5
    public static let latitudeHaute = 60.0
    public static let retard: Int64 = 30 * 60_000

    /// Le calcul complet, avec l'écart de chaque horaire en vol si le départ glisse de 30 minutes.
    public static func calculer(_ plan: Plan) -> Calcul {
        let base = calculerSeul(plan)
        var decale = plan
        // Avec un relevé, le départ est passé : l'incertitude est l'arrivée, 30 min plus tard.
        if !releveUtilisable(plan) { decale.decollage += retard }
        decale.atterrissage += retard
        let autre = calculerSeul(decale)
        let evenements = base.evenements.map { e -> Evenement in
            if e.instant < plan.decollage || e.instant > plan.atterrissage { return e }
            var proche: Evenement?
            for x in autre.evenements where x.cle == e.cle {
                if proche == nil || abs(secondesEntieres(e.instant, x.instant)) < abs(secondesEntieres(e.instant, proche!.instant)) { proche = x }
            }
            let retenu = proche.flatMap { abs(secondesEntieres(e.instant, $0.instant)) <= Int64(appariementS) ? $0 : nil }
            return Evenement(cle: e.cle, instant: e.instant, latitude: e.latitude, longitude: e.longitude,
                             ecartSiRetard: retenu.map { $0.instant - e.instant })
        }
        return Calcul(plan: plan, evenements: evenements, reserves: base.reserves, lignesDate: base.lignesDate)
    }

    /// `Duration.between(a, b).seconds` : les secondes entières, arrondies vers le bas.
    private static func secondesEntieres(_ de: Int64, _ a: Int64) -> Int64 {
        let d = a - de
        return d >= 0 ? d / 1000 : -((-d + 999) / 1000)
    }

    /// Les zmanim d'un lieu un jour, gardés le temps d'un calcul : au sol, l'avion reste au même point
    /// pendant trente heures d'échantillons. Le résultat ne change pas.
    private final class Memoire {
        private struct Cle: Hashable { let latitude: Double, longitude: Double, fuseau: String, jour: JourCivil }
        private var jours: [Cle: [Zmanim.Zman]] = [:]

        func jour(_ lieu: Zmanim.Lieu, _ d: JourCivil) -> [Zmanim.Zman] {
            let cle = Cle(latitude: lieu.latitude, longitude: lieu.longitude, fuseau: lieu.fuseau, jour: d)
            if let z = jours[cle] { return z }
            let z = Zmanim.jour(lieu: lieu, date: d)
            jours[cle] = z
            return z
        }
    }

    private struct Echantillon {
        let t: Int64
        let p: Point
        let occurrences: [String: [Int64]]
    }

    private static func calculerSeul(_ plan: Plan) -> Calcul {
        let memoire = Memoire()
        var reserves = Set<Reserve>()
        var instants: [Int64] = []
        var t = plan.decollage - marge
        while t < plan.decollage { instants.append(t); t += pasSol }
        t = plan.decollage
        while t < plan.atterrissage { instants.append(t); t += pasVol }
        t = plan.atterrissage
        while t <= plan.atterrissage + marge { instants.append(t); t += pasSol }

        let echantillons = instants.map { t -> Echantillon in
            let p = position(plan, t)
            let enVol = t >= plan.decollage && t <= plan.atterrissage
            if enVol && abs(p.latitude) > latitudeHaute { reserves.insert(.hauteLatitude) }
            return Echantillon(t: t, p: p, occurrences: occurrences(p, memoire) { if enVol { reserves.insert($0) } })
        }
        var trouves: [Evenement] = []
        let cles = Zmanim.profil.map { $0.cle }
        for i in 0..<max(0, echantillons.count - 1) {
            let a = echantillons[i], b = echantillons[i + 1]
            let enVol = a.t < plan.atterrissage && b.t > plan.decollage
            for cle in cles {
                let ob = b.occurrences[cle] ?? []
                for o in a.occurrences[cle] ?? [] {
                    // Sans vis-à-vis : la fenêtre de trois jours a glissé avec la date locale.
                    guard let apparie = plusProche(ob, de: o), abs(secondes(o, apparie)) <= appariementS else { continue }
                    let fa = secondes(a.t, o), fb = secondes(b.t, apparie)
                    // Racine dans ]a, b] : le zman du point rejoint l'heure.
                    let descend = fa > 0 && fb <= 0
                    let remonte = fa < 0 && fb >= 0
                    if !descend && !remonte { continue }
                    if remonte && enVol { reserves.insert(.aRebours) }
                    let r = racine(plan, cle, a.t, o, b.t, apparie, memoire)
                    let p = position(plan, r)
                    trouves.append(Evenement(cle: cle, instant: r, latitude: p.latitude, longitude: p.longitude, ecartSiRetard: nil))
                }
            }
        }
        // Un même zman trouvé deux fois à la minute près (aux bornes d'un intervalle) ne compte qu'une fois.
        let tries = trouves.enumerated().sorted { ($0.element.instant, $0.offset) < ($1.element.instant, $1.offset) }.map { $0.element }
        var evenements: [Evenement] = []
        for e in tries where !evenements.contains(where: { $0.cle == e.cle && abs(secondes($0.instant, e.instant)) < 60 }) {
            evenements.append(e)
        }
        return Calcul(plan: plan, evenements: evenements, reserves: reserves, lignesDate: lignesDate(plan, echantillons))
    }

    /// Le premier des instants le plus proche de `de` (`minByOrNull`).
    private static func plusProche(_ liste: [Int64], de: Int64) -> Int64? {
        var meilleur: Int64?
        for x in liste where meilleur == nil || abs(secondes(de, x)) < abs(secondes(de, meilleur!)) { meilleur = x }
        return meilleur
    }

    /// Les zmanim du point pour la veille, le jour et le lendemain (jour du fuseau nautique).
    private static func occurrences(_ p: Point, _ memoire: Memoire, _ signaler: (Reserve) -> Void = { _ in }) -> [String: [Int64]] {
        let lieu = lieuSous(p)
        guard let fuseau = Fuseau(lieu.fuseau) else {
            signaler(.erreur)
            return [:]
        }
        let jour = fuseau.jour(millis: p.instant)
        var parCle: [String: [Int64]] = [:]
        for d in [jour.plus(jours: -1), jour, jour.plus(jours: 1)] {
            for z in memoire.jour(lieu, d) {
                switch z.statut {
                case .ok: if let i = z.instant { parCle[z.cle, default: []].append(millis(i)) }
                case .absent: signaler(.absent)
                case .erreur: signaler(.erreur)
                }
            }
        }
        return parCle
    }

    /// Un instant de Foundation en millisecondes Unix, tronqué comme une `Date` de Java.
    static func millis(_ d: Date) -> Int64 { Int64((d.timeIntervalSince1970 * 1000).rounded(.down)) }

    /// Fausse position (Illinois) sur ]a, b] : t tel que zman(position(t)) = t, à la demi-seconde.
    private static func racine(_ plan: Plan, _ cle: String, _ a: Int64, _ oa: Int64, _ b: Int64, _ ob: Int64, _ memoire: Memoire) -> Int64 {
        var ta = 0.0
        var tb = secondes(a, b)
        var fa = secondes(a, oa)
        var fb = secondes(b, ob)
        var cote = 0
        for _ in 0..<60 {
            let t = fb == fa ? (ta + tb) / 2 : tb - fb * (tb - ta) / (fb - fa)
            let instant = a + Kotlin.versLong(t * 1000)
            let attendu = oa + Kotlin.versLong(secondes(oa, ob) * (t / secondes(a, b)) * 1000)
            guard let o = plusProche(occurrences(position(plan, instant), memoire)[cle] ?? [], de: attendu) else { return instant }
            let f = secondes(instant, o)
            if abs(f) <= toleranceS { return o }
            if (f > 0) == (fa > 0) {
                ta = t
                fa = f
                if cote == -1 { fb /= 2 }
                cote = -1
            } else {
                tb = t
                fb = f
                if cote == 1 { fa /= 2 }
                cote = 1
            }
        }
        return a + Kotlin.versLong((ta + tb) / 2 * 1000)
    }

    private static func secondes(_ de: Int64, _ a: Int64) -> Double { Double(a - de) / 1000 }

    /// Le passage du méridien de 180° en vol, et la date locale de part et d'autre.
    private static func lignesDate(_ plan: Plan, _ echantillons: [Echantillon]) -> [LigneDate] {
        var lignes: [LigneDate] = []
        for i in 0..<max(0, echantillons.count - 1) {
            let a = echantillons[i].p, b = echantillons[i + 1].p
            if a.instant < plan.decollage || b.instant > plan.atterrissage { continue }
            if abs(b.longitude - a.longitude) <= 180 { continue }
            // Vers l'est, la longitude passe de +180 à -180 ; la part du pas avant la ligne.
            let avantLigne = 180 - abs(a.longitude)
            let part = avantLigne / (avantLigne + 180 - abs(b.longitude))
            let t = a.instant + Kotlin.versLong(Double(b.instant - a.instant) * part)
            guard let za = Fuseau(fuseauNautique(a.longitude)), let zb = Fuseau(fuseauNautique(b.longitude)) else { continue }
            lignes.append(LigneDate(instant: t, avant: za.jour(millis: t), apres: zb.jour(millis: t)))
        }
        return lignes
    }

    /// Les horaires qu'attend ZmanimWidget.prochaine, pris sur la route : l'aube passée la plus récente,
    /// puis la première fin de Cha'harit, chki'a et minuit qui la suivent ; sans aube passée (route
    /// polaire), les prochains de chaque zman.
    public static func horaires(_ calcul: Calcul, _ maintenant: Int64) -> [String: Int64] {
        let ev = calcul.evenements
        let alot = ev.last { $0.cle == "alot" && $0.instant <= maintenant }?.instant
        let apres = alot ?? maintenant
        func suivant(_ cle: String) -> Int64? { ev.first { $0.cle == cle && $0.instant > apres }?.instant }
        var h: [String: Int64] = [:]
        h["alot"] = alot
        h["szt_gra"] = suivant("szt_gra")
        h["chkia"] = suivant("chkia")
        h["chatsot_layla"] = suivant("chatsot_layla")
        return h
    }
}

/// La prière du moment (ZmanimWidget.prochaine), sa règle telle qu'Android l'écrit : Cha'harit jusqu'au
/// sof zman tefila (GRA), Min'ha jusqu'à la chki'a, Arvit jusqu'à minuit. Les horaires sont des instants
/// vus d'un fuseau ; « la veille » garde l'heure civile (`minusDays`).
public enum PriereDuMoment {
    public static func prochaine(_ horaires: [String: DateHeureZonee], _ maintenant: DateHeureZonee) -> (priere: String, limite: DateHeureZonee?) {
        // Après minuit et avant l'aube, c'est encore la nuit d'Arvit (audit du 16/10) : jusqu'au milieu de
        // la nuit d'hier s'il n'est pas passé, sans limite affichée ensuite.
        if let alot = horaires["alot"], maintenant < alot {
            let hier = horaires["chatsot_layla"]?.plus(jours: -1)
            return ("arvit", hier.flatMap { maintenant < $0 ? $0 : nil })
        }
        for (priere, cle) in [("chaharit", "szt_gra"), ("minha", "chkia"), ("arvit", "chatsot_layla")] {
            if let limite = horaires[cle], maintenant < limite { return (priere, limite) }
        }
        return ("arvit", nil)
    }
}

/// Les aéroports des zmanim en vol (Aeroports.kt) : OurAirports (domaine public), fuseaux par
/// timezone-boundary-builder (ODbL) ; les noms en hébreu et en français (Wikidata, CC0) pour la recherche.
public enum Aeroports {
    public static let source = "OurAirports (domaine public) ; fuseaux : timezone-boundary-builder (ODbL, © contributeurs OpenStreetMap) ; noms : Wikidata (CC0)"

    private static let langues = ["he", "fr"]

    public static func parse(_ json: String, noms: String? = nil) throws -> [Vol.Aeroport] {
        let lignes = try ObjetJSON(texte: json).tableau("aeroports") ?? []
        let autres = try noms.map { try ObjetJSON(texte: $0).objet("noms") ?? ObjetJSON() }
        return lignes.indices.compactMap { i -> Vol.Aeroport? in
            guard let a = lignes.tableau(i) else { return nil }
            let iata = a.texte(0)
            // [nom he, [villes he], nom fr, [villes fr]]
            var parLangue: [String: String] = [:]
            var alias: [String] = []
            if let n = autres?.tableau(iata) {
                for (k, langue) in langues.enumerated() {
                    let nom = n.texte(2 * k)
                    if !nom.isEmpty {
                        parLangue[langue] = nom
                        alias.append(nom)
                    }
                    let villes = n.tableau(2 * k + 1) ?? []
                    alias.append(contentsOf: villes.indices.map { villes.texte($0) })
                }
            }
            return Vol.Aeroport(iata: iata, nom: a.texte(1), ville: a.texte(2), pays: a.texte(3), latitude: a.double(4),
                                longitude: a.double(5), fuseau: a.texte(6), noms: parLangue, alias: alias)
        }
    }

    /// « Zurich », « zur », « ZRH », « תל אביב », « Londres » : sans accents, points-voyelles, casse ni
    /// ponctuation ; le code IATA exact d'abord, puis la ville, puis le nom et les autres noms.
    public static func chercher(_ aeroports: [Vol.Aeroport], _ texte: String, max: Int = 20) -> [Vol.Aeroport] {
        let q = plier(texte)
        if q.isEmpty { return [] }
        var exact: [Int] = [], ville: [Int] = [], nom: [Int] = []
        for (i, a) in aeroports.enumerated() {
            let p = a.plies
            if p.iata.egalUnites(q) {
                exact.append(i)
            } else if p.ville.commenceParUnites(q) || p.alias.contains(where: { $0.commenceParUnites(q) }) {
                ville.append(i)
            } else if p.nom.contientUnites(q) || p.ville.contientUnites(q) || p.alias.contains(where: { $0.contientUnites(q) }) {
                nom.append(i)
            }
        }
        return (exact + ville + nom).prefix(max).map { aeroports[$0] }
    }

    /// L'aéroport dont la ville (ou un autre nom) est exactement `texte`, déjà plié ; nil sinon.
    public static func exact(_ aeroports: [Vol.Aeroport], _ texte: String) -> Vol.Aeroport? {
        aeroports.first { $0.plies.ville.egalUnites(texte) || $0.plies.alias.contains(where: { $0.egalUnites(texte) }) }
    }

    private static let marques = ExpressionReguliere("\\p{M}")
    private static let ponctuation = ExpressionReguliere("[-\\u05BE'’\"\\u05F3\\u05F4.]")
    /// `\s` de Java, sans drapeau.
    private static let blancs = ExpressionReguliere("[ \\t\\n\\u000B\\f\\r]+")

    /// Les marques (accents, nikoud) ôtées ; tiret, maqaf, apostrophe, guillemets, géresh et points
    /// deviennent des espaces.
    public static func plier(_ s: String) -> String {
        let sansMarques = marques.remplace(s.formeNFD, par: "").lowercased()
        return blancs.remplace(ponctuation.remplace(sansMarques, par: " "), par: " ").rogne
    }

    /// Le nom dans la langue de l'application s'il existe, sinon celui d'OurAirports (en anglais).
    public static func nomLocal(_ a: Vol.Aeroport, _ langue: String) -> String { a.noms[langue == "iw" ? "he" : langue] ?? a.nom }

    public static func parIata(_ aeroports: [Vol.Aeroport], _ iata: String) -> Vol.Aeroport? { aeroports.first { $0.iata == iata } }
}
