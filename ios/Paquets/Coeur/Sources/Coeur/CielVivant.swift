import Foundation

/// Les petites animations des ciels (CielVivant.kt, 24/11 ; demande du propriétaire : « Améliore les arrière-plans de
/// l'application, on rajoute des petites animations discrètes »).
///
/// La chorégraphie entière, en chiffres, la même qu'Android et que le site ; le dessin est dans les vues (le fond du
/// Jour, la carte-paysage de Sérénité).
///
/// Ce qui bouge, et rien d'autre :
///  - les étoiles scintillent, chacune à son rythme (8 à 16 s par cycle), entre 45 % et 100 % de leur éclat, jamais
///    au-delà de l'éclat du ciel immobile ;
///  - tout le champ d'étoiles dérive d'un rien : ±3 points en largeur sur 40 s, ±1,5 point en hauteur sur 31 s ;
///  - le halo du soleil ou de la lune respire : sur 12 s, il se resserre de 6 % et pâlit de 18 %, puis revient ; son
///    plus grand et son plus clair sont ceux du ciel immobile ;
///  - les nuages (trois, dans la bande des anneaux, qui prennent la lumière du moment) passent de gauche à droite à
///    3 points/s, le long à 2,1 points/s ; sortis d'un côté, ils reviennent de l'autre ;
///  - à l'heure dorée, les rayons doux du soleil bas font un tour en trois minutes.
/// Le soleil et la lune, eux, avancent sur leur arc avec l'heure réelle (`CielContinu`, revu chaque minute), pas avec
/// l'horloge des animations.
///
/// Ce qui ne bouge jamais : les écrans de lecture, la séance, les fonds unis.
///
/// Quand rien ne bouge (voir `permis` et `enMarche`) : le ciel prend sa pose de repos, la même à chaque fois —
/// étoiles pleines, halo entier, nuages à leur place de départ.
public enum CielVivant {

    /// Une image toutes les 50 ms au plus (20 par seconde) : le plus rapide de ces mouvements avance de 0,15 point
    /// par image.
    public static let imageMs = 50

    // MARK: Les étoiles

    /// Le cycle le plus court et le plus long d'un scintillement, en secondes.
    public static let scintillementMinS = 8.0
    public static let scintillementMaxS = 16.0

    /// Au plus bas du scintillement, l'étoile garde 45 % de son éclat.
    public static let scintillementBas: Float = 0.45

    /// La dérive du champ d'étoiles : amplitude en points et période en secondes, en largeur puis en hauteur.
    public static let deriveXDp: Float = 3
    public static let deriveXS = 40.0
    public static let deriveYDp: Float = 1.5
    public static let deriveYS = 31.0

    // MARK: Le halo

    /// Un souffle du halo : 12 s. Au creux, 94 % de sa taille et 82 % de son éclat.
    public static let souffleS = 12.0
    public static let souffleTaille: Float = 0.06
    public static let souffleEclat: Float = 0.18

    // MARK: Les nuages

    /// Les rayons doux de l'heure dorée tournent d'un tour en trois minutes.
    public static let rayonsDegS = 2.0

    /// Vitesse des nuages du jour, et du voile de l'aube et du coucher, en points par seconde.
    public static let nuageDpS: Float = 3
    public static let voileDpS: Float = 2

    /// Le ciel peut-il bouger ? Non si « Réduire les animations » est allumé (Accessibilité), ni en mode Économie
    /// d'énergie : sur Android, les animations du système coupées et l'économiseur de batterie.
    public static func permis(reduireAnimations: Bool, economieDEnergie: Bool) -> Bool {
        !reduireAnimations && !economieDEnergie
    }

    /// Le ciel bouge en ce moment : permis, l'app au premier plan et active (pas une scène inactive ni en arrière-
    /// plan), et l'écran qui le montre devant (pas un autre onglet, pas un écran poussé par-dessus) ; sinon il est
    /// dans sa pose de repos (HorlogeCiel.enMarche).
    public static func enMarche(permis: Bool, sceneActive: Bool, visible: Bool) -> Bool {
        permis && sceneActive && visible
    }

