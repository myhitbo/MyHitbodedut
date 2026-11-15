import Foundation

// Le modèle du journal, des réglages et de la lecture, et la sauvegarde JSON échangée avec Android et
// le site (PORTAGE.md § 3.3 à 3.9). Repris de la PR #29 (version 1), porté sur le Store.kt de la
// version Play : la version 2 de l'export (journal enrichi, journal du Tikoun, favoris, 'hizouk gardés,
// marque-pages, noussa'h, réglages de lecture, région choisie à la main) et l'historique daté des
// réglages qui pèsent sur le passé (HistoriqueReglage). L'import est `Store.importJson` ligne pour
// ligne, plus trois adaptations d'iOS : une valeur d'apparence ou d'adresse inconnue est ignorée,
// comme le fait le site (Android retombe sur le défaut) ; un morceau n'est pris que s'il est livré ;
// une taille de lecture illisible (NaN) est ignorée (Android l'écrirait, puis ne saurait plus exporter).
// Jugé par Tests/Vecteurs/sauvegarde.json (tools/vecteurs_ios, sur le Kotlin d'Android).

// MARK: - Dates

extension JourCivil {
    /// `Store.dateValide` : une date de `java.time` (ISO_LOCAL_DATE) qui se réécrit à l'identique. Les
    /// années de 0000 à 9999 en quatre chiffres ; au-delà, signées, « +12345-01-01 », « -0001-12-31 ».
    public init?(java texte: String) {
        if let jour = JourCivil(iso: texte) {
            self = jour
            return
        }
        let u = Array(texte.utf8)
        let tiret = UInt8(ascii: "-")
        guard u.count >= 11, u[0] == UInt8(ascii: "+") || u[0] == tiret,
              u[u.count - 6] == tiret, u[u.count - 3] == tiret else { return nil }
        func nombre(_ plage: Range<Int>) -> Int? {
            guard !plage.isEmpty, plage.count <= 9 else { return nil }
            var valeur = 0
            for i in plage {
                guard u[i] >= UInt8(ascii: "0"), u[i] <= UInt8(ascii: "9") else { return nil }
                valeur = valeur * 10 + Int(u[i] - UInt8(ascii: "0"))
            }
            return valeur
        }
        guard let a = nombre(1..<(u.count - 6)), let m = nombre((u.count - 5)..<(u.count - 3)),
              let j = nombre((u.count - 2)..<u.count),
              let jour = JourCivil(annee: u[0] == tiret ? -a : a, mois: m, jour: j), jour.iso == texte else { return nil }
        self = jour
    }
}

/// `distinct()` de Kotlin sur des chaînes : l'égalité de `java.lang.String`, unité UTF-16 par unité, et
/// non celle de Swift, pour qui « é » précomposé égale « e » suivi de son accent.
func distinctesKotlin(_ liste: [String]) -> [String] {
    var vues = Set<[UInt16]>()
    return liste.filter { vues.insert(Array($0.utf16)).inserted }
}

/// `split(separateur)` de Kotlin : tous les morceaux, vides compris, coupés au point de code (pour Swift,
/// « \r\n » est un seul caractère, que la coupe à « \n » ne verrait pas).
func morceauxKotlin(_ texte: String, _ separateur: Unicode.Scalar) -> [String] {
    texte.unicodeScalars.split(separator: separateur, omittingEmptySubsequences: false).map { String($0) }
}

