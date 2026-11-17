import Foundation
import KosherSwift
import Synchronization

/// La halakha du jour, hors ligne (Halakha.kt, demande du 11/10) : le Ben Ish 'Haï, Halakhot, en
/// hébreu (`ben_ish_hai.json`, construit par tools/ben_ish_hai_construction.py depuis l'export Sefaria
/// de Wikisource, domaine public). Le texte de halachayomit.co.il n'est pas repris (tous droits
/// réservés) : l'écran garde le lien vers le site.
///
/// Le livre suit la paracha de la semaine. Choix de l'application, pas une règle du livre : la section
/// de la paracha du Chabbat qui vient est partagée en sept, du dimanche au Chabbat ; la première année
/// du livre les années hébraïques impaires (5787 …), la deuxième les paires, l'autre année quand la
/// section manque ; les huit jours de 'Hanouka, la section de 'Hanouka partagée en huit.
///
/// Le juge : `Tests/Vecteurs/halakha.json`, écrit par le code d'Android (tools/vecteurs_ios/VecteursHalakha.kt).
public enum Halakha {

    /// Une section du livre : son titre hébreu et ses halakhot, dans l'ordre.
    public struct Section: Sendable, Hashable {
        public let he: String
        public let halakhot: [String]

        public init(he: String, halakhot: [String]) {
            self.he = he
            self.halakhot = halakhot
        }
    }

    /// Le livre : ses deux années (« 1 », « 2 ») et, pour chacune, la section de chaque paracha par son
    /// nom de KosherJava (« BERESHIS », « TAZRIA_METZORA »…) ; la section de 'Hanouka à part.
    public struct Livre: Sendable, Equatable {
        public let annees: [String: [String: Section]]
        public let hanouka: Section?
        /// Les parachiot de chaque année dans l'ordre du fichier, celui où Android les parcourt
        /// (`JSONObject.keys()`) : l'ordre des résultats de la recherche.
        public let parachiot: [String: [String]]

        /// Sans `parachiot`, l'ordre alphabétique des noms : un dictionnaire de Swift n'en garde aucun.
        public init(annees: [String: [String: Section]], hanouka: Section?, parachiot: [String: [String]]? = nil) {
            self.annees = annees
            self.hanouka = hanouka
            self.parachiot = parachiot ?? annees.mapValues { $0.keys.sorted() }
        }
    }

    /// Une halakha du jour : le texte, son rang dans la section (1 …), la section, l'année du livre.
    public struct Choisie: Sendable, Hashable {
        public let texte: String
        public let numero: Int
        public let section: String
        public let annee: Int

        public init(texte: String, numero: Int, section: String, annee: Int) {
            self.texte = texte
            self.numero = numero
            self.section = section
            self.annee = annee
        }
    }

    /// Une part de ce que le livre dit pour une paracha (le `Triple` de Kotlin) : la section, l'indice de
    /// sa première halakha retenue, les halakhot retenues.
    public typealias Part = (section: Section, depart: Int, halakhot: [String])

    // MARK: Lecture

    /// Le livre de `ben_ish_hai.json` : `{"annees": {"1": {"BERESHIS": {"he": …, "h": […]}, …}, …}, "hanouka": {…}}`.
    /// Lève, comme `JSONObject` d'Android, si le texte n'est pas du JSON ou s'il y manque une clé obligatoire.
    public static func parse(_ json: String) throws -> Livre {
        let o = try ObjetJSON(texte: json)
        guard let annees = o.objet("annees") else { throw ErreurJSON(position: 0, raison: "« annees » absent") }
        var livre: [String: [String: Section]] = [:]
        var parachiot: [String: [String]] = [:]
        for (a, valeur) in annees.paires {
            guard case .objet(let secs) = valeur else {
                throw ErreurJSON(position: 0, raison: "année « \(a) » : un objet attendu")
            }
            var sections: [String: Section] = [:]
            for (p, s) in secs.paires {
                guard case .objet(let objet) = s else {
                    throw ErreurJSON(position: 0, raison: "section « \(p) » : un objet attendu")
                }
                sections[p] = try section(objet)
            }
            livre[a] = sections
            parachiot[a] = secs.cles
        }
        var hanouka: Section?
        if let h = o.objet("hanouka") { hanouka = try section(h) }
        return Livre(annees: livre, hanouka: hanouka, parachiot: parachiot)
    }

