import Foundation
import SwiftUI
import Coeur
import Ecrans

/// Le choix des applications (AppPickerActivity.kt, activity_apps.xml) : ce que le sélecteur d'Apple permet, le compte
/// des choix, la limite des cinquante applications, l'aide-mémoire de la liste d'Android, le bouton du sélecteur, les
/// choix eux-mêmes et « Tout retirer ». Le sélecteur et les choix (`FamilyActivityPicker`, `Label(jeton)`) sont de
/// FamilyControls : l'app les donne (`jetons`, `choisir`, `retirer`), la vue les range.
public struct ChoixApplicationsVue<Jetons: View>: View {
    private let modele: ChoixApplicationsModele
    private let choisir: @MainActor () -> Void
    private let retirer: @MainActor () -> Void
    private let jetons: Jetons
    @Environment(\.traducteur) private var traducteur

    public init(modele: ChoixApplicationsModele, choisir: @escaping @MainActor () -> Void,
                retirer: @escaping @MainActor () -> Void, @ViewBuilder jetons: () -> Jetons) {
        self.modele = modele
        self.choisir = choisir
        self.retirer = retirer
        self.jetons = jetons()
    }

    public var body: some View {
        List {
            Section {
                Text(modele.explication, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
                if let aide = modele.aideMemoire {
                    Text(aide, traducteur: traducteur)
                        .font(.footnote)
                        .foregroundStyle(Teinte(.muted))
                }
            }
            .listRowBackground(Rectangle().fill(Teinte(.card)))
            Section {
                ForEach(Array(modele.comptes.enumerated()), id: \.offset) { _, compte in
                    Text(compte, traducteur: traducteur)
                        .font(Font.subheadline.weight(.semibold))
                        .foregroundStyle(ReglagesTeinte.nommee(modele.couleurComptes))
                }
                if let limite = modele.avertissementLimite {
                    Text(limite, traducteur: traducteur)
                        .font(.footnote)
                        .foregroundStyle(ReglagesTeinte.nommee("warning"))
                }
                Button {
                    choisir()
                } label: {
                    Text(Libelle("action_pick_apps"), traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.principal)
                .disabled(!modele.choixPossible)
                if let sansAcces = modele.sansAcces {
                    Text(sansAcces, traducteur: traducteur)
                        .font(.footnote)
                        .foregroundStyle(Teinte(.muted))
                }
            }
            .listRowBackground(Rectangle().fill(Teinte(.card)))
            if !modele.selection.vide {
                Section {
                    jetons
                }
                .listRowBackground(Rectangle().fill(Teinte(.card)))
                Section {
                    Button(role: .destructive) {
                        retirer()
                    } label: {
                        Text(Libelle("apps_clear"), traducteur: traducteur)
                    }
                }
                .listRowBackground(Rectangle().fill(Teinte(.card)))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Teinte(.paper))
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
    }
}
