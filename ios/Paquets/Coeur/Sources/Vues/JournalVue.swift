import Foundation
import SwiftUI
import Coeur
import Ecrans

/// Le journal (JournalActivity.kt, activity_journal.xml, item_journal.xml) : un bandeau vert (le titre, le résumé,
/// le graphique du mois), puis les journées de la plus récente à la plus ancienne, chacune en carte ; toucher une
/// carte ouvre la note de ce jour en feuille (NoteDialog). Sans aucune journée, l'écran dit quoi faire et propose
/// de commencer une hitbodedout : la séance est un autre écran, que `ouvrir` reçoit (`JournalRoute.seance`).
/// Les notes sont couvertes quand l'app quitte le premier plan (FLAG_SECURE d'Android).
public struct JournalVue: View {
    private let modele: JournalModele
    private let ouvrir: @MainActor (JournalRoute) -> Void
    @Environment(\.traducteur) private var traducteur

    /// - Parameters:
    ///   - modele: `JournalModele(magasin:horloge:traducteur:)`.
    ///   - ouvrir: l'écran de la séance (SessionActivity), pour `JournalRoute.seance`.
    public init(modele: JournalModele, ouvrir: @escaping @MainActor (JournalRoute) -> Void) {
        self.modele = modele
        self.ouvrir = ouvrir
    }

    public var body: some View {
        VStack(spacing: 0) {
            JournalBandeauVue(titre: Text(modele.titre, traducteur: traducteur),
                              resume: Text(modele.resume, traducteur: traducteur),
                              graphique: modele.graphique)
            zone
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Teinte(.paper))
        .navigationBarTitleDisplayMode(.inline)
        .modifier(JournalVoile(actif: modele.capturesMasquees, image: modele.imageVide))
        .sheet(isPresented: noteOuverte) {
            feuilleNote
        }
        .onChange(of: modele.route, initial: true) { _, route in
            partir(route)
        }
    }

    // MARK: Sous le bandeau

    @ViewBuilder
    private var zone: some View {
        if modele.vide {
            JournalVideVue(image: modele.imageVide,
                           texte: Text(modele.texteVide, traducteur: traducteur),
                           bouton: Text(modele.boutonVide, traducteur: traducteur),
                           commencer: { modele.commencer() })
        } else {
            liste
        }
    }

    private var liste: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(modele.lignes) { ligne in
                    JournalLigneVue(ligne: ligne, langue: traducteur.langue) {
                        modele.ouvrirNote(ligne.date)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    // MARK: La note

    /// La feuille suit le modèle ; le geste de retour, quand il est permis, passe par `fermerNote()`.
    private var noteOuverte: Binding<Bool> {
        let modele = self.modele
        return Binding.passerelle({ @MainActor in modele.noteOuverte },
                       { @MainActor ouverte in
                           if !ouverte { modele.fermerNote() }
                       })
    }

    @ViewBuilder
    private var feuilleNote: some View {
        if let note = modele.note {
            JournalNoteVue(note: note, enregistrer: {
                let modele = self.modele
                Task { @MainActor in
                    do {
                        try await modele.enregistrerNote()
                    } catch {
                        // L'écriture a échoué : la feuille reste ouverte, la note gardée en mémoire (Magasin).
                    }
                }
            }, renoncer: {
                modele.fermerNote()
            })
            .modifier(JournalVoile(actif: modele.capturesMasquees, image: modele.imageVide))
        }
    }

    // MARK: La séance

    /// « Commencer » : la séance s'ouvre, et la route est consommée.
    private func partir(_ route: JournalRoute?) {
        guard let route else { return }
        modele.route = nil
        ouvrir(route)
    }
}

// MARK: Le bandeau

/// Le bandeau (activity_journal.xml) : le titre en blanc, le résumé en menthe, le graphique du mois 12 points
/// plus bas. 24 de marge sur les côtés, en haut et en bas (@dimen/edge d'un téléphone de 360 dp ou plus).
struct JournalBandeauVue: View {
    let titre: Text
    let resume: Text
    let graphique: JournalGraphique
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titre
                .font(Font.title2.bold())
                .foregroundStyle(Color.white)
                .accessibilityAddTraits(.isHeader)
            resume
                .font(.subheadline)
                .foregroundStyle(Teinte(.mint))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            JournalGraphiqueVue(graphique: graphique, libelle: libelleGraphique)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .background {
            JournalBandeauFond()
        }
    }

    /// « Les minutes de chaque jour, novembre 2026 » (contentDescription d'Android).
    private var libelleGraphique: Text {
        let mois = JournalDates.mois(graphique.mois, langue: traducteur.langue)
        return Text(graphique.accessibilite(moisNomme: mois), traducteur: traducteur)
    }
}

// MARK: L'écran vide

/// Aucune journée (activity_journal.xml, journal_empty) : le hassid qui écrit, le texte, et le bouton qui lance
/// une première hitbodedout ; centré, 32 de marge.
struct JournalVideVue: View {
    let image: String
    let texte: Text
    let bouton: Text
    let commencer: @MainActor () -> Void

    var body: some View {
        GeometryReader { geometrie in
            ScrollView {
                VStack(spacing: 0) {
                    Illustration(decorative: image, hauteur: 190)
                        .frame(width: 180)
                    texte
                        .font(.subheadline)
                        .foregroundStyle(Teinte(.muted))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                    Button {
                        commencer()
                    } label: {
                        bouton
                    }
                    .buttonStyle(.principal)
                    .padding(.top, 16)
                }
                .padding(32)
                .frame(maxWidth: .infinity, minHeight: geometrie.size.height)
            }
        }
    }
}

// MARK: Une journée

/// Une carte du journal (item_journal.xml) : la date en gras, la durée à la couleur de l'accent, puis la note et
/// le journal enrichi, s'il y en a. Toute la carte se touche ; VoiceOver la lit d'un trait.
struct JournalLigneVue: View {
    let ligne: JournalLigne
    let langue: String
    let toucher: @MainActor () -> Void
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        Button {
            toucher()
        } label: {
            carte
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var carte: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: JournalDates.ligne(ligne.date, langue: langue))
                    .font(Font.subheadline.bold())
                    .foregroundStyle(Teinte(.ink))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(ligne.duree, traducteur: traducteur)
                    .font(Font.subheadline.bold())
                    .foregroundStyle(Teinte(.brand))
            }
            if let note = ligne.note {
                Text(verbatim: note)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.muted))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Teinte(.card), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Teinte(.line), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
