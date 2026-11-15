import Foundation

// Le modèle du journal et des réglages, et la sauvegarde JSON échangée avec Android et le site
// (PORTAGE.md § 3.3 à 3.6). L'import est `Store.importJson` d'Android ligne pour ligne, plus trois
// adaptations : `journal_plus` lu comme le site, une valeur d'apparence ou d'adresse inconnue
// ignorée comme le site, un morceau pris seulement s'il est livré sur iOS. L'export écrit les clés
// d'Android dans son ordre, puis `journal_plus` comme le site.
// Jugé par `Tests/Vecteurs/sauvegarde.json` (tools/vecteurs_ios/VecteursSauvegarde.kt).

/// `Store.DayRecord` : une journée du journal.
public struct Journee: Sendable, Equatable {
    /// Le cumul des séances du jour.
    public var minutes: Int
    /// 4 000 unités UTF-16 au plus (`Store.NOTE_MAX`).
    public var note: String
    /// Les clés de `Theme` ; une clé inconnue est conservée.
    public var themes: [String]
    /// Une note laissée un jour sans hitbodedout : elle ne valide pas la journée.
    public var noteSeule: Bool

    public init(minutes: Int, note: String = "", themes: [String] = [], noteSeule: Bool = false) {
        self.minutes = minutes
        self.note = note
        self.themes = themes
        self.noteSeule = noteSeule
    }

    public var faite: Bool { !noteSeule }

    public static let noteMax = 4000

    /// `Store.toJson` : `themes` et `note_seule` absents quand ils sont vides ou faux.
    var objet: ObjetJSON {
        var o = ObjetJSON([("minutes", .entier(Int64(minutes))), ("note", .chaine(note))])
        if !themes.isEmpty { o["themes"] = .tableau(themes.map { .chaine($0) }) }
        if noteSeule { o["note_seule"] = .booleen(true) }
        return o
    }

    /// `Store.days` : la lecture du fichier, sans bornes.
    init(_ o: ObjetJSON) {
        self.init(minutes: o.entier("minutes"), note: o.texte("note"), themes: Journee.themes(o),
                  noteSeule: o.booleen("note_seule"))
    }

    /// `Store.readThemes` : les sujets non blancs.
    static func themes(_ o: ObjetJSON) -> [String] {
        guard let t = o.tableau("themes") else { return [] }
        return t.indices.map { t.texte($0) }.filter { !$0.estBlanc }
    }
}

/// `JournalPlus.Plus` : l'humeur avant et après (0, non dite, à 5), une gratitude, la chose à travailler.
public struct JournalPlus: Sendable, Equatable {
    public var avant: Int
    public var apres: Int
    public var gratitude: String
    public var travail: String

    public static let texteMax = 200

    public init(avant: Int = 0, apres: Int = 0, gratitude: String = "", travail: String = "") {
        self.avant = avant
        self.apres = apres
        self.gratitude = gratitude
        self.travail = travail
    }

    public var vide: Bool { avant == 0 && apres == 0 && gratitude.estBlanc && travail.estBlanc }

    /// `JournalPlus.lire` : bornes et longueurs ramenées.
    init(_ o: ObjetJSON) {
        self.init(avant: min(max(o.entier("avant"), 0), 5), apres: min(max(o.entier("apres"), 0), 5),
                  gratitude: o.texte("gratitude").premieresUnites(JournalPlus.texteMax),
                  travail: o.texte("travail").premieresUnites(JournalPlus.texteMax))
    }

    /// `JournalPlus.ecrire`.
    var objet: ObjetJSON {
        ObjetJSON([("avant", .entier(Int64(avant))), ("apres", .entier(Int64(apres))),
                   ("gratitude", .chaine(gratitude.premieresUnites(JournalPlus.texteMax))),
                   ("travail", .chaine(travail.premieresUnites(JournalPlus.texteMax)))])
    }
}

