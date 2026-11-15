import Foundation

// Les réglages d'Android (Store.kt) : chaque accesseur de Store qui ne fait que lire ou écrire une
// préférence du fichier « myhitbodedut », avec la même valeur par défaut, les mêmes bornes et le même
// nom. Ils vivent dans un objet JSON à plat, sous les noms de clés d'Android : c'est le contenu du
// futur reglages.json (PORTAGE.md § 3.2), et ce qui rend les réglages portables.
//
// Une préférence garde la forme qu'Android lui donne : un entier, un booléen, une chaîne (les heures de
// rappel « 420,1260 », les coordonnées du lieu en texte), un Float en nombre décimal exact, un ensemble
// de chaînes (StringSet) en tableau trié par unités UTF-16. Une clé qu'aucun accesseur ne lit reste
// telle quelle, à sa place. Android lève sur une préférence d'un autre type ; la lecture est ici celle,
// tolérante, d'org.json (un nombre écrit en chaîne se lit, un booléen à la place d'un nombre ne se lit
// pas et rend le défaut).
//
// Restent à d'autres tâches les accesseurs qui calculent (série, semaine, fenêtre, séance, plan du vol
// et ses rappels, trophées, Tikoun, rotation du 'hizouk) et ceux de la lecture (favoris, marque-pages,
// places), qui iront dans lecture.json. Le journal, ses notes et le prénom sont dans Modele.swift.
// Jugé par `Tests/Vecteurs/reglages.json` (tools/vecteurs_ios/VecteursReglages.kt).

/// Les réglages : les préférences « myhitbodedut » d'Android, sous leurs noms de clés.
public struct Reglages: Sendable, Equatable {

    /// Les préférences, clés dans l'ordre où elles ont été posées.
    public private(set) var brut: ObjetJSON

    public init() {
        brut = ObjetJSON()
    }

    public init(brut: ObjetJSON) {
        self.brut = brut
    }

    /// Lit le texte de reglages.json.
    public init(texte: String) throws {
        brut = try ObjetJSON(texte: texte)
    }

    /// Le texte de reglages.json, écrit comme `JSONObject.toString()` d'Android.
    public func texte(indentation: Int? = nil) -> String {
        brut.texte(indentation: indentation)
    }

    // MARK: Valeurs par défaut (Store.kt)

    public static let defaultStart = 6 * 60
    public static let defaultEnd = 11 * 60
    public static let defaultSnooze = 15
    /// 15 minutes : ce que le conseil n° 2 recommande pour commencer (revue du 29/09).
    public static let defaultTarget = 15
    public static let defaultReminder = 7 * 60
    public static let defaultVolume = 60

    /// La taille des lettres des écrans de lecture, de 0,8 à 2 fois la taille de base (ReglagesLecture.MIN, MAX).
    public static let echelleMin: Float = 0.8
    public static let echelleMax: Float = 2.0

    /// La version de la présentation (Onboarding.VERSION).
    public static let versionPresentation = 2

    // MARK: Les clés admises des réglages à énumération

    /// צדיק ou צדקת (Adresse.kt) ; aucune : la clé est absente.
    public static let adresses = ["m", "f"]
    /// Apparence.Mode, le premier par défaut.
    public static let modesApparence = ["auto", "clair", "sombre"]
    /// PoliceHebraique.Police, la première par défaut.
    public static let polices = ["serif", "sans", "arrondie", "frank", "david", "rachi", "miriam"]
    /// Levana.Usage ; aucune : celui du noussa'h.
    public static let usagesLevana = ["trois_mi_mois", "sept_mi_mois", "sept_quinze"]

    /// Le livre de la halakha du jour (Store.SourceHalakha, 14/10) : le Yalkut Yosef par défaut, le Ben
    /// Ish 'Haï de la paracha, ou les deux. Les clés sont celles du web.
    public enum SourceHalakha: String, Sendable, CaseIterable {
        case yalkut
        case benIshHai = "ben_ish_hai"
        case lesDeux = "les_deux"

        /// La clé de son libellé dans les chaînes.
        public var libelle: String {
            switch self {
            case .yalkut: "halakha_source_yalkut"
            case .benIshHai: "halakha_source_bih"
            case .lesDeux: "halakha_source_deux"
            }
        }

        /// `yalkut` d'Android : un cas et une propriété ne peuvent porter le même nom en Swift.
        public var montreYalkut: Bool { self != .benIshHai }
        /// `benIshHai` d'Android.
        public var montreBenIshHai: Bool { self != .yalkut }
    }

    /// L'écran d'ouverture (Store.Ouverture, 14/10) : Aujourd'hui, Textes ou Zmanim.
    public enum Ouverture: String, Sendable, CaseIterable {
        case aujourdhui, textes, zmanim

