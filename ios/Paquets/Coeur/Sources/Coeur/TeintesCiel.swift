import Foundation
import Synchronization

/// Les teintes du ciel en fond du Jour (TeintesCiel.kt, 24/11). Demande du propriétaire : « Fais en sorte que le mode
/// jour nuit au coucher du soleil ou lever du soleil s'affiche dans l'arrière-plan de la première page sur toute la
/// page, pas dans le logo dans les anneaux ».
///
/// Le ciel est celui de `CielContinu` (couleurs brutes selon la hauteur du soleil, le matin ou le soir), adapté au
/// thème pour que chaque texte de la page garde les seuils de PaletteTests, à toute heure, pour chaque palette
/// « Fond » et « Accent » :
///  - thème sombre : chaque couleur est assombrie, teinte et saturation gardées, jusqu'à une luminance où les encres
///    claires (encre 7:1, texte secondaire, accent, légendes des anneaux 4,5:1) tiennent encore ; l'aube et le
///    coucher tirent vers le violet de leur haut, saturation bornée à 55 %, faute de quoi l'orangé sombre devient
///    brun ;
///  - thème clair : chaque couleur est éclaircie de la même façon, jusqu'à la luminance où les encres sombres
///    tiennent : un ciel pastel.
/// La lueur large du halo et les nuages (bord éclairé et corps) ont une opacité bornée par le même calcul, sur tout
/// le dégradé ; en thème sombre, le corps des nuages est une silhouette plus sombre que le ciel. Les étoiles, le
/// disque de l'astre, sa couronne et ses rayons ne sont jamais posés sous un texte (`PlanCiel`).
///
/// Le calcul est pur (des entiers ARGB) : TeintesCielTests le refait pour chaque palette de `palettes.json`. Les
/// mêmes règles qu'Android et que le site (ciel.js), au bit près.
public enum TeintesCiel {

    /// Une encre posée sur le ciel, et le contraste qu'elle doit y garder.
    public struct Encre: Sendable, Hashable {
        public let couleur: UInt32
        public let seuil: Double

        public init(couleur: UInt32, seuil: Double) {
            self.couleur = couleur
            self.seuil = seuil
        }
    }

    /// Le ciel d'un moment, pour un thème : le dégradé du haut de la page (0) au bas de l'écran (1), arrêt du milieu
    /// à `milieuDegrade` ; la lueur large du halo et son opacité au plus fort ; la couronne (et les rayons de l'heure
    /// dorée) et le disque du soleil ; la lune ; le corps et le bord éclairé des nuages et leurs opacités au plus
    /// fort ; les étoiles ; les deux collines du bas de l'écran, sous la barre de départ.
    public struct Page: Sendable, Equatable {
        public let haut: UInt32, milieu: UInt32, bas: UInt32
        public let lueur: UInt32, lueurAlpha: Float
        public let couronne: UInt32, astre: UInt32, lune: UInt32
        public let corps: UInt32, corpsAlpha: Float, bord: UInt32, bordAlpha: Float
        public let corpsVif: UInt32, bordVif: UInt32
        public let etoile: UInt32, etoileAlpha: Float
        public let collineLoin: UInt32, collinePres: UInt32

        static func nue(_ arrets: [UInt32]) -> Page {
            Page(haut: arrets[0], milieu: arrets[1], bas: arrets[2], lueur: 0, lueurAlpha: 0, couronne: 0, astre: 0,
                 lune: 0, corps: 0, corpsAlpha: 0, bord: 0, bordAlpha: 0, corpsVif: 0, bordVif: 0, etoile: 0,
                 etoileAlpha: 0, collineLoin: 0, collinePres: 0)
        }

        /// La couleur du dégradé à la hauteur `u` (0 en haut, 1 en bas de l'écran et au-delà).
        public func degrade(_ u: Float) -> UInt32 {
            if u <= 0 { return haut }
            if u < milieuDegrade { return melange(haut, milieu, Double(u / milieuDegrade)) }
            if u < 1 { return melange(milieu, bas, Double((u - milieuDegrade) / (1 - milieuDegrade))) }
            return bas
        }
    }

