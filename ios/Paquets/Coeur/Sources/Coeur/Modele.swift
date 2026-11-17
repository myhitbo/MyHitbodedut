import Foundation

// Le journal d'Android (Store.kt, JournalPlus.kt) : les journées de pratique, le journal enrichi et
// le prénom, qui vivent sur Android dans le fichier de préférences « myhitbodedut-journal », exclu de
// la sauvegarde automatique (PORTAGE.md § 3.2 et § 3.3).
//
// Le journal lit et écrit la préférence « days » à l'identique : les journées dans l'ordre de leurs
// clés, une journée nouvelle à la fin, `themes` et `note_seule` absents quand ils sont vides ou faux
// (Store.days, Store.writeDays). La préférence « journal_plus » est gardée telle quelle, clés inconnues
// comprises, et chaque écriture n'y touche que le jour écrit (JournalPlus.ecrire). Les coupes (note à
// 4 000, prénom à 40, gratitude à 200) comptent des unités UTF-16, comme `take` de Kotlin ; une coupe
// qui tomberait au milieu d'une paire de substitution la retire entière (Unites.texte).
//
// Restent ailleurs : la reprise du journal d'avant (« done_dates » et « days » dans le fichier des
// réglages), qui n'existe pas sur iOS ; l'instant de la séance (« seance_faite_a ») et le report effacé
// par addSession, qui sont la fenêtre de la barrière ; la notification retirée, qui est un écran.
// Jugé par `Tests/Vecteurs/modele.json` (tools/vecteurs_ios/VecteursModele.kt).

/// Une journée de pratique (Store.DayRecord, sans sa date, qui est sa clé dans le journal).
public struct Journee: Sendable, Equatable {
    /// Le cumul des séances du jour.
    public var minutes: Int
    /// La note laissée après la séance.
    public var note: String
    /// Les sujets des séances de ce jour-là, clés de Theme ; une clé inconnue est gardée.
    public var themes: [String]
    /// Une note laissée un jour sans hitbodedout : gardée, elle ne valide pas la journée (revue du 29/09).
    public var noteSeule: Bool

    public init(minutes: Int, note: String, themes: [String] = [], noteSeule: Bool = false) {
        self.minutes = minutes
        self.note = note
        self.themes = themes
        self.noteSeule = noteSeule
    }

    /// La journée compte : une hitbodedout y a eu lieu ou a été déclarée.
    public var faite: Bool { !noteSeule }
}

/// Le journal enrichi (JournalPlus.kt, 14/10) : l'humeur avant et après la hitbodedout, une gratitude,
/// une chose à travailler, et les minutes du mois. Gardé à part des journées : une journée reste ce
/// qu'elle était, ceci s'y ajoute. Le graphique du mois reviendra avec son écran.
public enum JournalPlus {

    /// L'humeur va de 1 à 5, 0 si elle n'est pas dite ; la gratitude et la chose à travailler
    /// (proposition 5, 19/10) gardent 200 unités UTF-16 au plus.
    public struct Plus: Sendable, Equatable {
        public var avant: Int
        public var apres: Int
        public var gratitude: String
        public var travail: String

        public init(avant: Int = 0, apres: Int = 0, gratitude: String = "", travail: String = "") {
            self.avant = avant
            self.apres = apres
            self.gratitude = gratitude
            self.travail = travail
        }

        public var vide: Bool { avant == 0 && apres == 0 && gratitude.estBlanc && travail.estBlanc }
    }

    /// Les cinq humeurs, de la plus lourde à la plus légère.
    public static let humeurs = ["\u{1F61E}", "\u{1F641}", "\u{1F610}", "\u{1F642}", "\u{1F604}"]

    public static let gratitudeMax = 200

    /// `lire` : le jour `date` de l'objet de la préférence « journal_plus » ; l'humeur ramenée de 0 à 5.
    public static func lire(_ objet: ObjetJSON, date: String) -> Plus {
        guard let o = objet.objet(date) else { return Plus() }
        return Plus(avant: humeurBornee(o.entier("avant", defaut: 0)),
                    apres: humeurBornee(o.entier("apres", defaut: 0)),
                    gratitude: o.texte("gratitude", defaut: "").premieresUnites(gratitudeMax),
                    travail: o.texte("travail", defaut: "").premieresUnites(gratitudeMax))
    }

