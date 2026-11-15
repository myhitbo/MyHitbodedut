import Foundation

/// La mesure de la danse du bravo (DanseMesure.kt) : où en est le danseur à l'instant t d'une mesure de
/// deux temps (t de 0 à 1).
///
/// Premier temps sur la pose A (jambe droite levée), second sur la pose B (jambe gauche). Chaque temps
/// est un saut : il décolle, monte, retombe, et plie les genoux en touchant le sol, moment où la pose
/// change. Le calcul est en simple précision, comme le `Float` de Kotlin ; seuls les sinus passent par
/// la double précision. Jugée par `Tests/Vecteurs/danse_mesure.json` (tools/vecteurs_ios/VecteursDanseMesure.kt).
public enum DanseMesure {

    /// Un temps. 480 ms : un peu plus de deux pas par seconde, un niggoun joyeux.
    public static let tempsMs: Int64 = 480

    /// La part du temps où les deux poses se relaient, à la réception (0,1f de Kotlin).
    private static let partRelais = Float(bitPattern: 0x3DCC_CCCD)

    /// La part du temps où les genoux plient après la réception (0,14f de Kotlin).
    private static let partFlexion = Float(bitPattern: 0x3E0F_5C29)

    public struct Pas: Equatable, Sendable {
        /// 0 au sol, 1 en haut du saut.
        public let hauteur: Float
        /// 1 à la réception, 0 jambes tendues.
        public let flexion: Float
        /// -1 penché d'un côté, 1 de l'autre.
        public let balance: Float
        /// Visibilité de la pose B ; celle de la pose A est son complément.
        public let poseB: Float

        public init(hauteur: Float, flexion: Float, balance: Float, poseB: Float) {
            self.hauteur = hauteur
            self.flexion = flexion
            self.balance = balance
            self.poseB = poseB
        }
    }

    public static func pas(_ t: Float) -> Pas {
        // `floor` de Kotlin sur un Float : l'arrondi vers le bas, exact en simple précision.
        let mesure = t - t.rounded(.down)
        let temps = mesure * 2
        let second = temps >= 1
        let p = temps - temps.rounded(.down)
        // `coerceAtMost(1f)` et `coerceAtLeast(0f)` laissent passer un NaN, comme ces comparaisons.
        let quotient = p / partRelais
        let relais: Float = quotient > 1 ? 1 : quotient
        let saut = Float(sin(Double.pi * Double(p)))
        let genoux: Float = 1 - p / partFlexion
        return Pas(
            hauteur: saut < 0 ? 0 : saut,
            flexion: genoux < 0 ? 0 : genoux,
            balance: Float(sin(2 * Double.pi * Double(mesure))),
            poseB: second ? relais : 1 - relais
        )
    }
}
