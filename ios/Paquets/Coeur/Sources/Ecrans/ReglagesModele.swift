import Foundation
import Observation
import Coeur
import Barriere

// L'onglet Réglages (SettingsActivity.kt, activity_settings.xml, item_permission.xml ; Permissions.kt et
// Divulgation.kt pour les autorisations) : chaque réglage d'Android, sous sa clé d'Android, les autorisations
// rassemblées, l'état de la barrière, l'export et l'import de la sauvegarde, la réinitialisation.
//
// Ce que fait iOS autrement (PORTAGE.md) :
// - la langue se règle dans les Réglages du système (§ 2.2.7) : la ligne y mène (`ReglagesRoute.reglagesApp`) ;
// - « Ne pas déranger » n'a pas d'équivalent (§ 2.2.6) : la ligne mène à une aide (`.aideConcentration`) ;
// - les autorisations sont les notifications et, avec la barrière, Temps d'écran ; la batterie et
//   l'affichage par-dessus n'existent pas (§ 2.3). La divulgation d'Android est gardée devant Temps d'écran ;
// - l'icône suit l'adresse et l'accent sur un geste seulement (§ 2.3, IconeLanceur) ;
// - un service ne tourne pas en fond : ce qu'Android relit de lui-même (GateService, Reminder, LevanaAlerte,
//   StreakWidget) est à réécrire après un changement (`ReglagesEffets`).

// MARK: Les services propres à l'écran

/// Ce que l'app constate de Temps d'écran pour la carte d'état (FamilyControls, DeviceActivityCenter, la boîte de
/// l'extension) et le nombre de jetons de la sélection (FamilyActivitySelection) : ce que Permissions.kt et
/// `Store.blockedApps(context).size` lisent sur Android.
public protocol ReglagesBarriereSysteme: Sendable {
    func constat() async -> Constat
    func nombreDeJetons() async -> Int
}

/// Une barrière qui rend ce qu'on lui a dit de rendre.
public actor ReglagesFausseBarriere: ReglagesBarriereSysteme {
    private var constatRendu: Constat
    private var jetons: Int
    public private(set) var lectures = 0

    public init(constat: Constat = Constat(), jetons: Int = 0) {
        constatRendu = constat
        self.jetons = jetons
    }

    public func regler(constat: Constat, jetons: Int) {
        constatRendu = constat
        self.jetons = jetons
    }

    public func constat() -> Constat {
        lectures += 1
        return constatRendu
    }

    public func nombreDeJetons() -> Int {
        jetons
    }
}

/// L'icône de l'app (`UIApplication.setAlternateIconName` dans l'app) : nil désigne l'icône principale.
public protocol ReglagesIcone: Sendable {
    /// `alternateIconName`.
    func nomActuel() async -> String?
    func changer(_ nom: String?) async throws
}

/// Une icône qui retient les changements demandés.
public actor ReglagesFausseIcone: ReglagesIcone {
    public struct Refus: Error, Sendable {}

    public private(set) var nom: String?
    public private(set) var changements: [String?] = []
    private let refuse: Bool

    public init(nom: String? = nil, refuse: Bool = false) {
        self.nom = nom
        self.refuse = refuse
    }

    public func nomActuel() -> String? {
        nom
    }

    public func changer(_ nom: String?) throws {
        if refuse { throw Refus() }
        changements.append(nom)
        self.nom = nom
    }
}

/// Ce qu'un changement de réglage oblige à réécrire hors de l'écran. Android le relit de lui-même ou le relance
/// (GateService, Reminder.reschedule, LevanaAlerte.programmer, StreakWidget.refresh) ; iOS doit le redéposer.
public struct ReglagesRepercussions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// L'instantané de la barrière (barriere/etat.json) et la surveillance de Temps d'écran (`applyServiceState`).
    public static let barriere = ReglagesRepercussions(rawValue: 1)
    /// Les notifications prévues : rappels, Chabbat, Levana (Reminder.reschedule, LevanaAlerte.programmer).
    public static let rappels = ReglagesRepercussions(rawValue: 2)
    /// Les widgets (StreakWidget.refresh).
    public static let widgets = ReglagesRepercussions(rawValue: 4)

    public static let tout: ReglagesRepercussions = [.barriere, .rappels, .widgets]
}

/// Réécrit ce que les réglages changés touchent, d'après le journal et les réglages tels qu'ils viennent d'être
/// écrits. Dans l'app : le dépôt de etat.json, le planificateur des notifications, `WidgetCenter`.
public protocol ReglagesEffets: Sendable {
    func repercuter(_ quoi: ReglagesRepercussions, journal: Journal, reglages: Reglages) async
}

/// Des effets qui ne font que retenir ce qu'on leur demande.
public actor ReglagesFauxEffets: ReglagesEffets {
    /// Chaque demande, dans l'ordre.
    public private(set) var demandes: [ReglagesRepercussions] = []
    /// Les réglages de la dernière demande.
    public private(set) var derniersReglages: Reglages?

    public init() {}

    public func repercuter(_ quoi: ReglagesRepercussions, journal: Journal, reglages: Reglages) {
        demandes.append(quoi)
        derniersReglages = reglages
    }
}

// MARK: Ce que l'écran montre

/// Un texte montré : une chaîne du catalogue, ou un texte tel quel (le prénom, le nom d'une langue écrit dans
/// cette langue, une heure « 06:00 »).
public enum ReglagesTexte: Sendable, Hashable {
    case libelle(Libelle)
    case brut(String)
}

