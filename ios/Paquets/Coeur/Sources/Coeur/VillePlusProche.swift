import Foundation

/// La ville la plus proche d'une position (Villes.kt, 16/10) : elle nomme la position (« près de
/// Jérusalem »), donne son altitude et dit Israël ou diaspora, que le seul fuseau devinait mal. La
/// lecture de `villes.json` est dans Contenus.swift ; `geo.json` (VecteursGeo.kt) vérifie le choix
/// sur une grille du globe et autour de chaque ville.
extension Villes {

    /// La distance en kilomètres entre deux points (haversine, rayon moyen de la Terre).
    public static func distanceKm(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let r = 6371.0
        let dLat = radians(lat2 - lat1)
        let dLon = radians(lon2 - lon1)
        let sinLat = sin(dLat / 2)
        let sinLon = sin(dLon / 2)
        // Dans l'ordre du Kotlin : sin² + (cos · cos) · sin², chaque carré calculé à part.
        let a = sinLat * sinLat + cos(radians(lat1)) * cos(radians(lat2)) * (sinLon * sinLon)
        return 2 * r * asin(borne(a, 0, 1).squareRoot())
    }

    /// La ville de la liste la plus proche d'une position, à moins de `maxKm` (16/10). À égalité,
    /// la première de la liste, comme `minByOrNull`.
    public static func plusProche(_ villes: [Ville], _ lat: Double, _ lon: Double, maxKm: Double = 60) -> Ville? {
        var meilleure: Ville?
        var plusCourte = 0.0
        for ville in villes {
            let d = distanceKm(lat, lon, ville.latitude, ville.longitude)
            if meilleure == nil || plusCourte > d {
                meilleure = ville
                plusCourte = d
            }
        }
        guard let trouvee = meilleure, distanceKm(lat, lon, trouvee.latitude, trouvee.longitude) <= maxKm else { return nil }
        return trouvee
    }

    /// `Math.toRadians` de Java (depuis Java 9) : un produit par π/180.
    private static func radians(_ d: Double) -> Double { d * 0.017453292519943295 }

    /// `coerceIn` de Kotlin : NaN passe tel quel.
    private static func borne(_ x: Double, _ bas: Double, _ haut: Double) -> Double {
        if x < bas { return bas }
        if x > haut { return haut }
        return x
    }
}
