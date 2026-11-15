import Foundation

// La sauvegarde échangée avec Android et le site (Store.exportJson et Store.importJson, Store.kt ;
// web/src/js/store.js pour journal_plus ; PORTAGE.md § 3.4 à 3.6).
//
// L'export écrit ce qu'écrit un téléphone Android : les mêmes clés dans le même ordre, indentées de deux
// espaces comme `JSONObject.toString(2)`, plus la clé `journal_plus` du site, qu'Android ignore. Les
// journées sont écrites dans l'ordre des dates, les jours de pause et les applications bloquées (des
// ensembles) dans l'ordre des unités UTF-16 ; `exported_at` est en UTC, avec ses millisecondes.
//
// L'import porte Store.importJson ligne pour ligne : une fusion, jamais un remplacement, avec les bornes
// et la tolérance d'org.json (ObjetJSON : un nombre écrit en chaîne, un décimal tronqué, un booléen
// écrit « true »). Les adaptations d'iOS (PORTAGE.md § 3.5) : 2 Mo au plus ; `music_track` n'est pris
// que s'il désigne un morceau livré ; une valeur inconnue d'`apparence_*` est ignorée (Android la
// ramène au défaut) ; `blocked_apps`, des paquets d'Android, sont gardés tels quels, sans effet ;
// `journal_plus` (du site) n'est pris, pour une date valable et passée, que si le jour n'a rien ici.
// Le JSON relâché qu'org.json accepte aussi (apostrophes, clés nues, commentaires) est refusé : aucun
// des trois programmes qui écrivent la sauvegarde n'en produit.
//
// Jugé par `Tests/Vecteurs/sauvegarde.json` (tools/vecteurs_ios/VecteursSauvegarde.kt).

/// La sauvegarde : Store.exportJson et Store.importJson.
public enum Sauvegarde {

    /// La valeur de la clé `format`, sans laquelle un fichier est refusé.
    public static let format = "myhitbodedut"
    /// La version écrite ; elle n'est jamais lue, ni par Android ni par le site.
    public static let version = 1
    /// Au-delà, le fichier est refusé (SettingsActivity.IMPORT_MAX_OCTETS) : une sauvegarde réelle pèse
    /// quelques dizaines de Ko.
    public static let importMaxOctets = 2 * 1024 * 1024

    /// L'ordre des clés de `settings` dans l'export d'Android, et ce qui suit sur iOS.
    public static let clesReglages = [
        "window_start", "window_end", "snooze_minutes", "target_minutes", "daily_goal_minutes", "pause_shabbat",
        "in_israel", "reminder_enabled", "reminder_minutes", "reminder_times", "first_name", "hide_countdown",
        "guided_hitbodedut", "music_enabled", "music_volume", "music_shuffle", "music_track", "adresse",
        "apparence_mode", "apparence_fond", "apparence_accent",
    ]

    /// Le nom proposé pour le fichier exporté (SettingsActivity) : « myhitbodedut-2026-11-13.json ».
    public static func nomDeFichier(_ jour: JourCivil) -> String {
        "myhitbodedut-" + jour.iso + ".json"
    }

    // MARK: L'export

    /// `Store.exportJson`, plus `journal_plus`. `maintenant` (millisecondes Unix) donne `exported_at` ;
    /// `fuseauTelephone` donne `in_israel` tant qu'il n'est pas encore figé (Store.inIsrael).
    public static func exporter(journal: Journal, reglages: Reglages, maintenant: Int64,
                                fuseauTelephone: String = "UTC") -> String {
        objet(journal: journal, reglages: reglages, maintenant: maintenant, fuseauTelephone: fuseauTelephone)
            .texte(indentation: 2)
    }

    /// L'objet que l'export écrit, avant sa mise en texte.
    static func objet(journal: Journal, reglages: Reglages, maintenant: Int64, fuseauTelephone: String) -> ObjetJSON {
        var racine = ObjetJSON()
        racine["format"] = .chaine(format)
        racine["version"] = entier(version)
        racine["exported_at"] = .chaine(horodatage(maintenant))
        racine["days"] = .objet(joursDansLOrdre(journal))
        racine["settings"] = .objet(reglagesExportes(journal: journal, reglages: reglages, fuseauTelephone: fuseauTelephone))
        racine["paused_dates"] = .tableau(trie(reglages.pausedDates).map { JSON.chaine($0) })
        racine["blocked_apps"] = .tableau(trie(reglages.blockedApps).map { JSON.chaine($0) })
        // Le journal enrichi : une clé de plus, qu'Android ignore à l'import (store.js).
        racine["journal_plus"] = .objet(journalPlus(journal))
        return racine
    }

