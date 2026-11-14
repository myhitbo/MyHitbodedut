import Foundation

/// La halakha du jour, hors ligne (Halakha.kt, demande du 11/10) : le Ben Ish 'Haï, Halakhot, en hébreu
/// (`ben_ish_hai.json`, tools/ben_ish_hai_construction.py, domaine public). Le livre suit la paracha de
/// la semaine. Choix de l'application, pas une règle du livre : la section de la paracha du Chabbat qui
/// vient est partagée en sept, du dimanche au Chabbat ; la première année du livre les années hébraïques
/// impaires (5787 …), la deuxième les paires, l'autre année quand la section manque ; les huit jours de
/// 'Hanouka, la section de 'Hanouka partagée en huit.
public enum Halakha {

    public struct Section: Sendable, Equatable {
        public let he: String
        public let halakhot: [String]

        public init(he: String, halakhot: [String]) {
            self.he = he
            self.halakhot = halakhot
        }
    }

    /// Une halakha du jour : le texte, son rang dans la section (1 …), la section, l'année du livre.
    public struct Choisie: Sendable, Equatable {
        public let texte: String
        public let numero: Int
        public let section: String
        public let annee: Int
    }

    /// Une part de section : la section, le rang de sa première halakha (dès 0), ses halakhot.
    public struct Part: Sendable, Equatable {
        public let section: Section
        public let depart: Int
        public let halakhot: [String]
    }

    public struct Livre: Sendable {
        /// Les années du livre (« 1 », « 2 ») et, dans chacune, les sections par paracha (nom de KosherJava).
        public let annees: TableOrdonnee<TableOrdonnee<Section>>
        public let hanouka: Section?
        /// Tout le livre dans l'ordre de la recherche, chaque halakha avec sa forme sans voyelles.
        let recherchable: [(choisie: Choisie, nu: String)]

        public init(annees: TableOrdonnee<TableOrdonnee<Section>>, hanouka: Section?) {
            self.annees = annees
            self.hanouka = hanouka
            let ordre = annees.cles.sorted { Array($0.utf16).lexicographicallyPrecedes(Array($1.utf16)) }
            var tout: [Choisie] = []
            for a in ordre {
                for s in annees[a]?.paires.map({ $0.valeur }) ?? [] {
                    for (i, t) in s.halakhot.enumerated() { tout.append(Choisie(texte: t, numero: i + 1, section: s.he, annee: Int(a) ?? 0)) }
                }
            }
            if let h = hanouka {
                for (i, t) in h.halakhot.enumerated() { tout.append(Choisie(texte: t, numero: i + 1, section: h.he, annee: 1)) }
            }
            recherchable = tout.map { (choisie: $0, nu: Halakha.nu($0.texte)) }
        }
    }

    public static func parse(_ json: String) throws -> Livre {
        let o = try ObjetJSON(texte: json)
        func section(_ s: ObjetJSON) -> Section { Section(he: s.texte("he"), halakhot: s.textes("h")) }
        let annees = o.objet("annees") ?? ObjetJSON()
        return Livre(
            annees: TableOrdonnee(annees.cles.map { a -> (String, TableOrdonnee<Section>) in
                let secs = annees.objet(a) ?? ObjetJSON()
                return (a, TableOrdonnee(secs.cles.map { ($0, section(secs.objet($0) ?? ObjetJSON())) }))
            }),
            hanouka: o.objet("hanouka").map(section))
    }

    /// Les parachiot jointes de KosherJava et leurs deux parts.
    public static let jointes: [(jointe: String, parts: [String])] = [
        ("VAYAKHEL_PEKUDEI", ["VAYAKHEL", "PEKUDEI"]),
        ("TAZRIA_METZORA", ["TAZRIA", "METZORA"]),
        ("ACHREI_MOS_KEDOSHIM", ["ACHREI_MOS", "KEDOSHIM"]),
        ("BEHAR_BECHUKOSAI", ["BEHAR", "BECHUKOSAI"]),
        ("CHUKAS_BALAK", ["CHUKAS", "BALAK"]),
        ("MATOS_MASEI", ["MATOS", "MASEI"]),
        ("NITZAVIM_VAYEILECH", ["NITZAVIM", "VAYEILECH"]),
    ]

