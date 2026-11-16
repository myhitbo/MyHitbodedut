import Foundation
import Coeur

// Le graphique des minutes du mois (JournalPlus.Graphique d'Android, 14/10) : une barre par jour du mois, à
// l'échelle du plus long, le jour d'aujourd'hui marqué d'un point. Le journal le pose sous son résumé, dans le
// bandeau ; « Mon parcours » dans sa carte verte. Le modèle rend les barres et leurs proportions ; la vue les
// dessine (Canvas) avec les mesures ci-dessous, en points là où Android compte en dp.

/// Une barre du graphique : un jour du mois.
public struct JournalBarre: Sendable, Hashable, Identifiable {
    /// Le jour du mois, du 1ᵉʳ au dernier.
    public let jour: Int
    /// Les minutes de ce jour ; 0 sans hitbodedout, et pour une note seule (JournalPlus.minutesDuMois).
    public let minutes: Int
    /// Les minutes à l'échelle du plus long jour du mois, de 0 à 1 ; 0 pour un jour vide.
    public let part: Double
    /// C'est aujourd'hui : un point au-dessus de la barre.
    public let aujourdhui: Bool

    public var id: Int { jour }

    /// Un jour fait : barre pleine (blanche) ; sinon une barre basse, blanche à 25 %.
    public var faite: Bool { minutes > 0 }

    public init(jour: Int, minutes: Int, part: Double, aujourdhui: Bool) {
        self.jour = jour
        self.minutes = minutes
        self.part = part
        self.aujourdhui = aujourdhui
    }
}

/// Le graphique du mois en cours.
public struct JournalGraphique: Sendable, Hashable {

    /// La hauteur du graphique (64 dp, `onMeasure`).
    public static let hauteur: Double = 64
    /// Ce qu'une barre faite garde au moins (4 dp), et la hauteur d'une barre vide (3 dp).
    public static let socle: Double = 4
    public static let hauteurVide: Double = 3
    /// La barre prend 60 % de sa place, 2 dp au moins ; ses bouts sont arrondis (rayon : sa demi-largeur).
    public static let largeurRelative: Double = 0.6
    public static let largeurMin: Double = 2
    /// Le point d'aujourd'hui : rayon 1,5 dp, centré 4 dp au-dessus du haut de la barre.
    public static let rayonPoint: Double = 1.5
    public static let ecartPoint: Double = 4
    /// Opacité d'une barre vide (0x40 sur 0xFF).
    public static let opaciteVide: Double = Double(0x40) / 255

    /// Le premier jour du mois montré.
    public let mois: JourCivil
    /// Une barre par jour du mois, du 1ᵉʳ au dernier (de gauche à droite, de droite à gauche en hébreu).
    public let barres: [JournalBarre]

    /// Le mois du jour `aujourdhui` (`YearMonth.now()`, `LocalDate.now().dayOfMonth`).
    public init(journal: Journal, aujourdhui: JourCivil) {
        let minutes = JournalPlus.minutesDuMois(journal.jours, annee: aujourdhui.annee, mois: aujourdhui.mois)
        var plusLong = 1
        for m in minutes where m > plusLong {
            plusLong = m
        }
        var barres: [JournalBarre] = []
        for (rang, m) in minutes.enumerated() {
            let part = m > 0 ? Double(m) / Double(plusLong) : 0
            barres.append(JournalBarre(jour: rang + 1, minutes: m, part: part, aujourdhui: rang + 1 == aujourdhui.jour))
        }
        self.barres = barres
        mois = aujourdhui.plus(jours: 1 - aujourdhui.jour)
    }

    /// Les minutes du mois (`mois.sum()` de ParcoursActivity).
    public var total: Int {
        var somme = 0
        for barre in barres {
            somme += barre.minutes
        }
        return somme
    }

    /// Les jours du mois qui ont des minutes (`mois.count { it > 0 }`).
    public var joursAvecMinutes: Int {
        var n = 0
        for barre in barres where barre.minutes > 0 {
            n += 1
        }
        return n
    }

    /// La description du graphique pour l'accessibilité : « Les minutes de chaque jour, novembre 2026 ».
    /// `moisNomme` est le mois et l'année écrits dans la langue de l'app (« MMMM yyyy »), mis en forme par la vue.
    public func accessibilite(moisNomme: String) -> Libelle {
        Libelle("journal_graphique", .texte(moisNomme))
    }

    /// La hauteur d'une barre dans un graphique haut de `hauteur` points (`onDraw`) : à l'échelle du plus long
    /// jour pour un jour fait, au moins 4 points ; 3 points pour un jour vide.
    public static func hauteurBarre(_ barre: JournalBarre, hauteur: Double = JournalGraphique.hauteur) -> Double {
        barre.faite ? (hauteur - socle) * barre.part + socle : hauteurVide
    }

    /// La largeur d'une barre dans un graphique large de `largeur` points, pour `nombre` barres.
    public static func largeurBarre(largeur: Double, nombre: Int) -> Double {
        guard nombre > 0 else { return 0 }
        return max(largeur / Double(nombre) * largeurRelative, largeurMin)
    }
}
