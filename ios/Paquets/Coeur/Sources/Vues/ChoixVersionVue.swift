import Foundation
import SwiftUI
import Coeur
import Ecrans

/// « Version de l'app » (ChoixVersionActivity.kt) : le titre, le détail, une carte par version (l'aperçu de ses trois
/// couleurs, son nom, ce qu'elle est, « ✓ » et « version actuelle » sur la choisie), le pied. Une carte touchée retient
/// la version et ferme l'écran : la racine montre aussitôt son accueil. Revenir sans choisir, au premier lancement,
/// garde Classique (`fermerSansChoisir`).
public struct ChoixVersionVue: View {
    private let modele: ChoixVersionModele
    @Environment(\.traducteur) private var traducteur
    @Environment(\.dismiss) private var fermer

    public init(modele: ChoixVersionModele) {
        self.modele = modele
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(modele.detail, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.muted))
                ForEach(modele.cartes) { carte in
                    Button {
                        let version = carte.version
                        Task { try? await modele.choisir(version) }
                    } label: {
                        ChoixVersionCarteVue(carte: carte, actuelle: modele.actuelle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: accessibilite(carte)))
                    .accessibilityAddTraits(carte.choisie ? [.isButton, .isSelected] : .isButton)
                }
                Text(modele.pied, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Teinte(.paper))
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: modele.ferme) { _, ferme in
            if ferme { fermer() }
        }
        .onDisappear {
            // Le retour sans choix (handleOnBackPressed) : au premier lancement, Classique, et la question ne revient pas.
            if !modele.ferme { Task { try? await modele.fermerSansChoisir() } }
        }
    }

    /// « Bento. Un tableau de tuiles… . version actuelle » (contentDescription d'Android).
    private func accessibilite(_ carte: ChoixVersionCarte) -> String {
        var texte = traducteur.texte(carte.nom) + ". " + traducteur.texte(carte.description)
        if carte.choisie { texte += ". " + traducteur.texte(modele.actuelle) }
        return texte
    }
}

/// Une carte de version : l'aperçu (le fond de la version, une carte, son accent), le nom et la description.
private struct ChoixVersionCarteVue: View {
    let carte: ChoixVersionCarte
    let actuelle: Libelle
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            apercu
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: traducteur.texte(carte.nom) + (carte.choisie ? "  ✓" : ""))
                    .tailleSp(19, poids: .bold, relativeA: .title3)
                    .foregroundStyle(carte.choisie ? AnyShapeStyle(Teinte(.brand)) : AnyShapeStyle(Teinte(.ink)))
                Text(carte.description, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.muted))
                    .fixedSize(horizontal: false, vertical: true)
                if carte.choisie {
                    Text(actuelle, traducteur: traducteur)
                        .font(Font.caption.weight(.semibold))
                        .foregroundStyle(Teinte(.brand))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
        .padding(.leading, 14)
        .padding(.trailing, 16)
        .background(Teinte(.card), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(carte.choisie ? AnyShapeStyle(Teinte(.brand)) : AnyShapeStyle(Teinte(.line)),
                              lineWidth: carte.choisie ? 2 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// 64 × 88 : le fond, une carte de 48 × 52 en haut, l'accent de 36 × 10 en bas.
    private var apercu: some View {
        let c = carte.apercu
        return RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(VersionCouleur.argb(c.count > 0 ? c[0] : 0xFF000000))
            .frame(width: 64, height: 88)
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(VersionCouleur.argb(c.count > 1 ? c[1] : 0xFF000000))
                    .frame(width: 48, height: 52)
                    .padding(.top, 10)
            }
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(VersionCouleur.argb(c.count > 2 ? c[2] : 0xFF000000))
                    .frame(width: 36, height: 10)
                    .padding(.bottom, 10)
            }
            .accessibilityHidden(true)
    }
}
