import Foundation
import SwiftUI
import Coeur
import Ecrans

// Les effets des trophées (AnimationsTrophees.kt et Confettis.kt) : le retournement d'un trophée neuf puis le
// reflet qui le traverse (A), les étincelles du métal (E) et les confettis d'une fête. Aucun ne joue avec
// « Réduire les animations » (`ValueAnimator.areAnimatorsEnabled()` d'Android) : tout est alors à sa place, sans
// étincelle ni confetti. Tous sont décoratifs : VoiceOver les passe, et ils ne prennent aucun toucher.

// MARK: Le retournement (A)

/// L'objet d'un trophée qui peut se retourner : après `retard` ms, il tourne en Y de −180° à 0° en 0,65 s
/// (décélération), puis un reflet le traverse en 0,7 s ; s'il y a des `etincelles`, elles jaillissent à la fin
/// du retournement (AnimationsTrophees.retourner, puis etincelles). Sans `retard`, c'est l'objet seul.
struct TropheeRetournement: View {
    let dessin: TropheeDessin?
    let cote: CGFloat
    let retard: Int?
    let etincelles: TropheeTeintes?

    @Environment(\.accessibilityReduceMotion) private var reduire
    @State private var angle: Double
    @State private var reflet: Double = 0
    @State private var eclat = false

    init(dessin: TropheeDessin?, cote: CGFloat, retard: Int?, etincelles: TropheeTeintes? = nil) {
        self.dessin = dessin
        self.cote = cote
        self.retard = retard
        self.etincelles = etincelles
        _angle = State(initialValue: retard == nil ? 0 : -180)
    }

    var body: some View {
        TropheeObjet(dessin)
            .frame(width: cote, height: cote)
            .overlay {
                if retard != nil && !reduire {
                    TropheeReflet(cote: cote, position: reflet)
                }
            }
            .rotation3DEffect(.degrees(reduire ? 0 : angle), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            .overlay {
                if eclat, let etincelles, !reduire {
                    TropheeEtincelles(teintes: etincelles)
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .task {
                await jouer()
            }
    }

    private func jouer() async {
        guard let retard, !reduire else { return }
        guard await TropheeAttente.ms(retard) else { return }
        // DecelerateInterpolator(1,6) d'Android.
        withAnimation(.timingCurve(0.15, 0.7, 0.3, 1, duration: 0.65)) {
            angle = 0
        }
        guard await TropheeAttente.ms(650) else { return }
        withAnimation(.easeInOut(duration: 0.7)) {
            reflet = 1
        }
        if etincelles != nil {
            eclat = true
        }
    }
}

/// Le reflet (AnimationsTrophees.Reflet) : une bande claire en biais, blanche à 75 % en son milieu, découpée dans
/// le cercle de l'objet. `position` va de 0 (la bande à gauche, hors de l'objet) à 1 (passée à droite) ; elle
/// suit Android : le milieu de la bande en x = −côté + position × 3 côtés, le dégradé de (x − 0,3 côté, haut) à
/// (x + 0,3 côté, bas).
struct TropheeReflet: View {
    let cote: CGFloat
    let position: Double

    var body: some View {
        // Une bande de cinq côtés de large, son milieu en son centre : assez pour couvrir l'objet à toute position.
        Rectangle()
            .fill(LinearGradient(stops: [
                Gradient.Stop(color: Color.white.opacity(0), location: 0),
                Gradient.Stop(color: Color.white.opacity(0.75), location: 0.5),
                Gradient.Stop(color: Color.white.opacity(0), location: 1),
            ], startPoint: UnitPoint(x: 0.44, y: 0), endPoint: UnitPoint(x: 0.56, y: 1)))
            .frame(width: cote * 5, height: cote)
            .offset(x: cote * 3 * CGFloat(position) - cote * 1.5)
            .frame(width: cote, height: cote)
            .clipShape(Circle())
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: Les étincelles (E)

/// Une dizaine d'étincelles du métal autour du centre de la vue qui les porte, en 1,1 s
/// (AnimationsTrophees.Etincelles) : chacune part du centre vers sa place (de 38 à 64 points), paraît puis
/// s'efface ; une sur deux du ton foncé, l'autre du ton clair. À poser en `overlay`, centrée sur l'objet.
struct TropheeEtincelles: View {
    let teintes: TropheeTeintes

    @State private var debut = Date()
    @State private var points = TropheeEtincelle.tirer()
    @State private var fini = false

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: fini)) { contexte in
            Canvas { c, taille in
                peindre(c, taille, t: contexte.date.timeIntervalSince(debut) / 1.1)
            }
        }
        .frame(width: 160, height: 160)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            if await TropheeAttente.ms(1150) {
                fini = true
            }
        }
    }

    private func peindre(_ c: GraphicsContext, _ taille: CGSize, t: Double) {
        let cx = taille.width / 2
        let cy = taille.height / 2
        for point in points {
            let u = min(max((t - point.retard) / 0.8, 0), 1)
            if u <= 0 || u >= 1 { continue }
            let e = 1 - (1 - u) * (1 - u)
            let opacite = u < 0.25 ? u / 0.25 : (1 - u) / 0.75
            let rayon = 3.5 * (0.4 + 0.6 * e)
            let x = cx + CGFloat(point.dx * e)
            let y = cy + CGFloat(point.dy * e)
            let couleur = point.fonce ? teintes.fonce : teintes.clair
            c.fill(Path(ellipseIn: CGRect(x: x - rayon, y: y - rayon, width: rayon * 2, height: rayon * 2)),
                   with: .color(couleur.couleurSwiftUI.opacity(opacite)))
        }
    }
}

/// Une étincelle tirée au hasard, comme Android (angle régulier un peu bousculé, distance de 38 à 64).
struct TropheeEtincelle {
    let dx: Double
    let dy: Double
    let fonce: Bool
    let retard: Double

