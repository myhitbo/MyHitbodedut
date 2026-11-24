import Foundation
import SwiftUI
import Coeur
import Ecrans

/// Une entrée de la bibliothèque (LibraryEntryActivity.kt, activity_library_entry.xml) : le bandeau sans image (pas
/// d'image pendant une lecture), puis les paragraphes d'une source, ou la fiche d'un article (résumé, texte
/// intégral), et le bouton vers Sefaria ou le site. Une source a le bouton de lecture (taille, nuit, police,
/// langues). Tout se lit dans `BibliothequeEntreeModele`.
public struct BibliothequeEntreeVue: View {
    let modele: BibliothequeEntreeModele

    @Environment(\.traducteur) private var traducteur
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    /// Les tailles d'Android, en sp, suivent la taille du texte du téléphone (Dynamic Type) comme le corps du texte.
    /// En centièmes : `@ScaledMetric` arrondit sa valeur, et sur 1 il n'avançait que par sauts entiers (la police
    /// restait la même d'une taille du texte à la suivante : l'audit la disait suivie « en partie »).
    @ScaledMetric(relativeTo: .body) private var centiemes: CGFloat = 100

    private var dynamique: CGFloat { centiemes / 100 }

    public init(modele: BibliothequeEntreeModele) {
        self.modele = modele
    }

    public var body: some View {
        ScrollView {
            if modele.etat == .pret {
                contenu
            }
        }
        .background(Teinte(.paper))
        // Le bouton de lecture sous le texte, jamais sur une ligne (boutonsDeLecture).
        .boutonsDeLecture(fond: Teinte(.paper), visibles: modele.barreLectureVisible) {
            if modele.barreLectureVisible {
                BibliothequeBarreVue(barre: modele.barre)
            }
        }
        .overlay(alignment: .bottom) {
            bas
        }
        .navigationTitle(Text(verbatim: modele.titre))
        .navigationBarTitleDisplayMode(.inline)
        .task { await modele.charger() }
        .onChange(of: modele.etat) { _, etat in
            // finish() d'Android : l'identifiant ne désigne rien.
            if etat == .introuvable { dismiss() }
        }
    }

