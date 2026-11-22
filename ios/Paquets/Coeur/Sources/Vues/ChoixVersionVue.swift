import Foundation
import SwiftUI
import Coeur
import Ecrans

/// « Version de l'app » (ChoixVersionActivity.kt) : le titre, le détail, une carte par version (son nom, ce qu'elle
/// est, « version actuelle » sur la choisie), le pied. Une carte touchée retient la version et ferme l'écran ; une
/// version dont l'accueil n'est pas encore porté sur iOS le dit (`ios_version_a_venir`) et l'app garde Classique.
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
                        Carte {
                            HStack(alignment: .firstTextBaseline) {
                                Text(carte.nom, traducteur: traducteur)
                                    .titreCarte()
                                Spacer(minLength: 8)
                                if carte.choisie {
                                    Text(modele.actuelle, traducteur: traducteur)
                                        .font(Font.caption.weight(.semibold))
                                        .foregroundStyle(Teinte(.brand))
                                }
                            }
                            Text(carte.description, traducteur: traducteur)
                                .indicationCarte()
                                .padding(.top, 4)
                        }
                        .overlay {
                            if carte.choisie {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(Teinte(.brand), lineWidth: 2)
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(carte.choisie ? .isSelected : [])
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
        .alert(Text(modele.message ?? modele.titre, traducteur: traducteur), isPresented: Bindable(modele).messageLie) {
            Button {
                modele.messageMontre()
                fermer()
            } label: {
                Text(Libelle("action_ok"), traducteur: traducteur)
            }
        }
        .onChange(of: modele.ferme) { _, ferme in
            // Une version à venir le dit d'abord ; sinon l'écran se ferme aussitôt.
            if ferme && modele.message == nil { fermer() }
        }
    }
}

extension ChoixVersionModele {
    var messageLie: Bool {
        get { message != nil }
        set { if !newValue { messageMontre() } }
    }
}
