import Foundation
import SwiftUI
import Coeur
import Ecrans

// Les fenêtres de l'écran du vol (VolActivity.kt) : la recherche d'un aéroport (choisirAeroport, une liste qui se
// filtre 120 ms après la dernière lettre) et le choix de la date et de l'heure, à l'heure locale de l'aéroport
// (choisirHeure : DatePickerDialog puis TimePickerDialog). Le modèle dit laquelle est ouverte (`dialogue`) ; ces
// feuilles appellent ses actions, qui la referment.

/// La feuille ouverte, tirée du `dialogue` du modèle : la recherche d'un aéroport, ou le choix d'une heure.
enum VolFeuilleOuverte: Identifiable, Hashable {
    case aeroport(VolTuile.Genre)
    case heure(VolChampHeure, initiale: DateHeure)

    var id: VolFeuilleOuverte { self }

    /// La feuille d'un dialogue ; nil pour les messages et la question des services en ligne, qui sont des alertes.
    static func de(_ dialogue: VolDialogue?) -> VolFeuilleOuverte? {
        switch dialogue {
        case .aeroport(let genre)?:
            return .aeroport(genre)
        case .heure(let champ, let initiale)?:
            return .heure(champ, initiale: initiale)
        default:
            return nil
        }
    }
}

// MARK: La recherche d'un aéroport

/// « Choisir un aéroport » : le champ (le clavier s'ouvre aussitôt), « Aucun aéroport trouvé. », puis les
/// résultats, chacun sur deux lignes à côté de son code. Toucher un résultat le choisit ; « Entrée » prend le
/// premier ; « Annuler » ferme sans rien choisir.
struct VolFeuilleAeroport: View {
    let modele: VolModele
    @State private var texte = ""
    @FocusState private var champActif: Bool
    @Environment(\.traducteur) private var traducteur

    init(modele: VolModele) {
        self.modele = modele
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                champ
                if modele.rechercheVide {
                    t("vol_aucun_resultat")
                        .font(.subheadline)
                        .foregroundStyle(Teinte(.muted))
                        .padding(.top, 12)
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(modele.lignesAeroports) { ligne in
                            ligneAeroport(ligne)
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Teinte(.paper))
            .navigationTitle(t("vol_choisir_aeroport"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        modele.fermerDialogue()
                    }
                }
            }
        }
        // La recherche part 120 ms après la dernière lettre : une nouvelle lettre annule l'attente.
        .task(id: texte) {
            await chercher(texte)
        }
        .onAppear {
            champActif = true
        }
    }

    private var champ: some View {
        TextField(text: $texte, prompt: t("vol_chercher")) {
            t("vol_chercher")
        }
        .font(.body)
        .foregroundStyle(Teinte(.ink))
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .submitLabel(.done)
        .onSubmit {
            modele.validerRecherche()
        }
        .focused($champActif)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .volCadreSaisie()
    }

    /// Le code dans sa pastille (toujours de gauche à droite), la ville en gras, puis l'aéroport et le pays.
    private func ligneAeroport(_ ligne: VolAeroportLigne) -> some View {
        Button {
            modele.choisirAeroport(ligne.aeroport)
        } label: {
            HStack(spacing: 12) {
                Text(verbatim: ligne.iata)
                    .font(Font.footnote.bold().monospaced())
                    .foregroundStyle(Teinte(.brand))
                    .lineLimit(1)
                    .frame(width: 52, height: 32)
                    .background(Teinte(.brand).opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .environment(\.layoutDirection, .leftToRight)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: ligne.titre)
                        .font(Font.callout.bold())
                        .foregroundStyle(Teinte(.ink))
                        .lineLimit(1)
                    Text(verbatim: ligne.detail)
                        .font(.footnote)
                        .foregroundStyle(Teinte(.muted))
                        .lineLimit(1)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Le texte tapé, passé au modèle après 120 ms de calme ; rien si c'est déjà celui de la recherche.
    private func chercher(_ saisi: String) async {
        guard saisi != modele.recherche else { return }
        do {
            try await Task.sleep(for: .milliseconds(120))
        } catch {
            // Une autre lettre est venue : c'est elle qui cherchera.
            return
        }
        modele.chercherAeroport(saisi)
    }

    private func t(_ cle: String) -> Text {
        Text(Libelle(cle), traducteur: traducteur)
    }
}

// MARK: Le choix de l'heure

/// La date et l'heure, à l'heure locale de l'aéroport : une heure civile, sans fuseau. Le sélecteur travaille en
/// UTC, où l'heure civile se lit telle quelle (Fuseau.utc) ; il est en 24 h ou en 12 h selon le réglage du
/// téléphone. « OK » la donne au modèle, « Annuler » ferme sans rien changer.
struct VolFeuilleHeure: View {
    let modele: VolModele
    @State private var instant: Date

    init(modele: VolModele, initiale: DateHeure) {
        self.modele = modele
        _instant = State(initialValue: Date(timeIntervalSince1970: Double(Fuseau.utc.millis(initiale)) / 1000))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                DatePicker(selection: $instant, displayedComponents: [.date, .hourAndMinute]) {
                    EmptyView()
                }
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(Teinte(.brand))
                .environment(\.timeZone, .gmt)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Teinte(.paper))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        modele.fermerDialogue()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        choisir()
                    }
                }
            }
        }
    }

    /// L'instant du sélecteur relu en heure civile (UTC), à la minute près : le modèle garde la minute.
    private func choisir() {
        let millis = Int64((instant.timeIntervalSince1970 * 1000).rounded())
        let civile = Fuseau.utc.dateHeure(millis: millis)
        Task { await modele.choisirHeure(civile) }
    }
}