        /// La clé de son libellé dans les chaînes.
        public var libelle: String {
            switch self {
            case .aujourdhui: "nav_today"
            case .textes: "nav_texts"
            case .zmanim: "nav_zmanim"
            }
        }
    }

    /// Le bravo en attente, et le jour de la note qu'il proposera ensuite (Store.Celebration).
    public struct Celebration: Sendable, Equatable {
        public let minutes: Int
        public let dateNote: String?

        public init(minutes: Int, dateNote: String?) {
            self.minutes = minutes
            self.dateNote = dateNote
        }
    }

    // MARK: Jours sans obligation

    /// Shabbat et Yom Tov : un seul réglage, la clé d'origine est conservée.
    public var shabbatMode: Bool { booleen("pause_shabbat", true) }

    public mutating func setShabbatMode(_ value: Bool) {
        poseBooleen("pause_shabbat", value)
    }

    /// Israël ou diaspora : la valeur enregistrée, sinon celle que le fuseau du téléphone donne et que
    /// le premier accès d'Android fige (`figeInIsrael`).
    public func inIsrael(fuseauTelephone: String) -> Bool {
        guard brut.a("in_israel") else { return Holidays.defaultInIsrael(timeZoneId: fuseauTelephone) }
        return booleen("in_israel", false)
    }

    /// `inIsrael` d'Android : le premier accès fige la valeur déduite du fuseau. Sans cela, un voyage
    /// changeait le deuxième jour de fête après coup, et pouvait casser une série (revue du 01/10).
    @discardableResult
    public mutating func figeInIsrael(fuseauTelephone: String) -> Bool {
        if !brut.a("in_israel") {
            poseBooleen("in_israel", Holidays.defaultInIsrael(timeZoneId: fuseauTelephone))
        }
        return booleen("in_israel", false)
    }

    public mutating func setInIsrael(_ value: Bool) {
        poseBooleen("in_israel", value)
    }

    /// Les dates mises en pause à la main, telles qu'écrites (une date mal formée y reste).
    public var pausedDates: Set<String> { ensemble("paused_dates") ?? [] }

    public mutating func togglePausedDate(_ date: String) {
        var dates = pausedDates
        if dates.remove(date) == nil {
            dates.insert(date)
        }
        poseEnsemble("paused_dates", dates)
    }

    /// Toutes les dates d'un coup, telles quelles : ce que l'import de la sauvegarde écrit
    /// (Store.importJson, `putStringSet(KEY_PAUSED_DATES, …)`).
    public mutating func setPausedDates(_ dates: Set<String>) {
        poseEnsemble("paused_dates", dates)
    }

    // MARK: Le lieu des zmanim

    /// Une ville de la liste ou la position du téléphone ; nil tant que rien n'est choisi. Les nombres
    /// sont gardés en texte, lus comme `toDoubleOrNull` : SharedPreferences n'a pas de type décimal double.
    public var lieuZmanim: Zmanim.Lieu? {
        guard let latitude = chaine("lieu_latitude").flatMap({ Java.parseDouble($0) }),
              let longitude = chaine("lieu_longitude").flatMap({ Java.parseDouble($0) }),
              let fuseau = chaine("lieu_fuseau") else { return nil }
        let altitude = chaine("lieu_altitude").flatMap({ Java.parseDouble($0) }) ?? 0
        return Zmanim.Lieu(nom: chaine("lieu_nom") ?? "", latitude: latitude, longitude: longitude,
                           altitude: altitude, fuseau: fuseau)
    }

    /// Quand le lieu a été enregistré (millisecondes), 0 s'il date d'avant le 02/11.
    public var lieuDepuis: Int64 { long("lieu_t", 0) }

    /// La ville choisie dans la liste (identifiant GeoNames), ou -1 pour la position du téléphone.
    public var lieuVille: Int64 { long("lieu_ville", -1) }

    /// La position du téléphone prise dans un autre fuseau que celui du téléphone aujourd'hui : on a
    /// voyagé depuis. Une ville choisie n'est jamais périmée.
    public func lieuPerime(fuseauTelephone: String) -> Bool {
        guard let lieu = lieuZmanim else { return false }
        return lieuVille == -1 && !lieu.fuseau.egalUnites(fuseauTelephone)
    }

    /// Le lieu des alertes programmées (Chabbat, Levana) : celui des zmanim, sauf une position périmée.
    public func lieuAlertes(fuseauTelephone: String) -> Zmanim.Lieu? {
        lieuPerime(fuseauTelephone: fuseauTelephone) ? nil : lieuZmanim
    }

