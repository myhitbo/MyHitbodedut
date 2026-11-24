import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Coeur
import Ecrans

/// Les réglages (SettingsActivity.kt, activity_settings.xml), carte par carte dans l'ordre d'Android : la phrase des
/// autorisations ; la langue, l'adresse et la présentation ; l'apparence (version de l'app, mode, fond, accent,
/// police, grand texte, écran allumé, écran d'ouverture) ; l'écran Zmanim (Birkat haLevana, son rappel, l'alerte de
/// Chabbat, l'usage, les hilloulot, la halakha et sa source) ; l'état du mode et ses réglages (édition complète) ; le
/// rythme (prénom, durée, objectif, Chabbat, région, décompte, concentration, guidée, pause du jour) ; les
/// autorisations ; la dédicace ; les données ; la réinitialisation ; la version.
///
/// La vue lit `ReglagesModele` (testé sous Linux). Les pages du système (Réglages d'iOS, navigateur) s'ouvrent ici ;
/// les écrans de l'app passent par `ouvrir`, que la pile de l'onglet (ios/App) relie.
public struct ReglagesVue: View {
    private let modele: ReglagesModele
    private let carteBarriere: Bool
    private let ouvrir: @MainActor (ReglagesRoute) -> Void
    @Environment(\.traducteur) private var traducteur
    @Environment(\.openURL) private var ouvrirLien
    @Environment(\.scenePhase) private var phase
    @Environment(\.dynamicTypeSize) private var tailleTexte
    @State private var exportOuvert = false
    @State private var importOuvert = false
    @State private var sauvegarde = ReglagesSauvegarde(donnees: Data())
    @State private var nomSauvegarde = ""

    /// `carteBarriere` : l'écran défile jusqu'à la carte du mode (EXTRA_CARTE_BARRIERE).
    public init(modele: ReglagesModele, carteBarriere: Bool = false,
                ouvrir: @escaping @MainActor (ReglagesRoute) -> Void) {
        self.modele = modele
        self.carteBarriere = carteBarriere
        self.ouvrir = ouvrir
    }

