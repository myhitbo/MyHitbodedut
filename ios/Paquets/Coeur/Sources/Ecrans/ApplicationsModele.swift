import Foundation
import Observation
import Coeur

// Le choix des applications de la barrière (AppPickerActivity.kt, activity_apps.xml, item_app.xml ; PORTAGE.md
// § 2.1.3, § 2.1.13 et § 3.7), poussé depuis « Choisir les applications » des réglages
// (`ReglagesRoute.choixApplications`).
//
// Ce que fait iOS autrement :
// - l'app ne lit pas la liste des applications : le sélecteur d'Apple (`FamilyActivityPicker`) rend des jetons
//   opaques, applications, catégories entières et sites web. « Tout sélectionner » et l'ordre alphabétique
//   d'Android se perdent ; choisir une catégorie entière les remplace ;
// - le sélecteur ne sert qu'une fois Temps d'écran autorisé (`AuthorizationCenter.requestAuthorization(for:
//   .individual)`) : l'écran dit où en est l'autorisation, et ne fait pas semblant. Sans l'entitlement Family
//   Controls accordé par Apple (décision D3), iOS refuse, et l'écran le dit ;
// - iOS ne retient que 50 applications par bouclier, et au-delà ne bloque plus rien sans prévenir : l'écran
//   compte et prévient, et propose une catégorie entière, qui n'a pas cette limite ;
// - la liste d'Android (`blocked_apps`, des noms de paquets) ne migre pas : venue d'une sauvegarde importée, elle
//   reste en aide-mémoire au-dessus du bouton.
//
// Tout ce qui touche FamilyControls (le sélecteur, `FamilyActivitySelection`, `Label(jeton)`) vit dans l'app
// (ios/App/ApplicationsChoixVue.swift, ios/App/Services/SystemeFamilyControls.swift) : ce modèle ne voit la
// sélection qu'en octets opaques, et ce qu'elle compte. Les chaînes neuves sont dans ios.xcstrings.

// MARK: Les services de l'écran

/// Où en est l'autorisation de Temps d'écran (`AuthorizationCenter.authorizationStatus`).
public enum AppsAutorisationEtat: Sendable, Hashable {
    /// `.notDetermined` : la question n'a pas encore été posée.
    case nonDemandee
    /// `.denied`.
    case refusee
    /// `.approved`.
    case accordee
}

/// Ce qu'a rendu une demande d'autorisation (`requestAuthorization(for: .individual)` et ses erreurs,
/// `FamilyControlsError`).
public enum AppsDemandeIssue: Sendable, Hashable {
    case accordee
    /// L'utilisateur a refusé ou fermé la feuille du système (`.authorizationCanceled`).
    case annulee
    /// Temps d'écran est restreint sur cet iPhone : contrôle parental, gestion de l'appareil (`.restricted`).
    case restreinte
    /// iOS refuse pour une autre raison : l'entitlement Family Controls n'est pas accordé à l'app, Temps d'écran
    /// indisponible, pas de code, pas de réseau…
    case echec
}

/// L'autorisation de Temps d'écran (`AuthorizationCenter` dans l'app).
public protocol AppsAutorisation: Sendable {
    /// L'état, sans rien demander.
    func etat() async -> AppsAutorisationEtat
    /// Pose la question (Face ID ou code) et rend ce qu'il en est sorti.
    func demander() async -> AppsDemandeIssue
}

/// Une autorisation fixée d'avance : la demande rend `issue`, et l'état devient `etatApres`.
public actor AppsFausseAutorisation: AppsAutorisation {
    private var etatActuel: AppsAutorisationEtat
    private let issue: AppsDemandeIssue
    private let etatApres: AppsAutorisationEtat
    public private(set) var demandes = 0

    public init(etat: AppsAutorisationEtat, issue: AppsDemandeIssue = .accordee,
                etatApres: AppsAutorisationEtat? = nil) {
        etatActuel = etat
        self.issue = issue
        self.etatApres = etatApres ?? (issue == .accordee ? .accordee : etat)
    }

    /// L'état change hors de l'app (les Réglages d'iOS).
    public func regler(_ etat: AppsAutorisationEtat) {
        etatActuel = etat
    }

    public func etat() -> AppsAutorisationEtat {
        etatActuel
    }

    public func demander() -> AppsDemandeIssue {
        demandes += 1
        etatActuel = etatApres
        return issue
    }
}

