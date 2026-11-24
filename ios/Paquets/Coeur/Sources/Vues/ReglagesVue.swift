import Accessibility
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Coeur
import Ecrans

/// L'onglet Réglages (SettingsActivity.kt, activity_settings.xml) : une seule page qui défile sur le dégradé de la
/// marque, avec l'en-tête et son résumé, puis les cartes (langue, apparence, écran Zmanim, état du mode, « Je suis
/// avec Hachem », rythme, autorisations, dédicace, données, réinitialisation) et la version.
///
/// La vue ne décide rien : ReglagesModele (cible Ecrans) dit les valeurs, les états, les fenêtres ouvertes et les
/// routes. Elle relit le système à l'apparition et à chaque retour au premier plan (onResume d'Android), présente
/// les fenêtres que `modele.dialogue` nomme, et suit les routes rendues : les Réglages d'iOS et le navigateur
/// s'ouvrent d'ici ; les autres écrans de l'app (présentation, aperçu du bouclier, choix des applications,
/// dédicace, aide de la concentration, nouveau départ) passent par `ouvrir`, que l'app branche.
///
/// Sa pile de navigation est celle de son onglet (ios/App) : la vue n'en ouvre pas une seconde.
public struct ReglagesVue: View {
    private let modele: ReglagesModele
    private let aiguillage: ReglagesAiguillage

    @Environment(\.traducteur) private var traducteur
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var schema
    @Environment(\.paletteApp) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduireAnimations

    /// La largeur de la page : le bouton de valeur en prend 45 % au plus (SettingValue, maxWidth).
    @State private var largeur: CGFloat = 0
    /// Le texte du champ de la fenêtre ouverte (le prénom, la durée libre), prérempli à son ouverture.
    @State private var saisie = ""
    /// Le sélecteur de fichiers de l'export, et ce qu'il écrit.
    @State private var exportOuvert = false
    @State private var documentExport: ReglagesDocument? = nil
    @State private var nomExport = ""
    /// Le sélecteur de fichiers de l'import.
    @State private var importOuvert = false

    /// - Parameters:
    ///   - modele: le modèle de l'onglet, construit par l'app avec le magasin et les services.
    ///   - ouvrir: les écrans de l'app que l'onglet ouvre (`.presentation`, `.apercuBarriere`,
    ///     `.choixApplications`, `.dedicace`, `.aideConcentration`, `.recommencer`) ; les Réglages d'iOS et le
    ///     navigateur, la vue les ouvre elle-même.
    public init(modele: ReglagesModele, ouvrir: @escaping @MainActor (ReglagesRoute) -> Void) {
        self.modele = modele
        self.aiguillage = ReglagesAiguillage(modele: modele, ouvrir: ouvrir)
    }

