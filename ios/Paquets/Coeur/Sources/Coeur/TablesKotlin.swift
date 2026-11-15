import Foundation

// Les tables écrites dans le Kotlin d'Android (PORTAGE.md § 4.1 C), exportées par
// tools/export_contenu/tables : le Kotlin de l'app compilé sur la JVM écrit Contenu/tables.json,
// qu'iOS lit au lieu de recopier les valeurs. Les noms de ressources (« tip_1_title »,
// « char_open_arms ») sont ceux d'Android : les clés du catalogue de chaînes et des images.
//
// Les clés du fichier sont en snake_case ; les CodingKeys les nomment une à une (la stratégie
// convertFromSnakeCase toucherait aussi les clés des dictionnaires, comme « VAYAKHEL_PEKUDEI »).

public struct TablesKotlin: Sendable, Decodable {
    public let paliers: [String: Echelle]
    public let trophees: Trophees
    public let tehilim: Tehilim
    public let tikkun: Tikkun
    public let hitbodedut: Hitbodedut
    public let sujetsTefila: SujetsTefila
    public let sujetsSeance: [Sujet]
    public let questions: [String]
    public let presentation: Presentation
    public let conseils: [Conseil]
    public let yalkutYosef: YalkutYosef
    public let benIshHai: BenIshHai
    public let calendrier: Calendrier
    public let zmanim: Zmanim
    public let references: References
    public let saisieVol: SaisieVol
    public let territoireIsrael: Territoire
    public let directionJerusalem: DirectionJerusalem
    public let personnage: Personnage
    /// Personnage.FEMININ (lu par expression régulière : le fichier tient à Android).
    public let posesFeminines: [PoseFeminine]
    /// PoliceHebraique : les polices et leurs signes absents (expression régulière aussi).
    public let polices: [Police]

    enum CodingKeys: String, CodingKey {
        case paliers, trophees, tehilim, tikkun, hitbodedut, questions, presentation, conseils, calendrier,
             zmanim, references, personnage, polices
        case sujetsTefila = "sujets_tefila", sujetsSeance = "sujets_seance", yalkutYosef = "yalkut_yosef",
             benIshHai = "ben_ish_hai", saisieVol = "saisie_vol", territoireIsrael = "territoire_israel",
             directionJerusalem = "direction_jerusalem", posesFeminines = "poses_feminines"
    }

    public static func lire(_ donnees: Data) throws -> TablesKotlin {
        try JSONDecoder().decode(TablesKotlin.self, from: donnees)
    }

    // MARK: Paliers et trophées

    /// Une échelle de paliers (Paliers.ECHELLES) : la base, et le pas au-delà du dernier palier.
    public struct Echelle: Sendable, Equatable, Decodable {
        public let echelle: [Int]
        public let pas: Int
    }

    public struct Trophees: Sendable, Equatable, Decodable {
        public let metaux: [String]
        public let formes: [String]
        public let familles: [Famille]
        /// Trophees.chemin : tous les niveaux, du plus facile au plus dur.
        public let chemin: [Niveau]
        public let seuilsGrades: [Int]

        enum CodingKeys: String, CodingKey {
            case metaux, formes, familles, chemin
            case seuilsGrades = "seuils_grades"
        }
    }

    public struct Famille: Sendable, Equatable, Decodable {
        public let cle: String
        public let icone: String
        public let forme: String
        public let seuils: [Int]
    }

    public struct Niveau: Sendable, Equatable, Decodable {
        public let famille: String
        public let rang: Int
        public let seuil: Int
        public let cout: Double
    }

    // MARK: Textes

    /// Un passage de Tehilim ; seul le psaume 119 se coupe, d'où les bornes de versets.
    public struct Portion: Sendable, Equatable, Decodable {
        public let debut: Int
        public let fin: Int
        public let debutVerset: Int
        public let finVerset: Int?

        enum CodingKeys: String, CodingKey {
            case debut, fin
            case debutVerset = "debut_verset", finVerset = "fin_verset"
        }
    }

    public struct Tehilim: Sendable, Equatable, Decodable {
        public let psaumes: Int
        public let mois: [Portion]
        public let semaine: [Portion]
        /// Le 29 d'un mois de 29 jours : les deux dernières portions (CycleTehilim.duMois).
        public let finMoisCourt: Portion

        enum CodingKeys: String, CodingKey {
            case psaumes, mois, semaine
            case finMoisCourt = "fin_mois_court"
        }
    }

    public struct Tikkun: Sendable, Equatable, Decodable {
        public let ordre: [Int]
    }

    /// Un temps de la hitbodedout guidée : l'hébreu vocalisé et la source viennent du Kotlin.
    public struct Mouvement: Sendable, Equatable, Decodable {
        public let cle: String
        public let he: String
        public let titre: String
        public let invite: String
        public let illustration: String
        public let source: String
    }

    public struct Hitbodedut: Sendable, Equatable, Decodable {
        public let mouvements: [Mouvement]
    }

    public struct Sujet: Sendable, Equatable, Decodable {
        public let cle: String
        public let titre: String
    }

    public struct SujetsTefila: Sendable, Equatable, Decodable {
        public let sousSection: String
        public let sujets: [Sujet]

        enum CodingKeys: String, CodingKey {
            case sujets
            case sousSection = "sous_section"
        }
    }

    public struct Ecran: Sendable, Equatable, Decodable {
        public let cle: String
        public let titre: String
        public let corps: String
        public let illustration: String
        public let choixAdresse: Bool
        public let choixDuree: Bool
        public let choixRappel: Bool