/// Ce que `journal.json` garde : les journées, le journal enrichi, le prénom (le fichier
/// `myhitbodedut-journal` d'Android, exclu de la sauvegarde automatique).
public struct Journal: Sendable, Equatable {
    public var jours: [JourCivil: Journee]
    public var plus: [JourCivil: JournalPlus]
    /// 40 unités UTF-16 au plus, sans blancs aux bouts.
    public private(set) var prenom: String

    public init(jours: [JourCivil: Journee] = [:], plus: [JourCivil: JournalPlus] = [:], prenom: String = "") {
        self.jours = jours
        self.plus = plus
        self.prenom = ""
        changerPrenom(prenom)
    }

    /// `Store.setFirstName`.
    public mutating func changerPrenom(_ nom: String) {
        prenom = nom.rogne.premieresUnites(40)
    }

    /// `journal.json` : les clés d'Android (`days`, `first_name`) et celle du site (`journal_plus`).
    public var objet: ObjetJSON {
        ObjetJSON([("days", .objet(Journal.jours(jours))), ("journal_plus", .objet(Journal.plus(plus))),
                   ("first_name", .chaine(prenom))])
    }

    /// La relecture de `journal.json` : une date mal formée est ignorée, comme `Store.days`.
    public init(_ o: ObjetJSON) {
        var jours: [JourCivil: Journee] = [:]
        for (cle, valeur) in o.objet("days")?.paires ?? [] {
            guard case .objet(let e) = valeur, let jour = JourCivil(iso: cle) else { continue }
            jours[jour] = Journee(e)
        }
        var plus: [JourCivil: JournalPlus] = [:]
        for (cle, valeur) in o.objet("journal_plus")?.paires ?? [] {
            guard case .objet(let e) = valeur, let jour = JourCivil(iso: cle) else { continue }
            let p = JournalPlus(e)
            if !p.vide { plus[jour] = p }
        }
        self.init(jours: jours, plus: plus, prenom: o.texte("first_name"))
    }

    /// Les journées dans l'ordre des dates.
    static func jours(_ jours: [JourCivil: Journee]) -> ObjetJSON {
        ObjetJSON(jours.keys.sorted().map { ($0.iso, JSON.objet(jours[$0]?.objet ?? ObjetJSON())) })
    }

    static func plus(_ plus: [JourCivil: JournalPlus]) -> ObjetJSON {
        ObjetJSON(plus.keys.sorted().map { ($0.iso, JSON.objet(plus[$0]?.objet ?? ObjetJSON())) })
    }
}

/// `Apparence.Mode` : clair, sombre, ou celui du téléphone.
public enum ModeApparence: String, Sendable, CaseIterable {
    case auto, clair, sombre
}

/// Les réglages que la sauvegarde transporte, sous les noms de clés d'Android, et ceux qu'iOS ne
/// connaît pas encore, gardés tels quels (`autres`). Les défauts sont ceux de `Store.kt`.
public struct Reglages: Sendable, Equatable {
    public var debutFenetre = 6 * 60
    public var finFenetre = 11 * 60
    public var report = 15
    public var duree = 15
    /// 0 : comme la durée habituelle (`Anneaux`).
    public var objectifJour = 0
    public var pauseShabbat = true
    /// Figé au premier accès d'après le fuseau (`Store.inIsrael`) : c'est à l'appelant de le donner.
    public var enIsrael: Bool
    public var rappelActif = false
    /// Minutes depuis minuit, triées, sans doublon (`Store.normaliseHeures`).
    public private(set) var rappels = [7 * 60]
    public var masquerDecompte = false
    public var guidee = false
    public var musique = true
    public private(set) var volume = 60
    public var aleatoire = false
    /// L'identifiant d'un morceau livré, `""` si aucun.
    public var morceau = ""
    /// `m`, `f`, ou `""`.
    public var adresse = ""
    public var mode = ModeApparence.auto
    public var fond = Fond.vert
    public var accent = Accent.vert
    /// Dates ISO valides.
    public var joursPause: Set<String> = []
    /// Les paquets d'Android, recopiés sans effet sur iOS (§ 3.7).
    public var applisBloquees: [String] = []
    /// Les clés de `reglages.json` qu'iOS ne lit pas : gardées d'une écriture à l'autre.
    public var autres = ObjetJSON()

