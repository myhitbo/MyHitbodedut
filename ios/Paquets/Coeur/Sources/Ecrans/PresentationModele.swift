import Foundation
import Observation
import Coeur

// La présentation du premier lancement (OnboardingActivity.kt, activity_onboarding.xml) : sept pages, une à la
// fois, et une sortie à tout moment. Les pages et le parcours sont les règles de Coeur (Onboarding.swift) ;
// l'image suit l'adresse (Personnage.pour), comme toute ImageView d'Android (PersonnageViewInflater).
//
// On y choisit l'adresse (le seul endroit avec les réglages), la durée habituelle et le rappel quotidien. Le
// rappel demande l'autorisation des notifications (le Notificateur des Services), puis fait replanifier les
// rappels (`PresentationRappels`, Reminder.reschedule d'Android).
//
// Propre à iOS (PORTAGE.md § 3.8) : sur un téléphone neuf, un écran « Je viens d'Android » précède les pages. Il
// importe la sauvegarde exportée d'Android (ou du site) par l'import des réglages (`PresentationImport`, auquel
// `ReglagesModele` se conforme : une seule fusion, Sauvegarde.importer), dit « N journées importées » et la série
// retrouvée, puis mène aux pages, les réglages repris. Les applications retenues sur Android ne migrent pas
// (§ 3.7) : l'écran le dit.

// MARK: La replanification des rappels

/// Ce qui replanifie les rappels de la journée quand leurs réglages changent : `Reminder.reschedule(context)`
/// d'Android, que la présentation appelle après avoir allumé, éteint ou réglé le rappel. Dans l'app, le
/// planificateur des notifications (ROADMAP, tâche 12) ; dans les tests et les aperçus,
/// `PresentationRappelsEnMemoire`. Il reçoit les réglages tels qu'ils viennent d'être changés.
public protocol PresentationRappels: Sendable {
    func replanifier(_ reglages: Reglages) async
}

/// Des rappels qui retiennent chaque replanification demandée, sans rien programmer.
public actor PresentationRappelsEnMemoire: PresentationRappels {
    /// Les réglages de chaque replanification, dans l'ordre des demandes.
    public private(set) var replanifications: [Reglages] = []

    public init() {}

    public func replanifier(_ reglages: Reglages) {
        replanifications.append(reglages)
    }
}

// MARK: « Je viens d'Android »

/// Ce que l'import d'une sauvegarde a donné (PORTAGE.md § 3.8) : les journées lues et le message « N journées
/// importées » (`import_ok`), ou le refus et sa raison (`import_invalid`, `import_failed`), rien n'ayant changé.
public enum PresentationImportResultat: Sendable, Hashable {
    case importe(journees: Int, message: Libelle)
    case refuse(Libelle)
}

/// Ce qui fusionne la sauvegarde choisie dans le journal et les réglages : l'import des réglages
/// (`ReglagesModele.importer`, Store.importJson d'Android), qui en fait aussi tout ce qui suit (la barrière, les
/// notifications et les widgets réécrits, `ReglagesEffets`). La présentation ne refait pas la fusion : elle la
/// demande par ce protocole, auquel `ReglagesModele` se conforme plus bas.
@MainActor
public protocol PresentationImport: Sendable {
    /// Les octets du fichier choisi, nil s'il n'a pu être lu.
    func importerDepuisAndroid(_ donnees: Data?) async -> PresentationImportResultat
}

/// L'écran « Je viens d'Android » : qui importe, l'horloge qui dit la série retrouvée, et l'édition (sans la
/// barrière, rien à dire des applications retenues sur Android).
public struct PresentationAndroid: Sendable {
    public let importeur: any PresentationImport
    public let horloge: any Horloge
    public let avecBarriere: Bool

    public init(importeur: any PresentationImport, horloge: any Horloge, avecBarriere: Bool) {
        self.importeur = importeur
        self.horloge = horloge
        self.avecBarriere = avecBarriere
    }
}

