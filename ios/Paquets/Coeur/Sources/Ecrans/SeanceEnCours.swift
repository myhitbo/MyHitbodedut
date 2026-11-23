import Foundation
import Observation
import Coeur

// La séance qui tourne (SessionService.kt d'Android), sans service : une séance n'est que trois préférences du
// `Magasin` (`session_started_at`, `session_ends_at`, `session_target`, Store.kt) et `SessionRule` sait clore
// celle dont personne ne s'occupe plus (PORTAGE.md § 2.2.1). `SeanceEnCours` est le modèle partagé de l'app :
// l'écran de séance, l'accueil et le retour au premier plan s'en servent tous, pour qu'une séance ne soit close
// et inscrite qu'une fois.
//
// Ce qu'il fait d'Android :
// - `start` (et `cloreLaPrecedente`) : `commencer(minutes:)` ;
// - `finishNow` (ACTION_FINISH, `finishSession(early = true)`) : `terminer()` ;
// - `cancel` (ACTION_CANCEL) : `abandonner()` ;
// - le tour du service (`refresh`, `finishSession(early = false)`) : `actualiser()`, que l'écran appelle chaque
//   seconde et l'app au retour au premier plan ;
// - `reconcilier` : `reconcilier()`, au lancement et au retour au premier plan.
// `suivie` tient lieu de `SessionService.enMarche` : vrai tant que ce processus s'occupe de la séance.
//
// Ce qui, sur Android, est le service lui-même devient un service d'`Ecrans` : la musique et l'ambiance
// (`SeanceMusique`, que `MusiqueLecteur` remplit), la notification permanente (`ActiviteEnDirect`, la Live
// Activity), le son de fin d'un décompte masqué (`LecteurSon`), la notification « Mazal tov ! »
// (`Notificateur`). Chacun est facultatif : sans lui, la séance s'inscrit pareil.
//
// La « minuterie système » (MinuterieSeance.swift, propre à iOS) : une alarme d'AlarmKit posée au début d'une séance
// minutée, retirée par « Terminer maintenant » et « Abandonner », laissée sonner au terme.
//
// Restent ailleurs : la notification de fin, que pose le planificateur des notifications (PlanNotifications.finDeSeance,
// `PlanificateurNotifications`) quand l'app le fait repasser au début et à la fin d'une séance, le widget de la série
// (StreakWidget.refresh), le magasin `seance` de la barrière (§ 2.1.10).
// « Ne pas déranger » (NePasDeranger.kt) n'a pas d'équivalent : une app ne peut pas activer un mode de
// concentration (§ 2.2.6).

/// La musique et l'ambiance de la séance (le `MusicPlayer` et l'`AmbiancePlayer` du service d'Android).
/// `MusiqueLecteur` a déjà ces trois membres : `extension MusiqueLecteur: SeanceMusique {}` l'y branche.
@MainActor
public protocol SeanceMusique: AnyObject {
    /// Une séance est en cours pour la musique.
    var seanceEnCours: Bool { get }
    /// La séance commence : le morceau retenu (ou le hasard) et l'ambiance.
    func commencerSeance() async
    /// La séance est finie ou abandonnée : la musique s'éteint en fondu, l'ambiance se tait.
    func terminerSeance() async
}

/// Une musique muette, qui compte ce qu'on lui demande : pour les tests et les aperçus.
@MainActor
public final class SeanceFausseMusique: SeanceMusique {
    public private(set) var seanceEnCours = false
    public private(set) var commencees = 0
    public private(set) var terminees = 0

    public init() {}

    public func commencerSeance() async {
        seanceEnCours = true
        commencees += 1
    }

    public func terminerSeance() async {
        seanceEnCours = false
        terminees += 1
    }
}

/// Le sujet de la séance (`Store.sessionTheme`, `setSessionTheme`, clé « session_theme ») : facultatif,
/// l'absence de valeur dit « aucun ». Il se change pendant la séance, et reste pour la suivante.
public enum SeanceSujet {

    /// La clé d'Android.
    public static let cle = "session_theme"

    /// `ThemeRules.parse(getString(clé, null))` : seule une chaîne se lit ; une clé inconnue rend nil.
    public static func lire(_ reglages: Reglages) -> Theme? {
        guard case .chaine(let texte)? = reglages.brut[cle] else { return nil }
        return ThemeRules.parse(texte)
    }

