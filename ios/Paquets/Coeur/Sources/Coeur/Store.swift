import Foundation

// Les règles de Store.kt qui calculent : les journées (validées, annulées, la fenêtre de la barrière
// honorée), la série, la meilleure série et la semaine, les jours sans obligation, la fenêtre et le report,
// la séance en cours, le Tikoun et son jour qui bascule à 4 h, la reprise de lecture, les favoris, les
// marque-pages, le sac du 'hizouk, le bravo en attente, les paliers, les trophées, les anneaux, et
// l'écriture des durées. Les accesseurs simples sont dans Reglages.swift, le journal dans Modele.swift.
//
// Ce qui lit le Context d'Android reçoit ici (journal: Journal, reglages: Reglages), ce qui écrit les reçoit
// inout, et ce qui lit l'heure la reçoit : le jour (`aujourdhui`), l'heure civile (`maintenant`), ou
// l'instant en millisecondes Unix et le fuseau du téléphone. Jamais l'heure qu'il est, jamais le fuseau de
// la machine. Les préférences gardent les noms de clés et les formes d'Android (Reglages.brut).
//
// Israël ou diaspora : Android fige la valeur au premier accès, d'après le fuseau du téléphone ; l'app
// d'iOS le fait à l'ouverture (Reglages.figeInIsrael). Les règles d'ici la lisent sans l'écrire : tant
// qu'elle n'est pas figée, le fuseau donné (`fuseauTelephone`) la décide (Reglages.inIsrael).
//
// Restent à Android : la notification retirée par addSession (un écran), la reprise du journal d'avant.
// Jugé par `Tests/Vecteurs/store.json` (tools/vecteurs_ios/VecteursStore.kt).

/// Une hitbodedout close (`SeanceClose` de Store.kt) : ce qui s'inscrit, et le jour où elle a commencé.
public struct SeanceClose: Sendable, Equatable {
    public let minutes: Int
    public let date: JourCivil

    public init(minutes: Int, date: JourCivil) {
        self.minutes = minutes
        self.date = date
    }
}

/// Ajouter du temps à un jour passé (AjoutTemps.kt, 16/10) : une hitbodedout faite hors du téléphone
/// s'inscrit après coup, sur n'importe quel jour jusqu'à aujourd'hui, même un jour déjà fait (les minutes
/// s'ajoutent, Store.addSession). Jamais un jour à venir. Le dialogue qui le propose est un écran.
public enum AjoutTemps {

    public static func possible(_ date: JourCivil, aujourdhui: JourCivil) -> Bool {
        date <= aujourdhui
    }
}

/// Les règles de Store.kt qui calculent, sur le journal et les réglages.
public enum Store {

    // MARK: Constantes (Store.kt)

    /// Au-delà, une note n'est plus une note (NOTE_MAX).
    public static let noteMax = Journal.noteMax
    public static let defaultStart = Reglages.defaultStart
    public static let defaultEnd = Reglages.defaultEnd
    public static let defaultSnooze = Reglages.defaultSnooze
    /// 15 minutes : ce que le conseil n° 2 recommande pour commencer (revue du 29/09).
    public static let defaultTarget = Reglages.defaultTarget
    public static let defaultReminder = Reglages.defaultReminder
    public static let defaultVolume = Reglages.defaultVolume

    /// Trois heures : un appel, une pause ; pas la prière du lendemain (PRIERE_REPRISE_MS).
    public static let priereRepriseMs: Int64 = 3 * 60 * 60 * 1000

    // MARK: Les clés des préférences

    /// L'instant que la dernière séance couvre, pour la fenêtre de nuit (KEY_FAIT_A).
    private static let cleFaitA = "seance_faite_a"
    private static let cleDebut = "session_started_at"
    private static let cleFin = "session_ends_at"
    private static let cleDuree = "session_target"
    private static let cleTikkunJour = "tikkun_day"
    private static let cleTikkunFaits = "tikkun_done"
    private static let cleTikkunJournal = "tikkun_journal"
    private static let cleFavoris = "favoris"
    private static let cleChizukFavoris = "chizuk_favoris"
    private static let cleMarques = "marques_pages"
    private static let cleDerniereLecture = "derniere_lecture"

    // MARK: Les jours

    /// `today()` : le jour civil de l'instant, dans le fuseau du téléphone.
    public static func today(millis: Int64, fuseau: Fuseau) -> JourCivil {
        fuseau.jour(millis: millis)
    }

    /// `parse` : une date ISO stricte (ISO_LOCAL_DATE) ; nil là où Kotlin lève.
    public static func parse(_ date: String) -> JourCivil? {
        Journal.dateValide(date)
    }

