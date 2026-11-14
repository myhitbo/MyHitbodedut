import Foundation

/// La halakha du jour (YalkutYosef.kt, 13/10) : une sélection du ילקוט יוסף – קיצור שולחן ערוך du Rav
/// Yitzhak Yosef (`yalkut_yosef.json`, construit par tools/yalkut_yosef_construction.py ; droits et
/// source dans l'outil). Jamais le livre entier : une dizaine de pour cent, choisie par période.
///
/// Choix de l'application, pas du livre : deux se'ifim par jour ; le jour de Roch 'Hodech ses lois ;
/// avant et pendant chaque fête les siennes (Pessa'h dès le lendemain de Pourim, Roch Hachana dès
/// Eloul …) ; les vendredis ordinaires le Chabbat ; les autres jours la vie de chaque jour. Dans une
/// période, on avance de deux se'ifim par jour depuis son début ; le Chabbat et les jours ordinaires
/// avancent avec le calendrier, de semaine en semaine ou de jour en jour.
///
/// Le juge : `Tests/Vecteurs/yalkut_yosef.json`, écrit par le code d'Android (tools/vecteurs_ios/VecteursYalkutYosef.kt).
public enum YalkutYosef {

    /// Un se'if : son siman (« סימן א - הלכות השכמת הבוקר »), sa lettre (« ב », parfois vide), son texte.
    public struct Seif: Sendable, Hashable {
        public let siman: String
        public let lettre: String
        public let texte: String

        public init(siman: String, lettre: String, texte: String) {
            self.siman = siman
            self.lettre = lettre
            self.texte = texte
        }
    }

    /// Le livre : les se'ifim de chaque période (« ordinaire », « chabbat », « roch_hodech », « pessah »…).
    public struct Livre: Sendable, Equatable {
        public let periodes: [String: [Seif]]
        /// Les périodes dans l'ordre du fichier, celui où Android les parcourt (`JSONObject.keys()`) :
        /// l'ordre des résultats de la recherche.
        public let ordre: [String]

        /// Sans `ordre`, l'ordre alphabétique des noms : un dictionnaire de Swift n'en garde aucun.
        public init(periodes: [String: [Seif]], ordre: [String]? = nil) {
            self.periodes = periodes
            self.ordre = ordre ?? periodes.keys.sorted()
        }
    }

    public static let parJour = 2

    // MARK: Lecture

    /// Le livre de `yalkut_yosef.json` : `{"periodes": {"ordinaire": [{"s": …, "l": …, "t": …}, …], …}}`.
    /// Lève, comme `JSONObject` d'Android, si le texte n'est pas du JSON ou s'il y manque une clé obligatoire.
    public static func parse(_ json: String) throws -> Livre {
        guard let p = try ObjetJSON(texte: json).objet("periodes") else {
            throw ErreurJSON(position: 0, raison: "« periodes » absent")
        }
        var periodes: [String: [Seif]] = [:]
        for (k, valeur) in p.paires {
            guard case .tableau(let a) = valeur else {
                throw ErreurJSON(position: 0, raison: "période « \(k) » : un tableau attendu")
            }
            var seifs: [Seif] = []
            seifs.reserveCapacity(a.count)
            for element in a {
                guard case .objet(let o) = element else {
                    throw ErreurJSON(position: 0, raison: "période « \(k) » : un objet attendu")
                }
                seifs.append(Seif(siman: try texte(o, "s"), lettre: try texte(o, "l"), texte: try texte(o, "t")))
            }
            periodes[k] = seifs
        }
        return Livre(periodes: periodes, ordre: p.cles)
    }

    /// Le même, depuis les octets du fichier (UTF-8).
    public static func parse(_ donnees: Data) throws -> Livre {
        try parse(String(decoding: donnees, as: UTF8.self))
    }

    /// `getString(cle)` : toute valeur présente se lit en texte ; une clé absente lève.
    private static func texte(_ o: ObjetJSON, _ cle: String) throws -> String {
        guard let valeur = o[cle] else { throw ErreurJSON(position: 0, raison: "« \(cle) » absent") }
        return valeur.commeTexte
    }

    // MARK: La période du jour

