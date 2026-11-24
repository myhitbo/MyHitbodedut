import Foundation
import SwiftUI
import Coeur
import Ecrans

// Les deux dessins de Birkat haLevana (Levana.kt d'Android, `Levana.Dessin` et `Levana.Jauge`) : la lune de ce
// soir et la jauge du mois lunaire. Décoratifs : les textes de la carte disent la même chose à VoiceOver.

/// La lune de ce soir (Levana.Dessin), 56 × 56 : un disque d'ombre, la part éclairée (le demi-disque du côté
/// éclairé, refermé par le terminateur, une demi-ellipse), quatre mers à peine, un contour clair. Ses couleurs
/// sont écrites en dur sur Android : ce ne sont pas des jetons.
struct ZmanimLune: View {
    let lune: Levana.Lune
    /// Au sud de l'équateur, le dessin en miroir.
    let sud: Bool

    init(lune: Levana.Lune, sud: Bool) {
        self.lune = lune
        self.sud = sud
    }

    var body: some View {
        let lune = self.lune
        let sud = self.sud
        Canvas { contexte, taille in
            let r = min(taille.width, taille.height) / 2 - 1
            let cx = taille.width / 2
            let cy = taille.height / 2
            let disque = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
            contexte.fill(disque, with: .color(ZmanimDessin.ombre))
            contexte.drawLayer { couche in
                couche.clip(to: ZmanimDessin.partEclairee(lune: lune, sud: sud, cx: cx, cy: cy, r: r))
                couche.fill(disque, with: .color(ZmanimDessin.clair))
                // Quelques mers, à peine : la lune, pas un disque.
                for mer in ZmanimDessin.mers {
                    let rayon = mer.rayon * r
                    let centre = CGPoint(x: cx + mer.x * r, y: cy + mer.y * r)
                    couche.fill(Path(ellipseIn: CGRect(x: centre.x - rayon, y: centre.y - rayon,
                                                       width: 2 * rayon, height: 2 * rayon)),
                                with: .color(ZmanimDessin.mer))
                }
            }
            contexte.stroke(disque, with: .color(Color.white.opacity(0.2)), lineWidth: 1)
        }
        .frame(width: 56, height: 56)
        // Le dessin d'Android ne se retourne pas en hébreu : son côté éclairé est celui du ciel.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
    }
}

/// La jauge du mois lunaire (Levana.Jauge), 18 de haut sur toute la largeur : un fil `line` de 3, la fenêtre en
/// or (`ring_streak`) de 6, le soir du jour en point de la marque (rayon 5) cerclé de la couleur des cartes
/// (rayon 7). Chaque position va de 7 à la largeur − 7 ; en hébreu, le mois va de droite à gauche, comme le texte.
struct ZmanimJaugeVue: View {
    let jauge: ZmanimJauge

    @Environment(\.layoutDirection) private var sens
    @Environment(\.paletteApp) private var palette
    @Environment(\.colorScheme) private var schema

    init(jauge: ZmanimJauge) {
        self.jauge = jauge
    }