    /// `ecrire` : un jour vide est retiré ; sinon écrit tel quel, l'humeur sans borne, les textes coupés.
    public static func ecrire(_ objet: inout ObjetJSON, date: String, plus: Plus) {
        if plus.vide {
            objet[date] = nil
            return
        }
        objet[date] = .objet(ObjetJSON([
            ("avant", .entier(Int64(plus.avant))),
            ("apres", .entier(Int64(plus.apres))),
            ("gratitude", .chaine(plus.gratitude.premieresUnites(gratitudeMax))),
            ("travail", .chaine(plus.travail.premieresUnites(gratitudeMax))),
        ]))
    }

    /// « 🙁 → 🙂 · Gratitude » pour la ligne du journal ; vide s'il n'y a rien. L'humeur est isolée de
    /// gauche à droite (U+2066…U+2069) : en hébreu, la flèche pointait d'après vers avant (02/11).
    public static func resume(_ plus: Plus, gratitude: String, travail: String = "", sujets: String = "") -> String {
        var lignes: [String] = []
        if !sujets.estBlanc {
            lignes.append(sujets)
        }
        if plus.avant > 0 || plus.apres > 0 {
            lignes.append("\u{2066}" + humeur(plus.avant) + " \u{2192} " + humeur(plus.apres) + "\u{2069}")
        }
        if !plus.gratitude.estBlanc {
            lignes.append(gratitude + " : " + plus.gratitude)
        }
        if !plus.travail.estBlanc {
            lignes.append(travail + " : " + plus.travail)
        }
        return lignes.joined(separator: "\n")
    }

    /// Les minutes de chaque jour du mois, du 1er au dernier ; 0 sans hitbodedout, et pour une note seule.
    public static func minutesDuMois(_ jours: [JourCivil: Journee], annee: Int, mois: Int) -> [Int] {
        guard mois >= 1 && mois <= 12 else { return [] }
        var minutes: [Int] = []
        for jour in 1...JourCivil.joursDansLeMois(mois, annee: annee) {
            var valeur = 0
            if let date = JourCivil(annee: annee, mois: mois, jour: jour), let journee = jours[date], journee.faite {
                valeur = journee.minutes
            }
            minutes.append(valeur)
        }
        return minutes
    }

    /// `HUMEURS.getOrNull(n - 1) ?: "·"`.
    private static func humeur(_ n: Int) -> String {
        n >= 1 && n <= humeurs.count ? humeurs[n - 1] : "\u{00B7}"
    }

    private static func humeurBornee(_ n: Int) -> Int {
        min(max(n, 0), 5)
    }
}

/// Le journal : les journées, le journal enrichi et le prénom (le fichier « myhitbodedut-journal »).
public struct Journal: Sendable, Equatable {

    /// Au-delà, une note n'est plus une note (Store.NOTE_MAX).
    public static let noteMax = 4000
    /// Le prénom garde 40 unités UTF-16 au plus (Store.setFirstName).
    public static let prenomMax = 40

    /// Les journées, par jour.
    public private(set) var jours: [JourCivil: Journee] = [:]
    /// Les jours dans l'ordre de la préférence « days » : celui de la lecture, puis de l'ajout.
    public private(set) var dates: [JourCivil] = []
    /// La préférence « journal_plus », telle quelle.
    public private(set) var plusBrut = ObjetJSON()
    /// Le prénom tel qu'il est gardé (déjà rogné et coupé par `setFirstName`).
    public private(set) var prenom = ""
    /// La copie d'un journal illisible (« days_corrompu »), gardée pour qu'il ne soit pas écrasé en silence.
    public private(set) var corrompu: String?

    public init() {}

    /// `Store.days` et `JournalPlus.tout` : les préférences « days » et « journal_plus » telles qu'Android
    /// les écrit. Une clé qui n'est pas une vraie date, une valeur qui n'est pas un objet sont ignorées ;
    /// un texte illisible laisse un journal vide et sa copie dans `corrompu`, si aucune n'y est déjà.
    public init(daysTexte: String?, journalPlusTexte: String? = nil, prenom: String = "", corrompu: String? = nil) {
        self.prenom = prenom
        self.corrompu = corrompu
        if let daysTexte {
            if let racine = try? ObjetJSON(texte: daysTexte) {
                lireJours(racine)
            } else if self.corrompu == nil {
                self.corrompu = daysTexte
            }
        }
        if let journalPlusTexte, let objet = try? ObjetJSON(texte: journalPlusTexte) {
            plusBrut = objet
        }
    }

    /// Les mêmes préférences, déjà lues en objets JSON.
    public init(days: ObjetJSON, journalPlus: ObjetJSON = ObjetJSON(), prenom: String = "") {
        self.prenom = prenom
        plusBrut = journalPlus
        lireJours(days)
    }