    /// La fenêtre de fête d'un jour hébreu, ou nil. `mois` et `jour` comme KosherJava (`CalendrierJuif.Mois`).
    public static func fenetre(mois: Int, jour: Int, embolismique: Bool) -> String? {
        typealias M = CalendrierJuif.Mois
        let adar = embolismique ? M.adarII : M.adar
        if mois == adar && jour <= 15 { return "pourim" }
        if mois == adar || (mois == M.nissan && jour <= 22) { return "pessah" }
        if mois == M.nissan || mois == M.iyar || (mois == M.sivan && jour <= 7) { return "omer" }
        if (mois == M.tamouz && jour >= 17) || (mois == M.av && jour <= 9) { return "bein_hametsarim" }
        if mois == M.eloul || (mois == M.tichri && jour <= 2) { return "eloul" }
        if mois == M.tichri && jour <= 10 { return "kippour" }
        if mois == M.tichri && jour <= 23 { return "soukkot" }
        if (mois == M.kislev && jour >= 15) || (mois == M.tevet && jour <= 3) { return "hanouka" }
        if mois == M.chevat && jour <= 15 { return "tou_bichvat" }
        return nil
    }

    /// (période, rang du jour dans la période) pour une date. La date hébraïque ne dépend pas du lieu :
    /// `israel` garde la forme de YalkutYosef.kt, rien n'en dépend.
    public static func periode(_ date: JourCivil, israel: Bool) -> (periode: String, rang: Int) {
        let calendrier = calendrierHebreu()
        let c = jourHebreu(date, calendrier)
        // isRoshChodesh de KosherJava : le 1er d'un mois autre que Tichri, ou le 30. Le 30 ouvre le Roch
        // 'Hodech du mois suivant, le 1er le poursuit : deux rangs qui se suivent.
        if (c.jour == 1 && c.mois != CalendrierJuif.Mois.tichri) || c.jour == 30 {
            return (periode: "roch_hodech", rang: c.jour == 30 ? (c.mois + 1) * 2 : c.mois * 2 + 1)
        }
        if let f = fenetre(mois: c.mois, jour: c.jour, embolismique: c.embolismique) {
            var n = 0
            while n < 60 && fenetreDu(date.plus(jours: -(n + 1)), calendrier) == f { n += 1 }
            return (periode: f, rang: n)
        }
        // toEpochDay() / 7, puis toInt() : la division tronque vers zéro, le rang tient sur 32 bits.
        let epoque = date.jourJulien - 2_440_588
        if date.jourDeSemaine == 6 { return (periode: "chabbat", rang: Int(Int32(truncatingIfNeeded: epoque / 7))) }
        return (periode: "ordinaire", rang: Int(Int32(truncatingIfNeeded: epoque)))
    }

    /// Les se'ifim d'un rang : `parJour` à la suite, en boucle.
    public static func du(_ seifs: [Seif], rang: Int) -> [Seif] {
        if seifs.isEmpty { return [] }
        // floorMod(rang * PAR_JOUR, taille) ; le rang réduit d'abord, pour qu'aucun produit ne déborde.
        let debut = Kotlin.floorMod((rang % seifs.count) * parJour, seifs.count)
        return (0..<min(parJour, seifs.count)).map { seifs[(debut + $0) % seifs.count] }
    }

    public static func pour(_ livre: Livre, date: JourCivil, israel: Bool) -> [Seif] {
        let p = periode(date, israel: israel)
        return du(livre.periodes[p.periode] ?? [], rang: p.rang)
    }

    // MARK: Le jour hébreu

    /// Ce que `periode` lit d'un jour : le mois (numérotation de KosherJava), le quantième, l'année embolismique.
    private struct JourHebreu {
        let mois: Int
        let jour: Int
        let embolismique: Bool
    }

    /// Le calendrier hébreu de Foundation, en UTC : celui que KosherSwift lit pour `getJewishMonth`,
    /// `getJewishDayOfMonth` et `getJewishYear`. `periode` remonte jusqu'à soixante jours et ne veut de
    /// chacun que ces trois nombres : un seul calendrier pour tous, sans KosherSwift ni son verrou.
    private static func calendrierHebreu() -> Calendar {
        var calendrier = Calendar(identifier: .hebrew)
        calendrier.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        return calendrier
    }

