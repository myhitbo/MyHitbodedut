import Foundation

// Ce que l'app dépose pour les trois extensions de Temps d'écran : barriere/etat.json (PORTAGE.md § 3.2).
// L'extension de surveillance a quelques mégaoctets de mémoire, ni calendrier ni catalogue (§ 2.1.9) :
// tout ce dont elle a besoin y est déjà calculé, jours exemptés et textes du bouclier compris. Foundation
// seule. Le décodage est tolérant comme `optInt` d'Android : une clé absente ou d'un autre type prend sa
// valeur par défaut, pour qu'une extension lise l'état écrit par une autre version de l'app.

/// Un instant vu du fuseau du téléphone : l'instant Unix en millisecondes, le jour civil (« AAAA-MM-JJ »)
/// et la minute du jour. Les règles de la barrière comptent à la minute, comme `Store.inWindow`.
public struct Horodatage: Codable, Sendable, Hashable {
    public var millis: Int64
    public var jour: String
    public var minutes: Int

    public init(millis: Int64, jour: String, minutes: Int) {
        self.millis = millis
        self.jour = jour
        self.minutes = minutes
    }

    /// L'instant `millis` vu de `fuseau`, par le décalage du fuseau à cet instant ; ni `Calendar` ni
    /// l'heure qu'il est.
    public init(millis: Int64, fuseau: TimeZone) {
        let instant = Date(timeIntervalSince1970: Double(millis) / 1000)
        let local = millis + Int64(fuseau.secondsFromGMT(for: instant)) * 1000
        let jourUnix = JoursIso.divisionEntiere(local, JoursIso.millisParJour)
        let resteDuJour = local - jourUnix * JoursIso.millisParJour
        self.init(millis: millis, jour: JoursIso.iso(jourUnix: Int(jourUnix)), minutes: Int(resteDuJour / 60_000))
    }
}

/// L'instantané de la barrière, écrit par l'app seule, lu par les extensions.
public struct Etat: Codable, Sendable, Equatable {

    public static let nomFichier = "etat.json"
    public static let versionActuelle = 1

    /// Ce que `fenetreFaite` regarde : les jours faits récents (la veille et le jour même) et l'instant de
    /// la dernière séance close (`seance_faite_a`).
    public struct JourneeValidee: Codable, Sendable, Equatable {
        public var jours: [String]
        public var faitA: Horodatage?

        public init(jours: [String] = [], faitA: Horodatage? = nil) {
            self.jours = jours
            self.faitA = faitA
        }

        /// Les « Je l'ai déjà faite » de la boîte, que l'app n'a pas encore versés au journal : chacun vaut
        /// une séance close à cet instant, comme `Store.addSession(context, 0)` du bouclier d'Android.
        public func avec(_ evenements: [Evenement]) -> JourneeValidee {
            var resultat = self
            for evenement in evenements where evenement.genre == Evenement.Genre.dejaFaite.rawValue {
                let quand = evenement.quand
                if !resultat.jours.contains(quand.jour) { resultat.jours.append(quand.jour) }
                if let deja = resultat.faitA, deja.millis >= quand.millis { continue }
                resultat.faitA = quand
            }
            resultat.jours.sort()
            return resultat
        }

        private enum CodingKeys: String, CodingKey {
            case jours
            case faitA = "fait_a"
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            jours = (try? c.decodeIfPresent([String].self, forKey: .jours)) ?? []
            faitA = try? c.decodeIfPresent(Horodatage.self, forKey: .faitA)
        }
    }

    /// La séance en cours (`session_started_at`, `session_ends_at`, `session_target`).
    public struct Seance: Codable, Sendable, Equatable {
        public var debut: Int64
        /// 0 : une séance sans durée.
        public var fin: Int64
        public var minutes: Int

        public init(debut: Int64, fin: Int64, minutes: Int) {
            self.debut = debut
            self.fin = fin
            self.minutes = minutes
        }

        private enum CodingKeys: String, CodingKey {
            case debut, fin, minutes
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            debut = (try? c.decodeIfPresent(Int64.self, forKey: .debut)) ?? 0
            fin = (try? c.decodeIfPresent(Int64.self, forKey: .fin)) ?? 0
            minutes = (try? c.decodeIfPresent(Int.self, forKey: .minutes)) ?? 0
        }
    }

    /// Les textes du bouclier, déjà dans la langue de l'app (chaînes `blocker_*` de strings.xml) : l'extension
    /// ne charge aucun catalogue (§ 2.1.4).
    public struct Bouclier: Codable, Sendable, Equatable {
        public var question = ""
        public var sousTitre = ""
        public var serie = ""
        public var commencer = ""
        public var autreReponse = ""
        public var dejaFaite = ""
        public var plusTard = ""
        public var seanceTitre = ""
        public var seanceSousTitre = ""
        public var revenir = ""
        public var apercu = ""
        public var fermerApercu = ""
        public var notificationCommencer = ""

        public init() {}