    /// L'arrêt du milieu du dégradé, comme dans l'ancienne plaque du ciel (14/11).
    public static let milieuDegrade: Float = 0.55

    /// Ce que le calcul garde en réserve au-dessus de chaque seuil : l'arrondi à 8 bits et le tramage du dégradé.
    public static let marge = 0.05

    /// Thème clair : la luminance de chaque arrêt, au-dessus de la plus basse permise.
    private static let ecartClair: [Float] = [0.012, 0.03, 0.05]

    private static let echantillons = 48
    private static let astreClair = 0.55
    private static let etoileSombre: UInt32 = 0xFFFFF6EC
    private static let etoileClaire: UInt32 = 0xFF7884C4

    // MARK: Les encres du Jour

    /// Les légendes des anneaux de la semaine et de la série (ring_week_text, ring_streak_text de colors.xml), de
    /// jour et de nuit : plus sombres que le trait de l'anneau, elles tiennent 4,5:1 sur le papier comme sur le ciel.
    public static let legendeSemaine: (jour: UInt32, nuit: UInt32) = (0xFF256A9A, 0xFF6FB7E8)
    public static let legendeSerie: (jour: UInt32, nuit: UInt32) = (0xFF8A5A00, 0xFFE8B45C)

    /// Les encres posées sur le ciel du Jour et le contraste qu'elles y gardent, ceux de PaletteTests
    /// (MainActivity.encresDuJour) : le titre (7:1), le texte secondaire, l'accent (palier, boutons-liens) et les
    /// légendes des anneaux (4,5:1).
    public static func encresDuJour(_ palette: Palette, nuit: Bool) -> [Encre] {
        encresDuJour(encre: palette[.ink], discret: palette[.muted], accent: palette[.brand], nuit: nuit)
    }

    /// Les mêmes, d'après les trois jetons de la palette (l'encre, le texte discret, l'accent). Le texte discret
    /// d'iOS est mêlé d'un quart de l'encre (PaletteApp.renfortDiscret) : plus contrasté que le jeton, il tient
    /// d'autant mieux le seuil que le jeton seul tient.
    public static func encresDuJour(encre: Couleur, discret: Couleur, accent: Couleur, nuit: Bool) -> [Encre] {
        [
            Encre(couleur: argb(encre), seuil: 7),
            Encre(couleur: argb(discret), seuil: 4.5),
            Encre(couleur: argb(accent), seuil: 4.5),
            Encre(couleur: nuit ? legendeSemaine.nuit : legendeSemaine.jour, seuil: 4.5),
            Encre(couleur: nuit ? legendeSerie.nuit : legendeSerie.jour, seuil: 4.5),
        ]
    }

    /// Une couleur de la palette, en ARGB.
    public static func argb(_ c: Couleur) -> UInt32 {
        0xFF00_0000 | UInt32(c.rouge) << 16 | UInt32(c.vert) << 8 | UInt32(c.bleu)
    }

    // MARK: Le ciel d'un moment

    /// Le ciel quand le soleil est à `hauteur` degrés, avec la part du `matin` (1 le matin, 0 le soir,
    /// `CielContinu.partMatin`), sous des encres `encres` (claires si `sombre`, sombres sinon). Si aucune teinte ne
    /// les laisse lisibles (palette future trop exigeante), le ciel reste le `papier`.
    public static func pourCiel(_ hauteur: Double, matin: Double, sombre: Bool, encres: [Encre], papier: UInt32) -> Page {
        let cle = Cle(hauteur: CielContinu.arrondi(hauteur),
                      matin: Double(Kotlin.arrondi(min(max(matin, 0), 1) * 20)) / 20,
                      sombre: sombre, encres: encres, papier: papier)
        if let deja = memoire.withLock({ $0[cle] }) { return deja }
        let page = calculer(cle.hauteur, matin: cle.matin, sombre: sombre, encres: encres, papier: papier)
        memoire.withLock { pages in
            if pages.count >= 16 { pages.removeAll() }
            pages[cle] = page
        }
        return page
    }

