import Foundation
import SwiftUI
import UIKit
import Coeur
import Ecrans

// La séance (SessionActivity.kt, activity_session.xml) et le bravo (CelebrationActivity.kt). Les vues lisent
// `SeanceModele` et `CelebrationModele` (testés sous Linux) ; la séance elle-même vit dans `SeanceEnCours`, partagée
// par l'app : elle continue quand l'écran se ferme.

// MARK: - La séance

/// L'écran de séance : le hassid, le grand chiffre (la durée, ou le décompte), la légende, la musique, le sujet ;
/// avant la séance, les durées, « Sans durée » et « Commencer simplement » ; pendant, « Terminer », « Abandonner »,
/// « Je n'arrive pas à parler », la question, la hitbodedout guidée, et le mot de 'hizouk du moment. Rien ne bouge
/// sans un toucher : l'écran s'efface au bout de six secondes (la pratique calme) et revient d'un toucher.
public struct SeanceVue: View {
    private let modele: SeanceModele
    private let demande: SeanceDemande
    private let fabriqueCelebration: @MainActor (CelebrationDemande) -> CelebrationModele
    private let fabriqueNote: @MainActor (JourCivil) -> JournalNoteModele
    private let ouvrirTefilot: @MainActor () -> Void
    /// Le mini-lecteur de la pratique (MiniLecteur.kt), sur la musique de la séance ; nil : pas de mini-lecteur.
    private let mini: MusiqueMiniLecteurModele?
    @Environment(\.traducteur) private var traducteur
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.dismiss) private var fermerEcran

    /// `demande` : `.commencer` quand l'écran s'ouvre pour lancer la séance (EXTRA_START_NOW). `mini` : le mini-lecteur
    /// de l'app, posé au bas de l'écran pendant la séance.
    public init(modele: SeanceModele, demande: SeanceDemande,
                celebration: @escaping @MainActor (CelebrationDemande) -> CelebrationModele,
                note: @escaping @MainActor (JourCivil) -> JournalNoteModele,
                tefilot: @escaping @MainActor () -> Void,
                mini: MusiqueMiniLecteurModele? = nil) {
        self.modele = modele
        self.demande = demande
        fabriqueCelebration = celebration
        fabriqueNote = note
        ouvrirTefilot = tefilot
        self.mini = mini
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Illustration(decorative: modele.image, hauteur: 150)
                    .frame(maxWidth: .infinity)
                decompte
                Text(modele.legende, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.muted))
                    .multilineTextAlignment(.center)
                Group {
                    if let musique = modele.ligneMusique {
                        Text(musique, traducteur: traducteur)
                            .font(.footnote)
                            .foregroundStyle(Teinte(.muted))
                    }
                    Button {
                        modele.choisirSujet()
                    } label: {
                        Text(modele.libelleSujet, traducteur: traducteur)
                            .font(Font.subheadline.weight(.medium))
                            .foregroundStyle(Teinte(.brand))
                            .frame(minHeight: 44)
                    }
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    if modele.choixVisibles {
                        choix
                    }
                    boutons
                    if let question = modele.question {
                        questionVue(question)
                    }
                    if let guide = modele.guide {
                        guideVue(guide)
                    }
                    if let carte = modele.carte {
                        SeanceCarteVue(carte: carte)
                    }
                }
                .opacity(modele.opaciteEffacable)
                // Effacé au calme, il sort aussi de l'accessibilité (VoiceOver allumé, le calme ne vient pas).
                .accessibilityHidden(modele.calme)
                .animation(.easeInOut(duration: Double(modele.calme ? SeanceModele.fonduCalme : SeanceModele.fonduReveil) / 1000),
                           value: modele.calme)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            // Le disque du mini-lecteur ne cache pas le bas de la page (64 pt et ses marges).
            .padding(.bottom, mini?.visible == true ? 96 : 0)
        }
        .background(Teinte(.paper))
        .background(modele.calme ? Color.black.opacity(SeanceModele.assombrissement) : Color.clear)
        // Le mini-lecteur (19/10) : changer de morceau sans quitter la pratique. Hors de ce qui s'efface : la pratique
        // calme le laisse paraître (PratiqueCalme, `restes`).
        .overlay {
            if let mini {
                MusiqueMiniLecteurVue(mini: mini)
            }
        }
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .simultaneousGesture(TapGesture().onEnded { modele.toucher() })
        .sheet(item: Bindable(modele).dialogueLie) { dialogue in
            SeanceBoite(modele: modele, dialogue: dialogue)
                .hauteursDeFeuille([.medium, .large])
        }
        .sheet(item: Bindable(modele).noteLiee) { route in
            if case .note(let jour) = route {
                SeanceNote(modele: fabriqueNote(jour)) { modele.fermerRoute() }
            }
        }
        .fullScreenCover(item: Bindable(modele).celebrationLiee) { route in
            if case .celebration(let demandeBravo) = route {
                CelebrationEcran(modele: fabriqueCelebration(demandeBravo), note: fabriqueNote) {
                    modele.fermerRoute()
                    fermerEcran()
                }
            }
        }
        .onChange(of: modele.route) { _, route in
            if route == .tefilot {
                modele.fermerRoute()
                ouvrirTefilot()
            }
        }
        .task {
            await modele.ouvrir(demande)
            // Le tour d'une seconde d'Android (tick) : la fin de la séance, la pratique calme.
            while !Task.isCancelled {
                guard await AccueilAttente.ms(1_000) else { break }
                await modele.actualiser()
            }
        }
        .onChange(of: phase) { _, nouvelle in
            if nouvelle == .active { Task { await modele.revenir() } }
        }
        .onChange(of: voiceOver, initial: true) { _, actif in
            modele.lecteurEcranChange(actif)
        }
        // Allumé tant que la séance est montrée ; en partant, l'écran revient à ce que demandent les autres
        // (EcranAllume : un défilement automatique encore en marche derrière).
        .onAppear { EcranAllume.garder(modele.garderEcranAllume, pour: "seance") }
        .onDisappear { EcranAllume.garder(false, pour: "seance") }
    }

    /// Le grand chiffre : la durée de la prochaine, le temps qui reste ou le temps écoulé ; rien s'il est masqué.
    @ViewBuilder
    private var decompte: some View {
        switch modele.decompte {
        case .duree(let libelle):
            Text(libelle, traducteur: traducteur)
                .tailleSp(56, poids: .bold, relativeA: .largeTitle)
                .monospacedDigit()
                .foregroundStyle(Teinte(.ink))
        case .reste, .ecoule:
            TimelineView(.periodic(from: .now, by: 1)) { contexte in
                let millis = Int64((contexte.date.timeIntervalSince1970 * 1000).rounded())
                Text(verbatim: modele.texteDecompte(a: millis) ?? "")
                    .tailleSp(64, poids: .bold, relativeA: .largeTitle)
                    .monospacedDigit()
                    .foregroundStyle(Teinte(.ink))
                    .environment(\.layoutDirection, .leftToRight)
            }
            .accessibilityLabel(Text(modele.decompteAccessible ?? Libelle("session_screen_title"), traducteur: traducteur))
        case .masque:
            EmptyView()
        }
    }

    /// Avant la séance : les durées proposées, « Durée réglable… », « Sans durée », puis « Commencer simplement ».
    private var choix: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                ForEach(modele.durees) { duree in
                    Button {
                        Task { try? await modele.commencer(minutes: duree.minutes) }
                    } label: {
                        Text(duree.libelle, traducteur: traducteur)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.secondaire)
                }
            }
            HStack(spacing: 8) {
                Button {
                    modele.saisirDuree()
                } label: {
                    Text(modele.libelleDureeReglable, traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
                Button {
                    Task { try? await modele.commencerSansDuree() }
                } label: {
                    Text(modele.libelleSansDuree, traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
            }
            let simplement = modele.libellesSimplement
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(Array(simplement.enumerated()), id: \.offset) { rang, libelle in
                    Button {
                        simplementCommencer(rang)
                    } label: {
                        Text(libelle, traducteur: traducteur)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.secondaire)
                }
            }
        }
    }

    private func simplementCommencer(_ rang: Int) {
        Task {
            switch rang {
            case 0: try? await modele.simplementParler()
            case 1: try? await modele.simplementEcrire()
            case 2: try? await modele.simplementPrier()
            default: try? await modele.simplementQuestion()
            }
        }
    }

    private var boutons: some View {
        VStack(spacing: 8) {
            Button {
                Task { try? await modele.principal() }
            } label: {
                Text(modele.libellePrincipal, traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principalGrand)
            if let secondaire = modele.libelleSecondaire {
                Button {
                    modele.secondaire()
                } label: {
                    Text(secondaire, traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
            }
            if modele.blocageVisible {
                Button {
                    Task { await modele.bloque() }
                } label: {
                    Text(modele.libelleBlocage, traducteur: traducteur)
                        .font(Font.subheadline.weight(.medium))
                        .foregroundStyle(Teinte(.brand))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .contentShape(Rectangle())
                .buttonStyle(.plain)
            }
        }
    }

    /// Une question pour se lancer (QuestionsBlocage) : son rang, la barre, « Question suivante ».
    private func questionVue(_ question: SeanceQuestion) -> some View {
        Carte {
            Text(question.position, traducteur: traducteur)
                .font(.caption)
                .foregroundStyle(Teinte(.muted))
            ProgressView(value: Double(question.progression), total: 100)
                .tint(Teinte(.brand))
                .padding(.vertical, 6)
            Text(question.texte, traducteur: traducteur)
                .font(Font.body.weight(.medium))
                .foregroundStyle(Teinte(.ink))
            Button {
                modele.questionSuivante()
            } label: {
                Text(modele.libelleQuestionSuivante, traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondaire)
            .padding(.top, 10)
        }
    }

    /// La hitbodedout guidée (view_hitbodedut.xml) : le temps, son nom hébreu, l'invitation, la source.
    private func guideVue(_ guide: SeanceGuide) -> some View {
        Carte {
            HStack(spacing: 12) {
                Illustration(decorative: guide.image, hauteur: 64)
                    .frame(width: 54, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text(guide.rang, traducteur: traducteur)
                        .font(.caption)
                        .foregroundStyle(Teinte(.muted))
                    Text(verbatim: guide.hebreu)
                        .policeHebraique(.serif, taille: 20, relativeA: .title3)
                        .foregroundStyle(Teinte(.ink))
                        .environment(\.layoutDirection, .rightToLeft)
                    Text(guide.titre, traducteur: traducteur)
                        .font(Font.subheadline.bold())
                        .foregroundStyle(Teinte(.brand))
                }
            }
            Text(guide.invitation, traducteur: traducteur)
                .font(.subheadline)
                .foregroundStyle(Teinte(.ink))
                .padding(.top, 8)
            if let sujet = guide.sujet {
                Text(verbatim: sujet)
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(Teinte(.ink))
                    .padding(.top, 4)
            }
            Text(verbatim: guide.source)
                .font(.caption)
                .foregroundStyle(Teinte(.muted))
                .padding(.top, 4)
            HStack {
                if guide.precedentVisible {
                    Button {
                        modele.guidePrecedent()
                    } label: {
                        Text(modele.libelleGuidePrecedent, traducteur: traducteur)
                    }
                    .buttonStyle(.secondaire)
                }
                Spacer(minLength: 8)
                if guide.suivantVisible {
                    Button {
                        modele.guideSuivant()
                    } label: {
                        Text(modele.libelleGuideSuivant, traducteur: traducteur)
                    }
                    .buttonStyle(.principal)
                }
            }
            .padding(.top, 10)
        }
    }
}

extension SeanceModele {
    var dialogueLie: SeanceDialogue? {
        get { dialogue }
        set { dialogue = newValue }
    }

    /// La note du jour, par-dessus la séance (« Écrire »).
    var noteLiee: SeanceRoute? {
        get {
            if case .note = route { return route }
            return nil
        }
        set { if newValue == nil, case .note = route { fermerRoute() } }
    }

    /// Le bravo, ou « ’Hazak » après un abandon.
    var celebrationLiee: SeanceRoute? {
        get {
            if case .celebration = route { return route }
            return nil
        }
        set { if newValue == nil, case .celebration = route { fermerRoute() } }
    }
}

/// Le mot de 'hizouk de la séance (view_chizuk.xml) : le moment, le texte (hébreu ou traduction), la traduction, la
/// source.
struct SeanceCarteVue: View {
    let carte: SeanceCarteChizuk
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        Carte {
            HStack(spacing: 12) {
                Illustration(decorative: carte.image, hauteur: 64)
                    .frame(width: 54, height: 64)
                Text(carte.titre, traducteur: traducteur)
                    .font(Font.subheadline.bold())
                    .foregroundStyle(Teinte(.brand))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(verbatim: carte.texte)
                .policeHebraique(carte.texteDroiteAGauche ? .serif : .sans, taille: carte.texteDroiteAGauche ? 19 : 17)
                .foregroundStyle(Teinte(.ink))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, carte.texteDroiteAGauche ? .rightToLeft : .leftToRight)
                .padding(.top, 10)
            if let second = carte.second {
                Divider().overlay(Teinte(.line)).padding(.vertical, 8)
                Text(verbatim: second)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.muted))
            }
            Text(verbatim: carte.reference)
                .font(.caption2)
                .foregroundStyle(Teinte(.muted))
                .padding(.top, 8)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Les boîtes de la séance : terminer, abandonner, le sujet, la durée réglable.
private struct SeanceBoite: View {
    let modele: SeanceModele
    let dialogue: SeanceDialogue
    @Environment(\.traducteur) private var traducteur
    @State private var saisie = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(dialogue.titre, traducteur: traducteur)
                    .tailleSp(20, poids: .bold, relativeA: .title3)
                    .foregroundStyle(Teinte(.ink))
                if let message = dialogue.message {
                    Text(message, traducteur: traducteur)
                        .font(.body)
                        .foregroundStyle(Teinte(.ink))
                }
                contenu
                if let retour = dialogue.retour {
                    Button {
                        modele.dialogue = nil
                    } label: {
                        Text(retour, traducteur: traducteur)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.secondaire)
                }
            }
            .padding(24)
        }
        .background(Teinte(.paper))
    }

    @ViewBuilder
    private var contenu: some View {
        switch dialogue {
        case .terminer:
            confirmer { _ = try? await modele.confirmerTerminer() }
        case .abandonner:
            confirmer { _ = try? await modele.confirmerAbandonner() }
        case .sujet:
            ForEach(modele.choixSujets) { choix in
                Button {
                    Task { try? await modele.choisirSujet(choix.theme) }
                } label: {
                    HStack {
                        Text(choix.libelle, traducteur: traducteur)
                            .foregroundStyle(Teinte(.ink))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if choix.theme == modele.sujetChoisi {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Teinte(.brand))
                        }
                    }
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        case .duree:
            TextField(text: $saisie, axis: .vertical) {
                Text(modele.indicationDuree, traducteur: traducteur)
            }
            .keyboardType(.numberPad)
            .textFieldStyle(.roundedBorder)
            .onAppear { saisie = modele.saisieInitiale }
            Text(modele.erreurSaisie ?? modele.indicationDuree, traducteur: traducteur)
                .font(.footnote)
                .foregroundStyle(modele.erreurSaisie == nil ? ReglagesTeinte.nommee("muted")
                    : ReglagesTeinte.nommee("warning"))
            confirmer {
                let texte = saisie
                try? await modele.validerDuree(texte)
            }
        }
    }

    @ViewBuilder
    private func confirmer(_ action: @escaping @MainActor () async -> Void) -> some View {
        if let libelle = dialogue.confirmer {
            Button(role: dialogue.destructif ? .destructive : nil) {
                Task { await action() }
            } label: {
                Text(libelle, traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principal)
        }
    }
}

/// La note du jour par-dessus la séance : le modèle gardé le temps de la feuille.
private struct SeanceNote: View {
    @State private var modele: JournalNoteModele
    private let fermer: @MainActor () -> Void

    init(modele: JournalNoteModele, fermer: @escaping @MainActor () -> Void) {
        _modele = State(initialValue: modele)
        self.fermer = fermer
    }

    var body: some View {
        JournalNoteVue(modele: modele, enregistrer: {
            do {
                try await modele.enregistrer()
                fermer()
            } catch {
                // La fenêtre reste ouverte ; le changement reste en mémoire (Magasin).
            }
        }, fermer: fermer)
    }
}

// MARK: - Le bravo

/// Le bravo de fin de séance, ou « ’Hazak » après un abandon (CelebrationActivity) : le titre, les minutes, le
/// danseur, le mot de relance après un abandon, « Continuer » (qui propose la note du jour) et le partage.
public struct CelebrationEcran: View {
    @State private var modele: CelebrationModele
    private let fabriqueNote: @MainActor (JourCivil) -> JournalNoteModele
    private let fermer: @MainActor () -> Void
    @State private var note: SeanceJour? = nil
    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var reduire

    public init(modele: CelebrationModele, note: @escaping @MainActor (JourCivil) -> JournalNoteModele,
                fermer: @escaping @MainActor () -> Void) {
        _modele = State(initialValue: modele)
        fabriqueNote = note
        self.fermer = fermer
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(modele.titre, traducteur: traducteur)
                    .tailleSp(34, poids: .bold, relativeA: .largeTitle)
                    .foregroundStyle(Teinte(.brand))
                    .multilineTextAlignment(.center)
                    .padding(.top, 32)
                if let sous = modele.sousTitre {
                    Text(sous, traducteur: traducteur)
                        .font(.title3)
                        .foregroundStyle(Teinte(.ink))
                        .multilineTextAlignment(.center)
                }
                danseur
                    .frame(height: 220)
                if let carte = modele.carte {
                    SeanceCarteVue(carte: carte)
                }
                Button {
                    switch modele.continuer() {
                    case .fermer: fermer()
                    case .note(let jour): note = SeanceJour(jour: jour)
                    }
                } label: {
                    Text(modele.libelleContinuer, traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.principalGrand)
                if modele.partageVisible {
                    ShareLink(item: modele.textePartage { traducteur.texte($0) }) {
                        Text(modele.libellePartager, traducteur: traducteur)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.secondaire)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Teinte(.paper))
        .task { await modele.charger() }
        .sheet(item: $note, onDismiss: fermer) { choisi in
            SeanceNote(modele: fabriqueNote(choisi.jour)) { note = nil }
        }
    }

    /// Le danseur : deux poses qui alternent au temps de la danse (DanseMesure), immobile sans animations.
    @ViewBuilder
    private var danseur: some View {
        if let poseB = modele.poseB, modele.danse, !reduire {
            TimelineView(.periodic(from: .now, by: Double(DanseMesure.tempsMs) / 1000)) { contexte in
                let temps = Int64(contexte.date.timeIntervalSince1970 * 1000) / DanseMesure.tempsMs
                Illustration(decorative: temps % 2 == 0 ? modele.poseA : poseB, hauteur: 220)
            }
        } else {
            Illustration(decorative: modele.poseA, hauteur: 220)
        }
    }
}

/// Un jour, pour une feuille présentée par `sheet(item:)`.
struct SeanceJour: Identifiable, Hashable {
    let jour: JourCivil
    var id: String { jour.iso }
}