/// La version de l'app (`BuildConfig.VERSION_NAME`, `VERSION_CODE`) : `CFBundleShortVersionString` et
/// `CFBundleVersion`, que l'app lit et donne au modèle.
public struct ReglagesVersion: Sendable, Hashable {
    public let nom: String
    public let numero: Int

    public init(nom: String, numero: Int) {
        self.nom = nom
        self.numero = numero
    }
}

/// Les cartes de l'écran, dans l'ordre du layout : de quoi y faire défiler la vue.
public enum ReglagesSection: String, Sendable, Hashable, CaseIterable {
    case entete, langue, apparence, zmanim, etatBarriere, barriere, rythme, autorisations, dedicace, donnees,
         reinitialisation, version
}

/// Les écrans et pages qu'ouvrent les réglages.
public enum ReglagesRoute: Sendable, Hashable {
    /// La page de l'app dans les Réglages d'iOS (`UIApplication.openSettingsURLString`) : la langue (§ 2.2.7).
    case reglagesApp
    /// Les notifications de l'app dans les Réglages d'iOS (`openNotificationSettingsURLString`) : une demande
    /// déjà refusée ne se repose plus (Permissions.notificationSettingsIntent).
    case reglagesNotifications
    /// « Revoir la présentation » (OnboardingActivity) : `PresentationModele`, page 0.
    case presentation
    /// L'aperçu du bouclier (GateService.preview ; tâche 27).
    case apercuBarriere
    /// Le choix des applications à retenir (AppPickerActivity ; `FamilyActivityPicker` sur iOS).
    case choixApplications
    /// La dédicace (Dedicace.ouvrir) : un écran à venir.
    case dedicace
    /// Une page dans le navigateur (les règles de confidentialité).
    case navigateur(String)
    /// L'aide qui remplace « Ne pas déranger » : créer un mode de concentration (§ 2.2.6).
    case aideConcentration
    /// Tout a été effacé : l'app repart de zéro, présentation comprise (MainActivity, tâche vidée).
    case recommencer
}

/// Les listes à choix (`choisirParmi`, `pickMinutes`, `DureeSeance.choisir`, `askAdresse`).
public enum ReglagesListe: String, Sendable, Hashable, CaseIterable, Identifiable {
    case adresse, mode, fond, accent, police, ouverture, usageLevana, sourceHalakha, report, duree, objectif

    public var id: String { rawValue }
}

/// Une ligne d'une liste à choix.
public struct ReglagesOption: Sendable, Hashable, Identifiable {
    /// Son rang dans la liste : ce que `choisir(_:dans:)` reçoit.
    public let rang: Int
    public let libelle: Libelle
    /// La valeur réglée (le bouton radio coché) ; jamais vrai dans une liste sans coche.
    public let cochee: Bool

    public var id: Int { rang }
}

/// Une liste à choix ouverte : son titre et ses lignes.
public struct ReglagesChoix: Sendable, Hashable, Identifiable {
    public let liste: ReglagesListe
    public let titre: Libelle
    public let options: [ReglagesOption]
    /// Vrai : des boutons radio, la valeur réglée cochée (`setSingleChoiceItems`) ; faux : une simple liste
    /// (`setItems` : le report et les durées), qui se referme au premier toucher.
    public let aCocher: Bool

    public var id: String { liste.rawValue }
}

/// Une borne de la fenêtre de la barrière.
public enum ReglagesBorne: String, Sendable, Hashable, CaseIterable {
    case debut, fin
}

/// La fenêtre ouverte par-dessus l'écran.
public enum ReglagesDialogue: Sendable, Hashable, Identifiable {
    /// Une liste à choix (`choix(_:)` en donne le contenu).
    case choix(ReglagesListe)
    /// La durée saisie en minutes (DureeSeance.saisir) pour la durée habituelle ou l'objectif.
    case dureeLibre(ReglagesListe)
    /// Le prénom (askName).
    case prenom
    /// L'heure d'une borne de la fenêtre (TimePickerDialog, 24 h).
    case heure(ReglagesBorne)
    /// La divulgation avant de demander Temps d'écran (Divulgation.montrer).
    case divulgationTempsEcran
    /// « Tout effacer ? » (confirmerReinitialisation).
    case confirmationReinitialisation

    public var id: String {
        switch self {
        case .choix(let liste): "choix-" + liste.rawValue
        case .dureeLibre(let liste): "duree-" + liste.rawValue
        case .prenom: "prenom"
        case .heure(let borne): "heure-" + borne.rawValue
        case .divulgationTempsEcran: "divulgation"
        case .confirmationReinitialisation: "reinitialisation"
        }
    }
}

/// Les interrupteurs de l'écran (`bindSwitch`), chacun sur sa clé d'Android.
public enum ReglagesInterrupteur: String, Sendable, Hashable, CaseIterable {
    /// « Je suis avec Hachem » (`enabled`) ; seulement avec la barrière.
    case barriere
    /// Grand texte de lecture (`lecture_echelle` à 1,4).
    case grandTexte
    /// Afficher Birkat haLevana (`levana_affichee`).
    case levana
    /// Rappel de Birkat haLevana (`levana_rappel`).
    case levanaRappel
    /// Afficher les hilloulot (`hilloulot_affichees`).
    case hilloulot
    /// Afficher la halakha du jour (`halakha_affichee`).
    case halakha
    /// Chabbat et Yom Tov (`pause_shabbat`).
    case chabbat
    /// Masquer le décompte (`hide_countdown`).
    case masquerDecompte
    /// Hitbodedout guidée (`guided_hitbodedut`).
    case guidee
    /// Pause aujourd'hui (le jour dans `paused_dates`).
    case pauseAujourdhui
}

