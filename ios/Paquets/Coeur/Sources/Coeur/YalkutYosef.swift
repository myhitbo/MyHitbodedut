import Foundation

/// La halakha courte du jour (YalkutYosef.kt, 13/10) : une sélection du ילקוט יוסף – קיצור שולחן ערוך du
/// Rav Yitzhak Yosef (`yalkut_yosef.json`, tools/yalkut_yosef_construction.py ; droits et source dans
/// l'outil). Jamais le livre entier : une dizaine de pour cent, choisie par période.
///
/// Choix de l'application, pas du livre : deux se'ifim par jour ; le jour de Roch 'Hodech ses lois ;
/// avant et pendant chaque fête les siennes (Pessa'h dès le lendemain de Pourim, Roch Hachana dès
/// Eloul …) ; les vendredis ordinaires le Chabbat ; les autres jours la vie de chaque jour. Dans une
/// période, on avance de deux se'ifim par jour depuis son début ; le Chabbat et les jours ordinaires
/// avancent avec le calendrier, de semaine en semaine ou de jour en jour.
public enum YalkutYosef {

    public struct Seif: Sendable, Equatable {
        public let siman: String
        public let lettre: String
        public let texte: String

        public init(siman: String, lettre: String, texte: String) {
            self.siman = siman
            self.lettre = lettre
            self.texte = texte
        }
    }

    public struct Livre: Sendable {
        public let periodes: TableOrdonnee<[Seif]>
        /// Les se'ifim de toutes les périodes, chacun une fois (`distinct`), avec leur forme sans voyelles.
        let recherchable: [(seif: Seif, texte: String, siman: String)]

        public init(periodes: TableOrdonnee<[Seif]>) {
            self.periodes = periodes
            var vus = Set<[UInt16]>()
            var tous: [(seif: Seif, texte: String, siman: String)] = []
            for s in periodes.paires.flatMap({ $0.valeur }) {
                // L'égalité de Kotlin, unité UTF-16 par unité : pas l'équivalence canonique de Swift.
                let cle = Array(s.siman.utf16) + [0] + Array(s.lettre.utf16) + [0] + Array(s.texte.utf16)
                if vus.insert(cle).inserted { tous.append((seif: s, texte: Halakha.nu(s.texte), siman: Halakha.nu(s.siman))) }
            }
            recherchable = tous
        }
    }

    public static let parJour = 2

    public static func parse(_ json: String) throws -> Livre {
        let p = try ObjetJSON(texte: json).objet("periodes") ?? ObjetJSON()
        return Livre(periodes: TableOrdonnee(p.cles.map { k in
            (k, p.objets(k).map { Seif(siman: $0.texte("s"), lettre: $0.texte("l"), texte: $0.texte("t")) })
        }))
    }

    private typealias M = CalendrierJuif.Mois

    /// La fenêtre de fête d'un jour hébreu, ou nil ; `mois` et `jour` comme KosherJava.
    public static func fenetre(mois: Int, jour: Int, embolismique: Bool) -> String? {
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

    private static func fenetreDu(_ date: JourCivil) -> String? {
        let d = CalendrierJuif.dateJuive(date)
        return fenetre(mois: d.mois, jour: d.jour, embolismique: d.embolismique)
    }

    /// (période, rang du jour dans la période) pour une date. `israel` ne change ni le mois ni le jour.
    public static func periode(_ date: JourCivil, israel: Bool) -> (periode: String, rang: Int) {
        let d = CalendrierJuif.dateJuive(date)
        // Le 30 ouvre le Roch 'Hodech du mois suivant, le 1er le poursuit : deux rangs qui se suivent.
        if d.rochHodech { return ("roch_hodech", d.jour == 30 ? (d.mois + 1) * 2 : d.mois * 2 + 1) }
        if let f = fenetre(mois: d.mois, jour: d.jour, embolismique: d.embolismique) {
            var n = 0
            while n < 60 && fenetreDu(date.plus(jours: -(n + 1))) == f { n += 1 }
            return (f, n)
        }
        let jourEpoque = date.jourJulien - 2_440_588
        return date.jourDeSemaine == 6 ? ("chabbat", jourEpoque / 7) : ("ordinaire", jourEpoque)
    }

    /// Les se'ifim d'un rang : `parJour` à la suite, en boucle.
    public static func du(_ seifs: [Seif], rang: Int) -> [Seif] {
        if seifs.isEmpty { return [] }
        let debut = Kotlin.floorMod(rang * parJour, seifs.count)
        return (0..<min(parJour, seifs.count)).map { seifs[(debut + $0) % seifs.count] }
    }

    public static func pour(_ livre: Livre, _ date: JourCivil, israel: Bool) -> [Seif] {
        let (p, rang) = periode(date, israel: israel)
        return du(livre.periodes[p] ?? [], rang: rang)
    }

    public static func recherche(_ livre: Livre, _ texte: String) -> [Seif] {
        let q = Halakha.nu(texte.rogne)
        if q.utf16.count < 2 { return [] }
        return livre.recherchable.filter { $0.texte.contientUnites(q) || $0.siman.contientUnites(q) }.map { $0.seif }
    }

    /// « ילקוט יוסף · סימן א - הלכות השכמת הבוקר · סעיף ב »
    public static func source(_ s: Seif) -> String {
        (["ילקוט יוסף", s.siman] + (s.lettre.isEmpty ? [] : ["סעיף \(s.lettre)"])).joined(separator: " · ")
    }

    private static func simanUnique(_ seifs: [Seif]) -> Bool {
        Set(seifs.map { Array($0.siman.utf16) }).count == 1
    }

    /// Les halakhot du jour en une seule carte (13/10) : le siman une fois s'il est commun.
    public static func titreCarte(_ seifs: [Seif]) -> String {
        guard simanUnique(seifs), let premier = seifs.first else { return "ילקוט יוסף" }
        return "ילקוט יוסף · \(premier.siman)"
    }

    /// Chaque se'if sous sa lettre (et son siman, s'ils diffèrent).
    public static func texteCarte(_ seifs: [Seif]) -> String {
        let commun = simanUnique(seifs)
        return seifs.map { s in
            let l = s.lettre.isEmpty ? "" : "\(s.lettre). "
            return commun ? l + s.texte : "\(s.siman)\n\(l)\(s.texte)"
        }.joined(separator: "\n\n")
    }
}