    var body: some View {
        let jauge = self.jauge
        let rtl = sens == .rightToLeft
        let fil = palette.couleur(.line, schema: schema)
        let dore = ZmanimDessin.or(schema)
        let point = palette.couleur(.brand, schema: schema)
        let bord = palette.couleur(.card, schema: schema)
        Canvas { contexte, taille in
            let r: CGFloat = 7
            let y = taille.height / 2
            let g = r
            let dr = max(g, taille.width - r)
            let a = ZmanimDessin.x(jauge.debut, g: g, dr: dr, rtl: rtl)
            let b = ZmanimDessin.x(jauge.fin, g: g, dr: dr, rtl: rtl)
            let p = ZmanimDessin.x(jauge.point, g: g, dr: dr, rtl: rtl)
            contexte.fill(Path(roundedRect: CGRect(x: g, y: y - 1.5, width: dr - g, height: 3), cornerRadius: 2),
                          with: .color(fil))
            contexte.fill(Path(roundedRect: CGRect(x: min(a, b), y: y - 3, width: abs(b - a), height: 6), cornerRadius: 3),
                          with: .color(dore))
            contexte.fill(Path(ellipseIn: CGRect(x: p - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(bord))
            contexte.fill(Path(ellipseIn: CGRect(x: p - r + 2, y: y - r + 2, width: 2 * (r - 2), height: 2 * (r - 2))),
                          with: .color(point))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 18)
        // Le sens est déjà pris en compte dans le tracé, d'après la langue de l'écran.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
    }
}

/// Les couleurs et les tracés des deux dessins, hors des vues : le Canvas les appelle pendant qu'il dessine.
enum ZmanimDessin {
    /// #3A3F4A.
    static let ombre = Color(.sRGB, red: 0x3A / 255.0, green: 0x3F / 255.0, blue: 0x4A / 255.0, opacity: 1)
    /// #F4EFD8.
    static let clair = Color(.sRGB, red: 0xF4 / 255.0, green: 0xEF / 255.0, blue: 0xD8 / 255.0, opacity: 1)
    /// #6B6450 à 0x2E (18 %).
    static let mer = Color(.sRGB, red: 0x6B / 255.0, green: 0x64 / 255.0, blue: 0x50 / 255.0,
                           opacity: 0x2E / 255.0)

    /// Les mers : centre et rayon en fractions du rayon de la lune.
    struct Mer: Sendable {
        let x: CGFloat
        let y: CGFloat
        let rayon: CGFloat
    }

    static let mers: [Mer] = [
        Mer(x: -0.25, y: -0.3, rayon: 0.22),
        Mer(x: 0.2, y: -0.1, rayon: 0.18),
        Mer(x: -0.05, y: 0.25, rayon: 0.2),
        Mer(x: 0.35, y: 0.35, rayon: 0.1),
    ]

    /// La part éclairée, comme le chemin d'Android : du haut, le demi-cercle du côté éclairé (à droite quand elle
    /// croît au nord) jusqu'en bas, puis, du bas, la demi-ellipse du terminateur, de demi-largeur r·|1 − 2k|,
    /// bombée vers l'ombre au-delà de la moitié. Les arcs sont tracés point par point (y vers le bas, comme le
    /// Canvas d'Android : l'angle croît dans le sens des aiguilles d'une montre).
    static func partEclairee(lune: Levana.Lune, sud: Bool, cx: CGFloat, cy: CGFloat, r: CGFloat) -> Path {
        let droite = lune.croissante != sud
        let k = CGFloat(lune.eclairage)
        let ellipse = r * abs(1 - 2 * k)
        let bombe = k > 0.5 ? droite : !droite
        let pas = 48
        var chemin = Path()
        for i in 0...pas {
            let t = CGFloat(i) / CGFloat(pas)
            let angle = (-90 + (droite ? 180 : -180) * t) * CGFloat.pi / 180
            let point = CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle))
            if i == 0 {
                chemin.move(to: point)
            } else {
                chemin.addLine(to: point)
            }
        }
        for i in 0...pas {
            let t = CGFloat(i) / CGFloat(pas)
            let angle = (90 + (bombe ? 180 : -180) * t) * CGFloat.pi / 180
            chemin.addLine(to: CGPoint(x: cx + ellipse * cos(angle), y: cy + r * sin(angle)))
        }
        chemin.closeSubpath()
        return chemin
    }

    /// La position d'une part du mois, de gauche à droite, ou de droite à gauche en hébreu.
    static func x(_ part: Float, g: CGFloat, dr: CGFloat, rtl: Bool) -> CGFloat {
        let p = CGFloat(part)
        return rtl ? dr - p * (dr - g) : g + p * (dr - g)
    }

    /// @color/ring_streak, qui n'est pas un jeton de la palette : #B8780F de jour, #E8B45C de nuit.
    static func or(_ schema: ColorScheme) -> Color {
        schema == .dark
            ? Color(.sRGB, red: 0xE8 / 255.0, green: 0xB4 / 255.0, blue: 0x5C / 255.0, opacity: 1)
            : Color(.sRGB, red: 0xB8 / 255.0, green: 0x78 / 255.0, blue: 0x0F / 255.0, opacity: 1)
    }
}