    /// Pourim le 15 Adar : la ville de Jérusalem, ou une position dans Jérusalem.
    public var mukafChoma: Bool {
        let ville = lieuVille
        if ville == CalendrierJuif.jerusalemGeonames { return true }
        guard ville == -1, let lieu = lieuZmanim else { return false }
        return CalendrierJuif.aJerusalem(latitude: lieu.latitude, longitude: lieu.longitude)
    }

    /// Le lieu des zmanim est au sud de l'équateur (Ilanot, Morid hatal des Edot).
    public var hemisphereSud: Bool { (lieuZmanim?.latitude ?? 0) < 0 }

    /// Choisir le lieu règle aussi Israël ou diaspora : une ville le dit, une position son fuseau
    /// (Holidays.defaultInIsrael ; le contour du territoire est l'affaire de l'écran qui la prend).
    /// `maintenant` : l'instant de l'enregistrement, en millisecondes Unix.
    public mutating func setLieuZmanim(_ lieu: Zmanim.Lieu, ville: Ville?, maintenant: Int64) {
        poseChaine("lieu_nom", lieu.nom)
        poseChaine("lieu_latitude", Java.texte(lieu.latitude))
        poseChaine("lieu_longitude", Java.texte(lieu.longitude))
        poseChaine("lieu_altitude", Java.texte(lieu.altitude))
        poseChaine("lieu_fuseau", lieu.fuseau)
        poseLong("lieu_ville", ville?.id ?? -1)
        poseLong("lieu_t", maintenant)
        setInIsrael(ville?.enIsrael ?? Holidays.defaultInIsrael(timeZoneId: lieu.fuseau))
    }

    // MARK: Zmanim, boussole, calendrier

    /// La boussole en rose des vents plutôt qu'en hassid (design C, par défaut).
    public var boussoleRose: Bool { booleen("boussole_rose", false) }

    public mutating func setBoussoleRose(_ rose: Bool) {
        poseBooleen("boussole_rose", rose)
    }

    /// La direction de la carte de Mercator (cap constant) plutôt que celle du grand cercle (par défaut).
    public var boussoleCarte: Bool { booleen("boussole_carte", false) }

    public mutating func setBoussoleCarte(_ carte: Bool) {
        poseBooleen("boussole_carte", carte)
    }

    // MARK: Le vol

    /// Les rappels en vol (VolRappels, VolAlerte) : actifs par défaut, un interrupteur sur l'écran du vol.
    public var volRappelsActifs: Bool { booleen("vol_rappels_actifs", true) }

    public mutating func setVolRappelsActifs(_ actifs: Bool) {
        poseBooleen("vol_rappels_actifs", actifs)
    }

    /// Le suivi de vol en direct (SuiviVol) : désactivé tant que l'utilisateur ne l'active pas.
    public var suiviDirect: Bool { booleen("vol_suivi_direct", false) }

    public mutating func setSuiviDirect(_ actif: Bool) {
        poseBooleen("vol_suivi_direct", actif)
    }

    /// L'indicatif radio du vol (« ELY1 »), pour le suivi en direct ; vide par défaut.
    public var volIndicatif: String { chaine("vol_indicatif") ?? "" }

    public mutating func setVolIndicatif(_ indicatif: String) {
        poseChaine("vol_indicatif", indicatif)
    }

    /// L'instant du dernier rappel de vol montré (millisecondes Unix) : un rappel n'est pas montré deux fois.
    public var volRappelVu: Int64 { long("vol_rappel_vu", 0) }

    public mutating func setVolRappelVu(_ instant: Int64) {
        poseLong("vol_rappel_vu", instant)
    }

    /// Les minutes d'allumage avant la chki'a ; 18 si la valeur n'est pas de celles proposées.
    public var allumage: Int {
        let minutes = entier("allumage_minutes", Zmanim.allumageDefaut)
        return Zmanim.allumages.contains(minutes) ? minutes : Zmanim.allumageDefaut
    }

    public mutating func setAllumage(_ minutes: Int) {
        poseEntier("allumage_minutes", minutes)
    }

    /// Pas de Ta'hanoun du 22 Tichri à la fin du mois : toujours en Edot, jamais en Ashkenaz, au choix en Sfard.
    public var sansTahanounFinTichri: Bool {
        switch siddurNusah {
        case .edot: true
        case .sefard: booleen("sans_tahanoun_fin_tichri_sfard", false)
        case .ashkenaz: false
        }
    }

    public mutating func setSansTahanounFinTichriSfard(_ sans: Bool) {
        poseBooleen("sans_tahanoun_fin_tichri_sfard", sans)
    }

