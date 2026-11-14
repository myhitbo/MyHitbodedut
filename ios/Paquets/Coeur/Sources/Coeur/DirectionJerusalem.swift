import Foundation

/// La direction de Jérusalem (Har haBayit) depuis un lieu (DirectionJerusalem.kt, 28/10, boussole C).
/// Le hassid suit la direction réelle, le plus court chemin sur le globe (grand cercle, cap
/// initial ; décision du 28/10), ou, si on le choisit (03/11), la direction sur la carte
/// (loxodromie, cap constant) ; l'autre reste affichée. De New York : environ 54° et 96°. Calcul sur
/// une sphère : à moins d'un demi-degré du calcul sur l'ellipsoïde (DirectionJerusalemTests).
///
/// Les opérations sont celles du Kotlin, dans le même ordre : `geo.json` (VecteursGeo.kt) le
/// vérifie point par point sur le globe.
public enum DirectionJerusalem {

    /// Har haBayit, au Dôme : 31,7781° N, 35,2354° E.
    public static let latitude = 31.7781
    public static let longitude = 35.2354

    /// À ±4°, on est face à Jérusalem. Un `Float`, comme `TOLERANCE = 4f` (le dessin s'en sert).
    public static let tolerance: Float = 4

    private static let rayonKm = 6371.0

    // d·π/180 et r·180/π, écrits ainsi dans DirectionJerusalem.kt (et non Math.toRadians, qui
    // multiplie par une constante et peut différer au dernier chiffre).
    private static func rad(_ d: Double) -> Double { d * Double.pi / 180 }
    private static func deg(_ r: Double) -> Double { r * 180 / Double.pi }

    /// Un angle ramené entre 0 et 360. Le `%` de Kotlin sur un Double est le reste tronqué :
    /// `truncatingRemainder`, qui garde comme lui le signe du dividende.
    public static func norm(_ d: Double) -> Double {
        (d.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Le cap initial du grand cercle, en degrés depuis le nord vrai.
    public static func grandCercle(_ lat: Double, _ lon: Double) -> Double {
        let f1 = rad(lat)
        let f2 = rad(latitude)
        let dl = rad(longitude - lon)
        return norm(deg(atan2(sin(dl) * cos(f2), cos(f1) * sin(f2) - sin(f1) * cos(f2) * cos(dl))))
    }

    /// Le cap constant de la loxodromie (la droite sur une carte de Mercator), en degrés depuis le nord vrai.
    public static func carte(_ lat: Double, _ lon: Double) -> Double {
        var dl = rad(longitude - lon)
        // Par le plus court côté du méridien de 180°.
        if abs(dl) > Double.pi { dl = dl > 0 ? dl - 2 * Double.pi : dl + 2 * Double.pi }
        let q = log(tan(Double.pi / 4 + rad(latitude) / 2) / tan(Double.pi / 4 + rad(lat) / 2))
        return norm(deg(atan2(dl, q)))
    }

    /// La distance par le grand cercle, en kilomètres.
    public static func distanceKm(_ lat: Double, _ lon: Double) -> Double {
        let f1 = rad(lat)
        let f2 = rad(latitude)
        let c = sin(f1) * sin(f2) + cos(f1) * cos(f2) * cos(rad(longitude - lon))
        return rayonKm * acos(borne(c, -1, 1))
    }

    /// De combien tourner, de -180 (à gauche) à +180 (à droite), pour passer du cap `cap` à `cible`.
    public static func ecart(_ cible: Double, _ cap: Double) -> Double {
        let e = norm(cible - cap)
        return e > 180 ? e - 360 : e
    }

    /// En degrés entiers, de 0 à 359 (359,6° s'écrit 0°) : `Math.round`, les demis vers le haut.
    public static func degres(_ d: Double) -> Int {
        Int(Kotlin.arrondiLong(norm(d))) % 360
    }

    public static func face(_ ecart: Double) -> Bool {
        abs(ecart) <= Double(tolerance)
    }

    /// Le point cardinal le plus proche, de 0 (N) à 7 (NO), dans le sens des aiguilles.
    public static func point(_ d: Double) -> Int {
        Kotlin.arrondi(norm(d) / 45) % 8
    }

    /// Celle que suit le hassid, puis l'autre, affichée pour information : le grand cercle d'abord,
    /// ou la carte de Mercator si on l'a choisie (réglage `boussole_carte`, 03/11).
    public static func directions(_ lat: Double, _ lon: Double, selonCarte: Bool = false) -> (principale: Double, autre: Double) {
        if selonCarte {
            return (principale: carte(lat, lon), autre: grandCercle(lat, lon))
        }
        return (principale: grandCercle(lat, lon), autre: carte(lat, lon))
    }

    /// `coerceIn` de Kotlin : NaN passe tel quel.
    private static func borne(_ x: Double, _ bas: Double, _ haut: Double) -> Double {
        if x < bas { return bas }
        if x > haut { return haut }
        return x
    }
}