/// Une autorisation que l'app demande sur iOS (Autorisation.kt, dans l'ordre de l'utilité décroissante).
public enum ReglagesAutorisation: String, Sendable, Hashable, CaseIterable, Identifiable {
    case notifications
    /// Family Controls : ce que l'affichage par-dessus et l'accès aux données d'utilisation sont sur Android.
    case tempsEcran

    public var id: String { rawValue }

    public var titre: Libelle {
        switch self {
        case .notifications: Libelle(Autorisation.notifications.titre)
        case .tempsEcran: Libelle("reglages_autorisation_temps_ecran")
        }
    }

    public var pourquoi: Libelle {
        switch self {
        case .notifications: Libelle(Autorisation.notifications.pourquoi)
        case .tempsEcran: Libelle("reglages_autorisation_temps_ecran_pourquoi")
        }
    }

    /// Elle ne sert qu'à la barrière, absente de l'édition légère.
    public var barriere: Bool {
        self == .tempsEcran
    }

    /// Celles qu'il y a lieu de demander dans cette édition (PermissionRules.demandees).
    public static func demandees(avecBarriere: Bool) -> [ReglagesAutorisation] {
        allCases.filter { avecBarriere || !$0.barriere }
    }
}

/// Une ligne de la carte des autorisations (item_permission.xml).
public struct ReglagesLigneAutorisation: Sendable, Hashable, Identifiable {
    public let autorisation: ReglagesAutorisation
    public let titre: Libelle
    public let pourquoi: Libelle
    public let accordee: Bool

    public var id: String { autorisation.rawValue }

    /// « Accordée » ou « Manquante ».
    public var etat: Libelle {
        Libelle(accordee ? "permission_granted" : "permission_missing")
    }

    /// La couleur de l'état (colors.xml) : « brand » accordée, « warning » manquante.
    public var couleurEtat: String {
        accordee ? "brand" : "warning"
    }

    /// « Accorder » n'agit que sur ce qui manque.
    public var boutonActif: Bool {
        !accordee
    }
}

/// La carte « État du mode » (renderDiagnostic, GateStatus.titleOf, detailOf, colorOf).
public struct ReglagesCarteBarriere: Sendable, Equatable {
    public let etat: GateState
    public let titre: Libelle
    /// Le nom de la couleur du titre dans colors.xml : « brand », « warning » ou « muted ».
    public let couleurTitre: String
    /// Le titre cède la place au bouton quand une autorisation manque : le même message, mais actionnable.
    public let titreVisible: Bool
    public let detail: Libelle
    /// « Autorisations manquantes, les accorder » : mène à la carte des autorisations.
    public let boutonAutorisations: Bool
}

/// Ce que l'export remet à `fileExporter`.
public struct ReglagesExport: Sendable, Equatable {
    /// Le JSON de Store.exportJson, en UTF-8.
    public let donnees: Data
    /// « myhitbodedut-2026-11-16.json ».
    public let nomDeFichier: String
}

// MARK: Le modèle

/// L'onglet Réglages. Les valeurs se lisent dans le `Magasin` à chaque fois (un réglage changé ailleurs se voit
/// ici) ; ce qui vient du système (autorisations, Temps d'écran, icône) se relit par `rafraichir()`, que la vue
/// appelle à l'apparition et au retour au premier plan (onResume d'Android).
@MainActor
@Observable
public final class ReglagesModele {

    /// L'échelle du grand texte (SettingsActivity.GRAND_TEXTE).
    public static let grandTexte: Float = 1.4
    /// Les durées de report proposées (pickMinutes).
    public static let reports = [5, 10, 15, 30, 60]
    /// La page publique des règles de confidentialité (CelebrationActivity.LIEN_WEB + « confidentialite.html »).
    public static let lienConfidentialite = "https://hil123.github.io/myhitbodedut-web/confidentialite.html"

    private let magasin: Magasin
    private let contenus: ContenusApp
    private let horloge: any Horloge
    private let notificateur: any Notificateur
    private let tempsEcran: any TempsEcran
    private let activite: any ActiviteEnDirect
    private let systemeBarriere: any ReglagesBarriereSysteme
    private let icone: any ReglagesIcone
    private let effets: any ReglagesEffets

    /// L'édition complète (`BuildConfig.HAS_GATE`) : sans elle, ni carte de barrière, ni Temps d'écran.
    public let avecBarriere: Bool
    /// La langue de l'app : « fr », « en » ou « he » (Traducteur.langueApp).
    public let langue: String
    public let version: ReglagesVersion

    /// La fenêtre ouverte par-dessus l'écran ; nil sans fenêtre.
    public var dialogue: ReglagesDialogue? = nil
    /// Le message bref à montrer (les Toast d'Android) ; `messageVu()` l'efface.
    public private(set) var message: Libelle? = nil
    /// La carte vers laquelle faire défiler l'écran ; `defilementFait()` l'efface.
    public private(set) var cibleDefilement: ReglagesSection? = nil

    /// Le système a été lu une fois au moins : avant, ni résumé ni carte d'état (le TextView vide d'Android).
    public private(set) var systemeLu = false
    public private(set) var notificationsAccordees = false
    public private(set) var constat = Constat()
    /// Les applications retenues : les jetons de la sélection de Temps d'écran.
    public private(set) var nombreDeJetons = 0
    /// L'icône posée (nil : la principale), lue par `rafraichir()`.
    public private(set) var iconeActuelle: String? = nil
    /// La carte d'état de la barrière, recalculée à chaque rafraîchissement et après chaque changement (elle
    /// compte deux ans de jours chômés : pas à chaque dessin) ; nil sans barrière ou avant la première lecture.
    public private(set) var carteBarriere: ReglagesCarteBarriere? = nil