    /// `exported_at` : l'instant en UTC, avec ses millisecondes, comme `toISOString()` du site
    /// (« 2026-11-13T08:15:30.123Z »). Les années hors de 0000…9999 portent leur signe, comme java.time.
    public static func horodatage(_ millis: Int64) -> String {
        let civile = Fuseau.utc.dateHeure(millis: millis)
        let heure = chiffres(civile.heure, 2), minute = chiffres(civile.minute, 2)
        let seconde = chiffres(civile.seconde, 2), milli = chiffres(civile.milli, 3)
        return "\(civile.jour.iso)T\(heure):\(minute):\(seconde).\(milli)Z"
    }

    // MARK: L'import

    /// `Store.importJson` : fusionne la sauvegarde `texte` dans `journal` et `reglages`. Rend le nombre de
    /// journées lues dans le fichier, fusions comprises, ou nil si le fichier est invalide (trop gros, pas
    /// du JSON, ou d'un autre format) ; rien n'est alors changé. `aujourdhui` est accepté, demain non.
    /// `morceauxLivres` : les identifiants des morceaux livrés sur iOS. `fuseauTelephone` fige `in_israel`
    /// s'il ne l'est pas encore, comme Store.inIsrael.
    @discardableResult
    public static func importer(texte: String, journal: inout Journal, reglages: inout Reglages, aujourdhui: JourCivil,
                                morceauxLivres: Set<String>, fuseauTelephone: String = "UTC") -> Int? {
        guard texte.utf8.count <= importMaxOctets, let racine = try? ObjetJSON(texte: texte),
              racine.texte("format").egalUnites(format) else { return nil }

        let demain = aujourdhui.plus(jours: 1)
        var importees = 0
        if let jours = racine.objet("days") {
            for (cle, valeur) in jours.paires {
                // Une date mal formée faisait tomber l'écran Journal à chaque ouverture ; une date à venir
                // n'a rien à faire dans un journal.
                guard case .objet(let entree) = valeur, let jour = Journal.dateValide(cle), jour < demain else { continue }
                let entrante = Journee(minutes: borne(entree.entier("minutes", defaut: 0), 0, 24 * 60),
                                       note: entree.texte("note", defaut: "").premieresUnites(Journal.noteMax),
                                       themes: lireThemes(entree),
                                       noteSeule: entree.booleen("note_seule", defaut: false))
                if let existante = journal[jour] {
                    // En conflit : la séance la plus longue, la note non vide ; les sujets se réunissent,
                    // ceux d'ici d'abord : deux sauvegardes du même jour ont pu voir deux séances.
                    journal[jour] = Journee(minutes: max(existante.minutes, entrante.minutes),
                                            note: existante.note.estBlanc ? entrante.note : existante.note,
                                            themes: distincts(existante.themes + entrante.themes),
                                            noteSeule: existante.noteSeule && entrante.noteSeule)
                } else {
                    journal[jour] = entrante
                }
                importees += 1
            }
        }

        // Le journal enrichi du site : un jour déjà noté ici garde ce qu'il a, comme la note.
        if let plus = racine.objet("journal_plus") {
            for cle in plus.cles {
                guard plus.objet(cle) != nil, let jour = Journal.dateValide(cle), jour < demain else { continue }
                if journal.lirePlus(jour).vide {
                    journal.ecrirePlus(JournalPlus.lire(plus, date: cle), pour: jour)
                }
            }
        }

        if let fichier = racine.objet("settings") {
            appliquer(fichier, journal: &journal, reglages: &reglages, morceauxLivres: morceauxLivres,
                      fuseauTelephone: fuseauTelephone)
        }

        if let pauses = racine.tableau("paused_dates") {
            var dates = reglages.pausedDates
            for rang in pauses.indices {
                dates.insert(pauses.texte(rang))
            }
            // Les dates invalides tombent, celles d'ici comprises.
            reglages.setPausedDates(dates.filter { Journal.dateValide($0) != nil })
        }

        if let applis = racine.tableau("blocked_apps") {
            var apps = reglages.blockedApps
            for rang in applis.indices {
                apps.insert(applis.texte(rang))
            }
            reglages.setBlockedApps(apps.filter { !$0.estBlanc })
        }
        return importees
    }