    /// Le `matin` ou le soir, sans passage.
    public static func pourCiel(_ hauteur: Double, matin: Bool, sombre: Bool, encres: [Encre], papier: UInt32) -> Page {
        pourCiel(hauteur, matin: matin ? 1.0 : 0.0, sombre: sombre, encres: encres, papier: papier)
    }

    /// Les ciels déjà calculés : l'accueil revoit le sien chaque minute, au quart de degré et au vingtième du matin.
    private struct Cle: Hashable {
        let hauteur: Double
        let matin: Double
        let sombre: Bool
        let encres: [Encre]
        let papier: UInt32
    }
    private static let memoire = Mutex<[Cle: Page]>([:])

    /// `lisible`, la luminance de chaque encre lue une fois : le calcul la demande des centaines de milliers de fois.
    /// Le même rapport que `contraste`, au bit près.
    private struct Lecture {
        let luminances: [Double]
        let minima: [Double]

        init(_ encres: [Encre]) {
            luminances = encres.map { TeintesCiel.luminance($0.couleur) }
            minima = encres.map { $0.seuil + TeintesCiel.marge }
        }

        func lisible(_ fond: UInt32) -> Bool {
            let l = TeintesCiel.luminance(fond)
            for i in luminances.indices {
                let x = luminances[i]
                if (max(x, l) + 0.05) / (min(x, l) + 0.05) < minima[i] { return false }
            }
            return true
        }
    }

