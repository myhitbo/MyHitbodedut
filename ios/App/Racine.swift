import Coeur
import Ecrans
import SwiftUI
import Vues

/// Un écran poussé dans la pile d'un onglet. Les trois piles partagent ces destinations : la séance part de la barre
/// de départ de n'importe quel lieu, un texte s'ouvre depuis le Jour comme depuis les Livres.
enum Ecran: Hashable {
    case zmanim
    case reglages(carteBarriere: Bool)
    case choixVersion
    case seance(demarrer: Bool)
    case tefilotDeLaSeance
    case journal
    case parcours
    case paliers
    case recherche
    case tikkun
    case siddour
    case tehilim
    case tefilot
    case chizuk
    case conseils
    case bibliotheque(livresSeuls: Bool)
    case halakha(recherche: String?)
    case hilloulot(recherche: String?)
    case halakhaLe(JourCivil)
    case hilloulotLe(JourCivil)
    case vol
    case musique
    case lecture(LectureCible)
    case tehilimLecture(TehilimLectureCible)
    case entree(String)
    case calendrier
    case boussole
    case rappels
    /// L'aperçu du bouclier, le choix des applications, la dédicace, le journal de la barrière (Barriere/BarriereEcrans.swift).
    case barriere(EcranBarriere)
}

/// Une feuille ou un écran plein posé par-dessus les onglets.
enum Pardessus: Hashable, Identifiable {
    case presentation
    case celebration(CelebrationDemande)
    case note(JourCivil)
    case marquesPages(recueil: String?)
    case ajoutTemps(JourCivil)

    var id: String {
        switch self {
        case .presentation: "presentation"
        case .celebration(let demande): "celebration-\(demande.minutes)-\(demande.annulee)"
        case .note(let jour): "note-\(jour.iso)"
        case .marquesPages(let recueil): "marques-\(recueil ?? "")"
        case .ajoutTemps(let jour): "ajout-\(jour.iso)"
        }
    }
}

/// Les trois onglets de l'app, dans l'ordre de la barre d'Android (Onglet, nav_main.xml ; refonte du 13/11), chacun
/// avec sa pile de navigation (PORTAGE.md § 1.2) ; la barre de départ au bas de chacun, et son volet par-dessus. Les
/// modèles demandent leurs écrans par des routes, que la racine ouvre. Une autre version de l'app choisie (Sérénité,
/// Bento, Pile : VersionApp) remplace les onglets par son accueil, avec la seule pile du Jour. La racine pose aussi
/// l'apparence tirée des réglages : la palette, le mode clair ou sombre, l'adresse qui choisit le personnage ; un
/// réglage changé se voit aussitôt.
struct Racine: View {
    let app: ModelesApp
    let palettes: Palettes?
    @State private var onglet: Onglet
    @State private var pileDuJour: NavigationPath
    @State private var pileDesLivres = NavigationPath()
    @State private var pileDuChemin = NavigationPath()
    @State private var feuille: Pardessus? = nil
    @State private var plein: Pardessus? = nil
    @Environment(\.colorScheme) private var schema

    init(app: ModelesApp, palettes: Palettes?) {
        self.app = app
        self.palettes = palettes
        _onglet = State(initialValue: Onglet.initial(app.magasin.reglages))
        var pile = NavigationPath()
        // Zmanim est déjà posé au lancement quand le réglage « ecran_ouverture » le demande.
        if Onglet.zmanimParDessus(app.magasin.reglages) { pile.append(Ecran.zmanim) }
        _pileDuJour = State(initialValue: pile)
    }