    /// `putString(clé, theme?.cle)` : nil retire la clé. Les autres préférences gardent leur place.
    public static func poser(_ theme: Theme?, dans reglages: inout Reglages) {
        var brut = reglages.brut
        brut[cle] = theme.map { JSON.chaine($0.cle) }
        reglages = Reglages(brut: brut)
    }
}

/// La séance de hitbodedout qui tourne, partagée par toute l'app.
@MainActor
@Observable
public final class SeanceEnCours {

    /// Le son de fin d'un décompte masqué (la sonnerie de notification du téléphone sur Android), joué par le
    /// `LecteurSon` : un fichier des ressources de l'app, à livrer.
    public static let sonDeFin = "fin_seance"
    /// Le son de fin ne sonne que si la fin est constatée à temps : une séance retrouvée une heure après son
    /// terme ne sonne pas une heure trop tard (le verrou d'éveil d'Android évitait ce retard, revue du 29/09).
    public static let retardSonMax: Int64 = 60_000
    /// L'identifiant de la notification « Mazal tov ! » d'après séance (Notifications.ID_CELEBRATION).
    public static let identifiantFete = "celebration"

    let magasin: Magasin
    let horloge: any Horloge
    private let musique: (any SeanceMusique)?
    private let activite: (any ActiviteEnDirect)?
    private let son: (any LecteurSon)?
    private let notificateur: (any Notificateur)?
    private let minuterie: (any MinuterieSysteme)?

    /// Ce processus s'occupe de la séance (`SessionService.enMarche`) : la musique, la Live Activity, le tour
    /// qui la clôt à son terme. Faux au lancement : une séance encore inscrite est alors reprise par
    /// `reconcilier`.
    public private(set) var suivie = false
    /// Monte à chaque séance close et inscrite au journal (pour l'accueil, le widget).
    public private(set) var inscriptions = 0
    /// L'alarme de la minuterie système est posée pour la séance en cours : à son terme, elle sonne seule.
    public private(set) var alarmePosee = false

    public init(magasin: Magasin, horloge: any Horloge, musique: (any SeanceMusique)? = nil,
                activite: (any ActiviteEnDirect)? = nil, son: (any LecteurSon)? = nil,
                notificateur: (any Notificateur)? = nil, minuterie: (any MinuterieSysteme)? = nil) {
        self.magasin = magasin
        self.horloge = horloge
        self.musique = musique
        self.activite = activite
        self.son = son
        self.notificateur = notificateur
        self.minuterie = minuterie
    }

    // MARK: Ce qu'on en sait

    /// Une séance est inscrite comme commencée, qu'elle soit suivie ou non (`hasSessionRecord`).
    public var enregistree: Bool {
        Store.hasSessionRecord(reglages: magasin.reglages)
    }

    /// Elle court, ici et maintenant : une séance ouverte jusqu'à ce qu'on l'arrête, une séance minutée
    /// jusqu'à son terme.
    public var enCours: Bool {
        Store.isSessionRunning(reglages: magasin.reglages, millis: horloge.maintenant)
    }

    /// Son début, en millisecondes Unix ; 0 sans séance.
    public var debut: Int64 {
        Store.sessionStartedAt(reglages: magasin.reglages)
    }

    /// Sa fin prévue, en millisecondes Unix ; 0 pour une séance sans durée ou sans séance.
    public var fin: Int64 {
        Store.sessionEndsAt(reglages: magasin.reglages)
    }

    /// Sa durée choisie, en minutes ; 0 (`SessionRule.ouverte`) pour une séance sans durée.
    public var duree: Int {
        Store.sessionTarget(reglages: magasin.reglages)
    }

    /// Une séance sans durée.
    public var ouverte: Bool {
        Store.isSessionOpen(reglages: magasin.reglages)
    }

    /// Ce que le compteur a le droit de dire : le reste, l'écoulé, ou rien.
    public var compteur: SessionRule.Compteur {
        Store.sessionCounter(reglages: magasin.reglages)
    }

    /// Le sujet choisi, pour cette séance et les suivantes.
    public var sujet: Theme? {
        SeanceSujet.lire(magasin.reglages)
    }