    public var body: some View {
        pageAvecFichiers
            .overlay(alignment: .bottom) {
                messagePassager
            }
            .sheet(item: listeOuverte) { liste in
                feuilleChoix(liste)
            }
            .sheet(item: heureOuverte) { ouverte in
                feuilleHeure(ouverte.borne)
            }
            .alert(titreAlerte, isPresented: alerteOuverte, presenting: modele.dialogue) { dialogue in
                actionsAlerte(dialogue)
            } message: { dialogue in
                messageAlerte(dialogue)
            }
            .onChange(of: modele.dialogue) { _, dialogue in
                preparerSaisie(dialogue)
            }
            .task {
                await modele.rafraichir()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task.immediate { @MainActor [modele] in
                        await modele.rafraichir()
                    }
                }
            }
    }

    // MARK: La page

    private var page: some View {
        ScrollViewReader { defilement in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    entete
                        .id(ReglagesSection.entete)
                    cartesDuHaut
                    cartesDuBas
                    version
                        .id(ReglagesSection.version)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 32)
            }
            .onChange(of: modele.cibleDefilement, initial: true) { _, cible in
                defiler(vers: cible, defilement)
            }
        }
        .onGeometryChange(for: CGFloat.self) { geometrie in
            geometrie.size.width
        } action: { nouvelle in
            largeur = nouvelle
        }
        .background {
            fondPage
                .ignoresSafeArea()
        }
        // Le titre nomme l'écran (VoiceOver, l'onglet) ; l'en-tête le montre déjà : la barre ne le répète pas.
        .navigationTitle(reglagesTexte("settings_title", traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(removing: .title)
    }

    /// Le bouton de valeur prend 45 % de la largeur au plus ; rien tant que la page n'est pas mesurée.
    private var largeurValeur: CGFloat? {
        largeur > 0 ? largeur * 0.45 : nil
    }

    private var cartesDuHaut: some View {
        VStack(alignment: .leading, spacing: 0) {
            ReglagesCarteLangue(modele: modele, aiguillage: aiguillage, largeurValeur: largeurValeur)
                .modifier(ReglagesPlaceCarte(section: .langue))
            ReglagesCarteApparence(modele: modele, aiguillage: aiguillage, largeurValeur: largeurValeur)
                .modifier(ReglagesPlaceCarte(section: .apparence))
            ReglagesCarteZmanim(modele: modele, aiguillage: aiguillage, largeurValeur: largeurValeur)
                .modifier(ReglagesPlaceCarte(section: .zmanim))
            if modele.avecBarriere, let carte = modele.carteBarriere {
                ReglagesCarteEtatMode(modele: modele, carte: carte, aiguillage: aiguillage)
                    .modifier(ReglagesPlaceCarte(section: .etatBarriere))
            }
            if modele.avecBarriere {
                ReglagesCarteMode(modele: modele, aiguillage: aiguillage, largeurValeur: largeurValeur)
                    .modifier(ReglagesPlaceCarte(section: .barriere))
            }
        }
    }

    private var cartesDuBas: some View {
        VStack(alignment: .leading, spacing: 0) {
            ReglagesCarteRythme(modele: modele, aiguillage: aiguillage, largeurValeur: largeurValeur)
                .modifier(ReglagesPlaceCarte(section: .rythme))
            ReglagesCarteAutorisations(modele: modele, aiguillage: aiguillage, largeurValeur: largeurValeur)
                .modifier(ReglagesPlaceCarte(section: .autorisations))
            ReglagesCarteDedicace(modele: modele, aiguillage: aiguillage)
                .modifier(ReglagesPlaceCarte(section: .dedicace))
            carteDonnees
                .modifier(ReglagesPlaceCarte(section: .donnees))
            ReglagesCarteReinitialiser(modele: modele)
                .modifier(ReglagesPlaceCarte(section: .reinitialisation))
        }
    }

    /// Fait venir une carte en haut de l'écran (scrollToPermissions), sans animation si on les a réduites.
    private func defiler(vers cible: ReglagesSection?, _ defilement: ScrollViewProxy) {
        guard let cible else { return }
        if reduireAnimations {
            defilement.scrollTo(cible, anchor: .top)
        } else {
            withAnimation {
                defilement.scrollTo(cible, anchor: .top)
            }
        }
        modele.defilementFait()
    }

    // MARK: L'en-tête (bg_hero)

    /// « Réglages » en petites lettres espacées, et le résumé des autorisations dessous.
    private var entete: some View {
        VStack(alignment: .leading, spacing: 4) {
            reglagesTexte("settings_title", traducteur)
                .font(.footnote)
                .tracking(1.8)
                .foregroundStyle(Teinte(.mint))
                .accessibilityAddTraits(.isHeader)
            if let resume = modele.resume {
                Text(resume, traducteur: traducteur)
                    .font(Font.title3.bold())
                    .foregroundStyle(Color.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background {
            fondEntete
        }
    }

    /// Le dégradé de la marque (bg_hero : 225°, centre à 55 %), du haut à droite vers le vert sombre.
    private var degrade: LinearGradient {
        LinearGradient(stops: [
            Gradient.Stop(color: palette.couleur(.brand, schema: schema), location: 0),
            Gradient.Stop(color: palette.couleur(.brandDark, schema: schema), location: 0.55),
            Gradient.Stop(color: palette.couleur(.brandDark, schema: schema), location: 1),
        ], startPoint: .topTrailing, endPoint: .bottomLeading)
    }

    private var fondPage: some View {
        Rectangle()
            .fill(degrade)
    }

    /// Le bandeau : les coins du bas arrondis, et le filet de lumière du bas (blanc au centre, retrait de 36).
    private var fondEntete: some View {
        UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20, style: .continuous)
            .fill(degrade)
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.25), Color.white.opacity(0)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(height: 1)
                    .padding(.horizontal, 36)
            }
    }

    /// « Version 1.0 (12) · édition complète », centrée sous les cartes.
    private var version: some View {
        Text(modele.texteVersion, traducteur: traducteur)
            .font(.caption)
            .foregroundStyle(Teinte(.mint))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 16)
    }

    // MARK: 9. Mes données

    /// Exporter, importer, et les règles de confidentialité.
    private var carteDonnees: some View {
        Carte {
            ReglagesTitreCarte("section_data", indication: "section_data_hint")
            HStack(spacing: 8) {
                Button {
                    exporter()
                } label: {
                    reglagesTexte("action_export", traducteur)
                        .frame(maxWidth: .infinity)
                }
                Button {
                    importOuvert = true
                } label: {
                    reglagesTexte("action_import", traducteur)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.secondaire)
            .padding(.top, 12)
            Button {
                aiguillage.suivre(modele.routeConfidentialite)
            } label: {
                reglagesTexte("settings_confidentialite", traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ReglagesBoutonTexte())
            .padding(.top, 8)
        }
    }

    private var pageAvecFichiers: some View {
        page
            .fileExporter(isPresented: $exportOuvert, document: documentExport, contentTypes: [.json],
                          defaultFilename: nomExport) { resultat in
                exportFini(resultat)
            } onCancellation: {
                // Une annulation ne dit rien (writeBackup d'Android).
            }
            .fileImporter(isPresented: $importOuvert, allowedContentTypes: [.json, .plainText, .data]) { resultat in
                fichierChoisi(resultat)
            }
    }

    /// « Exporter » : la sauvegarde de l'instant, puis le sélecteur de fichiers du système (CreateDocument).
    private func exporter() {
        let export = modele.preparerExport()
        documentExport = ReglagesDocument(donnees: export.donnees)
        nomExport = export.nomDeFichier
        exportOuvert = true
    }

    private func exportFini(_ resultat: Result<URL, any Error>) {
        switch resultat {
        case .success:
            modele.exportTermine(reussi: true)
        case .failure:
            modele.exportTermine(reussi: false)
        }
        documentExport = nil
    }

    /// « Importer » (OpenDocument) : les octets du fichier choisi, lus sous l'accès que le système accorde ; nil
    /// s'ils n'ont pu l'être, ce que le modèle dit par son message.
    private func fichierChoisi(_ resultat: Result<URL, any Error>) {
        let donnees: Data?
        switch resultat {
        case .success(let url):
            donnees = ReglagesVue.lire(url)
        case .failure:
            donnees = nil
        }
        Task.immediate { @MainActor [modele] in
            await modele.importer(donnees)
        }
    }

    private static func lire(_ url: URL) -> Data? {
        let acces = url.startAccessingSecurityScopedResource()
        defer {
            if acces { url.stopAccessingSecurityScopedResource() }
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            return nil
        }
    }

    // MARK: Les listes et l'heure

    /// La liste à choix ouverte. Le geste qui baisse la feuille la ferme sans rien changer ; un choix la referme par
    /// le modèle (qui peut ouvrir aussitôt la durée libre) : la fermeture que SwiftUI écrit alors n'a rien à faire.
    private var listeOuverte: Binding<ReglagesListe?> {
        let modele = self.modele
        return Binding(get: { @MainActor in
            if case .choix(let liste)? = modele.dialogue { return liste }
            return nil
        }, set: { @MainActor nouvelle in
            guard nouvelle == nil, case .choix? = modele.dialogue else { return }
            modele.fermerDialogue()
        })
    }

    private func feuilleChoix(_ liste: ReglagesListe) -> some View {
        let modele = self.modele
        return ReglagesFeuilleChoix(choix: modele.choix(liste), choisir: { rang in
            Task.immediate { @MainActor in
                do {
                    try await modele.choisir(rang, dans: liste)
                } catch {
                    // La persistance a refusé d'écrire : rien de plus, comme Store sur Android.
                }
            }
        }, fermer: {
            modele.fermerDialogue()
        })
    }

    private var heureOuverte: Binding<ReglagesHeureOuverte?> {
        let modele = self.modele
        return Binding(get: { @MainActor in
            if case .heure(let borne)? = modele.dialogue { return ReglagesHeureOuverte(borne: borne) }
            return nil
        }, set: { @MainActor nouvelle in
            guard nouvelle == nil, case .heure? = modele.dialogue else { return }
            modele.fermerDialogue()
        })
    }

    private func feuilleHeure(_ borne: ReglagesBorne) -> some View {
        let modele = self.modele
        let initiale = modele.heureInitiale(borne)
        return ReglagesFeuilleHeure(heure: initiale.heure, minute: initiale.minute,
                                    titre: reglagesTexte("settings_window", traducteur),
                                    valider: { heure, minute in
            Task.immediate { @MainActor in
                do {
                    try await modele.choisirHeure(borne, heure: heure, minute: minute)
                } catch {
                    // La persistance a refusé d'écrire : rien de plus, comme Store sur Android.
                }
            }
        }, annuler: {
            modele.fermerDialogue()
        })
    }

    // MARK: Les alertes

    /// Les fenêtres qui sont des alertes : la durée libre, le prénom, la divulgation de Temps d'écran, la
    /// confirmation de la réinitialisation. Chaque bouton ferme la fenêtre par le modèle lui-même ; la fermeture que
    /// SwiftUI écrit ici n'a rien à faire (et surtout pas « fermerDialogue », qui annulerait l'allumage du mode que
    /// « Continuer » attend).
    private var alerteOuverte: Binding<Bool> {
        let modele = self.modele
        return Binding(get: { @MainActor in
            switch modele.dialogue {
            case .dureeLibre?, .prenom?, .divulgationTempsEcran?, .confirmationReinitialisation?:
                return true
            case .choix?, .heure?, nil:
                return false
            }
        }, set: { @MainActor _ in
        })
    }

    private var titreAlerte: Text {
        switch modele.dialogue {
        case .dureeLibre?:
            reglagesTexte("duration_custom_title", traducteur)
        case .prenom?:
            reglagesTexte("settings_name", traducteur)
        case .divulgationTempsEcran?:
            reglagesTexte("reglages_divulgation_titre", traducteur)
        case .confirmationReinitialisation?:
            reglagesTexte("reset_confirm_title", traducteur)
        case .choix?, .heure?, nil:
            Text(verbatim: "")
        }
    }

    /// Le champ de la fenêtre qui s'ouvre reprend la valeur réglée (DureeSeance.saisir, le prénom).
    private func preparerSaisie(_ dialogue: ReglagesDialogue?) {
        switch dialogue {
        case .prenom?:
            saisie = modele.prenomInitial
        case .dureeLibre?:
            saisie = modele.dureeLibreInitiale
        default:
            break
        }
    }

    @ViewBuilder
    private func actionsAlerte(_ dialogue: ReglagesDialogue) -> some View {
        switch dialogue {
        case .dureeLibre(let liste):
            actionsDureeLibre(liste)
        case .prenom:
            actionsPrenom
        case .divulgationTempsEcran:
            actionsDivulgation
        case .confirmationReinitialisation:
            actionsReinitialisation
        case .choix, .heure:
            EmptyView()
        }
    }

    @ViewBuilder
    private func messageAlerte(_ dialogue: ReglagesDialogue) -> some View {
        switch dialogue {
        case .divulgationTempsEcran:
            reglagesTexte("reglages_divulgation_texte", traducteur)
        case .confirmationReinitialisation:
            reglagesTexte("reset_confirm_text", traducteur)
        case .dureeLibre, .prenom, .choix, .heure:
            EmptyView()
        }
    }

    /// La durée libre (DureeSeance.saisir) : un nombre de minutes, au clavier des chiffres.
    @ViewBuilder
    private func actionsDureeLibre(_ liste: ReglagesListe) -> some View {
        let modele = self.modele
        TextField(text: $saisie, prompt: reglagesTexte("duration_custom_hint", traducteur)) {
            reglagesTexte("duration_custom_hint", traducteur)
        }
        .keyboardType(.numberPad)
        Button {
            let texte = saisie
            Task.immediate { @MainActor in
                do {
                    try await modele.validerDureeLibre(texte, pour: liste)
                } catch {
                    // La persistance a refusé d'écrire : rien de plus, comme Store sur Android.
                }
            }
        } label: {
            reglagesTexte("reglages_ok", traducteur)
        }
        Button(role: .cancel) {
            modele.fermerDialogue()
        } label: {
            reglagesTexte("action_back", traducteur)
        }
    }

    /// Le prénom : une ligne, que l'accueil reprend ; vide est une réponse.
    @ViewBuilder
    private var actionsPrenom: some View {
        let modele = self.modele
        TextField(text: $saisie, prompt: reglagesTexte("settings_name", traducteur)) {
            reglagesTexte("settings_name", traducteur)
        }
        .textContentType(.givenName)
        Button {
            let texte = saisie
            Task.immediate { @MainActor in
                do {
                    try await modele.enregistrerPrenom(texte)
                } catch {
                    // La persistance a refusé d'écrire : rien de plus, comme Store sur Android.
                }
            }
        } label: {
            reglagesTexte("action_save", traducteur)
        }
        Button(role: .cancel) {
            modele.fermerDialogue()
        } label: {
            reglagesTexte("action_back", traducteur)
        }
    }

    /// La divulgation de Temps d'écran (Divulgation.kt, PORTAGE § 2.1.13) : « Continuer » présente la feuille du
    /// système, puis suit la route que rend l'allumage du mode s'il venait de l'interrupteur.
    @ViewBuilder
    private var actionsDivulgation: some View {
        let modele = self.modele
        let aiguillage = self.aiguillage
        Button {
            Task.immediate { @MainActor in
                do {
                    let route = try await modele.continuerDivulgation()
                    aiguillage.suivre(route)
                } catch {
                    // La persistance a refusé d'écrire : rien de plus, comme Store sur Android.
                }
            }
        } label: {
            reglagesTexte("reglages_divulgation_continuer", traducteur)
        }
        Button(role: .cancel) {
            modele.fermerDialogue()
        } label: {
            reglagesTexte("reglages_divulgation_pas_maintenant", traducteur)
        }
    }

    /// « Tout effacer ? » : « Non » ferme ; « Oui » efface tout et l'app repart de la présentation.
    @ViewBuilder
    private var actionsReinitialisation: some View {
        let modele = self.modele
        let aiguillage = self.aiguillage
        Button(role: .cancel) {
            modele.fermerDialogue()
        } label: {
            reglagesTexte("reset_confirm_no", traducteur)
        }
        Button(role: .destructive) {
            Task.immediate { @MainActor in
                do {
                    let route = try await modele.reinitialiser()
                    aiguillage.suivre(route)
                } catch {
                    // La persistance a refusé d'écrire : l'effacement reste en mémoire (Magasin) ; le modèle ne
                    // rend pas de route dans ce cas, la vue n'en invente pas.
                }
            }
        } label: {
            reglagesTexte("reset_confirm_yes", traducteur)
        }
    }

    // MARK: Le message passager (Toast)

    @ViewBuilder
    private var messagePassager: some View {
        if let message = modele.message {
            Text(message, traducteur: traducteur)
                .font(.subheadline)
                .foregroundStyle(Teinte(.paper))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Teinte(.ink).opacity(0.92), in: Capsule())
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                // Un Toast ne prend pas les touchers : ce qui est dessous reste touchable.
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .transition(reduireAnimations ? .identity : .opacity)
                .task(id: message) {
                    await montrerMessage(message)
                }
        }
    }

    /// Le Toast (LENGTH_LONG, 3,5 s) : VoiceOver le dit (TalkBack lit un Toast), puis il s'efface. Un autre
    /// message, ou le départ de l'écran, annule l'attente.
    private func montrerMessage(_ message: Libelle) async {
        AccessibilityNotification.Announcement(traducteur.texte(message)).post()
        do {
            try await Task.sleep(for: .milliseconds(3_500))
        } catch {
            return
        }
        modele.messageVu()
    }
}

/// La place d'une carte dans la page (style Card) : 16 sur les côtés, 14 au-dessus, et son ancre de défilement.
private struct ReglagesPlaceCarte: ViewModifier {
    let section: ReglagesSection

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .id(section)
    }
}
