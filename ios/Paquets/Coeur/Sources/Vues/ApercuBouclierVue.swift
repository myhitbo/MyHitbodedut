import Foundation
import SwiftUI
import Barriere
import Coeur
import Ecrans

/// L'aperçu du bouclier (« Voir l'écran « Je suis avec Hachem » maintenant », GateService.preview d'Android ;
/// PORTAGE.md § 2.1.4, § 2.1.8) : une réplique dessinée des trois visages du bouclier (view_blocker.xml : le fond
/// `brand_dark`, la pose du hassid sur sa plaque, le titre blanc, le sous-titre et la série à la menthe, le bouton
/// principal, puis « Autre réponse » et son sous-menu), le visage choisi par un sélecteur ; puis l'essai réel, qui
/// pose le vrai bouclier deux minutes. La vue lit `ApercuBouclierModele` (Ecrans) ; elle est poussée sur la pile de
/// l'onglet Réglages et n'en ouvre pas d'autre.
///
/// La réplique n'agit pas : ses boutons ne font rien, comme l'indique l'introduction. Elle prend toujours les
/// couleurs de jour de la palette, celles que l'app dépose pour le vrai bouclier (barriere/bouclier.json).
public struct ApercuBouclierVue: View {
    @Bindable private var modele: ApercuBouclierModele
    @Environment(\.traducteur) private var traducteur

    public init(modele: ApercuBouclierModele) {
        _modele = Bindable(wrappedValue: modele)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(modele.introduction, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.muted))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                Picker(selection: $modele.choisi) {
                    ForEach(modele.visages) { visage in
                        Text(visage.nom, traducteur: traducteur)
                            .tag(visage.visage)
                    }
                } label: {
                    Text(modele.titre, traducteur: traducteur)
                }
                .pickerStyle(.segmented)
                ApercuBouclierReplique(visage: modele.visage)
                if modele.essaiDisponible {
                    carteEssai
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Teinte(.paper))
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { modele.actualiser() }
        .alert(titreMessage, isPresented: messageOuvert) {
            Button(role: .cancel) {
                modele.messageVu()
            } label: {
                Text("action_ok", tableName: "ios")
            }
        }
    }

    // MARK: L'essai réel

    private var carteEssai: some View {
        Carte {
            Text(modele.titreEssai, traducteur: traducteur)
                .titreCarte()
                .multilineTextAlignment(.leading)
                .accessibilityAddTraits(.isHeader)
            Text(modele.explicationEssai, traducteur: traducteur)
                .font(.subheadline)
                .foregroundStyle(Teinte(.ink))
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .padding(.top, 8)
            Button {
                let modele = self.modele
                Task { await modele.faireEssai() }
            } label: {
                Text(modele.boutonEssai, traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principal)
            .disabled(modele.essaiEnDemande)
            .padding(.top, 14)
            if let etat = modele.etatEssai {
                Etiquette(Text(etat, traducteur: traducteur))
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
                                          modele.messageVu()
                                      }
                                  })
    }
}

/// Un visage du bouclier, dessiné comme l'écran de garde d'Android (view_blocker.xml) dans la mise en page du
/// bouclier d'iOS : l'icône en haut, le titre, le sous-titre, le bouton principal, le secondaire.
private struct ApercuBouclierReplique: View {
    let visage: ApercuBouclierVisage
    @Environment(\.traducteur) private var traducteur

    init(visage: ApercuBouclierVisage) {
        self.visage = visage
    }

    var body: some View {
        let contenu = visage.contenu
        VStack(spacing: 0) {
            if let badge = contenu.badge {
                // bg_badge : le badge de l'aperçu, en capitales blanches.
                Text(badge, traducteur: traducteur)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Teinte(.stageSoft))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Teinte(.brand), in: Capsule())
                    .padding(.bottom, 12)
            }
            // bg_stage : la plaque claire sous le personnage.
            Illustration(decorative: visage.image, hauteur: 150)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Teinte(.stageSoft), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            Text(contenu.titre, traducteur: traducteur)
                .font(Font.title2.bold())
                .foregroundStyle(Teinte(.stageSoft))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(contenu.lignes.enumerated()), id: \.offset) { _, ligne in
                Text(ligne, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.mint))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            Text(contenu.principal, traducteur: traducteur)
                .font(Font.body.weight(.semibold))
                .foregroundStyle(Teinte(.onBrand))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 50)
                .padding(.horizontal, 16)
                .background(Teinte(.brand), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, 24)
                .accessibilityAddTraits(.isButton)
            if let secondaire = contenu.secondaire {
                Menu {
                    ForEach(Array(contenu.sousMenu.enumerated()), id: \.offset) { _, entree in
                        Text(entree, traducteur: traducteur)
                    }
                } label: {
                    Text(secondaire, traducteur: traducteur)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Teinte(.mint))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(Teinte(.brandDark), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        // Les couleurs de jour, celles du vrai bouclier.
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
    }
}
