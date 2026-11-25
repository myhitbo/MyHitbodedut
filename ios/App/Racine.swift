import Coeur
import Ecrans
import SwiftUI
import Vues

/// Les cinq onglets de l'app, dans l'ordre de la barre d'Android (Onglet, nav_main.xml), chacun avec sa pile de
/// navigation (PORTAGE.md § 1.2) ; par-dessus, les feuilles et les pleins écrans que les routes demandent
/// (Routage.swift). La racine pose aussi l'apparence tirée des réglages : la palette, le mode clair ou sombre,
/// l'adresse qui choisit le personnage ; un réglage changé se voit aussitôt. Elle tient enfin le plan des
/// notifications à jour : au retour au premier plan, au début et à la fin d'une séance, au changement de lieu.
struct Racine: View {
    let app: PartageApp
    @Bindable private var navigation: Navigation
    @Environment(\.colorScheme) private var schema

    init(app: PartageApp) {
        self.app = app
        _navigation = Bindable(wrappedValue: app.navigation)
    }

    var body: some View {
        let apparence = ApparenceChoisie(app.magasin.reglages)
        let palette = PaletteApp.choisie(app.palettes, apparence)
        onglets
            .modifier(Presentations(app: app, navigation: navigation, apparence: apparence, palette: palette))
            .overlay(alignment: .bottom) { MessageMusique(lecteur: app.musique) }
            .tint(palette.couleur(.brand, schema: schema))
            .environment(\.paletteApp, palette)
            .environment(\.apparence, apparence)
            .preferredColorScheme(apparence.schema)
            .modifier(Veilleur(app: app))
            .onChange(of: navigation.onglet) { ancien, nouveau in
                // L'accueil rejoue ses anneaux au retour depuis les Textes (OnItemSelectedListener).
                if ancien == .textes && nouveau == .aujourdhui {
                    app.accueil.ongletChoisi()
                }
            }
    }

    private var onglets: some View {
        TabView(selection: $navigation.onglet) {
            Tab(LocalizedStringKey(Onglet.aujourdhui.cle), systemImage: Onglet.aujourdhui.symbole,
                value: Onglet.aujourdhui) {
                pileAujourdhui
            }
            Tab(LocalizedStringKey(Onglet.textes.cle), systemImage: Onglet.textes.symbole,
                value: Onglet.textes) {
                pileTextes
            }
            Tab(LocalizedStringKey(Onglet.zmanim.cle), systemImage: Onglet.zmanim.symbole,
                value: Onglet.zmanim) {
                pileZmanim
            }
            Tab(LocalizedStringKey(Onglet.journal.cle), systemImage: Onglet.journal.symbole,
                value: Onglet.journal) {
                pileJournal
            }
            Tab(LocalizedStringKey(Onglet.reglages.cle), systemImage: Onglet.reglages.symbole,
                value: Onglet.reglages) {
                pileReglages
            }
        }
    }

    // MARK: Les cinq piles

    private var pileAujourdhui: some View {
        NavigationStack(path: $navigation.aujourdhui) {
            AccueilVue(modele: app.accueil, formes: app.formes,
                       ouvrir: { route in app.ouvrirAccueil(route) },
                       preparer: { [seance = app.seance] in
                           // La séance restée inscrite close ou reprise (SessionService.reconcilier) ; celle que
                           // l'app suit, close si son terme est passé hors de l'écran de séance (actualiser fait
                           // les deux : reconcilier ne touche pas une séance suivie).
                           _ = try? await seance.actualiser()
                       })
                .modifier(Destinations(app: app))
        }
    }

    private var pileTextes: some View {
        NavigationStack(path: $navigation.textes) {
            TextesVue(modele: app.textes, ouvrir: { route in app.ouvrirTextes(route) })
                .modifier(Destinations(app: app))
        }
    }

    private var pileZmanim: some View {
        NavigationStack(path: $navigation.zmanim) {
            ZmanimOngletVue(modele: app.zmanim,
                            calendrier: { app.calendrier() },
                            ouvrir: { route in app.ouvrirZmanim(route) })
                .modifier(Destinations(app: app))
        }
    }

    private var pileJournal: some View {
        NavigationStack(path: $navigation.journal) {
            JournalVue(modele: app.journal, ouvrir: { route in app.ouvrirJournal(route) })
                .modifier(Destinations(app: app))
        }
    }

    private var pileReglages: some View {
        NavigationStack(path: $navigation.reglages) {
            ReglagesVue(modele: app.reglages, ouvrir: { route in app.ouvrirReglages(route) })
                .modifier(Destinations(app: app))
        }
    }
}

/// La seule destination de chaque pile : un `Ecran` mené à sa vue (Destinations.swift).
struct Destinations: ViewModifier {
    let app: PartageApp

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: Ecran.self) { ecran in
                Destination(ecran: ecran, app: app)
            }
    }
}