/// L'import des réglages, tel quel : le même chemin que « Importer » de l'onglet Réglages (la fusion de
/// Sauvegarde.importer, les écritures, les répercussions). Son message est rendu à la présentation, puis effacé
/// des réglages, pour qu'il ne s'y montre pas une seconde fois.
extension ReglagesModele: PresentationImport {
    public func importerDepuisAndroid(_ donnees: Data?) async -> PresentationImportResultat {
        await importer(donnees)
        // `importer` dit toujours quelque chose ; une lecture ratée à défaut.
        let dit = message ?? Libelle("import_failed")
        messageVu()
        if dit.cle == "import_ok", let journees = dit.quantite {
            return .importe(journees: journees, message: dit)
        }
        return .refuse(dit)
    }
}

/// Un import qui rend ce qu'on lui a dit de rendre et retient ce qu'il a reçu : pour les aperçus et les tests.
@MainActor
public final class PresentationFauxImport: PresentationImport {
    public private(set) var recus: [Data?] = []
    private let resultat: PresentationImportResultat

    public init(resultat: PresentationImportResultat) {
        self.resultat = resultat
    }

    public func importerDepuisAndroid(_ donnees: Data?) async -> PresentationImportResultat {
        recus.append(donnees)
        return resultat
    }
}

// MARK: Ce que montrent les pages à choix

/// Un des quatre boutons de durée de la page « La hitbodedout » (onboarding_duree_0 à 3).
public struct PresentationDuree: Sendable, Hashable, Identifiable {
    /// 5, 10, 15 ou 30 (Onboarding.durees).
    public let minutes: Int
    /// « 15 min » (Store.formatDuration).
    public let libelle: Libelle
    /// C'est la durée habituelle réglée : le bouton est coché. Une durée réglée ailleurs (20, 45…) n'en coche
    /// aucun.
    public let choisie: Bool

    public var id: Int { minutes }
}

/// Un des deux boutons צדיק / צדקת de la page « Comment vous appeler ? » (onboarding_tsadik, onboarding_tsadeket).
public struct PresentationAdresse: Sendable, Hashable, Identifiable {
    public let adresse: Adresse
    /// « adresse_tsadik » ou « adresse_tsadeket ».
    public let libelle: Libelle
    /// C'est l'adresse réglée : le bouton est coché. Tant que rien n'est choisi, aucun ne l'est.
    public let choisie: Bool

    public var id: String { adresse.rawValue }
}

// MARK: Le modèle

/// La présentation (OnboardingActivity.kt) : la page montrée, ce qu'elle porte, et ses boutons.
///
/// Elle se montre une fois par version d'elle-même, installation existante comprise (`aMontrer`), et se revoit
/// depuis les réglages (« Revoir la présentation ») : un modèle neuf, à la première page. Quelle que soit la
/// sortie — « Commencer » sur la dernière page, « Passer », ou un geste qui ferme l'écran — elle est vue et ne
/// revient plus (`terminer`, `OnboardingActivity.finish`).
///
/// L'adresse, la durée et le rappel sont les réglages du `Magasin`, lus à chaque fois et écrits par les actions ;
/// la page montrée et l'état des dialogues sont à l'écran.
@MainActor
@Observable
public final class PresentationModele {
    private let magasin: Magasin
    private let notificateur: any Notificateur
    private let rappels: any PresentationRappels
    /// L'écran « Je viens d'Android », s'il est offert.
    private let android: PresentationAndroid?

    /// L'écran « Je viens d'Android » se montre à la place des pages (PORTAGE.md § 3.8) : avant la première
    /// page, sur un téléphone encore sans journée. Importer ou passer mène aux pages.
    public private(set) var montreAndroid: Bool
    /// Le sélecteur de fichiers (`fileImporter`) est ouvert.
    public private(set) var importOuvert = false
    /// La sauvegarde choisie est en train d'être lue et fusionnée.
    public private(set) var importEnCours = false
    /// Ce que le dernier import a donné ; nil avant le premier.
    public private(set) var resultatImport: PresentationImportResultat? = nil