    /// La demande de notification a déjà été présentée (`notificationsDemandees` d'Android) : la suivante passe
    /// par les Réglages d'iOS, qui ne reposent jamais la question.
    private var notificationsDemandees = false

    public init(magasin: Magasin, contenus: ContenusApp, horloge: any Horloge, notificateur: any Notificateur,
                tempsEcran: any TempsEcran, activite: any ActiviteEnDirect, barriere: any ReglagesBarriereSysteme,
                icone: any ReglagesIcone, effets: any ReglagesEffets, avecBarriere: Bool, langue: String,
                version: ReglagesVersion) {
        self.magasin = magasin
        self.contenus = contenus
        self.horloge = horloge
        self.notificateur = notificateur
        self.tempsEcran = tempsEcran
        self.activite = activite
        self.systemeBarriere = barriere
        self.icone = icone
        self.effets = effets
        self.avecBarriere = avecBarriere
        self.langue = Traducteur.langueApp(langue)
        self.version = version
    }

    /// Un écran d'aperçu : des réglages donnés, dans un magasin en mémoire, avec des services qui ne font rien.
    public convenience init(apercu enregistrement: Enregistrement = Enregistrement(), avecBarriere: Bool = true,
                            langue: String = "fr") {
        self.init(magasin: Magasin.enMemoire(enregistrement),
                  contenus: ContenusApp(lecteur: { _ in nil }),
                  horloge: HorlogeSysteme(),
                  notificateur: FauxNotificateur(),
                  tempsEcran: FauxTempsEcran(),
                  activite: FausseActiviteEnDirect(),
                  barriere: ReglagesFausseBarriere(jetons: 3),
                  icone: ReglagesFausseIcone(),
                  effets: ReglagesFauxEffets(),
                  avecBarriere: avecBarriere,
                  langue: langue,
                  version: ReglagesVersion(nom: "1.0", numero: 1))
    }

    private var reglages: Reglages { magasin.reglages }

    private var fuseauTelephone: String { horloge.fuseau.identifiant }

    // MARK: Le système

    /// Relit les autorisations, Temps d'écran et l'icône, puis la carte d'état (onResume → refresh).
    public func rafraichir() async {
        notificationsAccordees = await notificateur.autorisation()
        if avecBarriere {
            constat = await systemeBarriere.constat()
            let jetons = await systemeBarriere.nombreDeJetons()
            nombreDeJetons = max(jetons, 0)
        }
        iconeActuelle = await icone.nomActuel()
        systemeLu = true
        recalculer()
    }

    /// La carte d'état d'après le magasin, l'heure qu'il est et ce que le système a dit (renderDiagnostic).
    private func recalculer() {
        guard avecBarriere, systemeLu else {
            carteBarriere = nil
            return
        }
        let millis = horloge.maintenant
        let fuseau = horloge.fuseau
        let etat = EtatBarriere.etat(journal: magasin.journal, reglages: reglages, millis: millis, fuseau: fuseau,
                                     nombreDeJetons: nombreDeJetons, textes: { $0.cle })
        let verdict = GateStatus.evaluate(etat, maintenant: EtatBarriere.horodatage(millis: millis, fuseau: fuseau),
                                          constat: constat)
        let manque = verdict == .missingPermissions
        carteBarriere = ReglagesCarteBarriere(
            etat: verdict,
            titre: GateStatus.titleOf(verdict),
            couleurTitre: GateStatus.colorOf(verdict),
            titreVisible: !manque,
            detail: GateStatus.detailOf(verdict, etat: etat),
            // iOS : un accès retiré se rend aussi depuis la carte des autorisations.
            boutonAutorisations: manque || verdict == .autorisationRetiree)
    }

    // MARK: L'en-tête et les autorisations

    /// Les lignes d'autorisation de cette édition, dans l'ordre (renderPermissions).
    public var autorisations: [ReglagesLigneAutorisation] {
        ReglagesAutorisation.demandees(avecBarriere: avecBarriere).map { autorisation in
            ReglagesLigneAutorisation(autorisation: autorisation, titre: autorisation.titre,
                                      pourquoi: autorisation.pourquoi, accordee: estAccordee(autorisation))
        }
    }

    private func estAccordee(_ autorisation: ReglagesAutorisation) -> Bool {
        switch autorisation {
        case .notifications: notificationsAccordees
        case .tempsEcran: constat.autorise
        }
    }

    /// La phrase en tête : ce qui manque, ou que rien ne manque (renderSummary) ; nil avant la première lecture.
    public var resume: Libelle? {
        guard systemeLu else { return nil }
        let manquantes = autorisations.filter { !$0.accordee }.count
        if manquantes == 0 { return Libelle("settings_all_granted") }
        return Libelle.pluriel("permissions_missing", quantite: manquantes, .entier(manquantes))
    }

    /// « Accorder » (demander) : les notifications directement, ou les Réglages d'iOS si la demande a déjà été
    /// faite ; Temps d'écran après la divulgation. Rend l'écran à ouvrir, s'il y en a un.
    @discardableResult
    public func accorder(_ autorisation: ReglagesAutorisation) async -> ReglagesRoute? {
        switch autorisation {
        case .notifications:
            return await accorderNotifications()
        case .tempsEcran:
            // Les accès spéciaux passent par la divulgation, jamais directement (Divulgation.kt).
            dialogue = .divulgationTempsEcran
            return nil
        }
    }