        private enum CodingKeys: String, CodingKey {
            case question
            case sousTitre = "sous_titre"
            case serie
            case commencer
            case autreReponse = "autre_reponse"
            case dejaFaite = "deja_faite"
            case plusTard = "plus_tard"
            case seanceTitre = "seance_titre"
            case seanceSousTitre = "seance_sous_titre"
            case revenir
            case apercu
            case fermerApercu = "fermer_apercu"
            case notificationCommencer = "notification_commencer"
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            func texte(_ cle: CodingKeys) -> String { (try? c.decodeIfPresent(String.self, forKey: cle)) ?? "" }
            question = texte(.question)
            sousTitre = texte(.sousTitre)
            serie = texte(.serie)
            commencer = texte(.commencer)
            autreReponse = texte(.autreReponse)
            dejaFaite = texte(.dejaFaite)
            plusTard = texte(.plusTard)
            seanceTitre = texte(.seanceTitre)
            seanceSousTitre = texte(.seanceSousTitre)
            revenir = texte(.revenir)
            apercu = texte(.apercu)
            fermerApercu = texte(.fermerApercu)
            notificationCommencer = texte(.notificationCommencer)
        }
    }

    public var version = Etat.versionActuelle
    /// L'instant où l'app l'a écrit.
    public var ecritA: Int64 = 0
    /// Le mode « Je suis avec Hachem » est allumé (`Store.isEnabled`).
    public var enabled = false
    /// La fenêtre, en minutes depuis minuit (`window_start`, `window_end`) ; de nuit si le début suit la fin.
    public var windowStart = 6 * 60
    public var windowEnd = 11 * 60
    /// La durée du report (`snooze_minutes`) et sa fin en millisecondes Unix (`snoozed_until`).
    public var snoozeMinutes = 15
    public var snoozedUntil: Int64 = 0
    /// « Chabbat et Yom Tov » (`pause_shabbat`) : sans lui, ni la liste ni le repli du samedi ne comptent.
    public var chabbat = true
    /// Les jours chômés (Chabbat, Yom Tov) de `exemptesDepuis` à `exemptesJusquau` inclus, triés.
    public var joursExemptes: [String] = []
    public var exemptesDepuis = ""
    public var exemptesJusquau = ""
    /// Les dates mises en pause à la main (`paused_dates`), triées.
    public var joursEnPause: [String] = []
    public var journee = JourneeValidee()
    public var seance: Seance?
    public var bouclier = Bouclier()
    /// Les jetons de la sélection : une application, une catégorie ou un site vaut un.
    public var nombreDeJetons = 0

    public init() {}

    /// L'état lu d'un fichier ; nil si ce n'est pas un objet JSON.
    public static func lire(_ donnees: Data) -> Etat? {
        try? JSONDecoder().decode(Etat.self, from: donnees)
    }

    /// Le fichier, clés triées : deux écritures du même état donnent les mêmes octets.
    public func donnees() throws -> Data {
        let encodeur = JSONEncoder()
        encodeur.outputFormatting = [.sortedKeys]
        return try encodeur.encode(self)
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case ecritA = "ecrit_a"
        case enabled
        case windowStart = "window_start"
        case windowEnd = "window_end"
        case snoozeMinutes = "snooze_minutes"
        case snoozedUntil = "snoozed_until"
        case chabbat
        case joursExemptes = "jours_exemptes"
        case exemptesDepuis = "exemptes_depuis"
        case exemptesJusquau = "exemptes_jusquau"
        case joursEnPause = "jours_en_pause"
        case journee
        case seance
        case bouclier
        case nombreDeJetons = "nombre_de_jetons"
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaut = Etat()
        version = (try? c.decodeIfPresent(Int.self, forKey: .version)) ?? defaut.version
        ecritA = (try? c.decodeIfPresent(Int64.self, forKey: .ecritA)) ?? defaut.ecritA
        enabled = (try? c.decodeIfPresent(Bool.self, forKey: .enabled)) ?? defaut.enabled
        windowStart = (try? c.decodeIfPresent(Int.self, forKey: .windowStart)) ?? defaut.windowStart
        windowEnd = (try? c.decodeIfPresent(Int.self, forKey: .windowEnd)) ?? defaut.windowEnd
        snoozeMinutes = (try? c.decodeIfPresent(Int.self, forKey: .snoozeMinutes)) ?? defaut.snoozeMinutes
        snoozedUntil = (try? c.decodeIfPresent(Int64.self, forKey: .snoozedUntil)) ?? defaut.snoozedUntil
        chabbat = (try? c.decodeIfPresent(Bool.self, forKey: .chabbat)) ?? defaut.chabbat
        joursExemptes = (try? c.decodeIfPresent([String].self, forKey: .joursExemptes)) ?? defaut.joursExemptes
        exemptesDepuis = (try? c.decodeIfPresent(String.self, forKey: .exemptesDepuis)) ?? defaut.exemptesDepuis
        exemptesJusquau = (try? c.decodeIfPresent(String.self, forKey: .exemptesJusquau)) ?? defaut.exemptesJusquau
        joursEnPause = (try? c.decodeIfPresent([String].self, forKey: .joursEnPause)) ?? defaut.joursEnPause
        journee = (try? c.decodeIfPresent(JourneeValidee.self, forKey: .journee)) ?? defaut.journee
        seance = try? c.decodeIfPresent(Seance.self, forKey: .seance)
        bouclier = (try? c.decodeIfPresent(Bouclier.self, forKey: .bouclier)) ?? defaut.bouclier
        nombreDeJetons = (try? c.decodeIfPresent(Int.self, forKey: .nombreDeJetons)) ?? defaut.nombreDeJetons
    }
}