/// Ce que retient une sélection : des jetons d'applications, de catégories entières et de sites web.
public struct ApplicationsCompte: Sendable, Hashable {
    public let applications: Int
    public let categories: Int
    public let sites: Int

    public init(applications: Int = 0, categories: Int = 0, sites: Int = 0) {
        self.applications = max(applications, 0)
        self.categories = max(categories, 0)
        self.sites = max(sites, 0)
    }

    public static let vide = ApplicationsCompte()

    /// Le nombre de jetons (`Etat.nombreDeJetons`) : une application, une catégorie ou un site vaut un.
    public var total: Int {
        applications + categories + sites
    }
}

/// La sélection gardée pour les extensions de la barrière : `barriere/selection.plist` dans le conteneur du
/// groupe d'apps, à côté d'`etat.json` (PORTAGE.md § 3.2). Ses octets sont opaques ici : seul le stock sait les
/// lire (une `FamilyActivitySelection` encodée).
public protocol AppsSelectionStock: Sendable {
    /// Les octets gardés ; nil s'il n'y en a pas, ou s'ils ne se lisent pas sur le disque.
    func lire() async -> Data?
    /// Garde ces octets, ou efface la sélection (nil). Lève si le disque refuse.
    func ecrire(_ donnees: Data?) async throws
    /// Ce que retiennent ces octets ; nil s'ils ne sont pas une sélection.
    func compter(_ donnees: Data) async -> ApplicationsCompte?
}

/// Un stock en mémoire : chaque contenu connu a son compte d'avance (`comptes`), les autres ne se lisent pas.
public actor AppsFausseSelection: AppsSelectionStock {
    public struct Refus: Error, Sendable {}

    public private(set) var donnees: Data?
    /// Chaque écriture, dans l'ordre (nil : un effacement).
    public private(set) var ecritures: [Data?] = []
    private let comptes: [Data: ApplicationsCompte]
    private var refuse: Bool

    public init(donnees: Data? = nil, comptes: [Data: ApplicationsCompte] = [:], refuse: Bool = false) {
        self.donnees = donnees
        self.comptes = comptes
        self.refuse = refuse
    }

    public func refuser(_ oui: Bool) {
        refuse = oui
    }

    public func lire() -> Data? {
        donnees
    }

    public func ecrire(_ donnees: Data?) throws {
        if refuse { throw Refus() }
        ecritures.append(donnees)
        self.donnees = donnees
    }

    public func compter(_ donnees: Data) -> ApplicationsCompte? {
        comptes[donnees]
    }
}

// MARK: Ce que l'écran montre

/// L'accès à Temps d'écran tel que l'écran le montre.
public enum ApplicationsAcces: Sendable, Hashable {
    /// Pas encore lu : rien n'est montré.
    case lecture
    /// La question est posée, la feuille du système est ouverte.
    case enAttente
    /// Jamais demandé (ou la feuille a été fermée sans réponse) : le bouton « Accorder ».
    case aDemander
    case accordee
    /// Refusé : l'expliquer, proposer les Réglages, et de reposer la question.
    case refusee
    /// Temps d'écran restreint sur cet iPhone : rien à proposer.
    case restreinte
    /// iOS a refusé (l'entitlement absent, le plus souvent) : le dire, et proposer de réessayer.
    case echec
}

/// L'avertissement des 50 applications (PORTAGE.md § 2.1.3).
public enum ApplicationsLimite: Sendable, Hashable {
    /// Exactement 50 : c'est le plus qu'iOS bloque.
    case atteinte
    /// Plus de 50 : iOS ne bloque plus rien, sans prévenir.
    case depassee
}

// MARK: Le modèle