    /// La date si la clé est une vraie date ISO (2026-09-29), sinon nil.
    public static func dateValide(_ cle: String) -> JourCivil? {
        Journal.dateValide(cle)
    }

    /// Le jour civil d'un instant, dans le fuseau du téléphone.
    public static func dateOf(_ millis: Int64, fuseau: Fuseau) -> JourCivil {
        fuseau.jour(millis: millis)
    }

    // MARK: Journées

    /// Les journées qui comptent : faites ou déclarées, pas les notes seules.
    public static func joursFaits(journal: Journal) -> Set<JourCivil> {
        journal.joursFaits
    }

    public static func record(journal: Journal, date: JourCivil) -> Journee? {
        journal.record(date)
    }

    public static func isDone(journal: Journal, date: JourCivil) -> Bool {
        journal.isDone(date)
    }

    /// Valide la journée ; les minutes s'ajoutent si plusieurs séances ont lieu. `date` est le jour où la
    /// hitbodedout a commencé (aujourd'hui sans date) : celle de 23 h 40 qui finit à 0 h 20 compte pour la
    /// veille (revue du 29/09). L'instant que la séance couvre, pour la fenêtre de nuit (fenetreFaite) :
    /// `millis` pour aujourd'hui ; un jour passé, au plus tard sa dernière seconde, pour ne pas couvrir le
    /// soir qui vient. Le report en cours est effacé.
    public static func addSession(journal: inout Journal, reglages: inout Reglages, minutes: Int, note: String? = nil,
                                  theme: Theme? = nil, date: JourCivil? = nil, millis: Int64, fuseau: Fuseau) {
        let aujourdhui = fuseau.jour(millis: millis)
        let jour = date ?? aujourdhui
        journal.addSession(minutes: minutes, note: note, theme: theme?.cle, date: jour)
        var credit = millis
        if jour != aujourdhui {
            credit = min(millis, fuseau.millis(DateHeure(jour, heure: 23, minute: 59, seconde: 59)))
        }
        if credit > long(reglages, cleFaitA, 0) {
            pose(&reglages, cleFaitA, JSON.entier(credit))
        }
        reglages.clearSnooze()
    }

    /// La note d'un jour. Sur un jour sans hitbodedout, elle ne le valide pas.
    public static func setNote(journal: inout Journal, date: JourCivil, note: String) {
        journal.setNote(date: date, note: note)
    }

    /// La journée d'aujourd'hui est retirée, et l'instant de sa séance avec elle.
    public static func unmarkToday(journal: inout Journal, reglages: inout Reglages, aujourdhui: JourCivil) {
        journal.unmarkToday(aujourdhui)
        pose(&reglages, cleFaitA, nil)
    }

    /// La fenêtre de « Je suis avec Hachem » est-elle déjà honorée (02/11) ? Une fenêtre qui passe minuit
    /// (21:00–02:00) appartient au soir où elle commence : à 0 h 30, c'est encore la nuit de la veille, et
    /// la séance de 21 h 30 la couvre. Compte une séance close après la fin de la fenêtre précédente (le
    /// même jour à `end`) : celle de 0 h 30 sert la nuit d'avant, pas le soir qui suit ; celle de 10 h sert
    /// le soir. Sans heure connue (journal d'avant cette version), le jour de la fenêtre fait foi. Fenêtre
    /// dans la journée : le jour civil.
    public static func fenetreFaite(start: Int, end: Int, maintenant: DateHeure, faitA: DateHeure?,
                                    faitLe: (JourCivil) -> Bool) -> Bool {
        if start <= end { return faitLe(maintenant.jour) }
        let minutes = maintenant.heure * 60 + maintenant.minute
        let jour = minutes < end ? maintenant.jour.plus(jours: -1) : maintenant.jour
        guard let faitA else { return faitLe(jour) }
        return faitA >= DateHeure(jour, heure: end / 60, minute: end % 60)
    }

    /// `fenetreFaite(context)` : la fenêtre des réglages, l'instant de la dernière séance, ici et maintenant.
    public static func fenetreFaite(journal: Journal, reglages: Reglages, millis: Int64, fuseau: Fuseau) -> Bool {
        let t = long(reglages, cleFaitA, 0)
        let faitA: DateHeure? = t > 0 ? fuseau.dateHeure(millis: t) : nil
        return fenetreFaite(start: reglages.windowStart, end: reglages.windowEnd, maintenant: fuseau.dateHeure(millis: millis),
                            faitA: faitA) { journal.isDone($0) }
    }

