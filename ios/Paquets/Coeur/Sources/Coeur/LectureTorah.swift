import Foundation
import KosherSwift

/// La lecture de la Torah des offices de semaine (LectureTorah.kt, demande du 26/11 : « le texte de la paracha
/// concordant le jour de lecture de la Torah ») : à Cha'harit le lundi et le jeudi, à Roch 'Hodech, à 'Hol hamoèd, à
/// 'Hanouka, à Pourim et aux jeûnes publics (9 Av compris), à Min'ha des jeûnes publics ; jamais Chabbat ni Yom tov, dont
/// le siddour n'a pas l'office. Ses montées selon Israël ou la diaspora, Jérusalem (Pourim le 15) et le noussa'h.
///
/// Les données (lecture_torah.json, tools/lecture_torah_construction.py) viennent de @hebcal/leyning 10.1.0
/// (BSD-2-Clause, dont la licence est livrée dans leur `_meta`) et des écarts sourcés des Edot ; le calcul suit celui
/// d'hebcal (getLeyningOnDate), sur KosherSwift comme le reste du calendrier (CalendrierJuif.swift). Le juge :
/// `web/test/vecteurs_lecture_torah.json`, que le site écrit en comparant son calcul à hebcal jour par jour, et que le
/// test d'Android relit aussi (LectureTorahTest).
public enum LectureTorah {

    public static let chaharit = "chaharit"
    public static let minha = "minha"
    public static let offices = [chaharit, minha]
    public static let nusah = ["edot", "sefard", "ashkenaz"]

    /// Une montée : sa clé (« 1 », « 3_israel », « M »…), son libellé, son passage.
    public struct Montee: Sendable, Equatable {
        public let cle: String
        public let libelle: TexteLocalise
        public let livre: String
        public let debut: String
        public let fin: String

        public init(cle: String, libelle: TexteLocalise, livre: String, debut: String, fin: String) {
            self.cle = cle
            self.libelle = libelle
            self.livre = livre
            self.debut = debut
            self.fin = fin
        }
    }

    /// Une lecture : `cle` « semaine:VAYETZEI » (lundi et jeudi) ou la clé d'hebcal d'un jour (« Rosh Chodesh »…).
    public struct Lecture: Sendable, Equatable {
        public let cle: String
        public let titre: TexteLocalise
        public let montees: [Montee]

        public init(cle: String, titre: TexteLocalise, montees: [Montee]) {
            self.cle = cle
            self.titre = titre
            self.montees = montees
        }
    }

    /// Un verset ; `fin` : « פ » ou « ס » quand il clôt un paragraphe.
    public struct Verset: Sendable, Equatable {
        public let chapitre: Int
        public let verset: Int
        public let texte: String
        public let fin: String?
    }

    /// Une entrée de lecture_torah.json : listes [montée, livre, début, fin].
    public struct Entree: Sendable {
        public let titre: TexteLocalise?
        public let alias: String?
        public let champs: [String: [[String]]]
    }

    /// lecture_torah.json lu.
    public struct Donnees: Sendable {
        public let parachiot: [String: Entree]
        public let lectures: [String: Entree]
        public let montees: [String: TexteLocalise]
        /// Les noms des livres (« Genesis » → בראשית, Berèchit, Bereshit), pour nommer un passage.
        public let livres: [String: TexteLocalise]
    }

    /// Une donnée qui manque, ou une lecture inconnue (`error(…)` d'Android).
    public struct Erreur: Error, Sendable, Equatable {
        public let raison: String
    }

    // MARK: La lecture du fichier

    public static func parse(_ json: String) throws -> Donnees {
        let o = try ObjetJSON(texte: json)
        func texteLocalise(_ x: ObjetJSON?) -> TexteLocalise {
            guard let x else { return .vide }
            return TexteLocalise(he: x.texte("he"), fr: x.texte("fr"), en: x.texte("en"))
        }
        func listes(_ a: [JSON]) throws -> [[String]] {
            try a.map { element in
                guard case .tableau(let x) = element else { throw Erreur(raison: "une montée n'est pas une liste") }
                return x.map { $0.commeTexte }
            }
        }
        func entree(_ e: ObjetJSON) throws -> Entree {
            var champs: [String: [[String]]] = [:]
            for (k, v) in e.paires where k.commenceParUnites("alyot") || k.egalUnites("semaine") {
                guard case .tableau(let a) = v else { throw Erreur(raison: "« \(k) » n'est pas une liste") }
                champs[k] = try listes(a)
            }
            let alias = e.estNul("alias") ? nil : e.texte("alias")
            return Entree(titre: e.objet("titre").map { texteLocalise($0) }, alias: alias.flatMap { $0.estBlanc ? nil : $0 },
                          champs: champs)
        }
        func entrees(_ t: ObjetJSON?) throws -> [String: Entree] {
            guard let t else { throw Erreur(raison: "table absente") }
            var sortie: [String: Entree] = [:]
            for (k, v) in t.paires {
                guard case .objet(let e) = v else { throw Erreur(raison: "« \(k) » n'est pas un objet") }
                sortie[k] = try entree(e)
            }
            return sortie
        }
        func noms(_ t: ObjetJSON?) throws -> [String: TexteLocalise] {
            guard let t else { throw Erreur(raison: "table absente") }
            var sortie: [String: TexteLocalise] = [:]
            for (k, v) in t.paires {
                guard case .objet(let x) = v else { throw Erreur(raison: "« \(k) » n'est pas un objet") }
                sortie[k] = texteLocalise(x)
            }
            return sortie
        }
        return Donnees(parachiot: try entrees(o.objet("parachiot")), lectures: try entrees(o.objet("lectures")),
                       montees: try noms(o.objet("montees")), livres: try noms(o.objet("livres")))
    }