    private static func calculer(_ e: Double, matin: Double, sombre: Bool, encres: [Encre], papier: UInt32) -> Page {
        let borne = borne(encres, sombre: sombre)
        let lecture = Lecture(encres)
        func lisible(_ fond: UInt32, _ encres: [Encre]) -> Bool { lecture.lisible(fond) }
        // Les arrêts, puis la vérification sur tout le dégradé : entre deux arrêts lisibles, le mélange peut perdre un
        // rien de luminance. On reprend alors avec plus de réserve.
        var reserve = 0
        var arrets = calculerArrets(e, matin: matin, sombre: sombre, borne: borne, reserve: 0)
        while !degradeLisible(arrets, lecture) && reserve < 12 {
            reserve += 1
            arrets = calculerArrets(e, matin: matin, sombre: sombre, borne: borne, reserve: reserve)
        }
        if !degradeLisible(arrets, lecture) { arrets = [papier, papier, papier] }
        let nu = Page.nue(arrets)
        let fonds = (0...echantillons).map { nu.degrade(Float($0) / Float(echantillons)) }
        func tous(_ fonds: [UInt32], _ couche: UInt32, _ a: Double) -> Bool {
            fonds.allSatisfy { lisible(melange($0, couche, a), encres) }
        }

        // Les nuages d'abord, ils passent partout : le bord éclairé (dessous), puis le corps par-dessus. En thème
        // sombre le corps est une silhouette plus sombre que le ciel, seul son bord s'allume ; en thème clair, corps
        // et bord sont pâles, assez pour se poser pleinement sous les encres sombres.
        var bord = CielContinu.nuageBord.a(e)
        var corps = CielContinu.nuageCorps.a(e)
        let plusSombre = fonds.map(luminance).min() ?? 0
        if sombre {
            corps = aLuminance(corps, plusSombre * 0.6)
        } else {
            if luminance(corps) < borne + 0.08 { corps = aLuminance(corps, min(borne + 0.08, 1)) }
            if luminance(bord) < borne + 0.03 { bord = aLuminance(bord, min(borne + 0.03, 1)) }
        }
        let bordAlpha = opaciteMax(sombre ? 0.5 : 0.8) { a in tous(fonds, bord, a) }
        let sousBord = fonds.map { melange($0, bord, Double(bordAlpha)) }
        let corpsAlpha = opaciteMax(sombre ? 0.6 : 0.8) { a in tous(fonds, corps, a) && tous(sousBord, corps, a) }

        // La lueur large prend ce qui reste, nuages par-dessus compris, dans l'ordre du dessin.
        var lueur = CielContinu.lueur.a(e)
        if e < 0 { lueur = melange(lueur, CielContinu.lune, CielContinu.rampe(e, de: 0, a: -12)) }
        if !sombre && luminance(lueur) < borne + 0.06 { lueur = aLuminance(lueur, min(borne + 0.06, 1)) }
        let lueurAlpha = opaciteMax(sombre ? 0.9 : 0.85) { a in
            fonds.allSatisfy { fond in
                let sous = melange(fond, lueur, a)
                let bordDessus = melange(sous, bord, Double(bordAlpha))
                return lisible(sous, encres) && lisible(bordDessus, encres)
                    && lisible(melange(sous, corps, Double(corpsAlpha)), encres)
                    && lisible(melange(bordDessus, corps, Double(corpsAlpha)), encres)
            }
        }

        // Le soleil tel quel sur un ciel sombre ; plus soutenu sur un ciel pâle, pour s'y détacher. De même la lune.
        func detache(_ c: UInt32) -> UInt32 { !sombre && luminance(c) > astreClair ? aLuminance(c, astreClair) : c }
        // Les collines du bas : la couleur du bas tirée vers le haut du ciel, la plus proche plus sombre.
        let loin = melange(arrets[2], arrets[0], 0.5)
        let pres0 = melange(arrets[2], arrets[0], 0.9)
        let pres = aLuminance(pres0, luminance(arrets[2]) * (sombre ? 0.55 : 0.86))
        // Du texte peut passer sur les collines et le sol : ils restent lisibles eux aussi.
        func lisibleAjuste(_ c0: UInt32) -> UInt32 {
            var c = c0
            var n = 0
            while !lisible(c, encres) && n < 40 {
                n += 1
                let l = luminance(c)
                c = aLuminance(c, sombre ? l * 0.9 : min(l + 0.01, 1))
            }
            return c
        }
        return Page(
            haut: arrets[0], milieu: arrets[1], bas: arrets[2],
            lueur: lueur, lueurAlpha: lueurAlpha,
            couronne: CielContinu.lueur.a(e), astre: detache(CielContinu.astre.a(e)), lune: detache(CielContinu.lune),
            corps: corps, corpsAlpha: corpsAlpha, bord: bord, bordAlpha: bordAlpha,
            corpsVif: nuageVif(CielContinu.nuageCorps.a(e), sombre: sombre, corps: true, haut: arrets[0]),
            bordVif: nuageVif(CielContinu.nuageBord.a(e), sombre: sombre, corps: false),
            etoile: sombre ? etoileSombre : etoileClaire,
            etoileAlpha: sombre ? 0.9 : 0.8,
            collineLoin: lisibleAjuste(aLuminance(loin, luminance(arrets[2]) * (sombre ? 0.8 : 0.94))),
            collinePres: lisibleAjuste(pres))
    }

    /// Les couleurs d'un nuage qui ne passe sous aucun texte (dans la bande des anneaux, `PlanCiel.nuages`) : vives,
    /// sans borne de lisibilité. En thème sombre, le corps est à contre-jour : à moitié la couleur du `haut` du ciel,
    /// atténué (luminance 0,10 au plus), sans s'aviver ; le bord garde sa lumière (0,35 au plus), sans s'aviver non
    /// plus. En thème clair, le corps est pâle (0,8 au moins), le bord tel quel.
    public static func nuageVif(_ c: UInt32, sombre: Bool, corps: Bool, haut: UInt32? = nil) -> UInt32 {
        if sombre && corps {
            let m = melange(c, haut ?? c, 0.5)
            return luminance(m) > 0.10 ? assombrirSansAviver(m, 0.10) : m
        }
        if sombre { return luminance(c) > 0.35 ? assombrirSansAviver(c, 0.35) : c }
        if corps { return luminance(c) < 0.8 ? aLuminance(c, 0.8) : c }
        return c
    }

