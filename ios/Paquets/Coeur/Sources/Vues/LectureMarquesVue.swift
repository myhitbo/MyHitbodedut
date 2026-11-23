import Foundation
import SwiftUI
import Coeur
import Ecrans

// La feuille de tous les marque-pages (RepriseFavoris.listeSignets) : des puces à choix unique (tout, un recueil,
// un texte), puis une ligne par marque-page, le texte en petit et les premiers mots dessous. Un toucher ferme la
// feuille et ouvre le texte à sa place (`LectureRoute`), par la fermeture `ouvrir` de l'app. La feuille porte sa
// propre pile, pour son titre et son bouton OK : l'app la présente en `.sheet`.

/// La feuille des marque-pages.
public struct LectureMarquesVue: View {
    private let modele: LectureMarquesModele
    /// La police hébraïque des réglages de lecture (`LecturePreferences.police`) : les titres hébreux du modèle
    /// sont déjà masqués pour elle.
    private let police: PoliceHebraique.Police
    private let ouvrir: @MainActor (LectureRoute) -> Void

    @Environment(\.traducteur) private var traducteur
    @Environment(\.dismiss) private var fermer

    public init(modele: LectureMarquesModele, police: PoliceHebraique.Police,
                ouvrir: @escaping @MainActor (LectureRoute) -> Void) {
        self.modele = modele
        self.police = police
        self.ouvrir = ouvrir
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    puces
                    ForEach(modele.lignes) { ligne in
                        ligneVue(ligne)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .background(Teinte(.paper))
            .navigationTitle(Text(modele.titre, traducteur: traducteur))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        fermer()
                    }
                }
            }
        }
        .task { await modele.charger() }
    }

    // MARK: Les puces

    /// Les filtres, à choix unique et obligatoire.
    private var puces: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(modele.filtres) { filtre in
                    puce(filtre)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    private func puce(_ filtre: LectureMarquesFiltre) -> some View {
        let choisie = filtre.id == modele.filtre
        return Button {
            modele.choisirFiltre(filtre.id)
        } label: {
            HStack(spacing: 4) {
                if choisie {
                    Image(systemName: "checkmark")
                        .font(Font.caption.weight(.semibold))
                        .accessibilityHidden(true)
                }
                nom(filtre.nom, taille: 14, style: .subheadline)
                    .lineLimit(1)
            }
            .foregroundStyle(Teinte(choisie ? .onPlate : .ink))
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(Teinte(choisie ? .mint : .card), in: Capsule())
            .overlay {
                Capsule().strokeBorder(Teinte(.line), lineWidth: choisie ? 0 : 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(choisie ? .isSelected : [])
    }

    // MARK: Les lignes

    /// Le texte en petit avec l'icône du recueil au bout, et les premiers mots dessous, de droite à gauche.
    private func ligneVue(_ ligne: LectureMarquesLigne) -> some View {
        Button {
            fermer()
            ouvrir(ligne.route)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    nom(ligne.titre, taille: 13, style: .footnote)
                        .foregroundStyle(Teinte(.muted))
                    SiddourIcone(ligne.icone, taille: 14)
                        .foregroundStyle(Teinte(.brand))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(verbatim: ligne.apercu)
                    .policeHebraique(police, taille: 17)
                    .foregroundStyle(Teinte(.ink))
                    .lignesAuPlus(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 10)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
            .environment(\.layoutDirection, .rightToLeft)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    /// Un nom : l'hébreu d'un titre dans la police choisie, ou une chaîne de l'interface.
    @ViewBuilder
    private func nom(_ nom: LectureNom, taille: CGFloat, style: Font.TextStyle) -> some View {
        switch nom {
        case .hebreu(let texte):
            Text(verbatim: texte)
                .policeHebraique(police, taille: taille, relativeA: style)
        case .libelle(let libelle):
            Text(libelle, traducteur: traducteur)
                .font(.system(style))
        }
    }
}