    /// « Berèchit 32:4–13 » : un passage dans la langue `langue` (les livres de `d`) ; l'hébreu pour l'espagnol et
    /// l'arabe, comme les autres textes.
    public static func reference(_ d: Donnees, livre: String, debut: String, fin: String, langue: String) -> String {
        let nom = d.livres[livre]?.pour(langue) ?? livre
        let a = debut.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        let b = fin.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        let plage: String
        if debut == fin {
            plage = debut
        } else if a.count == 2, b.count == 2, a[0] == b[0] {
            plage = a[0] + ":" + a[1] + "\u{2013}" + b[1]
        } else {
            plage = debut + "\u{2013}" + fin
        }
        return nom + " " + plage
    }

    // MARK: Le calendrier

    /// Le jour de Sim'hat Torah : 22 Tichri en Israël, 23 en diaspora.
    private static func simhatTorah(_ il: Bool) -> Int { il ? 22 : 23 }

    /// La paracha lue le Chabbat `date` ou, à défaut (fête), celle qui vient dans le cycle : findParshaHaShavua
    /// d'hebcal. Entre Kippour et Sim'hat Torah, Vézot haBérakha. Le nom est celui de l'énumération de KosherJava
    /// (« VAYISHLACH »).
    public static func parachaDeLaSemaine(_ date: JourCivil, enIsrael il: Bool) -> String {
        CalendrierJuif.verrou.withLock { _ in parachaSansVerrou(date, il) }
    }

    private static func parachaSansVerrou(_ date: JourCivil, _ il: Bool) -> String {
        var s = date
        while true {
            let jc = CalendrierJuif.calendrier(s, enIsrael: il, modernes: false)
            let p = jc.getParshah()
            if p != .NONE { return String(describing: p) }
            let mois = CalendrierJuif.moisKosherJava(jc.getJewishMonth(), embolismique: jc.isJewishLeapYear())
            let j = jc.getJewishDayOfMonth()
            if s == date && mois == CalendrierJuif.Mois.tichri && j > 2 && j <= simhatTorah(il) { return "VZOS_HABERACHA" }
            s = s.plus(jours: 7)
        }
    }

    /// Le samedi qui suit `date` (elle-même si c'est un samedi).
    private static func chabbatSuivant(_ date: JourCivil) -> JourCivil {
        date.plus(jours: (7 - date.jourDeSemaine) % 7)
    }