    /// askNotifications.
    private func accorderNotifications() async -> ReglagesRoute? {
        if await notificateur.autorisation() {
            notificationsAccordees = true
            return nil
        }
        if notificationsDemandees { return .reglagesNotifications }
        notificationsDemandees = true
        notificationsAccordees = await notificateur.demanderAutorisation()
        return nil
    }

    /// « Continuer » de la divulgation : la feuille de Temps d'écran, puis l'état relu.
    public func continuerDivulgation() async {
        dialogue = nil
        _ = await tempsEcran.demanderAutorisation()
        await rafraichir()
        await repercuter(.barriere)
    }

    /// « Pas maintenant », « Retour », un toucher hors de la fenêtre : rien ne change.
    public func fermerDialogue() {
        dialogue = nil
    }

    /// « Autorisations manquantes, les accorder » : la carte des autorisations sous les yeux (scrollToPermissions).
    public func montrerAutorisations() {
        cibleDefilement = .autorisations
    }

    public func defilementFait() {
        cibleDefilement = nil
    }

    public func messageVu() {
        message = nil
    }

    /// Un écran du système n'a pu s'ouvrir (safeStart).
    public func routeImpossible() {
        message = Libelle("settings_screen_missing")
    }

    // MARK: Langue, adresse, présentation

    /// Le nom de la langue de l'app, écrit dans cette langue (« עברית »).
    public var nomLangue: ReglagesTexte {
        .brut(Langues.nomDe(langue))
    }

    /// La langue se règle dans les Réglages d'iOS (§ 2.2.7).
    public var routeLangue: ReglagesRoute { .reglagesApp }

    public var adresse: Libelle {
        Libelle(Adresse.parse(reglages.adresse)?.nom ?? "adresse_none")
    }

    public var routePresentation: ReglagesRoute { .presentation }

    // MARK: Apparence

    public var mode: Libelle {
        Libelle("mode_" + reglages.modeApparence)
    }

    public var fond: Libelle {
        Libelle("fond_" + reglages.fond.rawValue)
    }

    public var accent: Libelle {
        Libelle("accent_" + reglages.accent.rawValue)
    }

    public var police: Libelle {
        Libelle(PoliceHebraique.Police(rawValue: reglages.lecturePolice)?.libelle ?? "police_serif")
    }

    public var ouverture: Libelle {
        Libelle(reglages.ouverture.libelle)
    }

    /// L'icône qui va avec l'adresse et l'accent choisis (IconeLanceur.alias), sous le nom des icônes de rechange
    /// d'iOS (« Icone_f_bleu ») ; nil pour l'icône principale (le hassid sur le vert).
    public var iconeProposee: String? {
        let alias = IconeLanceur.alias(Adresse.parse(reglages.adresse), reglages.accent)
        if alias == IconeLanceur.parDefaut { return nil }
        return alias.split(separator: ".").last.map(String.init) ?? alias
    }

    /// L'icône posée est déjà celle des couleurs choisies : le bouton n'a rien à faire. Vrai tant que l'icône n'a
    /// pas été lue.
    public var iconeAJour: Bool {
        !systemeLu || iconeActuelle == iconeProposee
    }

    /// « Mettre l'icône aux couleurs choisies » : sur un geste seulement, iOS prévient à chaque changement (§ 2.3).
    public func mettreIconeAuxCouleurs() async {
        let voulue = iconeProposee
        do {
            try await icone.changer(voulue)
        } catch {
            // Refusé par le système : l'icône lue ci-dessous dit ce qui est resté.
        }
        iconeActuelle = await icone.nomActuel()
    }

    // MARK: L'écran Zmanim

    /// L'usage de Birkat haLevana choisi, ou « Selon le noussa'h · » suivi de l'usage du noussa'h (renderValues).
    public var usageLevana: Libelle {
        if let usage = reglages.levanaUsage.flatMap(Levana.Usage.init(rawValue:)) {
            return Libelle(usage.libelle)
        }
        let duNusah = Levana.Usage.duNusah(reglages.siddurNusah)
        // « %1$@ · %2$@ » dans les trois langues.
        return Libelle("zmanim_lieu_detail", .libelle(Libelle("levana_usage_auto")), .libelle(Libelle(duNusah.libelle)))
    }

    public var sourceHalakha: Libelle {
        Libelle(reglages.sourceHalakha.libelle)
    }

    // MARK: La barrière

    /// Le début et la fin de la fenêtre, en minutes depuis minuit.
    public func minutes(_ borne: ReglagesBorne) -> Int {
        switch borne {
        case .debut: reglages.windowStart
        case .fin: reglages.windowEnd
        }
    }

    /// « 06:00 » (Store.formatMinutes, sur 24 h dans toutes les langues).
    public func texteHeure(_ borne: ReglagesBorne) -> ReglagesTexte {
        .brut(Store.formatMinutes(minutes(borne)))
    }

    /// L'heure et la minute que montre le sélecteur à son ouverture.
    public func heureInitiale(_ borne: ReglagesBorne) -> (heure: Int, minute: Int) {
        let m = minutes(borne)
        return (heure: (m / 60) % 24, minute: m % 60)
    }

    /// L'heure choisie pour une borne (pickTime → Store.setWindow).
    public func choisirHeure(_ borne: ReglagesBorne, heure: Int, minute: Int) async throws {
        dialogue = nil
        let choisie = heure * 60 + minute
        let debut = borne == .debut ? choisie : reglages.windowStart
        let fin = borne == .fin ? choisie : reglages.windowEnd
        try await modifier(.barriere) { $0.setWindow(startMinutes: debut, endMinutes: fin) }
    }

