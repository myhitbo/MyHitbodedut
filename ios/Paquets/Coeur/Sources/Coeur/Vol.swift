import Foundation

/// Les zmanim en vol (Vol.kt, 28/10), phase 1 : hors ligne, sur la route prévue. Rien ne quitte le
/// téléphone, aucune permission n'est demandée.
///
/// L'avion est placé sur l'arc de grand cercle entre les deux aéroports, à vitesse constante entre les
/// heures prévues de décollage et d'atterrissage ; avant le décollage, il est à l'aéroport de départ,
/// après l'atterrissage, à celui d'arrivée. Un zman a lieu en vol à l'instant t où le zman du point
/// sous l'avion vaut t : t = zman(position(t)). Le zman du point est celui du moteur existant
/// (`Zmanim.jour`, au niveau de la mer, même profil), rien n'est recalculé autrement. Choix et
/// limites : ZMANIM.md, « En vol ».
///
/// Tout est en UTC : les instants sont des millisecondes Unix, et les fuseaux ne servent qu'à lire les
/// heures saisies. Jugé par `web/test/vecteurs_vol.json` (le juge du site, produit par Vol.kt) et par
/// `Tests/Vecteurs/vol.json` (tools/vecteurs_ios/VecteursVol.kt). La prière du moment est dans
/// VolPriere.swift ; Chabbat, les fêtes et le Omer dans VolCalendrier.swift.
public enum Vol {