    /// Le rang de la page montrée, de 0 à `Onboarding.dernier`. Il dure autant que l'écran : sur Android, une
    /// rotation ne ramenait pas à la première page (ETAT_INDEX).
    public private(set) var index: Int
    /// La présentation est finie : la vue se retire (`finish()`).
    public private(set) var termine = false
    /// Le choix de l'heure du rappel est ouvert (le TimePickerDialog d'Android).
    public private(set) var choixHeureOuvert = false
    /// La dernière demande d'autorisation des notifications a été refusée. Comme sur Android, le rappel reste
    /// réglé et la présentation n'en dit rien (c'est l'affaire des réglages, SettingsActivity) : la vue peut
    /// l'ignorer.
    public private(set) var notificationsRefusees = false

    /// `index` : la page où reprendre (une restauration d'état), ramenée dans les bornes ; la première sinon.
    /// `android` : de quoi offrir « Je viens d'Android » ; l'écran ne se montre qu'au départ (page 0) d'un
    /// téléphone sans aucune journée, pas à qui revoit la présentation avec un journal déjà rempli.
    public init(magasin: Magasin, notificateur: any Notificateur, rappels: any PresentationRappels, index: Int = 0,
                android: PresentationAndroid? = nil) {
        self.magasin = magasin
        self.notificateur = notificateur
        self.rappels = rappels
        self.android = android
        let rang = min(max(index, 0), Onboarding.dernier)
        self.index = rang
        montreAndroid = android != nil && rang == 0 && magasin.journal.dates.isEmpty
    }

    /// Une présentation sur des réglages donnés d'avance, dans un magasin en mémoire, avec un notificateur qui
    /// accorde tout et des rappels qui ne programment rien : pour les aperçus.
    /// `importAndroid` : ce que rendrait l'import, pour voir l'écran « Je viens d'Android » ; nil, il ne se
    /// montre pas.
    public static func apercu(reglages: Reglages = Reglages(), index: Int = 0,
                              importAndroid: PresentationImportResultat? = nil) -> PresentationModele {
        var android: PresentationAndroid? = nil
        if let importAndroid {
            android = PresentationAndroid(importeur: PresentationFauxImport(resultat: importAndroid),
                                          horloge: HorlogeSysteme(), avecBarriere: true)
        }
        return PresentationModele(magasin: Magasin.enMemoire(Enregistrement(reglages: reglages)),
                                  notificateur: FauxNotificateur(),
                                  rappels: PresentationRappelsEnMemoire(),
                                  index: index,
                                  android: android)
    }

    // MARK: Quand la montrer

    /// La présentation est-elle à montrer à l'ouverture de l'app (MainActivity.showOnboardingOnce) ? Tant que la
    /// version vue (« onboarded_version ») est inférieure à celle de la présentation (`Reglages.versionPresentation`,
    /// Onboarding.version) : une fois par version, installation existante comprise, le booléen de la v1.96
    /// (« onboarded ») ne la cachant plus.
    nonisolated public static func aMontrer(_ reglages: Reglages) -> Bool {
        !reglages.hasOnboarded
    }

    // MARK: « Je viens d'Android »

    /// L'import a fusionné une sauvegarde : l'écran dit ce qui a été retrouvé et mène aux pages.
    public var importReussi: Bool {
        if case .importe? = resultatImport { return true }
        return false
    }

    /// Le titre : la question, puis, la sauvegarde importée, ce qui a été retrouvé.
    public var titreAndroid: Libelle {
        Libelle(importReussi ? "presentation_android_retrouve" : "presentation_android_titre")
    }