    /// Le calendrier s'ouvre sur le mois hébreu ; le mois civil est au choix.
    public var calendrierCivil: Bool { booleen("calendrier_civil", false) }

    public mutating func setCalendrierCivil(_ civil: Bool) {
        poseBooleen("calendrier_civil", civil)
    }

    // MARK: Applications bloquées

    /// Des noms de paquets d'Android, gardés tels quels : sans effet sur iOS (PORTAGE.md § 3.7).
    public var blockedApps: Set<String> { ensemble("blocked_apps") ?? [] }

    public mutating func setBlockedApps(_ apps: Set<String>) {
        poseEnsemble("blocked_apps", apps)
    }

    /// La barrière « Je suis avec Hachem » est activée.
    public var isEnabled: Bool { booleen("enabled", false) }

    public mutating func setEnabled(_ enabled: Bool) {
        poseBooleen("enabled", enabled)
    }

    // MARK: Fenêtre, report, durée

    /// Minutes depuis minuit ; Store ne borne pas ce qu'on y écrit (l'import, lui, le fait).
    public var windowStart: Int { entier("window_start", Reglages.defaultStart) }

    public var windowEnd: Int { entier("window_end", Reglages.defaultEnd) }

    public mutating func setWindow(startMinutes: Int, endMinutes: Int) {
        poseEntier("window_start", startMinutes)
        poseEntier("window_end", endMinutes)
    }

    public var snoozeMinutes: Int { entier("snooze_minutes", Reglages.defaultSnooze) }

    public mutating func setSnoozeMinutes(_ minutes: Int) {
        poseEntier("snooze_minutes", minutes)
    }

    /// La fin du report, en millisecondes Unix ; 0 sans report.
    public var snoozedUntil: Int64 { long("snoozed_until", 0) }

    /// `snooze` : le report court de `maintenant` (millisecondes Unix) à la durée du report plus loin.
    public mutating func snooze(maintenant: Int64) {
        poseLong("snoozed_until", maintenant &+ Int64(snoozeMinutes) &* 60_000)
    }

    public mutating func clearSnooze() {
        poseLong("snoozed_until", 0)
    }

    public func isSnoozed(maintenant: Int64) -> Bool {
        snoozedUntil > maintenant
    }

    /// La durée habituelle d'une hitbodedout ; Store ne borne pas ce qu'on y écrit.
    public var targetMinutes: Int { entier("target_minutes", Reglages.defaultTarget) }

    public mutating func setTargetMinutes(_ minutes: Int) {
        poseEntier("target_minutes", minutes)
    }

    /// L'objectif réglé tel qu'il est écrit, 0 tant qu'il ne l'est pas : ce que l'export d'Android emporte.
    public var objectifRegle: Int { entier("daily_goal_minutes", 0) }

    /// L'objectif de l'anneau du jour : tant qu'il n'est pas réglé, la durée habituelle, une minute au
    /// moins (Anneaux.objectifEffectif).
    public var dailyGoal: Int {
        let regle = objectifRegle
        return regle > 0 ? regle : max(targetMinutes, 1)
    }

    public mutating func setDailyGoal(_ minutes: Int) {
        poseEntier("daily_goal_minutes", max(minutes, 0))
    }

    // MARK: Rappel quotidien

    public var reminderEnabled: Bool { booleen("reminder_on", false) }

    public mutating func setReminderEnabled(_ enabled: Bool) {
        poseBooleen("reminder_on", enabled)
    }

    /// L'heure unique des versions d'avant la liste, encore tenue à jour pour l'export.
    public var reminderMinutes: Int { entier("reminder_minutes", Reglages.defaultReminder) }

    public mutating func setReminderMinutes(_ minutes: Int) {
        poseEntier("reminder_minutes", minutes)
    }

    /// Les heures de rappel de la journée, en minutes depuis minuit, triées et sans doublon. Sans liste
    /// écrite, l'heure unique d'avant, telle quelle : personne ne perd l'heure qu'il avait choisie.
    public var reminderTimes: [Int] {
        guard let texte = chaine("reminder_times") else { return [reminderMinutes] }
        return Reglages.normaliseHeures(Reglages.morceaux(texte).compactMap { Reglages.entierKotlin($0.rogne) })
    }

    public mutating func setReminderTimes(_ heures: [Int]) {
        let propres = Reglages.normaliseHeures(heures)
        poseChaine("reminder_times", propres.map { String($0) }.joined(separator: ","))
        // L'ancienne clé reste à jour : l'export et une version précédente y lisent la première heure.
        poseEntier("reminder_minutes", propres.first ?? Reglages.defaultReminder)
    }