    // MARK: Les réglages

    /// Les réglages du fichier, chaque valeur ramenée dans ce que l'écran permet : un fichier modifié à la
    /// main ne doit pas laisser une durée nulle ou une heure qui n'existe pas. L'ordre des écritures est
    /// celui de Store.importJson.
    private static func appliquer(_ s: ObjetJSON, journal: inout Journal, reglages: inout Reglages,
                                  morceauxLivres: Set<String>, fuseauTelephone: String) {
        let debut = s.entier("window_start", defaut: reglages.windowStart)
        let fin = s.entier("window_end", defaut: reglages.windowEnd)
        reglages.setWindow(startMinutes: dansLaJournee(debut) ? debut : reglages.windowStart,
                           endMinutes: dansLaJournee(fin) ? fin : reglages.windowEnd)
        reglages.setSnoozeMinutes(borne(s.entier("snooze_minutes", defaut: reglages.snoozeMinutes), 1, 240))
        reglages.setTargetMinutes(borne(s.entier("target_minutes", defaut: reglages.targetMinutes),
                                        DureeSeance.min, DureeSeance.max))
        if s.a("daily_goal_minutes") {
            reglages.setDailyGoal(borne(s.entier("daily_goal_minutes", defaut: 0), 0, DureeSeance.max))
        }
        reglages.setShabbatMode(s.booleen("pause_shabbat", defaut: reglages.shabbatMode))
        // Le défaut d'Android est Store.inIsrael, qui fige la valeur du fuseau avant que le fichier ne la pose.
        let israel = reglages.figeInIsrael(fuseauTelephone: fuseauTelephone)
        reglages.setInIsrael(s.booleen("in_israel", defaut: israel))
        reglages.setReminderEnabled(s.booleen("reminder_enabled", defaut: reglages.reminderEnabled))
        // Les heures de rappel : la liste si le fichier l'a, même vide ou sans heure valable ; sinon
        // l'heure unique des anciennes sauvegardes.
        var heures: [Int] = []
        if let liste = s.tableau("reminder_times") {
            for rang in liste.indices {
                let heure = liste.entier(rang, defaut: -1)
                if dansLaJournee(heure) {
                    heures.append(heure)
                }
            }
        } else {
            let heure = s.entier("reminder_minutes", defaut: -1)
            if dansLaJournee(heure) {
                heures.append(heure)
            }
        }
        if !heures.isEmpty {
            reglages.setReminderTimes(heures)
        }
        if s.a("first_name") {
            journal.setFirstName(s.texte("first_name"))
        }
        if s.a("hide_countdown") {
            reglages.setHideCountdown(s.booleen("hide_countdown"))
        }
        if s.a("guided_hitbodedut") {
            reglages.setGuidedHitbodedut(s.booleen("guided_hitbodedut"))
        }
        reglages.setMusicEnabled(s.booleen("music_enabled", defaut: reglages.musicEnabled))
        reglages.setMusicVolume(s.entier("music_volume", defaut: reglages.musicVolume))
        reglages.setMusicShuffle(s.booleen("music_shuffle", defaut: reglages.musicShuffle))
        // Un morceau ajouté sur Android (une URI content://) ou qu'iOS ne livre pas n'est pas repris.
        let piste = s.texte("music_track")
        if !piste.estBlanc && morceauxLivres.contains(piste) {
            reglages.setMusicTrackId(piste)
        }
        let adresse = s.texte("adresse")
        if Reglages.adresses.contains(adresse) {
            reglages.setAdresse(adresse)
        }
        // Une clé absente ou inconnue garde le choix présent.
        let mode = s.texte("apparence_mode")
        if Reglages.modesApparence.contains(mode) {
            reglages.setModeApparence(mode)
        }
        if let fond = Fond(rawValue: s.texte("apparence_fond")) {
            reglages.setFond(fond)
        }
        if let accent = Accent(rawValue: s.texte("apparence_accent")) {
            reglages.setAccent(accent)
        }
    }