    /// Le texte : où trouver l'export sur Android, avec les noms de ses écrans dans la langue de l'app
    /// (Réglages → Mes données → Exporter) ; la sauvegarde importée, ce qui suit.
    public var corpsAndroid: Libelle {
        if importReussi { return Libelle("presentation_android_suite") }
        return Libelle("presentation_android_corps", .libelle(Libelle("settings_title")),
                       .libelle(Libelle("section_data")), .libelle(Libelle("action_export")))
    }

    /// « N journées importées » (import_ok), une fois la sauvegarde importée.
    public var bilanAndroid: Libelle? {
        if case .importe(_, let message)? = resultatImport { return message }
        return nil
    }

    /// La série retrouvée, « 9 jours d'affilée » (status_streak, Store.streak), une fois la sauvegarde importée ;
    /// nil sans série en cours.
    public var serieAndroid: Libelle? {
        guard importReussi, let android else { return nil }
        let serie = Store.streak(journal: magasin.journal, reglages: magasin.reglages,
                                 aujourdhui: android.horloge.aujourdhui,
                                 fuseauTelephone: android.horloge.fuseau.identifiant)
        guard serie > 0 else { return nil }
        return Libelle.pluriel("status_streak", quantite: serie, .entier(serie))
    }

    /// Les applications retenues sur Android ne migrent pas (PORTAGE.md § 3.7) : l'écran le dit, s'il y en
    /// avait et que l'édition a la barrière. L'écran des applications en montre la liste en aide-mémoire.
    public var applicationsAndroid: Libelle? {
        guard importReussi, let android, android.avecBarriere, !magasin.reglages.blockedApps.isEmpty else { return nil }
        return Libelle("presentation_android_applications", .libelle(Libelle("section_gate")))
    }

    /// Le refus du dernier fichier choisi : « Ce fichier n'est pas une sauvegarde MyHitbodedut. », « Le fichier
    /// n'a pas pu être lu. » ; l'écran reste, pour en choisir un autre ou passer.
    public var refusAndroid: Libelle? {
        if case .refuse(let raison)? = resultatImport { return raison }
        return nil
    }

    /// L'image : l'accueil, puis le pouce levé ; au féminin dès que l'adresse est connue (celle de la sauvegarde).
    public var illustrationAndroid: String {
        Personnage.pour(adresse, importReussi ? "char_thumbs_up" : "char_welcome")
    }

    /// Le grand bouton avant l'import : « Importer ma sauvegarde ».
    public var libelleImporterAndroid: Libelle {
        Libelle("presentation_android_importer")
    }

    /// Le bouton qui passe l'import : « Non, je commence ici ».
    public var libelleIgnorerAndroid: Libelle {
        Libelle("presentation_android_ignorer")
    }

    /// Le grand bouton après l'import : « Suivant », vers la première page.
    public var libelleContinuerAndroid: Libelle {
        Libelle("onboarding_next")
    }

    /// Ce que VoiceOver dit pendant l'import.
    public var libelleImportEnCours: Libelle {
        Libelle("presentation_android_en_cours")
    }

    /// « Importer ma sauvegarde » : le sélecteur de fichiers s'ouvre (rien pendant un import).
    public func ouvrirImport() {
        guard montreAndroid, !importEnCours else { return }
        importOuvert = true
    }

    /// Le sélecteur s'est fermé sans fichier : rien ne change.
    public func fermerImport() {
        importOuvert = false
    }

    /// Le fichier choisi (ses octets, nil s'il n'a pu être lu) : il se fusionne par l'import des réglages. Réussi,
    /// l'écran dit les journées et la série retrouvées, et les pages suivent avec les réglages repris ; refusé,
    /// il dit pourquoi, rien n'ayant changé. Un second fichier pendant l'import est ignoré.
    /// Un rappel repris allumé demande l'autorisation des notifications, comme l'interrupteur de la page « jours »
    /// (sans elle, iOS ne montrerait aucun rappel alors que la page le dit allumé), puis les rappels se
    /// replanifient.
    public func importer(_ donnees: Data?) async {
        importOuvert = false
        guard let android, montreAndroid, !importEnCours, !importReussi else { return }
        importEnCours = true
        let resultat = await android.importeur.importerDepuisAndroid(donnees)
        importEnCours = false
        resultatImport = resultat
        guard case .importe = resultat, rappelActif else { return }
        if await notificateur.autorisation() { return }
        let accordee = await notificateur.demanderAutorisation()
        notificationsRefusees = !accordee
        await rappels.replanifier(magasin.reglages)
    }

