import Foundation
import SwiftUI
import Coeur
import Ecrans

/// Ajouter du temps à un jour passé (AjoutTemps.kt, 16/10), depuis le calendrier et Zmanim : une feuille qui suit les
/// fenêtres d'`AjoutTempsModele` — le jour (ce qui y est inscrit, « Ajouter du temps », « Modifier », « Retour »), la
/// liste des durées, la durée réglable, « Modifier » d'un jour fait, la confirmation du retrait. La feuille se ferme
/// quand le modèle n'a plus de fenêtre (`etape` nil) ; `fermer` la retire alors de l'écran qui l'a ouverte.
public struct AjoutTempsVue: View {
    @Bindable var modele: AjoutTempsModele
    private let fermer: @MainActor () -> Void
    @Environment(\.traducteur) private var traducteur

    public init(modele: AjoutTempsModele, fermer: @escaping @MainActor () -> Void) {
        self.modele = modele
        self.fermer = fermer
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch modele.etape {
                    case .jour: jour
                    case .durees: durees
                    case .saisie: saisie
                    case .modifier: modifier
                    case .retrait: retrait
                    case nil: EmptyView()
                    }
                }
                .padding(20)
            }
            .background(Teinte(.paper))
            .navigationTitle(Text(verbatim: AccueilDate.texte(modele.date, langue: traducteur.langue)))
            .navigationBarTitleDisplayMode(.inline)
        }
        .hauteursDeFeuille([.medium, .large])
        .onChange(of: modele.etape) { _, etape in
            if etape == nil { fermer() }
        }
        .onDisappear {
            // Glissée vers le bas : tout se ferme sans rien inscrire.
            if modele.etape != nil { modele.retour() }
        }
    }

    private var jour: some View {
        Group {
            Text(modele.message, traducteur: traducteur)
                .font(.body)
                .foregroundStyle(Teinte(.ink))
            bouton(modele.boutonAjouter, principal: true) { modele.ajouterTemps() }
            if modele.modifiable {
                bouton(modele.boutonModifier) { modele.modifier() }
            }
            bouton(modele.boutonRetour) { modele.retour() }
        }
    }

    private var durees: some View {
        Group {
            Text(modele.titreDurees, traducteur: traducteur)
                .font(.title3.bold())
                .foregroundStyle(Teinte(.ink))
            ForEach(modele.durees) { duree in
                Button {
                    Task { try? await modele.choisir(duree) }
                } label: {
                    Text(duree.libelle, traducteur: traducteur)
                        .foregroundStyle(Teinte(.ink))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            bouton(modele.boutonRetour) { modele.retour() }
        }
    }

    private var saisie: some View {
        Group {
            Text(modele.titreSaisie, traducteur: traducteur)
                .font(.title3.bold())
                .foregroundStyle(Teinte(.ink))
            TextField(text: $modele.saisie, axis: .vertical) {
                Text(modele.indicationSaisie, traducteur: traducteur)
            }
            .keyboardType(.numberPad)
            .textFieldStyle(.roundedBorder)
            Text(modele.erreurSaisie ?? modele.indicationSaisie, traducteur: traducteur)
                .font(.footnote)
                .foregroundStyle(modele.erreurSaisie == nil ? Teinte(.muted) : Teinte(.ink))
            bouton(modele.boutonValider, principal: true) {
                Task { try? await modele.validerSaisie() }
            }
            bouton(modele.boutonRetour) { modele.retour() }
        }
    }

    private var modifier: some View {
        Group {
            ForEach(modele.actions) { action in
                bouton(action.libelle) { modele.choisirAction(action) }
            }
            bouton(modele.boutonRetour) { modele.retour() }
        }
    }

    private var retrait: some View {
        Group {
            Text(modele.messageRetrait, traducteur: traducteur)
                .font(.body)
                .foregroundStyle(Teinte(.ink))
            bouton(modele.boutonRetirer, principal: true) {
                Task { try? await modele.confirmerRetrait() }
            }
            bouton(modele.boutonRetour) { modele.retour() }
        }
    }

    private func bouton(_ libelle: Libelle, principal: Bool = false,
                        action: @escaping @MainActor () -> Void) -> some View {
        Group {
            if principal {
                Button(action: action) {
                    Text(libelle, traducteur: traducteur).frame(maxWidth: .infinity)
                }
                .buttonStyle(.principal)
            } else {
                Button(action: action) {
                    Text(libelle, traducteur: traducteur).frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
            }
        }
    }
}
