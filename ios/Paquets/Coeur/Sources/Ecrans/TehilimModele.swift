import Foundation
import Observation
import Coeur

// Le livre de Tehilim (TehilimActivity.kt, activity_tehilim.xml, demande du 04/10) : la portion du jour, des deux
// façons de dire tout le livre (en un mois hébraïque, en une semaine), puis les 150 psaumes, un toucher chacun.
// Au-dessus des deux portions, la ligne des marque-pages des Tehilim (RepriseFavoris.ligneSignets(c, "t"), 28/10),
// qui ouvre leur feuille (RepriseFavoris.listeSignets).
//
// Les numéros suivent la langue de l'app (TehilimTexte) : lettres en hébreu, chiffres sinon. Le jour montré est
// celui du téléphone (`LocalDate.now()`), relu à chaque retour sur l'écran (onResume : `actualiser()`). Les
// marque-pages sont lus dans le `Magasin` à chaque fois : un marque-page posé dans la lecture se voit au retour.
//
// Store.swift de Coeur n'est pas encore construit (`enChantierSources`) : la lecture et l'écriture des marque-pages
// (« marques_pages ») sont reprises ici (`TehilimMarques`), à l'identique, sur `Reglages.brut`.

/// Où en est un écran des Tehilim, du Tikoun ou des Tfilot.
public enum TehilimEtat: Sendable, Equatable {
    /// Les contenus se lisent.
    case chargement
    case pret
    /// Le contenu n'a pu être lu (fichier absent ou illisible) : Android s'arrêterait ; l'écran le dit.
    case erreur
}

/// Les numéros et les titres de passages dans la langue de l'app (TehilimTexte de TehilimActivity.kt).
public enum TehilimTexte {

    /// Un numéro : en lettres en hébreu (« כ״ה »), en chiffres sinon.
    public static func nombre(_ n: Int, langue: String) -> String {
        ChizukCard.language(langue).egalUnites("he") ? Reference.lettres(n) : String(n)
    }

    /// Le titre d'un passage : « Tehilim 25 », « Tehilim 1 à 9 », « Tehilim 119, versets 1 à 96 ».
    public static func portion(_ p: Portion, langue: String) -> Libelle {
        if p.partielle {
            return Libelle("tehilim_range_verses", .texte(nombre(p.debut, langue: langue)),
                           .texte(nombre(p.debutVerset, langue: langue)), .texte(nombre(p.finVerset ?? 0, langue: langue)))
        }
        if p.debut == p.fin {
            return Libelle("tehilim_single", .texte(nombre(p.debut, langue: langue)))
        }
        return Libelle("tehilim_range", .texte(nombre(p.debut, langue: langue)), .texte(nombre(p.fin, langue: langue)))
    }

    /// `NumberFormat.getIntegerInstance(locale).format(n)` : « 2 527 » en français (espace fine insécable,
    /// U+202F, celle d'ICU), « 2,527 » en anglais et en hébreu.
    public static func groupe(_ n: Int, langue: String) -> String {
        let separateur = ChizukCard.language(langue).egalUnites("fr") ? "\u{202F}" : ","
        var chiffres = String(n.magnitude)
        var morceaux: [String] = []
        while chiffres.count > 3 {
            morceaux.insert(String(chiffres.suffix(3)), at: 0)
            chiffres = String(chiffres.dropLast(3))
        }
        morceaux.insert(chiffres, at: 0)
        return (n < 0 ? "-" : "") + morceaux.joined(separator: separateur)
    }

    /// `dayOfWeek.getDisplayName(TextStyle.FULL, locale)`, la première lettre en capitale : « Dimanche »,
    /// « Sunday », « יום ראשון ». `jourDeSemaine` : 1 = dimanche … 7 = samedi (`JourCivil.jourDeSemaine`).
    public static func nomDuJour(_ jourDeSemaine: Int, langue: String) -> String {
        let rang = Kotlin.floorMod(jourDeSemaine - 1, 7)
        let code = ChizukCard.language(langue)
        if code.egalUnites("he") { return joursHe[rang] }
        if code.egalUnites("fr") { return joursFr[rang] }
        return joursEn[rang]
    }

    private static let joursFr = ["Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"]
    private static let joursEn = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private static let joursHe = ["יום ראשון", "יום שני", "יום שלישי", "יום רביעי", "יום חמישי", "יום שישי", "יום שבת"]
}

