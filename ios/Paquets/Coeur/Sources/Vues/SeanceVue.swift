import Foundation
import SwiftUI
import UIKit
import Coeur
import Ecrans

/// L'écran de séance (SessionActivity.kt, activity_session.xml) : sur le vert sombre, le titre, la scène du
/// personnage, le grand chiffre et sa lueur, la légende, la musique, « Commencer » ou « Terminer maintenant »,
/// « Abandonner », le sujet, les durées et « Commencer simplement » à l'arrêt ; puis la carte de 'hizouk, la
/// hitbodedout guidée, « Je n'arrive pas à parler » et ses questions. En paysage, deux colonnes (layout-land).
/// Tout se décide dans `SeanceModele` ; la séance elle-même vit dans la `SeanceEnCours` partagée de l'app.
///
/// La vue appelle `ouvrir(demande)` à sa première apparition, `revenir()` aux suivantes et au retour au premier
/// plan, et `actualiser()` chaque seconde tant qu'elle est montrée. Elle présente elle-même le bravo (plein écran)
/// et la note (feuille) ; les prières sont un autre écran : `ouvrir(.tefilot)`.
public struct SeanceVue: View {
    private let modele: SeanceModele
    private let demande: SeanceDemande
    private let mini: MusiqueMiniLecteurModele?
    private let celebration: @MainActor (CelebrationDemande) -> CelebrationModele
    private let note: @MainActor (JourCivil) -> NoteModele
    private let ouvrir: @MainActor (SeanceRoute) -> Void

    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var reduireAnimations
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.verticalSizeClass) private var classeVerticale
    @Environment(\.scenePhase) private var phaseScene

    /// `ouvrir(demande)` n'est appelé qu'une fois (onCreate) ; les apparitions suivantes sont des `revenir()`.
    @State private var ouvert = false
    /// La taille de l'écran de séance : les marges (dimen edge), la hauteur de la scène, le rayon de la lueur.
    @State private var taille: CGSize = .zero
    /// Le texte du champ de la durée réglable.
    @State private var saisieDuree = ""
    /// Le bravo présenté, et la note présentée.
    @State private var bravo: SeanceBravo? = nil
    @State private var noteOuverte: SeanceNoteOuverte? = nil
    /// Quand le dernier dialogue s'est fermé : le bravo attend que son alerte se soit retirée.
    @State private var fermetureDialogue: Date? = nil

    /// Le temps qu'une alerte met à se retirer, en secondes.
    private static let retraitAlerte = 0.45

    /// - Parameters:
    ///   - modele: `SeanceModele(seance:contenus:langue:debug:)`, sur la `SeanceEnCours` partagée de l'app.
    ///   - demande: `.commencer` depuis « Commencer » de l'accueil, un rappel, le bouclier ou un raccourci
    ///     (EXTRA_START_NOW) ; `.aucune` sinon.
    ///   - mini: le mini-lecteur de la pratique, posé en surimpression ; nil sans musique.
    ///   - celebration: le modèle du bravo (`CelebrationModele(demande:magasin:contenus:horloge:langue:debug:)`).
    ///   - note: le modèle de la note d'un jour (`NoteModele(date:magasin:)`).
    ///   - ouvrir: les autres écrans de l'app ; seul `.tefilot` (« Prier ») y arrive.
    public init(modele: SeanceModele,
                demande: SeanceDemande = .aucune,
                mini: MusiqueMiniLecteurModele? = nil,
                celebration: @escaping @MainActor (CelebrationDemande) -> CelebrationModele,
                note: @escaping @MainActor (JourCivil) -> NoteModele,
                ouvrir: @escaping @MainActor (SeanceRoute) -> Void) {
        self.modele = modele
        self.demande = demande
        self.mini = mini
        self.celebration = celebration
        self.note = note
        self.ouvrir = ouvrir
    }

    public var body: some View {
        presentations
            .task {
                await vivre()
            }
            .onChange(of: phaseScene) { _, phase in
                // onResume d'Android : le décompte a pu finir pendant que l'app dormait.
                if phase == .active {
                    Task { await modele.revenir() }
                }
            }
            .onChange(of: voiceOver, initial: true) { _, actif in
                modele.lecteurEcranChange(actif)
            }
            .onChange(of: modele.route, initial: true) { _, route in
                suivre(route)
            }
            .onChange(of: modele.dialogue) { ancien, dialogue in
                if dialogue == .duree {
                    saisieDuree = modele.saisieInitiale
                }
                if ancien != nil && dialogue == nil {
                    fermetureDialogue = Date()
                }
            }
            .onAppear {
                // FLAG_KEEP_SCREEN_ON : tant que l'écran de séance est montré.
                UIApplication.shared.isIdleTimerDisabled = modele.garderEcranAllume
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
    }

    // MARK: La vie de l'écran

    /// La première apparition ouvre l'écran (et lance la séance demandée) ; les suivantes le reprennent. Puis le
    /// tour de chaque seconde, tant que l'écran est montré (`.task` s'arrête quand il disparaît).
    private func vivre() async {
        if ouvert {
            await modele.revenir()
        } else {
            ouvert = true
            await modele.ouvrir(demande)
        }
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
            await modele.actualiser()
        }
    }

    /// L'écran que le modèle ouvre. Le bravo attend qu'une alerte ouverte, ou qui vient de se fermer (« Terminer
    /// maintenant » confirmé), se soit retirée : SwiftUI ne présente pas par-dessus une alerte.
    private func suivre(_ route: SeanceRoute?) {
        guard let route else { return }
        switch route {
        case .celebration(let demande):
            guard bravo == nil else { return }
            if modele.dialogue != nil {
                modele.dialogue = nil
                presenterBravo(demande, apres: SeanceVue.retraitAlerte)
            } else if let fermeture = fermetureDialogue,
                      Date().timeIntervalSince(fermeture) < SeanceVue.retraitAlerte {
                presenterBravo(demande, apres: SeanceVue.retraitAlerte - Date().timeIntervalSince(fermeture))
            } else {
                bravo = SeanceBravo(demande: demande)
            }
        case .note(let jour):
            noteOuverte = SeanceNoteOuverte(date: jour)
        case .tefilot:
            modele.fermerRoute()
            ouvrir(.tefilot)
        }
    }

    private func presenterBravo(_ demande: CelebrationDemande, apres delai: TimeInterval) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(max(delai, 0)))
            if bravo == nil {
                bravo = SeanceBravo(demande: demande)
            }
        }
    }

    // MARK: Les présentations

    private var presentations: some View {
        ecran
            .alert(Text(SeanceDialogue.terminer.titre, traducteur: traducteur),
                   isPresented: dialogueOuvert(.terminer)) {
                actionsConfirmation(.terminer)
            } message: {
                messageDialogue(.terminer)
            }
            .alert(Text(SeanceDialogue.abandonner.titre, traducteur: traducteur),
                   isPresented: dialogueOuvert(.abandonner)) {
                actionsConfirmation(.abandonner)
            } message: {
                messageDialogue(.abandonner)
            }
            .alert(Text(SeanceDialogue.duree.titre, traducteur: traducteur),
                   isPresented: dialogueOuvert(.duree)) {
                actionsDuree
            }
            .sheet(isPresented: dialogueOuvert(.sujet)) {
                SeanceListeSujets(modele: modele)
            }
            .sheet(item: $noteOuverte, onDismiss: { modele.fermerRoute() }) { ouverte in
                NotePage(date: ouverte.date, fabrique: note)
            }
            .fullScreenCover(item: $bravo, onDismiss: { modele.fermerRoute() }) { presente in
                CelebrationPage(demande: presente.demande, fabrique: celebration, note: note)
            }
    }

    /// Un dialogue suit `modele.dialogue` ; le fermer (« Retour », un geste) le remet à nil.
    private func dialogueOuvert(_ dialogue: SeanceDialogue) -> Binding<Bool> {
        let modele = self.modele
        return Binding(get: { @MainActor in modele.dialogue == dialogue },
                       set: { @MainActor montre in
                           if !montre && modele.dialogue == dialogue {
                               modele.dialogue = nil
                           }
                       })
    }

    @ViewBuilder
    private func actionsConfirmation(_ dialogue: SeanceDialogue) -> some View {
        if let confirmer = dialogue.confirmer {
            Button(role: dialogue.destructif ? ButtonRole.destructive : nil) {
                confirmerDialogue(dialogue)
            } label: {
                Text(confirmer, traducteur: traducteur)
            }
        }
        if let retour = dialogue.retour {
            Button(role: .cancel) {
                modele.dialogue = nil
            } label: {
                Text(retour, traducteur: traducteur)
            }
        }
    }

    @ViewBuilder
    private func messageDialogue(_ dialogue: SeanceDialogue) -> some View {
        if let message = dialogue.message {
            Text(message, traducteur: traducteur)
        }
    }

    private func confirmerDialogue(_ dialogue: SeanceDialogue) {
        let modele = self.modele
        Task {
            do {
                if dialogue == .abandonner {
                    try await modele.confirmerAbandonner()
                } else {
                    try await modele.confirmerTerminer()
                }
            } catch {
                // Rien de plus qu'Android : la séance est close, son écriture se refera.
            }
        }
    }

    /// Le champ de la durée réglable (DureeSeance.saisir) : un nombre de minutes, prérempli de la durée habituelle.
    @ViewBuilder
    private var actionsDuree: some View {
        TextField(text: $saisieDuree, prompt: Text(modele.indicationDuree, traducteur: traducteur)) {
            Text(modele.indicationDuree, traducteur: traducteur)
        }
        .keyboardType(.numberPad)
        if let confirmer = SeanceDialogue.duree.confirmer {
            Button {
                let texte = saisieDuree
                let modele = self.modele
                Task {
                    do {
                        try await modele.validerDuree(texte)
                    } catch {
                        // La séance est partie ; la durée habituelle s'écrira à la prochaine.
                    }
                }
            } label: {
                Text(confirmer, traducteur: traducteur)
            }
        }
        if let retour = SeanceDialogue.duree.retour {
            Button(role: .cancel) {
                modele.dialogue = nil
            } label: {
                Text(retour, traducteur: traducteur)
            }
        }
    }

    // MARK: L'écran

    /// Le défilement sur son fond, le mini-lecteur par-dessus, et au calme la vitre qui prend le toucher.
    private var ecranNu: some View {
        defilement
            .background {
                fond
            }
            .overlay {
                if let mini {
                    MusiqueMiniLecteurVue(mini: mini)
                }
            }
            .overlay {
                captureCalme
            }
            .onGeometryChange(for: CGSize.self) { geometrie in
                geometrie.size
            } action: { nouvelle in
                taille = nouvelle
            }
    }

    /// Un toucher réveille la pratique ; au calme, les barres du système se cachent.
    private var ecran: some View {
        ecranNu
            .simultaneousGesture(TapGesture().onEnded {
                modele.toucher()
            })
            .statusBarHidden(modele.calme)
            .persistentSystemOverlays(modele.calme ? .hidden : .automatic)
            .navigationBarBackButtonHidden(modele.calme)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    /// Le vert sombre de la séance ; au calme, mêlé de noir à 55 %.
    private var fond: some View {
        Rectangle()
            .fill(Teinte(.brandDark))
            .overlay {
                Color.black.opacity(modele.calme ? SeanceModele.assombrissement : 0)
            }
            .animation(animationCalme, value: modele.calme)
            .ignoresSafeArea()
    }

    /// Au calme, un toucher n'importe où réveille l'écran et s'arrête là : on ne touche pas un bouton qu'on ne
    /// voyait pas (dispatchTouchEvent avalé).
    @ViewBuilder
    private var captureCalme: some View {
        if modele.calme {
            Color.clear
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { _ in
                    modele.toucher()
                })
                .ignoresSafeArea()
                .accessibilityHidden(true)
        }
    }

    private var defilement: some View {
        ScrollView {
            Group {
                if classeVerticale == .compact {
                    paysage
                } else {
                    portrait
                }
            }
            .padding(.horizontal, marge)
            .frame(maxWidth: .infinity, minHeight: 400)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onScrollPhaseChange { _, phase in
            if phase.isScrolling {
                modele.toucher()
            }
        }
    }

    /// Une colonne centrée (activity_session.xml).
    private var portrait: some View {
        VStack(spacing: 0) {
            titre
            scene
                .padding(.top, 16)
            blocChiffre
                // Derrière tout le reste, comme SouffleView sous la colonne d'Android : la lueur déborde.
                .zIndex(-1)
            legende
            musique
            boutonPrincipal
                .padding(.top, 16)
            boutonSecondaire
            boutonSujet
            choix
            carteChizuk
            guide
            blocage(pastille: true)
            question
        }
        .padding(.top, 24)
        .padding(.bottom, 104)
    }

    /// Deux colonnes de même largeur (layout-land/activity_session.xml) : la pratique à gauche, les commandes à
    /// droite.
    private var paysage: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(spacing: 0) {
                titre
                scene
                    .padding(.top, 16)
                blocChiffre
                    .zIndex(-1)
                legende
                musique
                carteChizuk
                guide
                blocage(pastille: false)
                question
            }
            .frame(maxWidth: .infinity)
            VStack(spacing: 0) {
                boutonPrincipal
                boutonSecondaire
                boutonSujet
                choix
            }
            .padding(.top, 24)
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
    }

    // MARK: Les éléments

    private var titre: some View {
        Text(modele.titre, traducteur: traducteur)
            .font(.footnote)
            .tracking(13 * 0.14)
            .foregroundStyle(Teinte(.mint))
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
            .modifier(effacable)
    }

    /// La scène (bg_stage) : le personnage du jour, qui ne change jamais sous les yeux.
    private var scene: some View {
        Illustration(decorative: modele.image, hauteur: hauteurScene)
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(Teinte(.mint), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .modifier(effacable)
    }

    /// Le grand chiffre et, derrière, la lueur du souffle ; rien quand le décompte est masqué (GONE). Il reste au
    /// calme.
    @ViewBuilder
    private var blocChiffre: some View {
        switch modele.decompte {
        case .masque:
            EmptyView()
        case .duree(let duree):
            habillerChiffre(Text(duree, traducteur: traducteur))
        case .reste, .ecoule:
            habillerChiffre(chiffreAnime)
        }
    }

    /// Le décompte, redessiné chaque seconde d'après l'heure (le modèle donne le texte de chaque instant).
    private var chiffreAnime: some View {
        TimelineView(.periodic(from: .now, by: 1)) { contexte in
            Text(verbatim: modele.texteDecompte(a: SeanceTemps.millis(contexte.date)) ?? "")
        }
    }

    @ViewBuilder
    private func habillerChiffre<Contenu: View>(_ contenu: Contenu) -> some View {
        let chiffre = SeanceGrandChiffre(contenu: contenu)
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
            .background {
                if modele.souffleActif {
                    SeanceSouffleVue(rayon: rayonSouffle)
                        .padding(.top, 16)
                }
            }
        if let accessible = modele.decompteAccessible {
            chiffre
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(accessible, traducteur: traducteur))
        } else {
            chiffre
        }
    }

    private var legende: some View {
        Text(modele.legende, traducteur: traducteur)
            .font(.subheadline)
            .foregroundStyle(Teinte(.mint))
            .multilineTextAlignment(.center)
            .padding(.top, 8)
            .modifier(effacable)
    }

    @ViewBuilder
    private var musique: some View {
        if let ligne = modele.ligneMusique {
            Text(ligne, traducteur: traducteur)
                .font(.footnote)
                .foregroundStyle(Teinte(.mint))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 4)
                .modifier(effacable)
        }
    }

    /// « Commencer, 15 min » ou « Terminer maintenant » : il reste au calme.
    private var boutonPrincipal: some View {
        Button {
            let modele = self.modele
            Task {
                do {
                    try await modele.principal()
                } catch {
                    // La séance est partie ; son écriture se refera à la prochaine.
                }
            }
        } label: {
            Text(modele.libellePrincipal, traducteur: traducteur)
                .font(Font.callout.weight(.medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.principal)
    }

    @ViewBuilder
    private var boutonSecondaire: some View {
        if let secondaire = modele.libelleSecondaire {
            Button {
                modele.secondaire()
            } label: {
                Text(secondaire, traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SeanceBoutonTexte())
            .padding(.top, 4)
            .modifier(effacable)
        }
    }

    private var boutonSujet: some View {
        Button {
            modele.choisirSujet()
        } label: {
            Text(modele.libelleSujet, traducteur: traducteur)
        }
        .buttonStyle(SeanceBoutonTexte())
        .padding(.top, 12)
        .modifier(effacable)
    }

    /// À l'arrêt : les six durées, « Durée réglable… », « Sans durée », et « Commencer simplement ».
    @ViewBuilder
    private var choix: some View {
        if modele.choixVisibles {
            VStack(spacing: 0) {
                durees
                    .padding(.top, 16)
                Button {
                    modele.saisirDuree()
                } label: {
                    Text(modele.libelleDureeReglable, traducteur: traducteur)
                }
                .buttonStyle(SeanceBoutonTexte())
                Button {
                    let modele = self.modele
                    Task {
                        do {
                            try await modele.commencerSansDuree()
                        } catch {
                            // La séance est partie ; son écriture se refera à la prochaine.
                        }
                    }
                } label: {
                    Text(modele.libelleSansDuree, traducteur: traducteur)
                }
                .buttonStyle(SeanceBoutonTexte())
                simplement
            }
            .modifier(effacable)
        }
    }

    /// Les durées proposées, en deux rangées de trois boutons de même largeur (DurationButton).
    private var durees: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
            ForEach(modele.durees) { duree in
                Button {
                    let modele = self.modele
                    let minutes = duree.minutes
                    Task {
                        do {
                            try await modele.commencer(minutes: minutes)
                        } catch {
                            // La séance est partie ; la durée habituelle s'écrira à la prochaine.
                        }
                    }
                } label: {
                    Text(duree.libelle, traducteur: traducteur)
                        .font(.footnote)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SeanceBoutonContour(margeLaterale: 4))
            }
        }
    }

    /// « Commencer simplement » : quatre boutons texte de même largeur, dans l'ordre du modèle (parler, écrire,
    /// prier, une question).
    private var simplement: some View {
        HStack(spacing: 0) {
            ForEach(Array(modele.libellesSimplement.enumerated()), id: \.offset) { rang, libelle in
                Button {
                    commencerSimplement(rang)
                } label: {
                    Text(libelle, traducteur: traducteur)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SeanceBoutonTexte())
            }
        }
    }

    private func commencerSimplement(_ rang: Int) {
        let modele = self.modele
        Task {
            do {
                switch rang {
                case 0: try await modele.simplementParler()
                case 1: try await modele.simplementEcrire()
                case 2: try await modele.simplementPrier()
                default: try await modele.simplementQuestion()
                }
            } catch {
                // La séance est partie ; son écriture se refera à la prochaine.
            }
        }
    }

    @ViewBuilder
    private var carteChizuk: some View {
        if let carte = modele.carte {
            SeanceCarteChizukVue(carte: carte)
                .padding(.top, 16)
                .modifier(effacable)
        }
    }

    /// La hitbodedout guidée : elle reste au calme.
    @ViewBuilder
    private var guide: some View {
        if let guide = modele.guide {
            let modele = self.modele
            SeanceGuideVue(guide: guide,
                           libellePrecedent: modele.libelleGuidePrecedent,
                           libelleSuivant: modele.libelleGuideSuivant,
                           precedent: { modele.guidePrecedent() },
                           suivant: { modele.guideSuivant() })
                .padding(.top, 12)
        }
    }

    /// « Je n'arrive pas à parler » : une pilule cerclée de menthe ; en paysage, un bouton texte.
    @ViewBuilder
    private func blocage(pastille: Bool) -> some View {
        if modele.blocageVisible {
            let bouton = Button {
                let modele = self.modele
                Task { await modele.bloque() }
            } label: {
                Text(modele.libelleBlocage, traducteur: traducteur)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
            if pastille {
                bouton
                    .buttonStyle(SeanceBoutonContour())
                    .padding(.top, 12)
                    .modifier(effacable)
            } else {
                bouton
                    .buttonStyle(SeanceBoutonTexte())
                    .padding(.top, 12)
                    .modifier(effacable)
            }
        }
    }

    /// Une question à la fois : elle reste au calme.
    @ViewBuilder
    private var question: some View {
        if let question = modele.question {
            let modele = self.modele
            SeanceQuestionVue(question: question,
                              libelleSuivante: modele.libelleQuestionSuivante,
                              changements: modele.changementsQuestion,
                              suivante: { modele.questionSuivante() })
                .padding(.top, 12)
        }
    }

    // MARK: Les mesures et les fondus

    /// La marge des côtés (dimen edge).
    private var marge: CGFloat {
        SeanceMesures.marge(largeur: taille.width)
    }

    /// La hauteur de l'image de la scène (dimen art_height) : 190 sur un écran d'au moins 480 de haut, 130 sinon.
    private var hauteurScene: CGFloat {
        taille.height >= 480 || taille.height == 0 ? 190 : 130
    }

    /// Le rayon de la lueur : 42 % du plus petit côté.
    private var rayonSouffle: CGFloat {
        CGFloat(SeanceSouffle.rayon) * min(taille.width, taille.height)
    }

    /// Le fondu du calme : 900 ms pour s'effacer, 250 ms pour revenir ; aucun sous « Réduire les animations ».
    private var animationCalme: Animation? {
        guard !reduireAnimations else { return nil }
        let duree = modele.calme ? SeanceModele.fonduCalme : SeanceModele.fonduReveil
        return Animation.easeInOut(duration: Double(duree) / 1000)
    }

    private var effacable: SeanceEffacable {
        SeanceEffacable(opacite: modele.opaciteEffacable, calme: modele.calme, animation: animationCalme)
    }
}

// MARK: - Les pièces de l'écran

/// Ce qui s'efface au calme (PratiqueCalme.effacables) : l'opacité du modèle, en fondu.
struct SeanceEffacable: ViewModifier {
    let opacite: Double
    let calme: Bool
    let animation: Animation?

    init(opacite: Double, calme: Bool, animation: Animation?) {
        self.opacite = opacite
        self.calme = calme
        self.animation = animation
    }

    func body(content: Content) -> some View {
        content
            .opacity(opacite)
            .animation(animation, value: calme)
    }
}

/// Le grand chiffre (session_countdown) : blanc, 56 sp gras, chiffres de même chasse, toujours de gauche à droite.
private struct SeanceGrandChiffre<Contenu: View>: View {
    let contenu: Contenu
    @ScaledMetric(relativeTo: .largeTitle) private var taille: CGFloat = 56

    init(contenu: Contenu) {
        self.contenu = contenu
    }

    var body: some View {
        contenu
            .font(Font.system(size: taille, weight: .bold).monospacedDigit())
            .foregroundStyle(SeanceBlanc.plein)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .environment(\.layoutDirection, .leftToRight)
    }
}

/// « Sur quoi voulez-vous parler ? » (pickTheme) : la liste des sujets, « Aucun » en tête, le sujet choisi coché.
/// Toucher un sujet le choisit et ferme la liste ; un geste la ferme sans rien changer.
struct SeanceListeSujets: View {
    let modele: SeanceModele
    @Environment(\.traducteur) private var traducteur

    init(modele: SeanceModele) {
        self.modele = modele
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(modele.choixSujets) { choix in
                    Button {
                        let modele = self.modele
                        let theme = choix.theme
                        Task {
                            do {
                                try await modele.choisirSujet(theme)
                            } catch {
                                // Le choix reste en mémoire ; la prochaine écriture l'emportera.
                            }
                        }
                    } label: {
                        HStack {
                            Text(choix.libelle, traducteur: traducteur)
                                .foregroundStyle(Teinte(.ink))
                            Spacer(minLength: 8)
                            if choix.theme == modele.sujetChoisi {
                                Image(systemName: "checkmark")
                                    .font(Font.body.weight(.semibold))
                                    .foregroundStyle(Teinte(.brand))
                                    .accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(choix.theme == modele.sujetChoisi ? .isSelected : [])
                }
            }
            .navigationTitle(Text(SeanceDialogue.sujet.titre, traducteur: traducteur))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

/// Le bravo présenté en plein écran.
struct SeanceBravo: Identifiable, Hashable {
    let demande: CelebrationDemande
    let id = UUID()

    init(demande: CelebrationDemande) {
        self.demande = demande
    }
}

/// La note présentée en feuille.
struct SeanceNoteOuverte: Identifiable, Hashable {
    let date: JourCivil

    init(date: JourCivil) {
        self.date = date
    }

    var id: JourCivil { date }
}
