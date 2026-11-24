import Foundation
import SwiftUI
import Coeur
import Ecrans

// La fiche d'un trophée (FicheTrophee.kt, 16/10 point 1, 19/10) : l'objet, ce qu'il demande, le jour gagné ou la
// progression. L'écran des paliers l'ouvre d'un toucher (`PaliersModele.fiche`) ; l'accueil, de lui-même pour
// chaque trophée neuf (`TropheeFeteModele.ficheCourante`), avec confettis, étincelles et vibration. Sur Android,
// une fenêtre plein écran transparente, pour que les confettis passent par-dessus la carte et le voile : ici une
// couverture plein écran au fond transparent (`tropheeFiche(_:formes:fermer:)`).

extension View {
    /// Présente la fiche quand `fiche` existe : une couverture plein écran transparente, un voile noir à 60 %, la
    /// carte au milieu. Un toucher sur le voile ou « Continuer » appelle `fermer`, qui remet la fiche à nil dans le
    /// modèle (`PaliersModele.fermerFiche`, `TropheeFeteModele.fermerFiche`). Pour qu'elle paraisse et parte d'un
    /// coup, comme un dialogue d'Android, et non en glissant du bas, changer la fiche du modèle dans
    /// `TropheeTransaction.sansAnimation { … }`.
    public func tropheeFiche(_ fiche: TropheeFiche?, formes: TropheeFormes,
                             fermer: @escaping @MainActor () -> Void) -> some View {
        fullScreenCover(item: Binding(get: { @MainActor in fiche },
                                      set: { @MainActor nouvelle in
                                          if nouvelle == nil { fermer() }
                                      })) { montree in
            TropheeFicheVue(fiche: montree, formes: formes, fermer: fermer)
                .presentationBackground(.clear)
        }
    }
}

/// La fiche plein écran : le voile, la carte centrée, et pour une fête les confettis par-dessus tout.
public struct TropheeFicheVue: View {
    private let fiche: TropheeFiche
    private let formes: TropheeFormes
    private let fermer: @MainActor () -> Void

    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var reduire
    /// Les étincelles du métal, 0,7 s après l'ouverture d'une fête.
    @State private var etincelles = false
    /// La pluie de confettis d'une fête, le temps qu'elle tombe.
    @State private var pluie = false
    /// La vibration longue d'une fête (`HapticFeedbackConstants.LONG_PRESS`).
    @State private var vibration = false

    public init(fiche: TropheeFiche, formes: TropheeFormes, fermer: @escaping @MainActor () -> Void) {
        self.fiche = fiche
        self.formes = formes
        self.fermer = fermer
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    fermer()
                }
                .accessibilityHidden(true)
            carte
                .frame(maxWidth: 360)
                .padding(.horizontal, 24)
            if pluie {
                TropheeConfettis()
                    .ignoresSafeArea()
            }
        }
        .accessibilityAction(.escape) {
            fermer()
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: vibration)
        .task {
            await feter()
        }
    }

    // MARK: La carte

    private var carte: some View {
        VStack(spacing: 0) {
            TropheeRetournement(dessin: formes.dessin(fiche.niveau, metal: fiche.metal), cote: 120,
                                retard: fiche.retourner ? TropheeFiche.retardRetournement : nil)
                .overlay {
                    if etincelles {
                        TropheeEtincelles(teintes: TropheeTeintes.de(fiche.metal ?? .or))
                    }
                }
            VStack(spacing: 0) {
                Text(fiche.titre, traducteur: traducteur)
                    .tropheeTexte(20, gras: true)
                    .foregroundStyle(Teinte(.ink))
                    .padding(.top, 12)
                Text(verbatim: traducteur.texte(fiche.nom) + " · " + traducteur.texte(fiche.niveauCourt))
                    .tropheeTexte(14)
                    .foregroundStyle(Teinte(.muted))
                    .padding(.top, 4)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(TropheeAccessibilite.texte(fiche.accessibilite, traducteur))
            .accessibilityAddTraits(.isHeader)
            etat
            Button {
                fermer()
            } label: {
                Text(TropheeFiche.bouton, traducteur: traducteur)
                    .tropheeTexte(14, gras: true)
                    .foregroundStyle(Teinte(.brand))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, 16)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 8)
        // colorSurfaceContainerHigh de Material : le jeton « card », qui suit le mode de l'écran.
        .background(Teinte(.card), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    /// Gagné : le jour et le grade d'alors ; à gagner : la barre et ce qu'il reste.
    @ViewBuilder private var etat: some View {
        switch fiche.etat {
        case .gagne(let sous, let grade):
            Text(sous.libelle(dateLongue: { TropheeDate.longue($0, langue: traducteur.langue) }), traducteur: traducteur)
                .tropheeTexte(15, gras: true)
                .foregroundStyle(Teinte(.brand))
                .padding(.top, 8)
            Text(grade, traducteur: traducteur)
                .tropheeTexte(13)
                .foregroundStyle(Teinte(.muted))
                .padding(.top, 4)
        case .aGagner(let fraction, let encore):
            TropheeBarre(fraction: Double(fraction), hauteur: 10, couleur: Teinte(.brand), monte: false)
                .padding(.top, 12)
            Text(encore, traducteur: traducteur)
                .tropheeTexte(14, gras: true)
                .foregroundStyle(Teinte(.brand))
                .padding(.top, 4)
        }
    }

    // MARK: La fête

    /// Une fête (et seulement si les animations sont permises) : confettis tout de suite, vibration longue, puis
    /// les étincelles du métal à 0,7 s ; les confettis se retirent une fois tombés.
    private func feter() async {
        guard fiche.confettis, !reduire else { return }
        pluie = true
        vibration = true
        guard await TropheeAttente.ms(TropheeFiche.retardEtincelles) else { return }
        etincelles = true
        guard await TropheeAttente.ms(2900 - TropheeFiche.retardEtincelles) else { return }
        pluie = false
    }
}