    /// Le total des minutes, sur 32 bits comme `sumOf` de Kotlin.
    public static func totalMinutes(journal: Journal) -> Int {
        journal.totalMinutes
    }

    /// Au moins une journée faite, un jour : il y a une série à perdre.
    public static func aDejaPratique(journal: Journal) -> Bool {
        journal.aDejaPratique
    }

    // MARK: Jours sans obligation

    /// Jour où la pratique n'est pas attendue : une date mise en pause à la main pour un voyage, ou
    /// Chabbat et Yom Tov si l'option est active.
    public static func isExempt(reglages: Reglages, date: JourCivil, fuseauTelephone: String) -> Bool {
        exemption(reglages, fuseauTelephone)(date)
    }

    /// Veille d'un jour chômé, pour taire le rappel du soir.
    public static func isEveOfRestDay(reglages: Reglages, date: JourCivil, fuseauTelephone: String) -> Bool {
        reglages.shabbatMode && Holidays.isEveOfRestDay(date, inIsrael: reglages.inIsrael(fuseauTelephone: fuseauTelephone))
    }

    // MARK: Série

    /// Jours consécutifs validés. Les jours exemptés ne comptent pas et ne cassent pas.
    public static func streak(journal: Journal, reglages: Reglages, aujourdhui: JourCivil, fuseauTelephone: String) -> Int {
        serie(journal.joursFaits, aujourdhui, exemption(reglages, fuseauTelephone))
    }

    /// La plus longue série jamais tenue (Plaque.meilleureSerie), au moins la série en cours.
    public static func meilleureSerie(journal: Journal, reglages: Reglages, aujourdhui: JourCivil,
                                      fuseauTelephone: String) -> Int {
        let exempt = exemption(reglages, fuseauTelephone)
        let faits = journal.joursFaits
        return max(Plaque.meilleureSerie(faits, exempt: exempt), serie(faits, aujourdhui, exempt))
    }

    /// La semaine en cours, du dimanche au samedi : c'est ainsi que se compte la semaine juive, et le
    /// samedi doit tomber en fin de bande, pas au milieu.
    public static func currentWeek(journal: Journal, reglages: Reglages, aujourdhui: JourCivil,
                                   fuseauTelephone: String) -> [CaseSemaine] {
        let faits = journal.joursFaits
        let exempt = exemption(reglages, fuseauTelephone)
        // `jourDeSemaine` vaut 1 le dimanche : on recule d'autant de jours moins un.
        let dimanche = aujourdhui.plus(jours: 1 - aujourdhui.jourDeSemaine)
        var jours: [CaseSemaine] = []
        for decalage in 0..<7 {
            let jour = dimanche.plus(jours: decalage)
            jours.append(CaseSemaine(date: jour, done: faits.contains(jour), exempt: exempt(jour),
                                     shabbat: jour.jourDeSemaine == 7, future: jour > aujourdhui))
        }
        return jours
    }

    // MARK: Fenêtre, report, durée

    /// L'heure est-elle dans la fenêtre de la barrière ? Une fenêtre qui passe minuit (début après la fin)
    /// court du début jusqu'à minuit, puis de minuit à la fin.
    public static func inWindow(reglages: Reglages, maintenant: DateHeure) -> Bool {
        let minutes = maintenant.heure * 60 + maintenant.minute
        let start = reglages.windowStart
        let end = reglages.windowEnd
        if start <= end { return minutes >= start && minutes < end }
        return minutes >= start || minutes < end
    }

    /// Le report court de `millis` à la durée du report plus loin.
    public static func snooze(reglages: inout Reglages, millis: Int64) {
        reglages.snooze(maintenant: millis)
    }

    public static func clearSnooze(reglages: inout Reglages) {
        reglages.clearSnooze()
    }

    public static func isSnoozed(reglages: Reglages, millis: Int64) -> Bool {
        reglages.isSnoozed(maintenant: millis)
    }

    /// L'objectif de l'anneau du jour, en minutes : tant qu'il n'est pas réglé, la durée habituelle.
    public static func dailyGoal(reglages: Reglages) -> Int {
        reglages.dailyGoal
    }

    // MARK: Le lieu des zmanim

    /// La position du téléphone prise dans un autre fuseau que celui du téléphone aujourd'hui (02/11).
    public static func lieuPerime(reglages: Reglages, fuseauTelephone: String) -> Bool {
        reglages.lieuPerime(fuseauTelephone: fuseauTelephone)
    }

    /// Le lieu des alertes programmées (Chabbat, Levana) : celui des zmanim, sauf une position périmée.
    public static func lieuAlertes(reglages: Reglages, fuseauTelephone: String) -> Zmanim.Lieu? {
        reglages.lieuAlertes(fuseauTelephone: fuseauTelephone)
    }

