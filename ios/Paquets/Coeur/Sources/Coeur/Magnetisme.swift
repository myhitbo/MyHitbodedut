import Foundation

/// La déclinaison magnétique (28/10), pour que la boussole d'iOS compte depuis le nord vrai sans
/// demander la localisation (PORTAGE.md § 2.2.5) : CoreMotion donne le cap par rapport au nord
/// magnétique ; Android lui ajoute la déclinaison du lieu des zmanim (GeomagneticField), qui peut
/// être une ville choisie sans localisation ; iOS, celle du modèle du site, porté ici à l'identique
/// en Double (web/src/js/magnetisme.js).
///
/// Le World Magnetic Model 2025 (NOAA NCEI et British Geological Survey), du domaine public :
/// coefficients de WMM2025.COF (13/11/2024), valables de 2025 à 2030, recopiés de magnetisme.js par
/// programme (MagnetismeTests les y relit). Le calcul suit le rapport technique du WMM : coordonnées
/// géodésiques vers géocentriques, fonctions de Legendre semi-normalisées de Schmidt, champ en
/// coordonnées sphériques puis tourné vers le repère géodésique. Vérifié contre les 100 valeurs de
/// WMM2025_TestValues.txt (web/test/vecteurs_wmm2025.txt), à la tolérance du site.
public enum Magnetisme {

    /// L'année de référence des coefficients.
    public static let epoque = 2025.0

    /// Le degré du développement en harmoniques sphériques.
    private static let degre = 12

