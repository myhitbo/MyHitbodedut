// Le décor de la vignette, en nombres (VignetteDecor.kt, demande du 04/10 : « trop banale ») : son
// dégradé, ses voiles et la taille de son image.
//
// La vignette porte la couleur des boutons choisie, en dégradé du coin de départ vers le foncé (comme
// la plaque de l'écran de séance), avec deux grands arcs très pâles et un halo derrière le hassid. Le
// dégradé part de « day_done » (la même couleur le jour, fixe la nuit) et arrive sur « brand_dark »,
// fixe lui aussi ; le soir, les deux bouts foncent encore. Tout ce qui est écrit dessus l'est en blanc
// ou en « mint » : VignetteDecorTests vérifie qu'ils restent lisibles sur le pire point du fond, d'où
// les voiles plafonnés ici.
//
// Comme sur Android, les couleurs sont des entiers ARGB (0xAARRGGBB, ici en UInt32) et les calculs se
// font en simple précision (Float), arrondis comme `roundToInt` ; les jetons de la palette (Couleur,
// opaques) y passent par `argb` et en reviennent par `couleur`.

/// Le dégradé, les voiles et l'image de fond de la vignette.
public enum VignetteDecor {

    /// La part de brand_dark dans le coin clair, le jour : le coin reste vif sans pâlir le texte.
    public static let departJour: Float = 0.2

    /// La nuit, le coin clair se rapproche du foncé…
    public static let departNuit: Float = 0.45

    /// … et le foncé descend vers le noir.
    public static let noirNuit: Float = 0.35

    /// Le blanc des deux arcs décoratifs : à peine visibles, ils ne doivent rien coûter au texte.
    public static let arcExterieur: Float = 0.05
    public static let arcInterieur: Float = 0.035

    /// Le halo derrière les anneaux : il ne passe jamais sous le texte.
    public static let halo: Float = 0.18

    /// Le liseré clair du haut, sur le bord seulement.
    public static let lisere: Float = 0.16

    /// Le voile sombre sous le texte du jour et sous le compte : il ne fait que gagner du contraste.
    public static let voilePanneau: Float = 0.18
    public static let voileBadge: Float = 0.24

    /// Le disque sombre sous les anneaux, qui les détache du dégradé.
    public static let voileAnneaux: Float = 0.16

    /// La plus grande image de fond, en pixels : un dégradé n'a pas besoin de plus.
    public static let coteMax = 640

    public static let blanc: UInt32 = 0xFFFF_FFFF
    public static let noir: UInt32 = 0xFF00_0000

    /// Le mélange de deux couleurs, canal par canal (alpha compris) ; `t` est la part de `b`, ramenée
    /// entre 0 et 1.
    public static func melange(_ a: UInt32, _ b: UInt32, _ t: Float) -> UInt32 {
        let u = borne(t, 0, 1)
        func canal(_ decalage: Int) -> UInt32 {
            let x = Int((a >> decalage) & 0xFF)
            let y = Int((b >> decalage) & 0xFF)
            // (x + (y - x) * u).roundToInt() : Int fois Float se calcule en Float, comme sur la JVM.
            let v = Kotlin.arrondiFlottant(Float(x) + Float(y - x) * u)
            return UInt32(v < 0 ? 0 : (v > 255 ? 255 : v))
        }
        let alpha = canal(24) << 24
        let rouge = canal(16) << 16
        let vert = canal(8) << 8
        return alpha | rouge | vert | canal(0)
    }

    /// La couleur avec une autre opacité, de 0 à 1.
    public static func opacite(_ couleur: UInt32, _ alpha: Float) -> UInt32 {
        let a = Kotlin.arrondiFlottant(borne(alpha, 0, 1) * 255)
        let octet = UInt32(a < 0 ? 0 : (a > 255 ? 255 : a))
        return (octet << 24) | (couleur & 0x00FF_FFFF)
    }

    /// Les deux bouts du dégradé : le coin de départ, puis le coin foncé.
    public static func degrade(jourFait: UInt32, brandDark: UInt32, nuit: Bool) -> (clair: UInt32, fonce: UInt32) {
        if nuit {
            return (melange(jourFait, brandDark, departNuit), melange(brandDark, noir, noirNuit))
        }
        return (melange(jourFait, brandDark, departJour), brandDark)
    }