    /// Pourim le 15 Adar : la ville de Jérusalem, ou une position dans Jérusalem.
    public static func mukafChoma(reglages: Reglages) -> Bool {
        reglages.mukafChoma
    }

    /// Le lieu des zmanim est au sud de l'équateur.
    public static func hemisphereSud(reglages: Reglages) -> Bool {
        reglages.hemisphereSud
    }

    // MARK: La reprise de lecture

    /// La place où reprendre un texte (« s:id » du siddour, « l:id » d'un livre). Un livre reprend
    /// toujours ; une prière du siddour seulement juste après une interruption (`priereRepriseMs`) : le
    /// lendemain, elle recommence au début (bug du 02/11). `maintenant` en millisecondes Unix.
    public static func positionLecture(reglages: Reglages, cle: String, maintenant: Int64) -> Int? {
        let position = entier(reglages, "position:" + cle, -1)
        guard position > 0 else { return nil }
        return repriseValable(cle, quand: long(reglages, "position_t:" + cle, 0), maintenant: maintenant) ? position : nil
    }

    /// Retient la place, l'instant où elle est prise, et le texte comme dernière lecture.
    public static func setPositionLecture(reglages: inout Reglages, cle: String, position: Int, maintenant: Int64) {
        pose(&reglages, "position:" + cle, JSON.entier(Int64(position)))
        pose(&reglages, "position_t:" + cle, JSON.entier(maintenant))
        pose(&reglages, cleDerniereLecture, JSON.chaine(cle))
    }

    /// La clé du dernier texte lu ; nil tant qu'aucun ne l'a été.
    public static func derniereLecture(reglages: Reglages) -> String? {
        chaine(reglages, cleDerniereLecture)
    }

    /// Une place enregistrée à `quand` vaut-elle encore pour `cle` ? L'écart se calcule comme une
    /// soustraction de `Long`, qui déborde sans lever.
    public static func repriseValable(_ cle: String, quand: Int64, maintenant: Int64) -> Bool {
        if !cle.commenceParUnites("s:") { return true }
        let ecart = maintenant &- quand
        return quand > 0 && ecart >= 0 && ecart < priereRepriseMs
    }

    // MARK: Favoris et marque-pages

    /// Les textes favoris (« s:id », « l:id »), le plus récent en tête.
    public static func favoris(reglages: Reglages) -> [String] {
        liste(reglages, cleFavoris)
    }

    /// Ajoute en tête, ou retire s'il y est.
    public static func basculerFavori(reglages: inout Reglages, cle: String) {
        bascule(&reglages, cleFavoris, cle)
    }

    /// Les textes de 'hizouk gardés (19/10), le plus récent en tête.
    public static func chizukFavoris(reglages: Reglages) -> [String] {
        liste(reglages, cleChizukFavoris)
    }

    public static func basculerChizukFavori(reglages: inout Reglages, id: String) {
        bascule(&reglages, cleChizukFavoris, id)
    }

    /// Les marque-pages des lectures (MarquesPages).
    public static func marques(reglages: Reglages) -> [MarquesPages.Marque] {
        MarquesPages.decoder(chaine(reglages, cleMarques))
    }

    /// Pose ou retire ; vrai si la marque est maintenant posée.
    @discardableResult
    public static func basculerMarque(reglages: inout Reglages, _ m: MarquesPages.Marque) -> Bool {
        let l = MarquesPages.basculer(marques(reglages: reglages), m)
        pose(&reglages, cleMarques, JSON.chaine(MarquesPages.encoder(l)))
        return l.contains { $0.memePlace(m) }
    }

    // MARK: Paliers, trophées, anneaux

    /// La pratique vue par les paliers : minutes des jours faits, série, mois hébreu en cours.
    public static func bilan(journal: Journal, reglages: Reglages, aujourdhui: JourCivil, fuseauTelephone: String) -> Paliers.Bilan {
        Paliers.Bilan(aujourdhui: aujourdhui, minutes: minutesDesJoursFaits(journal),
                      serie: streak(journal: journal, reglages: reglages, aujourdhui: aujourdhui, fuseauTelephone: fuseauTelephone),
                      debutMoisHebreu: JourAffiche.debutMoisHebreu(aujourdhui), objectifJour: reglages.dailyGoal)
    }

