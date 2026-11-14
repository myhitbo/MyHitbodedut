import Foundation

// Le livre de Tehilim entier, ses deux cycles de lecture et le jour du mois hébreu (Tehilim.kt).
// `tehilim.json` est lu comme org.json d'Android le lit (`ObjetJSON`), conversions comprises.
// Jugé par `Tests/Vecteurs/tehilim.json` (tools/vecteurs_ios/VecteursTehilim.kt).

/// Le livre de Tehilim entier (demande du 04/10) : 150 psaumes, 2 527 versets, dans l'édition et
/// selon les conventions du Tikoun (`tehilim.json`, dont le bloc `_meta` dit la source et la
/// vérification).
public struct Tehilim: Sendable, Equatable {

    /// `PSAUMES` de Kotlin : le nombre de psaumes du livre.
    public static let nombreDePsaumes = 150

    public let psaumes: [[String]]
    /// Langue (« fr », « en ») → psaumes → versets.
    public let traductions: [String: [[String]]]
    /// Les langues de `traductions`, dans l'ordre du fichier, que la Map de Kotlin garde.
    public let langues: [String]

    /// `traductions` : (langue, psaumes) dans l'ordre ; une langue répétée garde sa première
    /// place et prend ses derniers psaumes, comme `toMap()`.
    public init(psaumes: [[String]], traductions: [(String, [[String]])] = []) {
        self.psaumes = psaumes
        var parLangue: [String: [[String]]] = [:]
        var ordre: [String] = []
        for (langue, texte) in traductions {
            if parLangue.updateValue(texte, forKey: langue) == nil {
                ordre.append(langue)
            }
        }
        self.traductions = parLangue
        langues = ordre
    }

    /// Les versets du psaume `numero` (1 à 150), dans l'ordre ; aucun hors du livre.
    public func versets(_ numero: Int) -> [String] {
        numero >= 1 && numero <= psaumes.count ? psaumes[numero - 1] : []
    }

    /// La traduction (« fr », « en ») du verset `verset` du psaume `numero` ; nil sans traduction,
    /// ou si elle n'est faite que de blancs (04/11).
    public func traduction(_ langue: String, _ numero: Int, _ verset: Int) -> String? {
        guard let livre = traductions[langue], numero >= 1, numero <= livre.count else { return nil }
        let versets = livre[numero - 1]
        guard verset >= 1, verset <= versets.count else { return nil }
        let texte = versets[verset - 1]
        return texte.estBlanc ? nil : texte
    }

    public var versetsTotal: Int {
        var total = 0
        for psaume in psaumes {
            total += psaume.count
        }
        return total
    }
}

/// La lecture de `tehilim.json` (TehilimLoader).
public enum TehilimLoader {

    /// Lève, comme `getJSONArray` d'Android, si `psaumes` manque ou si l'un de ses psaumes (ou de
    /// ceux d'une traduction) n'est pas un tableau. Un verset qui n'est pas une chaîne est lu comme
    /// `getString` le lit : le texte de sa valeur, « null » compris.
    public static func parse(_ json: String) throws -> Tehilim {
        let racine = try ObjetJSON(texte: json)
        // Les traductions (04/11) : « traductions » {fr, en} → {edition, psaumes}, à côté de l'hébreu.
        var traductions: [(String, [[String]])] = []
        if let trad = racine.objet("traductions") {
            for langue in trad.cles {
                if let tableau = trad.objet(langue)?.tableau("psaumes") {
                    let traduits = try versetsDes(tableau)
                    traductions.append((langue, traduits))
                }
            }
        }
        guard let tableau = racine.tableau("psaumes") else {
            throw ErreurJSON(position: 0, raison: "« psaumes » n'est pas un tableau")
        }
        let psaumes = try versetsDes(tableau)
        return Tehilim(psaumes: psaumes, traductions: traductions)
    }

    /// `load(context)` : `res/raw/tehilim.json`, exporté sous `Contenu/`.
    public static func load(_ lire: LecteurContenu) throws -> Tehilim {
        guard let donnees = try lire("tehilim.json") else { throw ErreurContenu.absent("tehilim.json") }
        return try parse(String(decoding: donnees, as: UTF8.self))
    }

    private static func versetsDes(_ tableau: [JSON]) throws -> [[String]] {
        var resultat: [[String]] = []
        for psaume in tableau {
            guard case .tableau(let versets) = psaume else {
                throw ErreurJSON(position: 0, raison: "un psaume n'est pas un tableau")
            }
            var textes: [String] = []
            for verset in versets {
                textes.append(verset.commeTexte)
            }
            resultat.append(textes)
        }
        return resultat
    }
}

/// Un passage du livre : du psaume `debut` au psaume `fin`. Seul le psaume 119, trop long pour un
/// jour, se coupe en deux, d'où les bornes de versets.
public struct Portion: Sendable, Hashable {
    public let debut: Int
    public let fin: Int
    public let debutVerset: Int
    /// nil : jusqu'au dernier verset du psaume.
    public let finVerset: Int?

    public init(_ debut: Int, _ fin: Int, _ debutVerset: Int = 1, _ finVerset: Int? = nil) {
        self.debut = debut
        self.fin = fin
        self.debutVerset = debutVerset
        self.finVerset = finVerset
    }