    /// Le fond le plus clair sur lequel un texte peut tomber : le coin de départ, sous l'arc le plus
    /// marqué. Le halo et le liseré n'y sont pas : ils restent derrière le hassid et sur le bord.
    public static func pireFond(jourFait: UInt32, brandDark: UInt32, nuit: Bool) -> UInt32 {
        let arc = arcExterieur > arcInterieur ? arcExterieur : arcInterieur
        return melange(degrade(jourFait: jourFait, brandDark: brandDark, nuit: nuit).clair, blanc, arc)
    }

    /// Le dégradé d'une palette : de son « day_done » vers son « brand_dark ».
    public static func degrade(_ palette: Palette, nuit: Bool) -> (clair: Couleur, fonce: Couleur) {
        let bouts = degrade(jourFait: argb(palette[.dayDone]), brandDark: argb(palette[.brandDark]), nuit: nuit)
        return (couleur(bouts.clair), couleur(bouts.fonce))
    }

    /// Le pire fond d'une palette.
    public static func pireFond(_ palette: Palette, nuit: Bool) -> Couleur {
        couleur(pireFond(jourFait: argb(palette[.dayDone]), brandDark: argb(palette[.brandDark]), nuit: nuit))
    }

    /// La taille de l'image de fond, en pixels, pour une vignette de `largeurDp` × `hauteurDp` : la
    /// densité de l'écran, ramenée sous `max` sans changer les proportions.
    public static func pixels(largeurDp: Float, hauteurDp: Float, densite: Float,
                              max plafond: Int = VignetteDecor.coteMax) -> (largeur: Int, hauteur: Int) {
        let l = auMoins(auMoins(largeurDp, 1) * densite, 1)
        let h = auMoins(auMoins(hauteurDp, 1) * densite, 1)
        let echelle = plusPetit(1, Float(plafond) / plusGrand(l, h))
        let largeur = Kotlin.arrondiFlottant(l * echelle)
        let hauteur = Kotlin.arrondiFlottant(h * echelle)
        return (largeur < 1 ? 1 : largeur, hauteur < 1 ? 1 : hauteur)
    }

    /// Un jeton de la palette en entier ARGB, opaque.
    public static func argb(_ c: Couleur) -> UInt32 {
        let rouge = UInt32(c.rouge) << 16
        let vert = UInt32(c.vert) << 8
        return 0xFF00_0000 | rouge | vert | UInt32(c.bleu)
    }

    /// Les trois canaux d'un entier ARGB ; l'opacité n'est pas gardée.
    public static func couleur(_ argb: UInt32) -> Couleur {
        Couleur(rouge: UInt8(truncatingIfNeeded: argb >> 16), vert: UInt8(truncatingIfNeeded: argb >> 8),
                bleu: UInt8(truncatingIfNeeded: argb))
    }

    // MARK: Les bornes de Kotlin et de Java, NaN compris

    /// `coerceIn(a, b)` : NaN passe tel quel.
    private static func borne(_ x: Float, _ a: Float, _ b: Float) -> Float {
        if x < a { return a }
        if x > b { return b }
        return x
    }

    /// `coerceAtLeast(m)` : NaN passe tel quel.
    private static func auMoins(_ x: Float, _ m: Float) -> Float {
        x < m ? m : x
    }

    /// `Math.max(a, b)` sur des Float : NaN l'emporte, +0 l'emporte sur −0.
    private static func plusGrand(_ a: Float, _ b: Float) -> Float {
        if a.isNaN { return a }
        if a == 0 && b == 0 && a.sign == .minus { return b }
        return a >= b ? a : b
    }

    /// `Math.min(a, b)` sur des Float : NaN l'emporte, −0 l'emporte sur +0.
    private static func plusPetit(_ a: Float, _ b: Float) -> Float {
        if a.isNaN { return a }
        if a == 0 && b == 0 && b.sign == .minus { return b }
        return a <= b ? a : b
    }
}