    /// Ce que regardent les trophées : minutes des jours faits, notes écrites (une note seule compte),
    /// meilleure série, jours du Tikoun.
    public static func pratique(journal: Journal, reglages: Reglages, aujourdhui: JourCivil, fuseauTelephone: String) -> Trophees.Pratique {
        var notes = 0
        for journee in journal.jours.values where !journee.note.estBlanc {
            notes += 1
        }
        return Trophees.Pratique(minutes: minutesDesJoursFaits(journal), notes: notes,
                                 meilleureSerie: meilleureSerie(journal: journal, reglages: reglages, aujourdhui: aujourdhui,
                                                                fuseauTelephone: fuseauTelephone),
                                 tikkun: tikkunJournal(reglages: reglages))
    }

    /// Le jour où chaque trophée gagné l'a été (16/10) : l'historique rejoué (Trophees.datesGain), les
    /// jours exemptés ne cassant pas la série.
    public static func datesTrophees(journal: Journal, reglages: Reglages, fuseauTelephone: String) -> [String: JourCivil] {
        var notes = Set<JourCivil>()
        for (date, journee) in journal.jours where !journee.note.estBlanc {
            notes.insert(date)
        }
        return Trophees.datesGain(minutesDesJoursFaits(journal), notes, tikkun: tikkunJournal(reglages: reglages),
                                  exempt: exemption(reglages, fuseauTelephone))
    }

    /// Les trois anneaux de l'accueil, ici et maintenant.
    public static func anneaux(journal: Journal, reglages: Reglages, aujourdhui: JourCivil, fuseauTelephone: String) -> Anneaux.Etat {
        let semaine = currentWeek(journal: journal, reglages: reglages, aujourdhui: aujourdhui, fuseauTelephone: fuseauTelephone)
        return Anneaux.etat(minutesJour: journal.record(aujourdhui)?.minutes ?? 0, objectifJour: reglages.dailyGoal,
                            semaine: JaugeSemaine.progression(semaine),
                            serie: streak(journal: journal, reglages: reglages, aujourdhui: aujourdhui, fuseauTelephone: fuseauTelephone))
    }

    // MARK: La séance en cours

    /// Le début de la séance inscrite, en millisecondes Unix ; 0 sans séance.
    public static func sessionStartedAt(reglages: Reglages) -> Int64 {
        long(reglages, cleDebut, 0)
    }

    /// Sa fin prévue ; 0 pour une séance ouverte ou sans séance.
    public static func sessionEndsAt(reglages: Reglages) -> Int64 {
        long(reglages, cleFin, 0)
    }

    /// Sa durée choisie, en minutes ; 0 (SessionRule.ouverte) pour une séance sans durée.
    public static func sessionTarget(reglages: Reglages) -> Int {
        entier(reglages, cleDuree, 0)
    }

    public static func isSessionRunning(reglages: Reglages, millis: Int64) -> Bool {
        SessionRule.enCours(debutMillis: sessionStartedAt(reglages: reglages), finMillis: sessionEndsAt(reglages: reglages),
                            duree: sessionTarget(reglages: reglages), maintenant: millis)
    }

    /// Une séance sans durée, que seul le geste de l'arrêter termine.
    public static func isSessionOpen(reglages: Reglages) -> Bool {
        SessionRule.estOuverte(debutMillis: sessionStartedAt(reglages: reglages), duree: sessionTarget(reglages: reglages))
    }

    public static func sessionElapsedMinutes(reglages: Reglages, millis: Int64) -> Int {
        SessionRule.minutesEcoulees(debutMillis: sessionStartedAt(reglages: reglages), maintenant: millis)
    }

    /// Commence une séance à `millis` ; une durée nulle (ou négative) l'ouvre : rien n'est inscrit comme fin.
    public static func beginSession(reglages: inout Reglages, minutes: Int, millis: Int64) {
        let ouverte = minutes <= SessionRule.ouverte
        pose(&reglages, cleDebut, JSON.entier(millis))
        pose(&reglages, cleFin, JSON.entier(ouverte ? 0 : millis &+ Int64(minutes) &* 60_000))
        pose(&reglages, cleDuree, JSON.entier(Int64(ouverte ? SessionRule.ouverte : minutes)))
    }