    /// Ce que la notification permanente disait (`runningText`), et ce que la Live Activity dira : le reste,
    /// arrondi à la minute supérieure ; l'écoulé d'une séance sans durée ; rien sous un décompte masqué.
    public var texteEnCours: Libelle {
        let reglages = magasin.reglages
        let maintenant = horloge.maintenant
        switch Store.sessionCounter(reglages: reglages) {
        case .masque:
            return Libelle("session_running_hidden")
        case .ecoule:
            let minutes = Store.sessionElapsedMinutes(reglages: reglages, millis: maintenant)
            return Libelle("session_elapsed", .libelle(Store.formatDuration(minutes)))
        case .reste:
            let minutes = SessionRule.minutesRestantes(finMillis: Store.sessionEndsAt(reglages: reglages),
                                                       maintenant: maintenant)
            return Libelle("session_remaining", .libelle(Store.formatDuration(minutes)))
        }
    }

    /// Le titre de la Live Activity (la notification permanente d'Android).
    public var titreEnCours: Libelle {
        Libelle("session_running_title")
    }

    // MARK: Les gestes

    /// Commence une séance de `minutes` (`SessionService.start`) ; `SessionRule.ouverte` (0) : sans durée.
    /// Une séance encore inscrite est d'abord close (`cloreLaPrecedente`) : échue, elle est inscrite au
    /// journal ; sinon ses minutes le sont si elle en a. La durée habituelle n'est pas touchée ici.
    ///
    /// Les changements se voient tout de suite ; une écriture refusée rend son erreur une fois la séance
    /// lancée (la musique et la Live Activity suivent quand même).
    public func commencer(minutes: Int) async throws {
        let maintenant = horloge.maintenant
        let fuseau = horloge.fuseau
        var reglages = magasin.reglages
        var journal = magasin.journal
        var inscrite = false
        var annonce: Celebrations.Annonce? = nil
        if Store.hasSessionRecord(reglages: reglages) {
            let echue = SessionRule.estEchue(debutMillis: Store.sessionStartedAt(reglages: reglages),
                                             finMillis: Store.sessionEndsAt(reglages: reglages),
                                             duree: Store.sessionTarget(reglages: reglages), maintenant: maintenant)
            let theme = SeanceSujet.lire(reglages)
            let close = Store.endSession(reglages: &reglages, millis: maintenant, fuseau: fuseau)
            if echue || close.minutes > 0 {
                annonce = SeanceEnCours.inscrire(close, theme: theme, journal: &journal, reglages: &reglages,
                                                 maintenant: maintenant, fuseau: fuseau)
                inscrite = true
            }
        }
        Store.beginSession(reglages: &reglages, minutes: minutes, millis: maintenant)
        let erreur = await ecrire(journal: inscrite ? journal : nil, reglages: reglages)
        if inscrite { inscriptions += 1 }
        await armer()
        await demarrer()
        await annoncer(annonce, maintenant: maintenant)
        if let erreur { throw erreur }
    }

    /// « Terminer maintenant » (ACTION_FINISH, `finishSession(early = true)`) : le temps passé est inscrit au
    /// jour du début, s'il fait au moins une minute pleine ; avant, rien n'est inscrit et aucun bravo n'attend.
    public func terminer() async throws {
        try await finir(precoce: true)
    }

    /// « Abandonner » (ACTION_CANCEL) : la séance s'efface, rien n'est inscrit, aucun bravo n'attend.
    public func abandonner() async throws {
        var reglages = magasin.reglages
        Store.endSession(reglages: &reglages, millis: horloge.maintenant, fuseau: horloge.fuseau)
        let erreur = await ecrire(journal: nil, reglages: reglages)
        await desarmer()
        await arreter()
        if let erreur { throw erreur }
    }

    /// Le tour (`refresh`, toutes les secondes sur l'écran, au retour au premier plan dans l'app) : une séance
    /// suivie arrivée à son terme est close et inscrite pour sa durée, jamais plus, au jour de son début ; une
    /// séance qui n'est plus suivie est réconciliée.
    public func actualiser() async throws {
        guard suivie else {
            try await reconcilier()
            return
        }
        if Store.isSessionRunning(reglages: magasin.reglages, millis: horloge.maintenant) { return }
        try await finir(precoce: false)
    }

