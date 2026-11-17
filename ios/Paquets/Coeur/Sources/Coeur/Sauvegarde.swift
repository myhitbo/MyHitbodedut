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
    /// La version écrite ; elle n'est jamais lue, ni par Android ni par le site. Version 2 (audit du 12/11,
    /// FDONNEES-01) : le journal enrichi, le journal du Tikoun, les favoris, les 'hizouk gardés, les marque-pages,
    /// le noussa'h et les réglages de lecture.
    public static let version = 2
    /// Au-delà, le fichier est refusé (SettingsActivity.IMPORT_MAX_OCTETS) : une sauvegarde réelle pèse
    /// quelques dizaines de Ko.
    public static let importMaxOctets = 2 * 1024 * 1024

    /// L'ordre des clés de `settings` dans l'export d'Android ; « lecture_langues » suit, quand elle est choisie.
    public static let clesReglages = [
        "window_start", "window_end", "snooze_minutes", "target_minutes", "daily_goal_minutes", "pause_shabbat",
        "in_israel", "in_israel_manuel", "reminder_enabled", "reminder_minutes", "reminder_times", "first_name",
        "hide_countdown", "guided_hitbodedut", "music_enabled", "music_volume", "music_shuffle", "music_track", "adresse",
        "apparence_mode", "apparence_fond", "apparence_accent", "siddur_nusah", "lecture_echelle", "lecture_police",
        "lecture_sombre", "lecture_masquee", "lecture_ecran_allume",
    ]

    /// Au plus autant de jours du Tikoun qu'il y en a en dix ans et plus (revue du 15/11).
    static let importDatesMax = 4000

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
        // Le journal enrichi : humeurs, gratitude, chose à travailler (même forme que le site), tel qu'il est gardé.
        racine["journal_plus"] = .objet(journal.plusBrut)
        racine["tikkun_journal"] = .tableau(Store.tikkunJournal(reglages: reglages).sorted().map { JSON.chaine($0.iso) })
        racine["favoris"] = .tableau(Store.favoris(reglages: reglages).map { JSON.chaine($0) })
        racine["chizuk_favoris"] = .tableau(Store.chizukFavoris(reglages: reglages).map { JSON.chaine($0) })
        racine["marques_pages"] = .tableau(Store.marques(reglages: reglages).map { m in
            JSON.objet(ObjetJSON([("cle", .chaine(m.cle)), ("nusah", .chaine(m.nusah)), ("section", entier(m.section)),
                                  ("bloc", entier(m.bloc)), ("apercu", .chaine(m.apercu))]))
        })
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
    /// journées ajoutées ou modifiées (réimporter le même fichier n'annonce plus tout le journal, FDONNEES-11),
    /// ou nil si le fichier est invalide (trop gros, pas du JSON, ou d'un autre format) ; rien n'est alors
    /// changé. `aujourdhui` est accepté, demain non.
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
                                       themes: Journal.lireThemes(entree),
                                       noteSeule: entree.booleen("note_seule", defaut: false))
                let avant = journal[jour]
                if let existante = avant {
                    // En conflit : la séance la plus longue, la note non vide ; les sujets se réunissent,
                    // ceux d'ici d'abord : deux sauvegardes du même jour ont pu voir deux séances.
                    journal[jour] = Journee(minutes: max(existante.minutes, entrante.minutes),
                                            note: existante.note.estBlanc ? entrante.note : existante.note,
                                            themes: distincts(existante.themes + entrante.themes),
                                            noteSeule: existante.noteSeule && entrante.noteSeule)
                } else {
                    journal[jour] = entrante
                }
                if journal[jour] != avant { importees += 1 }
            }
        }

        importerAjouts(racine, journal: &journal, reglages: &reglages, demain: demain)

        if let fichier = racine.objet("settings") {
            appliquer(fichier, journal: &journal, reglages: &reglages, morceauxLivres: morceauxLivres,
                      aujourdhui: aujourdhui, fuseauTelephone: fuseauTelephone)
        }

        if let pauses = racine.tableau("paused_dates") {
            var dates = reglages.pausedDates
            for rang in pauses.indices {
                dates.insert(pauses.texte(rang))
            }
            // Les dates invalides tombent, celles d'ici comprises ; 4 000 au plus (revue du 15/11 ; l'ordre d'un
            // HashSet d'Android n'est pas celui-ci : seul un fichier fabriqué en a autant).
            reglages.setPausedDates(Set(trie(dates.filter { Journal.dateValide($0) != nil }).prefix(importDatesMax)))
        }

        if let applis = racine.tableau("blocked_apps") {
            var apps = reglages.blockedApps
            for rang in applis.indices {
                apps.insert(applis.texte(rang))
            }
            reglages.setBlockedApps(Set(trie(apps.filter { !$0.estBlanc && $0.utf16.count <= 255 }).prefix(500)))
        }
        return importees
    }

    /// Les chaînes d'un tableau JSON, non vides, sans doublon (`chaines` de Store.kt).
    private static func chaines(_ a: [JSON]?) -> [String] {
        guard let a else { return [] }
        var vus = Set<[UInt16]>(), r: [String] = []
        for rang in a.indices {
            let t = a.texte(rang)
            if !t.estBlanc && vus.insert(Array(t.utf16)).inserted { r.append(t) }
        }
        return r
    }

    /// Ce que la version 2 a ajouté (Store.importerAjouts) : réuni à ce que le téléphone a déjà, sans rien en
    /// retirer. Un jour du journal enrichi déjà noté ici garde ce qu'il a (store.js fait de même). Bornés (revue
    /// du 15/11) : un fichier fabriqué ne remplit plus les préférences, et un « | » ne coupe plus un favori.
    private static func importerAjouts(_ racine: ObjetJSON, journal: inout Journal, reglages: inout Reglages,
                                       demain: JourCivil) {
        if let entrant = racine.objet("journal_plus") {
            var ici = journal.plusBrut
            var change = false
            for date in entrant.cles {
                guard let jour = Journal.dateValide(date), jour < demain, let e = entrant.objet(date) else { continue }
                let plus = JournalPlus.Plus(avant: borne(e.entier("avant", defaut: 0), 0, 5),
                                            apres: borne(e.entier("apres", defaut: 0), 0, 5),
                                            gratitude: e.texte("gratitude", defaut: "").premieresUnites(JournalPlus.gratitudeMax),
                                            travail: e.texte("travail", defaut: "").premieresUnites(JournalPlus.gratitudeMax))
                var dejaNote = false
                if let o = ici.objet(date) {
                    dejaNote = o.entier("avant", defaut: 0) != 0 || o.entier("apres", defaut: 0) != 0
                        || !o.texte("gratitude").estBlanc || !o.texte("travail").estBlanc
                }
                if !plus.vide && !dejaNote {
                    JournalPlus.ecrire(&ici, date: date, plus: plus)
                    change = true
                }
            }
            if change { journal.setPlusBrut(ici) }
        }
        let tikkun = chaines(racine.tableau("tikkun_journal")).compactMap { Journal.dateValide($0) }.filter { $0 < demain }
        if !tikkun.isEmpty {
            let tous = Set(Store.tikkunJournal(reglages: reglages)).union(tikkun).sorted().suffix(importDatesMax)
            Store.pose(&reglages, Store.cleTikkunJournal, JSON.chaine(tous.map { $0.iso }.joined(separator: ",")))
        }
        let favoris = chaines(racine.tableau("favoris")).filter {
            ($0.hasPrefix("s:") || $0.hasPrefix("l:")) && !$0.utf16.contains(0x7C) && $0.utf16.count <= 100
        }
        if !favoris.isEmpty {
            let tous = distincts(Store.favoris(reglages: reglages) + favoris).prefix(200)
            Store.pose(&reglages, Store.cleFavoris, JSON.chaine(tous.joined(separator: "|")))
        }
        let chizuk = chaines(racine.tableau("chizuk_favoris")).filter { !$0.utf16.contains(0x7C) && $0.utf16.count <= 40 }
        if !chizuk.isEmpty {
            let tous = distincts(Store.chizukFavoris(reglages: reglages) + chizuk).prefix(500)
            Store.pose(&reglages, Store.cleChizukFavoris, JSON.chaine(tous.joined(separator: "|")))
        }
        if let a = racine.tableau("marques_pages") {
            var entrantes: [MarquesPages.Marque] = []
            for rang in a.indices {
                guard let o = a.objet(rang) else { continue }
                let apercu = o.texte("apercu").replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ")
                let m = MarquesPages.Marque(cle: o.texte("cle"), nusah: o.texte("nusah"), section: o.entier("section", defaut: -1),
                                            bloc: o.entier("bloc", defaut: -1), apercu: apercu.premieresUnites(200))
                let propre = { (t: String) in !t.utf16.contains(0x09) && !t.utf16.contains(0x0A) }
                if !m.cle.estBlanc && m.cle.utf16.count <= 100 && m.nusah.utf16.count <= 20 && propre(m.cle) && propre(m.nusah)
                    && m.section >= 0 && m.bloc >= 0 {
                    entrantes.append(m)
                }
            }
            let ici = Store.marques(reglages: reglages)
            let reunies = (ici + entrantes.filter { e in !ici.contains { $0.memePlace(e) } }).prefix(MarquesPages.max)
            Store.pose(&reglages, Store.cleMarques, JSON.chaine(MarquesPages.encoder(Array(reunies))))
        }
    }

    // MARK: Les réglages

    /// Les réglages du fichier, chaque valeur ramenée dans ce que l'écran permet : un fichier modifié à la
    /// main ne doit pas laisser une durée nulle ou une heure qui n'existe pas. L'ordre des écritures est
    /// celui de Store.importJson.
    private static func appliquer(_ s: ObjetJSON, journal: inout Journal, reglages: inout Reglages,
                                  morceauxLivres: Set<String>, aujourdhui: JourCivil, fuseauTelephone: String) {
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
        reglages.setShabbatMode(s.booleen("pause_shabbat", defaut: reglages.shabbatMode), aujourdhui: aujourdhui)
        // Le défaut d'Android est Store.inIsrael, qui fige la valeur du fuseau avant que le fichier ne la pose.
        // La région et son drapeau « choisie à la main » voyagent ensemble (FCALENDRIER-06).
        let israel = reglages.figeInIsrael(fuseauTelephone: fuseauTelephone)
        let manuel = s.booleen("in_israel_manuel", defaut: reglages.inIsraelManuel)
        reglages.setInIsrael(s.booleen("in_israel", defaut: israel), manuel: manuel,
                             aujourdhui: aujourdhui, fuseauTelephone: fuseauTelephone)
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
        // Douze heures au plus, comme le web (revue du 15/11) : 1 440 heures donnaient un rappel par minute.
        if !heures.isEmpty {
            var distinctes: [Int] = []
            for h in heures where !distinctes.contains(h) { distinctes.append(h) }
            reglages.setReminderTimes(Array(distinctes.prefix(12)))
        }
        // Un prénom vide dans le fichier (export du site sans prénom) n'efface pas celui du téléphone (FDONNEES-11).
        let prenom = s.texte("first_name")
        if !prenom.estBlanc {
            journal.setFirstName(prenom)
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
        if !piste.estBlanc && piste.utf16.count <= 100 && morceauxLivres.contains(piste) {
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
        // La version 2 : le noussa'h et les réglages de lecture (FDONNEES-01).
        if let nusah = Nusah(rawValue: s.texte("siddur_nusah")) {
            reglages.setSiddurNusah(nusah)
        }
        // « NaN » se lit comme un nombre dans org.json : écarté (revue du 15/11).
        let echelle = s.double("lecture_echelle", defaut: .nan)
        if echelle.isFinite {
            reglages.setLectureEchelle(min(max(Float(echelle), Reglages.echelleMin), Reglages.echelleMax))
        }
        let police = s.texte("lecture_police")
        if Reglages.polices.contains(police) {
            reglages.setLecturePolice(police)
        }
        let langues = s.texte("lecture_langues")
        if LanguesTexte.Mode.allCases.contains(where: { $0.cle == langues }) {
            reglages.setLectureLangues(langues)
        }
        if s.a("lecture_sombre") {
            reglages.setLectureSombre(s.booleen("lecture_sombre"))
        }
        if s.a("lecture_masquee") {
            reglages.setLectureMasquee(s.booleen("lecture_masquee"))
        }
        if s.a("lecture_ecran_allume") {
            reglages.setLectureEcranAllume(s.booleen("lecture_ecran_allume", defaut: true))
        }
    }

    /// Les 28 réglages de l'export d'Android, dans son ordre, et « lecture_langues » quand elle est choisie.
    private static func reglagesExportes(journal: Journal, reglages: Reglages, fuseauTelephone: String) -> ObjetJSON {
        var o = ObjetJSON()
        o["window_start"] = entier(reglages.windowStart)
        o["window_end"] = entier(reglages.windowEnd)
        o["snooze_minutes"] = entier(reglages.snoozeMinutes)
        o["target_minutes"] = entier(reglages.targetMinutes)
        o["daily_goal_minutes"] = entier(reglages.objectifRegle)
        o["pause_shabbat"] = .booleen(reglages.shabbatMode)
        o["in_israel"] = .booleen(reglages.inIsrael(fuseauTelephone: fuseauTelephone))
        o["in_israel_manuel"] = .booleen(reglages.inIsraelManuel)
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
        o["siddur_nusah"] = .chaine(reglages.siddurNusah.rawValue)
        o["lecture_echelle"] = .decimal(Double(reglages.lectureEchelle))
        o["lecture_police"] = .chaine(reglages.lecturePolice)
        o["lecture_sombre"] = .booleen(reglages.lectureSombre)
        o["lecture_masquee"] = .booleen(reglages.lectureMasquee)
        o["lecture_ecran_allume"] = .booleen(reglages.lectureEcranAllume)
        if let langues = reglages.lectureLangues {
            o["lecture_langues"] = .chaine(langues)
        }
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