    /// [n, m, g, h, dg/dt, dh/dt], en nT et nT/an. Interne : le test la compare à celle du site.
    static let coefficients: [[Double]] = [
        [1, 0, -29351.8, 0.0, 12.0, 0.0], [1, 1, -1410.8, 4545.4, 9.7, -21.5], [2, 0, -2556.6, 0.0, -11.6, 0.0],
        [2, 1, 2951.1, -3133.6, -5.2, -27.7], [2, 2, 1649.3, -815.1, -8.0, -12.1], [3, 0, 1361.0, 0.0, -1.3, 0.0],
        [3, 1, -2404.1, -56.6, -4.2, 4.0], [3, 2, 1243.8, 237.5, 0.4, -0.3], [3, 3, 453.6, -549.5, -15.6, -4.1],
        [4, 0, 895.0, 0.0, -1.6, 0.0], [4, 1, 799.5, 278.6, -2.4, -1.1], [4, 2, 55.7, -133.9, -6.0, 4.1],
        [4, 3, -281.1, 212.0, 5.6, 1.6], [4, 4, 12.1, -375.6, -7.0, -4.4], [5, 0, -233.2, 0.0, 0.6, 0.0],
        [5, 1, 368.9, 45.4, 1.4, -0.5], [5, 2, 187.2, 220.2, 0.0, 2.2], [5, 3, -138.7, -122.9, 0.6, 0.4],
        [5, 4, -142.0, 43.0, 2.2, 1.7], [5, 5, 20.9, 106.1, 0.9, 1.9], [6, 0, 64.4, 0.0, -0.2, 0.0],
        [6, 1, 63.8, -18.4, -0.4, 0.3], [6, 2, 76.9, 16.8, 0.9, -1.6], [6, 3, -115.7, 48.8, 1.2, -0.4],
        [6, 4, -40.9, -59.8, -0.9, 0.9], [6, 5, 14.9, 10.9, 0.3, 0.7], [6, 6, -60.7, 72.7, 0.9, 0.9],
        [7, 0, 79.5, 0.0, -0.0, 0.0], [7, 1, -77.0, -48.9, -0.1, 0.6], [7, 2, -8.8, -14.4, -0.1, 0.5],
        [7, 3, 59.3, -1.0, 0.5, -0.8], [7, 4, 15.8, 23.4, -0.1, 0.0], [7, 5, 2.5, -7.4, -0.8, -1.0],
        [7, 6, -11.1, -25.1, -0.8, 0.6], [7, 7, 14.2, -2.3, 0.8, -0.2], [8, 0, 23.2, 0.0, -0.1, 0.0],
        [8, 1, 10.8, 7.1, 0.2, -0.2], [8, 2, -17.5, -12.6, 0.0, 0.5], [8, 3, 2.0, 11.4, 0.5, -0.4],
        [8, 4, -21.7, -9.7, -0.1, 0.4], [8, 5, 16.9, 12.7, 0.3, -0.5], [8, 6, 15.0, 0.7, 0.2, -0.6],
        [8, 7, -16.8, -5.2, -0.0, 0.3], [8, 8, 0.9, 3.9, 0.2, 0.2], [9, 0, 4.6, 0.0, -0.0, 0.0],
        [9, 1, 7.8, -24.8, -0.1, -0.3], [9, 2, 3.0, 12.2, 0.1, 0.3], [9, 3, -0.2, 8.3, 0.3, -0.3],
        [9, 4, -2.5, -3.3, -0.3, 0.3], [9, 5, -13.1, -5.2, 0.0, 0.2], [9, 6, 2.4, 7.2, 0.3, -0.1],
        [9, 7, 8.6, -0.6, -0.1, -0.2], [9, 8, -8.7, 0.8, 0.1, 0.4], [9, 9, -12.9, 10.0, -0.1, 0.1],
        [10, 0, -1.3, 0.0, 0.1, 0.0], [10, 1, -6.4, 3.3, 0.0, 0.0], [10, 2, 0.2, 0.0, 0.1, -0.0],
        [10, 3, 2.0, 2.4, 0.1, -0.2], [10, 4, -1.0, 5.3, -0.0, 0.1], [10, 5, -0.6, -9.1, -0.3, -0.1],
        [10, 6, -0.9, 0.4, 0.0, 0.1], [10, 7, 1.5, -4.2, -0.1, 0.0], [10, 8, 0.9, -3.8, -0.1, -0.1],
        [10, 9, -2.7, 0.9, -0.0, 0.2], [10, 10, -3.9, -9.1, -0.0, -0.0], [11, 0, 2.9, 0.0, 0.0, 0.0],
        [11, 1, -1.5, 0.0, -0.0, -0.0], [11, 2, -2.5, 2.9, 0.0, 0.1], [11, 3, 2.4, -0.6, 0.0, -0.0],
        [11, 4, -0.6, 0.2, 0.0, 0.1], [11, 5, -0.1, 0.5, -0.1, -0.0], [11, 6, -0.6, -0.3, 0.0, -0.0],
        [11, 7, -0.1, -1.2, -0.0, 0.1], [11, 8, 1.1, -1.7, -0.1, -0.0], [11, 9, -1.0, -2.9, -0.1, 0.0],
        [11, 10, -0.2, -1.8, -0.1, 0.0], [11, 11, 2.6, -2.3, -0.1, 0.0], [12, 0, -2.0, 0.0, 0.0, 0.0],
        [12, 1, -0.2, -1.3, 0.0, -0.0], [12, 2, 0.3, 0.7, -0.0, 0.0], [12, 3, 1.2, 1.0, -0.0, -0.1],
        [12, 4, -1.3, -1.4, -0.0, 0.1], [12, 5, 0.6, -0.0, -0.0, -0.0], [12, 6, 0.6, 0.6, 0.1, -0.0],
        [12, 7, 0.5, -0.1, -0.0, -0.0], [12, 8, -0.1, 0.8, 0.0, 0.0], [12, 9, -0.4, 0.1, 0.0, -0.0],
        [12, 10, -0.2, -1.0, -0.1, -0.0], [12, 11, -1.3, 0.1, -0.0, 0.0], [12, 12, -0.7, 0.2, -0.1, -0.1],
    ]

    // WGS84 : demi-grand axe (km), aplatissement, excentricité au carré ; le rayon de référence du modèle (km).
    private static let demiGrandAxe = 6378.137
    private static let aplatissement = 1 / 298.257223563
    private static let excentricite2 = aplatissement * (2 - aplatissement)
    private static let rayonReference = 6371.2

    private static func rad(_ d: Double) -> Double { (d * Double.pi) / 180 }

    /// Le champ en un point : déclinaison et inclinaison en degrés ; `x`, `y`, `z` en nT (nord, est, bas).
    public struct Champ: Sendable, Equatable {
        public let declinaison: Double
        public let inclinaison: Double
        public let x: Double
        public let y: Double
        public let z: Double
    }