    var body: some View {
        let apparence = ApparenceChoisie(app.magasin.reglages)
        let palette = PaletteApp.choisie(palettes, apparence)
        let version = VersionApp.accueil(app.magasin.reglages)
        accueil(version)
        .sheet(item: $feuille) { pardessus in
            vuePardessus(pardessus)
        }
        .fullScreenCover(item: $plein) { pardessus in
            vuePardessus(pardessus)
        }
        // Les routes des modèles deviennent des écrans ; celles dont l'écran n'est pas encore porté sont retirées sans
        // rien ouvrir.
        .onChange(of: app.accueil.routes) { _, routes in
            guard let route = routes.first else { return }
            app.accueil.routeOuverte()
            ouvrirAccueil(route)
        }
        .onChange(of: app.accueilVersion.routes) { _, routes in
            guard let route = routes.first else { return }
            app.accueilVersion.routeOuverte()
            ouvrirAccueilVersion(route)
        }
        .onChange(of: app.chemin.routes) { _, routes in
            guard let route = routes.first else { return }
            app.chemin.routeOuverte()
            switch route {
            case .journal: pileDuChemin.append(Ecran.journal)
            case .parcours: pileDuChemin.append(Ecran.parcours)
            case .paliers: pileDuChemin.append(Ecran.paliers)
            }
        }
        .onChange(of: onglet) { _, nouveau in
            // Revenir au Jour rejoue les anneaux (MainActivity.rejouer).
            if nouveau == .aujourdhui { app.accueil.ongletChoisi() }
        }
        .onChange(of: version) { _, _ in
            // Une autre version choisie (VersionApp.appliquer) : l'app repart de son accueil, sans pile d'écrans derrière.
            pileDuJour = NavigationPath()
            pileDesLivres = NavigationPath()
            pileDuChemin = NavigationPath()
            onglet = .aujourdhui
        }
        .onChange(of: plein) { avant, apres in
            // Au retour de la présentation, l'accueil repasse (onResume) : le choix de la version s'y propose.
            if avant == .presentation && apres == nil && version == .classique {
                Task { await app.accueil.apparaitre() }
            }
        }
        // Les captures d'écran de la CI (Captures.swift) : l'écran demandé au lancement ; sans « -capture », rien.
        .task {
            await Captures.ouvrir(app, onglet: $onglet, jour: $pileDuJour, livres: $pileDesLivres, chemin: $pileDuChemin,
                                  feuille: $feuille, plein: $plein)
        }
        // Les notifications touchées, les widgets, la Live Activity ; le planificateur et les widgets à jour.
        .modifier(GestesExterieurs(app: app) { lien in ouvrirLien(lien) })
        // L'iPad et le téléphone couché : le contenu s'écarte des bords (GrandEcran, tâche 29).
        .margesLarges()
        .tint(palette.couleur(.brand, schema: schema))
        .environment(\.paletteApp, palette)
        .environment(\.apparence, apparence)
        .preferredColorScheme(schemaPrefere(version, apparence))
    }

    /// L'accueil : les trois onglets de Classique, ou l'accueil d'une autre version (VersionApp.rediriger), qui prend
    /// leur place avec une seule pile — celle du Jour — comme l'activité de la version remplace MainActivity.
    @ViewBuilder
    private func accueil(_ version: VersionApp) -> some View {
        if version == .classique {
            onglets
        } else {
            NavigationStack(path: $pileDuJour) {
                AccueilVersionVue(modele: app.accueilVersion)
                    .navigationDestination(for: Ecran.self) { ecran in
                        destination(ecran)
                    }
            }
        }
    }

    /// Le mode de l'écran : celui des réglages. L'accueil d'une version, seul à l'écran, garde le sien, clair ou sombre
    /// selon ses couleurs (VueVersion.barres) : la barre d'état reste lisible sur son fond.
    private func schemaPrefere(_ version: VersionApp, _ apparence: ApparenceChoisie) -> ColorScheme? {
        guard version != .classique, pileDuJour.isEmpty, feuille == nil, plein == nil else { return apparence.schema }
        return app.accueilVersion.fondSombre ? .dark : .light
    }

    /// Les trois onglets de l'accueil Classique, la barre de départ et son volet, la fête des trophées neufs.
    private var onglets: some View {
        TabView(selection: $onglet) {
            Tab(LocalizedStringKey(Onglet.aujourdhui.cle), systemImage: Onglet.aujourdhui.symbole,
                value: Onglet.aujourdhui) {
                NavigationStack(path: $pileDuJour) {
                    racineDeLOnglet(AccueilVue(modele: app.accueil))
                }
            }
            Tab(LocalizedStringKey(Onglet.textes.cle), systemImage: Onglet.textes.symbole, value: Onglet.textes) {
                NavigationStack(path: $pileDesLivres) {
                    racineDeLOnglet(TextesVue(modele: app.textes) { route in ouvrirTexte(route) })
                }
            }
            Tab(LocalizedStringKey(Onglet.chemin.cle), systemImage: Onglet.chemin.symbole, value: Onglet.chemin) {
                NavigationStack(path: $pileDuChemin) {
                    racineDeLOnglet(CheminVue(modele: app.chemin))
                }
            }
        }
        .feuilleDepart(accueil: app.accueil, textes: app.textes)
        .feteDesTrophees(app.accueil.fete)
    }