    /// Un rappel reporté, qui doit sonner une fois à cette heure-là (millisecondes Unix).
    public var reminderSnoozedUntil: Int64 { long("reminder_snoozed_until", 0) }

    public mutating func setReminderSnoozedUntil(_ millis: Int64) {
        poseLong("reminder_snoozed_until", millis)
    }

    // MARK: Pendant la séance

    /// Masquer le décompte pendant la séance : éteint par défaut, c'est un choix.
    public var hideCountdown: Bool { booleen("hide_countdown", false) }

    public mutating func setHideCountdown(_ hidden: Bool) {
        poseBooleen("hide_countdown", hidden)
    }

    /// Les quatre temps de Likoutei Moharan II, 25 affichés pendant la séance : éteint par défaut.
    public var guidedHitbodedut: Bool { booleen("guided_hitbodedut", false) }

    public mutating func setGuidedHitbodedut(_ guided: Bool) {
        poseBooleen("guided_hitbodedut", guided)
    }

    /// « Ne pas déranger » pendant la hitbodedout : désactivé par défaut.
    public var nePasDeranger: Bool { booleen("ne_pas_deranger", false) }

    public mutating func setNePasDeranger(_ v: Bool) {
        poseBooleen("ne_pas_deranger", v)
    }

    /// Le mode du téléphone avant la séance, à rétablir à la fin ; nil s'il n'a pas été changé.
    public var filtreAvantSeance: Int? {
        let filtre = entier("filtre_avant_seance", -1)
        return filtre >= 0 ? filtre : nil
    }

    public mutating func setFiltreAvantSeance(_ v: Int?) {
        if let v {
            poseEntier("filtre_avant_seance", v)
        } else {
            brut["filtre_avant_seance"] = nil
        }
    }

    /// L'ambiance des séances : la clé d'une Ambiance, telle qu'écrite ; le silence par défaut.
    public var ambiance: String { chaine("ambiance") ?? "silence" }

    public mutating func setAmbiance(_ cle: String) {
        poseChaine("ambiance", cle)
    }

    // MARK: Musique

    /// Active par défaut : éteinte, une séance restait muette sans que rien ne dise pourquoi.
    public var musicEnabled: Bool { booleen("music_enabled", true) }

    public mutating func setMusicEnabled(_ enabled: Bool) {
        poseBooleen("music_enabled", enabled)
    }

    /// Le morceau choisi ; nil retire la clé, comme `putString(clé, null)`.
    public var musicTrackId: String? { chaine("music_track") }

    public mutating func setMusicTrackId(_ id: String?) {
        poseChaine("music_track", id)
    }

    /// Lecture aléatoire : un morceau au hasard, puis un autre.
    public var musicShuffle: Bool { booleen("music_shuffle", false) }

    public mutating func setMusicShuffle(_ on: Bool) {
        poseBooleen("music_shuffle", on)
    }

    /// Le morceau qui joue en ce moment, pour que l'écran de séance le nomme.
    public var musicNow: String? { chaine("music_now") }

    public mutating func setMusicNow(_ id: String?) {
        poseChaine("music_now", id)
    }

    /// Le volume en pour cent ; ramené entre 0 et 100 à l'écriture.
    public var musicVolume: Int { entier("music_volume", Reglages.defaultVolume) }

    public mutating func setMusicVolume(_ percent: Int) {
        poseEntier("music_volume", min(max(percent, 0), 100))
    }

    /// Les morceaux ajoutés, en JSON (MusicLibrary) ; « [] » par défaut.
    public var musicUserTracks: String { chaine("music_user_tracks") ?? "[]" }

    public mutating func setMusicUserTracks(_ json: String) {
        poseChaine("music_user_tracks", json)
    }

    /// Les noms donnés aux morceaux, en JSON ; « {} » par défaut.
    public var musicNames: String { chaine("music_names") ?? "{}" }

    public mutating func setMusicNames(_ json: String) {
        poseChaine("music_names", json)
    }

    // MARK: Présentation, adresse, langue

    /// La présentation, dans sa version actuelle, a déjà été vue.
    public var hasOnboarded: Bool { entier("onboarded_version", 0) >= Reglages.versionPresentation }

    /// Retient la version vue, et retire le booléen de la v1.96.
    public mutating func setOnboarded() {
        poseEntier("onboarded_version", Reglages.versionPresentation)
        brut["onboarded"] = nil
    }

    /// צדיק (« m ») ou צדקת (« f ») ; nil tant que rien n'est choisi, ou pour une clé inconnue (Adresse.parse).
    public var adresse: String? {
        guard let cle = chaine("adresse"), Reglages.adresses.contains(cle) else { return nil }
        return cle
    }