/// Les jours civils écrits « AAAA-MM-JJ », comptés en jours depuis le 1er janvier 1970 (l'algorithme
/// `days_from_civil` de H. Hinnant) : la barrière n'a pas `JourCivil`, qui est dans Coeur.
enum JoursIso {

    static let millisParJour: Int64 = 86_400_000

    /// `Math.floorDiv` sur 64 bits.
    static func divisionEntiere(_ a: Int64, _ b: Int64) -> Int64 {
        let q = a / b
        return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
    }

    private static func divisionEntiere(_ a: Int, _ b: Int) -> Int {
        let q = a / b
        return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
    }

    /// Le nombre de jours depuis le 1er janvier 1970 ; nil si le texte n'est pas une date valide écrite
    /// exactement « AAAA-MM-JJ ».
    static func jourUnix(_ iso: String) -> Int? {
        let unites = Array(iso.utf8)
        guard unites.count == 10, unites[4] == 0x2D, unites[7] == 0x2D else { return nil }
        func nombre(_ debut: Int, _ fin: Int) -> Int? {
            var valeur = 0
            for i in debut..<fin {
                let u = unites[i]
                guard u >= 0x30, u <= 0x39 else { return nil }
                valeur = valeur * 10 + Int(u - 0x30)
            }
            return valeur
        }
        guard let annee = nombre(0, 4), let mois = nombre(5, 7), let jour = nombre(8, 10) else { return nil }
        guard mois >= 1, mois <= 12, jour >= 1, jour <= joursDansLeMois(mois, annee: annee) else { return nil }
        let a = mois <= 2 ? annee - 1 : annee
        let ere = divisionEntiere(a, 400)
        let anneeDeLEre = a - ere * 400
        let jourDeLAnnee = (153 * (mois + (mois > 2 ? -3 : 9)) + 2) / 5 + jour - 1
        let jourDeLEre = anneeDeLEre * 365 + anneeDeLEre / 4 - anneeDeLEre / 100 + jourDeLAnnee
        return ere * 146_097 + jourDeLEre - 719_468
    }

    /// « AAAA-MM-JJ » du jour donné en jours depuis le 1er janvier 1970.
    static func iso(jourUnix: Int) -> String {
        let z = jourUnix + 719_468
        let ere = divisionEntiere(z, 146_097)
        let jourDeLEre = z - ere * 146_097
        let anneeDeLEre = (jourDeLEre - jourDeLEre / 1460 + jourDeLEre / 36_524 - jourDeLEre / 146_096) / 365
        let jourDeLAnnee = jourDeLEre - (365 * anneeDeLEre + anneeDeLEre / 4 - anneeDeLEre / 100)
        let mp = (5 * jourDeLAnnee + 2) / 153
        let jour = jourDeLAnnee - (153 * mp + 2) / 5 + 1
        let mois = mp < 10 ? mp + 3 : mp - 9
        let annee = anneeDeLEre + ere * 400 + (mois <= 2 ? 1 : 0)
        return chiffres(annee, 4) + "-" + chiffres(mois, 2) + "-" + chiffres(jour, 2)
    }

    /// Le jour décalé de `jours` ; nil si `iso` n'est pas une date.
    static func plus(_ iso: String, jours: Int) -> String? {
        guard let n = jourUnix(iso) else { return nil }
        return JoursIso.iso(jourUnix: n + jours)
    }

    /// 1 = dimanche … 7 = samedi, comme `JourCivil.jourDeSemaine` ; nil si `iso` n'est pas une date. Le
    /// 1er janvier 1970 était un jeudi.
    static func jourDeSemaine(_ iso: String) -> Int? {
        guard let n = jourUnix(iso) else { return nil }
        let reste = (n + 4) % 7
        return (reste < 0 ? reste + 7 : reste) + 1
    }

    private static func joursDansLeMois(_ mois: Int, annee: Int) -> Int {
        switch mois {
        case 2: (annee % 4 == 0 && annee % 100 != 0) || annee % 400 == 0 ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    /// Un entier positif écrit sur `largeur` chiffres au moins, complété de zéros.
    private static func chiffres(_ n: Int, _ largeur: Int) -> String {
        var texte = String(n)
        while texte.utf8.count < largeur { texte = "0" + texte }
        return texte
    }
}