    /// Termine la séance : les minutes à inscrire (SessionRule.minutesAInscrire), et le jour où elle a
    /// commencé, jamais dans l'avenir : une horloge reculée après le début ne doit pas inscrire une journée
    /// à venir. Comme Android, le plus petit des deux jours est pris sur leur écriture ISO.
    @discardableResult
    public static func endSession(reglages: inout Reglages, millis: Int64, fuseau: Fuseau) -> SeanceClose {
        let debut = sessionStartedAt(reglages: reglages)
        let minutes = SessionRule.minutesAInscrire(debutMillis: debut, finMillis: sessionEndsAt(reglages: reglages), maintenant: millis)
        let aujourdhui = fuseau.jour(millis: millis)
        var date = aujourdhui
        if debut > 0 {
            let commencee = fuseau.jour(millis: debut)
            // `minOf` de Kotlin sur deux chaînes : l'ordre des unités UTF-16 (celui des jours de 0000 à 9999).
            if commencee.iso.utf16.lexicographicallyPrecedes(aujourdhui.iso.utf16) {
                date = commencee
            }
        }
        pose(&reglages, cleDebut, nil)
        pose(&reglages, cleFin, nil)
        pose(&reglages, cleDuree, nil)
        return SeanceClose(minutes: minutes, date: date)
    }

    /// Une séance est inscrite comme commencée, que le service tourne ou non.
    public static func hasSessionRecord(reglages: Reglages) -> Bool {
        sessionStartedAt(reglages: reglages) > 0
    }

    /// Ce que le compteur doit dire, ici et maintenant.
    public static func sessionCounter(reglages: Reglages) -> SessionRule.Compteur {
        SessionRule.compteur(ouverte: isSessionOpen(reglages: reglages), masque: reglages.hideCountdown)
    }

    // MARK: Le bravo en attente

    /// Une séance vient de se clore : le bravo attend le prochain écran ouvert ; `dateNote` est le jour de
    /// la note qu'il proposera ensuite (revue du 29/09).
    public static func setPendingCelebration(reglages: inout Reglages, minutes: Int, dateNote: String? = nil) {
        reglages.setPendingCelebration(minutes: minutes, dateNote: dateNote)
    }

    public static func hasPendingCelebration(reglages: Reglages) -> Bool {
        reglages.hasPendingCelebration
    }

    /// Rend le bravo en attente et le retire, ou nil s'il n'y en a pas.
    @discardableResult
    public static func takePendingCelebration(reglages: inout Reglages) -> Reglages.Celebration? {
        reglages.takePendingCelebration()
    }

    // MARK: Tikoun HaKlali

    /// Le jour du Tikoun bascule à 4 h, pas à minuit : commencé à 23 h 45, il se finit après minuit (bug du 02/11).
    public static func jourTikkun(_ maintenant: DateHeure) -> JourCivil {
        maintenant.plus(heures: -4).jour
    }

    /// Les psaumes déjà dits ce jour du Tikoun ; rien un autre jour : c'est une pratique quotidienne, pas
    /// un compteur qui s'accumule. Les numéros se lisent comme `toIntOrNull` de Kotlin, blancs ôtés.
    public static func tikkunDone(reglages: Reglages, maintenant: DateHeure) -> Set<Int> {
        let jour = chaine(reglages, cleTikkunJour) ?? ""
        guard jour.egalUnites(jourTikkun(maintenant).iso) else { return [] }
        var numeros = Set<Int>()
        for morceau in morceaux(chaine(reglages, cleTikkunFaits) ?? "", 0x2C) {
            if let numero = entierKotlin(morceau.rogne) {
                numeros.insert(numero)
            }
        }
        return numeros
    }

    /// Coche ou décoche un psaume. Les dix psaumes dits : le jour entre au journal du Tikoun ; un psaume
    /// décoché l'en retire.
    public static func setTikkunDone(reglages: inout Reglages, numero: Int, done: Bool, maintenant: DateHeure) {
        var courant = tikkunDone(reglages: reglages, maintenant: maintenant)
        if done {
            courant.insert(numero)
        } else {
            courant.remove(numero)
        }
        let jour = jourTikkun(maintenant)
        var journal = tikkunJournal(reglages: reglages)
        if courant.isSuperset(of: Tikkun.ordre) {
            journal.insert(jour)
        } else {
            journal.remove(jour)
        }
        pose(&reglages, cleTikkunJour, JSON.chaine(jour.iso))
        pose(&reglages, cleTikkunFaits, JSON.chaine(courant.sorted().map { String($0) }.joined(separator: ",")))
        pose(&reglages, cleTikkunJournal, JSON.chaine(journal.sorted().map { $0.iso }.joined(separator: ",")))
    }

    /// Les jours (du Tikoun, bascule à 4 h) où les dix psaumes ont été dits ; ce qui n'est pas une date est ignoré.
    public static func tikkunJournal(reglages: Reglages) -> Set<JourCivil> {
        var jours = Set<JourCivil>()
        for morceau in morceaux(chaine(reglages, cleTikkunJournal) ?? "", 0x2C) {
            if let jour = Journal.dateValide(morceau.rogne) {
                jours.insert(jour)
            }
        }
        return jours
    }

