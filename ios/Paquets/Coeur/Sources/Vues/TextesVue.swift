import Foundation
import SwiftUI
import Coeur
import Ecrans

/// Les Livres (refonte d'Android du 13/11, le panneau texts_scroll d'activity_main.xml) : le titre, la recherche,
/// « Reprendre » le dernier texte lu, les favoris et la ligne des marque-pages, puis trois rayons de couvertures —
/// prier (siddour, Tehilim, Tikoun, Tefilot), étudier (sources, livres, halakha), se renforcer ('hizouk, conseils) —
/// avec, sous le premier, où en sont le Tikoun et les Tehilim du jour.
///
/// La vue lit `TextesModele` (testé sous Linux) et rend chaque écran demandé par `ouvrir`, que la pile de l'onglet
/// (ios/App) relie à son modèle.
public struct TextesVue: View {
    private let modele: TextesModele
    private let ouvrir: @MainActor (TextesRoute) -> Void
    @Environment(\.traducteur) private var traducteur
    @Environment(\.scenePhase) private var phase

    public init(modele: TextesModele, ouvrir: @escaping @MainActor (TextesRoute) -> Void) {
        self.modele = modele
        self.ouvrir = ouvrir
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(modele.titre, traducteur: traducteur)
                    .tailleSp(24, poids: .bold, relativeA: .title2)
                    .foregroundStyle(Teinte(.ink))
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 16)
                recherche
                ForEach(modele.reprise) { ligne in
                    TextesRepriseVue(ligne: ligne, police: modele.police) { ouvrir(ligne.route) }
                }
                ForEach(modele.rayons) { rayon in
                    TextesRayonVue(rayon: rayon, ouvrir: ouvrir)
                }
                if let relecture = modele.ligneRelecture {
                    Button {
                        ouvrir(relecture.route)
                    } label: {
                        LigneSection(titre: Text(relecture.titre, traducteur: traducteur))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Teinte(.paper))
        .toolbar(.hidden, for: .navigationBar)
        .task { await modele.actualiser() }
        .onChange(of: phase) { _, nouvelle in
            if nouvelle == .active { Task { await modele.actualiser() } }
        }
    }

    /// Le bouton à contour de la recherche, toute la largeur, le texte au début.
    private var recherche: some View {
        Button {
            ouvrir(modele.routeRecherche)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .accessibilityHidden(true)
                Text(modele.recherche, traducteur: traducteur)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.subheadline)
            .foregroundStyle(Teinte(.muted))
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .overlay {
                Capsule().strokeBorder(Teinte(.line), lineWidth: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
    }
}

/// Une ligne de « Reprendre », des favoris ou des marque-pages (RepriseFavoris.ligne) : l'en-tête au-dessus, le titre
/// hébreu dans la police choisie, « › ».
private struct TextesRepriseVue: View {
    let ligne: TextesRepriseLigne
    let police: PoliceHebraique.Police
    let action: @MainActor () -> Void
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let entete = ligne.entete {
                Text(entete, traducteur: traducteur)
                    .font(Font.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .kerning(0.7)
                    .foregroundStyle(Teinte(.brand))
                    .padding(.top, 14)
            }
            Button(action: action) {
                HStack(spacing: 10) {
                    titre
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let icone = ligne.icone {
                        Illustration(decorative: icone, hauteur: 18)
                            .frame(width: 18, height: 18)
                    }
                    Image(systemName: "chevron.forward")
                        .font(Font.subheadline.weight(.semibold))
                        .foregroundStyle(Teinte(.brand))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var titre: some View {
        switch ligne.titre {
        case .hebreu(let hebreu):
            Text(verbatim: hebreu)
                .policeHebraique(police, taille: 19)
                .foregroundStyle(Teinte(.ink))
                .lineLimit(2)
                .environment(\.layoutDirection, .rightToLeft)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .libelle(let libelle):
            HStack(spacing: 6) {
                Text(libelle, traducteur: traducteur)
                if let nombre = ligne.nombre {
                    Text(verbatim: "· \(nombre)")
                        .monospacedDigit()
                }
            }
            .font(.body)
            .foregroundStyle(Teinte(.ink))
        }
    }
}

/// Un rayon : son titre, quatre places de même largeur (les vides gardent la leur), l'étagère, puis ses états.
private struct TextesRayonVue: View {
    let rayon: TextesRayon
    let ouvrir: @MainActor (TextesRoute) -> Void
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(rayon.titre, traducteur: traducteur)
                .tailleSp(18, poids: .bold, relativeA: .headline)
                .foregroundStyle(Teinte(.ink))
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 20)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(rayon.couvertures) { couverture in
                    TextesCouvertureVue(couverture: couverture) { ouvrir(couverture.route) }
                }
                ForEach(0..<max(TextesRayon.places - rayon.couvertures.count, 0), id: \.self) { _ in
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 124)
                        .accessibilityHidden(true)
                }
            }
            .padding(.top, 10)
            // L'étagère (bg_etagere) : le bois sous les livres.
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Teinte(.line))
                .frame(height: 6)
                .accessibilityHidden(true)
            ForEach(Array(rayon.etats.enumerated()), id: \.offset) { _, etat in
                Text(etat, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
                    .lineLimit(2)
                    .padding(.top, 8)
            }
        }
    }
}

/// Une couverture (style Couverture, drawable/couv_*.xml) : le plat et le dos au bord de départ, le titre hébreu en
/// Frank Ruhl de droite à gauche (que la lecture d'écran passe), le nom de l'écran dessous.
private struct TextesCouvertureVue: View {
    let couverture: TextesCouverture
    let action: @MainActor () -> Void
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        let encre = Color(couverture.couleur.encre)
        Button(action: action) {
            VStack(spacing: 4) {
                Text(couverture.titre, traducteur: traducteur)
                    .font(.hebreu(.frank, taille: 20))
                    .minimumScaleFactor(0.55)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .environment(\.layoutDirection, .rightToLeft)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)
                Text(couverture.libelle, traducteur: traducteur)
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .foregroundStyle(encre)
            .padding(.leading, 10)
            .padding(.trailing, 4)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 124)
            .background {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(couverture.couleur.plat))
                    UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 8, style: .continuous)
                        .fill(Color(couverture.couleur.dos))
                        .frame(width: 6)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(TextesToucher())
        .accessibilityLabel(Text(couverture.libelle, traducteur: traducteur))
    }
}

/// Le toucher d'une couverture : elle pâlit un peu (selectableItemBackground), sans sauter.
private struct TextesToucher: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
