import Foundation

/// Le ciel continu du Jour (CielContinu.kt, 24/11). Le propriétaire, d'après un fond d'écran animé qui suit le cycle
/// du jour, la Terre de jour et de nuit (NASA SVS 5477), des boucles d'aube et de coucher illustrées et des aubes en
/// accéléré : plus quatre ciels fixes, mais un ciel qui passe sans à-coup par le noir de la nuit, le bleu du
/// crépuscule, le violet, les rouges et les jaunes du lever, l'heure dorée, le bleu du jour, l'orange et le violet du
/// soir — d'après la hauteur réelle du soleil au lieu choisi (`Soleil`), revue chaque minute.
///
/// Ici, les couleurs brutes (ARGB) et les dosages, en fonction de la hauteur du soleil (degrés) et du moment (matin
/// ou soir) ; `TeintesCiel` les adapte au thème (lisibilité), la vue du Jour les dessine. Tout est pur et interpolé
/// en continu entre des clés : CielContinuTests vérifie qu'aucune minute ne saute. Les mêmes clés qu'Android et que
/// le site (ciel.js).
public enum CielContinu {

    /// Une clé : une hauteur du soleil et les trois couleurs du ciel (haut, milieu, horizon).
    public struct Cle: Sendable {
        public let hauteur: Double
        public let haut: UInt32
        public let milieu: UInt32
        public let horizon: UInt32

        init(_ hauteur: Double, _ haut: UInt32, _ milieu: UInt32, _ horizon: UInt32) {
            self.hauteur = hauteur
            self.haut = haut
            self.milieu = milieu
            self.horizon = horizon
        }
    }

    /// Le matin : nuit noire, bleu du crépuscule, heure bleue, rouges de l'aube, jaunes, heure dorée, bleu du jour.
    public static let matin: [Cle] = [
        Cle(-18, 0xFF0A0E24, 0xFF111839, 0xFF1B2550),
        Cle(-12, 0xFF121C44, 0xFF22336C, 0xFF3A4E8E),
        Cle(-6, 0xFF222E69, 0xFF56579A, 0xFFB07898),
        Cle(-2, 0xFF36408A, 0xFFA86A92, 0xFFF08870),
        Cle(0, 0xFF4B5DA6, 0xFFE2958A, 0xFFFFAE76),
        Cle(3, 0xFF5A80C4, 0xFFEEC29C, 0xFFFFDDA0),
        Cle(6, 0xFF5994D6, 0xFFB9D6EC, 0xFFFBE5B6),
        Cle(12, 0xFF5AA5E6, 0xFFA4D5F4, 0xFFE2F3FB),
        Cle(40, 0xFF4E9BE2, 0xFF96CDF2, 0xFFDDF1FB),
    ]

    /// Le soir : bleu du jour, heure dorée, orange, coucher, violet du crépuscule, bleu, nuit noire.
    public static let soir: [Cle] = [
        Cle(-18, 0xFF0A0E22, 0xFF101733, 0xFF18224A),
        Cle(-12, 0xFF131B46, 0xFF23336C, 0xFF3B4D8C),
        Cle(-6, 0xFF2C2A6C, 0xFF5B4891, 0xFFA2698C),
        Cle(-3, 0xFF463D8A, 0xFF985C9C, 0xFFDE7D78),
        Cle(0, 0xFF675FA6, 0xFFE6826E, 0xFFFF8A50),
        Cle(2, 0xFF6B7DC0, 0xFFF0A472, 0xFFFF9E5A),
        Cle(6, 0xFF6395D2, 0xFFE4D2B0, 0xFFFFD79E),
        Cle(12, 0xFF5AA5E6, 0xFFA4D5F4, 0xFFE2F3FB),
        Cle(40, 0xFF4E9BE2, 0xFF96CDF2, 0xFFDDF1FB),
    ]

    /// Une couleur qui suit la hauteur du soleil : des paires (hauteur, couleur), hauteurs croissantes.
    public struct Suite: Sendable {
        private let hauteurs: [Double]
        private let couleurs: [UInt32]

        init(_ paires: [(Double, UInt32)]) {
            hauteurs = paires.map(\.0)
            couleurs = paires.map(\.1)
        }

