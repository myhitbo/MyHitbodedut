import Foundation
import SwiftUI
import Coeur
import Ecrans

// Ce que partagent les vues de l'écran du vol (VolActivity.kt, activity_vol.xml) : les couleurs mêlées d'Android
// (ColorUtils.blendARGB), le cadre de saisie, le bandeau (bg_hero), les fonds de la carte rapide et de la carte de
// la prière, le volet (« dépliant »), le lien et les icônes. Aucune décision ici : VolModele (cible Ecrans) a tout dit.

// MARK: Les couleurs

/// Les couleurs que l'écran du vol mêle ou écrit en dur (VolActivity.kt).
enum VolCouleurs {

    /// `ColorUtils.blendARGB(a, b, part)` d'Android : `part` de `b` dans `a`, composante par composante, tronquée
    /// à l'entier comme le `(int)` d'Android.
    static func melange(_ a: Couleur, _ b: Couleur, part: Double) -> Couleur {
        func canal(_ x: UInt8, _ y: UInt8) -> UInt8 {
            let v = Double(x) * (1 - part) + Double(y) * part
            return UInt8(min(max(v.rounded(.down), 0), 255))
        }
        return Couleur(rouge: canal(a.rouge, b.rouge), vert: canal(a.vert, b.vert), bleu: canal(a.bleu, b.bleu))
    }

    /// Une couleur ARGB d'Android (0xFF3E4F86), sans son alpha (toujours opaque ici).
    static func argb(_ valeur: UInt32) -> Couleur {
        Couleur(rouge: UInt8(truncatingIfNeeded: valeur >> 16),
                vert: UInt8(truncatingIfNeeded: valeur >> 8),
                bleu: UInt8(truncatingIfNeeded: valeur))
    }

    /// Une couleur écrite en dur par Android (« #2B3F6E » → 0x2B3F6E).
    static func fixe(_ valeur: UInt32) -> Color {
        Color(argb(valeur))
    }
}

/// Un jeton mêlé d'un autre jeton, ou d'une couleur écrite en dur, dans la proportion `part` : « card mêlé à 25 %
/// de line ». Résolu à l'affichage d'après la palette et le mode de l'écran, comme `Teinte`.
struct VolMelange: ShapeStyle {
    enum Autre: Sendable, Hashable {
        case jeton(Jeton)
        case fixe(Couleur)
    }

    let base: Jeton
    let autre: Autre
    let part: Double

    init(_ base: Jeton, _ autre: Autre, part: Double) {
        self.base = base
        self.autre = autre
        self.part = part
    }

    func resolve(in environment: EnvironmentValues) -> Color {
        let nuit = environment.colorScheme == .dark
        let palette = environment.paletteApp
        let a = palette.couleur(base, nuit: nuit)
        let b: Couleur
        switch autre {
        case .jeton(let jeton): b = palette.couleur(jeton, nuit: nuit)
        case .fixe(let couleur): b = couleur
        }
        return Color(VolCouleurs.melange(a, b, part: part))
    }
}

// MARK: Le cadre de saisie

/// Le cadre des champs et des tuiles (cadreSaisie de VolActivity) : coins de 14, fond `card` mêlé à 25 % de
/// `line`, filet de 1 en `line`.
struct VolCadreSaisie: ViewModifier {
    init() {}

    func body(content: Content) -> some View {
        content
            .background(VolMelange(.card, .jeton(.line), part: 0.25),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Teinte(.line), lineWidth: 1)
            }
    }
}

extension View {
    /// Le cadre de saisie de l'écran du vol.
    func volCadreSaisie() -> some View {
        modifier(VolCadreSaisie())
    }

    /// La place d'une carte dans la colonne (VueJour.carte) : 16 sur les côtés, 12 au-dessus.
    func volPlace() -> some View {
        padding(.horizontal, 16)
            .padding(.top, 12)
    }
}

// MARK: Les fonds

/// Le fond du bandeau (bg_hero.xml) : un dégradé à 225° de l'accent vers le vert sombre (dès 55 %), les coins du
/// bas arrondis de 20, et un filet de lumière de 1 en bas, rentré de 36 de chaque côté.
struct VolFondBandeau: View {
    @Environment(\.paletteApp) private var palette
    @Environment(\.colorScheme) private var schema

    init() {}

    var body: some View {
        let marque = palette.couleur(.brand, schema: schema)
        let sombre = palette.couleur(.brandDark, schema: schema)
        UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20, style: .continuous)
            .fill(LinearGradient(stops: [Gradient.Stop(color: marque, location: 0),
                                         Gradient.Stop(color: sombre, location: 0.55),
                                         Gradient.Stop(color: sombre, location: 1)],
                                 startPoint: .topTrailing, endPoint: .bottomLeading))
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.25), Color.white.opacity(0)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(height: 1)
                    .padding(.horizontal, 36)
            }
            .accessibilityHidden(true)
    }
}

/// Le fond de la carte de la saisie rapide : un dégradé du coin haut gauche au coin bas droit (TL_BR d'Android, qui
/// ne se retourne pas en hébreu), de `card` mêlé à 10 % de `brand` vers `card`, coins de 20, filet de `line` mêlé à
/// 25 % de `brand`.
struct VolFondRapide: View {
    @Environment(\.paletteApp) private var palette
    @Environment(\.colorScheme) private var schema