    /// Une onde douce de 0 (repos) à 1 et retour, sur `periode` secondes, décalée de `phase` (en tours).
    public static func onde(_ secondes: Double, periode: Double, phase: Double = 0) -> Float {
        Float((1 - cos(2 * .pi * (secondes / periode + phase))) / 2)
    }

    /// L'éclat d'une étoile, de `scintillementBas` à 1, selon son cycle et son décalage.
    public static func scintillement(_ secondes: Double, periode: Double, phase: Double) -> Float {
        1 - (1 - scintillementBas) * onde(secondes, periode: periode, phase: phase)
    }

    /// Le décalage du champ d'étoiles, en points.
    public static func deriveX(_ secondes: Double) -> Float { deriveXDp * Float(sin(2 * .pi * secondes / deriveXS)) }
    public static func deriveY(_ secondes: Double) -> Float {
        deriveYDp * Float(sin(2 * .pi * secondes / deriveYS + 1.3))
    }

    /// La taille du halo (1 au repos) et son éclat (1 au repos).
    public static func tailleHalo(_ secondes: Double) -> Float { 1 - souffleTaille * onde(secondes, periode: souffleS) }
    public static func eclatHalo(_ secondes: Double) -> Float { 1 - souffleEclat * onde(secondes, periode: souffleS) }

    /// Le bord gauche d'un nuage de largeur `largeurNuage` parti de `depart` à `vitesse` (unités par seconde), dans un
    /// ciel de largeur `largeurCiel` : il sort à droite, revient à gauche.
    public static func nuageX(depart: Double, vitesse: Double, secondes: Double, largeurCiel: Double,
                              largeurNuage: Double) -> Double {
        let tour = largeurCiel + largeurNuage
        if tour <= 0 { return depart }
        let x = ((depart + largeurNuage) + vitesse * secondes).truncatingRemainder(dividingBy: tour)
        return x - largeurNuage
    }

    /// Les étoiles d'un ciel : pour chacune, sa place (fractions de la largeur et de la hauteur), son rayon (points),
    /// son cycle (s) et son décalage (tours). Tirées d'une graine fixe, par le java.util.Random d'Android
    /// (`HasardJava`) : le même ciel d'une ouverture à l'autre, et le même qu'Android et que le site.
    public static func etoiles(_ nombre: Int, graine: Int64, rayonMin: Float, rayonMax: Float) -> [Float] {
        var r = HasardJava(graine: graine)
        var t = [Float](repeating: 0, count: nombre * champs)
        for i in 0..<nombre {
            t[i * champs] = r.nextFloat()
            t[i * champs + 1] = r.nextFloat()
            t[i * champs + 2] = rayonMin + r.nextFloat() * (rayonMax - rayonMin)
            t[i * champs + 3] = Float(scintillementMinS + Double(r.nextFloat()) * (scintillementMaxS - scintillementMinS))
            t[i * champs + 4] = r.nextFloat()
        }
        return t
    }

    /// Les champs d'une étoile dans le tableau de `etoiles` : x, y, rayon, cycle, décalage.
    public static let champs = 5

    /// La même graine d'une ouverture à l'autre (CielPage.GRAINE) : le ciel ne change pas d'étoiles.
    public static let graine: Int64 = 29
}

/// `java.util.Random(seed)` : le générateur linéaire congruentiel de Java (48 bits), pour retrouver sur iOS les
/// tirages qu'Android fait d'une même graine (les étoiles des ciels).
public struct HasardJava: Sendable {
    private static let multiplicateur: UInt64 = 0x5_DEEC_E66D
    private static let masque: UInt64 = (1 << 48) - 1
    private var graine: UInt64

    public init(graine: Int64) {
        self.graine = (UInt64(bitPattern: graine) ^ HasardJava.multiplicateur) & HasardJava.masque
    }

    private mutating func suivant(_ bits: Int) -> Int32 {
        graine = (graine &* HasardJava.multiplicateur &+ 0xB) & HasardJava.masque
        return Int32(truncatingIfNeeded: Int64(bitPattern: graine) >> (48 - bits))
    }

    /// `nextFloat()` : 24 bits, de 0 inclus à 1 exclu.
    public mutating func nextFloat() -> Float {
        Float(suivant(24)) / Float(1 << 24)
    }

    /// `nextInt()` : 32 bits signés.
    public mutating func nextInt() -> Int32 { suivant(32) }
}