    public init(enIsrael: Bool) {
        self.enIsrael = enIsrael
    }

    /// `Store.setReminderTimes`.
    public mutating func changerRappels(_ heures: [Int]) {
        var vues = Set<Int>()
        rappels = heures.filter { (0..<1440).contains($0) && vues.insert($0).inserted }.sorted()
    }

    /// `Store.reminderMinutes` : la première heure, l'ancienne clé d'Android.
    public var rappelMinutes: Int { rappels.first ?? 7 * 60 }

    /// `Store.setMusicVolume`.
    public mutating func changerVolume(_ v: Int) {
        volume = min(max(v, 0), 100)
    }

    /// Les 21 réglages de l'export, dans l'ordre d'Android (`Store.exportJson`).
    func exportes(prenom: String) -> ObjetJSON {
        ObjetJSON([
            ("window_start", .entier(Int64(debutFenetre))), ("window_end", .entier(Int64(finFenetre))),
            ("snooze_minutes", .entier(Int64(report))), ("target_minutes", .entier(Int64(duree))),
            ("daily_goal_minutes", .entier(Int64(objectifJour))), ("pause_shabbat", .booleen(pauseShabbat)),
            ("in_israel", .booleen(enIsrael)), ("reminder_enabled", .booleen(rappelActif)),
            ("reminder_minutes", .entier(Int64(rappelMinutes))),
            ("reminder_times", .tableau(rappels.map { .entier(Int64($0)) })),
            ("first_name", .chaine(prenom)), ("hide_countdown", .booleen(masquerDecompte)),
            ("guided_hitbodedut", .booleen(guidee)), ("music_enabled", .booleen(musique)),
            ("music_volume", .entier(Int64(volume))), ("music_shuffle", .booleen(aleatoire)),
            ("music_track", .chaine(morceau)), ("adresse", .chaine(adresse)),
            ("apparence_mode", .chaine(mode.rawValue)), ("apparence_fond", .chaine(fond.rawValue)),
            ("apparence_accent", .chaine(accent.rawValue)),
        ])
    }

    /// Les clés que `Reglages` lit dans `reglages.json`.
    private static let connues: Set<String> = [
        "window_start", "window_end", "snooze_minutes", "target_minutes", "daily_goal_minutes", "pause_shabbat",
        "in_israel", "reminder_on", "reminder_times", "reminder_minutes", "hide_countdown", "guided_hitbodedut",
        "music_enabled", "music_volume", "music_shuffle", "music_track", "adresse", "apparence_mode",
        "apparence_fond", "apparence_accent", "paused_dates", "blocked_apps",
    ]

    /// `reglages.json`, sous les noms des préférences d'Android (`reminder_on`, et non `reminder_enabled`).
    public var objet: ObjetJSON {
        var o = ObjetJSON([
            ("window_start", .entier(Int64(debutFenetre))), ("window_end", .entier(Int64(finFenetre))),
            ("snooze_minutes", .entier(Int64(report))), ("target_minutes", .entier(Int64(duree))),
            ("daily_goal_minutes", .entier(Int64(objectifJour))), ("pause_shabbat", .booleen(pauseShabbat)),
            ("in_israel", .booleen(enIsrael)), ("reminder_on", .booleen(rappelActif)),
            ("reminder_minutes", .entier(Int64(rappelMinutes))),
            ("reminder_times", .tableau(rappels.map { .entier(Int64($0)) })),
            ("hide_countdown", .booleen(masquerDecompte)), ("guided_hitbodedut", .booleen(guidee)),
            ("music_enabled", .booleen(musique)), ("music_volume", .entier(Int64(volume))),
            ("music_shuffle", .booleen(aleatoire)), ("music_track", .chaine(morceau)), ("adresse", .chaine(adresse)),
            ("apparence_mode", .chaine(mode.rawValue)), ("apparence_fond", .chaine(fond.rawValue)),
            ("apparence_accent", .chaine(accent.rawValue)),
            ("paused_dates", .tableau(joursPause.sorted().map { .chaine($0) })),
            ("blocked_apps", .tableau(applisBloquees.map { .chaine($0) })),
        ])
        for (cle, valeur) in autres.paires where !Reglages.connues.contains(cle) { o[cle] = valeur }
        return o
    }

