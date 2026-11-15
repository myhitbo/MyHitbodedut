import Foundation

/// La direction de Jérusalem (Har haBayit) depuis un lieu (DirectionJerusalem.kt, 28/10, boussole C) :
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

/// Israël ou diaspora d'après la position (TerritoireIsrael.kt, 16/10) : l'État d'Israël avec Jérusalem,
/// la Judée-Samarie et le Golan, de la frontière libanaise à Eilat, du Jourdain et de la Arava à la mer.
/// Contour simplifié (précision de 2 à 3 km) : le réglage « Israël / diaspora » reste là pour les
/// frontières. La question halakhique des limites de la Terre d'Israël n'est pas tranchée ici.
public enum TerritoireIsrael {

    /// (latitude, longitude), dans l'ordre : la côte vers le nord, le Liban, le Golan, le Jourdain, la Arava, l'Égypte.
    private static let contour: [(Double, Double)] = [
        (31.23, 34.21), (31.36, 34.24), (31.55, 34.40), (31.72, 34.50),
        (31.95, 34.66), (32.10, 34.72), (32.33, 34.80), (32.55, 34.86),
        (32.75, 34.92), (32.84, 34.93), (32.93, 35.03), (33.09, 35.08),
        // La frontière libanaise, de Roch Hanikra à Metoula, puis l'Hermon.
        (33.10, 35.20), (33.09, 35.33), (33.08, 35.45), (33.11, 35.52),
        (33.20, 35.55), (33.28, 35.57), (33.31, 35.63), (33.33, 35.79),
        // Le Golan, à l'est, jusqu'à 'Hamat Gader ; la ligne passe entre Ein Zivan et Kuneitra.
        (33.22, 35.82), (33.13, 35.815), (33.05, 35.86), (32.93, 35.87), (32.78, 35.80),
        (32.70, 35.72), (32.66, 35.62),
        // Le Jourdain et la mer Morte.
        (32.45, 35.57), (32.20, 35.56), (31.95, 35.55), (31.76, 35.56),
        (31.45, 35.50), (31.15, 35.45),
        // La Arava, jusqu'à Eilat et Taba.
        (30.85, 35.36), (30.50, 35.22), (30.15, 35.14), (29.90, 35.09), (29.70, 35.03),
        (29.55, 34.98), (29.49, 34.90),
        // La frontière égyptienne, jusqu'à Kerem Chalom et Rafia'h.
        (29.80, 34.76), (30.20, 34.60), (30.60, 34.50), (30.95, 34.37),
        (31.22, 34.26),
    ]

    /// Le point est-il dans le contour (tracé de rayon) ?
    public static func contient(latitude: Double, longitude: Double) -> Bool {
        var dedans = false
        var j = contour.count - 1
        for i in contour.indices {
            let (yi, xi) = contour[i]
            let (yj, xj) = contour[j]
            if (yi > latitude) != (yj > latitude) && longitude < (xj - xi) * (latitude - yi) / (yj - yi) + xi { dedans.toggle() }
            j = i
        }
        return dedans
    }
}

/// Les villes proposées pour les zmanim (Villes.kt) : la distance, et la plus proche d'une position.
extension Villes {

    /// La distance en kilomètres entre deux points (haversine, rayon moyen de la Terre).
    public static func distanceKm(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let r = 6371.0, k = Double.pi / 180
        let dLat = (lat2 - lat1) * k, dLon = (lon2 - lon1) * k
        let s1 = sin(dLat / 2), s2 = sin(dLon / 2)
        let a = s1 * s1 + cos(lat1 * k) * cos(lat2 * k) * s2 * s2
        return 2 * r * asin(min(max(a, 0), 1).squareRoot())
    }

    /// La ville la plus proche d'une position, à moins de `maxKm` (16/10) : elle nomme la position
    /// (« près de Jérusalem »), donne son altitude et dit Israël ou diaspora. La première à égalité.
    public static func plusProche(_ villes: [Ville], _ lat: Double, _ lon: Double, maxKm: Double = 60) -> Ville? {
        var meilleure: (Ville, Double)?
        for v in villes {
            let d = distanceKm(lat, lon, v.latitude, v.longitude)
            if meilleure == nil || d < meilleure!.1 { meilleure = (v, d) }
        }
        guard let m = meilleure, m.1 <= maxKm else { return nil }
        return m.0
    }
}