    public var report: Libelle {
        Store.formatDuration(reglages.snoozeMinutes)
    }

    /// « 3 applications bloquées », ou l'avertissement qu'aucune ne l'est.
    public var applications: Libelle {
        let n = nombreDeJetons
        if n == 0 { return Libelle("apps_none_warning") }
        return Libelle.pluriel("apps_selected", quantite: n, .entier(n))
    }

    /// « warning » sans application, « muted » sinon.
    public var couleurApplications: String {
        nombreDeJetons == 0 ? "warning" : "muted"
    }

    public var routeChoixApplications: ReglagesRoute { .choixApplications }

    /// « Voir l'écran « Je suis avec Hachem » maintenant » : l'aperçu ne demande rien sur iOS.
    public var routeApercuBarriere: ReglagesRoute { .apercuBarriere }

    // MARK: Le rythme

    /// Le prénom, ou « Non renseigné ».
    public var prenom: ReglagesTexte {
        let nom = magasin.journal.firstName
        return nom.estBlanc ? .libelle(Libelle("settings_name_empty")) : .brut(nom)
    }

    /// Le texte du champ à son ouverture.
    public var prenomInitial: String {
        magasin.journal.firstName
    }

    /// « Enregistrer » : vide est une réponse, l'accueil se tait alors.
    public func enregistrerPrenom(_ texte: String) async throws {
        dialogue = nil
        try await magasin.modifierJournal { $0.setFirstName(texte) }
    }

    public var duree: Libelle {
        Store.formatDuration(reglages.targetMinutes)
    }

    /// L'objectif de l'anneau ; sans réglage, la durée habituelle.
    public var objectif: Libelle {
        Store.formatDuration(reglages.dailyGoal)
    }

    /// Le texte prérempli de la durée libre : la durée habituelle (DureeSeance.saisir).
    public var dureeLibreInitiale: String {
        String(reglages.targetMinutes)
    }

    /// « OK » de la durée libre : un nombre, ramené entre 1 et 240 ; autre chose ne change rien.
    public func validerDureeLibre(_ texte: String, pour liste: ReglagesListe) async throws {
        dialogue = nil
        guard let minutes = DureeSeance.lire(texte) else { return }
        try await appliquerDuree(minutes, pour: liste)
    }

    private func appliquerDuree(_ minutes: Int, pour liste: ReglagesListe) async throws {
        switch liste {
        case .duree: try await modifier(.barriere) { $0.setTargetMinutes(minutes) }
        case .objectif: try await modifier([]) { $0.setDailyGoal(minutes) }
        case .report: try await modifier(.barriere) { $0.setSnoozeMinutes(minutes) }
        default: break
        }
    }

    public var region: Libelle {
        Libelle(reglages.inIsrael(fuseauTelephone: fuseauTelephone) ? "region_israel" : "region_diaspora")
    }

    /// Israël ↔ diaspora (region_button).
    public func basculerRegion() async throws {
        let israel = reglages.inIsrael(fuseauTelephone: fuseauTelephone)
        try await modifier(.tout) { $0.setInIsrael(!israel) }
    }

    /// « Ne pas déranger » n'existe pas sur iOS : la ligne mène à l'aide (§ 2.2.6).
    public var routeConcentration: ReglagesRoute { .aideConcentration }

    // MARK: Les interrupteurs

    /// Les interrupteurs de cette édition, dans l'ordre de l'écran.
    public var interrupteurs: [ReglagesInterrupteur] {
        ReglagesInterrupteur.allCases.filter { avecBarriere || $0 != .barriere }
    }

    /// La position de l'interrupteur, lue dans les réglages.
    public func estActif(_ interrupteur: ReglagesInterrupteur) -> Bool {
        let r = reglages
        switch interrupteur {
        case .barriere: return r.isEnabled
        case .grandTexte: return r.lectureEchelle >= ReglagesModele.grandTexte
        case .levana: return r.levanaAffichee
        case .levanaRappel: return r.levanaRappel
        case .hilloulot: return r.hilloulotAffichees
        case .halakha: return r.halakhaAffichee
        case .chabbat: return r.shabbatMode
        case .masquerDecompte: return r.hideCountdown
        case .guidee: return r.guidedHitbodedut
        case .pauseAujourdhui: return r.pausedDates.contains(horloge.aujourdhui.iso)
        }
    }

    /// L'interrupteur mis sur `actif` : sa clé d'Android est écrite, puis ce qu'il touche est réécrit. Allumer la
    /// barrière demande aussi les notifications : rend l'écran à ouvrir s'il y en a un.
    @discardableResult
    public func basculer(_ interrupteur: ReglagesInterrupteur, _ actif: Bool) async throws -> ReglagesRoute? {
        switch interrupteur {
        case .barriere:
            guard avecBarriere else { return nil }
            try await modifier([.barriere, .rappels]) { $0.setEnabled(actif) }
            if actif {
                return await accorderNotifications()
            }
        case .grandTexte:
            let echelle: Float = actif ? ReglagesModele.grandTexte : 1
            try await modifier([]) { $0.setLectureEchelle(echelle) }
        case .levana:
            try await modifier([]) { $0.setLevanaAffichee(actif) }
        case .levanaRappel:
            try await modifier(.rappels) { $0.setLevanaRappel(actif) }
        case .hilloulot:
            try await modifier([]) { $0.setHilloulotAffichees(actif) }
        case .halakha:
            try await modifier([]) { $0.setHalakhaAffichee(actif) }
        case .chabbat:
            try await modifier(.tout) { $0.setShabbatMode(actif) }
        case .masquerDecompte:
            try await modifier([]) { $0.setHideCountdown(actif) }
        case .guidee:
            try await modifier([]) { $0.setGuidedHitbodedut(actif) }
        case .pauseAujourdhui:
            let jour = horloge.aujourdhui.iso
            guard reglages.pausedDates.contains(jour) != actif else { return nil }
            try await modifier(.tout) { $0.togglePausedDate(jour) }
        }
        return nil
    }

