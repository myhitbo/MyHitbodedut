import Foundation
import SwiftUI
import Coeur
import Ecrans

// La fête des trophées neufs, à l'accueil (Celebrations.ecran, FicheTrophee.feter ; 16/10 et 19/10). Le modèle
// (`TropheeFeteModele`, testé sous Linux) dit ce qui est neuf ; ici, ce qui se voit :
//
// - un trophée neuf ouvre sa fiche, 500 ms après l'accueil, dans une fenêtre qui voile tout l'écran (le Dialog plein
//   écran d'Android) : l'objet se retourne, des confettis tombent par-dessus la carte et le voile, des étincelles du
//   métal jaillissent autour de lui, et le téléphone vibre. Plusieurs s'ouvrent l'une après l'autre ;
// - un palier neuf : sa phrase en bandeau bref (le Toast long d'Android) et des étincelles du grade autour de la
//   ligne du grade de l'accueil (AccueilVue).
//
// Avec « Réduire les animations », la fiche s'ouvre sans retournement, sans confettis, sans étincelles ni vibration.

extension View {
    /// La fiche des trophées neufs, posée par la racine par-dessus les onglets (le voile couvre aussi la barre des
    /// onglets et la barre de départ, comme le Dialog d'Android couvre l'activité).
    public func feteDesTrophees(_ fete: TropheeFeteModele) -> some View {
        // Sous une fiche, l'écran voilé sort de l'accessibilité : VoiceOver et l'audit ne lisent que la fiche. Sans
        // fiche, rien n'est posé (`isEnabled`) : un `accessibilityHidden(false)` l'emporterait sur celui des enfants.
        accessibilityHidden(true, isEnabled: fete.ficheCourante != nil)
            .overlay {
                TropheeFeteCouche(fete: fete)
            }
    }
}

/// La couche de la fête : vide tant qu'aucune fiche n'est à montrer.
private struct TropheeFeteCouche: View {
    let fete: TropheeFeteModele
    /// Les fiches attendent 500 ms après l'accueil, le temps qu'il paraisse (`postDelayed(…, 500)`).
    @State private var montree = false

    var body: some View {
        ZStack {
            if montree, let fiche = fete.ficheCourante {
                TropheeFeteFiche(fiche: fiche) {
                    TropheeTransaction.sansAnimation { fete.fermerFiche() }
                }
                // Une fiche, une fête : la suivante rejoue le retournement et les confettis.
                .id(fiche.id)
            }
        }
        .task(id: fete.fiches.isEmpty) {
            guard !fete.fiches.isEmpty else {
                montree = false
                return
            }
            guard await TropheeAttente.ms(TropheeFeteModele.retardFiches) else { return }
            TropheeTransaction.sansAnimation { montree = true }
        }
    }
}

/// La fiche d'un trophée neuf (FicheTrophee.montrer, `feter`) : le voile à 60 %, la carte (360 pt au plus, coins de
/// 28) — l'objet de 120 pt qui se retourne, ce qu'il demande, le nom et le niveau, le jour gagné et le grade,
/// « Continuer » — et les confettis par-dessus. Un toucher hors de la carte la ferme aussi.
private struct TropheeFeteFiche: View {
    let fiche: TropheeFiche
    let fermer: @MainActor () -> Void
    @Environment(\.traducteur) private var traducteur
    @Environment(\.tropheeFormes) private var formes
    @Environment(\.accessibilityReduceMotion) private var reduire
    @State private var vibre = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { fermer() }
                .accessibilityHidden(true)
            carte
                .padding(24)
            if fiche.confettis && !reduire {
                // Les confettis dans la fenêtre de la fiche : par-dessus la carte et le voile.
                TropheeConfettis()
                    .ignoresSafeArea()
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: vibre)
        // Une fiche modale : VoiceOver (et l'audit d'accessibilité) ne voient plus l'écran voilé dessous.
        .accessibilityAddTraits(.isModal)
        .onAppear {
            if fiche.confettis && !reduire { vibre = true }
        }
    }

    private var carte: some View {
        VStack(spacing: 0) {
            TropheeRetournement(dessin: formes?.dessin(fiche.niveau, metal: fiche.metal), cote: 120,
                                retard: fiche.retourner ? TropheeFiche.retardRetournement : nil,
                                etincelles: fiche.confettis ? TropheeTeintes.de(fiche.metal) : nil)
                .frame(width: 120, height: 120)
            Text(fiche.titre, traducteur: traducteur)
                .tropheeTexte(20, gras: true)
                .foregroundStyle(Teinte(.ink))
                .multilineTextAlignment(.center)
                .padding(.top, 12)
            Text(verbatim: traducteur.texte(fiche.nom) + " · " + traducteur.texte(fiche.niveauCourt))
                .tropheeTexte(14)
                .foregroundStyle(Teinte(.muted))
                .multilineTextAlignment(.center)
                .padding(.top, 2)
            switch fiche.etat {
            case .gagne(let sous, let grade):
                Text(sous.libelle { TropheeDate.longue($0, langue: traducteur.langue) }, traducteur: traducteur)
                    .tropheeTexte(15, gras: true)
                    .foregroundStyle(Teinte(.brand))
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                Text(grade, traducteur: traducteur)
                    .tropheeTexte(13)
                    .foregroundStyle(Teinte(.muted))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            case .aGagner(let fraction, let encore):
                TropheeBarre(fraction: Double(fraction), hauteur: 10, couleur: Teinte(.brand), monte: false)
                    .padding(.top, 12)
                Text(encore, traducteur: traducteur)
                    .tropheeTexte(14, gras: true)
                    .foregroundStyle(Teinte(.brand))
                    .padding(.top, 4)
            }
            Button(action: fermer) {
                Text(TropheeFiche.bouton, traducteur: traducteur)
                    .font(Font.subheadline.weight(.semibold))
                    .foregroundStyle(Teinte(.brand))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, 16)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 8)
        .frame(maxWidth: 360)
        .background(Teinte(.card), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { fermer() }
    }
}

// MARK: - Le palier neuf, autour de la ligne du grade

/// Les étincelles d'un palier neuf autour de la ligne du grade (AnimationsTrophees.etincelles, 500 ms après
/// l'accueil) ; à poser en `overlay` de la ligne. Rien avec « Réduire les animations ».
struct TropheeFetePalier: View {
    let fete: TropheeFeteModele
    @Environment(\.accessibilityReduceMotion) private var reduire
    /// La fête en cours (son numéro), le temps des étincelles ; nil : rien.
    @State private var montree: Int? = nil
    /// La dernière fête montrée : un retour sur l'accueil ne la rejoue pas.
    @State private var vue = 0

    var body: some View {
        ZStack {
            if let numero = montree, let metal = fete.etincelles, !reduire {
                TropheeEtincelles(teintes: TropheeTeintes.de(metal))
                    .id(numero)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: fete.fetesPalier) {
            let numero = fete.fetesPalier
            guard numero > vue, !reduire else { return }
            vue = numero
            guard await TropheeAttente.ms(TropheeFeteModele.retardEtincelles) else { return }
            montree = numero
            guard await TropheeAttente.ms(1_200) else { return }
            if montree == numero { montree = nil }
        }
    }
}
