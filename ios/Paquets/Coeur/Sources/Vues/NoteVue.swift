import Foundation
import SwiftUI
import Coeur
import Ecrans

/// La note présentée en feuille par l'écran de séance ou par le bravo : elle construit son modèle une fois, puis
/// montre `NoteVue`. Elle se retire d'elle-même (`dismiss`).
public struct NotePage: View {
    private let date: JourCivil
    private let fabrique: @MainActor (JourCivil) -> NoteModele
    @State private var modele: NoteModele? = nil

    /// - Parameters:
    ///   - date: le jour de la note (le jour de la séance, ou aujourd'hui).
    ///   - fabrique: `NoteModele(date:magasin:)`.
    public init(date: JourCivil, fabrique: @escaping @MainActor (JourCivil) -> NoteModele) {
        self.date = date
        self.fabrique = fabrique
    }

    public var body: some View {
        Group {
            if let modele {
                NoteVue(modele: modele)
            } else {
                Rectangle()
                    .fill(Teinte(.paper))
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            if modele == nil {
                modele = fabrique(date)
            }
        }
    }
}

/// La note de la hitbodedout (NoteDialog.kt) : le hassid qui écrit, la note libre sur quatre lignes, l'humeur avant
/// et après (cinq visages), une gratitude et une chose à travailler. « Enregistrer » écrit puis ferme ; « Plus
/// tard » (« Ne pas enregistrer » une fois la note changée) ferme sans écrire. Un toucher à côté ne ferme jamais, et
/// le geste qui ferme non plus dès que la note a changé. Tout se lit dans `NoteModele`.
public struct NoteVue: View {
    private let modele: NoteModele
    @Environment(\.dismiss) private var fermer
    @Environment(\.traducteur) private var traducteur
    /// « Enregistrer » touché : l'écriture est en cours, on ne l'envoie pas deux fois.
    @State private var enregistrement = false

    /// - Parameter modele: `NoteModele(date:magasin:)`.
    public init(modele: NoteModele) {
        self.modele = modele
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                formulaire
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Teinte(.paper))
            .navigationTitle(Text(modele.titre, traducteur: traducteur))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        fermer()
                    } label: {
                        Text(modele.libelleFermer, traducteur: traducteur)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        enregistrer()
                    } label: {
                        Text(modele.libelleEnregistrer, traducteur: traducteur)
                    }
                    .disabled(enregistrement)
                }
            }
        }
        .interactiveDismissDisabled(!modele.fermableParGeste)
    }

    private var formulaire: some View {
        VStack(alignment: .leading, spacing: 0) {
            Illustration(decorative: modele.image, hauteur: 120)
                .frame(maxWidth: .infinity)
            TextField(text: liaisonNote, prompt: Text(modele.indicationNote, traducteur: traducteur), axis: .vertical) {
                Text(modele.indicationNote, traducteur: traducteur)
            }
            .lineLimit(4, reservesSpace: true)
            .modifier(NoteChamp())
            .padding(.top, 8)
            NoteHumeurs(titre: Text(modele.titreAvant, traducteur: traducteur), humeurs: modele.humeurs,
                        choisie: modele.avant) { rang in
                modele.choisirAvant(rang)
            }
            .padding(.top, 8)
            NoteHumeurs(titre: Text(modele.titreApres, traducteur: traducteur), humeurs: modele.humeurs,
                        choisie: modele.apres) { rang in
                modele.choisirApres(rang)
            }
            .padding(.top, 8)
            TextField(text: liaisonGratitude,
                      prompt: Text(modele.indicationGratitude, traducteur: traducteur)) {
                Text(modele.indicationGratitude, traducteur: traducteur)
            }
            .modifier(NoteChamp())
            .padding(.top, 12)
            TextField(text: liaisonTravail,
                      prompt: Text(modele.indicationTravail, traducteur: traducteur)) {
                Text(modele.indicationTravail, traducteur: traducteur)
            }
            .modifier(NoteChamp())
            .padding(.top, 8)
        }
    }

    // MARK: Les liaisons

    private var liaisonNote: Binding<String> {
        let modele = self.modele
        return Binding.passerelle({ @MainActor in modele.texte },
                       { @MainActor nouveau in modele.ecrire(nouveau) })
    }

    private var liaisonGratitude: Binding<String> {
        let modele = self.modele
        return Binding.passerelle({ @MainActor in modele.gratitude },
                       { @MainActor nouveau in modele.ecrireGratitude(nouveau) })
    }

    private var liaisonTravail: Binding<String> {
        let modele = self.modele
        return Binding.passerelle({ @MainActor in modele.travail },
                       { @MainActor nouveau in modele.ecrireTravail(nouveau) })
    }

    // MARK: Les gestes

    /// « Enregistrer » : la note est écrite, puis la feuille se ferme, enregistrée ou non (Android ne montre rien
    /// d'une écriture refusée).
    private func enregistrer() {
        enregistrement = true
        let modele = self.modele
        let fermer = self.fermer
        Task { @MainActor in
            do {
                try await modele.enregistrer()
            } catch {
                // Rien de plus qu'Android : la feuille se ferme.
            }
            fermer()
        }
    }
}

// MARK: - Les pièces de la note

/// Un champ de la note (EditText) : encre `ink` sur la carte, cerclé du filet `line`, coins de 12.
private struct NoteChamp: ViewModifier {
    init() {}

    func body(content: Content) -> some View {
        content
            .font(.body)
            .foregroundStyle(Teinte(.ink))
            .tint(Teinte(.brand))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Teinte(.card), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Teinte(.line), lineWidth: 1)
            }
    }
}

/// Un bloc d'humeur : son titre (13 sp) et les cinq visages de même largeur, 44 de haut ; le visage choisi est
/// plein, les autres pâlis. VoiceOver lit « 3/5 ».
private struct NoteHumeurs: View {
    let titre: Text
    let humeurs: [String]
    let choisie: Int
    let choisir: @MainActor (Int) -> Void

    init(titre: Text, humeurs: [String], choisie: Int, choisir: @escaping @MainActor (Int) -> Void) {
        self.titre = titre
        self.humeurs = humeurs
        self.choisie = choisie
        self.choisir = choisir
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titre
                .font(.footnote)
                .foregroundStyle(Teinte(.ink))
            HStack(spacing: 0) {
                ForEach(Array(humeurs.enumerated()), id: \.offset) { rang, visage in
                    Button {
                        choisir(rang)
                    } label: {
                        Text(verbatim: visage)
                            .font(.system(size: 26))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .opacity(NoteModele.opacite(humeur: choisie, rang: rang))
                    .accessibilityLabel(Text(verbatim: NoteModele.etiquette(rang: rang)))
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}