    // MARK: Les listes à choix

    /// Le contenu d'une liste : son titre, ses lignes, la valeur réglée cochée.
    public func choix(_ liste: ReglagesListe) -> ReglagesChoix {
        let r = reglages
        switch liste {
        case .adresse:
            let courante = Adresse.parse(r.adresse)
            let options: [Adresse?] = [.homme, .femme, nil]
            return coches(liste, "settings_adresse", options.map { $0?.nom ?? "adresse_none" },
                          options.firstIndex(of: courante))
        case .mode:
            let modes = ApparenceChoisie.Mode.allCases
            return coches(liste, "settings_mode", modes.map { "mode_" + $0.rawValue },
                          modes.firstIndex { $0.rawValue == r.modeApparence })
        case .fond:
            return coches(liste, "settings_fond", Fond.allCases.map { "fond_" + $0.rawValue },
                          Fond.allCases.firstIndex(of: r.fond))
        case .accent:
            return coches(liste, "settings_accent", Accent.allCases.map { "accent_" + $0.rawValue },
                          Accent.allCases.firstIndex(of: r.accent))
        case .police:
            let polices = PoliceHebraique.Police.allCases
            return coches(liste, "settings_police", polices.map { $0.libelle },
                          polices.firstIndex { $0.rawValue == r.lecturePolice })
        case .ouverture:
            let choix = Reglages.Ouverture.allCases
            return coches(liste, "settings_ouverture", choix.map { $0.libelle }, choix.firstIndex(of: r.ouverture))
        case .usageLevana:
            let choix: [Levana.Usage?] = [nil] + Levana.Usage.allCases.map { Optional($0) }
            let courant = r.levanaUsage.flatMap(Levana.Usage.init(rawValue:))
            return coches(liste, "levana_usage_titre", choix.map { $0?.libelle ?? "levana_usage_auto" },
                          choix.firstIndex(of: courant))
        case .sourceHalakha:
            let choix = Reglages.SourceHalakha.allCases
            return coches(liste, "halakha_source_titre", choix.map { $0.libelle },
                          choix.firstIndex(of: r.sourceHalakha))
        case .report:
            return simples(liste, "settings_snooze", ReglagesModele.reports.map { Store.formatDuration($0) })
        case .duree:
            return simples(liste, "settings_target", durees())
        case .objectif:
            return simples(liste, "settings_daily_goal", durees())
        }
    }

    /// Les durées proposées, puis « Durée réglable… » (DureeSeance.choisir).
    private func durees() -> [Libelle] {
        DureeSeance.proposees.map { Store.formatDuration($0) } + [Libelle("duration_custom")]
    }

    private func coches(_ liste: ReglagesListe, _ titre: String, _ cles: [String], _ cochee: Int?) -> ReglagesChoix {
        let options = cles.enumerated().map { rang, cle in
            ReglagesOption(rang: rang, libelle: Libelle(cle), cochee: rang == cochee)
        }
        return ReglagesChoix(liste: liste, titre: Libelle(titre), options: options, aCocher: true)
    }

    private func simples(_ liste: ReglagesListe, _ titre: String, _ libelles: [Libelle]) -> ReglagesChoix {
        let options = libelles.enumerated().map { rang, libelle in
            ReglagesOption(rang: rang, libelle: libelle, cochee: false)
        }
        return ReglagesChoix(liste: liste, titre: Libelle(titre), options: options, aCocher: false)
    }

    /// La ligne `rang` choisie dans une liste : la liste se referme, la valeur s'écrit sous sa clé d'Android.
    /// « Durée réglable… » ouvre la saisie libre.
    public func choisir(_ rang: Int, dans liste: ReglagesListe) async throws {
        dialogue = nil
        switch liste {
        case .adresse:
            let options: [Adresse?] = [.homme, .femme, nil]
            guard options.indices.contains(rang) else { return }
            let cle = options[rang]?.cle
            try await modifier([]) { $0.setAdresse(cle) }
        case .mode:
            let modes = ApparenceChoisie.Mode.allCases
            guard modes.indices.contains(rang) else { return }
            let cle = modes[rang].rawValue
            try await modifier(.widgets) { $0.setModeApparence(cle) }
        case .fond:
            guard Fond.allCases.indices.contains(rang) else { return }
            let fond = Fond.allCases[rang]
            try await modifier(.widgets) { $0.setFond(fond) }
        case .accent:
            guard Accent.allCases.indices.contains(rang) else { return }
            let accent = Accent.allCases[rang]
            try await modifier(.widgets) { $0.setAccent(accent) }
        case .police:
            let polices = PoliceHebraique.Police.allCases
            guard polices.indices.contains(rang) else { return }
            let cle = polices[rang].rawValue
            try await modifier([]) { $0.setLecturePolice(cle) }
        case .ouverture:
            let choix = Reglages.Ouverture.allCases
            guard choix.indices.contains(rang) else { return }
            let ouverture = choix[rang]
            try await modifier([]) { $0.setOuverture(ouverture) }
        case .usageLevana:
            let choix: [Levana.Usage?] = [nil] + Levana.Usage.allCases.map { Optional($0) }
            guard choix.indices.contains(rang) else { return }
            let cle = choix[rang]?.cle
            try await modifier(.rappels) { $0.setLevanaUsage(cle) }
        case .sourceHalakha:
            let choix = Reglages.SourceHalakha.allCases
            guard choix.indices.contains(rang) else { return }
            let source = choix[rang]
            try await modifier([]) { $0.setSourceHalakha(source) }
        case .report:
            guard ReglagesModele.reports.indices.contains(rang) else { return }
            try await appliquerDuree(ReglagesModele.reports[rang], pour: .report)
        case .duree, .objectif:
            if rang == DureeSeance.proposees.count {
                dialogue = .dureeLibre(liste)
                return
            }
            guard DureeSeance.proposees.indices.contains(rang) else { return }
            try await appliquerDuree(DureeSeance.proposees[rang], pour: liste)
        }
    }

