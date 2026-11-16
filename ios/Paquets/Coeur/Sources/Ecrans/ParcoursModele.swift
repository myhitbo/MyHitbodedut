import Foundation
import Observation
import Coeur

// « Mon parcours » (ParcoursActivity.kt d'Android, proposition 6, 19/10) : une page qui rassemble ce que
// l'accueil ne montre qu'en partie. Quatre tuiles (série actuelle, meilleure série, jours de hitbodedout,
// temps total), la moyenne par jour, le mois en barres sur le vert du bandeau, les sujets les plus fréquents
// en barres, et l'humeur moyenne avant → après quand elle a été notée. Les chiffres sont ceux de Coeur
// (Parcours.bilan, Parcours.humeur, Store.streak, Store.meilleureSerie, JournalPlus.minutesDuMois).
//
// Lu du Magasin à chaque fois : Android calcule à l'ouverture, ici ce qui change ailleurs se voit aussitôt.

/// Ce qu'une tuile montre en grand.
public enum ParcoursValeur: Sendable, Hashable {
    /// Un nombre de jours : il monte de 0 à sa valeur à l'ouverture (Effets.compte).
    case nombre(Int)
    /// Une durée (« 4 h 30 ») : affichée telle quelle.
    case duree(Libelle)
}

/// La couleur de la pastille d'une tuile : celle de l'anneau qu'elle rappelle.
public enum ParcoursTeinte: Sendable, Hashable {
    /// L'anneau de la série (ring_streak : #B8780F de jour, #E8B45C de nuit).
    case anneauSerie
    /// L'anneau de la semaine (ring_week : #2E7DB3 de jour, #6FB7E8 de nuit).
    case anneauSemaine
    /// La couleur de marque de la palette (jeton `brand`).
    case marque

    /// Le jeton de la palette, pour `marque` ; nil pour les couleurs fixes des anneaux.
    public var jeton: Jeton? {
        switch self {
        case .marque: Jeton.brand
        case .anneauSerie, .anneauSemaine: nil
        }
    }

    /// La couleur fixe d'un anneau, de jour ou de nuit (res/values et values-night/colors.xml) ; nil pour `marque`.
    public func couleur(nuit: Bool) -> Couleur? {
        switch self {
        case .anneauSerie: Couleur(hex: nuit ? "#E8B45C" : "#B8780F")
        case .anneauSemaine: Couleur(hex: nuit ? "#6FB7E8" : "#2E7DB3")
        case .marque: nil
        }
    }
}

/// Une tuile : le chiffre en grand, son unité, puis ce qu'il compte ; une pastille de la couleur de son anneau.
public struct ParcoursTuile: Sendable, Hashable, Identifiable {
    public let id: String
    public let valeur: ParcoursValeur
    /// L'unité après le chiffre (« jours ») ; nil sans unité.
    public let unite: Libelle?
    /// Ce que la tuile compte (« Série actuelle »).
    public let libelle: Libelle
    public let teinte: ParcoursTeinte

    public init(id: String, valeur: ParcoursValeur, unite: Libelle?, libelle: Libelle, teinte: ParcoursTeinte) {
        self.id = id
        self.valeur = valeur
        self.unite = unite
        self.libelle = libelle
        self.teinte = teinte
    }
}

/// Un sujet fréquent : son nom, le nombre de fois, et sa barre.
public struct ParcoursSujet: Sendable, Hashable, Identifiable {
    public let theme: Theme
    /// Le nom du sujet (clé `theme_…`).
    public let nom: Libelle
    /// « 3 fois ».
    public let fois: Libelle
    /// Sa part du sujet le plus fréquent, de 0 à 1.
    public let part: Double

    public var id: String { theme.cle }

    /// La part que la barre remplit : au moins 4 %, pour qu'un sujet rare se voie (`coerceIn(0.04f, 1f)`).
    public var partDessinee: Double { min(max(part, 0.04), 1) }

    public init(theme: Theme, nombre: Int, plusFrequent: Int) {
        self.theme = theme
        nom = Libelle(theme.titre)
        fois = Libelle.pluriel("parcours_fois", quantite: nombre, .entier(nombre))
        part = plusFrequent > 0 ? Double(nombre) / Double(plusFrequent) : 0
    }
}

/// L'humeur moyenne, avant → après.
public struct ParcoursHumeur: Sendable, Hashable {
    /// De 1 à 5.
    public let avant: Int
    public let apres: Int
    /// Les jours où l'humeur avant et l'humeur après sont notées.
    public let jours: Int

    public init(_ humeur: Parcours.Humeur) {
        avant = humeur.avant
        apres = humeur.apres
        jours = humeur.jours
    }

    /// « 🙁  →  🙂 », isolé de gauche à droite (U+2066…U+2069) : en hébreu aussi, la flèche va d'avant à après.
    /// En 36 pt, centré.
    public var texte: String {
        "\u{2066}" + ParcoursHumeur.emoji(avant) + "  \u{2192}  " + ParcoursHumeur.emoji(apres) + "\u{2069}"
    }