    /// L'écart entre le plus fort et le plus faible canal, de 0 (un gris) à 1 : ce qu'une couleur a de couleur.
    public static func chroma(_ c: UInt32) -> Double {
        let r = canal(c, 16), g = canal(c, 8), b = canal(c, 0)
        return Double(max(r, g, b) - min(r, g, b)) / 255
    }

    /// `c` assombrie à la luminance `cible` comme par `aLuminance`, sans gagner de couleur : à saturation gardée, un
    /// blanc crème assombri devenait un kaki vif. Sa saturation baisse d'autant que sa couleur aurait crû.
    public static func assombrirSansAviver(_ c: UInt32, _ cible: Double) -> UInt32 {
        var r = aLuminance(c, cible)
        let avant = chroma(c)
        for _ in 0..<3 {
            let apres = chroma(r)
            if apres <= avant + 1.0 / 255 { return r }
            let h = hsl(r)
            r = aLuminance(deHsl(h[0], h[1] * avant / apres, h[2]), cible)
        }
        return r
    }

    /// Les trois arrêts du dégradé ; chaque cran de `reserve` les éloigne un peu plus de la borne.
    private static func calculerArrets(_ e: Double, matin: Double, sombre: Bool, borne: Double,
                                       reserve: Int) -> [UInt32] {
        let departs = CielContinu.brutes(e, matin: matin)
        let parts = CielContinu.partsSombre(e)
        let chaleur = CielContinu.chaleur(e)
        return (0..<3).map { i in
            var c = departs[i]
            if sombre {
                let cible = borne * Double(parts[i]) * pow(0.9, Double(reserve))
                if luminance(c) > cible {
                    // L'orangé sombre devient brun, le vert-de-gris kaki : à l'aube, au coucher et jusqu'au bout de
                    // l'heure dorée, le milieu et l'horizon tirent vers le violet ou le bleu de leur haut,
                    // saturation bornée.
                    if i > 0 && chaleur > 0 {
                        c = melange(c, departs[0], 0.45 * chaleur)
                        let h = hsl(c)
                        c = deHsl(h[0], min(h[1], 1 - 0.45 * chaleur), h[2])
                    }
                    c = aLuminance(c, cible)
                }
            } else {
                let cible = borne + Double(ecartClair[i]) + 0.01 * Double(reserve)
                if luminance(c) < cible { c = aLuminance(c, min(cible, 1)) }
            }
            return c
        }
    }

    private static func degradeLisible(_ arrets: [UInt32], _ lecture: Lecture) -> Bool {
        let page = Page.nue(arrets)
        return (0...echantillons).allSatisfy { lecture.lisible(page.degrade(Float($0) / Float(echantillons))) }
    }

    /// Chaque encre garde son seuil (plus la marge) sur `fond`.
    public static func lisible(_ fond: UInt32, _ encres: [Encre]) -> Bool {
        encres.allSatisfy { contraste($0.couleur, fond) >= $0.seuil + marge }
    }

    /// La plus forte opacité (au plus `plafond`) pour laquelle `tient` ; 0 si même un voile ténu est de trop.
    public static func opaciteMax(_ plafond: Float, _ tient: (Double) -> Bool) -> Float {
        if tient(Double(plafond)) { return plafond }
        if !tient(0) { return 0 }
        var bas = 0.0
        var haut = Double(plafond)
        for _ in 0..<24 {
            let m = (bas + haut) / 2
            if tient(m) { bas = m } else { haut = m }
        }
        return Float(bas)
    }

    /// Thème sombre : la plus haute luminance qu'un fond peut avoir pour que chaque encre (claire) y garde son seuil.
    /// Thème clair : la plus basse, pour des encres sombres.
    public static func borne(_ encres: [Encre], sombre: Bool) -> Double {
        sombre
            ? encres.map { (luminance($0.couleur) + 0.05) / $0.seuil - 0.05 }.min() ?? 1
            : encres.map { $0.seuil * (luminance($0.couleur) + 0.05) - 0.05 }.max() ?? 0
    }

    // MARK: Les couleurs

    static func canal(_ c: UInt32, _ decalage: UInt32) -> Int { Int((c >> decalage) & 0xFF) }