    /// Reprend une séance restée inscrite sans personne pour la suivre (l'app tuée, le téléphone redémarré ;
    /// `SessionService.reconcilier`). Échue (minutée : son terme est passé ; sans durée : 240 minutes sont
    /// passées), elle est inscrite pour ce que `SessionRule.minutesAInscrire` lui accorde, au jour de son
    /// début, et le bravo attend ; encore en cours, elle est suivie de nouveau (musique, Live Activity).
    public func reconcilier() async throws {
        guard !suivie, Store.hasSessionRecord(reglages: magasin.reglages) else { return }
        let maintenant = horloge.maintenant
        let fuseau = horloge.fuseau
        var reglages = magasin.reglages
        let echue = SessionRule.estEchue(debutMillis: Store.sessionStartedAt(reglages: reglages),
                                         finMillis: Store.sessionEndsAt(reglages: reglages),
                                         duree: Store.sessionTarget(reglages: reglages), maintenant: maintenant)
        guard echue else {
            await demarrer()
            return
        }
        let theme = SeanceSujet.lire(reglages)
        let close = Store.endSession(reglages: &reglages, millis: maintenant, fuseau: fuseau)
        var journal = magasin.journal
        let inscrite = close.minutes > 0
        let annonce: Celebrations.Annonce?
        if inscrite {
            annonce = SeanceEnCours.inscrire(close, theme: theme, journal: &journal, reglages: &reglages,
                                             maintenant: maintenant, fuseau: fuseau)
        } else {
            annonce = nil
        }
        let erreur = await ecrire(journal: inscrite ? journal : nil, reglages: reglages)
        if inscrite { inscriptions += 1 }
        await annoncer(annonce, maintenant: maintenant)
        // Une Live Activity restée de la vie d'avant se retire.
        await arreter()
        if let erreur { throw erreur }
    }

    // MARK: La clôture

    /// `finishSession` : rien d'inscrit, rien à clore ; sinon la séance se clôt, et s'inscrit si elle a des
    /// minutes ou si elle est allée à son terme. Le son de fin ne sonne qu'au terme d'un décompte masqué :
    /// celui qui arrête lui-même n'a pas besoin qu'on le lui apprenne.
    private func finir(precoce: Bool) async throws {
        let maintenant = horloge.maintenant
        let fuseau = horloge.fuseau
        var reglages = magasin.reglages
        guard Store.hasSessionRecord(reglages: reglages) else {
            await arreter()
            return
        }
        let finPrevue = Store.sessionEndsAt(reglages: reglages)
        // Le sujet se lit AVANT la clôture.
        let theme = SeanceSujet.lire(reglages)
        let close = Store.endSession(reglages: &reglages, millis: maintenant, fuseau: fuseau)
        var journal = magasin.journal
        let inscrite = close.minutes > 0 || !precoce
        let annonce: Celebrations.Annonce?
        if inscrite {
            annonce = SeanceEnCours.inscrire(close, theme: theme, journal: &journal, reglages: &reglages,
                                             maintenant: maintenant, fuseau: fuseau)
        } else {
            annonce = nil
        }
        let erreur = await ecrire(journal: inscrite ? journal : nil, reglages: reglages)
        if inscrite { inscriptions += 1 }
        // « Terminer maintenant » retire l'alarme ; au terme, elle sonne, et c'est le seul son.
        let alarme = alarmePosee
        if precoce {
            await desarmer()
        } else {
            alarmePosee = false
        }
        if !precoce && !alarme && reglages.hideCountdown && finPrevue > 0
            && maintenant &- finPrevue <= SeanceEnCours.retardSonMax {
            await sonner()
        }
        await annoncer(annonce, maintenant: maintenant)
        await arreter()
        if let erreur { throw erreur }
    }

    /// `inscrire` : la journée du début de la séance, son sujet, l'instant qu'elle couvre (Store.addSession) ;
    /// les paliers et trophées neufs, retenus comme notifiés (Celebrations.notification) ; puis le bravo en
    /// attente, avec le jour de la note qu'il proposera. Rend la notification « Mazal tov ! » s'il y a du neuf.
    static func inscrire(_ close: SeanceClose, theme: Theme?, journal: inout Journal, reglages: inout Reglages,
                         maintenant: Int64, fuseau: Fuseau) -> Celebrations.Annonce? {
        Store.addSession(journal: &journal, reglages: &reglages, minutes: close.minutes, theme: theme,
                         date: close.date, millis: maintenant, fuseau: fuseau)
        let aujourdhui = fuseau.jour(millis: maintenant)
        let bilan = Store.bilan(journal: journal, reglages: reglages, aujourdhui: aujourdhui,
                                fuseauTelephone: fuseau.identifiant)
        let pratique = Store.pratique(journal: journal, reglages: reglages, aujourdhui: aujourdhui,
                                      fuseauTelephone: fuseau.identifiant)
        let fete = Celebrations.notification(bilan, pratique, paliersNotifies: reglages.paliersNotifies,
                                             tropheesNotifies: reglages.tropheesNotifies)
        reglages.setPaliersNotifies(fete.neuf.marques)
        reglages.setTropheesNotifies(fete.neuf.trophees)
        Store.setPendingCelebration(reglages: &reglages, minutes: close.minutes, dateNote: close.date.iso)
        return fete.annonce
    }