    /// Le même, depuis les octets du fichier (UTF-8).
    public static func parse(_ donnees: Data) throws -> Livre {
        try parse(String(decoding: donnees, as: UTF8.self))
    }

    /// `Section(s.getString("he"), Json.strings(s.getJSONArray("h")))` : toute valeur se lit en texte, comme `getString`.
    private static func section(_ s: ObjetJSON) throws -> Section {
        guard let he = s["he"] else { throw ErreurJSON(position: 0, raison: "« he » absent") }
        guard let h = s.tableau("h") else { throw ErreurJSON(position: 0, raison: "« h » absent") }
        var halakhot: [String] = []
        halakhot.reserveCapacity(h.count)
        for valeur in h { halakhot.append(valeur.commeTexte) }
        return Section(he: he.commeTexte, halakhot: halakhot)
    }

    // MARK: Le choix du jour

    /// Les parachiot jointes de KosherJava et leurs deux parts.
    public static let jointes: [String: [String]] = [
        "VAYAKHEL_PEKUDEI": ["VAYAKHEL", "PEKUDEI"],
        "TAZRIA_METZORA": ["TAZRIA", "METZORA"],
        "ACHREI_MOS_KEDOSHIM": ["ACHREI_MOS", "KEDOSHIM"],
        "BEHAR_BECHUKOSAI": ["BEHAR", "BECHUKOSAI"],
        "CHUKAS_BALAK": ["CHUKAS", "BALAK"],
        "MATOS_MASEI": ["MATOS", "MASEI"],
        "NITZAVIM_VAYEILECH": ["NITZAVIM", "VAYEILECH"],
    ]

    /// Ce que le livre dit pour `parsha` dans une année : (section, indice de départ, halakhot), ou nil.
    public static func sections(_ annee: [String: Section], parsha: String) -> [Part]? {
        if let s = annee[parsha] { return [(section: s, depart: 0, halakhot: s.halakhot)] }
        if let parts = jointes[parsha] {
            let sa = sections(annee, parsha: parts[0])
            let sb = sections(annee, parsha: parts[1])
            if sa == nil && sb == nil { return nil }
            return (sa ?? []) + (sb ?? [])
        }
        // Une paracha lue seule, que le livre traite jointe à sa voisine : sa moitié.
        if let jointe = jointes.first(where: { $0.value.contains(parsha) }) {
            guard let s = annee[jointe.key] else { return nil }
            let milieu = (s.halakhot.count + 1) / 2
            if jointe.value[0] == parsha { return [(section: s, depart: 0, halakhot: Array(s.halakhot.prefix(milieu)))] }
            return [(section: s, depart: milieu, halakhot: Array(s.halakhot.dropFirst(milieu)))]
        }
        return nil
    }

    /// La part du jour `jour` sur `parts` jours : un septième (ou un huitième) ; une section courte, une halakha.
    public static func part<T>(_ items: [T], jour: Int, parts: Int) -> [T] {
        if items.isEmpty { return [] }
        if items.count < parts { return [items[jour % items.count]] }
        return Array(items[(jour * items.count / parts)..<((jour + 1) * items.count / parts)])
    }

    public static func anneeDuLivre(_ anneeHebraique: Int) -> Int {
        anneeHebraique % 2 == 1 ? 1 : 2
    }

    /// Les halakhot du jour : `parsha` du Chabbat qui vient (nom de KosherJava), `jourSemaine` 0 le
    /// dimanche … 6 le Chabbat, `jourHanouka` 1 … 8 ou 0.
    /// Début de la note de l'auteur qui remplace une section sans halakhot (Vayéchev, deuxième année).
    public static let sansHalakhot = "בפרשה זו לא כתבתי"