    /// La valeur linéaire de chaque niveau d'un canal (sRGB), calculée une fois.
    private static let lineaire: [Double] = (0..<256).map { v in
        let c = Double(v) / 255
        return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    /// La luminance relative (WCAG) d'une couleur opaque.
    public static func luminance(_ c: UInt32) -> Double {
        0.2126 * lineaire[canal(c, 16)] + 0.7152 * lineaire[canal(c, 8)] + 0.0722 * lineaire[canal(c, 0)]
    }

    public static func contraste(_ a: UInt32, _ b: UInt32) -> Double {
        let x = luminance(a)
        let y = luminance(b)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    /// `a` recouvert de `b` à l'opacité `t` : un dégradé, ou une couche posée par-dessus. Opaque.
    public static func melange(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
        func m(_ d: UInt32) -> UInt32 {
            let x = Double(canal(a, d)) + Double(canal(b, d) - canal(a, d)) * t
            return UInt32(min(max(Kotlin.arrondi(x), 0), 255))
        }
        return 0xFF00_0000 | m(16) << 16 | m(8) << 8 | m(0)
    }

    /// Teinte (0 à 1), saturation, clarté.
    public static func hsl(_ c: UInt32) -> [Double] {
        let r = Double(canal(c, 16)) / 255
        let g = Double(canal(c, 8)) / 255
        let b = Double(canal(c, 0)) / 255
        let haut = max(r, g, b)
        let bas = min(r, g, b)
        let l = (haut + bas) / 2
        if haut == bas { return [0, 0, l] }
        let d = haut - bas
        let s = l > 0.5 ? d / (2 - haut - bas) : d / (haut + bas)
        let h: Double
        if haut == r {
            h = ((g - b) / d + (g < b ? 6 : 0)) / 6
        } else if haut == g {
            h = ((b - r) / d + 2) / 6
        } else {
            h = ((r - g) / d + 4) / 6
        }
        return [h, s, l]
    }

    public static func deHsl(_ h: Double, _ s: Double, _ l: Double) -> UInt32 {
        let c = (1 - abs(2 * l - 1)) * s
        let hp = (h * 6).truncatingRemainder(dividingBy: 6)
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        let (r, g, b): (Double, Double, Double)
        if hp < 1 {
            (r, g, b) = (c, x, 0)
        } else if hp < 2 {
            (r, g, b) = (x, c, 0)
        } else if hp < 3 {
            (r, g, b) = (0, c, x)
        } else if hp < 4 {
            (r, g, b) = (0, x, c)
        } else if hp < 5 {
            (r, g, b) = (x, 0, c)
        } else {
            (r, g, b) = (c, 0, x)
        }
        let m = l - c / 2
        func v(_ t: Double) -> UInt32 { UInt32(min(max(Kotlin.arrondi((t + m) * 255), 0), 255)) }
        return 0xFF00_0000 | v(r) << 16 | v(g) << 8 | v(b)
    }

    /// `c` amenée à la luminance `cible` en ne changeant que sa clarté : la teinte et la saturation restent, le ciel
    /// garde sa couleur en s'assombrissant ou en pâlissant. Arrondie du bon côté : au plus `cible` en assombrissant,
    /// au moins en éclaircissant.
    public static func aLuminance(_ c: UInt32, _ cible: Double) -> UInt32 {
        let teinte = hsl(c)
        let h = teinte[0], s = teinte[1]
        let assombrir = luminance(c) > cible
        var bas = 0.0
        var haut = 1.0
        for _ in 0..<40 {
            let m = (bas + haut) / 2
            if luminance(deHsl(h, s, m)) < cible { bas = m } else { haut = m }
        }
        // La couleur à 8 bits, du côté qui tient la cible.
        var l = assombrir ? bas : haut
        var r = deHsl(h, s, l)
        var garde = 0
        while garde < 64 && (assombrir ? luminance(r) > cible : luminance(r) < cible) {
            garde += 1
            l += assombrir ? -0.002 : 0.002
            r = deHsl(h, s, min(max(l, 0), 1))
        }
        return r
    }
}