    /// « Non, je commence ici », ou « Suivant » après l'import : la première page de la présentation.
    public func quitterAndroid() {
        guard montreAndroid, !importEnCours else { return }
        montreAndroid = false
        importOuvert = false
        index = 0
    }

    // MARK: La page montrée

    /// La page montrée (Onboarding.ecran).
    public var ecran: OnboardingEcran {
        Onboarding.ecran(index)
    }

    /// Le nombre de pages : sept.
    public var nombreDePages: Int {
        Onboarding.ecrans.count
    }

    /// La pastille du haut, « 3 / 7 » (onboarding_step).
    public var etape: Libelle {
        Libelle("onboarding_step", .entier(index + 1), .entier(Onboarding.ecrans.count))
    }

    /// Le titre de la page.
    public var titre: Libelle {
        Libelle(ecran.titre)
    }

    /// Le texte de la page.
    public var corps: Libelle {
        Libelle(ecran.corps)
    }

    /// L'adresse réglée ; nil tant que rien n'est choisi.
    public var adresse: Adresse? {
        Adresse.parse(magasin.reglages.adresse)
    }

    /// Le nom de l'image de la page (ios/Ressources/Images), la pose féminine pour qui a choisi צדקת : elle change
    /// dès que l'adresse est choisie, sur la page même.
    public var illustration: String {
        Personnage.pour(adresse, ecran.illustration)
    }

    /// La page porte les deux boutons צדיק / צדקת (la page « adresse »).
    public var montreAdresse: Bool {
        ecran.choixAdresse
    }

    /// La page porte les quatre durées (la page « seance »).
    public var montreDurees: Bool {
        ecran.choixDuree
    }

    /// La page porte le rappel quotidien et son heure (la page « jours »).
    public var montreRappel: Bool {
        ecran.choixRappel
    }

    // MARK: Les choix

    /// Les deux boutons d'adresse, צדיק puis צדקת.
    public var adresses: [PresentationAdresse] {
        let choisie = adresse
        return Adresse.allCases.map { une in
            PresentationAdresse(adresse: une, libelle: Libelle(une.nom), choisie: une == choisie)
        }
    }

    /// Les quatre boutons de durée, dans l'ordre d'Onboarding.durees.
    public var durees: [PresentationDuree] {
        let cible = magasin.reglages.targetMinutes
        return Onboarding.durees.map { minutes in
            PresentationDuree(minutes: minutes, libelle: PresentationModele.libelleDuree(minutes), choisie: minutes == cible)
        }
    }

    /// L'intitulé de l'interrupteur du rappel.
    public var libelleRappel: Libelle {
        Libelle("onboarding_rappel")
    }

    /// Le rappel quotidien est allumé.
    public var rappelActif: Bool {
        magasin.reglages.reminderEnabled
    }

    /// La première heure de rappel, en minutes depuis minuit, de 0 à 1439 : celle que le bouton montre et d'où
    /// part le choix de l'heure ; 7 h sans heure réglée (Store.DEFAULT_REMINDER). Les autres heures se règlent
    /// dans les réglages. Une heure hors du jour, venue d'une ancienne version, se ramène dans le jour comme
    /// Android l'écrit (`(minutes / 60) % 24`, `minutes % 60`) ; une négative, qui l'aurait fait planter, aussi.
    public var heureRappel: Int {
        let premiere = magasin.reglages.reminderTimes.first ?? Reglages.defaultReminder
        return Kotlin.floorMod(premiere, ReminderRule.minutesParJour)
    }