    static func tirer() -> [TropheeEtincelle] {
        (0..<10).map { k in
            let a = Double(k) / 10 * 2 * Double.pi + Double.random(in: 0..<0.4)
            let r = 38 + Double.random(in: 0..<26)
            return TropheeEtincelle(dx: cos(a) * r, dy: sin(a) * r, fonce: k % 2 == 0,
                                    retard: Double.random(in: 0..<0.2))
        }
    }
}

// MARK: Les confettis

/// La pluie de confettis d'une fête (Confettis.Vue) : 140 pièces de six couleurs, rectangles et ronds, qui
/// tombent en tournant sur toute la vue en 2,8 s, puis s'effacent. Les couleurs sont celles qu'Android écrit en
/// dur.
struct TropheeConfettis: View {
    @State private var debut = Date()
    @State private var pieces = TropheeConfetti.tirer()
    @State private var fini = false

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: fini)) { contexte in
            Canvas { c, taille in
                peindre(c, taille, t: contexte.date.timeIntervalSince(debut) / 2.8)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            if await TropheeAttente.ms(2850) {
                fini = true
            }
        }
    }

    private func peindre(_ c: GraphicsContext, _ taille: CGSize, t: Double) {
        for piece in pieces {
            let u = min(max((t - piece.retard) / (1 - piece.retard), 0), 1)
            if u <= 0 || u >= 1 { continue }
            let x = CGFloat(piece.x + piece.vx * u) * taille.width
            let y = CGFloat(-0.05 + piece.vy * u + 0.6 * u * u) * taille.height
            let opacite = min((1 - u) * 2, 1)
            var p = c
            p.translateBy(x: x, y: y)
            p.rotate(by: .degrees(piece.tour * u))
            let s = CGFloat(piece.taille)
            let forme = piece.rond
                ? Path(ellipseIn: CGRect(x: -s / 2, y: -s / 2, width: s, height: s))
                : Path(CGRect(x: -s / 2, y: -s / 4, width: s, height: s / 2))
            p.fill(forme, with: .color(TropheeConfetti.couleurs[piece.couleur].opacity(opacite)))
        }
    }
}

/// Une pièce de confetti tirée au hasard (Confettis.Piece).
struct TropheeConfetti {
    let x: Double
    let vx: Double
    let vy: Double
    let tour: Double
    let taille: Double
    let couleur: Int
    let rond: Bool
    let retard: Double

    /// Confettis.COULEURS.
    static let couleurs: [Color] = [
        TropheeCouleur(0xC9, 0x9A, 0x2E).couleurSwiftUI, TropheeCouleur(0x1F, 0x6F, 0x5C).couleurSwiftUI,
        TropheeCouleur(0xE0, 0x5A, 0x47).couleurSwiftUI, TropheeCouleur(0x3B, 0x6E, 0xC4).couleurSwiftUI,
        TropheeCouleur(0xF2, 0xC9, 0x4C).couleurSwiftUI, TropheeCouleur(0x8E, 0x4F, 0xB5).couleurSwiftUI,
    ]

    static func tirer() -> [TropheeConfetti] {
        (0..<140).map { _ in
            TropheeConfetti(x: Double.random(in: 0..<1),
                            vx: (Double.random(in: 0..<1) - 0.5) * 0.25,
                            vy: 0.55 + Double.random(in: 0..<0.6),
                            tour: (Double.random(in: 0..<1) - 0.5) * 1440,
                            taille: 6 + Double.random(in: 0..<8),
                            couleur: Int.random(in: 0..<couleurs.count),
                            rond: Int.random(in: 0..<4) == 0,
                            retard: Double.random(in: 0..<0.35))
        }
    }
}