    /// L'année décimale d'un instant (millisecondes Unix), comptée en UTC : 2026-07-02 ≈ 2026,5.
    public static func anneeDecimale(millis: Int64) -> Double {
        let parJour = 86_400_000
        let annee = JourCivil(jourJulien: 2_440_588 + Kotlin.floorDiv(Int(millis), parJour)).annee
        guard let debut = JourCivil(annee: annee, mois: 1, jour: 1),
              let fin = JourCivil(annee: annee + 1, mois: 1, jour: 1) else { return Double(annee) }
        let t0 = (debut.jourJulien - 2_440_588) * parJour
        let t1 = (fin.jourJulien - 2_440_588) * parJour
        return Double(annee) + Double(Int(millis) - t0) / Double(t1 - t0)
    }

    /// Le champ au point donné : latitude et longitude géodésiques en degrés, altitude en km
    /// au-dessus de l'ellipsoïde, année décimale.
    public static func champ(_ latitude: Double, _ longitude: Double, _ altitudeKm: Double, _ annee: Double) -> Champ {
        let dt = annee - epoque
        let phi = rad(latitude)
        let lambda = rad(longitude)
        let sinPhi = sin(phi)
        // Math.sin(phi) ** 2 du site : pow(x, 2) rend x · x.
        let rc = demiGrandAxe / (1 - excentricite2 * (sinPhi * sinPhi)).squareRoot()
        let p = (rc + altitudeKm) * cos(phi)
        let zg = (rc * (1 - excentricite2) + altitudeKm) * sinPhi
        let r = hypot(p, zg)
        let phiC = asin(zg / r)
        let cosT = sin(phiC)
        let sinT = cos(phiC)

        // Legendre de Schmidt P[n][m](cos θ) et leur dérivée en θ.
        var pnm = [[Double]](repeating: [Double](repeating: 0, count: degre + 1), count: degre + 1)
        var dpnm = pnm
        pnm[0][0] = 1
        for n in 1...degre {
            for m in 0...n {
                if n == m {
                    let k = n == 1 ? 1 : (Double(2 * n - 1) / Double(2 * n)).squareRoot()
                    pnm[n][n] = k * sinT * pnm[n - 1][n - 1]
                    dpnm[n][n] = k * (cosT * pnm[n - 1][n - 1] + sinT * dpnm[n - 1][n - 1])
                } else {
                    let k1 = Double(2 * n - 1) / Double(n * n - m * m).squareRoot()
                    let k2 = (Double((n - 1) * (n - 1) - m * m) / Double(n * n - m * m)).squareRoot()
                    let p2 = n >= 2 ? pnm[n - 2][m] : 0
                    let d2 = n >= 2 ? dpnm[n - 2][m] : 0
                    pnm[n][m] = k1 * cosT * pnm[n - 1][m] - k2 * p2
                    dpnm[n][m] = k1 * (cosT * dpnm[n - 1][m] - sinT * pnm[n - 1][m]) - k2 * d2
                }
            }
        }

        var xc = 0.0
        var yc = 0.0
        var zc = 0.0
        for ligne in coefficients {
            let n = Int(ligne[0])
            let m = Int(ligne[1])
            let g = ligne[2] + dt * ligne[4]
            let h = ligne[3] + dt * ligne[5]
            let facteur = pow(rayonReference / r, Double(n + 2))
            let cosM = cos(Double(m) * lambda)
            let sinM = sin(Double(m) * lambda)
            xc += facteur * (g * cosM + h * sinM) * dpnm[n][m]
            yc += facteur * Double(m) * (g * sinM - h * cosM) * pnm[n][m]
            zc -= facteur * Double(n + 1) * (g * cosM + h * sinM) * pnm[n][m]
        }
        yc /= cos(phiC)

        let psi = phiC - phi
        let x = xc * cos(psi) - zc * sin(psi)
        let y = yc
        let z = xc * sin(psi) + zc * cos(psi)
        let horizontal = hypot(x, y)
        return Champ(declinaison: (atan2(y, x) * 180) / Double.pi, inclinaison: (atan2(z, horizontal) * 180) / Double.pi,
                     x: x, y: y, z: z)
    }

    /// La déclinaison en degrés (positive vers l'est), au niveau de la mer, à l'instant donné
    /// (millisecondes Unix) : le cap vrai est le cap magnétique plus la déclinaison.
    public static func declinaison(_ latitude: Double, _ longitude: Double, millis: Int64) -> Double {
        champ(latitude, longitude, 0, anneeDecimale(millis: millis)).declinaison
    }
}