    /// Une clé inconnue, comme nil, retire le choix : Android n'écrit que les clés de son énumération.
    public mutating func setAdresse(_ cle: String?) {
        if let cle, Reglages.adresses.contains(cle) {
            poseChaine("adresse", cle)
        } else {
            brut["adresse"] = nil
        }
    }

    /// Copie du choix de langue d'AppCompat, pour les services (LangueApp).
    public var langueApp: String { chaine("langue_app") ?? "" }

    public mutating func setLangueApp(_ etiquettes: String) {
        poseChaine("langue_app", etiquettes)
    }

    /// Vrai si l'anglais a été posé par LangueApp.appliquerRepli, non choisi dans les réglages.
    public var langueRepli: Bool { booleen("langue_repli", false) }

    public mutating func setLangueRepli(_ auto: Bool) {
        poseBooleen("langue_repli", auto)
    }

    // MARK: Apparence

    /// La clé du mode clair ou sombre (Apparence.Mode.parse) : « auto » pour une clé absente ou inconnue.
    public var modeApparence: String {
        guard let cle = chaine("apparence_mode"), Reglages.modesApparence.contains(cle) else { return "auto" }
        return cle
    }

    /// Une clé inconnue s'écrit « auto », comme `setModeApparence(Mode.parse(clé))`.
    public mutating func setModeApparence(_ cle: String) {
        poseChaine("apparence_mode", Reglages.modesApparence.contains(cle) ? cle : "auto")
    }

    public var fond: Fond { Fond.de(chaine("apparence_fond")) }

    public mutating func setFond(_ fond: Fond) {
        poseChaine("apparence_fond", fond.rawValue)
    }

    public var accent: Accent { Accent.de(chaine("apparence_accent")) }

    public mutating func setAccent(_ accent: Accent) {
        poseChaine("apparence_accent", accent.rawValue)
    }

    // MARK: Lecture

    /// La taille des lettres, ramenée de 0,8 à 2 à la lecture ; écrite telle quelle.
    public var lectureEchelle: Float {
        let echelle = flottant("lecture_echelle", 1)
        if echelle < Reglages.echelleMin { return Reglages.echelleMin }
        if echelle > Reglages.echelleMax { return Reglages.echelleMax }
        return echelle
    }

    public mutating func setLectureEchelle(_ echelle: Float) {
        brut["lecture_echelle"] = .decimal(Double(echelle))
    }

    /// La clé de la police des textes : l'hébraïque à empattements (« serif ») par défaut.
    public var lecturePolice: String {
        guard let cle = chaine("lecture_police"), Reglages.polices.contains(cle) else { return "serif" }
        return cle
    }

    /// Une clé inconnue s'écrit « serif », la police par défaut.
    public mutating func setLecturePolice(_ cle: String) {
        poseChaine("lecture_police", Reglages.polices.contains(cle) ? cle : "serif")
    }

    /// Les langues d'un texte à lire (« he », « he+fr »…) ; nil : celles de la langue de l'application.
    public var lectureLangues: String? { chaine("lecture_langues") }

    public mutating func setLectureLangues(_ cle: String) {
        poseChaine("lecture_langues", cle)
    }

    /// La lecture sur fond noir, choisie d'un toucher sur la lune.
    public var lectureSombre: Bool { booleen("lecture_sombre", false) }

    public mutating func setLectureSombre(_ sombre: Bool) {
        poseBooleen("lecture_sombre", sombre)
    }

    /// Le bouton de lecture masqué tout à fait.
    public var lectureMasquee: Bool { booleen("lecture_masquee", false) }

    public mutating func setLectureMasquee(_ masquee: Bool) {
        poseBooleen("lecture_masquee", masquee)
    }

    /// Le noussa'h du siddour : Edot HaMizra'h par défaut.
    public var siddurNusah: Nusah { Nusah.de(chaine("siddur_nusah")) }

    public mutating func setSiddurNusah(_ nusah: Nusah) {
        poseChaine("siddur_nusah", nusah.rawValue)
    }

    // MARK: La carte du jour, Levana, l'écran d'ouverture

    /// La hilloula du jour sur la carte du jour : affichée par défaut.
    public var hilloulotAffichees: Bool { booleen("hilloulot_affichees", true) }

    public mutating func setHilloulotAffichees(_ v: Bool) {
        poseBooleen("hilloulot_affichees", v)
    }

    /// La halakha du jour sur la carte du jour : affichée par défaut.
    public var halakhaAffichee: Bool { booleen("halakha_affichee", true) }

    public mutating func setHalakhaAffichee(_ v: Bool) {
        poseBooleen("halakha_affichee", v)
    }