    /// Un aéroport de aeroports.json (tools/aeroports_construction.py).
    public struct Aeroport: Sendable, Hashable {
        public var iata: String
        public var nom: String
        public var ville: String
        public var pays: String
        public var latitude: Double
        public var longitude: Double
        /// Fuseau IANA de l'aéroport : celui des heures du billet.
        public var fuseau: String
        /// Le nom de l'aéroport par langue (« he », « fr » ; Wikidata, aeroports_noms.json), pour l'affichage.
        public var noms: [String: String]
        /// Les autres noms cherchés : ceux de `noms` et des lieux desservis, en hébreu et en français.
        public var alias: [String]

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
        }
    }

    /// Le vol tel qu'on le saisit : numéro (affiché seulement), aéroports et heures prévues (millisecondes Unix).
    public struct Plan: Sendable, Hashable {
        public var numero: String
        public var depart: Aeroport
        public var arrivee: Aeroport
        public var decollage: Int64
        public var atterrissage: Int64
        /// Un relevé pris en vol (GPS ou suivi en direct) : la route passe par lui (deux grands cercles).
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

    /// Le GPS du téléphone, ou la position reçue du suivi en direct (SuiviVol).
    public enum SourceReleve: String, Sendable, Hashable {
        case gps
        case direct
    }

    /// Le relevé compte s'il tombe entre le décollage et l'atterrissage prévus, bornes exclues.
    public static func releveUtilisable(_ plan: Plan) -> Bool {
        guard let r = plan.releve else { return false }
        return r.instant > plan.decollage && r.instant < plan.atterrissage
    }

    /// Les valeurs brutes sont les noms de Kotlin en minuscules (« meme_aeroport »), ceux des vecteurs.
    public enum Invalide: String, Sendable, Hashable {
        case memeAeroport = "meme_aeroport"
        case arriveeAvantDepart = "arrivee_avant_depart"
        case tropLong = "trop_long"
        case fuseauInconnu = "fuseau_inconnu"
    }

    /// Plus long qu'aucun vol régulier : une erreur de saisie (date d'arrivée, AM/PM). 22 heures, en millisecondes.
    public static let dureeMax: Int64 = 22 * 3_600_000

    public static func verifier(_ plan: Plan) -> Invalide? {
        if plan.depart.iata.egalUnites(plan.arrivee.iata) { return .memeAeroport }
        if !(plan.atterrissage > plan.decollage) { return .arriveeAvantDepart }
        if plan.atterrissage - plan.decollage > dureeMax { return .tropLong }
        if zone(plan.depart.fuseau) == nil || zone(plan.arrivee.fuseau) == nil { return .fuseauInconnu }
        return nil
    }

    /// Un fuseau que l'appareil ne connaît pas (base de fuseaux trop ancienne) rend nil plutôt que d'échouer.
    public static func zone(_ fuseau: String) -> Fuseau? {
        Fuseau(fuseau)
    }

    /// L'heure du billet (heure locale de l'aéroport) en instant UTC, en millisecondes Unix, avec les règles de
    /// `LocalDateTime.atZone` aux changements d'heure ; nil si le fuseau est inconnu.
    public static func instant(_ local: DateHeure, _ aeroport: Aeroport) -> Int64? {
        zone(aeroport.fuseau)?.millis(local)
    }

    /// Un point de la route : l'instant (millisecondes Unix) et la position de l'avion.
    public struct Point: Sendable, Hashable {
        public var instant: Int64
        public var latitude: Double
        public var longitude: Double

        public init(instant: Int64, latitude: Double, longitude: Double) {
            self.instant = instant
            self.latitude = latitude
            self.longitude = longitude
        }
    }

    /// La position prévue à `t` : grand cercle, vitesse constante ; à l'aéroport hors du vol. Avec un relevé en
    /// vol : du départ au relevé, puis du relevé à l'arrivée, chaque tronçon à vitesse constante.
    public static func position(_ plan: Plan, _ t: Int64) -> Point {
        if let r = plan.releve, releveUtilisable(plan) {
            if t > r.instant {
                return arc(r.latitude, r.longitude, plan.arrivee.latitude, plan.arrivee.longitude, r.instant, plan.atterrissage, t)
            }
            return arc(plan.depart.latitude, plan.depart.longitude, r.latitude, r.longitude, plan.decollage, r.instant, t)
        }
        return arc(plan.depart.latitude, plan.depart.longitude, plan.arrivee.latitude, plan.arrivee.longitude,
                   plan.decollage, plan.atterrissage, t)
    }

    // swiftlint:disable:next function_parameter_count
    private static func arc(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double,
                            _ debut: Int64, _ fin: Int64, _ t: Int64) -> Point {
        let total = Double(fin - debut)
        let f = borne(Double(t - debut) / total, 0, 1)
        let a = vecteur(lat1, lon1)
        let b = vecteur(lat2, lon2)
        let produit = a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
        let omega = acos(borne(produit, -1, 1))
        var p = a
        if !(omega < 1e-9) {
            let sa = sin((1 - f) * omega), sb = sin(f * omega), so = sin(omega)
            p = (0..<3).map { i in (sa * a[i] + sb * b[i]) / so }
        }
        let lat = degres(asin(borne(p[2], -1, 1)))
        let lon = degres(atan2(p[1], p[0]))
        return Point(instant: t, latitude: lat, longitude: lon)
    }

    private static func vecteur(_ lat: Double, _ lon: Double) -> [Double] {
        let la = radians(lat)
        let lo = radians(lon)
        return [cos(la) * cos(lo), cos(la) * sin(lo), sin(la)]
    }

    /// La distance du grand cercle, en kilomètres (haversine, rayon moyen : comme Villes.distanceKm).
    public static func distanceKm(_ plan: Plan) -> Double {
        distanceKm(plan.depart.latitude, plan.depart.longitude, plan.arrivee.latitude, plan.arrivee.longitude)
    }

    public static func distanceKm(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let dLat = radians(lat2 - lat1)
        let dLon = radians(lon2 - lon1)
        let sLat = sin(dLat / 2)
        let sLon = sin(dLon / 2)
        let h = sLat * sLat + cos(radians(lat1)) * cos(radians(lat2)) * sLon * sLon
        return 2 * 6371.0 * asin(borne(h, 0, 1).squareRoot())
    }

    /// Le décalage de l'heure solaire moyenne au point, arrondi à l'heure : le fuseau nautique (UTC + n,
    /// n = longitude / 15). Il choisit seulement quel jour civil demander au moteur ; les zmanim n'en dépendent pas.
    public static func decalageNautique(_ longitude: Double) -> Int {
        let n = Kotlin.arrondi(longitude / 15.0)
        if n < -12 { return -12 }
        if n > 12 { return 12 }
        return n
    }

    /// « Etc/GMT-3 » pour UTC+3 : le signe des fuseaux Etc est inversé (tzdb).
    public static func fuseauNautique(_ longitude: Double) -> String {
        let n = decalageNautique(longitude)
        if n == 0 { return "Etc/GMT" }
        return n > 0 ? "Etc/GMT-\(n)" : "Etc/GMT+\(-n)"
    }

    /// Le lieu du moteur pour le point sous l'avion, au niveau de la mer comme tout le profil.
    public static func lieuSous(_ p: Point) -> Zmanim.Lieu {
        Zmanim.Lieu(nom: "", latitude: p.latitude, longitude: p.longitude, altitude: 0, fuseau: fuseauNautique(p.longitude))
    }

    /// Le jour civil de `millis` au fuseau nautique de `longitude` : `instant.atZone(ZoneId.of(fuseauNautique(…)))
    /// .toLocalDate()`. Un fuseau Etc/GMT∓n est un décalage fixe de n heures : le calcul se passe de la base de
    /// fuseaux. Pour ce fichier et VolCalendrier.swift.
    static func jourNautique(_ millis: Int64, _ longitude: Double) -> JourCivil {
        let local = millis + Int64(decalageNautique(longitude)) * 3_600_000
        return JourCivil(jourJulien: 2_440_588 + Kotlin.floorDiv(Int(local), 86_400_000))
    }

    /// Un zman sur la route : l'instant, et où est l'avion à cet instant.
    public struct Evenement: Sendable, Hashable {
        public var cle: String
        public var instant: Int64
        public var latitude: Double
        public var longitude: Double
        /// De combien cet horaire bouge (en millisecondes) si le vol part 30 min plus tard (même durée) ; avec un
        /// relevé, si l'arrivée a 30 min de retard. nil : sans correspondant.
        public var ecartSiRetard: Int64?

        public init(cle: String, instant: Int64, latitude: Double, longitude: Double, ecartSiRetard: Int64? = nil) {
            self.cle = cle
            self.instant = instant
            self.latitude = latitude
            self.longitude = longitude
            self.ecartSiRetard = ecartSiRetard
        }
    }

    /// Ce que l'écran doit dire de la donnée, sans conseil : des faits. Valeurs brutes : les noms de Kotlin en minuscules.
    public enum Reserve: String, Sendable, Hashable, CaseIterable {
        /// La route passe au-delà de 60° de latitude : les méthodes en degrés et en minutes s'écartent, certains zmanim manquent.
        case hauteLatitude = "haute_latitude"
        /// Un zman n'a pas lieu sur une partie de la route (soleil de minuit, nuit polaire).
        case absent
        /// Le moteur a échoué en un point : une erreur, distincte d'un événement absent.
        case erreur
        /// L'avion va plus vite que le soleil vers l'ouest : un zman repasse à rebours.
        case aRebours = "a_rebours"
    }

    /// Le passage du méridien de 180° : la date locale (fuseau nautique) passe de `avant` à `apres`.
    public struct LigneDate: Sendable, Hashable {
        public var instant: Int64
        public var avant: JourCivil
        public var apres: JourCivil

        public init(instant: Int64, avant: JourCivil, apres: JourCivil) {
            self.instant = instant
            self.avant = avant
            self.apres = apres
        }
    }

    /// La fiabilité : la route prévue seule, ou recalée sur un relevé pris en vol (GPS ou suivi en direct).
    public enum Fiabilite: String, Sendable, Hashable {
        case routePrevue = "route_prevue"
        case releveGps = "releve_gps"
        case releveDirect = "releve_direct"
    }

    public struct Calcul: Sendable {
        public var plan: Plan
        /// Tous les zmanim de la fenêtre (30 h avant le décollage à 30 h après l'atterrissage), dans l'ordre.
        public var evenements: [Evenement]
        public var reserves: Set<Reserve>
        public var lignesDate: [LigneDate]
        public var fiabilite: Fiabilite

        /// Sans `fiabilite`, celle du plan : la route prévue, sauf un relevé utilisable (la valeur par défaut de Kotlin).
        public init(plan: Plan, evenements: [Evenement], reserves: Set<Reserve>, lignesDate: [LigneDate],
                    fiabilite: Fiabilite? = nil) {
            self.plan = plan
            self.evenements = evenements
            self.reserves = reserves
            self.lignesDate = lignesDate
            if let fiabilite {
                self.fiabilite = fiabilite
            } else if !Vol.releveUtilisable(plan) {
                self.fiabilite = .routePrevue
            } else {
                self.fiabilite = plan.sourceReleve == .direct ? .releveDirect : .releveGps
            }
        }

        /// Les zmanim entre le décollage et l'atterrissage, bornes comprises.
        public var enVol: [Evenement] {
            evenements.filter { $0.instant >= plan.decollage && $0.instant <= plan.atterrissage }
        }
    }

    /// 30 heures de part et d'autre du vol, en millisecondes.
    public static let marge: Int64 = 30 * 3_600_000
    private static let pasVol: Int64 = 5 * 60_000
    private static let pasSol: Int64 = 60 * 60_000
    private static let appariementS = 3 * 3600.0
    private static let toleranceS = 0.5
    public static let latitudeHaute = 60.0
    /// 30 minutes, en millisecondes.
    public static let retard: Int64 = 30 * 60_000

    /// Le calcul complet, avec l'écart de chaque horaire en vol si le départ glisse de 30 minutes.
    public static func calculer(_ plan: Plan) -> Calcul {
        var memoire = Memoire()
        let base = calculerSeul(plan, &memoire)
        // Avec un relevé, le départ est passé : l'incertitude est l'arrivée, 30 min plus tard.
        var decale = plan
        if releveUtilisable(plan) {
            decale.atterrissage = plan.atterrissage + retard
        } else {
            decale.decollage = plan.decollage + retard
            decale.atterrissage = plan.atterrissage + retard
        }
        let retarde = calculerSeul(decale, &memoire)
        var evenements: [Evenement] = []
        for e in base.evenements {
            if e.instant < plan.decollage || e.instant > plan.atterrissage {
                evenements.append(e)
                continue
            }
            // Le plus proche de même clé, à la seconde entière (Duration.seconds), le premier en cas d'égalité.
            var proche: Evenement?
            var meilleur: Int64 = 0
            for x in retarde.evenements where x.cle.egalUnites(e.cle) {
                let d = abs(secondesEntieres(e.instant, x.instant))
                if proche == nil || d < meilleur {
                    proche = x
                    meilleur = d
                }
            }
            var copie = e
            if let proche, Double(meilleur) <= appariementS {
                copie.ecartSiRetard = proche.instant - e.instant
            }
            evenements.append(copie)
        }
        var calcul = base
        calcul.evenements = evenements
        return calcul
    }

    private struct Echantillon {
        let t: Int64
        let p: Point
        let occurrences: [String: [Int64]]
    }

    private static func calculerSeul(_ plan: Plan, _ memoire: inout Memoire) -> Calcul {
        var reserves = Set<Reserve>()
        var instants: [Int64] = []
        var t = plan.decollage - marge
        while t < plan.decollage {
            instants.append(t)
            t += pasSol
        }
        t = plan.decollage
        while t < plan.atterrissage {
            instants.append(t)
            t += pasVol
        }
        t = plan.atterrissage
        let fin = plan.atterrissage + marge
        while t <= fin {
            instants.append(t)
            t += pasSol
        }
        var echantillons: [Echantillon] = []
        for instant in instants {
            let p = position(plan, instant)
            let enVol = instant >= plan.decollage && instant <= plan.atterrissage
            if enVol && abs(p.latitude) > latitudeHaute { reserves.insert(.hauteLatitude) }
            let o = occurrences(p, &memoire)
            if enVol { reserves.formUnion(o.signaux) }
            echantillons.append(Echantillon(t: instant, p: p, occurrences: o.parCle))
        }
        var trouves: [Evenement] = []
        for i in echantillons.indices.dropLast() {
            let a = echantillons[i]
            let b = echantillons[i + 1]
            let enVol = a.t < plan.atterrissage && b.t > plan.decollage
            for entree in Zmanim.profil {
                let cle = entree.cle
                let oa = a.occurrences[cle] ?? []
                let ob = b.occurrences[cle] ?? []
                for o in oa {
                    // Sans vis-à-vis : la fenêtre de trois jours a glissé avec la date locale. Un zman vraiment
                    // absent est signalé par le moteur (Statut.absent), pas ici.
                    guard let apparie = plusProche(o, ob), abs(secondes(o, apparie)) <= appariementS else { continue }
                    let fa = secondes(a.t, o)
                    let fb = secondes(b.t, apparie)
                    // Racine dans ]a, b] : le zman du point rejoint l'heure.
                    let descend = fa > 0 && fb <= 0
                    let remonte = fa < 0 && fb >= 0
                    if !descend && !remonte { continue }
                    if remonte && enVol { reserves.insert(.aRebours) }
                    let r = racine(plan, cle, a.t, o, b.t, apparie, &memoire)
                    let p = position(plan, r)
                    trouves.append(Evenement(cle: cle, instant: r, latitude: p.latitude, longitude: p.longitude))
                }
            }
        }
        // Le tri de Kotlin est stable : à instant égal, l'ordre de découverte.
        let tries = trouves.enumerated()
            .sorted { ($0.element.instant, $0.offset) < ($1.element.instant, $1.offset) }
            .map { $0.element }
        // Un même zman trouvé deux fois à la seconde près (aux bornes d'un intervalle) ne compte qu'une fois.
        var evenements: [Evenement] = []
        for e in tries {
            var double = false
            for x in evenements where x.cle.egalUnites(e.cle) && abs(secondes(x.instant, e.instant)) < 60 {
                double = true
                break
            }
            if !double { evenements.append(e) }
        }
        return Calcul(plan: plan, evenements: evenements, reserves: reserves, lignesDate: lignesDate(plan, echantillons))
    }

    /// Les zmanim du point pour la veille, le jour et le lendemain (jour du fuseau nautique), dans cet ordre, et ce
    /// que le moteur a signalé : un zman absent, une erreur.
    private static func occurrences(_ p: Point, _ memoire: inout Memoire) -> (parCle: [String: [Int64]], signaux: Set<Reserve>) {
        let lieu = lieuSous(p)
        let jour = jourNautique(p.instant, p.longitude)
        var parCle: [String: [Int64]] = [:]
        var signaux = Set<Reserve>()
        for d in [jour.plus(jours: -1), jour, jour.plus(jours: 1)] {
            let z = memoire.jour(lieu, d)
            for (cle, millis) in z.instants {
                parCle[cle, default: []].append(millis)
            }
            if z.absent { signaux.insert(.absent) }
            if z.erreur { signaux.insert(.erreur) }
        }
        return (parCle, signaux)
    }

    /// Les zmanim déjà demandés au moteur pendant un calcul. `Zmanim.jour` rend toujours la même chose pour un même
    /// lieu et un même jour ; or les points au sol se répètent, et le calcul du retard repasse par les points du
    /// premier, décalés d'une demi-heure. Kotlin redemande chaque fois : le résultat est le même, trois fois moins
    /// d'appels ici (un appel de KosherSwift coûte plus cher que sur la JVM).
    private struct Memoire {
        struct Cle: Hashable {
            let latitude: UInt64
            let longitude: UInt64
            let jour: JourCivil
        }

        /// Les zmanim calculés du jour, dans l'ordre du profil, et ce que le moteur a signalé.
        struct Jour {
            let instants: [(cle: String, millis: Int64)]
            let absent: Bool
            let erreur: Bool
        }

        var jours: [Cle: Jour] = [:]

        mutating func jour(_ lieu: Zmanim.Lieu, _ date: JourCivil) -> Jour {
            let cle = Cle(latitude: lieu.latitude.bitPattern, longitude: lieu.longitude.bitPattern, jour: date)
            if let connu = jours[cle] { return connu }
            var instants: [(cle: String, millis: Int64)] = []
            var absent = false
            var erreur = false
            for z in Zmanim.jour(lieu: lieu, date: date) {
                switch z.statut {
                case .ok:
                    if let d = z.instant { instants.append((cle: z.cle, millis: Vol.millis(d))) }
                case .absent:
                    absent = true
                case .erreur:
                    erreur = true
                }
            }
            let calcule = Jour(instants: instants, absent: absent, erreur: erreur)
            jours[cle] = calcule
            return calcule
        }
    }

    /// Fausse position (Illinois) sur ]a, b] : t tel que zman(position(t)) = t, à la demi-seconde.
    // swiftlint:disable:next function_parameter_count
    private static func racine(_ plan: Plan, _ cle: String, _ a: Int64, _ oa: Int64, _ b: Int64, _ ob: Int64,
                               _ memoire: inout Memoire) -> Int64 {
        var ta = 0.0
        var tb = secondes(a, b)
        var fa = secondes(a, oa)
        var fb = secondes(b, ob)
        var cote = 0
        for _ in 0..<60 {
            let t = fb == fa ? (ta + tb) / 2 : tb - fb * (tb - ta) / (fb - fa)
            let instant = a + Kotlin.versLong(t * 1000)
            let attendu = oa + Kotlin.versLong(secondes(oa, ob) * (t / secondes(a, b)) * 1000)
            let liste = occurrences(position(plan, instant), &memoire).parCle[cle] ?? []
            guard let o = plusProche(attendu, liste) else { return instant }
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

    /// Le passage du méridien de 180° en vol, et la date locale de part et d'autre.
    private static func lignesDate(_ plan: Plan, _ echantillons: [Echantillon]) -> [LigneDate] {
        var lignes: [LigneDate] = []
        for i in echantillons.indices.dropLast() {
            let a = echantillons[i].p
            let b = echantillons[i + 1].p
            if a.instant < plan.decollage || b.instant > plan.atterrissage { continue }
            if abs(b.longitude - a.longitude) <= 180 { continue }
            // Vers l'est, la longitude passe de +180 à -180 ; la part du pas avant la ligne.
            let avantLigne = 180 - abs(a.longitude)
            let part = avantLigne / (avantLigne + 180 - abs(b.longitude))
            let t = a.instant + Kotlin.versLong(Double(b.instant - a.instant) * part)
            lignes.append(LigneDate(instant: t, avant: jourNautique(t, a.longitude), apres: jourNautique(t, b.longitude)))
        }
        return lignes
    }

    /// Les horaires que ZmanimWidget.prochaine attend, pris sur la route : l'aube passée la plus récente, puis la
    /// première fin de Cha'harit, chki'a et minuit qui la suivent. Sans aube passée (route polaire), les prochains
    /// de chaque zman. Les clés : « alot », « szt_gra », « chkia », « chatsot_layla » ; une clé manque là où
    /// Kotlin rend null.
    public static func horaires(_ calcul: Calcul, _ maintenant: Int64) -> [String: Int64] {
        let ev = calcul.evenements
        let alot = ev.last { $0.cle == "alot" && $0.instant <= maintenant }?.instant
        let apres = alot ?? maintenant
        func suivant(_ cle: String) -> Int64? {
            ev.first { $0.cle == cle && $0.instant > apres }?.instant
        }
        var h: [String: Int64] = [:]
        h["alot"] = alot
        h["szt_gra"] = suivant("szt_gra")
        h["chkia"] = suivant("chkia")
        h["chatsot_layla"] = suivant("chatsot_layla")
        return h
    }

    // MARK: Aides

    /// `Duration.between(de, a).toMillis() / 1000.0`.
    private static func secondes(_ de: Int64, _ a: Int64) -> Double {
        Double(a - de) / 1000.0
    }

    /// `Duration.between(de, a).seconds` : les secondes entières, arrondies vers moins l'infini.
    private static func secondesEntieres(_ de: Int64, _ a: Int64) -> Int64 {
        Int64(Kotlin.floorDiv(Int(a - de), 1000))
    }

    /// `minByOrNull { abs(secondes(x, it)) }` : le premier des plus proches.
    private static func plusProche(_ x: Int64, _ liste: [Int64]) -> Int64? {
        var meilleur: Int64?
        var ecart = 0.0
        for y in liste {
            let d = abs(secondes(x, y))
            if meilleur == nil || d < ecart {
                meilleur = y
                ecart = d
            }
        }
        return meilleur
    }

    /// `coerceIn` de Kotlin : NaN passe tel quel.
    private static func borne(_ x: Double, _ bas: Double, _ haut: Double) -> Double {
        if x < bas { return bas }
        if x > haut { return haut }
        return x
    }

    /// `Math.toRadians` et `Math.toDegrees` de Java : une multiplication, dans cet ordre.
    private static func radians(_ x: Double) -> Double { x * 0.017453292519943295 }
    private static func degres(_ x: Double) -> Double { x * 57.29577951308232 }

    /// Un instant de KosherSwift en millisecondes Unix, tronqué comme la `Date` de Java.
    static func millis(_ date: Date) -> Int64 {
        Kotlin.versLong((date.timeIntervalSince1970 * 1000).rounded(.down))
    }
}