/// Ce qu'on ouvre dans la lecture des Tehilim : les extras de TehilimLectureActivity (DEBUT, FIN, DEBUT_VERSET,
/// FIN_VERSET, MARQUE_VERSET), tels quels ; `portion` les ramène dans le livre comme Android.
public struct TehilimLectureCible: Sendable, Hashable {
    /// DEBUT (1 par défaut).
    public let debut: Int
    /// FIN (1 par défaut).
    public let fin: Int
    /// DEBUT_VERSET (1 par défaut).
    public let debutVerset: Int
    /// FIN_VERSET : 0 (par défaut) jusqu'au dernier verset.
    public let finVerset: Int
    /// MARQUE_VERSET : ouvert depuis un marque-page, ce verset en haut de l'écran ; 0 sinon.
    public let marqueVerset: Int

    public init(debut: Int = 1, fin: Int = 1, debutVerset: Int = 1, finVerset: Int = 0, marqueVerset: Int = 0) {
        self.debut = debut
        self.fin = fin
        self.debutVerset = debutVerset
        self.finVerset = finVerset
        self.marqueVerset = marqueVerset
    }

    /// `TehilimLectureActivity.ouvrir(context, p)`.
    public static func portion(_ p: Portion) -> TehilimLectureCible {
        TehilimLectureCible(debut: p.debut, fin: p.fin, debutVerset: p.debutVerset, finVerset: p.finVerset ?? 0)
    }

    /// `TehilimLectureActivity.ouvrirMarque(context, m)` : DEBUT = FIN = le psaume, MARQUE_VERSET = le verset.
    public static func marque(psaume: Int, verset: Int) -> TehilimLectureCible {
        TehilimLectureCible(debut: psaume, fin: psaume, marqueVerset: verset)
    }

    /// La portion lue : les psaumes ramenés de 1 à 150 (`coerceIn`), FIN_VERSET 0 pour « jusqu'au bout ».
    public var portion: Portion {
        Portion(TehilimLectureCible.borne(debut), TehilimLectureCible.borne(fin), debutVerset,
                finVerset > 0 ? finVerset : nil)
    }

    private static func borne(_ n: Int) -> Int {
        min(max(n, 1), Tehilim.nombreDePsaumes)
    }
}

/// Les écrans qu'ouvre le livre de Tehilim, pour `navigationDestination(for:)`.
public enum TehilimRoute: Sendable, Hashable {
    /// TehilimLectureActivity, sur une portion ou un marque-page.
    case lecture(TehilimLectureCible)

    /// Ce qu'ouvre la lecture.
    public var cible: TehilimLectureCible {
        switch self {
        case .lecture(let cible): cible
        }
    }
}

/// Une case de la grille des 150 psaumes.
public struct TehilimCase: Sendable, Equatable, Identifiable {
    /// Le numéro du psaume, 1 à 150.
    public let id: Int
    /// Le numéro affiché : « כ״ה » en hébreu, « 25 » sinon.
    public let numero: String
    /// Pour la lecture d'écran : « Tehilim 25 » (`contentDescription`).
    public let description: Libelle
    public let route: TehilimRoute
}

/// Une ligne de cinq cases.
public struct TehilimRangee: Sendable, Equatable, Identifiable {
    /// Le rang de la ligne, à partir de 0.
    public let id: Int
    public let cases: [TehilimCase]
}

/// La ligne « Marque-pages · n  › » au-dessus des portions du jour.
public struct TehilimSignets: Sendable, Equatable {
    /// « Marque-pages », suivi dans la vue de « · », du nombre, puis de deux espaces et « › ».
    public let titre: Libelle
    public let nombre: Int
    /// L'icône des marque-pages de prière (`SiddurLectureActivity.icone(false)`), teinte de la couleur de marque,
    /// 18 pt, en fin de ligne.
    public let icone: String
}

/// Une puce de la feuille des marque-pages : « Tout » ou « Tehilim ».
public struct TehilimFiltreSignets: Sendable, Equatable, Identifiable {
    /// « * » (tous) ou « t » (les Tehilim).
    public let id: String
    public let libelle: Libelle
}

/// Un marque-page dans la feuille : « Tehilim » en petit, les premiers mots du verset dessous.
public struct TehilimSignetLigne: Sendable, Equatable, Identifiable {
    /// Son rang parmi les marque-pages des Tehilim, dans l'ordre où ils sont gardés : unique.
    public let id: Int
    /// « Tehilim » (13 pt, discret, de droite à gauche).
    public let titre: Libelle
    /// « כ״ה, ג׳ · לדוד אליך ה׳ נפשי… » : le psaume, le verset et ses premiers mots, suivis de « … » (17 pt,
    /// encre, une ligne, de droite à gauche, police de lecture), les signes absents de la police masqués.
    public let apercu: String
    /// L'icône des marque-pages de prière, 14 pt, teinte de la couleur de marque, après le titre.
    public let icone: String
    /// La lecture du psaume, le verset en haut de l'écran.
    public let route: TehilimRoute
}

