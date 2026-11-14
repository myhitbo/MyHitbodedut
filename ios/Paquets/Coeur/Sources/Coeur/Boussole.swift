import Foundation

/// Les deux règles pures de la boussole (BoussoleActivity.kt, compagnon) : le cap de la direction où
/// l'on fait face, d'après la matrice de rotation du téléphone, et le filtre doux du cap affiché. Le
/// reste de BoussoleActivity est l'écran ; le dessin (BoussoleDessin.kt) viendra avec lui.
/// `boussole.json` (VecteursBoussole.kt) vérifie les deux sur un balayage d'angles.
public enum Boussole {

    /// Le cap (degrés, nord magnétique, sens horaire) de la direction où l'on fait face, pour une
    /// matrice de rotation en coordonnées d'écran (neuf valeurs, ligne par ligne, Est-Nord-Haut).
    /// Le seul haut de l'écran ne suffit pas : téléphone droit, il pointe le ciel et le cap
    /// s'affole (bug du 02/11). On somme donc le haut de l'écran et le dos du téléphone (−Z) : à
    /// plat, le premier donne le cap ; droit, le second ; entre les deux, ils pointent du même côté.
    /// Les différences se font en simple précision, comme sur la `FloatArray` d'Android.
    public static func capDevant(_ r: [Float]) -> Double {
        let est = r[1] - r[2]
        let nord = r[4] - r[5]
        return DirectionJerusalem.norm(atan2(Double(est), Double(nord)) * radianEnDegres)
    }

    /// Un filtre doux sur le cercle : un cinquième du chemin à chaque mesure, par le plus court côté.
    public static func lisser(_ avant: Double?, _ mesure: Double) -> Double {
        guard let avant else { return mesure }
        return DirectionJerusalem.norm(avant + DirectionJerusalem.ecart(mesure, avant) * 0.2)
    }

    /// `Math.toDegrees` de Java (depuis Java 9) : un produit par 180/π, et non r · 180 / π.
    private static let radianEnDegres = 57.29577951308232
}