    public var psaumes: Intervalle { Intervalle(debut, fin) }

    /// Les versets à lire dans `psaume`, qui en compte `total`.
    public func versets(_ psaume: Int, _ total: Int) -> Intervalle {
        let premier = psaume == debut ? debutVerset : 1
        let dernier = psaume == fin ? (finVerset ?? total) : total
        return Intervalle(premier, dernier)
    }

    /// Vrai si la portion ne prend qu'une partie d'un psaume (119:1-96).
    public var partielle: Bool { debut == fin && (debutVerset > 1 || finVerset != nil) }

    /// Des entiers consécutifs, bornes comprises : l'`IntRange` de Kotlin, vide quand `premier`
    /// dépasse `dernier`. Un `ClosedRange` de Swift s'arrêterait sur des bornes à l'envers, que
    /// donne un psaume sans verset (livre absent : 1…0).
    public struct Intervalle: Sendable, Hashable, Sequence {
        public let premier: Int
        public let dernier: Int

        public init(_ premier: Int, _ dernier: Int) {
            self.premier = premier
            self.dernier = dernier
        }

        public var estVide: Bool { premier > dernier }

        /// `count()` de Kotlin.
        public var nombre: Int { estVide ? 0 : dernier - premier + 1 }

        public func contient(_ n: Int) -> Bool { premier <= n && n <= dernier }

        public func makeIterator() -> StrideThroughIterator<Int> {
            stride(from: premier, through: dernier, by: 1).makeIterator()
        }

        /// Comme `IntRange.equals` : deux intervalles vides sont égaux, quelles que soient leurs bornes.
        public static func == (a: Intervalle, b: Intervalle) -> Bool {
            (a.estVide && b.estVide) || (a.premier == b.premier && a.dernier == b.dernier)
        }

        public func hash(into hasher: inout Hasher) {
            if estVide {
                hasher.combine(0)
            } else {
                hasher.combine(premier)
                hasher.combine(dernier)
            }
        }
    }
}

/// Les deux façons traditionnelles de dire tout le livre : en un mois, une portion par jour du mois
/// hébraïque, ou en une semaine, du dimanche au Chabbat. Découpages relevés le 04/10/2026 et
/// recoupés sur plusieurs sources indépendantes (hebcal.com, tehilim.co, tehillim-online.com,
/// tehillimforall.com).
public enum CycleTehilim {

    /// `MOIS` de Kotlin : une portion par jour du mois hébreu.
    public static let mois: [Portion] = [
        Portion(1, 9), Portion(10, 17), Portion(18, 22), Portion(23, 28), Portion(29, 34),
        Portion(35, 38), Portion(39, 43), Portion(44, 48), Portion(49, 54), Portion(55, 59),
        Portion(60, 65), Portion(66, 68), Portion(69, 71), Portion(72, 76), Portion(77, 78),
        Portion(79, 82), Portion(83, 87), Portion(88, 89), Portion(90, 96), Portion(97, 103),
        Portion(104, 105), Portion(106, 107), Portion(108, 112), Portion(113, 118),
        Portion(119, 119, 1, 96), Portion(119, 119, 97, 176),
        Portion(120, 134), Portion(135, 139), Portion(140, 144), Portion(145, 150),
    ]

    /// `SEMAINE` de Kotlin : du dimanche au Chabbat.
    public static let semaine: [Portion] = [
        Portion(1, 29), Portion(30, 50), Portion(51, 72), Portion(73, 89),
        Portion(90, 106), Portion(107, 119), Portion(120, 150),
    ]

    /// La portion du `jour` (1 à 30) d'un mois hébraïque de `longueur` jours. Un mois de 29 jours
    /// dit le 29 les deux dernières portions, pour finir le livre avec le mois.
    public static func duMois(_ jour: Int, _ longueur: Int) -> Portion {
        if jour >= 29 && longueur == 29 { return Portion(140, 150) }
        return mois[min(max(jour, 1), 30) - 1]
    }

    /// `jour` : `JourCivil.jourDeSemaine`, 1 = dimanche … 7 = samedi, ramené modulo 7 hors de 1…7.
    /// Kotlin reçoit un DayOfWeek, du lundi (1) au dimanche (7), dont le reste par 7 ramène au dimanche.
    public static func deLaSemaine(_ jour: Int) -> Portion {
        // (jour − 1) modulo 7, sans soustraire avant le modulo : aucun débordement possible.
        semaine[(Kotlin.floorMod(jour, 7) + 6) % 7]
    }

    /// Le jour du mois hébraïque et la longueur de ce mois, pour la date civile : le jour change ici
    /// à minuit, pas au coucher du soleil. La longueur (`daysInJewishMonth`) se lit au trentième jour
    /// compté depuis celui-ci : encore du mois, il en compte 30 ; déjà le 1er du suivant, 29.
    public static func jourHebreu(_ date: JourCivil) -> (jour: Int, longueur: Int) {
        let jour = CalendrierJuif.jour(date, enIsrael: false).jourHebreu
        let trentieme = CalendrierJuif.jour(date.plus(jours: 30 - jour), enIsrael: false).jourHebreu
        return (jour, trentieme == 30 ? 30 : 29)
    }
}