/// Ce que la racine présente par-dessus les onglets : la présentation et le bravo en plein écran, les feuilles
/// (marque-pages, note du jour), le dialogue d'ajout de temps du calendrier. Les feuilles reprennent
/// l'environnement de l'app.
struct Presentations: ViewModifier {
    let app: PartageApp
    @Bindable var navigation: Navigation
    let apparence: ApparenceChoisie
    let palette: PaletteApp

    func body(content: Content) -> some View {
        content
            .sheet(item: $navigation.feuille) { feuille in
                vueFeuille(feuille)
                    .environment(\.paletteApp, palette)
                    .environment(\.apparence, apparence)
                    .environment(\.traducteur, app.traducteur)
            }
            .fullScreenCover(item: $navigation.couverture) { couverture in
                vueCouverture(couverture)
                    .environment(\.paletteApp, palette)
                    .environment(\.apparence, apparence)
                    .environment(\.traducteur, app.traducteur)
            }
            .fullScreenCover(item: $navigation.presentation) { ouverte in
                PresentationVue(modele: ouverte.modele)
                    .environment(\.paletteApp, palette)
                    .environment(\.apparence, apparence)
                    .environment(\.traducteur, app.traducteur)
                    .onDisappear {
                        // Fermée autrement que par Commencer ou Passer : elle ne revient pas (l'appel est
                        // idempotent).
                        let modele = ouverte.modele
                        Task { _ = try? await modele.terminer() }
                    }
            }
            .ajoutTemps($navigation.ajout)
    }

    @ViewBuilder
    private func vueFeuille(_ feuille: Feuille) -> some View {
        switch feuille {
        case .marquesPages(let recueil):
            LectureMarquesEcran(magasin: app.magasin, contenus: app.contenus, recueil: recueil,
                                ouvrir: { route in app.ouvrirLecture(route) })
        case .note(let jour):
            NotePage(date: jour, fabrique: { jour in app.note(jour) })
        case .dedicace:
            Garde {
                DedicaceModele(traducteur: app.traducteur)
            } contenu: { modele in
                DedicaceVue(modele: modele)
            }
        }
    }

    @ViewBuilder
    private func vueCouverture(_ couverture: Couverture) -> some View {
        switch couverture {
        case .celebration(let demande):
            CelebrationPage(demande: demande,
                            fabrique: { demande in app.celebration(demande) },
                            note: { jour in app.note(jour) })
        }
    }
}

/// Le plan des notifications recalculé quand ce qui le fonde change : le retour au premier plan (l'heure, le
/// fuseau, un rappel paru), une séance qui commence ou finit (la notification de fin doit partir à
/// « Terminer »), un lieu enregistré (Chabbat, Levana).
struct Veilleur: ViewModifier {
    let app: PartageApp
    @Environment(\.scenePhase) private var phase

    func body(content: Content) -> some View {
        content
            .onChange(of: phase) { _, nouvelle in
                if nouvelle == .active {
                    app.actualiserSeance()
                    app.replanifier()
                    app.actualiserBarriere()
                }
                // En quittant l'app, les widgets de la série et des zmanim reçoivent le dernier état (prénom, pauses,
                // objectif, palette… que rien d'autre ne leur dépose).
                if nouvelle == .background {
                    let widgets = app.services.widgets
                    Task { await widgets.rafraichir() }
                }
            }
            .onChange(of: app.seance.suivie) { _, _ in
                app.replanifier()
                // Le widget de la série montre la séance en cours, puis le jour fait (StreakWidget.refresh).
                let widgets = app.services.widgets
                Task { await widgets.rafraichir() }
            }
            .onChange(of: app.seance.inscriptions) { _, _ in
                app.replanifier()
                let widgets = app.services.widgets
                Task { await widgets.rafraichir() }
            }
            .onChange(of: app.magasin.reglages.lieuDepuis) { _, _ in
                app.replanifier()
                // Le widget de la boussole suit le lieu (BoussoleWidget.refresh après ChoixLieu).
                let widgets = app.services.widgets
                Task { await widgets.rafraichir() }
            }
            .onChange(of: app.magasin.reglages.boussoleCarte) { _, _ in
                let widgets = app.services.widgets
                Task { await widgets.rafraichir() }
            }
    }
}

/// Le message de la musique pendant une séance (un morceau illisible) : un Toast de 3,5 s en bas de l'écran, lu
/// par VoiceOver, puis effacé (`MusiqueLecteur.effacerMessage`).
struct MessageMusique: View {
    let lecteur: MusiqueLecteur
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        if let message = lecteur.message {
            Text(message, traducteur: traducteur)
                .font(.callout)
                .foregroundStyle(Teinte(.paper))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(Teinte(.ink)))
                .padding(.horizontal, 24)
                .padding(.bottom, 72)
                .allowsHitTesting(false)
                .task(id: message) {
                    AccessibilityNotification.Announcement(traducteur.texte(message)).post()
                    do {
                        try await Task.sleep(for: .seconds(3.5))
                        lecteur.effacerMessage()
                    } catch {
                        // Un autre message l'a remplacé.
                    }
                }
        }
    }
}