        public func a(_ e: Double) -> UInt32 {
            if e <= hauteurs[0] { return couleurs[0] }
            if e >= hauteurs[hauteurs.count - 1] { return couleurs[couleurs.count - 1] }
            guard let i = hauteurs.firstIndex(where: { $0 > e }) else { return couleurs[couleurs.count - 1] }
            let t = (e - hauteurs[i - 1]) / (hauteurs[i] - hauteurs[i - 1])
            return TeintesCiel.melange(couleurs[i - 1], couleurs[i], t)
        }
    }

    /// Le disque du soleil : rouge-orangé à l'horizon, doré bas, jaune pâle haut.
    public static let astre = Suite([(0, 0xFFFF8C4E), (3, 0xFFFFB566), (8, 0xFFFFDB8A), (20, 0xFFFFF0B8),
                                     (40, 0xFFFFF6CE)])

    /// Sa lueur et sa couronne.
    public static let lueur = Suite([(0, 0xFFFF9A5C), (3, 0xFFFFBE7E), (8, 0xFFFFDFA0), (20, 0xFFFFF6C8)])

    /// La lune, et sa lueur.
    public static let lune: UInt32 = 0xFFF6F0D6

    /// Les nuages prennent la lumière du moment : leur corps et leur bord éclairé (le dessous, tourné vers le soleil
    /// bas) — gris bleu pâle au crépuscule, roses et orangés à l'aube et au coucher, dorés à l'heure dorée, blancs le
    /// jour.
    public static let nuageCorps = Suite([(-12, 0xFF5E6A8E), (-6, 0xFF6E6E9E), (0, 0xFFE8A9A0), (4, 0xFFF6D2B8),
                                          (10, 0xFFFFFFFF)])
    public static let nuageBord = Suite([(-12, 0xFF7A86A8), (-6, 0xFFC88AA8), (0, 0xFFFFB070), (4, 0xFFFFD27A),
                                         (10, 0xFFFFF4DC)])

    /// Les trois couleurs brutes du ciel pour `hauteur` : celles du matin et du soir mêlées selon la part du `matin`
    /// (1 le matin, 0 le soir, entre les deux autour de midi et de minuit, `partMatin`).
    public static func brutes(_ hauteur: Double, matin part: Double) -> [UInt32] {
        if part >= 1 { return selon(matin, hauteur) }
        if part <= 0 { return selon(soir, hauteur) }
        let m = selon(matin, hauteur)
        let s = selon(soir, hauteur)
        return (0..<3).map { TeintesCiel.melange(s[$0], m[$0], part) }
    }

    /// Le `matin` ou le soir, sans passage.
    public static func brutes(_ hauteur: Double, matin: Bool) -> [UInt32] {
        brutes(hauteur, matin: matin ? 1.0 : 0.0)
    }

    private static func selon(_ cles: [Cle], _ hauteur: Double) -> [UInt32] {
        if hauteur <= cles[0].hauteur { return [cles[0].haut, cles[0].milieu, cles[0].horizon] }
        let fin = cles[cles.count - 1]
        if hauteur >= fin.hauteur { return [fin.haut, fin.milieu, fin.horizon] }
        guard let i = cles.firstIndex(where: { $0.hauteur > hauteur }) else { return [fin.haut, fin.milieu, fin.horizon] }
        let a = cles[i - 1]
        let b = cles[i]
        let t = (hauteur - a.hauteur) / (b.hauteur - a.hauteur)
        return [TeintesCiel.melange(a.haut, b.haut, t), TeintesCiel.melange(a.milieu, b.milieu, t),
                TeintesCiel.melange(a.horizon, b.horizon, t)]
    }

    /// La part du matin dans les couleurs, d'après l'angle horaire du soleil (degrés, négatif le matin) : 1 le matin,
    /// 0 l'après-midi et le soir, et un passage d'une heure environ de part et d'autre de midi et de minuit (le sinus
    /// de l'angle horaire de −0,25 à 0,25, soit 14,5° du méridien). Là où le soleil reste bas à midi (le nord en
    /// hiver) ou haut à minuit (en été), les clés du matin et du soir ne se rejoignent pas : sans ce passage, le ciel
    /// sautait d'un coup à midi ou à minuit. Ailleurs, rien ne change.
    public static func partMatin(_ angleHoraire: Double) -> Double {
        rampe(sin(angleHoraire * .pi / 180), de: passage, a: -passage)
    }
    public static let passage = 0.25