    /// Le jour civil à midi UTC, lu en UTC, comme CalendrierJuif : aucun fuseau ne peut le déplacer.
    private static func jourHebreu(_ date: JourCivil, _ calendrier: Calendar) -> JourHebreu {
        let midi = Date(timeIntervalSince1970: Double(date.jourJulien - 2_440_588) * 86_400 + 43_200)
        let annee = calendrier.component(.year, from: midi)
        // JewishDate.isJewishLeapYear (KosherJava comme KosherSwift) : les années 3, 6, 8, 11, 14, 17 et 19 du cycle.
        let embolismique = (7 * annee + 1) % 19 < 7
        let mois = CalendrierJuif.moisKosherJava(calendrier.component(.month, from: midi), embolismique: embolismique)
        return JourHebreu(mois: mois, jour: calendrier.component(.day, from: midi), embolismique: embolismique)
    }

    private static func fenetreDu(_ date: JourCivil, _ calendrier: Calendar) -> String? {
        let c = jourHebreu(date, calendrier)
        return fenetre(mois: c.mois, jour: c.jour, embolismique: c.embolismique)
    }

    // MARK: La recherche

    /// Les se'ifim de tout le livre (chaque se'if une fois, dans l'ordre des périodes) dont le texte ou
    /// le siman contient `texte`, sans voyelles ni guillemets.
    public static func recherche(_ livre: Livre, texte: String) -> [Seif] {
        let q = nu(texte.rogne)
        if q.count < 2 { return [] }
        var vus = Set<Identite>()
        var trouves: [Seif] = []
        for p in livre.ordre {
            for s in livre.periodes[p] ?? [] {
                // distinct() de Kotlin : le premier de chaque se'if, égal unité pour unité.
                guard vus.insert(Identite(s)).inserted else { continue }
                if Unites.position(de: q, dans: nu(s.texte)) != nil || Unites.position(de: q, dans: nu(s.siman)) != nil {
                    trouves.append(s)
                }
            }
        }
        return trouves
    }

    /// Un se'if comparé comme Kotlin compare une data class : unité UTF-16 pour unité, là où Swift tient
    /// pour égales deux chaînes canoniquement équivalentes (les mêmes signes dans un autre ordre).
    private struct Identite: Hashable {
        let siman: [UInt16]
        let lettre: [UInt16]
        let texte: [UInt16]

        init(_ s: Seif) {
            siman = Array(s.siman.utf16)
            lettre = Array(s.lettre.utf16)
            texte = Array(s.texte.utf16)
        }
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

    // MARK: La carte

    /// « ילקוט יוסף · סימן א - הלכות השכמת הבוקר · סעיף ב »
    public static func source(_ s: Seif) -> String {
        var parties = ["ילקוט יוסף", s.siman]
        if !s.lettre.isEmpty { parties.append("סעיף \(s.lettre)") }
        return parties.joined(separator: " · ")
    }

    /// Les halakhot du jour en une seule carte (13/10) : le siman une fois s'il est commun.
    public static func titreCarte(_ seifs: [Seif]) -> String {
        if let premier = seifs.first, simanimDistincts(seifs) == 1 { return "ילקוט יוסף · \(premier.siman)" }
        return "ילקוט יוסף"
    }

    /// Chaque se'if sous sa lettre (et son siman, s'ils diffèrent).
    public static func texteCarte(_ seifs: [Seif]) -> String {
        let commun = simanimDistincts(seifs) == 1
        var blocs: [String] = []
        for s in seifs {
            let l = s.lettre.isEmpty ? "" : "\(s.lettre). "
            blocs.append(commun ? l + s.texte : s.siman + "\n" + l + s.texte)
        }
        return blocs.joined(separator: "\n\n")
    }

    /// `seifs.map { it.siman }.distinct().size` : des simanim comparés unité pour unité, comme Kotlin.
    private static func simanimDistincts(_ seifs: [Seif]) -> Int {
        var vus = Set<[UInt16]>()
        for s in seifs { vus.insert(Array(s.siman.utf16)) }
        return vus.count
    }
}