/// L'écran du choix des applications (AppPickerActivity) : l'autorisation de Temps d'écran, ce que retient la
/// sélection, l'aide-mémoire d'Android, le sélecteur d'Apple et « Tout retirer ».
///
/// La vue de l'app présente le sélecteur quand `selecteurOuvert` passe à vrai (`choisir()`), et rend ce qu'il a
/// choisi en octets par `retenir(_:)` ; elle remet le sélecteur d'accord avec `donnees`, que ce modèle garde.
@MainActor
@Observable
public final class ApplicationsModele {

    /// « Your app can shield up to 50 application tokens at once » (PORTAGE.md § 2.1.3).
    public static let limiteApplications = 50

    private let magasin: Magasin
    private let autorisation: any AppsAutorisation
    private let stock: any AppsSelectionStock

    /// L'état lu de l'autorisation ; nil avant la première lecture.
    public private(set) var autorisationEtat: AppsAutorisationEtat? = nil
    /// La feuille du système est ouverte.
    public private(set) var demandeEnCours = false
    /// Ce qu'a rendu la dernière demande ; nil si rien n'a été demandé ici.
    public private(set) var derniereIssue: AppsDemandeIssue? = nil

    /// La sélection gardée, en octets opaques ; nil sans sélection (ou si elle ne se lit plus).
    public private(set) var donnees: Data? = nil
    /// Ce qu'elle retient.
    public private(set) var compte = ApplicationsCompte.vide
    /// Des octets sont gardés, mais ils ne sont plus une sélection : à refaire.
    public private(set) var selectionIllisible = false
    /// La sélection a été lue une fois au moins.
    public private(set) var selectionLue = false

    /// Le sélecteur d'Apple est présenté : la vue de l'app le lie à `familyActivityPicker(isPresented:)`.
    public var selecteurOuvert = false
    /// Le message à montrer en alerte (une écriture refusée, des Réglages introuvables) ; la vue le remet à nil.
    public var message: Libelle? = nil

    public init(magasin: Magasin, autorisation: any AppsAutorisation, stock: any AppsSelectionStock) {
        self.magasin = magasin
        self.autorisation = autorisation
        self.stock = stock
    }

    /// Un écran d'aperçu : une autorisation et une sélection données, la liste d'Android en aide-mémoire.
    public static func apercu(etat: AppsAutorisationEtat = .accordee,
                              compte: ApplicationsCompte = ApplicationsCompte(applications: 3, categories: 1),
                              android: Set<String> = []) -> ApplicationsModele {
        var reglages = Reglages()
        reglages.setBlockedApps(android)
        let octets = Data([0x01])
        let stock = compte.total > 0
            ? AppsFausseSelection(donnees: octets, comptes: [octets: compte])
            : AppsFausseSelection()
        return ApplicationsModele(magasin: Magasin.enMemoire(Enregistrement(reglages: reglages)),
                                  autorisation: AppsFausseAutorisation(etat: etat), stock: stock)
    }

    // MARK: Les actions

    /// À l'ouverture : l'autorisation et la sélection gardée.
    public func ouvrir() async {
        await rafraichir()
        await lireSelection()
    }

    /// L'autorisation relue : au retour des Réglages d'iOS (retour au premier plan).
    public func rafraichir() async {
        autorisationEtat = await autorisation.etat()
    }

    /// « Accorder » : la feuille de Temps d'écran, puis l'état relu.
    public func demanderAutorisation() async {
        guard !demandeEnCours else { return }
        demandeEnCours = true
        let issue = await autorisation.demander()
        let etat = await autorisation.etat()
        derniereIssue = issue
        // L'état peut tarder à suivre une autorisation qui vient d'être accordée.
        autorisationEtat = issue == .accordee ? .accordee : etat
        demandeEnCours = false
    }

    /// « Choisir les applications » : le sélecteur, s'il peut servir.
    public func choisir() {
        guard peutChoisir else { return }
        selecteurOuvert = true
    }

