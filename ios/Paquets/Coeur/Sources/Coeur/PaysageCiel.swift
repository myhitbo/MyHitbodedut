import Foundation

/// Le paysage de la carte de Sérénité (PaysageCiel.kt) : le ciel du moment en dégradé, le soleil (ou la lune) dans son
/// halo, les étoiles la nuit, deux collines et une brume. Ici, ce qu'il faut pour le peindre, en couleurs ARGB et en
/// parts de la carte ; la vue le dessine (SereniteCiel).
///
/// Le ciel est continu depuis le 24/11 (`EtatCiel`, `CielContinu`) : ses couleurs passent sans à-coup entre les quatre
/// ciels peints d'avant (nuit, aube, jour, coucher), selon la hauteur du vrai soleil — l'aube et le jour le matin, le
/// jour et le coucher le soir ; les collines passent du jour à la nuit, les étoiles s'allument avec le crépuscule, la
/// lune a sa phase du mois hébreu. Avec `arc` (Sérénité), le soleil puis la lune suivent un arc de la gauche à la
/// droite dans le haut du ciel, libre de texte ; sans, l'astre garde les places des quatre ciels d'avant, de l'une à
/// l'autre en douceur.
///
/// Animé (`CielVivant`), seuls des motifs déjà peints bougent : les étoiles qui scintillent et dérivent d'un rien, le
/// halo qui respire, et sur la carte de Sérénité (`nuages`) un nuage qui prend la lumière du moment, dans le haut du
/// ciel, loin du texte. Étoiles et halo ne dépassent jamais l'éclat du paysage immobile.
public struct PaysageCiel: Sendable {
    public let etat: EtatCiel
    public let nuages: Bool
    public let arc: Bool

    /// Les poids des quatre ciels peints, dans l'ordre nuit, aube, jour, coucher.
    public let poids: [Double]

    /// Le dégradé : les quatre ciels ramenés à six arrêts, mêlés selon leurs poids, sur les 85 % du haut.
    public let couleurs: [UInt32]

    /// La nuit des collines : 0 de jour et à l'aube, 1 la nuit et au coucher (le matin et le soir mêlés comme le ciel).
    public let nuit: Double

    /// Le soleil suit son arc jusqu'à 3° sous l'horizon, puis la lune.
    public let estSoleil: Bool

    public init(etat: EtatCiel, nuages: Bool = false, arc: Bool = false) {
        self.etat = etat
        self.nuages = nuages
        self.arc = arc
        let e = etat.hauteur
        let poids = PaysageCiel.poidsDesCiels(e, matin: etat.matin)
        self.poids = poids
        couleurs = (0..<6).map { i in
            var r = 0.0, g = 0.0, b = 0.0
            for (k, ciel) in PaysageCiel.ciels.enumerated() {
                let c = PaysageCiel.echantillon(ciel, Float(i) / 5)
                r += poids[k] * Double((c >> 16) & 0xFF)
                g += poids[k] * Double((c >> 8) & 0xFF)
                b += poids[k] * Double(c & 0xFF)
            }
            return PaysageCiel.argb(r, g, b)
        }
        nuit = etat.matin * CielContinu.rampe(e, de: -3, a: -12)
            + (1 - etat.matin) * CielContinu.rampe(e, de: 12, a: 3)
        estSoleil = arc ? etat.estSoleil : poids[0] < 0.5
    }

    /// Le rayon du halo, en rayons de l'astre.
    public static let halo = 3.6
    /// La lune des paysages.
    public static let lune: UInt32 = 0xFFF3EBD2
    /// L'étoile des paysages.
    public static let etoile: UInt32 = 0xFFFFF6EC

    /// Le halo : trois arrêts (0, 0,32, 0,64 du rayon), en ARGB avec leur opacité.
    public static let haloArrets: [(position: Double, couleur: UInt32)] = [
        (0, 0xB0FF_D6AA), (0.32, 0x47FF_BE96), (0.64, 0x00FF_BE96),
    ]

    /// Les quarante étoiles du paysage, toujours les mêmes (java.util.Random(29)) : x, y (sur le haut du ciel),
    /// taille ; et le rythme de chacune (cycle, décalage), tiré de la graine 31.
    public static let etoiles: [(x: Float, y: Float, taille: Float)] = {
        var r = HasardJava(graine: 29)
        return (0..<40).map { _ in
            let x = r.nextFloat()
            let y = r.nextFloat() * 0.55
            let t = 1 + r.nextFloat() * 1.6
            return (x, y, t)
        }
    }()
    public static let rythmes: [Float] = CielVivant.etoiles(40, graine: 31, rayonMin: 0, rayonMax: 0)

    /// Les étoiles : toutes la nuit, s'allumant avec le crépuscule (presque rien à +2°, toutes à −10°).
    public var eclatEtoiles: Double { CielContinu.rampe(etat.hauteur, de: 2, a: -10) }

    /// L'astre paraît et s'efface à l'horizon, et là où son arc recommence (arc) ; sans arc il est toujours là.
    public var astreVisible: Double { arc ? etat.astreVisible : 1 }

    /// Le nuage de Sérénité, dans la lumière du moment, quand le ciel en porte assez.
    public var avecNuage: Bool { nuages && CielContinu.nuages(etat.hauteur) > 0.2 }