    public var body: some View {
        ScrollViewReader { defilement in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    entete
                    // Sur l'iPad, deux colonnes (DeuxColonnes) : l'app, son apparence, Zmanim et le mode ; à côté, le
                    // rythme et le reste.
                    DeuxColonnes(espacement: 14) {
                        carteLangue
                        carteApparence
                        carteZmanim
                        if modele.avecBarriere {
                            carteEtatBarriere
                            carteBarriereReglages
                        }
                    } seconde: {
                        carteRythme
                        carteAutorisations
                        carteDedicace
                        carteDonnees
                        carteReinitialisation
                    }
                    Text(modele.texteVersion, traducteur: traducteur)
                        .font(.caption)
                        .foregroundStyle(Teinte(.muted))
                        .frame(maxWidth: .infinity)
                        .id(ReglagesSection.version)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .onChange(of: modele.cibleDefilement) { _, cible in
                guard let cible else { return }
                withAnimation { defilement.scrollTo(cible, anchor: .top) }
                modele.defilementFait()
            }
            .task {
                await modele.rafraichir()
                if carteBarriere && modele.avecBarriere {
                    defilement.scrollTo(ReglagesSection.etatBarriere, anchor: .top)
                }
            }
        }
        .background(Teinte(.paper))
        .navigationTitle(Text(Libelle("settings_title"), traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: Bindable(modele).dialogueLie) { dialogue in
            ReglagesBoite(modele: modele, dialogue: dialogue, ouvrir: ouvrirRoute)
                .hauteursDeFeuille([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .fileExporter(isPresented: $exportOuvert, document: sauvegarde, contentType: .json,
                      defaultFilename: nomSauvegarde) { resultat in
            switch resultat {
            case .success: modele.exportTermine(reussi: true)
            case .failure: modele.exportTermine(reussi: false)
            }
        }
        .fileImporter(isPresented: $importOuvert, allowedContentTypes: [.json, .plainText, .data]) { resultat in
            importer(resultat)
        }
        .overlay(alignment: .bottom) {
            if let message = modele.message {
                AccueilMessage(texte: Text(message, traducteur: traducteur))
                    .padding(.bottom, 24)
                    .transition(.opacity)
            }
        }
        .task(id: modele.message) {
            guard modele.message != nil else { return }
            if await AccueilAttente.ms(2_000) { modele.messageVu() }
        }
        .onChange(of: modele.routes) { _, routes in
            guard let route = routes.first else { return }
            modele.routeOuverte()
            ouvrirRoute(route)
        }
        .onChange(of: phase) { _, nouvelle in
            if nouvelle == .active { Task { await modele.rafraichir() } }
        }
    }

    // MARK: Les routes

    /// Les pages du système s'ouvrent ici ; un écran de l'app passe par `ouvrir`.
    private func ouvrirRoute(_ route: ReglagesRoute) {
        switch route {
        case .reglagesApp, .aideConcentration:
            lien(UIApplication.openSettingsURLString)
        case .reglagesNotifications:
            lien(UIApplication.openNotificationSettingsURLString)
        case .navigateur(let adresse):
            lien(adresse)
        default:
            ouvrir(route)
        }
    }

    private func lien(_ adresse: String) {
        guard let url = URL(string: adresse) else {
            modele.routeImpossible()
            return
        }
        ouvrirLien(url) { reussi in
            if !reussi { modele.routeImpossible() }
        }
    }

    private func importer(_ resultat: Result<URL, any Error>) {
        guard case .success(let url) = resultat else {
            Task { await modele.importer(nil) }
            return
        }
        let accede = url.startAccessingSecurityScopedResource()
        let donnees = try? Data(contentsOf: url)
        if accede { url.stopAccessingSecurityScopedResource() }
        Task { await modele.importer(donnees) }
    }

    // MARK: Les cartes

    /// La phrase des autorisations, en tête (settings_summary).
    @ViewBuilder
    private var entete: some View {
        if let resume = modele.resume {
            Text(resume, traducteur: traducteur)
                .tailleSp(19, poids: .bold, relativeA: .title3)
                .foregroundStyle(Teinte(.onBrand))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Teinte(.brand), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .id(ReglagesSection.entete)
        }
    }

    private var carteLangue: some View {
        Carte {
            ligne("settings_language", valeur: texte(modele.nomLangue)) { ouvrirRoute(modele.routeLangue) }
            ligne("settings_adresse", valeur: Text(modele.adresse, traducteur: traducteur)) { modele.dialogue = .choix(.adresse) }
            ligne("settings_onboarding") { ouvrir(modele.routePresentation) }
        }
        .id(ReglagesSection.langue)
    }

    private var carteApparence: some View {
        Carte {
            titreSection("section_appearance", indication: "section_appearance_hint")
            ligne("settings_version", valeur: Text(modele.versionApp, traducteur: traducteur)) {
                ouvrir(modele.routeVersionApp)
            }
            ligne("settings_mode", valeur: Text(modele.mode, traducteur: traducteur)) { modele.dialogue = .choix(.mode) }
            ligne("settings_fond", valeur: Text(modele.fond, traducteur: traducteur)) { modele.dialogue = .choix(.fond) }
            ligne("settings_accent", valeur: Text(modele.accent, traducteur: traducteur)) {
                modele.dialogue = .choix(.accent)
            }
            ligne("settings_police", valeur: Text(modele.police, traducteur: traducteur)) {
                modele.dialogue = .choix(.police)
            }
            interrupteur("settings_grand_texte", .grandTexte)
            interrupteur("settings_ecran_allume", .ecranAllume)
            ligne("settings_ouverture", valeur: Text(modele.ouverture, traducteur: traducteur)) {
                modele.dialogue = .choix(.ouverture)
            }
            if !modele.iconeAJour {
                Button {
                    Task { await modele.mettreIconeAuxCouleurs() }
                } label: {
                    Text(Libelle("ios_icone_couleurs"), traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
                .padding(.top, 8)
            }
        }
        .id(ReglagesSection.apparence)
    }

    private var carteZmanim: some View {
        Carte {
            titreSection("section_zmanim_ecran", indication: "section_zmanim_ecran_hint")
            interrupteur("reglage_levana", .levana)
            interrupteur("levana_rappel_reglage", .levanaRappel)
            interrupteur("chabbat_alerte_reglage", .chabbatAlerte)
            ligne("levana_usage_titre", valeur: Text(modele.usageLevana, traducteur: traducteur)) {
                modele.dialogue = .choix(.usageLevana)
            }
            interrupteur("hilloulot_afficher", .hilloulot)
            interrupteur("halakha_afficher", .halakha)
            ligne("halakha_source_titre", valeur: Text(modele.sourceHalakha, traducteur: traducteur)) {
                modele.dialogue = .choix(.sourceHalakha)
            }
        }
        .id(ReglagesSection.zmanim)
    }

    /// L'état du mode (renderDiagnostic) : pourquoi il agit, ou pourquoi non.
    @ViewBuilder
    private var carteEtatBarriere: some View {
        Carte {
            titreSection("section_gate_state", indication: nil)
            if let carte = modele.carteBarriere {
                if carte.titreVisible {
                    Text(carte.titre, traducteur: traducteur)
                        .font(Font.body.bold())
                        .foregroundStyle(ReglagesTeinte.nommee(carte.couleurTitre))
                        .padding(.top, 6)
                }
                Text(carte.detail, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
                    .padding(.top, 4)
                // Le bouton suit l'état (gate_fix_permissions) : les accès, l'accès rendu, le choix des applications,
                // la surveillance relancée (PORTAGE.md § 2.1.8).
                if let action = carte.action {
                    Button {
                        Task {
                            if let route = await modele.agir(action) { ouvrirRoute(route) }
                        }
                    } label: {
                        Text(action.libelle, traducteur: traducteur)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.principal)
                    .padding(.top, 10)
                }
            }
            Button {
                ouvrir(modele.routeApercuBarriere)
            } label: {
                Text(Libelle("action_preview_gate"), traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondaire)
            .padding(.top, 10)
            Button {
                ouvrir(modele.routeJournalBarriere)
            } label: {
                Text(Libelle("journal_barriere_titre"), traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondaire)
            .padding(.top, 6)
        }
        .id(ReglagesSection.etatBarriere)
    }

    private var carteBarriereReglages: some View {
        Carte {
            titreSection("section_gate", indication: "section_gate_hint")
            interrupteur("start_focus", .barriere)
            ligne("settings_window", valeur: Text(verbatim: "\(chaine(modele.texteHeure(.debut))) – \(chaine(modele.texteHeure(.fin)))")) {
                modele.dialogue = .heure(.debut)
            }
            HStack(spacing: 12) {
                Button {
                    modele.dialogue = .heure(.debut)
                } label: {
                    texte(modele.texteHeure(.debut))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
                Button {
                    modele.dialogue = .heure(.fin)
                } label: {
                    texte(modele.texteHeure(.fin))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
            }
            .environment(\.layoutDirection, .leftToRight)
            ligne("settings_snooze", valeur: Text(modele.report, traducteur: traducteur)) { modele.dialogue = .choix(.report) }
            Text(modele.applications, traducteur: traducteur)
                .font(.footnote)
                .foregroundStyle(ReglagesTeinte.nommee(modele.couleurApplications))
                .padding(.top, 8)
            Button {
                ouvrir(modele.routeChoixApplications)
            } label: {
                Text(Libelle("action_pick_apps"), traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondaire)
            .padding(.top, 8)
        }
        .id(ReglagesSection.barriere)
    }

    private var carteRythme: some View {
        Carte {
            titreSection("section_rhythm", indication: nil)
            ligne("settings_name", indication: "settings_name_hint", valeur: texte(modele.prenom)) {
                modele.dialogue = .prenom
            }
            ligne("settings_target", valeur: Text(modele.duree, traducteur: traducteur)) { modele.dialogue = .choix(.duree) }
            ligne("settings_daily_goal", indication: "settings_daily_goal_hint",
                  valeur: Text(modele.objectif, traducteur: traducteur)) { modele.dialogue = .choix(.objectif) }
            interrupteur("settings_shabbat", .chabbat, indication: "settings_shabbat_hint")
            ligne("settings_region", valeur: Text(modele.region, traducteur: traducteur)) {
                Task { try? await modele.basculerRegion() }
            }
            interrupteur("settings_hide_countdown", .masquerDecompte, indication: "settings_hide_countdown_hint")
            ReglagesMinuterieLigne(modele: modele)
            ligne("settings_ne_pas_deranger", indication: "settings_ne_pas_deranger_hint") {
                ouvrirRoute(modele.routeConcentration)
            }
            interrupteur("settings_hitbodedut", .guidee, indication: "settings_hitbodedut_hint")
            interrupteur("settings_exempt_today", .pauseAujourdhui, indication: "settings_exempt_today_hint")
        }
        .id(ReglagesSection.rythme)
    }

    private var carteAutorisations: some View {
        Carte {
            titreSection("section_permissions", indication: "section_permissions_hint")
            ForEach(modele.autorisations) { ligne in
                VStack(alignment: .leading, spacing: 4) {
                    Text(ligne.titre, traducteur: traducteur)
                        .font(Font.subheadline.weight(.semibold))
                        .foregroundStyle(Teinte(.ink))
                    Text(ligne.pourquoi, traducteur: traducteur)
                        .font(.footnote)
                        .foregroundStyle(Teinte(.muted))
                    HStack {
                        Text(ligne.etat, traducteur: traducteur)
                            .font(Font.footnote.bold())
                            .foregroundStyle(ReglagesTeinte.nommee(ligne.couleurEtat))
                        Spacer(minLength: 8)
                        Button {
                            let autorisation = ligne.autorisation
                            Task {
                                if let route = await modele.accorder(autorisation) { ouvrirRoute(route) }
                            }
                        } label: {
                            Text(Libelle("action_grant"), traducteur: traducteur)
                        }
                        .buttonStyle(.secondaire)
                        .disabled(!ligne.boutonActif)
                    }
                }
                .padding(.top, 10)
            }
        }
        .id(ReglagesSection.autorisations)
    }

    private var carteDedicace: some View {
        Carte {
            titreSection("section_dedicace", indication: "section_dedicace_hint")
            Button {
                ouvrir(modele.routeDedicace)
            } label: {
                Text(Libelle("dedicace_bouton"), traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondaire)
            .padding(.top, 10)
        }
        .id(ReglagesSection.dedicace)
    }

    private var carteDonnees: some View {
        Carte {
            titreSection("section_data", indication: "section_data_hint")
            HStack(spacing: 12) {
                Button {
                    Task {
                        // L'export emporte tout le journal : le verrou le garde aussi (revue du 15/11).
                        guard await modele.exportAutorise() else { return }
                        let export = modele.preparerExport()
                        sauvegarde = ReglagesSauvegarde(donnees: export.donnees)
                        nomSauvegarde = export.nomDeFichier
                        exportOuvert = true
                    }
                } label: {
                    Text(Libelle("action_export"), traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
                Button {
                    importOuvert = true
                } label: {
                    Text(Libelle("action_import"), traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
            }
            .padding(.top, 10)
            ReglagesVerrouLigne(modele: modele)
            ligne("settings_confidentialite") { ouvrirRoute(modele.routeConfidentialite) }
        }
        .id(ReglagesSection.donnees)
    }

    private var carteReinitialisation: some View {
        Carte {
            titreSection("reset_title", indication: "reset_hint")
            Button(role: .destructive) {
                modele.demanderReinitialisation()
            } label: {
                Text(Libelle("reset_action"), traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondaire)
            .padding(.top, 10)
        }
        .id(ReglagesSection.reinitialisation)
    }

    // MARK: Les lignes

    private func titreSection(_ cle: String, indication: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Libelle(cle), traducteur: traducteur)
                .titreCarte()
                .accessibilityAddTraits(.isHeader)
            if let indication {
                Text(Libelle(indication), traducteur: traducteur)
                    .indicationCarte()
            }
        }
        .padding(.bottom, 4)
    }

    /// Une ligne de réglage (SettingRow) : le libellé, son indication, la valeur à la couleur de l'accent, « › ».
    private func ligne(_ cle: String, indication: String? = nil, valeur: Text? = nil,
                       action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // La valeur au bout de la ligne ; sous le libellé aux tailles d'accessibilité, où les deux côte à
                // côte n'avaient plus que quelques lettres par ligne.
                RangeeAdaptable(espacement: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Libelle(cle), traducteur: traducteur)
                            .font(.subheadline)
                            .foregroundStyle(Teinte(.ink))
                        if let indication {
                            Text(Libelle(indication), traducteur: traducteur)
                                .font(.footnote)
                                .foregroundStyle(Teinte(.muted))
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if let valeur {
                        valeur
                            .font(Font.subheadline.weight(.semibold))
                            .foregroundStyle(Teinte(.brand))
                            .multilineTextAlignment(tailleTexte.isAccessibilitySize ? .leading : .trailing)
                            .lignesAuPlus(2)
                    }
                }
                Image(systemName: "chevron.forward")
                    .font(Font.footnote.weight(.semibold))
                    .foregroundStyle(Teinte(.brand))
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 52)
            // En colonne aux tailles d'accessibilité : un peu d'air entre deux lignes.
            .padding(.vertical, tailleTexte.isAccessibilitySize ? 6 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Un interrupteur (bindSwitch) : sa clé d'Android est écrite par le modèle.
    private func interrupteur(_ cle: String, _ quel: ReglagesInterrupteur, indication: String? = nil) -> some View {
        Toggle(isOn: Bindable(modele)[dynamicMember: \ReglagesModele.[interrupteur: quel]]) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Libelle(cle), traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
                if let indication {
                    Text(Libelle(indication), traducteur: traducteur)
                        .font(.footnote)
                        .foregroundStyle(Teinte(.muted))
                }
            }
        }
        .tint(Teinte(.brand))
        .frame(minHeight: 52)
    }

    private func texte(_ t: ReglagesTexte) -> Text {
        switch t {
        case .libelle(let libelle): Text(libelle, traducteur: traducteur)
        case .brut(let brut): Text(verbatim: brut)
        }
    }

    private func chaine(_ t: ReglagesTexte) -> String {
        switch t {
        case .libelle(let libelle): traducteur.texte(libelle)
        case .brut(let brut): brut
        }
    }
}

// MARK: - Les liaisons

extension ReglagesModele {
    /// La fenêtre ouverte ; la baisser d'un geste vaut « Retour » (rien ne change).
    var dialogueLie: ReglagesDialogue? {
        get { dialogue }
        set { if newValue == nil { fermerDialogue() } else { dialogue = newValue } }
    }

    /// La position d'un interrupteur, lue dans les réglages ; la poser l'écrit (et ouvre ce qu'elle demande).
    subscript(interrupteur quel: ReglagesInterrupteur) -> Bool {
        get { estActif(quel) }
        set {
            let actif = newValue
            Task { try? await self.poser(quel, actif) }
        }
    }
}

/// Les couleurs nommées par le modèle (colors.xml) : « brand », « warning », « muted ».
enum ReglagesTeinte {
    static func nommee(_ nom: String) -> AnyShapeStyle {
        switch nom {
        case "brand": AnyShapeStyle(Teinte(.brand))
        case "warning": AnyShapeStyle(AccueilFixe(jour: 0xA8561F, nuit: 0xE8A062))
        default: AnyShapeStyle(Teinte(.muted))
        }
    }
}

/// La sauvegarde exportée : le JSON de Store.exportJson.
struct ReglagesSauvegarde: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let donnees: Data

    init(donnees: Data) {
        self.donnees = donnees
    }

    init(configuration: ReadConfiguration) throws {
        donnees = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: donnees)
    }
}

// MARK: - Les fenêtres

/// La fenêtre ouverte par-dessus les réglages : une liste à choix, une durée, le prénom, une heure, la divulgation de
/// Temps d'écran, la confirmation de tout effacer.
private struct ReglagesBoite: View {
    let modele: ReglagesModele
    let dialogue: ReglagesDialogue
    let ouvrir: @MainActor (ReglagesRoute) -> Void
    @Environment(\.traducteur) private var traducteur
    @State private var saisie = ""
    @State private var heure = Date(timeIntervalSince1970: 0)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                contenu
            }
            .padding(24)
        }
        .background(Teinte(.paper))
    }

    @ViewBuilder
    private var contenu: some View {
        switch dialogue {
        case .choix(let liste):
            choix(modele.choix(liste))
        case .dureeLibre(let liste):
            saisieDuree(liste)
        case .prenom:
            prenom
        case .heure(let borne):
            choixHeure(borne)
        case .divulgationTempsEcran:
            divulgation
        case .confirmationReinitialisation:
            reinitialisation
        }
    }

    private func titre(_ libelle: Libelle) -> some View {
        Text(libelle, traducteur: traducteur)
            .tailleSp(20, poids: .bold, relativeA: .title3)
            .foregroundStyle(Teinte(.ink))
    }

    private var retour: some View {
        Button {
            modele.fermerDialogue()
        } label: {
            Text(Libelle("action_back"), traducteur: traducteur)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.secondaire)
    }

    private func choix(_ choix: ReglagesChoix) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            titre(choix.titre)
                .padding(.bottom, 8)
            ForEach(choix.options) { option in
                Button {
                    let liste = choix.liste
                    Task { try? await modele.choisir(option.rang, dans: liste) }
                } label: {
                    HStack(spacing: 10) {
                        if choix.aCocher {
                            Image(systemName: option.cochee ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(Teinte(.brand))
                                .accessibilityHidden(true)
                        }
                        Text(option.libelle, traducteur: traducteur)
                            .foregroundStyle(Teinte(.ink))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(option.cochee ? .isSelected : [])
            }
            retour
                .padding(.top, 12)
        }
    }

    private func saisieDuree(_ liste: ReglagesListe) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            titre(Libelle("duration_custom_title"))
            TextField(text: $saisie, axis: .vertical) {
                Text(Libelle("duration_custom_hint"), traducteur: traducteur)
            }
            .keyboardType(.numberPad)
            .textFieldStyle(.roundedBorder)
            .onAppear { saisie = modele.dureeLibreInitiale }
            Text(modele.erreurSaisie ?? Libelle("duration_custom_hint"), traducteur: traducteur)
                .font(.footnote)
                .foregroundStyle(modele.erreurSaisie == nil ? ReglagesTeinte.nommee("muted") : ReglagesTeinte.nommee("warning"))
            Button {
                let texte = saisie
                Task { try? await modele.validerDureeLibre(texte, pour: liste) }
            } label: {
                Text(Libelle("action_ok"), traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principal)
            retour
        }
    }

    private var prenom: some View {
        VStack(alignment: .leading, spacing: 12) {
            titre(Libelle("settings_name"))
            TextField(text: $saisie, axis: .vertical) {
                Text(Libelle("settings_name_hint"), traducteur: traducteur)
            }
            .textFieldStyle(.roundedBorder)
            .textContentType(.givenName)
            .onAppear { saisie = modele.prenomInitial }
            Text(Libelle("settings_name_hint"), traducteur: traducteur)
                .font(.footnote)
                .foregroundStyle(Teinte(.muted))
            Button {
                let texte = saisie
                Task { try? await modele.enregistrerPrenom(texte) }
            } label: {
                Text(Libelle("action_save"), traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principal)
            retour
        }
    }

    /// Le sélecteur d'heure sur 24 h (TimePickerDialog) : l'heure et la minute seules, dans un calendrier sans fuseau.
    private func choixHeure(_ borne: ReglagesBorne) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            titre(Libelle("settings_window"))
            DatePicker(selection: $heure, displayedComponents: .hourAndMinute) {
                Text(Libelle("settings_window"), traducteur: traducteur)
            }
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.timeZone, .gmt)
            .environment(\.locale, Locale(identifier: "fr_FR"))
            .frame(maxWidth: .infinity)
            .onAppear {
                let initiale = modele.heureInitiale(borne)
                heure = Date(timeIntervalSince1970: TimeInterval(initiale.heure * 3600 + initiale.minute * 60))
            }
            Button {
                let secondes = Int(heure.timeIntervalSince1970) % 86_400
                let h = secondes / 3600, m = (secondes % 3600) / 60
                Task { try? await modele.choisirHeure(borne, heure: h, minute: m) }
            } label: {
                Text(Libelle("action_ok"), traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principal)
            retour
        }
    }

    /// La divulgation avant Temps d'écran (Divulgation.montrer) : jamais l'accès sans l'avoir dit.
    private var divulgation: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Le texte de Divulgation, adapté à Temps d'écran (PORTAGE.md § 2.1.13) : ce qui est fait, ce qui ne l'est
            // pas, rien n'est envoyé, comment l'éteindre. Les divulgations d'Android ne sont pas exportées.
            titre(Libelle("temps_ecran_divulgation_titre"))
            Text(Libelle("temps_ecran_divulgation_texte"), traducteur: traducteur)
                .font(.body)
                .foregroundStyle(Teinte(.ink))
            Button {
                Task {
                    if let route = try? await modele.continuerDivulgation() { ouvrir(route) }
                }
            } label: {
                Text(Libelle("celebration_continue"), traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principal)
            Button {
                modele.fermerDialogue()
            } label: {
                Text(Libelle("temps_ecran_divulgation_pas_maintenant"), traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondaire)
        }
    }

    private var reinitialisation: some View {
        VStack(alignment: .leading, spacing: 12) {
            titre(Libelle("reset_confirm_title"))
            Text(Libelle("reset_confirm_text"), traducteur: traducteur)
                .font(.body)
                .foregroundStyle(Teinte(.ink))
            Button(role: .destructive) {
                Task {
                    if let route = try? await modele.reinitialiser() { ouvrir(route) }
                }
            } label: {
                Text(Libelle("reset_confirm_yes"), traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principal)
            Button {
                modele.fermerDialogue()
            } label: {
                Text(Libelle("reset_confirm_no"), traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondaire)
        }
    }
}