    /// La clé de la lecture d'un jour de semaine qui n'est pas un lundi ou un jeudi ordinaire (holiday-readings.json
    /// d'hebcal) : Roch 'Hodech, 'Hol hamoèd, 'Hanouka, Pourim, jeûnes ; nil sinon. `jc` n'est ni Chabbat ni Yom tov.
    static func cleFete(_ jc: JewishCalendar, _ date: JourCivil, _ il: Bool, _ muk: Bool) -> String? {
        let m = CalendrierJuif.moisKosherJava(jc.getJewishMonth(), embolismique: jc.isJewishLeapYear())
        let d = jc.getJewishDayOfMonth()
        let yt = jc.getYomTovIndex()
        if m == CalendrierJuif.Mois.tichri {
            if d >= (il ? 16 : 17) && d <= 20 {
                let n = d - (il ? 15 : 16)
                return il ? "Sukkot Chol ha-Moed Day \(n) (Israel)" : "Sukkot Chol ha-Moed Day \(n)"
            }
            if d == 21 { return il ? "Sukkot Final Day (Hoshana Raba) (Israel)" : "Sukkot Final Day (Hoshana Raba)" }
        }
        if yt == JewishCalendar.FAST_OF_GEDALYAH { return "Tzom Gedaliah" }
        if jc.isChanukah() {
            let j = jc.getDayOfChanukah()
            let rc = jc.isRoshChodesh()
            if rc && j == 7 { return "Chanukah Day 7 (on Rosh Chodesh)" }
            if rc { return "Chanukah Day 6" }
            return "Chanukah Day \(j)"
        }
        if yt == JewishCalendar.TENTH_OF_TEVES { return "Asara B'Tevet" }
        if yt == JewishCalendar.FAST_OF_ESTHER { return "Ta'anit Esther" }
        if yt == JewishCalendar.SEVENTEEN_OF_TAMMUZ { return "Tzom Tammuz" }
        if yt == JewishCalendar.TISHA_BEAV { return "Tish'a B'Av" }
        // Pourim : le 14, ou le 15 dans une ville murée (Jérusalem), où il est « Chouchan Pourim ».
        if jc.isPurim() { return muk ? "Shushan Purim" : "Purim" }
        if m == CalendrierJuif.Mois.nissan {
            if d == 16 { return "Pesach II (CH''M)" }  // en Israël ; en diaspora, Yom tov
            if (17...20).contains(d) {
                // Pessa'h un jeudi : « ראה אתה » (פסל) le Chabbat 17, puis קדש, בכספא, במדברא du dimanche au mardi
                // (Choul'han Aroukh O.H. 490:5 ; Kitsour Yalkout Yossef 488:12, pour Israël aussi : hebcal y relit פסל le
                // lundi et omet קדש, écart voulu).
                let jeudi = date.plus(jours: -(d - 15)).jourDeSemaine == 5
                let n: Int
                if jeudi {
                    switch d {
                    case 18: n = 1
                    case 19: n = 2
                    case 20: n = 4
                    // getValue(17) d'Android lève : Pessa'h un jeudi, le 17 est un Chabbat, jamais demandé ici.
                    default: return nil
                    }
                } else {
                    n = d - 16
                }
                return "Pesach Chol ha-Moed Day \(n)"
            }
        }
        if jc.isRoshChodesh() { return "Rosh Chodesh" }
        return nil
    }

    // MARK: Les lectures

    /// Les montées d'une entrée pour un noussa'h, alias résolu.
    private static func fete(_ d: Donnees, _ cle: String, _ nusah: String) throws -> Lecture {
        guard let e = d.lectures[cle] else { throw Erreur(raison: "lecture inconnue : \(cle)") }
        let base: Entree
        if let alias = e.alias {
            guard let b = d.lectures[alias] else { throw Erreur(raison: "alias inconnu : \(alias)") }
            base = b
        } else {
            base = e
        }
        guard let alyot = e.champs["alyot_" + nusah] ?? e.champs["alyot"] ?? base.champs["alyot_" + nusah]
            ?? base.champs["alyot"] else { throw Erreur(raison: "\(cle) sans montées") }
        guard let titre = e.titre ?? base.titre else { throw Erreur(raison: "\(cle) sans titre") }
        return try lecture(d, cle, titre, alyot)
    }

    private static func lecture(_ d: Donnees, _ cle: String, _ titre: TexteLocalise, _ alyot: [[String]]) throws -> Lecture {
        let trois = alyot.count == 3
        let montees = try alyot.map { a -> Montee in
            guard a.count >= 4 else { throw Erreur(raison: "\(cle) : montée incomplète") }
            let c = a[0]
            let nom = trois && c == "3" ? "3_israel" : c
            guard let libelle = d.montees[nom] else { throw Erreur(raison: "montée inconnue : \(nom)") }
            return Montee(cle: c, libelle: libelle, livre: a[1], debut: a[2], fin: a[3])
        }
        return Lecture(cle: cle, titre: titre, montees: montees)
    }

    private static func semaine(_ d: Donnees, _ p: String) throws -> Lecture {
        guard let e = d.parachiot[p], let titre = e.titre, let alyot = e.champs["semaine"] else {
            throw Erreur(raison: "paracha inconnue : \(p)")
        }
        return try lecture(d, "semaine:" + p, titre, alyot)
    }

