import Foundation
import SwiftUI
import UIKit
import Coeur
import Ecrans

/// Le choix des applications de la barrière (AppPickerActivity.kt, activity_apps.xml, item_app.xml ; PORTAGE.md
/// § 2.1.3) : ce que le sélecteur d'iOS propose, la carte de l'autorisation de Temps d'écran, puis la carte de la
/// sélection (l'aide-mémoire d'Android, ce qui est retenu, l'avertissement des 50 applications, « Choisir les
/// applications », la liste des jetons, « Tout retirer »). La vue lit `ApplicationsModele` (Ecrans) ; elle est
/// poussée sur la pile de l'onglet Réglages et n'en ouvre pas d'autre.
///
/// FamilyControls n'est pas ici : l'app pose cette vue dans la sienne (ios/App/ApplicationsChoixVue.swift), qui
/// présente le sélecteur d'Apple quand `modele.selecteurOuvert` passe à vrai, et donne la liste des jetons
/// (`Label(jeton)`, que le système dessine) par `jetons`. Seule ouverture du système d'ici : les Réglages d'iOS,
/// après un refus, comme l'aide à la concentration.
public struct ApplicationsVue<Jetons: View>: View {
    private let modele: ApplicationsModele
    private let jetons: Jetons
    @Environment(\.traducteur) private var traducteur
    @Environment(\.scenePhase) private var scenePhase

    /// - Parameters:
    ///   - modele: le modèle de l'écran.
    ///   - jetons: ce que la sélection retient, dessiné par le système ; montré quand `modele.montrerJetons`.
    public init(modele: ApplicationsModele, @ViewBuilder jetons: () -> Jetons) {
        self.modele = modele
        self.jetons = jetons()
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(modele.indication, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.muted))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                carteAutorisation
                carteSelection
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Teinte(.paper))
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await modele.ouvrir()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task.immediate { @MainActor [modele] in
                    await modele.rafraichir()
                }
            }
        }
        .alert(titreMessage, isPresented: messageOuvert) {
            Button(role: .cancel) {
                modele.message = nil
            } label: {
                Text("action_ok", tableName: "ios")
            }
        }
    }

    // MARK: L'autorisation

    private var carteAutorisation: some View {
        Carte {
            Text(modele.titreAutorisation, traducteur: traducteur)
                .titreCarte()
                .multilineTextAlignment(.leading)
                .accessibilityAddTraits(.isHeader)
            if modele.acces == .enAttente {
                HStack(spacing: 10) {
                    ProgressView()
                    texteAcces
                }
                .padding(.top, 8)
            } else {
                texteAcces
                    .padding(.top, 8)
            }
            if let bouton = modele.boutonDemande {
                Button {
                    Task.immediate { @MainActor [modele] in
                        await modele.demanderAutorisation()
                    }
                } label: {
                    Text(bouton, traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.principal)
                .padding(.top, 12)
            }
            if let reglages = modele.boutonReglages {
                Button {
                    ouvrirReglages()
                } label: {
                    Text(reglages, traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
                .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private var texteAcces: some View {
        if let texte = modele.texteAcces {
            Text(texte, traducteur: traducteur)
                .font(.subheadline)
                .foregroundStyle(modele.accesAvertit ? AnyShapeStyle(ReglagesTeinteFixe.avertissement)
                                                     : AnyShapeStyle(Teinte(.ink)))
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
    }

    // MARK: La sélection

    private var carteSelection: some View {
        Carte {
            Text(modele.titreSelection, traducteur: traducteur)
                .titreCarte()
                .multilineTextAlignment(.leading)
                .accessibilityAddTraits(.isHeader)
            // L'aide-mémoire d'Android, au-dessus du bouton (PORTAGE.md § 3.7).
            if let aide = modele.aideMemoire {
                Text(aide, traducteur: traducteur)
                    .indicationCarte()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 8)
            }
            VStack(alignment: .leading, spacing: 2) {
                ForEach(modele.resume, id: \.self) { ligne in
                    Text(ligne, traducteur: traducteur)
                        .font(.subheadline)
                        .foregroundStyle(modele.resumeAvertit ? AnyShapeStyle(ReglagesTeinteFixe.avertissement)
                                                              : AnyShapeStyle(Teinte(.muted)))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
            }
            .accessibilityElement(children: .combine)
            .padding(.top, 8)
            ForEach([modele.texteIllisible, modele.texteLimite].compactMap { $0 }, id: \.self) { alerte in
                Label {
                    Text(alerte, traducteur: traducteur)
                        .multilineTextAlignment(.leading)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.subheadline)
                .foregroundStyle(ReglagesTeinteFixe.avertissement)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
            }
            Button {
                modele.choisir()
            } label: {
                Text(modele.boutonChoisir, traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principal)
            .disabled(!modele.peutChoisir)
            .padding(.top, 12)
            if modele.montrerJetons {
                jetons
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 14)
            }
            if modele.peutToutRetirer {
                Button {
                    Task.immediate { @MainActor [modele] in
                        await modele.toutRetirer()
                    }
                } label: {
                    Text(modele.boutonToutRetirer, traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
                .padding(.top, 12)
            }
        }
    }

    // MARK: Le message

    private var titreMessage: Text {
        Text(verbatim: modele.message.map { traducteur.texte($0) } ?? "")
    }

    private var messageOuvert: Binding<Bool> {
        let modele = self.modele
        return Binding.passerelle({ @MainActor in modele.message != nil },
                                  { @MainActor ouvert in
                                      if !ouvert {
                                          modele.message = nil
                                      }
                                  })
    }

    /// Les Réglages d'iOS, sur la page de l'app (aucune adresse publique n'ouvre Temps d'écran).
    private func ouvrirReglages() {
        let modele = self.modele
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            modele.reglagesImpossibles()
            return
        }
        UIApplication.shared.open(url, options: [:]) { acceptee in
            if !acceptee {
                modele.reglagesImpossibles()
            }
        }
    }
}