    /// La légende, en deux morceaux que la vue joint par « · » : « Avant et après, en moyenne · sur 4
    /// hitbodedout notées ».
    public var legende: [Libelle] {
        [Libelle("parcours_humeur_legende"), Libelle.pluriel("parcours_humeur_jours", quantite: jours, .entier(jours))]
    }

    private static func emoji(_ n: Int) -> String {
        n >= 1 && n <= JournalPlus.humeurs.count ? JournalPlus.humeurs[n - 1] : "\u{00B7}"
    }
}

/// L'écran « Mon parcours ».
@MainActor
@Observable
public final class ParcoursModele {

    // Les textes et l'image fixes (activity_parcours.xml, ParcoursActivity.kt).
    public let titre = Libelle("parcours_title")
    public let sousTitre = Libelle("parcours_hint")
    /// Le hassid qui loue, dans le bandeau (50 × 60 pt sur une plaque `mint`, décoratif).
    public let imageBandeau = "char_praise"
    public let titreMois = Libelle("parcours_mois")
    public let titreSujets = Libelle("parcours_sujets")
    public let titreHumeur = Libelle("parcours_humeur")
    public let sujetsVide = Libelle("parcours_sujets_vide")

    private let magasin: Magasin
    private let horloge: any Horloge

    public init(magasin: Magasin, horloge: any Horloge) {
        self.magasin = magasin
        self.horloge = horloge
    }

    // MARK: Les tuiles

    /// Deux rangées de deux : série actuelle et meilleure série ; jours de hitbodedout et temps total.
    public var tuiles: [ParcoursTuile] {
        let journal = magasin.journal
        let reglages = magasin.reglages
        let aujourdhui = horloge.aujourdhui
        let telephone = horloge.fuseau.identifiant
        let serie = Store.streak(journal: journal, reglages: reglages, aujourdhui: aujourdhui, fuseauTelephone: telephone)
        let meilleure = Store.meilleureSerie(journal: journal, reglages: reglages, aujourdhui: aujourdhui,
                                             fuseauTelephone: telephone)
        let bilan = self.bilan
        return [
            ParcoursTuile(id: "serie", valeur: .nombre(serie),
                          unite: Libelle.pluriel("parcours_unite_jours", quantite: serie),
                          libelle: Libelle("parcours_serie"), teinte: .anneauSerie),
            ParcoursTuile(id: "meilleure", valeur: .nombre(meilleure),
                          unite: Libelle.pluriel("parcours_unite_jours", quantite: meilleure),
                          libelle: Libelle("parcours_meilleure"), teinte: .anneauSerie),
            ParcoursTuile(id: "jours", valeur: .nombre(bilan.jours), unite: nil,
                          libelle: Libelle("parcours_jours_faits"), teinte: .anneauSemaine),
            ParcoursTuile(id: "total", valeur: .duree(Store.formatDuration(bilan.minutes)), unite: nil,
                          libelle: Libelle("parcours_total"), teinte: .marque),
        ]
    }

    /// « En moyenne, 25 min par jour de hitbodedout », sous les tuiles ; nil sans aucun jour fait.
    public var moyenne: Libelle? {
        let bilan = self.bilan
        guard bilan.jours > 0 else { return nil }
        return Libelle("parcours_moyenne_ligne", .libelle(Store.formatDuration(bilan.moyenne)))
    }

    // MARK: Le mois

    /// Les barres du mois en cours.
    public var graphique: JournalGraphique {
        JournalGraphique(journal: magasin.journal, aujourdhui: horloge.aujourdhui)
    }

    /// Au-dessus des barres : « 2 h 10 ce mois-ci, en 5 jours », ou « Pas encore de hitbodedout ce mois-ci. ».
    public var texteMois: Libelle {
        let mois = graphique
        let total = mois.total
        let jours = mois.joursAvecMinutes
        guard total != 0 else { return Libelle("parcours_mois_vide") }
        return Libelle.pluriel("parcours_mois_total", quantite: jours, .libelle(Store.formatDuration(total)),
                               .entier(jours))
    }

    // MARK: Les sujets

    /// Les sujets les plus fréquents (cinq au plus), du plus au moins ; vide : la carte dit `sujetsVide`.
    public var sujets: [ParcoursSujet] {
        let frequents = bilan.sujets
        var plusFrequent = 0
        for f in frequents where f.nombre > plusFrequent {
            plusFrequent = f.nombre
        }
        return frequents.map { ParcoursSujet(theme: $0.theme, nombre: $0.nombre, plusFrequent: plusFrequent) }
    }

    // MARK: L'humeur

    /// L'humeur moyenne, sur les journées du journal où l'humeur avant et après sont notées ; nil sinon (la
    /// section entière, titre compris, est alors absente).
    public var humeur: ParcoursHumeur? {
        let journal = magasin.journal
        // Les jours des journées seulement (`jours.keys`), pas tout le journal enrichi.
        let plus = journal.dates.map { journal.lirePlus($0) }
        return Parcours.humeur(plus).map { ParcoursHumeur($0) }
    }

    // MARK: Le bilan

    /// Les jours faits, leurs minutes, et les sujets de toutes les journées.
    private var bilan: Parcours.Bilan {
        Parcours.bilan(magasin.journal.jours.values)
    }
}