    /// L'heure (0 à 23) de la première heure de rappel.
    public var heureRappelHeure: Int {
        heureRappel / 60
    }

    /// Les minutes (0 à 59) de la première heure de rappel.
    public var heureRappelMinute: Int {
        heureRappel % 60
    }

    /// Le texte du bouton de l'heure, « à 07:00 » (onboarding_rappel_heure) : la vue y glisse l'heure qu'elle a
    /// mise en forme (24 h ou 12 h selon le téléphone, `DateFormat.is24HourFormat`).
    public func libelleHeureRappel(_ heureMiseEnForme: String) -> Libelle {
        Libelle("onboarding_rappel_heure", .texte(heureMiseEnForme))
    }

    /// Ce que VoiceOver dit du bouton de l'heure, « Heure du rappel : 07:00 » (onboarding_rappel_heure_desc).
    public func descriptionHeureRappel(_ heureMiseEnForme: String) -> Libelle {
        Libelle("onboarding_rappel_heure_desc", .texte(heureMiseEnForme))
    }

    // MARK: Les boutons du bas

    /// La page montrée est la dernière, celle de la promesse.
    public var estDerniere: Bool {
        Onboarding.estDernier(index)
    }

    /// « Précédent » se voit, sauf sur la première page, où sa place reste vide (INVISIBLE, pas GONE).
    public var retourVisible: Bool {
        !Onboarding.estPremier(index)
    }

    /// « Passer » se voit, sauf sur la dernière page, où sa place reste vide.
    public var passerVisible: Bool {
        !Onboarding.estDernier(index)
    }

    /// Le grand bouton : « Commencer » sur la dernière page, « Suivant » ailleurs.
    public var libelleSuivant: Libelle {
        Onboarding.estDernier(index) ? Libelle("onboarding_start") : Libelle("onboarding_next")
    }

    public var libelleRetour: Libelle {
        Libelle("onboarding_back")
    }

    public var libellePasser: Libelle {
        Libelle("onboarding_skip")
    }

    // MARK: Le parcours

    /// Le grand bouton : la page suivante, ou, sur la dernière, la fin de la présentation.
    public func suivant() async throws {
        if Onboarding.estDernier(index) {
            try await terminer()
        } else {
            index = Onboarding.suivant(index)
        }
    }

    /// « Précédent » : la page d'avant ; rien sur la première.
    public func precedent() {
        index = Onboarding.precedent(index)
    }

    /// La page amenée par un glissement du doigt (le `TabView` paginé de PORTAGE.md, que la vue lie à `index`),
    /// ramenée dans les bornes. Android n'a que ses boutons : glisser ne termine rien et n'écrit rien.
    public func afficher(page: Int) {
        index = min(max(page, 0), Onboarding.dernier)
    }

    /// « Passer » : la présentation finit d'un geste, depuis n'importe quelle page.
    public func passer() async throws {
        try await terminer()
    }

    /// La fin de la présentation, quelle que soit la sortie (« Commencer », « Passer », la feuille glissée vers le
    /// bas) : elle est vue dans sa version actuelle et ne revient plus (Store.setOnboarded, qui retire aussi le
    /// booléen de la v1.96). La vue se retire aussitôt ; une écriture refusée se rend à l'appelant, le
    /// changement restant en mémoire (Magasin). La revoir depuis les réglages n'écrit rien de plus.
    public func terminer() async throws {
        termine = true
        choixHeureOuvert = false
        try await magasin.modifierReglages { $0.setOnboarded() }
    }

    // MARK: Les choix

    /// צדיק ou צדקת (OnboardingActivity.choisir). Toucher le bouton déjà coché le laisse coché : le choix est
    /// facultatif, mais une fois fait il se change et ne s'efface pas ici.
    public func choisirAdresse(_ adresse: Adresse) async throws {
        try await magasin.modifierReglages { $0.setAdresse(adresse.cle) }
    }