    /// La relecture de `reglages.json` ; une clé absente garde le défaut.
    public init(_ o: ObjetJSON, enIsrael defaut: Bool) {
        self.init(enIsrael: o.booleen("in_israel", defaut: defaut))
        debutFenetre = o.entier("window_start", defaut: debutFenetre)
        finFenetre = o.entier("window_end", defaut: finFenetre)
        report = o.entier("snooze_minutes", defaut: report)
        duree = o.entier("target_minutes", defaut: duree)
        objectifJour = o.entier("daily_goal_minutes", defaut: objectifJour)
        pauseShabbat = o.booleen("pause_shabbat", defaut: pauseShabbat)
        rappelActif = o.booleen("reminder_on", defaut: rappelActif)
        if let t = o.tableau("reminder_times") {
            changerRappels(t.indices.map { t.entier($0, defaut: -1) })
        } else if o.a("reminder_minutes") {
            changerRappels([o.entier("reminder_minutes", defaut: rappelMinutes)])
        }
        masquerDecompte = o.booleen("hide_countdown")
        guidee = o.booleen("guided_hitbodedut")
        musique = o.booleen("music_enabled", defaut: musique)
        changerVolume(o.entier("music_volume", defaut: volume))
        aleatoire = o.booleen("music_shuffle")
        morceau = o.texte("music_track")
        adresse = o.texte("adresse")
        mode = ModeApparence(rawValue: o.texte("apparence_mode")) ?? .auto
        fond = Fond.de(o.texte("apparence_fond"))
        accent = Accent.de(o.texte("apparence_accent"))
        let pauses = o.tableau("paused_dates") ?? []
        joursPause = Set(pauses.indices.map { pauses.texte($0) }.filter { JourCivil(iso: $0) != nil })
        let applis = o.tableau("blocked_apps") ?? []
        applisBloquees = applis.indices.map { applis.texte($0) }
        for (cle, valeur) in o.paires where !Reglages.connues.contains(cle) { autres[cle] = valeur }
    }
}

/// Tout ce que la sauvegarde touche : le journal et les réglages.
public struct Donnees: Sendable, Equatable {
    public var journal: Journal
    public var reglages: Reglages

    public init(journal: Journal = Journal(), reglages: Reglages) {
        self.journal = journal
        self.reglages = reglages
    }
}

/// La sauvegarde JSON, version 1.
public enum Sauvegarde {

    /// `SettingsActivity.IMPORT_MAX_OCTETS`.
    public static let tailleMax = 2 * 1024 * 1024

    /// Les morceaux livrés (`MusiquePlay.BUNDLED`) : seul un de ceux-là peut venir d'une sauvegarde.
    public static let morceauxLivres: [String] = [
        "hamelech_basade", "yanuka_nigoun_3", "shpayer_beyond", "shpayer_eshet_hayil", "shpayer_arba_bavot",
        "shpayer_afilou", "shpayer_kenout", "shpayer_esh_kamanche", "shpayer_hithadshout", "shpayer_pnima",
        "shpayer_tunnels_end", "shpayer_ki_hine_kahomer", "ianir_mirage", "ianir_al_harega", "ianir_hello",
        "ianir_baal_shem_tov", "ianir_zemer_bishvahin", "ianir_berditchev", "ianir_kol_bayaar",
        "ianir_yohanan_hasandlar", "ianir_haleluhu", "ianir_houppa", "ianir_eden_el_salvador",
        "ianir_hakol_milfanekha", "ianir_kabbalat_chabbat", "ianir_bessarabie",
    ]

