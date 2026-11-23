import Foundation
import SwiftUI
import Coeur
import Ecrans

/// Le Tikoun HaKlali (TikkunFlowActivity.kt, activity_tikkun_flow.xml) : le texte entier, d'un trait, sans bouton
/// entre les psaumes ; en bas, « J'ai dit le Tikoun en entier », qui ferme l'écran. Le bouton de lecture règle la
/// taille, la nuit, la police et les langues. Pas d'image pendant une prière, pas de sous-titre en tête.
///
/// Tout se lit dans `TikkunModele` ; la vue suit ses demandes de défilement et lui signale l'élément en tête.
public struct TikkunVue: View {
    let modele: TikkunModele

    @Environment(\.traducteur) private var traducteur
    @Environment(\.dismiss) private var fermer
    @ScaledMetric(relativeTo: .body) private var dynamique: CGFloat = 1

    /// La place dans le texte : les demandes de défilement du modèle y passent.
    @State private var position = ScrollPosition(idType: String.self)

    public init(modele: TikkunModele) {
        self.modele = modele
    }

    public var body: some View {
        VStack(spacing: 0) {
            TehilimBandeau(titre: Text(modele.titre, traducteur: traducteur), sousTitre: nil, image: nil)
            texte
            boutonFin
        }
        .background(Teinte(.paper))
        .overlay(alignment: .bottom) {
            if modele.barre.annonceMasque {
                TehilimAnnonceMasque(barre: modele.barre)
            }
        }
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .task { await modele.charger() }
        .onChange(of: modele.termine) { _, fini in
            // `finish()` d'Android : le Tikoun dit, l'écran se ferme.
            if fini { fermer() }
        }
    }

    // MARK: Les mesures

    private var rendu: TehilimRendu {
        TehilimRendu(sombre: modele.barre.sombre)
    }

    private var echelle: CGFloat {
        CGFloat(modele.barre.echelle) * dynamique
    }

    private var police: PoliceHebraique.Police {
        modele.barre.police
    }

    // MARK: Le texte

    private var texte: some View {
        ScrollView {
            contenu
                .padding(.top, 12)
                // 16 sous le texte ; la barre de lecture est dessous (boutonsDeLecture).
                .padding(.bottom, 16)
        }
        .scrollPosition($position, anchor: .top)
        .defilementAutomatique(modele.barre.defilementAuto, position: $position)
        .scrollIndicators(.visible)
        .background(rendu.fond)
        .onScrollTargetVisibilityChange(idType: String.self) { visibles in
            if let premier = visibles.first {
                modele.teteVisible(premier)
            }
        }
        .onScrollGeometryChange(for: Double.self, of: { geometrie in
            Double(geometrie.contentOffset.y)
        }, action: { ancien, nouveau in
            modele.barre.defilementVertical(nouveau - ancien)
        })
        .onChange(of: modele.defilement) { _, demande in
            guard let demande else { return }
            if let cible = demande.cible {
                position.scrollTo(id: cible, anchor: .top)
            } else {
                position.scrollTo(edge: .top)
            }
        }
        // La barre de lecture sous le texte, jamais sur une ligne.
        .boutonsDeLecture(fond: rendu.fond, visibles: (modele.barre.pastilleVisible && !modele.barre.pastilleEffacee)
                          || modele.barre.barreVisible || modele.barre.defilementAuto.commandeVisible) {
            TehilimBarreVue(barre: modele.barre)
        }
    }

    @ViewBuilder
    private var contenu: some View {
        switch modele.etat {
        case .erreur:
            Text("contenu_illisible", tableName: "ios")
                .font(.subheadline)
                .foregroundStyle(rendu.discret)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
        case .chargement, .pret:
            VStack(alignment: .leading, spacing: 0) {
                ForEach(modele.elements) { element in
                    elementVue(element)
                        .padding(.horizontal, 16)
                        .gestesTehilim(modele.barre)
                        .id(element.id)
                }
            }
            .scrollTargetLayout()
        }
    }

    @ViewBuilder
    private func elementVue(_ element: TikkunElement) -> some View {
        switch element.sorte {
        case .titre(let titre, let premier):
            titreVue(titre, premier: premier)
        case .verset(let texte):
            hebreu(texte, taille: 19, interligne: 13, style: rendu.texte)
                .padding(.top, 12)
        case .arret(let texte):
            hebreu(texte, taille: 15, interligne: 4, style: rendu.discret)
                .padding(.top, 12)
        case .paragraphe(let texte, let centre):
            hebreu(texte, taille: 18, interligne: 13, style: rendu.texte, centre: centre)
                .padding(.top, 12)
        case .note(let texte):
            note(texte)
        case .traduction(let texte, _, let seule, let base, let margeHaut):
            traduction(texte, seule: seule, base: base)
                .padding(.top, CGFloat(margeHaut))
        }
    }

    /// Le nom d'une partie ou d'un psaume : 20 pt gras, couleur des titres, de droite à gauche.
    private func titreVue(_ titre: TikkunTexte, premier: Bool) -> some View {
        texteTitre(titre)
            .font(Font.hebreu(police, taille: 20 * echelle).bold())
            .foregroundStyle(rendu.titre)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, premier ? 0 : 24)
            .padding(.bottom, 4)
            .environment(\.layoutDirection, .rightToLeft)
            .accessibilityAddTraits(.isHeader)
    }

    private func texteTitre(_ titre: TikkunTexte) -> Text {
        switch titre {
        case .hebreu(let texte): Text(verbatim: texte)
        case .libelle(let libelle): Text(libelle, traducteur: traducteur)
        }
    }

    /// Un texte hébreu (verset, arret, paragraphe) : police de lecture, de droite à gauche, l'interligne à l'échelle.
    private func hebreu(_ texte: String, taille: CGFloat, interligne: CGFloat, style: AnyShapeStyle,
                        centre: Bool = false) -> some View {
        Text(verbatim: texte)
            .font(Font.hebreu(police, taille: taille * echelle))
            .foregroundStyle(style)
            .lineSpacing(interligne * echelle)
            .multilineTextAlignment(centre ? .center : .leading)
            .frame(maxWidth: .infinity, alignment: centre ? .center : .leading)
            .environment(\.layoutDirection, .rightToLeft)
    }

    /// La note d'une partie, dans la langue de l'app (et son sens) : 14 pt, discrète.
    private func note(_ texte: String) -> some View {
        Text(verbatim: texte)
            .font(Font.system(size: 14 * echelle))
            .foregroundStyle(rendu.discret)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
    }

    /// Une traduction : de gauche à droite, police à empattements du système. Seule : `base − 1` pt, encre ; sous
    /// l'hébreu : `base − 3` pt, discrète.
    private func traduction(_ texte: String, seule: Bool, base: Int) -> some View {
        Text(verbatim: texte)
            .font(Font.system(size: CGFloat(seule ? base - 1 : base - 3) * echelle, design: .serif))
            .foregroundStyle(seule ? rendu.texte : rendu.discret)
            .lineSpacing(4 * echelle)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .leftToRight)
    }

    // MARK: Le bouton du bas

    private var boutonFin: some View {
        Button {
            TehilimTache.lancer { try await modele.direEnEntier() }
        } label: {
            Text(modele.libelleFin, traducteur: traducteur)
                .font(Font.body.weight(.medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.principal)
        .disabled(!modele.finPossible)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}