    /// Les lectures d'un office de semaine : vide s'il n'y en a pas, et toujours un Chabbat ou un Yom tov. `date` : le
    /// jour civil de l'office ; `office` : `chaharit` ou `minha` ; `nusah` : « edot », « sefard » ou « ashkenaz » ;
    /// `mukafChoma` : Jérusalem (Pourim le 15), en Israël seulement.
    public static func lectures(_ d: Donnees, date: JourCivil, office: String, enIsrael: Bool, mukafChoma: Bool = false,
                                nusah: String = "edot") throws -> [Lecture] {
        let il = enIsrael
        let muk = mukafChoma && enIsrael
        // Les clés se lisent sous le verrou de KosherSwift ; les données, après.
        enum Choix { case rien, fete(String), semaine(String) }
        let choix: Choix = CalendrierJuif.verrou.withLock { _ in
            let jc = CalendrierJuif.calendrier(date, enIsrael: il, modernes: false, mukafChoma: muk)
            if jc.isAssurBemelacha() { return .rien }
            if office == minha {
                guard jc.isTaanis() else { return .rien }
                return .fete((cleFete(jc, date, il, muk) ?? "null") + " (Mincha)")
            }
            if office != chaharit { return .rien }
            if let cle = cleFete(jc, date, il, muk) { return .fete(cle) }
            let jour = date.jourDeSemaine
            if jour == 2 || jour == 5 { return .semaine(parachaSansVerrou(chabbatSuivant(date), il)) }
            return .rien
        }
        switch choix {
        case .rien: return []
        case .fete(let cle): return [try fete(d, cle, nusah)]
        case .semaine(let p): return [try semaine(d, p)]
        }
    }

    /// La lecture d'un office de semaine du siddour, à sa place (26/11) : à Cha'harit les jours où l'on lit
    /// (`CalendrierJuif.C.kriatHatorah` : lundi, jeudi, Roch 'Hodech, 'Hol hamoed, 'Hanouka, Pourim, jeûnes), à Min'ha
    /// les jours de jeûne ; jamais un Chabbat ni un Yom tov (le siddour n'en a pas l'office : « Pas de Yom Tov »).
    public static func lecturesOffice(_ d: Donnees, date: JourCivil, office: String, enIsrael: Bool,
                                      mukafChoma: Bool = false, nusah: String = "edot") throws -> [Lecture] {
        guard litDansLOffice(CalendrierJuif.jour(date, enIsrael: enIsrael, mukafChoma: mukafChoma), office: office) else {
            return []
        }
        return try lectures(d, date: date, office: office, enIsrael: enIsrael, mukafChoma: mukafChoma, nusah: nusah)
    }

    /// Le jour `j` a-t-il une lecture à l'office de semaine `office` (sans lire les données) ?
    public static func litDansLOffice(_ j: CalendrierJuif.Jour, office: String) -> Bool {
        if j.chome { return false }
        switch office {
        case chaharit: return j.conditions.contains(CalendrierJuif.C.kriatHatorah)
        case minha: return j.conditions.contains(CalendrierJuif.C.jeune)
        default: return false
        }
    }

    // MARK: Le texte

    /// lecture_torah_texte.json : les chapitres lus, livre par livre, et les fins de paragraphe.
    public struct Texte: Sendable {
        private let livres: [String: [String: [String]]]
        private let paragraphes: [String: [String: String]]

        private struct Brut: Decodable {
            let livres: [String: [String: [String]]]
            let paragraphes: [String: [String: String?]]?
        }

        public init(_ donnees: Data) throws {
            let brut = try JSONDecoder().decode(Brut.self, from: donnees)
            livres = brut.livres
            var p: [String: [String: String]] = [:]
            for (livre, fins) in brut.paragraphes ?? [:] {
                // `Json.nullable` d'Android : une fin nulle ou blanche ne compte pas.
                p[livre] = fins.compactMapValues { f in f.flatMap { $0.estBlanc ? nil : $0 } }
            }
            paragraphes = p
        }

        public func versets(_ m: Montee) throws -> [Verset] {
            try versets(livre: m.livre, debut: m.debut, fin: m.fin)
        }

        public func versets(livre: String, debut: String, fin: String) throws -> [Verset] {
            func paire(_ x: String) throws -> (Int, Int) {
                let p = x.split(separator: ":", omittingEmptySubsequences: false)
                guard p.count == 2, let c = Int(p[0]), let v = Int(p[1]) else { throw Erreur(raison: "référence illisible : \(x)") }
                return (c, v)
            }
            let (c1, v1) = try paire(debut)
            let (c2, v2) = try paire(fin)
            guard let chapitres = livres[livre] else { throw Erreur(raison: "\(livre) : livre absent") }
            let fins = paragraphes[livre]
            var sortie: [Verset] = []
            guard c1 <= c2 else { return sortie }
            for c in c1...c2 {
                guard let chapitre = chapitres[String(c)] else { throw Erreur(raison: "\(livre) \(c) : chapitre absent") }
                let premier = c == c1 ? v1 : 1
                let dernier = c == c2 ? v2 : chapitre.count
                guard premier <= dernier else { continue }
                for v in premier...dernier {
                    guard v >= 1 && v <= chapitre.count else { throw Erreur(raison: "\(livre) \(c):\(v) : verset absent") }
                    sortie.append(Verset(chapitre: c, verset: v, texte: chapitre[v - 1], fin: fins?["\(c):\(v)"]))
                }
            }
            return sortie
        }
    }
}