    /// Repart du premier psaume ; le journal du Tikoun reste.
    public static func resetTikkun(reglages: inout Reglages, maintenant: DateHeure) {
        pose(&reglages, cleTikkunJour, JSON.chaine(jourTikkun(maintenant).iso))
        pose(&reglages, cleTikkunFaits, JSON.chaine(""))
    }

    // MARK: Rotation des textes de 'hizouk

    /// Le sac mélangé d'un moment : les identifiants qui n'ont pas encore servi dans le cycle en cours,
    /// un par ligne (ChizukBag).
    public static func chizukBag(reglages: Reglages, moment: Moment) -> [String] {
        morceaux(chaine(reglages, "chizuk_bag_" + moment.rawValue) ?? "", 0x0A).filter { !$0.estBlanc }
    }

    /// Le dernier texte sorti pour ce moment, pour ne pas le redonner aussitôt ; nil s'il est blanc.
    public static func chizukLast(reglages: Reglages, moment: Moment) -> String? {
        guard let dernier = chaine(reglages, "chizuk_last_" + moment.rawValue), !dernier.estBlanc else { return nil }
        return dernier
    }

    /// Le sac tel qu'il reste, et le dernier sorti ; nil le retire.
    public static func setChizukBag(reglages: inout Reglages, moment: Moment, bag: [String], last: String?) {
        pose(&reglages, "chizuk_bag_" + moment.rawValue, JSON.chaine(bag.joined(separator: "\n")))
        var dernier: JSON?
        if let last {
            dernier = JSON.chaine(last)
        }
        pose(&reglages, "chizuk_last_" + moment.rawValue, dernier)
    }

    // MARK: Format

    /// « 07:05 » : `"%02d:%02d".format((minutes / 60) % 24, minutes % 60)`, divisions et restes tronqués
    /// vers zéro comme en Kotlin.
    public static func formatMinutes(_ minutes: Int) -> String {
        deuxChiffres((minutes / 60) % 24) + ":" + deuxChiffres(minutes % 60)
    }

    /// « 20 min », « 1 h 30 » : les unités viennent des chaînes, pour suivre la langue de l'interface
    /// (audit des traductions, 28/09). L'écran résout le libellé.
    public static func formatDuration(_ minutes: Int) -> Libelle {
        if minutes < 60 { return Libelle("duration_minutes", .entier(minutes)) }
        if minutes % 60 == 0 { return Libelle("duration_hours", .entier(minutes / 60)) }
        return Libelle("duration_hours_minutes", .entier(minutes / 60), .entier(minutes % 60))
    }

    // MARK: Aides

    /// `isExempt` pour des réglages donnés : les dates en pause, puis Chabbat et Yom Tov si l'option est
    /// active. Les réglages sont lus une fois pour toute la série.
    private static func exemption(_ reglages: Reglages, _ fuseauTelephone: String) -> (JourCivil) -> Bool {
        let pauses = reglages.pausedDates
        let chabbat = reglages.shabbatMode
        let israel = reglages.inIsrael(fuseauTelephone: fuseauTelephone)
        return { date in
            if pauses.contains(date.iso) { return true }
            return chabbat && Holidays.isRestDay(date, inIsrael: israel)
        }
    }

    /// La série qui finit aujourd'hui, ou hier si aujourd'hui n'est ni fait ni exempté ; dix ans au plus,
    /// comme la garde de Kotlin (`guard++ < 3650`).
    private static func serie(_ faits: Set<JourCivil>, _ aujourdhui: JourCivil, _ exempt: (JourCivil) -> Bool) -> Int {
        var jour = aujourdhui
        if !faits.contains(jour) && !exempt(jour) {
            jour = jour.plus(jours: -1)
        }
        var compte = 0
        var garde = 0
        while garde < 3650 {
            garde += 1
            if faits.contains(jour) {
                compte += 1
            } else if !exempt(jour) {
                return compte
            }
            jour = jour.plus(jours: -1)
        }
        return compte
    }

    /// Les minutes de chaque jour fait (une note seule n'en est pas un).
    private static func minutesDesJoursFaits(_ journal: Journal) -> [JourCivil: Int] {
        var minutes: [JourCivil: Int] = [:]
        for (date, journee) in journal.jours where journee.faite {
            minutes[date] = journee.minutes
        }
        return minutes
    }

    /// `split('|').filter { it.isNotBlank() }`.
    private static func liste(_ reglages: Reglages, _ cle: String) -> [String] {
        morceaux(chaine(reglages, cle) ?? "", 0x7C).filter { !$0.estBlanc }
    }

