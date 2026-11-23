import Foundation

// La matrice de rotation de la boussole, d'après la gravité et le champ magnétique (BoussoleActivity.kt,
// onSensorChanged, branche TYPE_ACCELEROMETER + TYPE_MAGNETIC_FIELD) : `SensorManager.getRotationMatrix` et
// `SensorManager.remapCoordinateSystem` d'Android, recopiés de leur source (AOSP, SensorManager.java), en
// simple précision comme la `FloatArray` d'Android. Sur iOS, CoreMotion donne la gravité et le champ
// magnétique calibré dans les axes du téléphone, les mêmes qu'Android (x vers la droite de l'écran, y vers son
// haut, z hors de l'écran) : la matrice se construit donc comme sur Android, sans dépendre de la convention de
// `CMAttitude.rotationMatrix`, et `Boussole.capDevant` la lit telle quelle.

extension Boussole {

    /// `SensorManager.GRAVITY_EARTH`, en m/s².
    public static let graviteTerrestre: Float = 9.80665

    /// `SensorManager.getRotationMatrix(R, null, gravity, geomagnetic)` : la matrice Est-Nord-Haut ← téléphone,
    /// ligne par ligne. `gravite` est ce que lit l'accéléromètre d'Android au repos (le haut, environ 9,81 m/s²
    /// sur z téléphone à plat, écran vers le ciel) ; `champ`, le champ magnétique (µT), tous deux dans les axes du
    /// téléphone. nil en chute libre (moins d'un dixième de g) ou près du pôle magnétique (champ presque
    /// vertical), comme le `false` d'Android.
    public static func matriceRotation(gravite: [Float], champ: [Float]) -> [Float]? {
        guard gravite.count == 3, champ.count == 3 else { return nil }
        var ax = gravite[0], ay = gravite[1], az = gravite[2]
        let normeCarreeA = ax * ax + ay * ay + az * az
        let g: Float = 9.81
        let chuteLibre: Float = 0.01 * g * g
        if normeCarreeA < chuteLibre { return nil }
        let ex = champ[0], ey = champ[1], ez = champ[2]
        var hx = ey * az - ez * ay
        var hy = ez * ax - ex * az
        var hz = ex * ay - ey * ax
        let normeH = (hx * hx + hy * hy + hz * hz).squareRoot()
        if normeH < 0.1 { return nil }
        let invH: Float = 1 / normeH
        hx *= invH
        hy *= invH
        hz *= invH
        let invA: Float = 1 / (ax * ax + ay * ay + az * az).squareRoot()
        ax *= invA
        ay *= invA
        az *= invA
        let mx = ay * hz - az * hy
        let my = az * hx - ax * hz
        let mz = ax * hy - ay * hx
        return [hx, hy, hz, mx, my, mz, ax, ay, az]
    }

    /// La matrice depuis CoreMotion (`CMDeviceMotion.gravity`, en g, vers le sol ; `magneticField.field`, en µT,
    /// déjà débarrassé du biais de l'appareil) : la gravité de CoreMotion pointe vers le bas, l'accéléromètre
    /// d'Android vers le haut, d'où le signe ; l'unité passe de g en m/s².
    public static func matriceCoreMotion(gravite: [Double], champ: [Double]) -> [Float]? {
        guard gravite.count == 3, champ.count == 3 else { return nil }
        let haut = gravite.map { Float(-$0) * graviteTerrestre }
        return matriceRotation(gravite: haut, champ: champ.map { Float($0) })
    }

    /// Le haut de l'écran, quelle que soit la rotation de l'affichage (BoussoleActivity.onSensorChanged) :
    /// `remapCoordinateSystem` avec les axes qu'Android choisit pour chaque rotation de l'écran, en quarts de tour
    /// dans le sens inverse des aiguilles depuis le portrait (`Surface.ROTATION_0` à `ROTATION_270`).
    /// - 1 (ROTATION_90, l'écran en paysage, le haut du téléphone à gauche) : AXIS_Y, AXIS_MINUS_X ;
    /// - 2 (ROTATION_180) : AXIS_MINUS_X, AXIS_MINUS_Y ;
    /// - 3 (ROTATION_270, le haut du téléphone à droite) : AXIS_MINUS_Y, AXIS_X ;
    /// - sinon : AXIS_X, AXIS_Y, la matrice telle quelle.
    public static func remapper(_ r: [Float], rotation: Int) -> [Float] {
        guard r.count == 9 else { return r }
        // Les colonnes de la matrice sont les axes du téléphone dans le repère Est-Nord-Haut. Android envoie
        // l'axe x du téléphone sur l'axe nommé en premier, son axe y sur le second : x et y de l'écran sont donc
        // ces colonnes-ci, avec ce signe-là (ROTATION_90 : x écran = −y téléphone, y écran = x téléphone). z ne
        // change pas : le produit vectoriel des deux premiers, que remapCoordinateSystem garde de même signe.
        let (x, y): ((colonne: Int, signe: Float), (colonne: Int, signe: Float))
        switch ((rotation % 4) + 4) % 4 {
        case 1: (x, y) = ((1, -1), (0, 1))
        case 2: (x, y) = ((0, -1), (1, -1))
        case 3: (x, y) = ((1, 1), (0, -1))
        default: return r
        }
        var sortie = r
        for ligne in 0..<3 {
            sortie[ligne * 3] = x.signe * r[ligne * 3 + x.colonne]
            sortie[ligne * 3 + 1] = y.signe * r[ligne * 3 + y.colonne]
            sortie[ligne * 3 + 2] = r[ligne * 3 + 2]
        }
        return sortie
    }
}