    /// L'astre : sur son arc (Sérénité), de 12 % à 88 % de la largeur selon la part du jour (ou de la nuit), de 56 %
    /// de la hauteur (l'horizon, derrière les collines) à 24 % selon sa hauteur ; sinon aux places des quatre ciels
    /// d'avant, mêlées selon leurs poids. En points.
    public func astrePlace(largeur w: Double, hauteur h: Double) -> (x: Double, y: Double, rayon: Double) {
        let rayon: Double
        if estSoleil {
            let somme = zip(PaysageCiel.rayons, poids).reduce(0) { $0 + $1.0 * $1.1 }
            rayon = Double(Float(somme / max(1 - poids[0], 0.01)))
        } else {
            rayon = 22
        }
        if arc {
            let progres = estSoleil ? etat.progresJour : etat.progresNuit
            let haut = CielContinu.elevationDessinee(estSoleil ? etat.hauteur : -etat.hauteur)
            return (w * (0.12 + 0.76 * progres), h * (0.56 - 0.32 * haut), min(rayon, 26))
        }
        var x = 0.0, y = 0.0
        for (k, place) in PaysageCiel.places.enumerated() {
            x += poids[k] * place.0
            y += poids[k] * place.1
        }
        return (w * x, h * y, rayon)
    }

    /// La couleur du soleil : celles des trois ciels de jour, mêlées selon leurs poids.
    public var astreCouleur: UInt32 {
        var r = 0.0, g = 0.0, b = 0.0
        let total = max(1 - poids[0], 0.01)
        for (k, c) in PaysageCiel.astres.enumerated() where k > 0 {
            r += poids[k] * Double((c >> 16) & 0xFF)
            g += poids[k] * Double((c >> 8) & 0xFF)
            b += poids[k] * Double(c & 0xFF)
        }
        return PaysageCiel.argb(r / total, g / total, b / total)
    }

    /// Les deux collines (la plus lointaine plus claire) et la brume entre elles, du jour à la nuit.
    public var collineLoin: UInt32 { TeintesCiel.melange(0xFF8FA9C4, 0xFF2A2350, nuit) }
    public var collinePres: UInt32 { TeintesCiel.melange(0xFF4D6B5C, 0xFF151026, nuit) }
    public var brume: UInt32 {
        let voile = TeintesCiel.melange(0xFFFFFFFF, 0xFFF7CDA8, nuit)
        let opacite = UInt32(Kotlin.versInt(Double(0x99) + Double(0x80 - 0x99) * nuit))
        return opacite << 24 | (voile & 0xFFFFFF)
    }

    /// Les couleurs du nuage de Sérénité, brutes : le corps à 90/255 et le bord à 110/255 de présence.
    public var nuageCorps: UInt32 { CielContinu.nuageCorps.a(etat.hauteur) }
    public var nuageBord: UInt32 { CielContinu.nuageBord.a(etat.hauteur) }
    public var presenceNuage: Double { CielContinu.nuages(etat.hauteur) }

    // MARK: Les quatre ciels peints d'avant

    /// Dans l'ordre nuit, aube, jour, coucher : leurs arrêts, également espacés.
    public static let ciels: [[UInt32]] = [
        [0xFF0B0A1F, 0xFF1D1838, 0xFF2E2366, 0xFF4E3486],
        [0xFF2A2357, 0xFF6A4C9C, 0xFFC98AA0, 0xFFF2C6A0, 0xFFFBE3C8],
        [0xFF4F86C6, 0xFF7FAEDC, 0xFFB3D2EA, 0xFFDCE9EC, 0xFFF4E6CB],
        [0xFF0E0B1D, 0xFF241C52, 0xFF4E3486, 0xFF9A5C97, 0xFFE3957A, 0xFFF7CDA8],
    ]
    /// Leurs astres : la lune, puis les soleils de l'aube, du jour et du coucher ; places et rayons.
    static let astres: [UInt32] = [lune, 0xFFFFF1DC, 0xFFFFF8E6, 0xFFFFE6CC]
    static let places: [(Double, Double)] = [(0.72, 0.2), (0.6, 0.6), (0.3, 0.24), (0.4, 0.62)]
    static let rayons: [Double] = [0, 30, 30, 34]

    private static func echantillon(_ arrets: [UInt32], _ u: Float) -> UInt32 {
        let x = u * Float(arrets.count - 1)
        let i = min(Int(x), arrets.count - 2)
        return TeintesCiel.melange(arrets[i], arrets[i + 1], Double(x - Float(i)))
    }

    private static func argb(_ r: Double, _ g: Double, _ b: Double) -> UInt32 {
        func v(_ x: Double) -> UInt32 { UInt32(min(max(Kotlin.versInt(x), 0), 255)) }
        return 0xFF00_0000 | v(r) << 16 | v(g) << 8 | v(b)
    }

    /// Les poids des quatre ciels peints (nuit, aube, jour, coucher) pour un soleil à `e` degrés : le matin la nuit
    /// jusqu'à −12°, vers l'aube jusqu'à −3°, l'aube jusqu'à +3°, vers le jour jusqu'à +12° ; le soir l'inverse, par
    /// le coucher ; autour de midi et de minuit, les deux mêlés selon la part du `matin` (`CielContinu.partMatin`).
    public static func poidsDesCiels(_ e: Double, matin: Double) -> [Double] {
        if matin >= 1 { return poidsDesCiels(e, matin: true) }
        if matin <= 0 { return poidsDesCiels(e, matin: false) }
        let m = poidsDesCiels(e, matin: true)
        let s = poidsDesCiels(e, matin: false)
        return (0..<4).map { matin * m[$0] + (1 - matin) * s[$0] }
    }

    public static func poidsDesCiels(_ e: Double, matin: Bool) -> [Double] {
        var p = [0.0, 0, 0, 0]
        let chaud = matin ? 1 : 3
        if e <= -12 {
            p[0] = 1
        } else if e < -3 {
            let t = (e + 12) / 9
            p[0] = 1 - t
            p[chaud] = t
        } else if e <= 3 {
            p[chaud] = 1
        } else if e < 12 {
            let t = (e - 3) / 9
            p[chaud] = 1 - t
            p[2] = t
        } else {
            p[2] = 1
        }
        return p
    }
}