    /// `jourSemaine` : 0 le dimanche … 6 le Chabbat (sur `parts` jours : 0 … parts − 1).
    public static func choix(_ livre: Livre, parsha: String, jourSemaine: Int, anneeHebraique: Int,
                             jourHanouka: Int = 0, parts: Int = 7) -> [Choisie] {
        if (1...8).contains(jourHanouka), let h = livre.hanouka {
            return part(Array(h.halakhot.indices), jour: jourHanouka - 1, parts: 8)
                .map { Choisie(texte: h.halakhot[$0], numero: $0 + 1, section: h.he, annee: 1) }
        }
        let premiere = anneeDuLivre(anneeHebraique)
        for a in [premiere, 3 - premiere] {
            guard let secs = sections(livre.annees[String(a)] ?? [:], parsha: parsha) else { continue }
            var toutes: [Choisie] = []
            for s in secs {
                for (i, t) in s.halakhot.enumerated() {
                    toutes.append(Choisie(texte: t, numero: s.depart + i + 1, section: s.section.he, annee: a))
                }
            }
            // Ni la note « je n'ai pas écrit de halakhot ici » (Vayéchev, année 2) : l'autre année.
            let utiles = toutes.filter { !$0.texte.commenceParUnites(sansHalakhot) }
            if !utiles.isEmpty { return part(utiles, jour: jourSemaine, parts: parts) }
        }
        return []
    }

    /// Pour une date : la paracha du Chabbat qui vient (le Chabbat même, la sienne), le jour de la semaine, 'Hanouka.
    public static func pour(_ livre: Livre, date: JourCivil, enIsrael: Bool) -> [Choisie] {
        let cal = calendrier(date, enIsrael: enIsrael)
        // Du 15 au 23 Tichri (Soukkot, Hochaana Rabba, Sim'hat Torah) : la section de Vézot haBéra'kha, qui parle de
        // Hochaana Rabba, et non la paracha qui vient (Béréchit) ; partagée sur ces neuf jours.
        if cal.mois == CalendrierJuif.Mois.tichri && (15...23).contains(cal.jour) {
            return choix(livre, parsha: "VZOS_HABERACHA", jourSemaine: cal.jour - 15, anneeHebraique: cal.annee, parts: 9)
        }
        // 0 le dimanche … 6 le Chabbat (`jourDeSemaine` : 1 le dimanche … 7 le samedi).
        let jour = date.jourDeSemaine - 1
        return choix(livre, parsha: cal.parsha, jourSemaine: jour, anneeHebraique: cal.annee,
                     jourHanouka: max(cal.hanouka, 0))
    }

    // MARK: La recherche

    /// La recherche dans tout le livre, sans voyelles ni guillemets : les années dans l'ordre de leur nom,
    /// chacune dans l'ordre du fichier, puis 'Hanouka.
    public static func recherche(_ livre: Livre, texte: String) -> [Choisie] {
        let q = nu(texte.rogne)
        if q.count < 2 { return [] }
        var tout: [Choisie] = []
        for a in livre.annees.keys.sorted(by: { $0.utf16.lexicographicallyPrecedes($1.utf16) }) {
            guard let secs = livre.annees[a] else { continue }
            let annee = Int(a) ?? 0
            for p in livre.parachiot[a] ?? [] {
                guard let s = secs[p] else { continue }
                for (i, t) in s.halakhot.enumerated() {
                    tout.append(Choisie(texte: t, numero: i + 1, section: s.he, annee: annee))
                }
            }
        }
        if let h = livre.hanouka {
            for (i, t) in h.halakhot.enumerated() {
                tout.append(Choisie(texte: t, numero: i + 1, section: h.he, annee: 1))
            }
        }
        return tout.filter { Unites.position(de: q, dans: nu($0.texte)) != nil }
    }

