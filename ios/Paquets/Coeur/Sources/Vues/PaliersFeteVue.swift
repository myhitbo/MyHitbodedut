import Foundation
import SwiftUI
import Coeur
import Ecrans

// La fête d'un nouveau grade (PaliersActivity.fete, animation C), une fois : des rayons lents derrière la
// médaille, qui passe de l'ancien métal au nouveau, puis les étincelles du nouveau métal. Le dialogue de Material
// d'Android (MaterialAlertDialogBuilder, un bouton positif) : ici une carte au milieu d'un voile, sur une
// couverture plein écran transparente ; un toucher hors de la carte la ferme aussi, comme le dialogue d'Android.

/// Le dialogue de la fête. `fermer` remet `PaliersModele.feteGrade` à nil.
struct PaliersFeteGradeVue: View {
    let fete: PaliersFeteGrade
    let formes: TropheeFormes
    let fermer: @MainActor () -> Void

    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var reduire
    /// Les rayons paraissent (opacité 0 → 1, échelle 0,6 → 1) en 1,5 s.
    @State private var rayonsParus = false
    /// Puis ils tournent, un tour en 12 s, sans fin.
    @State private var tour: Double = 0
    /// L'ancienne médaille s'efface, la nouvelle paraît (après 0,3 s, en 1,2 s).
    @State private var passage = false
    /// Les étincelles du nouveau métal, à 1,5 s.
    @State private var etincelles = false

    init(fete: PaliersFeteGrade, formes: TropheeFormes, fermer: @escaping @MainActor () -> Void) {
        self.fete = fete
        self.formes = formes
        self.fermer = fermer
    }

    var body: some View {
        ZStack {
            // Le voile d'un dialogue de Material (scrim à 32 %).
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    fermer()
                }
                .accessibilityHidden(true)
            carte
                .frame(maxWidth: 360)
                .padding(.horizontal, 24)
        }
        .accessibilityAction(.escape) {
            fermer()
        }
        .task {
            await jouer()
        }
    }

    private var carte: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                scene
                Text(fete.titre, traducteur: traducteur)
                    .tropheeTexte(24, gras: true)
                    .foregroundStyle(Teinte(.ink))
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 4)
                Text(fete.sous, traducteur: traducteur)
                    .tropheeTexte(15)
                    .foregroundStyle(Teinte(.muted))
                    .padding(.top, 4)
                if let prochain = fete.prochain {
                    Text(prochain, traducteur: traducteur)
                        .tropheeTexte(13)
                        .foregroundStyle(Teinte(.muted))
                        .padding(.top, 4)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 8)
            Button {
                fermer()
            } label: {
                Text(fete.bouton, traducteur: traducteur)
                    .tropheeTexte(14, gras: true)
                    .foregroundStyle(Teinte(.brand))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(Teinte(.card), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    /// Le cadre de 260 × 220, sans rognage : les rayons de 260, l'ancienne médaille, la nouvelle.
    private var scene: some View {
        ZStack {
            PaliersRayons(couleur: fete.rayons.couleurSwiftUI)
                .frame(width: 260, height: 260)
                .rotationEffect(.degrees(reduire ? 0 : tour))
                .animation(reduire ? nil : .linear(duration: 12).repeatForever(autoreverses: false), value: tour)
                .opacity(reduire || rayonsParus ? 1 : 0)
                .scaleEffect(reduire || rayonsParus ? 1 : 0.6)
                .animation(reduire ? nil : .easeInOut(duration: 1.5), value: rayonsParus)
            TropheeObjet(formes.medaille(fete.ancien))
                .frame(width: 140, height: 140)
                .opacity(reduire || passage ? 0 : 1)
                .scaleEffect(!reduire && passage ? 0.85 : 1)
            TropheeObjet(formes.medaille(fete.nouveau))
                .frame(width: 140, height: 140)
                .opacity(reduire || passage ? 1 : 0)
                .scaleEffect(reduire || passage ? 1 : 1.15)
                .overlay {
                    if etincelles && !reduire {
                        TropheeEtincelles(teintes: TropheeTeintes.de(fete.nouveau))
                    }
                }
        }
        .frame(width: 260, height: 220)
        .accessibilityHidden(true)
    }

    private func jouer() async {
        guard !reduire else { return }
        rayonsParus = true
        tour = 360
        guard await TropheeAttente.ms(300) else { return }
        withAnimation(.easeInOut(duration: 1.2)) {
            passage = true
        }
        guard await TropheeAttente.ms(1200) else { return }
        etincelles = true
    }
}

/// Les rayons (AnimationsTrophees.Rayons) : vingt secteurs de 6°, un tous les 18°, dans le cercle de la vue, en
/// dégradé radial de la couleur (pleine jusqu'à 35 % du rayon) vers le transparent.
struct PaliersRayons: View {
    let couleur: Color

    var body: some View {
        Canvas { c, taille in
            peindre(c, taille)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func peindre(_ c: GraphicsContext, _ taille: CGSize) {
        let r = min(taille.width, taille.height) / 2
        guard r > 0 else { return }
        let centre = CGPoint(x: taille.width / 2, y: taille.height / 2)
        var secteurs = Path()
        for k in 0..<20 {
            secteurs.move(to: centre)
            secteurs.addRelativeArc(center: centre, radius: r, startAngle: .degrees(Double(k) * 18), delta: .degrees(6))
            secteurs.closeSubpath()
        }
        let degrade = Gradient(stops: [
            Gradient.Stop(color: couleur, location: 0),
            Gradient.Stop(color: couleur, location: 0.35),
            Gradient.Stop(color: couleur.opacity(0), location: 1),
        ])
        c.fill(secteurs, with: .radialGradient(AnyGradient(degrade), center: centre, startRadius: 0, endRadius: r))
    }
}