    private var contenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            BibliothequeEnteteEntree(modele: modele)
            if modele.paragraphesVisibles {
                paragraphes
            }
            if !modele.faits.isEmpty {
                fiche
            }
            if let lien = modele.lien {
                boutonLien(lien)
            }
        }
        // 24 sous la page, et 72 de plus pour lire au-dessus du bouton de lecture.
        .padding(.bottom, 24)
    }

    // MARK: Le bas de l'écran

    /// La barre du masquage et le message d'une adresse qui ne s'ouvre pas (le bouton de lecture est sous le texte).
    private var bas: some View {
        VStack(spacing: 0) {
            if let alerte = modele.alerte {
                BibliothequeMessageBref(message: alerte) {
                    modele.fermerAlerte()
                }
            }
            if let message = modele.barre.messageMasque {
                BibliothequeAnnonceMasque(barre: modele.barre, message: message)
            }
        }
    }

    // MARK: Les mesures de lecture

    private var rendu: BibliothequeRendu {
        BibliothequeRendu(sombre: modele.lectureSombre)
    }

    /// L'échelle du texte : celle du bouton de lecture (0,8 à 2), par celle du téléphone.
    private var echelle: CGFloat {
        CGFloat(modele.echelle) * dynamique
    }

    // MARK: Les paragraphes d'une source

    private var paragraphes: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(modele.blocs) { bloc in
                blocVue(bloc)
                    .padding(.top, CGFloat(bloc.margeHaut))
            }
        }
        .padding(16)
        .fondCarteBibliotheque(rendu.fond)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .contentShape(Rectangle())
        // Deux touchers sur le texte font revenir le bouton de lecture masqué (ReglagesLecture.toucher) ; VoiceOver
        // a la même chose en action nommée.
        .onTapGesture(count: 2) {
            BibliothequeTache.lancer { try await modele.barre.retrouver() }
        }
        .accessibilityAction {
            BibliothequeTache.lancer { try await modele.barre.retrouver() }
        } label: {
            Text(Libelle("lecture_reglages"), traducteur: traducteur)
        }
    }

    @ViewBuilder
    private func blocVue(_ bloc: BibliothequeBloc) -> some View {
        switch bloc.sorte {
        case .hebreu:
            Text(verbatim: bloc.texte)
                .font(Font.hebreu(modele.police, taille: 17 * echelle))
                .lineSpacing(12 * CGFloat(modele.echelle))
                .foregroundStyle(rendu.texte)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .rightToLeft)
        case .traduction(_, let seule):
            Text(verbatim: bloc.texte)
                .font(Font.system(size: (seule ? 16 : 14) * echelle, design: .serif))
                .lineSpacing(4 * CGFloat(modele.echelle))
                .foregroundStyle(seule ? rendu.texte : rendu.discret)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    // MARK: La fiche d'un article

    private var fiche: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(modele.faits.enumerated()), id: \.element.id) { rang, fait in
                if rang > 0 {
                    Rectangle()
                        .fill(Teinte(.line))
                        .frame(height: 1)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(fait.intitule, traducteur: traducteur)
                        .font(.caption)
                        .foregroundStyle(Teinte(.brand))
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: fait.texte)
                        .font(.subheadline)
                        .lineSpacing(9)
                        .foregroundStyle(Teinte(.ink))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .fondCarteBibliotheque()
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: Le lien

    private func boutonLien(_ lien: BibliothequeLien) -> some View {
        Button {
            ouvrirLien(lien)
        } label: {
            Text(lien.titre, traducteur: traducteur)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.principal)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    /// `startActivity(ACTION_VIEW)` d'Android : hors de l'app. Une adresse illisible, ou que le système refuse,
    /// montre le message du modèle (le Toast d'Android).
    private func ouvrirLien(_ lien: BibliothequeLien) {
        let modele = self.modele
        guard let url = lien.url else {
            modele.ouvertureEchouee()
            return
        }
        openURL(url) { @Sendable acceptee in
            Task { @MainActor in
                if !acceptee { modele.ouvertureEchouee() }
            }
        }
    }
}

// MARK: - Le bandeau d'une entrée

/// Le bandeau d'une entrée (bg_hero, sans image) : la pastille translucide « Source » ou « Article », le titre en
/// blanc dans la police de lecture, la référence en menthe.
private struct BibliothequeEnteteEntree: View {
    let modele: BibliothequeEntreeModele
    @Environment(\.traducteur) private var traducteur
    @Environment(\.verticalSizeClass) private var classeVerticale
    @ScaledMetric(relativeTo: .title2) private var tailleTitre: CGFloat = 21

    init(modele: BibliothequeEntreeModele) {
        self.modele = modele
    }

    /// hero_pad_top et hero_pad_bottom : plus grands sur un écran haut (values-h640dp).
    private var haut: Bool {
        classeVerticale != .compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let nature = modele.nature {
                Text(nature, traducteur: traducteur)
                    .font(.caption2)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0x33 / 255.0), in: Capsule())
                    .padding(.bottom, 8)
            }
            titre
            if let reference = modele.reference {
                Text(verbatim: reference)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.mint))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, haut ? 22 : 12)
        .padding(.bottom, haut ? 18 : 10)
        .background { BibliothequeFondBandeau() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// Le titre : de droite à gauche pour une source, dans le sens de la langue pour un article.
    @ViewBuilder
    private var titre: some View {
        let texte = Text(verbatim: modele.titre)
            .font(Font.hebreu(modele.police, taille: tailleTitre).bold())
            .foregroundStyle(Color.white)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        if modele.titreDroiteAGauche {
            texte.environment(\.layoutDirection, .rightToLeft)
        } else {
            texte
        }
    }
}