    // MARK: La dédicace, les données, la version

    public var routeDedicace: ReglagesRoute { .dedicace }

    /// Les règles de confidentialité, à l'ancre de la langue de l'app (ouvrirConfidentialite).
    public var routeConfidentialite: ReglagesRoute {
        let ancre: String
        switch langue {
        case "he": ancre = "he"
        case "en": ancre = "en"
        default: ancre = "fr"
        }
        return .navigateur(ReglagesModele.lienConfidentialite + "#" + ancre)
    }

    /// « Version 1.0 (12) · édition complète ».
    public var texteVersion: Libelle {
        Libelle("app_version", .texte(version.nom), .entier(version.numero),
                .libelle(Libelle(avecBarriere ? "edition_full" : "edition_light")))
    }

    /// Ce que « Exporter » remet à `fileExporter` : Store.exportJson à l'instant, et le nom proposé.
    public func preparerExport() -> ReglagesExport {
        let texte = Sauvegarde.exporter(journal: magasin.journal, reglages: reglages, maintenant: horloge.maintenant,
                                        fuseauTelephone: fuseauTelephone)
        return ReglagesExport(donnees: Data(texte.utf8), nomDeFichier: Sauvegarde.nomDeFichier(horloge.aujourdhui))
    }

    /// Ce que `fileExporter` a fait du fichier (writeBackup) ; une annulation ne dit rien.
    public func exportTermine(reussi: Bool) {
        message = Libelle(reussi ? "export_ok" : "export_failed")
    }

    /// « Importer » (readBackup) : les octets du fichier choisi, nil s'il n'a pu être lu. La sauvegarde se
    /// fusionne dans le journal et les réglages (Sauvegarde.importer) ; le message dit combien de journées.
    public func importer(_ donnees: Data?) async {
        // Au plus 2 Mo : au-delà, ce n'est pas une sauvegarde de cette application.
        guard let donnees, donnees.count <= Sauvegarde.importMaxOctets else {
            message = Libelle("import_failed")
            return
        }
        let texte = String(decoding: donnees, as: UTF8.self)
        let morceaux: [Morceau]
        do {
            morceaux = try await contenus.musique()
        } catch {
            // Sans la liste des morceaux livrés, aucun morceau n'est repris ; le reste s'importe.
            morceaux = []
        }
        var journal = magasin.journal
        var nouveaux = reglages
        guard let importees = Sauvegarde.importer(texte: texte, journal: &journal, reglages: &nouveaux,
                                                  aujourdhui: horloge.aujourdhui,
                                                  morceauxLivres: Set(morceaux.map { $0.id }),
                                                  fuseauTelephone: fuseauTelephone) else {
            message = Libelle("import_invalid")
            return
        }
        let journalFusionne = journal
        let reglagesFusionnes = nouveaux
        do {
            try await magasin.modifierJournal { $0 = journalFusionne }
            try await magasin.modifierReglages { $0 = reglagesFusionnes }
        } catch {
            recalculer()
            message = Libelle("import_failed")
            return
        }
        // Le clair ou le sombre de la sauvegarde se voit de lui-même (la racine lit le magasin).
        await repercuter(.tout)
        recalculer()
        message = Libelle.pluriel("import_ok", quantite: importees, .entier(importees))
    }

    // MARK: Réinitialiser

    /// « Réinitialiser l'application » : la confirmation d'abord.
    public func demanderReinitialisation() {
        dialogue = .confirmationReinitialisation
    }

    /// « Tout effacer » : la séance, la barrière, les notifications, puis le journal et les réglages ; l'app
    /// repart de la présentation (confirmerReinitialisation).
    public func reinitialiser() async throws -> ReglagesRoute {
        dialogue = nil
        await activite.terminer()
        await tempsEcran.leverBoucliers()
        await notificateur.annulerTout()
        notificationsDemandees = false
        try await magasin.modifierJournal { $0 = Journal() }
        try await magasin.modifierReglages { $0 = Reglages() }
        await repercuter(.tout)
        recalculer()
        return .recommencer
    }

    // MARK: Écrire

    /// Écrit un changement des réglages, puis ce qu'il touche ; un changement qui ne change rien ne fait rien
    /// réécrire. La carte d'état suit, même si l'écriture échoue (le changement reste en mémoire, Magasin).
    private func modifier(_ quoi: ReglagesRepercussions, _ changement: (inout Reglages) -> Void) async throws {
        defer { recalculer() }
        let avant = magasin.reglages
        try await magasin.modifierReglages(changement)
        guard magasin.reglages != avant else { return }
        await repercuter(quoi)
    }

    private func repercuter(_ quoi: ReglagesRepercussions) async {
        guard !quoi.isEmpty else { return }
        await effets.repercuter(quoi, journal: magasin.journal, reglages: magasin.reglages)
    }
}
