import Foundation
import SwiftUI
import Coeur
import Ecrans

/// L'écran Tfilot (TefilotActivity.kt, sur la mise en page de la bibliothèque, activity_library.xml) : les dix
/// sujets, et sous chacun ses prières de Likoutei Tefilot. Une prière s'ouvre dans l'écran d'une entrée de la
/// bibliothèque (LibraryEntryActivity) : un autre écran de l'app, que `ouvrir` atteint (le câblage de l'app traduit
/// `TefilotRoute.entree(id)` en `BibliothequeRoute.entree(id)`).
public struct TefilotVue: View {
    let modele: TefilotModele
    private let ouvrir: @MainActor (TefilotRoute) -> Void

    @Environment(\.traducteur) private var traducteur

    public init(modele: TefilotModele, ouvrir: @escaping @MainActor (TefilotRoute) -> Void) {
        self.modele = modele
        self.ouvrir = ouvrir
    }

    public var body: some View {
        VStack(spacing: 0) {
            TehilimBandeau(titre: Text(modele.titre, traducteur: traducteur),
                           sousTitre: Text(modele.sousTitre, traducteur: traducteur),
                           image: modele.image, mesure: .tefilot)
            ScrollView {
                liste
                    .padding(.top, 4)
                    .padding(.bottom, 24)
            }
        }
        .background(Teinte(.paper))
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .task { await modele.charger() }
    }

    @ViewBuilder
    private var liste: some View {
        switch modele.etat {
        case .erreur:
            Text("contenu_illisible", tableName: "ios")
                .font(.subheadline)
                .foregroundStyle(Teinte(.muted))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 16)
        case .chargement, .pret:
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(modele.lignes) { ligne in
                    ligneVue(ligne)
                }
            }
        }
    }

    @ViewBuilder
    private func ligneVue(_ ligne: TefilotLigne) -> some View {
        switch ligne.sorte {
        case .sujet:
            sujet(ligne)
        case .priere:
            if let route = ligne.route {
                Button {
                    ouvrir(route)
                } label: {
                    carte(ligne)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            } else {
                carte(ligne)
                    .accessibilityElement(children: .combine)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: Le titre d'un sujet

    /// item_tefila_sujet : le nom du sujet, 19 pt gras, puis le nombre de ses prières, 13 pt discret.
    private func sujet(_ ligne: TefilotLigne) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ligne.sujet, traducteur: traducteur)
                .font(Font.title3.bold())
                .foregroundStyle(Teinte(.ink))
            if let compte = ligne.compte {
                Text(compte, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: La carte d'une prière

    /// item_library_entry : l'illustration dans son cadre (bg_stage_soft), puis le sujet en pastille, le titre hébreu
    /// et, dessous, la référence (et la mise en garde, à la ligne).
    private func carte(_ ligne: TefilotLigne) -> some View {
        HStack(alignment: .center, spacing: 12) {
            if let image = ligne.image {
                Illustration(decorative: image)
                    .padding(4)
                    .frame(width: 56, height: 68)
                    .background(Teinte(.stageSoft), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 0) {
                Etiquette(Text(ligne.sujet, traducteur: traducteur))
                    .padding(.bottom, 4)
                Text(verbatim: ligne.titre ?? "")
                    .font(Font.callout.bold())
                    .foregroundStyle(Teinte(.ink))
                Text(verbatim: detail(ligne))
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
                    .padding(.top, 4)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Teinte(.card), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Teinte(.line), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// La référence, puis la mise en garde à la ligne (un seul TextView sur Android).
    private func detail(_ ligne: TefilotLigne) -> String {
        var morceaux: [String] = []
        if let reference = ligne.reference {
            morceaux.append(reference)
        }
        if let avertissement = ligne.avertissement {
            morceaux.append(traducteur.texte(avertissement))
        }
        return morceaux.joined(separator: "\n")
    }
}