        enum CodingKeys: String, CodingKey {
            case cle, titre, corps, illustration
            case choixAdresse = "choix_adresse", choixDuree = "choix_duree", choixRappel = "choix_rappel"
        }
    }

    public struct Presentation: Sendable, Equatable, Decodable {
        public let version: Int
        public let durees: [Int]
        public let ecrans: [Ecran]
    }

    public struct Conseil: Sendable, Equatable, Decodable {
        public let numero: Int
        public let titre: String
        public let corps: String
        public let illustration: String
    }

    // MARK: Halakha

    /// Une plage de jours d'un mois de KosherJava, et sa fenêtre de fête (YalkutYosef.fenetre).
    public struct Plage: Sendable, Equatable, Decodable {
        public let mois: Int
        public let debut: Int
        public let fin: Int
        public let fenetre: String

        public init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            mois = try c.decode(Int.self)
            debut = try c.decode(Int.self)
            fin = try c.decode(Int.self)
            fenetre = try c.decode(String.self)
        }
    }

    public struct YalkutYosef: Sendable, Equatable, Decodable {
        public let parJour: Int
        /// « simple » et « embolismique ».
        public let fenetres: [String: [Plage]]

        enum CodingKeys: String, CodingKey {
            case fenetres
            case parJour = "par_jour"
        }

        /// La fenêtre d'un jour hébreu, ou nil : la table rend ce que YalkutYosef.fenetre rendait.
        public func fenetre(mois: Int, jour: Int, embolismique: Bool) -> String? {
            fenetres[embolismique ? "embolismique" : "simple"]?
                .first { $0.mois == mois && (($0.debut)...($0.fin)).contains(jour) }?.fenetre
        }
    }

    public struct BenIshHai: Sendable, Equatable, Decodable {
        /// Les parachiot jointes de KosherJava et leurs deux parts.
        public let jointes: [String: [String]]
    }

    // MARK: Calendrier et zmanim

    public struct Fete: Sendable, Equatable, Decodable {
        /// JewishCalendar.getYomTovIndex().
        public let index: Int
        public let cle: String
    }

    public struct Calendrier: Sendable, Equatable, Decodable {
        public let fetes: [Fete]
        /// La clé d'une fête dans une ville murée (Pourim, Chouchan Pourim).
        public let muree: [String: String]
        public let conditions: [String]
        public let derivees: [String]
    }

    public struct ZmanDuProfil: Sendable, Equatable, Decodable {
        public let cle: String
        public let methode: String
        public let parametres: String
    }

    public struct Zmanim: Sendable, Equatable, Decodable {
        public let moteur: String
        public let profil: [ZmanDuProfil]
        public let allumage: String
        public let allumages: [Int]
        public let allumageDefaut: Int

        enum CodingKeys: String, CodingKey {
            case moteur, profil, allumage, allumages
            case allumageDefaut = "allumage_defaut"
        }
    }

    // MARK: Références, vol, personnage, polices

    public struct LivreCite: Sendable, Equatable, Decodable {
        public let fr: String
        public let en: String
        public let he: String
    }

    public struct References: Sendable, Equatable, Decodable {
        /// Reference.LIVRES, du plus long au plus court.
        public let livres: [LivreCite]
        /// Reference.lettres(n) pour n de 1 à 999 : `lettres[n - 1]`.
        public let lettres: [String]
    }

    /// Une compagnie : son nom, puis son code IATA.
    public struct Compagnie: Sendable, Equatable, Decodable {
        public let nom: String
        public let code: String

        public init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            nom = try c.decode(String.self)
            code = try c.decode(String.self)
        }
    }

    public struct SaisieVol: Sendable, Equatable, Decodable {
        /// Dans l'ordre du Kotlin : à longueur égale, la première nommée l'emporte.
        public let compagnies: [Compagnie]
        /// Les villes à plusieurs aéroports → celui qu'on prend (SaisieVol.PRINCIPAL).
        public let villes: [String: String]
        public let mots: [String]
        public let mois: [String: Int]
        /// Jour de la semaine, 1 lundi … 7 dimanche (java.time.DayOfWeek).
        public let jours: [String: Int]
        public let vers: [String]
        public let de: [String]
    }

    public struct Territoire: Sendable, Equatable, Decodable {
        /// (latitude, longitude), dans l'ordre du contour.
        public let contour: [[Double]]
    }

    public struct DirectionJerusalem: Sendable, Equatable, Decodable {
        public let latitude: Double
        public let longitude: Double
        public let tolerance: Double
    }

    public struct Personnage: Sendable, Equatable, Decodable {
        public let appel: [String]
        public let seance: [String]
        public let joie: [String]
        public let accueil: String
        public let journal: String
        public let etude: String
        public let lecture: String
        public let tehilim: String
        /// Moment (Chizuk.kt) → illustration.
        public let moments: [String: String]
        /// « source » et « article » → illustration.
        public let bibliotheque: [String: String]
    }

    public struct PoseFeminine: Sendable, Equatable, Decodable {
        public let masculin: String
        public let feminin: String
    }

    public struct Police: Sendable, Equatable, Decodable {
        public let cle: String
        public let libelle: String
        /// Les fichiers de Polices/ (sans extension), du regular au gras ; aucun : la police du système.
        public let fichiers: [String]
        /// Les signes absents de la police, masqués à l'affichage, en points de code hexadécimaux.
        public let absents: [String]
    }
}