    init() {}

    var body: some View {
        let nuit = schema == .dark
        let carte = palette.couleur(.card, nuit: nuit)
        let marque = palette.couleur(.brand, nuit: nuit)
        let ligne = palette.couleur(.line, nuit: nuit)
        let forme = RoundedRectangle(cornerRadius: 20, style: .continuous)
        forme
            .fill(LinearGradient(colors: [Color(VolCouleurs.melange(carte, marque, part: 0.1)), Color(carte)],
                                 startPoint: UnitPoint(x: 0, y: 0), endPoint: UnitPoint(x: 1, y: 1)))
            .overlay {
                forme.strokeBorder(Color(VolCouleurs.melange(ligne, marque, part: 0.25)), lineWidth: 1)
            }
    }
}

/// Le ciel de la carte de la prière (VolActivity.cartePriere) : un dégradé du coin haut gauche au coin bas droit,
/// aux couleurs qu'Android écrit en dur ; hors de la fenêtre du calcul, l'accent puis l'accent assombri de 35 %.
/// Coins de 24, légère ombre.
struct VolFondPriere: View {
    let ciel: VolCiel
    @Environment(\.paletteApp) private var palette
    @Environment(\.colorScheme) private var schema

    init(ciel: VolCiel) {
        self.ciel = ciel
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(LinearGradient(colors: couleurs, startPoint: UnitPoint(x: 0, y: 0), endPoint: UnitPoint(x: 1, y: 1)))
            .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
            .accessibilityHidden(true)
    }

    private var couleurs: [Color] {
        switch ciel {
        case .chaharit:
            return [VolCouleurs.fixe(0x2B3F6E), VolCouleurs.fixe(0x8C5A7A), VolCouleurs.fixe(0xE0906B)]
        case .minha:
            return [VolCouleurs.fixe(0x17525A), VolCouleurs.fixe(0x6E7A3E), VolCouleurs.fixe(0xC9962E)]
        case .arvit:
            return [VolCouleurs.fixe(0x0E1530), VolCouleurs.fixe(0x1E2A55), VolCouleurs.fixe(0x3E4F86)]
        case .aucun:
            let marque = palette.couleur(.brand, nuit: schema == .dark)
            return [Color(marque), Color(VolCouleurs.melange(marque, .noir, part: 0.35))]
        }
    }
}

// MARK: Le volet et le lien

/// Un volet replié (depliant de VolActivity) : une rangée touchable d'au moins 44 de haut, le titre en gras puis
/// le chevron, qui pointe vers le bas fermé et vers le haut ouvert ; ouvert, le contenu suit. Le chevron tourne en
/// 180 ms, sans animation si « Réduire les animations » est allumé.
struct VolVoletVue<Contenu: View>: View {
    private let titre: Text
    private let ouvert: Bool
    private let couleur: Jeton
    private let basculer: @MainActor () -> Void
    private let contenu: Contenu
    @Environment(\.accessibilityReduceMotion) private var reduireAnimations

    init(titre: Text, ouvert: Bool, couleur: Jeton = .brand, basculer: @escaping @MainActor () -> Void,
         @ViewBuilder contenu: () -> Contenu) {
        self.titre = titre
        self.ouvert = ouvert
        self.couleur = couleur
        self.basculer = basculer
        self.contenu = contenu()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: basculer) {
                HStack(spacing: 6) {
                    titre
                        .font(Font.subheadline.bold())
                        .foregroundStyle(Teinte(couleur))
                        .multilineTextAlignment(.leading)
                    Image(systemName: "chevron.down")
                        .font(Font.footnote.weight(.semibold))
                        .foregroundStyle(Teinte(couleur))
                        .frame(width: 18, height: 18)
                        .rotationEffect(.degrees(ouvert ? -180 : 0))
                        .animation(reduireAnimations ? nil : .easeInOut(duration: 0.18), value: ouvert)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if ouvert {
                contenu
            }
        }
    }
}

/// Un lien (Bouton.Lien) : le texte seul, medium, 44 de haut au moins pour le doigt.
struct VolLien: View {
    private let texte: Text
    private let couleur: Jeton
    private let action: @MainActor () -> Void

    init(texte: Text, couleur: Jeton = .brand, action: @escaping @MainActor () -> Void) {
        self.texte = texte
        self.couleur = couleur
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            texte
                .font(Font.subheadline.weight(.medium))
                .foregroundStyle(Teinte(couleur))
                .multilineTextAlignment(.center)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: Les icônes

/// Les icônes d'Android (res/drawable) en symboles du système.
enum VolIcones {
    /// L'icône d'un point de la frise (`VolCielFrise.icone`).
    static func frise(_ nom: String) -> String {
        switch nom {
        case "ic_frise_nuit": return "moon.stars.fill"
        case "ic_frise_aube": return "sunrise.fill"
        case "ic_frise_jour": return "sun.max.fill"
        case "ic_frise_crepuscule": return "sunset.fill"
        case "ic_frise_avion": return "airplane"
        default: return "circle.fill"
        }
    }

    /// ic_billet.
    static let billet = "ticket"
    /// ic_loupe.
    static let loupe = "magnifyingglass"
}