    // MARK: Les services

    /// La séance est suivie : la Live Activity (jusqu'à la fin prévue ; sans durée, jusqu'au plafond de
    /// 240 minutes où elle sera close), puis la musique et l'ambiance.
    private func demarrer() async {
        suivie = true
        let reglages = magasin.reglages
        let debut = Store.sessionStartedAt(reglages: reglages)
        var finMontree = Store.sessionEndsAt(reglages: reglages)
        if finMontree <= 0 {
            finMontree = debut &+ Int64(SessionRule.plafondOuverte) &* 60_000
        }
        if let activite {
            let affichee = SeanceAffichee(debut: debut, fin: finMontree, compteur: Store.sessionCounter(reglages: reglages),
                                          ouverte: Store.isSessionOpen(reglages: reglages))
            do {
                try await activite.commencer(affichee)
            } catch {
                // Sans Live Activity (refusée dans les réglages d'iOS), la séance court pareil.
            }
        }
        await musique?.commencerSeance()
    }

    /// La minuterie système : l'alarme d'une séance précédente est retirée, puis, le réglage allumé, une séance minutée
    /// pose la sienne à son heure de fin. Sans autorisation, rien n'est posé.
    private func armer() async {
        guard let minuterie else { return }
        let reglages = magasin.reglages
        if alarmePosee {
            await minuterie.retirer()
            alarmePosee = false
        }
        let fin = Store.sessionEndsAt(reglages: reglages)
        guard MinuterieReglage.lire(reglages), Store.sessionTarget(reglages: reglages) > 0,
              fin > horloge.maintenant else { return }
        alarmePosee = await minuterie.poser(fin: fin, titre: MinuterieModele.titreAlarme)
    }

    /// L'alarme de la séance est retirée (« Terminer maintenant », « Abandonner »).
    private func desarmer() async {
        guard let minuterie, alarmePosee || MinuterieReglage.lire(magasin.reglages) else { return }
        await minuterie.retirer()
        alarmePosee = false
    }

    /// `stopSelfAndClear` : plus rien ne suit la séance.
    private func arreter() async {
        suivie = false
        await musique?.terminerSeance()
        await activite?.terminer()
    }

    private func sonner() async {
        guard let son else { return }
        do {
            try await son.jouer(fichier: SeanceEnCours.sonDeFin, volume: 100)
        } catch {
            // Un son qui ne joue pas ne retient pas la clôture.
        }
    }

    private func annoncer(_ annonce: Celebrations.Annonce?, maintenant: Int64) async {
        guard let annonce, let notificateur else { return }
        let notification = NotificationPrevue(identifiant: SeanceEnCours.identifiantFete, instant: maintenant,
                                              titre: annonce.titre, corps: annonce.texte)
        do {
            try await notificateur.programmer([notification])
        } catch {
            // La fête se verra à l'accueil (TropheeFete) ; la notification n'est qu'un plus.
        }
    }

    /// Écrit les réglages (la séance close d'abord, pour qu'elle ne puisse pas l'être deux fois), puis le
    /// journal s'il a changé. Les deux changements se voient tout de suite ; rend la première erreur.
    private func ecrire(journal: Journal?, reglages: Reglages) async -> (any Error)? {
        var erreur: (any Error)? = nil
        do {
            try await magasin.modifierReglages { $0 = reglages }
        } catch {
            erreur = error
        }
        if let journal {
            do {
                try await magasin.modifierJournal { $0 = journal }
            } catch {
                if erreur == nil { erreur = error }
            }
        }
        return erreur
    }
}
