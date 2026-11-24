import Foundation

/// Le plan du ciel du Jour (PlanCiel de CielPage.kt, 24/11) : où passent l'astre, les étoiles et les nuages. Pur, en
/// points (le dp d'Android) : TeintesCielTests et CielContinuTests le vérifient ; la vue du Jour le dessine.
///
/// Les zones sont celles de la page, en points, dans le contenu qui défile (haut du contenu = 0), de gauche à droite
/// à l'écran quelle que soit la langue : le soleil se lève à gauche et se couche à droite, en hébreu comme en
/// français, comme sur Android.
public enum PlanCiel {

    /// Un rectangle, en points, dans le contenu du Jour.
    public struct Zone: Sendable, Equatable {
        public let gauche: Double, haut: Double, droite: Double, bas: Double

        public init(gauche: Double, haut: Double, droite: Double, bas: Double) {
            self.gauche = gauche
            self.haut = haut
            self.droite = droite
            self.bas = bas
        }

        /// Le carré qui entoure le cercle (`cx`, `cy`, `r`) mord sur la zone.
        public func touche(_ cx: Double, _ cy: Double, _ r: Double) -> Bool {
            cx + r > gauche && cx - r < droite && cy + r > haut && cy - r < bas
        }

        public var largeur: Double { droite - gauche }
        public var hauteur: Double { bas - haut }
    }

    /// La couronne vive et la lueur large, en rayons du disque ; les rayons de l'heure dorée.
    public static let couronne = 2.2
    public static let lueur = 4.2
    public static let rayons = 12

    /// L'écart entre une étoile et le texte le plus proche, en points.
    public static let margeEtoile = 6.0

    /// La hauteur des collines du bas du premier écran, en points.
    public static let collines = 72.0

    /// Le bord éclairé d'un nuage dépasse de son corps vers le bas de 3 points.
    public static let bordNuage = 3.0

    /// Le centre de l'astre sur son arc, en points : de la place libre à gauche des anneaux (`progres` 0, le lever) à
    /// celle de droite (`progres` 1, le coucher), en passant derrière les anneaux vers le milieu du jour ; la hauteur
    /// (`hauteur` 0 : l'horizon, au bas des anneaux ; 1 : le haut des anneaux) suit celle du soleil. La couronne
    /// (`couronne`) reste dans la hauteur des anneaux. Nil si elle toucherait un texte. Sur un écran étroit, où la
    /// marge des anneaux est plus mince que le disque, il s'arrête au bord de l'écran.
    ///
    /// L'abscisse s'attarde dans les marges : x = centre ∓ écart × |cos(π·progrès)|^0,4. Et il longe le disque des
    /// anneaux sans s'y cacher, tout entier dehors (son centre au moins à un rayon du cercle), jusqu'à trois quarts
    /// d'heure environ de midi (|cos(π·progrès)| < `longe`), où il glisse derrière, puis ressort de l'autre côté.
    public static func arc(progres: Double, hauteur: Double, jauge: Zone, largeur: Double, r: Double,
                           couronne: Double, zones: [Zone]) -> (x: Double, y: Double)? {
        if largeur < 2 * r { return nil }
        let cx = (jauge.gauche + jauge.droite) / 2
        let cy = (jauge.haut + jauge.bas) / 2
        let rayonAnneaux = min(jauge.largeur, jauge.hauteur) / 2
        let gauche = jauge.gauche / 2
        let droite = (jauge.droite + largeur) / 2
        let u = cos(.pi * min(max(progres, 0), 1))
        let pousse = pow(abs(u), 0.4)
        let bas = jauge.bas - couronne
        let hautArc = jauge.haut + couronne
        let y = bas - max(bas - hautArc, 0) * min(max(hauteur, 0), 1)
        let loin = rayonAnneaux + r
        let longe = sqrt(max(loin * loin - (y - cy) * (y - cy), 0)) * min(abs(u) / PlanCiel.longe, 1)
        let ecart = max((u >= 0 ? cx - gauche : droite - cx) * pousse, longe)
        let x = min(max(u >= 0 ? cx - ecart : cx + ecart, r), largeur - r)
        if zones.contains(where: { $0.touche(x, y, couronne) }) { return nil }
        return (x, y)
    }