    public var sourceHalakha: SourceHalakha {
        chaine("halakha_source").flatMap(SourceHalakha.init(rawValue:)) ?? .yalkut
    }

    public mutating func setSourceHalakha(_ v: SourceHalakha) {
        poseChaine("halakha_source", v.rawValue)
    }

    /// Birkat haLevana sur l'écran Zmanim : affichée par défaut.
    public var levanaAffichee: Bool { booleen("levana_affichee", true) }

    public mutating func setLevanaAffichee(_ v: Bool) {
        poseBooleen("levana_affichee", v)
    }

    /// La clé de l'usage de Birkat haLevana choisi ; nil : celui du noussa'h.
    public var levanaUsage: String? {
        guard let cle = chaine("levana_usage"), Reglages.usagesLevana.contains(cle) else { return nil }
        return cle
    }

    /// nil, ou une clé inconnue, retire le choix.
    public mutating func setLevanaUsage(_ cle: String?) {
        if let cle, Reglages.usagesLevana.contains(cle) {
            poseChaine("levana_usage", cle)
        } else {
            brut["levana_usage"] = nil
        }
    }

    /// Le rappel de Birkat haLevana : activé par défaut.
    public var levanaRappel: Bool { booleen("levana_rappel", true) }

    public mutating func setLevanaRappel(_ v: Bool) {
        poseBooleen("levana_rappel", v)
    }

    /// Le soir annoncé par l'alarme posée.
    public var levanaRappelSoir: String? { chaine("levana_rappel_soir") }

    public mutating func setLevanaRappelSoir(_ v: String) {
        poseChaine("levana_rappel_soir", v)
    }

    public var ouverture: Ouverture {
        chaine("ecran_ouverture").flatMap(Ouverture.init(rawValue:)) ?? .aujourdhui
    }

    public mutating func setOuverture(_ v: Ouverture) {
        poseChaine("ecran_ouverture", v.rawValue)
    }

    // MARK: Ce qui a déjà été fêté ou annoncé (anneaux, paliers, trophées, bilan)

    /// Les marques des anneaux déjà fêtés (Anneaux.marque).
    public var anneauxFetes: Set<String> { ensemble("anneaux_fetes") ?? [] }

    public mutating func setAnneauxFetes(_ marques: Set<String>) {
        poseEnsemble("anneaux_fetes", marques)
    }

    /// nil tant que les paliers n'ont jamais été regardés : le premier passage ne fête rien.
    public var paliersVus: Set<String>? { ensemble("paliers_vus") }

    public mutating func setPaliersVus(_ marques: Set<String>) {
        poseEnsemble("paliers_vus", marques)
    }

    /// Les paliers déjà annoncés par notification (nil : jamais encore regardés).
    public var paliersNotifies: Set<String>? { ensemble("paliers_notifies") }

    public mutating func setPaliersNotifies(_ marques: Set<String>) {
        poseEnsemble("paliers_notifies", marques)
    }

    /// Les trophées déjà fêtés à l'écran (nil : jamais encore regardés).
    public var tropheesVus: Set<String>? { ensemble("trophees_vus") }

    public mutating func setTropheesVus(_ cles: Set<String>) {
        poseEnsemble("trophees_vus", cles)
    }

    public var tropheesNotifies: Set<String>? { ensemble("trophees_notifies") }

    public mutating func setTropheesNotifies(_ cles: Set<String>) {
        poseEnsemble("trophees_notifies", cles)
    }

    /// Les trophées dont la proximité a déjà été dite, une fois par trophée.
    public var tropheesProchesSignales: Set<String> { ensemble("trophees_proches_signales") ?? [] }

    public mutating func setTropheesProchesSignales(_ cles: Set<String>) {
        poseEnsemble("trophees_proches_signales", cles)
    }

    /// Le dernier grade fêté : nil la première fois, pour ne pas fêter un grade ancien.
    public var gradeVu: Int? {
        let grade = entier("grade_vu", -1)
        return grade >= 0 ? grade : nil
    }

    public mutating func setGradeVu(_ g: Int) {
        poseEntier("grade_vu", g)
    }

    /// Le dernier bilan de semaine montré : le dimanche de la semaine résumée.
    public var bilanVu: String? { chaine("bilan_vu") }

    public mutating func setBilanVu(_ iso: String) {
        poseChaine("bilan_vu", iso)
    }

    /// Le rappel dit qu'un trophée est tout proche : activé par défaut.
    public var rappelTropheeProche: Bool { booleen("rappel_trophee_proche", true) }

    public mutating func setRappelTropheeProche(_ oui: Bool) {
        poseBooleen("rappel_trophee_proche", oui)
    }

    // MARK: Le bravo en attente