/// Les marque-pages de Store.kt (`Store.marques`, `Store.basculerMarque`), sous la clé « marques_pages ».
enum TehilimMarques {
    private static let cle = "marques_pages"

    /// Toutes les marques gardées, dans leur ordre (la plus récente en tête).
    static func toutes(_ reglages: Reglages) -> [MarquesPages.Marque] {
        if case .chaine(let texte)? = reglages.brut[cle] {
            return MarquesPages.decoder(texte)
        }
        return []
    }

    /// Pose ou retire ; vrai si la marque est maintenant posée.
    @discardableResult
    static func basculer(_ reglages: inout Reglages, _ m: MarquesPages.Marque) -> Bool {
        let l = MarquesPages.basculer(toutes(reglages), m)
        var brut = reglages.brut
        brut[cle] = .chaine(MarquesPages.encoder(l))
        reglages = Reglages(brut: brut)
        return l.contains { $0.memePlace(m) }
    }
}

/// Le livre de Tehilim : la portion du jour, la grille des psaumes, les marque-pages.
@MainActor
@Observable
public final class TehilimModele {
    private let magasin: Magasin
    private let contenus: ContenusApp
    private let horloge: any Horloge
    /// « fr », « en » ou « he ».
    public let langue: String

    /// Le livre se lit : seul le compte du bandeau l'attend ; les portions et la grille n'en ont pas besoin.
    public private(set) var etat: TehilimEtat = .chargement
    /// Le jour dont on montre les portions : aujourd'hui, relu par `actualiser()`.
    public private(set) var jour: JourCivil
    private var versetsTotal: Int?

    /// La feuille des marque-pages est ouverte (le dialogue d'Android).
    public private(set) var feuilleSignetsOuverte = false
    /// La puce choisie dans la feuille : « * » à chaque ouverture.
    public private(set) var filtreSignets = "*"

    public init(magasin: Magasin, contenus: ContenusApp, horloge: any Horloge, langue: String) {
        self.magasin = magasin
        self.contenus = contenus
        self.horloge = horloge
        self.langue = ChizukCard.language(langue)
        jour = horloge.aujourdhui
    }

    /// Lit le livre (pour le compte des versets). À appeler à l'apparition de l'écran.
    public func charger() async {
        do {
            versetsTotal = try await contenus.tehilim().versetsTotal
            etat = .pret
        } catch {
            etat = .erreur
        }
    }

    /// Le retour sur l'écran (onResume) : le jour a pu changer depuis l'ouverture.
    public func actualiser() {
        jour = horloge.aujourdhui
    }

    // MARK: Le bandeau

    /// « Tehilim ».
    public var titre: Libelle {
        Libelle("tehilim_title")
    }

    /// « 150 Tehilim, 2 527 versets » ; nil tant que le livre n'est pas lu.
    public var sousTitre: Libelle? {
        guard let versetsTotal else { return nil }
        return Libelle("tehilim_count", .entier(Tehilim.nombreDePsaumes),
                       .texte(TehilimTexte.groupe(versetsTotal, langue: langue)))
    }

    /// Le personnage au livre (char_tehilim), au féminin pour qui a choisi צדקת.
    public var image: String {
        Personnage.pour(Adresse.parse(magasin.reglages.adresse), Poses.reading)
    }

    // MARK: La portion du jour

    /// Le jour du mois hébraïque (1 à 30) et la longueur du mois (29 ou 30), le jour changeant à minuit.
    public var jourHebreu: (jour: Int, longueur: Int) {
        CycleTehilim.jourHebreu(jour)
    }

    /// La portion du jour selon le mois hébraïque.
    public var portionDuMois: Portion {
        let (jourDuMois, longueur) = jourHebreu
        return CycleTehilim.duMois(jourDuMois, longueur)
    }

    /// « Jour 5 du mois : Tehilim 29 à 34 ».
    public var etatMois: Libelle {
        Libelle("tehilim_month_state", .texte(TehilimTexte.nombre(jourHebreu.jour, langue: langue)),
                .libelle(TehilimTexte.portion(portionDuMois, langue: langue)))
    }

    /// La ligne « Selon le jour du mois » ouvre sa portion.
    public var routeMois: TehilimRoute {
        .lecture(.portion(portionDuMois))
    }

    /// La portion du jour selon la semaine, du dimanche au Chabbat.
    public var portionDeLaSemaine: Portion {
        CycleTehilim.deLaSemaine(jour.jourDeSemaine)
    }

    /// « Lundi : Tehilim 30 à 50 ».
    public var etatSemaine: Libelle {
        Libelle("tehilim_week_state", .texte(TehilimTexte.nomDuJour(jour.jourDeSemaine, langue: langue)),
                .libelle(TehilimTexte.portion(portionDeLaSemaine, langue: langue)))
    }