    // MARK: Les journées

    /// Une journée : la poser ajoute le jour à la fin s'il est nouveau, nil le retire.
    public subscript(date: JourCivil) -> Journee? {
        get {
            jours[date]
        }
        set {
            if let journee = newValue {
                if jours.updateValue(journee, forKey: date) == nil {
                    dates.append(date)
                }
            } else if jours.removeValue(forKey: date) != nil {
                dates.removeAll { $0 == date }
            }
        }
    }

    /// `Store.record`.
    public func record(_ date: JourCivil) -> Journee? {
        jours[date]
    }

    /// `Store.isDone` : la journée existe et compte.
    public func isDone(_ date: JourCivil) -> Bool {
        jours[date]?.faite == true
    }

    /// Les journées qui comptent : faites ou déclarées, pas les notes seules.
    public var joursFaits: Set<JourCivil> {
        var faits = Set<JourCivil>()
        for (date, journee) in jours where journee.faite {
            faits.insert(date)
        }
        return faits
    }

    /// Le total des minutes, sur 32 bits comme `sumOf` de Kotlin.
    public var totalMinutes: Int {
        var total: Int32 = 0
        for journee in jours.values {
            total = total &+ Int32(truncatingIfNeeded: journee.minutes)
        }
        return Int(total)
    }

    /// Au moins une journée faite, un jour : il y a une série à perdre.
    public var aDejaPratique: Bool {
        for journee in jours.values where journee.faite {
            return true
        }
        return false
    }

    /// `Store.addSession` : valide la journée ; les minutes s'ajoutent (sur 32 bits, une séance négative
    /// compte zéro), la note donnée remplace la note du jour, le sujet s'ajoute à ceux du jour.
    /// `date` est le jour où la hitbodedout a commencé (revue du 29/09).
    public mutating func addSession(minutes: Int, note: String? = nil, theme: String? = nil, date: JourCivil) {
        let existante = jours[date]
        let somme = Int32(truncatingIfNeeded: (existante?.minutes ?? 0) &+ max(minutes, 0))
        var themes = existante?.themes ?? []
        if let theme {
            themes.append(theme)
        }
        self[date] = Journee(minutes: Int(somme), note: note ?? existante?.note ?? "", themes: themes, noteSeule: false)
    }

    /// `Store.setNote` : la note d'un jour. Sur un jour sans hitbodedout, elle ne le valide pas ; une note
    /// seule qu'on efface retire la ligne ; une note blanche sur un jour vide n'écrit rien.
    public mutating func setNote(date: JourCivil, note: String) {
        if var existante = jours[date] {
            if existante.noteSeule && note.estBlanc {
                self[date] = nil
            } else {
                existante.note = note.premieresUnites(Journal.noteMax)
                self[date] = existante
            }
        } else if !note.estBlanc {
            self[date] = Journee(minutes: 0, note: note.premieresUnites(Journal.noteMax), themes: [], noteSeule: true)
        }
    }

    /// `Store.unmarkToday` : la journée d'aujourd'hui est retirée.
    public mutating func unmarkToday(_ aujourdhui: JourCivil) {
        self[aujourdhui] = nil
    }

    // MARK: La préférence « days »

    /// L'objet que `Store.writeDays` écrit : les journées dans l'ordre de `dates`.
    public var days: ObjetJSON {
        var racine = ObjetJSON()
        for date in dates {
            if let journee = jours[date] {
                racine[date.iso] = .objet(Journal.objet(journee))
            }
        }
        return racine
    }

    /// Le texte de la préférence « days », écrit comme `JSONObject.toString()` d'Android.
    public var daysTexte: String {
        days.texte()
    }

    /// `Store.dateValide` : la date si la clé est une vraie date ISO (2026-09-29) qui se réécrit à
    /// l'identique, de 2000 à 2100, sinon nil. Comme `java.time`, les années hors de 0000…9999 portent leur
    /// signe (« -0001-01-01 », « +10000-01-01 ») ; elles sont hors des bornes.
    public static func dateValide(_ cle: String) -> JourCivil? {
        let octets = Array(cle.utf8)
        var i = 0
        var negatif = false
        if i < octets.count && (octets[i] == 0x2B || octets[i] == 0x2D) {
            negatif = octets[i] == 0x2D
            i += 1
        }
        let debutAnnee = i
        var annee = 0
        while i < octets.count && octets[i] >= 0x30 && octets[i] <= 0x39 {
            if i - debutAnnee >= 10 { return nil }
            annee = annee * 10 + Int(octets[i] - 0x30)
            i += 1
        }
        guard i - debutAnnee >= 4, octets.count == i + 6, octets[i] == 0x2D, octets[i + 3] == 0x2D,
              let mois = deuxChiffres(octets[i + 1], octets[i + 2]),
              let jour = deuxChiffres(octets[i + 4], octets[i + 5]),
              let date = JourCivil(annee: negatif ? -annee : annee, mois: mois, jour: jour),
              date.iso.egalUnites(cle),
              // Ni avant 2000 ni après 2100, comme le web (revue du 15/11) : « 0000-01-01 » importé faisait
              // planter l'accueil d'Android (JewishCalendar refuse l'ère avant J.-C.).
              (2000...2100).contains(date.annee) else { return nil }
        return date
    }

