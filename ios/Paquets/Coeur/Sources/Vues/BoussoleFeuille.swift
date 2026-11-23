import Foundation
import SwiftUI
import Coeur
import Ecrans

/// Les trois dialogues de la boussole (MaterialAlertDialogBuilder de BoussoleActivity et de ChoixLieu), en
/// feuille : le choix du lieu (« Ma position », puis les villes), la méthode et l'affichage (un choix unique,
/// l'option choisie cochée). Choisir ferme la feuille (le modèle remet `dialogue` à nil) ; la glisser vers le
/// bas la ferme sans rien choisir, comme toucher hors d'un dialogue d'Android.
struct BoussoleFeuille: View {
    let modele: BoussoleModele
    let dialogue: BoussoleDialogue

    @Environment(\.traducteur) private var traducteur

    init(modele: BoussoleModele, dialogue: BoussoleDialogue) {
        self.modele = modele
        self.dialogue = dialogue
    }

    var body: some View {
        NavigationStack {
            liste
                .scrollContentBackground(.hidden)
                .background(Teinte(.paper))
                .navigationTitle(Text(dialogue.titre, traducteur: traducteur))
                .navigationBarTitleDisplayMode(.inline)
        }
        .hauteursDeFeuille(hauteurs)
        .presentationDragIndicator(.visible)
    }

    /// La liste des villes est longue : elle peut prendre tout l'écran ; les deux choix uniques, la moitié.
    private var hauteurs: Set<PresentationDetent> {
        switch dialogue {
        case .choixLieu: [.medium, .large]
        case .methode, .affichage: [.medium]
        }
    }

    @ViewBuilder private var liste: some View {
        switch dialogue {
        case .choixLieu:
            lieux
        case .methode:
            methodes
        case .affichage:
            affichages
        }
    }

    // MARK: Le choix du lieu (ChoixLieu.montrer)

    private var lieux: some View {
        List {
            Button {
                utiliserMaPosition()
            } label: {
                BoussoleLigneChoix(texte: Text(modele.maPosition, traducteur: traducteur), cochee: false)
            }
            .listRowBackground(Rectangle().fill(Teinte(.card)))
            ForEach(modele.villesProposees) { ville in
                Button {
                    choisirVille(ville.id)
                } label: {
                    BoussoleLigneChoix(texte: Text(verbatim: ville.nom), cochee: false)
                }
                .listRowBackground(Rectangle().fill(Teinte(.card)))
            }
        }
    }

    // MARK: Les choix uniques (setSingleChoiceItems)

    private var methodes: some View {
        List(modele.optionsMethode) { option in
            Button {
                choisirMethode(option.valeur)
            } label: {
                BoussoleLigneChoix(texte: Text(option.libelle, traducteur: traducteur), cochee: option.choisie)
            }
            .listRowBackground(Rectangle().fill(Teinte(.card)))
        }
    }

    private var affichages: some View {
        List(modele.optionsAffichage) { option in
            Button {
                choisirAffichage(option.valeur)
            } label: {
                BoussoleLigneChoix(texte: Text(option.libelle, traducteur: traducteur), cochee: option.choisie)
            }
            .listRowBackground(Rectangle().fill(Teinte(.card)))
        }
    }

    // MARK: Les actions
    // Une écriture des réglages qui échoue ne dit rien, comme Android (Store ne signale pas d'échec).

    private func utiliserMaPosition() {
        Task {
            do {
                try await modele.utiliserMaPosition()
            } catch {
            }
        }
    }

    private func choisirVille(_ id: Int64) {
        Task {
            do {
                try await modele.choisirVille(id: id)
            } catch {
            }
        }
    }

    private func choisirMethode(_ selonCarte: Bool) {
        Task {
            do {
                try await modele.choisirMethode(selonCarte: selonCarte)
            } catch {
            }
        }
    }

    private func choisirAffichage(_ rose: Bool) {
        Task {
            do {
                try await modele.choisirAffichage(rose: rose)
            } catch {
            }
        }
    }
}

/// Une ligne de dialogue : le texte, et la coche de l'option choisie (le bouton radio d'Android), que VoiceOver
/// dit « sélectionné ».
struct BoussoleLigneChoix: View {
    let texte: Text
    let cochee: Bool

    init(texte: Text, cochee: Bool) {
        self.texte = texte
        self.cochee = cochee
    }

    var body: some View {
        HStack(spacing: 12) {
            texte
                .font(.body)
                .foregroundStyle(Teinte(.ink))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if cochee {
                Image(systemName: "checkmark")
                    .font(Font.body.weight(.semibold))
                    .foregroundStyle(Teinte(.brand))
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(cochee ? .isSelected : [])
    }
}
