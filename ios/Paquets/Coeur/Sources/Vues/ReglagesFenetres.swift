import Foundation
import SwiftUI
import Coeur
import Ecrans

// Les fenêtres de l'écran Réglages qui ne sont pas de simples alertes : la liste à choix (AlertDialog.setItems et
// setSingleChoiceItems d'Android) et le choix d'une heure (TimePickerDialog en 24 h).

/// L'heure d'une borne de la fenêtre, ouverte en feuille.
struct ReglagesHeureOuverte: Identifiable, Hashable {
    let borne: ReglagesBorne

    var id: String { borne.rawValue }
}

/// Une liste à choix : son titre, ses lignes, la valeur réglée cochée s'il y a lieu. Toucher une ligne la choisit
/// (le modèle referme la fenêtre) ; « Retour » ferme sans rien changer, là où Android l'a (les listes à cocher).
struct ReglagesFeuilleChoix: View {
    private let choix: ReglagesChoix
    private let choisir: @MainActor (Int) -> Void
    private let fermer: @MainActor () -> Void
    @Environment(\.traducteur) private var traducteur

    init(choix: ReglagesChoix, choisir: @escaping @MainActor (Int) -> Void, fermer: @escaping @MainActor () -> Void) {
        self.choix = choix
        self.choisir = choisir
        self.fermer = fermer
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(choix.options) { option in
                    ligne(option)
                }
                .listRowBackground(Rectangle().fill(Teinte(.card)))
            }
            .scrollContentBackground(.hidden)
            .background(Teinte(.paper))
            .navigationTitle(Text(choix.titre, traducteur: traducteur))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if choix.aCocher {
                        Button {
                            fermer()
                        } label: {
                            reglagesTexte("action_back", traducteur)
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func ligne(_ option: ReglagesOption) -> some View {
        Button {
            choisir(option.rang)
        } label: {
            HStack(spacing: 12) {
                if choix.aCocher {
                    Image(systemName: option.cochee ? "largecircle.fill.circle" : "circle")
                        .font(.body)
                        .foregroundStyle(Teinte(.brand))
                        .accessibilityHidden(true)
                }
                Text(option.libelle, traducteur: traducteur)
                    .font(.body)
                    .foregroundStyle(Teinte(.ink))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(option.cochee ? .isSelected : [])
    }
}

/// Le choix d'une heure de la fenêtre : une roue des heures et des minutes en 24 h dans toutes les langues
/// (TimePickerDialog, is24HourView), avec « Annuler » et « Valider » du système. L'heure est tenue comme un instant
/// de la journée de référence en temps universel (2001-01-01 UTC), pour qu'aucun fuseau ni changement d'heure ne
/// la décale.
struct ReglagesFeuilleHeure: View {
    private let titre: Text
    private let valider: @MainActor (Int, Int) -> Void
    private let annuler: @MainActor () -> Void
    @State private var instant: Date

    init(heure: Int, minute: Int, titre: Text,
         valider: @escaping @MainActor (Int, Int) -> Void,
         annuler: @escaping @MainActor () -> Void) {
        self.titre = titre
        self.valider = valider
        self.annuler = annuler
        _instant = State(initialValue: Date(timeIntervalSinceReferenceDate: TimeInterval(heure * 3600 + minute * 60)))
    }

    var body: some View {
        NavigationStack {
            DatePicker(selection: $instant, displayedComponents: .hourAndMinute) {
                titre
            }
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.timeZone, .gmt)
            // Des chiffres seuls, sur 24 heures, comme Android (Store.formatMinutes) : une région qui les écrit ainsi.
            .environment(\.locale, Locale(identifier: "en_GB"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(titre)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        annuler()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        choisir()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func choisir() {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = .gmt
        let parties = calendrier.dateComponents([.hour, .minute], from: instant)
        valider(parties.hour ?? 0, parties.minute ?? 0)
    }
}