    /// L'astre s'efface là où son arc recommence, faute de quoi il sauterait d'un bord de l'écran à l'autre : le
    /// soleil autour de minuit (il ne s'y montre qu'au jour polaire), la lune autour de midi (à la nuit polaire). Une
    /// heure de part et d'autre (15° d'angle horaire) ; ailleurs, l'astre y est sous l'horizon et rien ne change.
    public static func fonduArc(_ angleHoraire: Double, soleil: Bool) -> Double {
        soleil ? rampe(abs(angleHoraire), de: 180, a: 165) : rampe(abs(angleHoraire), de: 0, a: 15)
    }

    /// Une rampe douce : 0 à `de`, 1 à `a` (de > a permis : la rampe descend).
    public static func rampe(_ x: Double, de: Double, a: Double) -> Double {
        let t = min(max((x - de) / (a - de), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Thème sombre : la luminance de chaque arrêt, en part de la plus haute permise.
    public static func partsSombre(_ e: Double) -> [Float] {
        let nuit: [Float] = [0.25, 0.40, 0.55]
        let crepuscule: [Float] = [0.36, 0.48, 0.56]
        let jour: [Float] = [0.38, 0.44, 0.52]
        let (a, b, t): ([Float], [Float], Double)
        if e <= -12 {
            (a, b, t) = (nuit, nuit, 0)
        } else if e < -3 {
            (a, b, t) = (nuit, crepuscule, (e + 12) / 9)
        } else if e < 6 {
            (a, b, t) = (crepuscule, crepuscule, 0)
        } else if e < 12 {
            (a, b, t) = (crepuscule, jour, (e - 6) / 6)
        } else {
            (a, b, t) = (jour, jour, 0)
        }
        // Comme Kotlin : (a + (b − a)·t) en double, puis en simple précision.
        return (0..<3).map { Float(Double(a[$0]) + Double(b[$0] - a[$0]) * t) }
    }

    /// Le poids des couleurs chaudes de l'aube et du coucher, de 0 (nuit, jour) à 1 (−6° à +10°, jusqu'au bout de
    /// l'heure dorée), nul à +16° : en thème sombre, ce qu'elles prennent du haut du ciel (`TeintesCiel`).
    public static func chaleur(_ e: Double) -> Double {
        rampe(e, de: -12, a: -6) * (1 - rampe(e, de: 10, a: 16))
    }

    /// Les étoiles s'allument avec la profondeur du crépuscule : aucune à −4°, toutes à −14°.
    public static func etoiles(_ e: Double) -> Double { rampe(e, de: -4, a: -14) }

    /// Les nuages : presque rien en pleine nuit, visibles dès le crépuscule.
    public static func nuages(_ e: Double) -> Double { 0.15 + 0.85 * rampe(e, de: -14, a: -6) }

    /// Les rayons doux autour du soleil bas : à l'heure dorée seulement.
    public static func rayons(_ e: Double) -> Double { rampe(e, de: -2, a: 2.5) * (1 - rampe(e, de: 6, a: 10)) }

    /// Le disque du soleil paraît en se levant et s'efface en se couchant (−3° à +1°, une quinzaine de minutes).
    public static func soleilVisible(_ e: Double) -> Double { rampe(e, de: -3, a: 1) }

    /// Au-dessus de −3°, c'est le soleil qui suit l'arc ; en dessous, la lune, qui paraît jusqu'à −7°.
    public static func soleilPlutotQueLune(_ e: Double) -> Bool { e >= -3 }
    public static func luneVisible(_ e: Double) -> Double { rampe(e, de: -3, a: -7) }

    /// La lueur large demeure un peu sous l'horizon, jusqu'à ce que la lune prenne le relais (de 0° à −3°).
    public static func lueurVisible(_ e: Double) -> Double { rampe(e, de: -3, a: 0) }

    /// La hauteur dessinée, de 0 (l'horizon) à 1 (60° et plus) : le sinus de la hauteur.
    public static func elevationDessinee(_ e: Double) -> Double {
        min(max(sin(e * .pi / 180) / sin(.pi / 3), 0), 1)
    }

    /// Le rayon du soleil, en points : un peu plus grand près de l'horizon.
    public static func rayonSoleil(_ e: Double) -> Float { Float(14 + 3 * (1 - rampe(e, de: 0, a: 15))) }
    public static let rayonLune: Float = 12

    /// La lune d'après le jour du mois hébreu (1 à 30) : son âge depuis le molad, la part éclairée (0 nouvelle, 1
    /// pleine) et si elle croît. Un fin croissant les premiers jours, la moitié vers le 7 ou le 8, pleine le 14 ou le
    /// 15, puis elle décroît.
    public struct Lune: Sendable, Equatable {
        public let age: Double
        public let eclairee: Double
        public let croissante: Bool
    }

    public static let moisLunaire = 29.530589

    public static func lune(_ jourDuMois: Int) -> Lune {
        let age = Double(min(max(jourDuMois, 1), 30)) - 0.5
        let angle = 2 * .pi * age / moisLunaire
        return Lune(age: age, eclairee: (1 - cos(angle)) / 2, croissante: age < moisLunaire / 2)
    }

    /// Une couleur en #RRGGBB, pour les messages des tests.
    public static func hexa(_ c: UInt32) -> String {
        let s = String(c & 0xFFFFFF, radix: 16, uppercase: true)
        return "#" + String(repeating: "0", count: max(0, 6 - s.count)) + s
    }

    /// L'arrondi utilisé pour revoir le ciel au plus une fois par quart de degré.
    public static func arrondi(_ e: Double) -> Double { Double(Kotlin.arrondi(e * 4)) / 4 }
}

/// Où en est le ciel : la hauteur du soleil (degrés), son angle horaire (degrés, négatif le matin), la part du jour
/// écoulée (0 au lever, 1 au coucher) et celle de la nuit (0 au coucher, 1 au lever), le jour du mois hébreu (la
/// lune).
public struct EtatCiel: Sendable, Hashable {
    public let hauteur: Double
    public let angleHoraire: Double
    public let progresJour: Double
    public let progresNuit: Double
    public let jourHebreu: Int

    public init(hauteur: Double, angleHoraire: Double, progresJour: Double, progresNuit: Double, jourHebreu: Int) {
        self.hauteur = hauteur
        self.angleHoraire = angleHoraire
        self.progresJour = progresJour
        self.progresNuit = progresNuit
        self.jourHebreu = jourHebreu
    }

    /// La part du matin dans les couleurs (`CielContinu.partMatin`).
    public var matin: Double { CielContinu.partMatin(angleHoraire) }

    /// L'astre du moment (le soleil jusqu'à 3° sous l'horizon, puis la lune) et son opacité.
    public var estSoleil: Bool { CielContinu.soleilPlutotQueLune(hauteur) }
    public var astreVisible: Double {
        (estSoleil ? CielContinu.soleilVisible(hauteur) : CielContinu.luneVisible(hauteur))
            * CielContinu.fonduArc(angleHoraire, soleil: estSoleil)
    }

    /// La lueur large du soleil demeure un peu sous l'horizon (`CielContinu.lueurVisible`).
    public var lueurVisible: Double {
        estSoleil
            ? max(CielContinu.soleilVisible(hauteur), CielContinu.lueurVisible(hauteur))
                * CielContinu.fonduArc(angleHoraire, soleil: true)
            : astreVisible
    }

    public static func de(_ position: Soleil.Position, jourHebreu: Int) -> EtatCiel {
        EtatCiel(hauteur: position.hauteur, angleHoraire: position.angleHoraire, progresJour: position.progresJour,
                 progresNuit: position.progresNuit, jourHebreu: jourHebreu)
    }

    /// Le repos d'avant tout calcul : le soleil haut du matin, la pleine lune.
    public static let parDefaut = EtatCiel(hauteur: 30, angleHoraire: -45, progresJour: 0.3, progresNuit: 0.5,
                                           jourHebreu: 15)
}
