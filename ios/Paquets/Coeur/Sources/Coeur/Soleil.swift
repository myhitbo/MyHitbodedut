import Foundation

/// La hauteur du soleil, pour le ciel continu du Jour (Soleil.kt, 24/11 ; `CielContinu`). Les formules de la NOAA
/// (celles de NOAACalculator de KosherJava, que SoleilTests prend pour témoin par KosherSwift) : déclinaison et
/// équation du temps d'après le jour julien, angle horaire d'après la longitude.
///
/// Pur, en degrés, sans réfraction ; le même calcul qu'Android et que le site (ciel.js, soleil).
public enum Soleil {

    /// Le soleil à un instant : sa hauteur au-dessus de l'horizon, son angle horaire (négatif le matin, positif
    /// l'après-midi, de −180 à 180) et l'angle horaire de son lever (0 : nuit polaire, 180 : jour polaire).
    public struct Position: Sendable, Equatable {
        public let hauteur: Double
        public let angleHoraire: Double
        public let angleLever: Double

        public init(hauteur: Double, angleHoraire: Double, angleLever: Double) {
            self.hauteur = hauteur
            self.angleHoraire = angleHoraire
            self.angleLever = angleLever
        }

        /// Le soleil est levé (angle horaire dans l'arc du jour).
        public var jour: Bool { abs(angleHoraire) <= angleLever }

        /// Le matin : avant le passage au méridien.
        public var matin: Bool { angleHoraire < 0 }

        /// La part du jour écoulée, de 0 au lever à 1 au coucher ; hors du jour, la plus proche borne.
        public var progresJour: Double {
            angleLever <= 0 ? 0.5 : min(max((angleHoraire + angleLever) / (2 * angleLever), 0), 1)
        }

        /// La part de la nuit écoulée, de 0 au coucher à 1 au lever ; de jour, la plus proche borne (1 le matin, 0
        /// l'après-midi : la nuit tout juste finie, ou sur le point de commencer).
        public var progresNuit: Double {
            let nuit = 360 - 2 * angleLever
            if nuit <= 0 { return 0.5 }
            if jour { return matin ? 1 : 0 }
            let depuis = ((angleHoraire - angleLever).truncatingRemainder(dividingBy: 360) + 360)
                .truncatingRemainder(dividingBy: 360)
            return min(max(depuis / nuit, 0), 1)
        }
    }

    private static func rad(_ d: Double) -> Double { d * .pi / 180 }
    private static func deg(_ r: Double) -> Double { r * 180 / .pi }

    /// Le soleil à l'instant `millis` (UTC), pour `latitude` et `longitude` (est positive), en degrés.
    public static func position(millis: Int64, latitude: Double, longitude: Double) -> Position {
        let jd = Double(millis) / 86_400_000 + 2_440_587.5
        let t = (jd - 2_451_545) / 36_525
        let l0 = ((280.46646 + t * (36_000.76983 + 0.0003032 * t)).truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        let m = 357.52911 + t * (35_999.05029 - 0.0001537 * t)
        let e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        let c = sin(rad(m)) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(rad(2 * m)) * (0.019993 - 0.000101 * t) + sin(rad(3 * m)) * 0.000289
        let omega = 125.04 - 1934.136 * t
        let lambda = l0 + c - 0.00569 - 0.00478 * sin(rad(omega))
        let eps0 = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        let eps = eps0 + 0.00256 * cos(rad(omega))
        let declinaison = deg(asin(sin(rad(eps)) * sin(rad(lambda))))
        let y = tan(rad(eps / 2)) * tan(rad(eps / 2))
        let equation = 4 * deg(y * sin(2 * rad(l0)) - 2 * e * sin(rad(m))
            + 4 * e * y * sin(rad(m)) * cos(2 * rad(l0))
            - 0.5 * y * y * sin(4 * rad(l0)) - 1.25 * e * e * sin(2 * rad(m)))
        let minutes = Double((millis % 86_400_000 + 86_400_000) % 86_400_000) / 60_000
        let solaire = minutes + equation + 4 * longitude
        var h = solaire / 4 - 180
        h = ((h + 180).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) - 180
        let phi = rad(latitude)
        let delta = rad(declinaison)
        let cosZenith = min(max(sin(phi) * sin(delta) + cos(phi) * cos(delta) * cos(rad(h)), -1), 1)
        let hauteur = 90 - deg(acos(cosZenith))
        // Le lever : le centre du soleil à 0,833° sous l'horizon (réfraction et demi-diamètre).
        let cosLever = (sin(rad(-0.833)) - sin(phi) * sin(delta)) / (cos(phi) * cos(delta))
        let lever: Double
        if cosLever >= 1 {
            lever = 0
        } else if cosLever <= -1 {
            lever = 180
        } else if cosLever.isNaN {
            // Aux pôles mêmes, cos(φ) est nul : le signe de la déclinaison dit le jour ou la nuit polaire.
            lever = (sin(phi) * sin(delta)) > 0 ? 180 : 0
        } else {
            lever = deg(acos(cosLever))
        }
        return Position(hauteur: hauteur, angleHoraire: h, angleLever: lever)
    }

    /// Sans lieu : un soleil moyen d'après la seule heure du téléphone (`heure` décimale, 0 à 24). Levé à 6 h 30,
    /// couché à 18 h 30, 50° à son plus haut (12 h 30) et −50° à son plus bas : il passe −19° à 5 h et à 20 h,
    /// +19° à 8 h et à 17 h, les heures de l'aube et du coucher d'avant (`CielDuJour.parHeure`).
    public static func parHeure(_ heure: Double) -> Position {
        let brut = (heure - 12.5) * 15
        let h = ((brut + 180).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) - 180
        return Position(hauteur: 50 * sin(.pi * (heure - 6.5) / 12), angleHoraire: h, angleLever: 90)
    }
}