    /// La ligne « Selon le jour de la semaine » ouvre sa portion.
    public var routeSemaine: TehilimRoute {
        .lecture(.portion(portionDeLaSemaine))
    }

    // MARK: La grille

    /// Cinq psaumes par ligne.
    public static let parLigne = 5

    /// Les 150 psaumes en lignes de cinq ; chaque case ouvre son psaume.
    public var grille: [TehilimRangee] {
        var rangees: [TehilimRangee] = []
        var cases: [TehilimCase] = []
        for n in 1...Tehilim.nombreDePsaumes {
            let seul = Portion(n, n)
            cases.append(TehilimCase(id: n, numero: TehilimTexte.nombre(n, langue: langue),
                                     description: TehilimTexte.portion(seul, langue: langue),
                                     route: .lecture(.portion(seul))))
            if cases.count == TehilimModele.parLigne {
                rangees.append(TehilimRangee(id: rangees.count, cases: cases))
                cases = []
            }
        }
        if !cases.isEmpty {
            rangees.append(TehilimRangee(id: rangees.count, cases: cases))
        }
        return rangees
    }

    // MARK: Les marque-pages des Tehilim

    /// L'icône des marque-pages de prière (`SiddurLectureActivity.icone(false)`).
    public static let iconeSignets = "ic_marque_priere"

    /// Les marque-pages des Tehilim (clé « t:tehilim »), dans l'ordre où ils sont gardés.
    public var signets: [MarquesPages.Marque] {
        TehilimMarques.toutes(magasin.reglages).filter { $0.cle.egalUnites(TehilimLectureModele.cleMarques) }
    }

    /// La ligne des marque-pages ; nil sans marque-page (Android ne la pose pas).
    public var ligneSignets: TehilimSignets? {
        let nombre = signets.count
        guard nombre > 0 else { return nil }
        return TehilimSignets(titre: Libelle("marques_titre"), nombre: nombre, icone: TehilimModele.iconeSignets)
    }

    /// Le titre de la feuille, « Marque-pages » ; un bouton OK la ferme.
    public var titreFeuilleSignets: Libelle {
        Libelle("marques_titre")
    }

    /// Toucher la ligne des marque-pages : la feuille s'ouvre sur « Tout ». Rien sans marque-page.
    public func ouvrirSignets() {
        guard ligneSignets != nil else { return }
        filtreSignets = "*"
        feuilleSignetsOuverte = true
    }

    public func fermerSignets() {
        feuilleSignetsOuverte = false
    }

    /// Les puces, une seule cochée (`filtreSignets`) : « Tout », « Tehilim ». Vide sans marque-page.
    public var filtresSignets: [TehilimFiltreSignets] {
        guard !signets.isEmpty else { return [] }
        return [
            TehilimFiltreSignets(id: "*", libelle: Libelle("recherche_tout")),
            TehilimFiltreSignets(id: "t", libelle: Libelle("tehilim_title")),
        ]
    }

    /// Choisit une puce ; une puce qui n'existe pas ne change rien.
    public func choisirFiltreSignets(_ id: String) {
        guard filtresSignets.contains(where: { $0.id == id }) else { return }
        filtreSignets = id
    }

    /// Les marque-pages de la puce choisie (les deux puces les montrent tous), dans l'ordre du livre : psaume,
    /// puis verset ; à égalité, l'ordre où ils sont gardés.
    public var lignesSignets: [TehilimSignetLigne] {
        let police = PoliceHebraique.Police(rawValue: magasin.reglages.lecturePolice) ?? .serif
        var retenues: [(rang: Int, marque: MarquesPages.Marque)] = []
        for (rang, marque) in signets.enumerated() {
            retenues.append((rang: rang, marque: marque))
        }
        retenues.sort { a, b in
            if a.marque.section != b.marque.section { return a.marque.section < b.marque.section }
            if a.marque.bloc != b.marque.bloc { return a.marque.bloc < b.marque.bloc }
            return a.rang < b.rang
        }
        var lignes: [TehilimSignetLigne] = []
        for retenue in retenues {
            lignes.append(TehilimSignetLigne(
                id: retenue.rang, titre: Libelle("tehilim_title"),
                apercu: PoliceHebraique.masque(retenue.marque.apercu + "…", police: police),
                icone: TehilimModele.iconeSignets,
                route: .lecture(.marque(psaume: retenue.marque.section, verset: retenue.marque.bloc))))
        }
        return lignes
    }

    /// Toucher un marque-page : la feuille se ferme, et la vue ouvre ce que la ligne désigne.
    @discardableResult
    public func choisirSignet(_ ligne: TehilimSignetLigne) -> TehilimRoute {
        feuilleSignetsOuverte = false
        return ligne.route
    }
}
