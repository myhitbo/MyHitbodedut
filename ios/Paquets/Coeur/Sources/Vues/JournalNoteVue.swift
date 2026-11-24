import Foundation
import SwiftUI
import Coeur
import Ecrans

/// La note d'un jour (NoteDialog.kt d'Android), en feuille : le hassid qui écrit, la note libre, l'humeur avant
/// et après, une gratitude et une chose à travailler. « Enregistrer » et le bouton de renoncement (« Plus tard »,
/// ou « Ne pas enregistrer » dès que la note a changé) sont confiés à l'écran qui l'ouvre : le journal, ou la
/// séance après le bravo. Un toucher à côté ne ferme jamais la feuille ; le geste de retour la ferme seulement
/// tant que la note n'a pas changé (`fermableParGeste`).
public struct JournalNoteVue: View {
    private let note: JournalNoteModele
    private let enregistrer: @MainActor () -> Void
    private let renoncer: @MainActor () -> Void
    @Environment(\.traducteur) private var traducteur

    /// - Parameters:
    ///   - note: la note ouverte (`JournalModele.note`).
    ///   - enregistrer: « Enregistrer » (`JournalModele.enregistrerNote`, la feuille se ferme si l'écriture réussit).
    ///   - renoncer: « Plus tard » ou « Ne pas enregistrer » (`JournalModele.fermerNote`).
    public init(note: JournalNoteModele, enregistrer: @escaping @MainActor () -> Void,
                renoncer: @escaping @MainActor () -> Void) {
        self.note = note
        self.enregistrer = enregistrer
        self.renoncer = renoncer
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                contenu
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Teinte(.card))
            .navigationTitle(Text(note.titre, traducteur: traducteur))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        renoncer()
                    } label: {
                        Text(note.boutonRenoncer, traducteur: traducteur)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        enregistrer()
                    } label: {
                        Text(note.boutonEnregistrer, traducteur: traducteur)
                    }
                }
            }
        }
        .tint(Teinte(.brand))
        .interactiveDismissDisabled(!note.fermableParGeste)
    }

    private var contenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            Illustration(decorative: note.image, hauteur: 120)
                .frame(maxWidth: .infinity)
            champNote
                .padding(.top, 8)
            JournalHumeursVue(titre: Text(note.titreAvant, traducteur: traducteur),
                              choisie: { rang in note.avantChoisi(rang) },
                              toucher: { rang in note.toucherAvant(rang) })
            JournalHumeursVue(titre: Text(note.titreApres, traducteur: traducteur),
                              choisie: { rang in note.apresChoisi(rang) },
                              toucher: { rang in note.toucherApres(rang) })
            JournalChampVue(texte: liaisonGratitude, indication: traducteur.texte(note.indicationGratitude))
                .padding(.top, 12)
            JournalChampVue(texte: liaisonTravail, indication: traducteur.texte(note.indicationTravail))
                .padding(.top, 8)
        }
    }

    /// Le champ de la note : quatre lignes visibles, le texte en haut, au début de la ligne.
    private var champNote: some View {
        let indication = traducteur.texte(note.indicationNote)
        return TextField(text: liaisonNote, prompt: Text(verbatim: indication), axis: .vertical) {
            Text(verbatim: indication)
        }
        .lineLimit(4, reservesSpace: true)
        .font(.body)
        .foregroundStyle(Teinte(.ink))
        .padding(12)
        .background(Teinte(.paper), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Teinte(.line), lineWidth: 1)
        }
    }

    // MARK: Les liaisons

    private var liaisonNote: Binding<String> {
        let note = self.note
        return Binding(get: { @MainActor in note.note },
                       set: { @MainActor texte in note.modifierNote(texte) })
    }

    private var liaisonGratitude: Binding<String> {
        let note = self.note
        return Binding(get: { @MainActor in note.gratitude },
                       set: { @MainActor texte in note.modifierGratitude(texte) })
    }

    private var liaisonTravail: Binding<String> {
        let note = self.note
        return Binding(get: { @MainActor in note.travail },
                       set: { @MainActor texte in note.modifierTravail(texte) })
    }
}

/// Une rangée d'humeurs (JournalPlus.HUMEURS) : son titre en 13, puis les cinq émojis en parts égales, 44 de
/// haut ; l'humeur choisie est pleine, les autres pâlies. Toucher la choisie la retire.
struct JournalHumeursVue: View {
    let titre: Text
    let choisie: @MainActor (Int) -> Bool
    let toucher: @MainActor (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titre
                .font(.footnote)
                .foregroundStyle(Teinte(.ink))
                .padding(.top, 8)
            HStack(spacing: 0) {
                ForEach(JournalNoteModele.humeurs) { humeur in
                    bouton(humeur)
                }
            }
        }
    }

    private func bouton(_ humeur: JournalHumeur) -> some View {
        let oui = choisie(humeur.rang)
        return Button {
            toucher(humeur.rang)
        } label: {
            Text(verbatim: humeur.emoji)
                .font(.title)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(oui ? JournalNoteModele.opaciteChoisie : JournalNoteModele.opaciteAutre)
        .accessibilityLabel(Text(verbatim: humeur.accessibilite))
        .accessibilityAddTraits(oui ? AccessibilityTraits.isSelected : [])
    }
}

/// Un champ d'une ligne (la gratitude, la chose à travailler), son indication en attente.
struct JournalChampVue: View {
    let texte: Binding<String>
    let indication: String

    var body: some View {
        TextField(text: texte, prompt: Text(verbatim: indication)) {
            Text(verbatim: indication)
        }
        .font(.body)
        .foregroundStyle(Teinte(.ink))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Teinte(.paper), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Teinte(.line), lineWidth: 1)
        }
    }
}