    /// Une séance vient de se clore : le bravo attend le prochain écran ouvert. `dateNote` est le jour de
    /// la séance ; le bravo propose la note ensuite.
    public mutating func setPendingCelebration(minutes: Int, dateNote: String? = nil) {
        poseEntier("celebration_minutes", max(minutes, 0))
        poseChaine("celebration_date", dateNote)
    }

    public var hasPendingCelebration: Bool { brut.a("celebration_minutes") }

    /// Rend le bravo en attente et le retire, ou nil s'il n'y en a pas.
    @discardableResult
    public mutating func takePendingCelebration() -> Celebration? {
        guard brut.a("celebration_minutes") else { return nil }
        let celebration = Celebration(minutes: entier("celebration_minutes", 0), dateNote: chaine("celebration_date"))
        brut["celebration_minutes"] = nil
        brut["celebration_date"] = nil
        return celebration
    }

    // MARK: Lecture et écriture d'une préférence

    /// `getInt` : le défaut si la clé manque ou ne se lit pas comme un nombre.
    private func entier(_ cle: String, _ defaut: Int) -> Int {
        guard let valeur = brut[cle]?.commeEntier else { return defaut }
        return Int(valeur)
    }

    /// `getLong`.
    private func long(_ cle: String, _ defaut: Int64) -> Int64 {
        brut[cle]?.commeLong ?? defaut
    }

    /// `getBoolean`.
    private func booleen(_ cle: String, _ defaut: Bool) -> Bool {
        brut[cle]?.commeBooleen ?? defaut
    }

    /// `getFloat` : un nombre décimal ramené en simple précision.
    private func flottant(_ cle: String, _ defaut: Float) -> Float {
        guard let valeur = brut[cle]?.commeDouble else { return defaut }
        return Float(valeur)
    }

    /// `getString(clé, null)` : seule une chaîne se lit ; nil si la clé manque.
    private func chaine(_ cle: String) -> String? {
        if case .chaine(let texte)? = brut[cle] { return texte }
        return nil
    }

    /// `getStringSet(clé, null)` : nil si la clé manque ; seules les chaînes du tableau comptent.
    private func ensemble(_ cle: String) -> Set<String>? {
        guard let elements = brut.tableau(cle) else { return nil }
        var resultat = Set<String>()
        for element in elements {
            if case .chaine(let texte) = element {
                resultat.insert(texte)
            }
        }
        return resultat
    }

    private mutating func poseEntier(_ cle: String, _ valeur: Int) {
        brut[cle] = .entier(Int64(valeur))
    }

    private mutating func poseLong(_ cle: String, _ valeur: Int64) {
        brut[cle] = .entier(valeur)
    }

    private mutating func poseBooleen(_ cle: String, _ valeur: Bool) {
        brut[cle] = .booleen(valeur)
    }

    /// `putString` : nil retire la clé.
    private mutating func poseChaine(_ cle: String, _ valeur: String?) {
        if let valeur {
            brut[cle] = .chaine(valeur)
        } else {
            brut[cle] = nil
        }
    }

    /// `putStringSet` : un tableau trié par unités UTF-16, comme `sorted()` de Kotlin.
    private mutating func poseEnsemble(_ cle: String, _ valeurs: Set<String>) {
        let triees = valeurs.sorted { $0.utf16.lexicographicallyPrecedes($1.utf16) }
        brut[cle] = .tableau(triees.map { JSON.chaine($0) })
    }

    // MARK: Les heures de rappel

    /// Tri, déduplication, et rejet de ce qui ne tombe pas dans la journée.
    private static func normaliseHeures(_ heures: [Int]) -> [Int] {
        var vues = Set<Int>()
        var gardees: [Int] = []
        for heure in heures where heure >= 0 && heure < 24 * 60 {
            if vues.insert(heure).inserted {
                gardees.append(heure)
            }
        }
        return gardees.sorted()
    }

    /// `split(',')` de Kotlin : les morceaux entre deux virgules, vides compris.
    private static func morceaux(_ texte: String) -> [String] {
        var resultat: [String] = []
        var courant: [UInt16] = []
        for unite in texte.utf16 {
            if unite == 0x2C {
                resultat.append(Unites.texte(courant))
                courant = []
            } else {
                courant.append(unite)
            }
        }
        resultat.append(Unites.texte(courant))
        return resultat
    }

    /// `String.toIntOrNull()` de Kotlin : un signe ASCII facultatif puis des chiffres décimaux, ceux de
    /// toute écriture du plan de base (`Character.digit`) ; nil hors des 32 bits d'un `Int` de Kotlin.
    /// La même règle que DureeSeance, dont l'aide est privée.
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
