import Foundation
import SwiftUI
import Coeur
import Ecrans

/// La dédicace (Dedicace.kt, la boîte qu'ouvre « Dédicacer » dans les réglages), en feuille : le texte d'aide,
/// « Que dédiez-vous ? » et « Pour » en listes à cocher (les RadioGroup), le nom, le mot facultatif. « Écrire
/// l'e-mail » ouvre le lien mailto: du modèle dans la messagerie (`openURL`, l'Intent.ACTION_SENDTO d'Android) ; la
/// feuille se ferme si une messagerie l'a pris, sinon elle dit « Aucune messagerie trouvée » puis se ferme. Tant
/// que le nom manque, rien ne s'ouvre et le champ le dit. « Retour » ferme sans rien écrire. Tout se lit dans
/// `DedicaceModele` ; rien n'est envoyé ni gardé par l'app.
public struct DedicaceVue: View {
    @Bindable private var modele: DedicaceModele
    @Environment(\.dismiss) private var fermer
    @Environment(\.openURL) private var ouvrirURL
    @Environment(\.traducteur) private var traducteur

    /// - Parameter modele: `DedicaceModele(traducteur:)`, neuf à chaque ouverture.
    public init(modele: DedicaceModele) {
        self.modele = modele
    }

    public var body: some View {
        NavigationStack {
            formulaire
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .background(Teinte(.paper))
                .navigationTitle(Text(modele.titre, traducteur: traducteur))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            fermer()
                        } label: {
                            Text(modele.libelleRetour, traducteur: traducteur)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            ecrire()
                        } label: {
                            Text(modele.libelleEcrire, traducteur: traducteur)
                        }
                    }
                }
                .alert(Text(modele.messageSansMessagerie, traducteur: traducteur), isPresented: messageOuvert) {
                    // Aucune action : le système met « OK », qui ferme l'alerte, puis la feuille (le Toast d'Android
                    // suivi de `dialogue.dismiss()`).
                }
                .onChange(of: modele.termine) { _, fini in
                    if fini {
                        fermer()
                    }
                }
        }
    }

    private var formulaire: some View {
        Form {
            Section {
                Text(modele.aide, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.muted))
            }
            Section {
                Picker(selection: $modele.objet) {
                    ForEach(modele.objets) { objet in
                        Text(objet.libelle, traducteur: traducteur)
                            .tag(objet)
                    }
                } label: {
                    Text(modele.legendeObjet, traducteur: traducteur)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text(modele.legendeObjet, traducteur: traducteur)
            }
            Section {
                Picker(selection: $modele.intention) {
                    ForEach(modele.intentions) { intention in
                        Text(intention.libelle, traducteur: traducteur)
                            .tag(intention)
                    }
                } label: {
                    Text(modele.legendeIntention, traducteur: traducteur)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text(modele.legendeIntention, traducteur: traducteur)
            }
            Section {
                TextField(text: $modele.nom, prompt: Text(modele.indicationNom, traducteur: traducteur)) {
                    Text(modele.indicationNom, traducteur: traducteur)
                }
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                if let erreur = modele.erreurNom {
                    // L'erreur du champ (`nom.error`), lue par VoiceOver avec lui.
                    Text(erreur, traducteur: traducteur)
                        .font(.footnote)
                        .foregroundStyle(ReglagesTeinteFixe.danger)
                }
                TextField(text: $modele.mot, prompt: Text(modele.indicationMot, traducteur: traducteur),
                          axis: .vertical) {
                    Text(modele.indicationMot, traducteur: traducteur)
                }
                .lineLimit(2...6)
                .textInputAutocapitalization(.sentences)
            }
        }
        .foregroundStyle(Teinte(.ink))
    }

    /// Le lien du modèle ouvert dans la messagerie ; rien tant que le nom manque. Le résultat revient au modèle sur
    /// l'acteur principal, quelle que soit la file où le système rappelle.
    private func ecrire() {
        let modele = self.modele
        guard let url = modele.ecrire() else { return }
        ouvrirURL(url) { @Sendable acceptee in
            Task { @MainActor in
                modele.ouverture(reussie: acceptee)
            }
        }
    }

    /// L'alerte « Aucune messagerie trouvée » : ouverte par le modèle, refermée (seul cas où la liaison est écrite)
    /// par `messageLu()`.
    private var messageOuvert: Binding<Bool> {
        let modele = self.modele
        return Binding.passerelle({ @MainActor in modele.sansMessagerie },
                                  { @MainActor _ in modele.messageLu() })
    }
}