    /// L'import d'un fichier : au-delà de 2 Mo, ou s'il n'est pas de l'UTF-8, il est refusé.
    public static func importer(_ donnees: Data, dans d: inout Donnees, aujourdhui: JourCivil) -> Int? {
        guard donnees.count <= tailleMax, let texte = String(data: donnees, encoding: .utf8) else { return nil }
        return importer(texte, dans: &d, aujourdhui: aujourdhui)
    }

    /// `Store.importJson` : fusionne la sauvegarde ; le nombre de journées lues, ou nil si le fichier est invalide.
    public static func importer(_ texte: String, dans d: inout Donnees, aujourdhui: JourCivil) -> Int? {
        guard let racine = try? ObjetJSON(texte: texte), racine.texte("format") == "myhitbodedut" else { return nil }
        let demain = aujourdhui.plus(jours: 1)
        var lues = 0
        for (cle, valeur) in racine.objet("days")?.paires ?? [] {
            guard case .objet(let e) = valeur, let jour = JourCivil(iso: cle), jour < demain else { continue }
            let entrant = Journee(minutes: min(max(e.entier("minutes"), 0), 24 * 60),
                                  note: e.texte("note").premieresUnites(Journee.noteMax),
                                  themes: Journee.themes(e), noteSeule: e.booleen("note_seule"))
            if let ici = d.journal.jours[jour] {
                var themes = ici.themes
                for t in entrant.themes where !themes.contains(t) { themes.append(t) }
                d.journal.jours[jour] = Journee(minutes: max(ici.minutes, entrant.minutes),
                                                note: ici.note.estBlanc ? entrant.note : ici.note,
                                                themes: themes, noteSeule: ici.noteSeule && entrant.noteSeule)
            } else {
                d.journal.jours[jour] = entrant
            }
            lues += 1
        }
        // Le journal enrichi, comme le site (store.js) : un jour déjà renseigné ici garde ce qu'il a.
        for (cle, valeur) in racine.objet("journal_plus")?.paires ?? [] {
            guard case .objet(let e) = valeur, let jour = JourCivil(iso: cle), jour < demain else { continue }
            if d.journal.plus[jour]?.vide ?? true {
                let p = JournalPlus(e)
                d.journal.plus[jour] = p.vide ? nil : p
            }
        }
        if let s = racine.objet("settings") {
            reglages(s, &d)
        }
        if let t = racine.tableau("paused_dates") {
            var dates = d.reglages.joursPause
            for i in t.indices { dates.insert(t.texte(i)) }
            d.reglages.joursPause = dates.filter { JourCivil(iso: $0) != nil }
        }
        if let t = racine.tableau("blocked_apps") {
            var applis = d.reglages.applisBloquees
            for i in t.indices where !applis.contains(t.texte(i)) { applis.append(t.texte(i)) }
            d.reglages.applisBloquees = applis.filter { !$0.estBlanc }
        }
        return lues
    }