// MARK: - Journal

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

    /// `Store.readThemes` : les sujets non blancs, dans l'ordre, doublons compris.
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

    /// `JournalPlus.GRATITUDE_MAX`.
    public static let texteMax = 200

    public init(avant: Int = 0, apres: Int = 0, gratitude: String = "", travail: String = "") {
        self.avant = avant
        self.apres = apres
        self.gratitude = gratitude
        self.travail = travail
    }

    public var vide: Bool { avant == 0 && apres == 0 && gratitude.estBlanc && travail.estBlanc }

    /// `JournalPlus.lire`, et la lecture de `Store.importerAjouts` : bornes et longueurs ramenées.
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

    /// `Store.setFirstName` (rogné, coupé à 40), relu par `Store.firstName` (rogné encore).
    public mutating func changerPrenom(_ nom: String) {
        prenom = nom.rogne.premieresUnites(40).rogne
    }

    /// `journal.json` : les clés d'Android (`days`, `journal_plus`, `first_name`).
    public var objet: ObjetJSON {
        ObjetJSON([("days", .objet(Journal.jours(jours))), ("journal_plus", .objet(Journal.plus(plus))),
                   ("first_name", .chaine(prenom))])
    }

    /// La relecture de `journal.json` : une date mal formée est ignorée, comme `Store.days`.
    public init(_ o: ObjetJSON) {
        var jours: [JourCivil: Journee] = [:]
        for (cle, valeur) in o.objet("days")?.paires ?? [] {
            guard case .objet(let e) = valeur, let jour = JourCivil(java: cle) else { continue }
            jours[jour] = Journee(e)
        }
        var plus: [JourCivil: JournalPlus] = [:]
        for (cle, valeur) in o.objet("journal_plus")?.paires ?? [] {
            guard case .objet(let e) = valeur, let jour = JourCivil(java: cle) else { continue }
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

// MARK: - Lecture

/// `MarquesPages.Marque` : une place dans un texte du siddour (« s:id ») ou d'un livre (« l:id »).
public struct MarquePage: Sendable, Equatable {
    public var cle: String
    /// Le noussa'h (les paragraphes diffèrent de l'un à l'autre) ; vide pour un livre.
    public var nusah: String
    public var section: Int
    public var bloc: Int
    /// Les premiers mots, pour la liste.
    public var apercu: String

    public init(cle: String, nusah: String, section: Int, bloc: Int, apercu: String) {
        self.cle = cle
        self.nusah = nusah
        self.section = section
        self.bloc = bloc
        self.apercu = apercu
    }

    /// `MarquesPages.MAX` : au-delà, les plus anciens tombent.
    public static let max = 60

    /// Une même place, quel que soit l'aperçu.
    public func memePlace(_ m: MarquePage) -> Bool {
        cle.egalUnites(m.cle) && nusah.egalUnites(m.nusah) && section == m.section && bloc == m.bloc
    }

    /// La forme de l'export et de `lecture.json`.
    var objet: ObjetJSON {
        ObjetJSON([("cle", .chaine(cle)), ("nusah", .chaine(nusah)), ("section", .entier(Int64(section))),
                   ("bloc", .entier(Int64(bloc))), ("apercu", .chaine(apercu))])
    }

    init(_ o: ObjetJSON) {
        self.init(cle: o.texte("cle"), nusah: o.texte("nusah"), section: o.entier("section", defaut: -1),
                  bloc: o.entier("bloc", defaut: -1), apercu: o.texte("apercu"))
    }

    /// Ce qu'Android relit de la liste après l'avoir rangée dans ses préférences : une ligne par marque,
    /// cinq champs séparés par des tabulations (`MarquesPages.encoder`, puis `decoder`).
    static func relues(_ liste: [MarquePage]) -> [MarquePage] {
        let texte = liste.map { "\($0.cle)\t\($0.nusah)\t\($0.section)\t\($0.bloc)\t\($0.apercu)" }.joined(separator: "\n")
        return morceauxKotlin(texte, "\n").compactMap { (ligne: String) -> MarquePage? in
            let c = morceauxKotlin(ligne, "\t")
            guard c.count >= 5, let section = Int(c[2]), let bloc = Int(c[3]) else { return nil }
            return MarquePage(cle: c[0], nusah: c[1], section: section, bloc: bloc, apercu: c[4])
        }
    }
}

/// Ce que `lecture.json` garde de la sauvegarde : favoris, 'hizouk gardés, marque-pages (les clés
/// `favoris`, `chizuk_favoris`, `marques_pages` d'Android).
public struct Lecture: Sendable, Equatable {
    /// « s:id » ou « l:id », le plus récent en tête.
    public var favoris: [String]
    /// Les identifiants des textes de 'hizouk gardés.
    public var chizukFavoris: [String]
    public var marques: [MarquePage]

    public init(favoris: [String] = [], chizukFavoris: [String] = [], marques: [MarquePage] = []) {
        self.favoris = favoris
        self.chizukFavoris = chizukFavoris
        self.marques = marques
    }

    /// Ce qu'Android relit d'une liste rangée en « a|b|c » (`Store.favoris`, `chizukFavoris`).
    static func relus(_ liste: [String]) -> [String] {
        morceauxKotlin(liste.joined(separator: "|"), "|").filter { !$0.estBlanc }
    }

    public var objet: ObjetJSON {
        ObjetJSON([("favoris", .tableau(favoris.map { .chaine($0) })),
                   ("chizuk_favoris", .tableau(chizukFavoris.map { .chaine($0) })),
                   ("marques_pages", .tableau(marques.map { .objet($0.objet) }))])
    }

    public init(_ o: ObjetJSON) {
        let f = o.tableau("favoris") ?? [], c = o.tableau("chizuk_favoris") ?? [], m = o.tableau("marques_pages") ?? []
        self.init(favoris: f.indices.map { f.texte($0) }, chizukFavoris: c.indices.map { c.texte($0) },
                  marques: m.indices.compactMap { m.objet($0).map(MarquePage.init) })
    }
}

// MARK: - Historique d'un réglage

/// `HistoriqueReglage` (FDONNEES-05) : « Israël ou diaspora » et « Chabbat et Yom Tov » décident des
/// jours exemptés, donc de la série ; chaque changement est daté, et un jour se juge avec la valeur en
/// vigueur ce jour-là. Forme gardée : « 2000-01-01=0,2026-11-05=1 », par dates croissantes ; la
/// première entrée vaut pour tout ce qui la précède. L'export ne la porte pas.
public enum HistoriqueReglage {
    public struct Entree: Sendable, Equatable {
        public let depuis: JourCivil
        public let valeur: Bool

        public init(_ depuis: JourCivil, _ valeur: Bool) {
            self.depuis = depuis
            self.valeur = valeur
        }
    }

    /// La date d'effet de la valeur d'avant le premier changement : avant tout journal.
    public static let origine = JourCivil(jourJulien: 2_451_545)  // 2000-01-01
    /// Au-delà, les plus anciens changements se fondent dans l'origine.
    public static let max = 200

    /// Les entrées lisibles, par dates croissantes, une par date (la dernière l'emporte) ; le reste est ignoré.
    public static func decoder(_ brut: String?) -> [Entree] {
        guard let brut, !brut.estBlanc else { return [] }
        var parDate: [JourCivil: Bool] = [:]
        for morceau in morceauxKotlin(brut, ",") {
            guard let date = JourCivil(java: morceau.avantUnites("=").rogne) else { continue }
            let valeur = morceau.contientUnites("=") ? morceau.apresUnites("=").rogne : ""
            if valeur == "1" { parDate[date] = true }
            if valeur == "0" { parDate[date] = false }
        }
        return parDate.keys.sorted().map { Entree($0, parDate[$0] ?? false) }
    }

    public static func encoder(_ histoire: [Entree]) -> String {
        histoire.map { "\($0.depuis.iso)=\($0.valeur ? 1 : 0)" }.joined(separator: ",")
    }

    /// La valeur en vigueur le `jour` : depuis le dernier changement, `actuelle` ; avant, celle de l'entrée.
    public static func valeurLe(_ histoire: [Entree], _ jour: JourCivil, actuelle: Bool) -> Bool {
        guard let derniere = histoire.last, jour < derniere.depuis else { return actuelle }
        return (histoire.last { !($0.depuis > jour) } ?? histoire[0]).valeur
    }

    /// Après un changement fait `aujourdhui` : le passé garde `ancienne`, le jour même et la suite
    /// prennent `nouvelle`. Changer puis revenir le même jour ne laisse rien.
    public static func apresChangement(_ histoire: [Entree], _ aujourdhui: JourCivil, ancienne: Bool, nouvelle: Bool) -> [Entree] {
        if ancienne == nouvelle { return histoire }
        let base = histoire.isEmpty ? [Entree(origine, ancienne)] : histoire
        // Jamais d'entrée à venir : une horloge reculée ne garde pas un changement du futur.
        var avant = base.filter { $0.depuis < aujourdhui }
        if avant.isEmpty { avant = [Entree(origine, ancienne)] }
        let suite = avant[avant.count - 1].valeur == nouvelle ? avant : avant + [Entree(aujourdhui, nouvelle)]
        if suite.count <= max { return suite }
        let gardees = Array(suite.suffix(max))
        return [Entree(origine, gardees[0].valeur)] + gardees.dropFirst()
    }
}

// MARK: - Réglages

/// `Apparence.Mode` : clair, sombre, ou celui du téléphone.
public enum ModeApparence: String, Sendable, CaseIterable {
    case auto, clair, sombre
}

/// Les réglages que la sauvegarde transporte, sous les noms de clés d'Android, et ceux qu'iOS ne connaît
/// pas encore, gardés tels quels (`autres`). Les défauts sont ceux de `Store.kt`.
public struct Reglages: Sendable, Equatable {
    public var debutFenetre = 6 * 60
    public var finFenetre = 11 * 60
    public var report = 15
    public var duree = 15
    /// 0 : comme la durée habituelle (`Anneaux`).
    public var objectifJour = 0
    public private(set) var pauseShabbat = true
    /// Figé au premier accès d'après le fuseau (`Store.inIsrael`) : c'est à l'appelant de le donner.
    public private(set) var enIsrael: Bool
    /// La région a été choisie à la main dans les réglages (FCALENDRIER-06).
    public private(set) var enIsraelManuel = false
    /// `pause_shabbat_histoire`, `in_israel_histoire` (`HistoriqueReglage`) ; nil tant que le réglage n'a
    /// jamais été écrit, vide s'il a été écrit sans changer.
    public private(set) var histoireShabbat: String?
    public private(set) var histoireIsrael: String?
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
    public var nusah = Nusah.edot
    /// De 0,8 à 2 fois la taille de base (`ReglagesLecture.MIN`, `MAX`), en simple précision comme Android.
    public private(set) var lectureEchelle: Float = 1
    /// Une clé de `PoliceHebraique.Police`.
    public var lecturePolice = "serif"
    public var lectureSombre = false
    public var lectureMasquee = false
    public var lectureEcranAllume = true
    /// Une clé de `LanguesTexte.Mode` ; nil : celle de la langue de l'application.
    public var lectureLangues: String?
    /// Dates valides (`Store.dateValide`).
    public var joursPause: Set<JourCivil> = []
    /// Les paquets d'Android, recopiés sans effet sur iOS (§ 3.7).
    public var applisBloquees: [String] = []
    /// Les jours (bascule à 4 h) où le Tikoun a été dit en entier.
    public var tikkun: Set<JourCivil> = []
    /// Les clés de `reglages.json` qu'iOS ne lit pas : gardées d'une écriture à l'autre.
    public var autres = ObjetJSON()

    /// `PoliceHebraique.Police`, dans l'ordre.
    public static let polices = ["serif", "sans", "arrondie", "frank", "david", "rachi", "miriam"]
    /// `LanguesTexte.Mode`, dans l'ordre.
    public static let languesTexte = ["he", "fr", "en", "he+fr", "he+en", "fr+en"]
    public static let echelleMin: Float = 0.8
    public static let echelleMax: Float = 2.0

    public init(enIsrael: Bool) {
        self.enIsrael = enIsrael
    }

    /// `Store.setShabbatMode` : la valeur, et son historique daté d'`aujourdhui`.
    public mutating func changerPauseShabbat(_ valeur: Bool, aujourdhui: JourCivil) {
        histoireShabbat = Reglages.datee(histoireShabbat, aujourdhui, ancienne: pauseShabbat, nouvelle: valeur)
        pauseShabbat = valeur
    }

    /// `Store.setInIsrael` : la région, le drapeau « choisie à la main », et l'historique.
    public mutating func changerEnIsrael(_ valeur: Bool, manuel: Bool = false, aujourdhui: JourCivil) {
        histoireIsrael = Reglages.datee(histoireIsrael, aujourdhui, ancienne: enIsrael, nouvelle: valeur)
        enIsrael = valeur
        enIsraelManuel = manuel
    }

    private static func datee(_ brut: String?, _ aujourdhui: JourCivil, ancienne: Bool, nouvelle: Bool) -> String {
        HistoriqueReglage.encoder(HistoriqueReglage.apresChangement(HistoriqueReglage.decoder(brut), aujourdhui,
                                                                    ancienne: ancienne, nouvelle: nouvelle))
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

    /// `Store.setLectureEchelle`, relu par `Store.lectureEchelle` : ramenée entre 0,8 et 2 (`coerceIn`).
    public mutating func changerLectureEchelle(_ e: Float) {
        guard !e.isNaN else { return }
        lectureEchelle = e < Reglages.echelleMin ? Reglages.echelleMin : e > Reglages.echelleMax ? Reglages.echelleMax : e
    }

    /// Les réglages de l'export, dans l'ordre d'Android (`Store.exportJson`, version 2).
    func exportes(prenom: String) -> ObjetJSON {
        var o = ObjetJSON([
            ("window_start", .entier(Int64(debutFenetre))), ("window_end", .entier(Int64(finFenetre))),
            ("snooze_minutes", .entier(Int64(report))), ("target_minutes", .entier(Int64(duree))),
            ("daily_goal_minutes", .entier(Int64(objectifJour))), ("pause_shabbat", .booleen(pauseShabbat)),
            ("in_israel", .booleen(enIsrael)), ("in_israel_manuel", .booleen(enIsraelManuel)),
            ("reminder_enabled", .booleen(rappelActif)), ("reminder_minutes", .entier(Int64(rappelMinutes))),
            ("reminder_times", .tableau(rappels.map { .entier(Int64($0)) })),
            ("first_name", .chaine(prenom)), ("hide_countdown", .booleen(masquerDecompte)),
            ("guided_hitbodedut", .booleen(guidee)), ("music_enabled", .booleen(musique)),
            ("music_volume", .entier(Int64(volume))), ("music_shuffle", .booleen(aleatoire)),
            ("music_track", .chaine(morceau)), ("adresse", .chaine(adresse)),
            ("apparence_mode", .chaine(mode.rawValue)), ("apparence_fond", .chaine(fond.rawValue)),
            ("apparence_accent", .chaine(accent.rawValue)), ("siddur_nusah", .chaine(nusah.rawValue)),
            // Float → Double, comme `lectureEchelle(context).toDouble()` : 1,3 s'écrit 1.2999999523162842.
            ("lecture_echelle", .decimal(Double(lectureEchelle))), ("lecture_police", .chaine(lecturePolice)),
            ("lecture_sombre", .booleen(lectureSombre)), ("lecture_masquee", .booleen(lectureMasquee)),
            ("lecture_ecran_allume", .booleen(lectureEcranAllume)),
        ])
        if let lectureLangues { o["lecture_langues"] = .chaine(lectureLangues) }
        return o
    }

    /// Les clés que `Reglages` lit dans `reglages.json`.
    private static let connues: Set<String> = [
        "window_start", "window_end", "snooze_minutes", "target_minutes", "daily_goal_minutes", "pause_shabbat",
        "pause_shabbat_histoire", "in_israel", "in_israel_manuel", "in_israel_histoire", "reminder_on",
        "reminder_times", "reminder_minutes", "hide_countdown", "guided_hitbodedut", "music_enabled",
        "music_volume", "music_shuffle", "music_track", "adresse", "apparence_mode", "apparence_fond",
        "apparence_accent", "siddur_nusah", "lecture_echelle", "lecture_police", "lecture_sombre",
        "lecture_masquee", "lecture_ecran_allume", "lecture_langues", "paused_dates", "blocked_apps", "tikkun_journal",
    ]

    /// `reglages.json`, sous les noms des préférences d'Android (`reminder_on`, et non `reminder_enabled`).
    public var objet: ObjetJSON {
        var o = ObjetJSON([
            ("window_start", .entier(Int64(debutFenetre))), ("window_end", .entier(Int64(finFenetre))),
            ("snooze_minutes", .entier(Int64(report))), ("target_minutes", .entier(Int64(duree))),
            ("daily_goal_minutes", .entier(Int64(objectifJour))), ("pause_shabbat", .booleen(pauseShabbat)),
            ("in_israel", .booleen(enIsrael)), ("in_israel_manuel", .booleen(enIsraelManuel)),
            ("reminder_on", .booleen(rappelActif)), ("reminder_minutes", .entier(Int64(rappelMinutes))),
            ("reminder_times", .tableau(rappels.map { .entier(Int64($0)) })),
            ("hide_countdown", .booleen(masquerDecompte)), ("guided_hitbodedut", .booleen(guidee)),
            ("music_enabled", .booleen(musique)), ("music_volume", .entier(Int64(volume))),
            ("music_shuffle", .booleen(aleatoire)), ("music_track", .chaine(morceau)), ("adresse", .chaine(adresse)),
            ("apparence_mode", .chaine(mode.rawValue)), ("apparence_fond", .chaine(fond.rawValue)),
            ("apparence_accent", .chaine(accent.rawValue)), ("siddur_nusah", .chaine(nusah.rawValue)),
            ("lecture_echelle", .decimal(Double(lectureEchelle))), ("lecture_police", .chaine(lecturePolice)),
            ("lecture_sombre", .booleen(lectureSombre)), ("lecture_masquee", .booleen(lectureMasquee)),
            ("lecture_ecran_allume", .booleen(lectureEcranAllume)),
            ("paused_dates", .tableau(joursPause.sorted().map { .chaine($0.iso) })),
            ("blocked_apps", .tableau(applisBloquees.map { .chaine($0) })),
            ("tikkun_journal", .tableau(tikkun.sorted().map { .chaine($0.iso) })),
        ])
        if let histoireShabbat { o["pause_shabbat_histoire"] = .chaine(histoireShabbat) }
        if let histoireIsrael { o["in_israel_histoire"] = .chaine(histoireIsrael) }
        if let lectureLangues { o["lecture_langues"] = .chaine(lectureLangues) }
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
        enIsraelManuel = o.booleen("in_israel_manuel")
        histoireShabbat = o.a("pause_shabbat_histoire") ? o.texte("pause_shabbat_histoire") : nil
        histoireIsrael = o.a("in_israel_histoire") ? o.texte("in_israel_histoire") : nil
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
        nusah = Nusah.de(o.texte("siddur_nusah"))
        changerLectureEchelle(Float(o.double("lecture_echelle", defaut: 1)))
        let police = o.texte("lecture_police")
        lecturePolice = Reglages.polices.contains(police) ? police : "serif"
        lectureSombre = o.booleen("lecture_sombre")
        lectureMasquee = o.booleen("lecture_masquee")
        lectureEcranAllume = o.booleen("lecture_ecran_allume", defaut: true)
        lectureLangues = o.a("lecture_langues") ? o.texte("lecture_langues") : nil
        let pauses = o.tableau("paused_dates") ?? []
        joursPause = Set(pauses.indices.compactMap { JourCivil(java: pauses.texte($0)) })
        let applis = o.tableau("blocked_apps") ?? []
        applisBloquees = applis.indices.map { applis.texte($0) }
        let tikkun = o.tableau("tikkun_journal") ?? []
        self.tikkun = Set(tikkun.indices.compactMap { JourCivil(java: tikkun.texte($0)) })
        for (cle, valeur) in o.paires where !Reglages.connues.contains(cle) { autres[cle] = valeur }
    }
}

/// Tout ce que la sauvegarde touche : le journal, les réglages et la lecture.
public struct Donnees: Sendable, Equatable {
    public var journal: Journal
    public var reglages: Reglages
    public var lecture: Lecture

    public init(journal: Journal = Journal(), reglages: Reglages, lecture: Lecture = Lecture()) {
        self.journal = journal
        self.reglages = reglages
        self.lecture = lecture
    }
}

// MARK: - La sauvegarde

/// La sauvegarde JSON, versions 1 et 2 à la lecture, version 2 à l'écriture.
public enum Sauvegarde {

    /// `SettingsActivity.IMPORT_MAX_OCTETS`.
    public static let tailleMax = 2 * 1024 * 1024

    /// La version écrite : celle d'Android et du site depuis l'audit du 12/11 (FDONNEES-01).
    public static let version = 2

    /// Les morceaux livrés (`MusiquePlay.BUNDLED`) : seul un de ceux-là peut venir d'une sauvegarde.
    public static let morceauxLivres: [String] = [
        "hamelech_basade", "yanuka_nigoun_3", "shpayer_beyond", "shpayer_eshet_hayil", "shpayer_arba_bavot",
        "shpayer_afilou", "shpayer_kenout", "shpayer_esh_kamanche", "shpayer_hithadshout", "shpayer_pnima",
        "shpayer_tunnels_end", "shpayer_ki_hine_kahomer", "ianir_mirage", "ianir_al_harega", "ianir_hello",
        "ianir_baal_shem_tov", "ianir_zemer_bishvahin", "ianir_berditchev", "ianir_kol_bayaar",
        "ianir_yohanan_hasandlar", "ianir_haleluhu", "ianir_houppa", "ianir_eden_el_salvador",
        "ianir_hakol_milfanekha", "ianir_kabbalat_chabbat", "ianir_bessarabie",
    ]

    /// Le texte d'un fichier : nil au-delà de 2 Mo (`SettingsActivity.readBackup`). Comme
    /// `String(octets, UTF_8)`, une suite d'octets mal formée devient U+FFFD sans faire échouer la lecture.
    public static func texte(_ donnees: Data) -> String? {
        guard donnees.count <= tailleMax else { return nil }
        return String(decoding: donnees, as: UTF8.self)
    }

    /// `Store.importJson` : fusionne la sauvegarde ; le nombre de journées lues, ou nil si le fichier est
    /// invalide (et rien n'est touché). `aujourdhui` décide des journées à venir et date les historiques.
    public static func importer(_ texte: String, dans d: inout Donnees, aujourdhui: JourCivil) -> Int? {
        guard let racine = try? ObjetJSON(texte: texte), racine.texte("format") == "myhitbodedut" else { return nil }
        let demain = aujourdhui.plus(jours: 1)
        var lues = 0
        for (cle, valeur) in racine.objet("days")?.paires ?? [] {
            guard case .objet(let e) = valeur, let jour = JourCivil(java: cle), jour < demain else { continue }
            let entrant = Journee(minutes: min(max(e.entier("minutes"), 0), 24 * 60),
                                  note: e.texte("note").premieresUnites(Journee.noteMax),
                                  themes: Journee.themes(e), noteSeule: e.booleen("note_seule"))
            if let ici = d.journal.jours[jour] {
                // La séance la plus longue, la note non vide, les sujets réunis (distinct), note seule des deux côtés.
                d.journal.jours[jour] = Journee(minutes: max(ici.minutes, entrant.minutes),
                                                note: ici.note.estBlanc ? entrant.note : ici.note,
                                                themes: distinctesKotlin(ici.themes + entrant.themes),
                                                noteSeule: ici.noteSeule && entrant.noteSeule)
            } else {
                d.journal.jours[jour] = entrant
            }
            lues += 1
        }
        ajouts(racine, &d, demain: demain)
        if let s = racine.objet("settings") {
            reglages(s, &d, aujourdhui: aujourdhui)
        }
        if let t = racine.tableau("paused_dates") {
            for i in t.indices {
                if let jour = JourCivil(java: t.texte(i)) { d.reglages.joursPause.insert(jour) }
            }
        }
        if let t = racine.tableau("blocked_apps") {
            let applis = distinctesKotlin(d.reglages.applisBloquees + t.indices.map { t.texte($0) })
            d.reglages.applisBloquees = applis.filter { !$0.estBlanc }
        }
        return lues
    }

    /// `Store.chaines` : les chaînes d'un tableau, non blanches, sans doublon.
    private static func chaines(_ t: [JSON]?) -> [String] {
        guard let t else { return [] }
        return distinctesKotlin(t.indices.map { t.texte($0) }.filter { !$0.estBlanc })
    }

    /// `Store.importerAjouts` : ce que la version 2 a ajouté, réuni à ce que le téléphone a déjà.
    private static func ajouts(_ racine: ObjetJSON, _ d: inout Donnees, demain: JourCivil) {
        // Le journal enrichi : un jour déjà noté ici garde ce qu'il a (store.js fait de même).
        let ici = d.journal.plus
        for (cle, valeur) in racine.objet("journal_plus")?.paires ?? [] {
            guard let jour = JourCivil(java: cle), jour < demain, case .objet(let e) = valeur else { continue }
            let plus = JournalPlus(e)
            let dejaNote = !(ici[jour]?.vide ?? true)
            if !plus.vide && !dejaNote { d.journal.plus[jour] = plus }
        }
        let tikkun = chaines(racine.tableau("tikkun_journal")).compactMap { JourCivil(java: $0) }.filter { $0 < demain }
        d.reglages.tikkun.formUnion(tikkun)
        let favoris = chaines(racine.tableau("favoris")).filter { $0.commenceParUnites("s:") || $0.commenceParUnites("l:") }
        if !favoris.isEmpty {
            d.lecture.favoris = Lecture.relus(distinctesKotlin(d.lecture.favoris + favoris))
        }
        let chizuk = chaines(racine.tableau("chizuk_favoris")).filter { !$0.contientUnites("|") }
        if !chizuk.isEmpty {
            d.lecture.chizukFavoris = Lecture.relus(distinctesKotlin(d.lecture.chizukFavoris + chizuk))
        }
        if let a = racine.tableau("marques_pages") {
            let entrantes: [MarquePage] = a.indices.compactMap { i in
                guard let o = a.objet(i) else { return nil }
                var m = MarquePage(o)
                m.apercu = m.apercu.remplacantUnites("\t", par: " ").remplacantUnites("\n", par: " ")
                guard !m.cle.estBlanc, !m.cle.contientUnites("\t"), !m.nusah.contientUnites("\t"),
                      m.section >= 0, m.bloc >= 0 else { return nil }
                return m
            }
            let deja = d.lecture.marques
            let reunies = deja + entrantes.filter { e in !deja.contains { $0.memePlace(e) } }
            d.lecture.marques = MarquePage.relues(Array(reunies.prefix(MarquePage.max)))
        }
    }

    /// Chaque valeur ramenée dans ce que l'écran permet, comme Android.
    private static func reglages(_ s: ObjetJSON, _ d: inout Donnees, aujourdhui: JourCivil) {
        var r = d.reglages
        let jour = 0..<(24 * 60)
        let debut = s.entier("window_start", defaut: r.debutFenetre)
        let fin = s.entier("window_end", defaut: r.finFenetre)
        if jour.contains(debut) { r.debutFenetre = debut }
        if jour.contains(fin) { r.finFenetre = fin }
        r.report = min(max(s.entier("snooze_minutes", defaut: r.report), 1), 240)
        r.duree = min(max(s.entier("target_minutes", defaut: r.duree), 1), 240)
        if s.a("daily_goal_minutes") { r.objectifJour = min(max(s.entier("daily_goal_minutes"), 0), 240) }
        r.changerPauseShabbat(s.booleen("pause_shabbat", defaut: r.pauseShabbat), aujourdhui: aujourdhui)
        // La région et son drapeau « choisie à la main » voyagent ensemble (FCALENDRIER-06).
        r.changerEnIsrael(s.booleen("in_israel", defaut: r.enIsrael),
                          manuel: s.booleen("in_israel_manuel", defaut: r.enIsraelManuel), aujourdhui: aujourdhui)
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
        // Adaptation d'iOS : une URI d'Android ou un morceau inconnu ne désigne rien ici.
        let morceau = s.texte("music_track")
        if morceauxLivres.contains(morceau) { r.morceau = morceau }
        // Adaptation, règle du site : une valeur inconnue est ignorée (Android retombe sur le défaut).
        let adresse = s.texte("adresse")
        if adresse == "m" || adresse == "f" { r.adresse = adresse }
        if let m = ModeApparence(rawValue: s.texte("apparence_mode")) { r.mode = m }
        if let f = Fond(rawValue: s.texte("apparence_fond")) { r.fond = f }
        if let a = Accent(rawValue: s.texte("apparence_accent")) { r.accent = a }
        if let n = Nusah(rawValue: s.texte("siddur_nusah")) { r.nusah = n }
        if s.a("lecture_echelle") { r.changerLectureEchelle(Float(s.double("lecture_echelle", defaut: 1))) }
        let police = s.texte("lecture_police")
        if Reglages.polices.contains(police) { r.lecturePolice = police }
        let langues = s.texte("lecture_langues")
        if Reglages.languesTexte.contains(langues) { r.lectureLangues = langues }
        if s.a("lecture_sombre") { r.lectureSombre = s.booleen("lecture_sombre") }
        if s.a("lecture_masquee") { r.lectureMasquee = s.booleen("lecture_masquee") }
        if s.a("lecture_ecran_allume") { r.lectureEcranAllume = s.booleen("lecture_ecran_allume", defaut: true) }
        d.reglages = r
    }

    /// `Store.exportJson`, version 2 : indenté de deux espaces, clés dans l'ordre d'Android.
    public static func exporter(_ d: Donnees, maintenant: Int64) -> String {
        racine(d, maintenant: maintenant).texte(indentation: 2)
    }

    /// Le même, à l'instant `maintenant`.
    public static func exporter(_ d: Donnees, maintenant: Date) -> String {
        exporter(d, maintenant: Int64((maintenant.timeIntervalSince1970 * 1000).rounded(.down)))
    }

    static func racine(_ d: Donnees, maintenant: Int64) -> ObjetJSON {
        ObjetJSON([
            ("format", .chaine("myhitbodedut")), ("version", .entier(Int64(version))),
            ("exported_at", .chaine(instant(maintenant))),
            ("days", .objet(Journal.jours(d.journal.jours))),
            ("settings", .objet(d.reglages.exportes(prenom: d.journal.prenom))),
            ("paused_dates", .tableau(d.reglages.joursPause.sorted().map { .chaine($0.iso) })),
            ("blocked_apps", .tableau(d.reglages.applisBloquees.map { .chaine($0) })),
            ("journal_plus", .objet(Journal.plus(d.journal.plus))),
            ("tikkun_journal", .tableau(d.reglages.tikkun.sorted().map { .chaine($0.iso) })),
            ("favoris", .tableau(d.lecture.favoris.map { .chaine($0) })),
            ("chizuk_favoris", .tableau(d.lecture.chizukFavoris.map { .chaine($0) })),
            ("marques_pages", .tableau(d.lecture.marques.map { .objet($0.objet) })),
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