    /// Ce que le sélecteur a choisi, en octets ; nil s'ils n'ont pu être écrits. Une sélection vide efface ce qui
    /// était gardé. Rien n'est écrit si rien ne change.
    public func retenir(_ nouvelles: Data?) async {
        guard let nouvelles else {
            message = Libelle("applications_echec_ecriture")
            return
        }
        guard let compteNeuf = await stock.compter(nouvelles) else {
            message = Libelle("applications_echec_ecriture")
            return
        }
        let aGarder: Data? = compteNeuf.total > 0 ? nouvelles : nil
        guard aGarder != donnees || selectionIllisible else { return }
        await garder(aGarder, compte: aGarder == nil ? .vide : compteNeuf)
    }

    /// « Tout retirer » (apps_clear) : la sélection effacée.
    public func toutRetirer() async {
        guard peutToutRetirer else { return }
        await garder(nil, compte: .vide)
    }

    /// Les Réglages d'iOS n'ont pas pu s'ouvrir.
    public func reglagesImpossibles() {
        message = Libelle("settings_screen_missing")
    }

    private func lireSelection() async {
        defer { selectionLue = true }
        guard let lues = await stock.lire() else {
            donnees = nil
            compte = .vide
            selectionIllisible = false
            return
        }
        if let compteLu = await stock.compter(lues) {
            donnees = compteLu.total > 0 ? lues : nil
            compte = compteLu.total > 0 ? compteLu : .vide
            selectionIllisible = false
        } else {
            donnees = nil
            compte = .vide
            selectionIllisible = true
        }
    }

    private func garder(_ nouvelles: Data?, compte compteNeuf: ApplicationsCompte) async {
        do {
            try await stock.ecrire(nouvelles)
        } catch {
            message = Libelle("applications_echec_ecriture")
            return
        }
        donnees = nouvelles
        compte = compteNeuf
        selectionIllisible = false
    }

    // MARK: Les textes

    /// « Applications à bloquer » : le titre de l'écran (activity_apps.xml).
    public var titre: Libelle {
        Libelle("apps_title")
    }

    /// Ce que propose le sélecteur d'Apple, et ce que l'app n'en voit pas.
    public var indication: Libelle {
        Libelle("applications_indication")
    }

    // MARK: L'autorisation

    /// Le titre de la carte de l'autorisation : « Temps d'écran ».
    public var titreAutorisation: Libelle {
        Libelle("reglages_autorisation_temps_ecran")
    }

    public var acces: ApplicationsAcces {
        if demandeEnCours { return .enAttente }
        guard let etat = autorisationEtat else { return .lecture }
        if etat == .accordee { return .accordee }
        switch derniereIssue {
        case .some(.accordee):
            // L'état peut tarder à suivre une autorisation accordée ici, même relu au retour au premier plan (la
            // feuille du système fait passer la scène par « inactive ») : la demande fait foi ; un refus l'emporte.
            if etat == .nonDemandee { return .accordee }
        case .some(.restreinte): return .restreinte
        case .some(.echec): return .echec
        case .some(.annulee), .none: break
        }
        return etat == .refusee ? .refusee : .aDemander
    }

    /// Ce que dit la carte de l'autorisation ; nil avant la première lecture.
    public var texteAcces: Libelle? {
        switch acces {
        case .lecture: nil
        case .enAttente: Libelle("applications_autorisation_attente")
        case .aDemander: Libelle("applications_autorisation_a_demander")
        case .accordee: Libelle("applications_autorisation_accordee")
        case .refusee: Libelle("applications_autorisation_refusee")
        case .restreinte: Libelle("applications_autorisation_restreinte")
        case .echec: Libelle("applications_autorisation_echec")
        }
    }

    /// Le texte de la carte est une mise en garde (couleur `warning`).
    public var accesAvertit: Bool {
        switch acces {
        case .refusee, .restreinte, .echec: true
        case .lecture, .enAttente, .aDemander, .accordee: false
        }
    }

    /// Le bouton qui pose la question à iOS ; nil quand il n'y a rien à demander.
    public var boutonDemande: Libelle? {
        switch acces {
        case .aDemander, .refusee: Libelle("action_grant")
        case .echec: Libelle("applications_reessayer")
        case .lecture, .enAttente, .accordee, .restreinte: nil
        }
    }