    /// Les 21 réglages de l'export d'Android, dans son ordre.
    private static func reglagesExportes(journal: Journal, reglages: Reglages, fuseauTelephone: String) -> ObjetJSON {
        var o = ObjetJSON()
        o["window_start"] = entier(reglages.windowStart)
        o["window_end"] = entier(reglages.windowEnd)
        o["snooze_minutes"] = entier(reglages.snoozeMinutes)
        o["target_minutes"] = entier(reglages.targetMinutes)
        o["daily_goal_minutes"] = entier(reglages.objectifRegle)
        o["pause_shabbat"] = .booleen(reglages.shabbatMode)
        o["in_israel"] = .booleen(reglages.inIsrael(fuseauTelephone: fuseauTelephone))
        o["reminder_enabled"] = .booleen(reglages.reminderEnabled)
        o["reminder_minutes"] = entier(reglages.reminderMinutes)
        // Toutes les heures : l'ancienne clé n'en porte qu'une.
        o["reminder_times"] = .tableau(reglages.reminderTimes.map { JSON.entier(Int64($0)) })
        o["first_name"] = .chaine(journal.firstName)
        o["hide_countdown"] = .booleen(reglages.hideCountdown)
        o["guided_hitbodedut"] = .booleen(reglages.guidedHitbodedut)
        o["music_enabled"] = .booleen(reglages.musicEnabled)
        o["music_volume"] = entier(reglages.musicVolume)
        o["music_shuffle"] = .booleen(reglages.musicShuffle)
        o["music_track"] = .chaine(reglages.musicTrackId ?? "")
        o["adresse"] = .chaine(reglages.adresse ?? "")
        o["apparence_mode"] = .chaine(reglages.modeApparence)
        o["apparence_fond"] = .chaine(reglages.fond.rawValue)
        o["apparence_accent"] = .chaine(reglages.accent.rawValue)
        return o
    }

    // MARK: Les journées

    /// Les journées dans l'ordre des dates, chacune écrite comme Store.toJson.
    private static func joursDansLOrdre(_ journal: Journal) -> ObjetJSON {
        let days = journal.days
        var tries = ObjetJSON()
        for date in journal.dates.sorted() {
            if let valeur = days[date.iso] {
                tries[date.iso] = valeur
            }
        }
        return tries
    }

    /// Le journal enrichi comme le site l'écrit : les jours qui ont quelque chose, lus comme JournalPlus.lire.
    private static func journalPlus(_ journal: Journal) -> ObjetJSON {
        let plus = journal.plus
        var o = ObjetJSON()
        for date in plus.keys.sorted() {
            guard let jour = plus[date], !jour.vide else { continue }
            o[date.iso] = .objet(ObjetJSON([
                ("avant", entier(jour.avant)),
                ("apres", entier(jour.apres)),
                ("gratitude", .chaine(jour.gratitude)),
                ("travail", .chaine(jour.travail)),
            ]))
        }
        return o
    }

    /// `Store.readThemes` : chaque élément lu comme `optString`, les blancs retirés ; rien sans tableau.
    private static func lireThemes(_ entree: ObjetJSON) -> [String] {
        guard let elements = entree.tableau("themes") else { return [] }
        var themes: [String] = []
        for rang in elements.indices {
            let theme = elements.texte(rang)
            if !theme.estBlanc {
                themes.append(theme)
            }
        }
        return themes
    }

    /// `distinct()` de Kotlin : la première occurrence, comparée unité UTF-16 par unité (« é » précomposé
    /// et « e » + accent restent deux sujets, comme sur Android).
    private static func distincts(_ themes: [String]) -> [String] {
        var vus = Set<[UInt16]>()
        var gardes: [String] = []
        for theme in themes {
            if vus.insert(Array(theme.utf16)).inserted {
                gardes.append(theme)
            }
        }
        return gardes
    }

    // MARK: Aides

    private static func dansLaJournee(_ minutes: Int) -> Bool {
        minutes >= 0 && minutes < 24 * 60
    }

    /// `coerceIn`.
    private static func borne(_ valeur: Int, _ bas: Int, _ haut: Int) -> Int {
        min(max(valeur, bas), haut)
    }

    private static func entier(_ n: Int) -> JSON {
        .entier(Int64(n))
    }

    /// Un ensemble dans l'ordre des unités UTF-16, comme `sorted()` de Kotlin.
    private static func trie(_ ensemble: Set<String>) -> [String] {
        ensemble.sorted { $0.utf16.lexicographicallyPrecedes($1.utf16) }
    }

    /// `n` écrit sur `largeur` chiffres au moins, des zéros devant.
    private static func chiffres(_ n: Int, _ largeur: Int) -> String {
        let texte = String(n)
        let manque = largeur - texte.count
        return manque > 0 ? String(repeating: "0", count: manque) + texte : texte
    }
}
