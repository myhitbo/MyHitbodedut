import Foundation
import SwiftUI
import UIKit
import Coeur
import Ecrans

/// La dédicace (Dedicace.kt) : ce qu'on dédie, pour quoi, le nom, un mot pour l'équipe, puis « Écrire l'e-mail », qui
/// ouvre la messagerie avec un message prêt à partir, adressé à l'équipe. Rien ne part sans l'utilisateur. Sans
/// messagerie, l'écran reste, le message est copié et l'adresse s'affiche, sélectionnable.
public struct DedicaceVue: View {
    private let modele: DedicaceModele
    @Environment(\.traducteur) private var traducteur
    @Environment(\.openURL) private var ouvrirLien

    public init(modele: DedicaceModele) {
        self.modele = modele
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(modele.explication, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
                Carte {
                    legende("dedicace_quoi")
                    ForEach(DedicaceObjet.allCases) { objet in
                        radio(modele.objet == objet, objet.libelle) { modele.objet = objet }
                    }
                    legende("dedicace_pour")
                        .padding(.top, 10)
                    ForEach(DedicaceIntention.allCases) { intention in
                        radio(modele.intention == intention, intention.libelle) { modele.intention = intention }
                    }
                }
                Carte {
                    TextField(text: Bindable(modele).nom) {
                        Text(Libelle("dedicace_nom"), traducteur: traducteur)
                    }
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    if let erreur = modele.erreurNom {
                        erreurChamp(erreur)
                    }
                    TextField(text: Bindable(modele).mot, axis: .vertical) {
                        Text(modele.indiceMot, traducteur: traducteur)
                    }
                    .lineLimit(2...6)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.sentences)
                    .padding(.top, 10)
                    if let erreur = modele.erreurMot {
                        erreurChamp(erreur)
                    }
                }
                if !modele.avis.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(modele.avis.enumerated()), id: \.offset) { _, avis in
                            Text(avis, traducteur: traducteur)
                                .font(.subheadline)
                                .foregroundStyle(Teinte(.ink))
                        }
                        Text(verbatim: DedicaceModele.adresse)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Teinte(.brand))
                            .textSelection(.enabled)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Teinte(.card), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                Button {
                    ecrire()
                } label: {
                    Text(Libelle("dedicace_ecrire"), traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.principal)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Teinte(.paper))
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Le message dans la messagerie ; sans elle, copié, et l'adresse affichée.
    private func ecrire() {
        guard let message = modele.ecrire() else { return }
        guard let url = URL(string: message.lien) else {
            copier(message)
            return
        }
        ouvrirLien(url) { ouvert in
            if !ouvert { copier(message) }
        }
    }

    private func copier(_ message: DedicaceMessage) {
        UIPasteboard.general.string = message.corps
        modele.sansMessagerie(copie: UIPasteboard.general.hasStrings)
    }

    private func legende(_ cle: String) -> some View {
        Text(Libelle(cle), traducteur: traducteur)
            .font(Font.subheadline.weight(.semibold))
            .foregroundStyle(Teinte(.ink))
            .accessibilityAddTraits(.isHeader)
    }

    private func radio(_ coche: Bool, _ libelle: Libelle, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: coche ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(Teinte(.brand))
                    .accessibilityHidden(true)
                Text(libelle, traducteur: traducteur)
                    .foregroundStyle(Teinte(.ink))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(coche ? .isSelected : [])
    }

    private func erreurChamp(_ erreur: Libelle) -> some View {
        Text(erreur, traducteur: traducteur)
            .font(.footnote)
            .foregroundStyle(AccueilFixe(jour: 0xA8561F, nuit: 0xE8A062))
            .padding(.top, 4)
    }
}