    /// Retire la première occurrence (égalité de Kotlin, unité par unité), ou ajoute en tête.
    private static func bascule(_ reglages: inout Reglages, _ cle: String, _ valeur: String) {
        var l = liste(reglages, cle)
        if let rang = l.firstIndex(where: { $0.egalUnites(valeur) }) {
            l.remove(at: rang)
        } else {
            l.insert(valeur, at: 0)
        }
        pose(&reglages, cle, JSON.chaine(l.joined(separator: "|")))
    }

    /// « %02d » de Java pour un nombre de -59 à 59 : deux chiffres au moins, le signe compris.
    private static func deuxChiffres(_ n: Int) -> String {
        if n < 0 { return "-" + String(-n) }
        return n < 10 ? "0" + String(n) : String(n)
    }

    // MARK: Lecture et écriture d'une préférence (les formes de Reglages)

    /// `getLong`.
    private static func long(_ reglages: Reglages, _ cle: String, _ defaut: Int64) -> Int64 {
        reglages.brut[cle]?.commeLong ?? defaut
    }

    /// `getInt`.
    private static func entier(_ reglages: Reglages, _ cle: String, _ defaut: Int) -> Int {
        guard let valeur = reglages.brut[cle]?.commeEntier else { return defaut }
        return Int(valeur)
    }

    /// `getString(clé, null)` : seule une chaîne se lit.
    private static func chaine(_ reglages: Reglages, _ cle: String) -> String? {
        if case .chaine(let texte)? = reglages.brut[cle] { return texte }
        return nil
    }

    /// `putLong`, `putInt`, `putString` ; nil retire la clé.
    private static func pose(_ reglages: inout Reglages, _ cle: String, _ valeur: JSON?) {
        var brut = reglages.brut
        brut[cle] = valeur
        reglages = Reglages(brut: brut)
    }

    /// `split(c)` de Kotlin sur une unité UTF-16 : les morceaux entre deux séparateurs, vides compris.
    private static func morceaux(_ texte: String, _ separateur: UInt16) -> [String] {
        var resultat: [String] = []
        var courant: [UInt16] = []
        for unite in texte.utf16 {
            if unite == separateur {
                resultat.append(Unites.texte(courant))
                courant = []
            } else {
                courant.append(unite)
            }
        }
        resultat.append(Unites.texte(courant))
        return resultat
    }

    /// `String.toIntOrNull()` de Kotlin : un signe ASCII facultatif puis des chiffres décimaux, ceux de toute
    /// écriture du plan de base (`Character.digit`) ; nil hors des 32 bits d'un `Int` de Kotlin. La règle de
    /// Reglages et de DureeSeance, dont l'aide est privée.
    private static func entierKotlin(_ texte: String) -> Int? {
        let unites = Array(texte.utf16)
        guard let premiere = unites.first else { return nil }
        var negatif = false
        var debut = 0
        if premiere < 0x30 {
            if unites.count == 1 { return nil }
            if premiere == 0x2D {
                negatif = true
            } else if premiere != 0x2B {
                return nil
            }
            debut = 1
        }
        let limite: Int64 = negatif ? 2_147_483_648 : 2_147_483_647
        var valeur: Int64 = 0
        for unite in unites[debut...] {
            guard let chiffre = valeurDuChiffre(unite) else { return nil }
            valeur = valeur * 10 + Int64(chiffre)
            if valeur > limite { return nil }
        }
        return Int(negatif ? -valeur : valeur)
    }

    /// Le zéro de chaque suite de dix chiffres décimaux du plan de base d'Unicode (catégorie Nd).
    private static let zerosDecimaux: [UInt16] = [
        0x0030, 0x0660, 0x06F0, 0x07C0, 0x0966, 0x09E6, 0x0A66, 0x0AE6, 0x0B66, 0x0BE6, 0x0C66, 0x0CE6,
        0x0D66, 0x0DE6, 0x0E50, 0x0ED0, 0x0F20, 0x1040, 0x1090, 0x17E0, 0x1810, 0x1946, 0x19D0, 0x1A80,
        0x1A90, 0x1B50, 0x1BB0, 0x1C40, 0x1C50, 0xA620, 0xA8D0, 0xA900, 0xA9D0, 0xA9F0, 0xAA50, 0xABF0,
        0xFF10,
    ]

    /// `Character.digit(unite, 10)` de Java : la valeur d'un chiffre décimal, ou nil.
    private static func valeurDuChiffre(_ unite: UInt16) -> Int? {
        for zero in zerosDecimaux where unite >= zero && unite - zero < 10 {
            return Int(unite - zero)
        }
        return nil
    }
}