    /// Chaque valeur ramenée dans ce que l'écran permet, comme Android.
    private static func reglages(_ s: ObjetJSON, _ d: inout Donnees) {
        var r = d.reglages
        let jour = 0..<(24 * 60)
        let debut = s.entier("window_start", defaut: r.debutFenetre)
        let fin = s.entier("window_end", defaut: r.finFenetre)
        if jour.contains(debut) { r.debutFenetre = debut }
        if jour.contains(fin) { r.finFenetre = fin }
        r.report = min(max(s.entier("snooze_minutes", defaut: r.report), 1), 240)
        r.duree = min(max(s.entier("target_minutes", defaut: r.duree), 1), 240)
        if s.a("daily_goal_minutes") { r.objectifJour = min(max(s.entier("daily_goal_minutes"), 0), 240) }
        r.pauseShabbat = s.booleen("pause_shabbat", defaut: r.pauseShabbat)
        r.enIsrael = s.booleen("in_israel", defaut: r.enIsrael)
        r.rappelActif = s.booleen("reminder_enabled", defaut: r.rappelActif)
        // La liste si le fichier l'a, sinon l'heure unique des anciennes sauvegardes.
        let heures: [Int]
        if let t = s.tableau("reminder_times") {
            heures = t.indices.map { t.entier($0, defaut: -1) }.filter { jour.contains($0) }
        } else {
            let m = s.entier("reminder_minutes", defaut: -1)
            heures = jour.contains(m) ? [m] : []
        }
        if !heures.isEmpty { r.changerRappels(heures) }
        if s.a("first_name") { d.journal.changerPrenom(s.texte("first_name")) }
        if s.a("hide_countdown") { r.masquerDecompte = s.booleen("hide_countdown") }
        if s.a("guided_hitbodedut") { r.guidee = s.booleen("guided_hitbodedut") }
        r.musique = s.booleen("music_enabled", defaut: r.musique)
        r.changerVolume(s.entier("music_volume", defaut: r.volume))
        r.aleatoire = s.booleen("music_shuffle", defaut: r.aleatoire)
        // Adaptation iOS : une URI d'Android ou un morceau inconnu ne désigne rien ici.
        let morceau = s.texte("music_track")
        if morceauxLivres.contains(morceau) { r.morceau = morceau }
        // Adaptation, règle du site : une valeur inconnue est ignorée (Android retombe sur le défaut).
        let adresse = s.texte("adresse")
        if adresse == "m" || adresse == "f" { r.adresse = adresse }
        if let m = ModeApparence(rawValue: s.texte("apparence_mode")) { r.mode = m }
        if let f = Fond(rawValue: s.texte("apparence_fond")) { r.fond = f }
        if let a = Accent(rawValue: s.texte("apparence_accent")) { r.accent = a }
        d.reglages = r
    }

    /// `Store.exportJson`, plus `journal_plus` : indenté de deux espaces, clés dans l'ordre d'Android.
    public static func exporter(_ d: Donnees, maintenant: Int64) -> String {
        racine(d, maintenant: maintenant).texte(indentation: 2)
    }

    static func racine(_ d: Donnees, maintenant: Int64) -> ObjetJSON {
        ObjetJSON([
            ("format", .chaine("myhitbodedut")), ("version", .entier(1)),
            ("exported_at", .chaine(instant(maintenant))),
            ("days", .objet(Journal.jours(d.journal.jours))),
            ("settings", .objet(d.reglages.exportes(prenom: d.journal.prenom))),
            ("paused_dates", .tableau(d.reglages.joursPause.sorted().map { .chaine($0) })),
            ("blocked_apps", .tableau(d.reglages.applisBloquees.map { .chaine($0) })),
            ("journal_plus", .objet(Journal.plus(d.journal.plus))),
        ])
    }

    /// « 2026-11-13T08:15:30.123Z » : UTC, à la milliseconde.
    public static func instant(_ millis: Int64) -> String {
        let jour = millis >= 0 ? millis / 86_400_000 : (millis - 86_399_999) / 86_400_000
        let reste = Int(millis - jour * 86_400_000)
        func deux(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
        let ms = reste % 1000
        let milli = ms < 10 ? "00\(ms)" : ms < 100 ? "0\(ms)" : "\(ms)"
        let civil = JourCivil(jourJulien: 2_440_588 + Int(jour))
        return "\(civil.iso)T\(deux(reste / 3_600_000)):\(deux(reste / 60_000 % 60)):\(deux(reste / 1000 % 60)).\(milli)Z"
    }

    /// « myhitbodedut-2026-11-13.json » (`SettingsActivity`).
    public static func nomDeFichier(_ jour: JourCivil) -> String { "myhitbodedut-\(jour.iso).json" }
}