    /// La durée habituelle, parmi les quatre de la page (Onboarding.durees) ; une autre est ignorée. C'est celle
    /// du bouton « Commencer » de l'accueil.
    public func choisirDuree(_ minutes: Int) async throws {
        // La durée déjà cochée : rien à écrire (écrire la valeur par défaut ajouterait sa clé aux réglages).
        guard Onboarding.durees.contains(minutes), minutes != magasin.reglages.targetMinutes else { return }
        try await magasin.modifierReglages { $0.setTargetMinutes(minutes) }
    }

    /// L'interrupteur du rappel. L'allumer demande l'autorisation des notifications si elle n'est pas déjà
    /// accordée ; l'allumer ou l'éteindre fait replanifier les rappels. Un réglage qui ne change rien ne fait
    /// rien (Android ignorait l'interrupteur remis à sa place par l'écran).
    public func basculerRappel(_ actif: Bool) async throws {
        guard actif != rappelActif else { return }
        let echec = await ecrire { $0.setReminderEnabled(actif) }
        if actif {
            await demanderNotifications()
        }
        await rappels.replanifier(magasin.reglages)
        if let echec { throw echec }
    }

    /// Le bouton de l'heure : ouvre son choix, qui part de la première heure de rappel (`heureRappelHeure`,
    /// `heureRappelMinute`).
    public func ouvrirChoixHeure() {
        choixHeureOuvert = true
    }

    /// Le choix de l'heure fermé sans rien choisir : rien ne change.
    public func fermerChoixHeure() {
        choixHeureOuvert = false
    }

    /// L'heure choisie (OnboardingActivity.choisirHeure) : elle remplace la première heure de rappel, les autres
    /// restent (la liste se retrie) ; le rappel s'allume, l'autorisation se demande s'il le faut, et les rappels
    /// se replanifient.
    public func choisirHeureRappel(heure: Int, minute: Int) async throws {
        choixHeureOuvert = false
        let heures = magasin.reglages.reminderTimes
        let nouvelles = [heure * 60 + minute] + Array(heures.dropFirst())
        let echec = await ecrire { reglages in
            reglages.setReminderTimes(nouvelles)
            reglages.setReminderEnabled(true)
        }
        await demanderNotifications()
        await rappels.replanifier(magasin.reglages)
        if let echec { throw echec }
    }

    // MARK: Aides

    /// Change les réglages et les écrit ; rend l'erreur d'une écriture refusée au lieu de la lever, pour que la
    /// suite (l'autorisation, la replanification) suive ce que l'écran montre, le changement restant en mémoire.
    private func ecrire(_ changement: (inout Reglages) -> Void) async -> (any Error)? {
        do {
            try await magasin.modifierReglages(changement)
            return nil
        } catch {
            return error
        }
    }

    /// L'autorisation des notifications : rien si elle est déjà accordée, la question sinon (iOS ne la pose
    /// qu'une fois). OnboardingActivity.demanderNotifications.
    private func demanderNotifications() async {
        if await notificateur.autorisation() {
            notificationsRefusees = false
            return
        }
        let accordee = await notificateur.demanderAutorisation()
        notificationsRefusees = !accordee
    }

    /// Store.formatDuration : « 45 min », « 2 h », « 1 h 05 » (Store.swift est encore en chantier dans Coeur).
    /// La division et le reste tronquent vers zéro, comme en Kotlin.
    nonisolated private static func libelleDuree(_ minutes: Int) -> Libelle {
        if minutes < 60 { return Libelle("duration_minutes", .entier(minutes)) }
        if minutes % 60 == 0 { return Libelle("duration_hours", .entier(minutes / 60)) }
        return Libelle("duration_hours_minutes", .entier(minutes / 60), .entier(minutes % 60))
    }
}
