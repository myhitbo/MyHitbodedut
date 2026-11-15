import Foundation

/// La direction de Jérusalem (Har haBayit) depuis un lieu (DirectionJerusalem.kt, 28/10, boussole C) :
/// repris de la PR #29 (Geographie.swift, tâche 13), seul, pour la boussole de la tâche 8 ; 
/// le plus court chemin sur le globe (grand cercle, cap initial), ou, si on le choisit (03/11), la
/// direction sur la carte (loxodromie, cap constant) ; l'autre reste affichée. Sur une sphère : à moins
/// d'un demi-degré du calcul sur l'ellipsoïde. Le lissage du cap et le dessin de la boussole sont des
/// écrans : ils viendront avec elle (ROADMAP, tâche 25).
public enum DirectionJerusalem {

    /// Har haBayit, au Dôme : 31,7781° N, 35,2354° E.
    public static let latitude = 31.7781
    public static let longitude = 35.2354

    /// À ±4°, on est face à Jérusalem.
    public static let tolerance = 4.0

    private static let rayonKm = 6371.0

    private static func rad(_ d: Double) -> Double { d * Double.pi / 180 }
    private static func deg(_ r: Double) -> Double { r * 180 / Double.pi }

    /// Un angle ramené entre 0 et 360.
    public static func norm(_ d: Double) -> Double {
        (d.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Le cap initial du grand cercle, en degrés depuis le nord vrai.
    public static func grandCercle(_ lat: Double, _ lon: Double) -> Double {
        let f1 = rad(lat), f2 = rad(latitude), dl = rad(longitude - lon)
        let y = sin(dl) * cos(f2)
        let x = cos(f1) * sin(f2) - sin(f1) * cos(f2) * cos(dl)
        return norm(deg(atan2(y, x)))
    }

    /// Le cap constant de la loxodromie (la droite sur une carte de Mercator).
    public static func carte(_ lat: Double, _ lon: Double) -> Double {
        var dl = rad(longitude - lon)
        // Par le plus court côté du méridien de 180°.
        if abs(dl) > Double.pi { dl = dl > 0 ? dl - 2 * Double.pi : dl + 2 * Double.pi }
        let q = log(tan(Double.pi / 4 + rad(latitude) / 2) / tan(Double.pi / 4 + rad(lat) / 2))
        return norm(deg(atan2(dl, q)))
    }

    /// La distance par le grand cercle, en kilomètres.
    public static func distanceKm(_ lat: Double, _ lon: Double) -> Double {
        let f1 = rad(lat), f2 = rad(latitude)
        let c = sin(f1) * sin(f2) + cos(f1) * cos(f2) * cos(rad(longitude - lon))
        return rayonKm * acos(min(max(c, -1), 1))
    }

    /// De combien tourner, de -180 (à gauche) à +180 (à droite), pour passer du cap `cap` à `cible`.
    public static func ecart(_ cible: Double, _ cap: Double) -> Double {
        let e = norm(cible - cap)
        return e > 180 ? e - 360 : e
    }

    /// En degrés entiers, de 0 à 359 (359,6° s'écrit 0°) : `Math.round`, les demis vers le haut.
    public static func degres(_ d: Double) -> Int { Int((norm(d) + 0.5).rounded(.down)) % 360 }

    public static func face(_ ecart: Double) -> Bool { abs(ecart) <= tolerance }

    /// Le point cardinal le plus proche, de 0 (N) à 7 (NO), dans le sens des aiguilles.
    public static func point(_ d: Double) -> Int { Kotlin.arrondi(norm(d) / 45) % 8 }

    /// Celle que suit le hassid, puis l'autre : le grand cercle d'abord, ou la carte si on l'a choisie.
    public static func directions(_ lat: Double, _ lon: Double, selonCarte: Bool = false) -> (suivie: Double, autre: Double) {
        selonCarte ? (carte(lat, lon), grandCercle(lat, lon)) : (grandCercle(lat, lon), carte(lat, lon))
    }
}