    /// Ce que le livre dit pour `parsha` dans une année, ou nil.
    public static func sections(_ annee: TableOrdonnee<Section>, _ parsha: String) -> [Part]? {
        if let s = annee[parsha] { return [Part(section: s, depart: 0, halakhot: s.halakhot)] }
        if let parts = jointes.first(where: { $0.jointe == parsha })?.parts {
            let sa = sections(annee, parts[0])
            let sb = sections(annee, parts[1])
            return sa == nil && sb == nil ? nil : (sa ?? []) + (sb ?? [])
        }
        // Une paracha lue seule, que le livre traite jointe à sa voisine : sa moitié.
        if let j = jointes.first(where: { $0.parts.contains(parsha) }) {
            guard let s = annee[j.jointe] else { return nil }
            let milieu = (s.halakhot.count + 1) / 2
            return [j.parts[0] == parsha ? Part(section: s, depart: 0, halakhot: Array(s.halakhot.prefix(milieu)))
                                         : Part(section: s, depart: milieu, halakhot: Array(s.halakhot.dropFirst(milieu)))]
        }
        return nil
    }

    /// La part du jour `jour` sur `parts` jours : un septième (ou un huitième) ; d'une section courte, une halakha.
    public static func part<T>(_ items: [T], _ jour: Int, _ parts: Int) -> [T] {
        if items.isEmpty { return [] }
        if items.count < parts { return [items[jour % items.count]] }
        return Array(items[(jour * items.count / parts)..<((jour + 1) * items.count / parts)])
    }

    public static func anneeDuLivre(_ anneeHebraique: Int) -> Int { anneeHebraique % 2 == 1 ? 1 : 2 }

    /// Les halakhot du jour : `parsha` du Chabbat qui vient (nom de KosherJava), `jourSemaine` 0 le
    /// dimanche … 6 le Chabbat, `jourHanouka` 1 … 8 ou 0.
    public static func choix(_ livre: Livre, parsha: String, jourSemaine: Int, anneeHebraique: Int, jourHanouka: Int = 0) -> [Choisie] {
        if (1...8).contains(jourHanouka), let h = livre.hanouka {
            return part(Array(h.halakhot.indices), jourHanouka - 1, 8)
                .map { Choisie(texte: h.halakhot[$0], numero: $0 + 1, section: h.he, annee: 1) }
        }
        let premiere = anneeDuLivre(anneeHebraique)
        for a in [premiere, 3 - premiere] {
            guard let secs = sections(livre.annees[String(a)] ?? TableOrdonnee([]), parsha) else { continue }
            let toutes = secs.flatMap { p in
                p.halakhot.enumerated().map { i, t in Choisie(texte: t, numero: p.depart + i + 1, section: p.section.he, annee: a) }
            }
            if !toutes.isEmpty { return part(toutes, jourSemaine, 7) }
        }
        return []
    }

    /// Pour une date : la paracha du Chabbat qui vient (le Chabbat même, la sienne), le jour de la
    /// semaine, 'Hanouka.
    public static func pour(_ livre: Livre, _ date: JourCivil, enIsrael: Bool) -> [Choisie] {
        let semaine = date.jourDeSemaine  // 1 = dimanche … 7 = samedi
        return choix(livre, parsha: CalendrierJuif.parachaAVenir(date, enIsrael: enIsrael), jourSemaine: semaine - 1,
                     anneeHebraique: CalendrierJuif.dateJuive(date).annee,
                     jourHanouka: max(CalendrierJuif.jourHanouka(date), 0))
    }

    private static let separateurs = ExpressionReguliere("[\\u05BE\\u05C0]")
    private static let voyelles = ExpressionReguliere("[\\u0591-\\u05C7\"'\\u05F4\\u05F3]")

    /// Sans voyelles ni guillemets, le maqaf et le paseq pris pour des espaces.
    static func nu(_ t: String) -> String { voyelles.remplace(separateurs.remplace(t, par: " "), par: "") }

    /// La recherche dans tout le livre, sans voyelles ni guillemets.
    public static func recherche(_ livre: Livre, _ texte: String) -> [Choisie] {
        let q = nu(texte.rogne)
        if q.utf16.count < 2 { return [] }
        return livre.recherchable.filter { $0.nu.contientUnites(q) }.map { $0.choisie }
    }
}