    /// La racine d'un onglet : la barre de départ en bas, et les destinations de la pile.
    private func racineDeLOnglet<Contenu: View>(_ contenu: Contenu) -> some View {
        contenu
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BarreDepart(modele: app.accueil)
            }
            .navigationDestination(for: Ecran.self) { ecran in
                // Hors des trois racines, pas de barre d'onglets : sur Android, chaque autre écran est une activité à
                // part, sans la barre du bas ; ici elle couvrait le bas de la séance et du lecteur (captures du 23/11).
                destination(ecran)
                    .toolbar(.hidden, for: .tabBar)
            }
    }

    // MARK: Pousser dans la pile de l'onglet choisi

    private func pousser(_ ecran: Ecran) {
        // L'accueil d'une autre version n'a qu'une pile.
        if VersionApp.accueil(app.magasin.reglages) != .classique {
            pileDuJour.append(ecran)
            return
        }
        switch onglet {
        case .aujourdhui: pileDuJour.append(ecran)
        case .textes: pileDesLivres.append(ecran)
        case .chemin: pileDuChemin.append(ecran)
        }
    }

    // MARK: Les routes des modèles

    private func ouvrirAccueil(_ route: AccueilRoute) {
        switch route {
        case .seance(let demarrer): pousser(.seance(demarrer: demarrer))
        case .paliers: pousser(.paliers)
        case .parcours: pousser(.parcours)
        case .note(let jour): feuille = .note(jour)
        case .celebration(let minutes, let dateNote):
            plein = .celebration(CelebrationDemande(minutes: minutes, dateNote: dateNote.flatMap { JourCivil(iso: $0) }))
        case .presentation: plein = .presentation
        case .siddour(let id): pousser(.lecture(.siddour(id)))
        case .entreeBibliotheque(let id): pousser(.entree(id))
        case .zmanim: pileDuJour.append(Ecran.zmanim)
        case .reglages(let carteBarriere): pileDuJour.append(Ecran.reglages(carteBarriere: carteBarriere))
        case .musique: pousser(.musique)
        case .choixVersion: pileDuJour.append(Ecran.choixVersion)
        }
    }

    /// Les écrans qu'ouvre l'accueil d'une version (AccueilVersion : commencerSeance, ouvrirZmanim…).
    private func ouvrirAccueilVersion(_ route: AccueilVersionRoute) {
        switch route {
        case .seance(let demarrer): pousser(.seance(demarrer: demarrer))
        case .zmanim: pousser(.zmanim)
        case .journal: pousser(.journal)
        // LibraryActivity : les sources de la bibliothèque.
        case .textes: pousser(.bibliotheque(livresSeuls: false))
        case .siddour: pousser(.siddour)
        case .tehilim: pousser(.tehilim)
        case .chizuk: pousser(.chizuk)
        case .musique: pousser(.musique)
        case .reglages: pousser(.reglages(carteBarriere: false))
        case .parcours: pousser(.parcours)
        case .recherche: pousser(.recherche)
        case .note(let jour): feuille = .note(jour)
        case .celebration(let minutes, let dateNote):
            plein = .celebration(CelebrationDemande(minutes: minutes, dateNote: dateNote.flatMap { JourCivil(iso: $0) }))
        case .presentation: plein = .presentation
        }
    }

    private func ouvrirTexte(_ route: TextesRoute) {
        switch route {
        case .recherche: pousser(.recherche)
        case .tikkun: pousser(.tikkun)
        case .siddour: pousser(.siddour)
        case .tehilim: pousser(.tehilim)
        case .tefilot: pousser(.tefilot)
        case .bibliotheque(let livresSeuls): pousser(.bibliotheque(livresSeuls: livresSeuls))
        case .chizuk: pousser(.chizuk)
        case .conseils: pousser(.conseils)
        case .halakha: pousser(.halakha(recherche: nil))
        case .lecture(let id, let livre): pousser(.lecture(LectureCible(id: id, livre: livre)))
        case .marquesPages(let recueil): feuille = .marquesPages(recueil: recueil)
        case .entreeBibliotheque(let id): pousser(.entree(id))
        case .musique: pousser(.musique)
        case .rappels: pousser(.rappels)
        case .relecture: break
        }
    }

    private func ouvrirLecture(_ route: LectureRoute) {
        switch route {
        case .lecture(let cible): pousser(.lecture(cible))
        case .tehilim: pousser(.tehilim)
        case .tikkun: pousser(.tikkun)
        case .tehilimMarque(let psaume, let verset): pousser(.tehilimLecture(.marque(psaume: psaume, verset: verset)))
        case .marquesPages(let recueil): feuille = .marquesPages(recueil: recueil)
        }
    }

    private func ouvrirRecherche(_ route: RechercheRoute) {
        if let cible = route.cible {
            pousser(.lecture(cible))
            return
        }
        switch route {
        case .halakha(let recherche): pousser(.halakha(recherche: recherche))
        case .hilloulot(let recherche): pousser(.hilloulot(recherche: recherche))
        case .siddour, .livre: break
        }
    }

    private func ouvrirBibliotheque(_ route: BibliothequeRoute) {
        switch route {
        case .livre(let id): pousser(.lecture(.livre(id)))
        case .marque(let livre, let section, let bloc):
            pousser(.lecture(LectureCible(id: livre, livre: true, marque: LecturePlace(section: section, bloc: bloc))))
        case .sousSection, .entree: break
        }
    }

    private func ouvrirZmanim(_ route: ZmanimRoute) {
        switch route {
        case .halakha(let jour): pousser(.halakhaLe(jour))
        case .hilloulot(let jour): pousser(.hilloulotLe(jour))
        case .siddour(let id): pousser(.lecture(.siddour(id)))
        case .vol: pousser(.vol)
        case .calendrier: pousser(.calendrier)
        case .boussole: pousser(.boussole)
        case .ajouterTemps(let jour): feuille = .ajoutTemps(jour)
        }
    }

    /// Un écran demandé d'hors de l'app (notification, widget, Live Activity) : sur le Jour, par-dessus ce qui y est.
    private func ouvrirLien(_ lien: LienApp) {
        let ecran: Ecran?
        switch lien {
        case .accueil, .terminerSeance: ecran = nil
        case .zmanim: ecran = .zmanim
        case .boussole: ecran = .boussole
        case .calendrier: ecran = .calendrier
        case .rappels: ecran = .rappels
        case .seance(let demarrer): ecran = .seance(demarrer: demarrer)
        case .siddour(let id): ecran = .lecture(.siddour(id))
        case .vol: ecran = .vol
        }
        feuille = nil
        onglet = .aujourdhui
        if let ecran { pileDuJour.append(ecran) }
    }

    private func ouvrirReglage(_ route: ReglagesRoute) {
        switch route {
        case .presentation: plein = .presentation
        case .choixVersion: pousser(.choixVersion)
        case .recommencer:
            // Tout a été effacé : l'app repart du Jour, présentation comprise.
            pileDuJour = NavigationPath()
            pileDesLivres = NavigationPath()
            pileDuChemin = NavigationPath()
            onglet = .aujourdhui
            plein = .presentation
        case .apercuBarriere, .choixApplications, .dedicace, .journalBarriere:
            // Les écrans de la barrière et la dédicace (Barriere/BarriereEcrans.swift).
            if let ecran = EcranBarriere(route) { pousser(.barriere(ecran)) }
        case .reglagesApp, .reglagesNotifications, .navigateur, .aideConcentration:
            // Ouvertes par la vue des réglages elle-même.
            break
        }
    }

    // MARK: Les écrans

    @ViewBuilder
    private func destination(_ ecran: Ecran) -> some View {
        switch ecran {
        case .zmanim:
            ZmanimVue(modele: app.zmanim) { route in ouvrirZmanim(route) }
        case .reglages(let carteBarriere):
            ReglagesVue(modele: app.reglages, carteBarriere: carteBarriere) { route in ouvrirReglage(route) }
        case .choixVersion:
            Garde(app.choixVersion) { ChoixVersionVue(modele: $0) }
        case .seance(let demarrer):
            Garde(app.seanceModele) { modele in
                SeanceVue(modele: modele, demande: demarrer ? .commencer : .aucune,
                          celebration: app.celebration, note: app.note,
                          tefilot: { pousser(.tefilotDeLaSeance) }, mini: app.miniLecteur)
            }
        case .tefilot, .tefilotDeLaSeance:
            Garde(app.tefilot) { modele in
                TefilotVue(modele: modele) { route in
                    switch route {
                    case .entree(let id): pousser(.entree(id))
                    }
                }
            }
        case .journal:
            // Le verrou du journal (VerrouJournal) : rien ne s'y montre avant le code, refermé à l'arrière-plan.
            Garde(app.journal) { JournalVue(modele: $0) { pousser(.seance(demarrer: false)) }.verrouJournal(app.verrouJournal) }
        case .parcours:
            Garde(app.parcours) { ParcoursVue(modele: $0) }
        case .paliers:
            Garde(app.paliers) { PaliersVue(modele: $0) }
        case .recherche:
            Garde(app.recherche) { modele in RechercheVue(modele: modele) { route in ouvrirRecherche(route) } }
        case .tikkun:
            Garde(app.tikkun) { TikkunVue(modele: $0) }
        case .siddour:
            SiddourEcran(magasin: app.magasin, contenus: app.contenus, horloge: app.horloge, langue: app.langue) { route in
                ouvrirLecture(route)
            }
        case .tehilim:
            Garde(app.tehilim) { TehilimVue(modele: $0, lecture: app.tehilimLecture) }
        case .chizuk:
            Garde(app.chizuk) { modele in
                ChizukVue(modele: modele) { route in
                    switch route {
                    case .seance: pousser(.seance(demarrer: false))
                    }
                }
            }
        case .conseils:
            Garde(app.conseils) { ConseilsVue(modele: $0) }
        case .bibliotheque(let livresSeuls):
            Garde({ app.bibliotheque(livresSeuls: livresSeuls) }) { modele in
                BibliothequeVue(modele: modele, sousSection: app.sousSection, entree: app.entree) { route in
                    ouvrirBibliotheque(route)
                }
            }
        case .halakha(let recherche):
            Garde({ app.halakha(recherche: recherche) }) { HalakhaVue(modele: $0) }
        case .hilloulot(let recherche):
            Garde({ app.hilloulotModele(recherche: recherche) }) { HilloulotVue(modele: $0) }
        case .vol:
            Garde(app.vol) { VolVue(modele: $0) }
        case .musique:
            Garde(app.musiqueModele) { MusiqueVue(modele: $0) }
        case .halakhaLe(let jour):
            Garde({ app.halakha(recherche: nil, date: jour) }) { HalakhaVue(modele: $0) }
        case .hilloulotLe(let jour):
            Garde({ app.hilloulotModele(recherche: nil, date: jour) }) { HilloulotVue(modele: $0) }
        case .lecture(let cible):
            LectureEcran(magasin: app.magasin, contenus: app.contenus, horloge: app.horloge, langue: app.langue,
                         cible: cible) { route in
                ouvrirLecture(route)
            }
        case .tehilimLecture(let cible):
            TehilimLecturePage(cible: cible, fabrique: app.tehilimLecture)
        case .entree(let id):
            BibliothequeEntreePage(id: id, fabrique: app.entree)
        case .calendrier:
            Garde(app.calendrier) { modele in CalendrierVue(modele: modele) { route in ouvrirZmanim(route) } }
        case .boussole:
            Garde(app.boussole) { BoussoleVue(modele: $0) }
        case .rappels:
            Garde(app.rappels) { RappelsVue(modele: $0) }
        case .barriere(let ecran):
            BarriereDestination(app: app, ecran: ecran)
        }
    }

    @ViewBuilder
    private func vuePardessus(_ pardessus: Pardessus) -> some View {
        switch pardessus {
        case .presentation:
            Garde(app.presentation) { PresentationVue(modele: $0) }
        case .celebration(let demande):
            CelebrationEcran(modele: app.celebration(demande), note: app.note) { plein = nil }
        case .note(let jour):
            Garde({ app.note(jour) }) { modele in
                JournalNoteVue(modele: modele, enregistrer: {
                    do {
                        try await modele.enregistrer()
                        feuille = nil
                    } catch {
                        // La fenêtre reste ouverte ; le changement reste en mémoire (Magasin).
                    }
                }, fermer: { feuille = nil })
            }
        case .ajoutTemps(let jour):
            AjoutTempsFeuille(fabrique: { app.ajoutTemps(jour) }, fermer: { feuille = nil })
        case .marquesPages(let recueil):
            NavigationStack {
                LectureMarquesEcran(magasin: app.magasin, contenus: app.contenus, recueil: recueil) { route in
                    feuille = nil
                    ouvrirLecture(route)
                }
            }
        }
    }
}

/// Un écran et son modèle, construit à la première apparition puis gardé le temps de l'écran : la destination de la
/// pile est recalculée à chaque dessin de la racine, le modèle ne doit pas l'être.
struct Garde<Modele: AnyObject, Contenu: View>: View {
    @State private var modele: Modele? = nil
    private let fabrique: @MainActor () -> Modele
    private let contenu: @MainActor (Modele) -> Contenu
    @Environment(\.paletteApp) private var palette
    @Environment(\.colorScheme) private var schema

    init(_ fabrique: @escaping @MainActor () -> Modele, @ViewBuilder contenu: @escaping @MainActor (Modele) -> Contenu) {
        self.fabrique = fabrique
        self.contenu = contenu
    }

    var body: some View {
        if let modele {
            contenu(modele)
        } else {
            palette.couleur(.paper, schema: schema)
                .ignoresSafeArea()
                .onAppear { modele = fabrique() }
        }
    }
}