    /// Les deux `Regex` de Kotlin, unité par unité : le maqaf et le paseq deviennent une espace ; les
    /// voyelles et les te'amim (U+0591 à U+05C7), les guillemets droits, le guéresh et le guershayim
    /// disparaissent. Ces caractères sont tous du plan de base : aucune paire de substitution n'est touchée.
    private static func nu(_ t: String) -> [UInt16] {
        var sortie: [UInt16] = []
        sortie.reserveCapacity(t.utf16.count)
        for u in t.utf16 {
            switch u {
            case 0x05BE, 0x05C0: sortie.append(0x20)
            case 0x0591...0x05C7, 0x22, 0x27, 0x05F3, 0x05F4: continue
            default: sortie.append(u)
            }
        }
        return sortie
    }

    // MARK: La source

    /// « בן איש חי · שנה ראשונה · לך לך · אות א׳ » (HalakhaActivity.source).
    public static func source(_ h: Choisie) -> String {
        ["בן איש חי", h.annee == 1 ? "שנה ראשונה" : "שנה שנייה", h.section, "אות \(lettres(h.numero))"]
            .joined(separator: " · ")
    }

    /// `Reference.lettres` (Reference.kt), dont `source` a seul besoin ici : un nombre de 1 à 999 en
    /// lettres hébraïques, « א׳ », « י״ד », 15 et 16 en « ט״ו », « ט״ז » ; les nombres de `inverses`
    /// à l'envers, pour ne pas former un mot de mauvais augure ; hors de 1 … 999, ses chiffres. Chaque
    /// lettre est une unité UTF-16 sans signe qui s'y joigne : compter des caractères compte des unités.
    private static func lettres(_ n: Int) -> String {
        if n <= 0 || n >= 1000 { return String(n) }
        if let inverse = inverses[n] {
            var l = Array(inverse)
            l.insert("״", at: l.count - 1)
            return String(l)
        }
        var b: [Character] = []
        var reste = n
        while reste >= 400 { b.append("ת"); reste -= 400 }
        if reste >= 100 { b.append(lettresCentaines[reste / 100]); reste %= 100 }
        switch reste {
        case 15: b.append(contentsOf: "טו")
        case 16: b.append(contentsOf: "טז")
        default:
            if reste >= 10 { b.append(lettresDizaines[reste / 10]) }
            if reste % 10 > 0 { b.append(lettresUnites[reste % 10]) }
        }
        if b.count == 1 { return String(b) + "׳" }
        b.insert("״", at: b.count - 1)
        return String(b)
    }

    private static let lettresUnites = Array(" אבגדהוזחט")
    private static let lettresDizaines = Array(" יכלמנסעפצ")
    private static let lettresCentaines = Array(" קרש")

    /// רע, רעב, רעד, רעה, רצח, שד, שמד : l'usage les écrit à l'envers.
    private static let inverses: [Int: String] = [
        270: "ער", 272: "ערב", 274: "ערד", 275: "ערה", 298: "רחצ", 304: "דש", 344: "שדמ",
    ]

    // MARK: KosherSwift

    private static let verrou = Mutex(())

    /// Ce que `pour` lit de KosherSwift pour un jour civil : la paracha du Chabbat (`getParshah`, ou en
    /// semaine et le Chabbat qui n'en a pas, `getUpcomingParshah`), l'année hébraïque, le jour de
    /// 'Hanouka (−1 hors de la fête). Le jour civil à midi UTC, lu en UTC, comme CalendrierJuif.
    private static func calendrier(_ date: JourCivil, enIsrael: Bool) -> (parsha: String, annee: Int, hanouka: Int, mois: Int, jour: Int) {
        verrou.withLock { _ in
            let utc = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
            let midi = Date(timeIntervalSince1970: Double(date.jourJulien - 2_440_588) * 86_400 + 43_200)
            let c = JewishCalendar(workingDate: midi, timezone: utc, inIsrael: enIsrael, useModernHolidays: false)
            let chabbat = c.getParshah()
            let parsha = chabbat == .NONE ? c.getUpcomingParshah() : chabbat
            return (parsha: nom(parsha), annee: c.getJewishYear(), hanouka: c.getDayOfChanukah(),
                    mois: CalendrierJuif.moisKosherJava(c.getJewishMonth(), embolismique: c.isJewishLeapYear()),
                    jour: c.getJewishDayOfMonth())
        }
    }