    /// Près de midi (|cos(π·progrès)| sous ce seuil : 45 minutes d'un jour de douze heures), l'astre cesse de longer
    /// les anneaux et glisse derrière.
    public static let longe = 0.2

    /// Combien d'étoiles (une pour 4 600 points², 24 à 72) et jusqu'où (les quatre cinquièmes du haut).
    public static func etoiles(largeur: Double, hauteur: Double) -> (nombre: Int, limite: Double) {
        (min(max(Kotlin.versInt(Double(Float(largeur) * Float(hauteur) / 4600)), 24), 72), Double(Float(0.78)))
    }

    /// Les étoiles qui se montrent : aucune à moins de `margeEtoile` (plus son rayon et sa dérive) d'une zone de
    /// texte, d'icône ou des anneaux. Leurs places sont des fractions de `largeur` et de `hauteur`
    /// (`CielVivant.etoiles`).
    public static func libres(_ etoiles: [Float], largeur: Double, hauteur: Double, zones: [Zone]) -> [Bool] {
        let n = etoiles.count / CielVivant.champs
        let ecart = margeEtoile + Double(max(CielVivant.deriveXDp, CielVivant.deriveYDp))
        return (0..<n).map { i in
            let o = i * CielVivant.champs
            let x = Double(etoiles[o]) * largeur
            let y = Double(etoiles[o + 1]) * hauteur
            return !zones.contains { $0.touche(x, y, Double(etoiles[o + 2]) * 1.6 + ecart) }
        }
    }

    /// Un nuage : départ (part de la largeur), place dans la hauteur des anneaux (0 en haut, 1 en bas), échelle,
    /// forme (0 bombé, 1 long).
    public struct Nuage: Sendable {
        public let depart: Double, place: Double, echelle: Double, forme: Int
    }

    /// Les trois nuages. Ils passent dans la bande des anneaux, à côté d'eux et derrière eux : il n'y a pas de texte,
    /// ils peuvent y être vifs.
    public static let nuages: [Nuage] = [
        Nuage(depart: 0.08, place: 0.06, echelle: 0.9, forme: 0),
        Nuage(depart: 0.30, place: 0.52, echelle: 0.8, forme: 1),
        Nuage(depart: 0.62, place: 0.86, echelle: 0.75, forme: 0),
    ]

    /// L'opacité d'un nuage vif, à son plus fort (la nuit, `CielContinu.nuages` l'atténue).
    public static let nuageVif = 0.85

    /// La hauteur (points) du nuage `i` de hauteur `haut` : dans la bande des anneaux, sinon dans le haut de l'écran.
    public static func nuageY(_ i: Int, jauge: Zone?, hauteurVue: Double, haut: Double) -> Double {
        let f = nuages[i].place
        if let jauge { return jauge.haut + f * max(jauge.bas - jauge.haut - haut, 0) }
        return hauteurVue * (0.1 + 0.4 * f)
    }

    /// Aucune zone de texte ne coupe la bande horizontale [haut, bas] : un nuage peut y passer vif.
    public static func bandeLibre(haut: Double, bas: Double, zones: [Zone]) -> Bool {
        !zones.contains { $0.bas > haut && $0.haut < bas }
    }

    /// La taille des deux formes, en points : bombé, long.
    public static let tailles: [(largeur: Double, hauteur: Double)] = [(128, 48), (240, 30)]

    /// Leurs formes : centre et demi-axes de chaque ovale, en parts de leur cadre.
    public static let formeNuage: [(cx: Double, cy: Double, rx: Double, ry: Double)] = [
        (0.30, 0.62, 0.22, 0.22),
        (0.50, 0.45, 0.20, 0.30),
        (0.68, 0.60, 0.20, 0.22),
        (0.50, 0.70, 0.38, 0.16),
    ]
    public static let formeVoile: [(cx: Double, cy: Double, rx: Double, ry: Double)] = [
        (0.30, 0.50, 0.24, 0.15),
        (0.55, 0.48, 0.30, 0.18),
        (0.78, 0.52, 0.18, 0.14),
    ]