    /// Le bouton qui ouvre les Réglages d'iOS : seulement après un refus.
    public var boutonReglages: Libelle? {
        acces == .refusee ? Libelle("applications_ouvrir_reglages") : nil
    }

    // MARK: La sélection

    /// Le titre de la carte de la sélection.
    public var titreSelection: Libelle {
        Libelle("applications_selection_titre")
    }

    /// Le sélecteur ne sert qu'avec l'autorisation, et une fois la sélection lue.
    public var peutChoisir: Bool {
        acces == .accordee && selectionLue
    }

    /// « Choisir les applications ».
    public var boutonChoisir: Libelle {
        Libelle("action_pick_apps")
    }

    /// Le nombre de jetons de la sélection, que l'app dépose dans `etat.json` (`Etat.nombreDeJetons`).
    public var nombreDeJetons: Int {
        compte.total
    }

    /// Ce que retient la sélection, ligne par ligne : « 3 applications bloquées » (apps_selected), les
    /// catégories entières, les sites ; l'avertissement d'Android (apps_none_warning) s'il n'y a rien. Vide avant
    /// la première lecture.
    public var resume: [Libelle] {
        guard selectionLue else { return [] }
        let c = compte
        if c.total == 0 { return [Libelle("apps_none_warning")] }
        var lignes: [Libelle] = []
        if c.applications > 0 {
            lignes.append(Libelle.pluriel("apps_selected", quantite: c.applications, .entier(c.applications)))
        }
        if c.categories > 0 {
            lignes.append(Libelle("applications_categories", .entier(c.categories)))
        }
        if c.sites > 0 {
            lignes.append(Libelle("applications_sites", .entier(c.sites)))
        }
        return lignes
    }

    /// Le résumé est l'avertissement « rien ne sera bloqué » (couleur `warning`, comme les réglages).
    public var resumeAvertit: Bool {
        selectionLue && compte.total == 0
    }

    /// Où en est la sélection face aux 50 applications d'iOS ; nil en deçà.
    public var limite: ApplicationsLimite? {
        let n = compte.applications
        if n > ApplicationsModele.limiteApplications { return .depassee }
        if n == ApplicationsModele.limiteApplications { return .atteinte }
        return nil
    }

    /// L'avertissement des 50 applications, qui propose une catégorie entière ; nil en deçà.
    public var texteLimite: Libelle? {
        switch limite {
        case .some(.atteinte):
            Libelle("applications_limite", .entier(ApplicationsModele.limiteApplications))
        case .some(.depassee):
            Libelle("applications_trop", .entier(compte.applications), .entier(ApplicationsModele.limiteApplications))
        case .none:
            nil
        }
    }

    /// La sélection gardée ne se lit plus : la refaire (gate_reselect_detail).
    public var texteIllisible: Libelle? {
        selectionIllisible ? Libelle("gate_reselect_detail") : nil
    }

    /// La liste des jetons (`Label(jeton)` dans l'app) : seulement ce qui est gardé, et l'autorisation accordée
    /// (sans elle, le système ne dessine pas les jetons).
    public var montrerJetons: Bool {
        acces == .accordee && compte.total > 0
    }

    /// « Tout retirer » : quand quelque chose est gardé.
    public var peutToutRetirer: Bool {
        selectionLue && (compte.total > 0 || selectionIllisible)
    }

    public var boutonToutRetirer: Libelle {
        Libelle("apps_clear")
    }

    // MARK: L'aide-mémoire d'Android

    /// Les applications qu'Android retenait (`blocked_apps` d'une sauvegarde importée), triées ; vide sans
    /// import. Ce sont des noms de paquets : iOS ne peut pas les retrouver, ils sont montrés tels quels.
    public var applicationsAndroid: [String] {
        magasin.reglages.blockedApps.filter { !$0.isEmpty }.sorted()
    }

    /// « Sur Android, vous reteniez : … » (PORTAGE.md § 3.7) ; nil sans liste venue d'Android.
    public var aideMemoire: Libelle? {
        let paquets = applicationsAndroid
        guard !paquets.isEmpty else { return nil }
        return Libelle("applications_android_aide", .texte(paquets.joined(separator: ", ")))
    }
}