    /// Le nom d'énumération de KosherJava (`Parsha.name`), clé des sections du livre. KosherSwift 1.10.11
    /// garde les mêmes noms, cas pour cas ; la table les écrit en clair pour ne pas dépendre de la
    /// réflexion (`String(describing:)`), et le compilateur y veut chaque cas.
    private static func nom(_ p: JewishCalendar.Parsha) -> String {
        switch p {
        case .NONE: "NONE"
        case .BERESHIS: "BERESHIS"
        case .NOACH: "NOACH"
        case .LECH_LECHA: "LECH_LECHA"
        case .VAYERA: "VAYERA"
        case .CHAYEI_SARA: "CHAYEI_SARA"
        case .TOLDOS: "TOLDOS"
        case .VAYETZEI: "VAYETZEI"
        case .VAYISHLACH: "VAYISHLACH"
        case .VAYESHEV: "VAYESHEV"
        case .MIKETZ: "MIKETZ"
        case .VAYIGASH: "VAYIGASH"
        case .VAYECHI: "VAYECHI"
        case .SHEMOS: "SHEMOS"
        case .VAERA: "VAERA"
        case .BO: "BO"
        case .BESHALACH: "BESHALACH"
        case .YISRO: "YISRO"
        case .MISHPATIM: "MISHPATIM"
        case .TERUMAH: "TERUMAH"
        case .TETZAVEH: "TETZAVEH"
        case .KI_SISA: "KI_SISA"
        case .VAYAKHEL: "VAYAKHEL"
        case .PEKUDEI: "PEKUDEI"
        case .VAYIKRA: "VAYIKRA"
        case .TZAV: "TZAV"
        case .SHMINI: "SHMINI"
        case .TAZRIA: "TAZRIA"
        case .METZORA: "METZORA"
        case .ACHREI_MOS: "ACHREI_MOS"
        case .KEDOSHIM: "KEDOSHIM"
        case .EMOR: "EMOR"
        case .BEHAR: "BEHAR"
        case .BECHUKOSAI: "BECHUKOSAI"
        case .BAMIDBAR: "BAMIDBAR"
        case .NASSO: "NASSO"
        case .BEHAALOSCHA: "BEHAALOSCHA"
        case .SHLACH: "SHLACH"
        case .KORACH: "KORACH"
        case .CHUKAS: "CHUKAS"
        case .BALAK: "BALAK"
        case .PINCHAS: "PINCHAS"
        case .MATOS: "MATOS"
        case .MASEI: "MASEI"
        case .DEVARIM: "DEVARIM"
        case .VAESCHANAN: "VAESCHANAN"
        case .EIKEV: "EIKEV"
        case .REEH: "REEH"
        case .SHOFTIM: "SHOFTIM"
        case .KI_SEITZEI: "KI_SEITZEI"
        case .KI_SAVO: "KI_SAVO"
        case .NITZAVIM: "NITZAVIM"
        case .VAYEILECH: "VAYEILECH"
        case .HAAZINU: "HAAZINU"
        case .VZOS_HABERACHA: "VZOS_HABERACHA"
        case .VAYAKHEL_PEKUDEI: "VAYAKHEL_PEKUDEI"
        case .TAZRIA_METZORA: "TAZRIA_METZORA"
        case .ACHREI_MOS_KEDOSHIM: "ACHREI_MOS_KEDOSHIM"
        case .BEHAR_BECHUKOSAI: "BEHAR_BECHUKOSAI"
        case .CHUKAS_BALAK: "CHUKAS_BALAK"
        case .MATOS_MASEI: "MATOS_MASEI"
        case .NITZAVIM_VAYEILECH: "NITZAVIM_VAYEILECH"
        case .SHKALIM: "SHKALIM"
        case .ZACHOR: "ZACHOR"
        case .PARA: "PARA"
        case .HACHODESH: "HACHODESH"
        case .SHUVA: "SHUVA"
        case .SHIRA: "SHIRA"
        case .HAGADOL: "HAGADOL"
        case .CHAZON: "CHAZON"
        case .NACHAMU: "NACHAMU"
        }
    }
}