    /// La lune d'un jour du mois, à plat : le disque entier à peine (14 %), puis sa part éclairée, à droite quand elle
    /// croît, à gauche quand elle décroît. Le terminateur est une demi-ellipse de demi-largeur r·|1 − 2k| (k, la part
    /// éclairée) : bombée vers la lumière en croissant (`versLumiere`), vers l'ombre en lune gibbeuse. Nil : trop
    /// mince pour être dessinée (moins de 2 %).
    public static func terminateur(_ l: CielContinu.Lune) -> (demiLargeur: Double, versLumiere: Bool)? {
        let k = Float(l.eclairee)
        if k < 0.02 { return nil }
        return (Double(abs(1 - 2 * k)), k < 0.5)
    }

    /// L'opacité du disque entier de la lune, sous sa part éclairée (36 sur 255).
    public static let luneDisque = 36.0 / 255

    // MARK: Le tracé d'un moment

    /// Le plan pour une taille de page et un moment (CielPage.tracer) : l'astre, les étoiles retenues, le disque des
    /// anneaux, la hauteur des nuages et ceux qui restent loin de tout texte (couleurs vives).
    public struct Trace: Sendable {
        /// Le centre de l'astre ; nil s'il toucherait un texte, ou sans anneaux.
        public let astre: (x: Double, y: Double)?
        public let estSoleil: Bool
        /// Le rayon du disque, en points.
        public let rayon: Double
        /// L'opacité du disque (il paraît et s'efface à l'horizon) et celle de sa lueur.
        public let astreAlpha: Double
        public let lueurAlpha: Double
        /// Les étoiles (`CielVivant.etoiles`), celles qui se montrent, et la part du premier écran qu'elles occupent.
        public let etoiles: [Float]
        public let libres: [Bool]
        public let limite: Double
        /// Le disque des anneaux, qui ne laisse rien passer de l'astre ni des nuages : centre et rayon.
        public let anneaux: (cx: Double, cy: Double, r: Double)?
        /// Pour chaque nuage : sa hauteur (points) et s'il reste loin de tout texte (couleurs vives).
        public let nuagesY: [Double]
        public let nuagesVifs: [Bool]
    }

    /// Le tracé du ciel du Jour : `etat` le moment, `sombre` le thème, `jauge` le carré des anneaux et `zones` ce qui
    /// porte du texte (points, dans le contenu qui défile), `largeur` celle de la page, `hauteurVue` celle du premier
    /// écran.
    public static func tracer(etat: EtatCiel, sombre: Bool, jauge: Zone?, zones: [Zone], largeur: Double,
                              hauteurVue: Double) -> Trace {
        let e = etat.hauteur
        // Le soleil jusqu'à 3° sous l'horizon ; ensuite la lune, à la hauteur inversée du soleil.
        let estSoleil = etat.estSoleil
        let r = Double(estSoleil ? CielContinu.rayonSoleil(e) : CielContinu.rayonLune)
        let progres = estSoleil ? etat.progresJour : etat.progresNuit
        let haut = CielContinu.elevationDessinee(estSoleil ? e : -e)
        let place = jauge.flatMap {
            arc(progres: progres, hauteur: haut, jauge: $0, largeur: largeur, r: r, couronne: r * couronne,
                zones: zones)
        }
        let (nombre, limite) = etoiles(largeur: largeur, hauteur: hauteurVue)
        let liste = CielVivant.etoiles(nombre, graine: CielVivant.graine, rayonMin: sombre ? 0.7 : 1.0,
                                       rayonMax: sombre ? 1.7 : 2.0)
        let libres = libres(liste, largeur: largeur, hauteur: hauteurVue * limite,
                            zones: zones + (jauge.map { [$0] } ?? []))
        let anneaux = jauge.map { j in
            ((j.gauche + j.droite) / 2, (j.haut + j.bas) / 2, min(j.largeur, j.hauteur) / 2)
        }
        var nuagesY: [Double] = []
        var nuagesVifs: [Bool] = []
        for (i, n) in nuages.enumerated() {
            let h = tailles[n.forme].hauteur * n.echelle
            let y = nuageY(i, jauge: jauge, hauteurVue: hauteurVue, haut: h)
            nuagesY.append(y)
            nuagesVifs.append(jauge != nil && bandeLibre(haut: y, bas: y + h + bordNuage, zones: zones))
        }
        return Trace(astre: place, estSoleil: estSoleil, rayon: r, astreAlpha: etat.astreVisible,
                     lueurAlpha: etat.lueurVisible, etoiles: liste, libres: libres, limite: limite,
                     anneaux: anneaux, nuagesY: nuagesY, nuagesVifs: nuagesVifs)
    }
}