    // MARK: Le journal enrichi

    /// Les jours du journal enrichi dont la clé est une vraie date, lus comme `JournalPlus.lire`.
    public var plus: [JourCivil: JournalPlus.Plus] {
        var resultat: [JourCivil: JournalPlus.Plus] = [:]
        for cle in plusBrut.cles {
            if plusBrut.objet(cle) != nil, let date = Journal.dateValide(cle) {
                resultat[date] = JournalPlus.lire(plusBrut, date: cle)
            }
        }
        return resultat
    }

    /// `JournalPlus.lire`.
    public func lirePlus(_ date: JourCivil) -> JournalPlus.Plus {
        JournalPlus.lire(plusBrut, date: date.iso)
    }

    /// `JournalPlus.ecrire` : un jour vide est retiré, les autres jours restent tels quels.
    public mutating func ecrirePlus(_ jour: JournalPlus.Plus, pour date: JourCivil) {
        JournalPlus.ecrire(&plusBrut, date: date.iso, plus: jour)
    }

    /// Remplace l'objet de la préférence « journal_plus » d'un coup (l'import, qui écrit tout ensemble).
    public mutating func setPlusBrut(_ objet: ObjetJSON) {
        plusBrut = objet
    }

    /// Le texte de la préférence « journal_plus ».
    public var journalPlusTexte: String {
        plusBrut.texte()
    }

    // MARK: Le prénom

    /// `Store.firstName` : vide par défaut, et vide est une réponse.
    public var firstName: String {
        prenom.rogne
    }

    /// `Store.setFirstName` : sans les blancs des bouts, 40 unités UTF-16 au plus.
    public mutating func setFirstName(_ name: String) {
        prenom = name.rogne.premieresUnites(Journal.prenomMax)
    }

    // MARK: Lecture et écriture d'une journée

    private mutating func lireJours(_ racine: ObjetJSON) {
        for (cle, valeur) in racine.paires {
            guard case .objet(let entree) = valeur, let date = Journal.dateValide(cle) else { continue }
            self[date] = Journee(minutes: entree.entier("minutes", defaut: 0),
                                 note: entree.texte("note", defaut: ""),
                                 themes: Journal.lireThemes(entree),
                                 noteSeule: entree.booleen("note_seule", defaut: false))
        }
    }

    /// `Store.readThemes` : chaque élément lu comme `optString`, les blancs retirés ; rien sans tableau. Bornés
    /// comme le web (revue du 15/11) : 20 sujets de 40 unités UTF-16 au plus.
    static func lireThemes(_ entree: ObjetJSON) -> [String] {
        guard let elements = entree.tableau("themes") else { return [] }
        var themes: [String] = []
        for rang in elements.indices where themes.count < 20 {
            let theme = elements.texte(rang)
            if !theme.estBlanc && theme.utf16.count <= 40 {
                themes.append(theme)
            }
        }
        return themes
    }

    /// `Store.toJson` : une clé absente vaut mieux qu'un tableau vide, le journal des journées sans
    /// sujet reste exactement ce qu'il était.
    private static func objet(_ journee: Journee) -> ObjetJSON {
        var o = ObjetJSON([("minutes", .entier(Int64(journee.minutes))), ("note", .chaine(journee.note))])
        if !journee.themes.isEmpty {
            o["themes"] = .tableau(journee.themes.map { JSON.chaine($0) })
        }
        if journee.noteSeule {
            o["note_seule"] = .booleen(true)
        }
        return o
    }

    private static func deuxChiffres(_ a: UInt8, _ b: UInt8) -> Int? {
        guard a >= 0x30 && a <= 0x39 && b >= 0x30 && b <= 0x39 else { return nil }
        return Int(a - 0x30) * 10 + Int(b - 0x30)
    }
}
