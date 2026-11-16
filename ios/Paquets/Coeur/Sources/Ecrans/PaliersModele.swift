import Foundation
import Observation
import Coeur

// L'écran « Trophées et paliers » (PaliersActivity.kt ; maquette du 15/10, lot du 16/10, retouches du 04/11).
//
// En tête, le grade (`Trophees.grade`), ce qu'il reste pour le suivant, les trois trophées les plus proches et
// le partage du grade ; un filtre par famille ; puis une seule ligne verticale : au-dessus, les trophées
// gagnés, chacun du métal du grade d'alors et daté du jour où il l'a été, une bannière à chaque changement de
// grade ; au milieu, « Vous êtes ici » et le prochain objectif (l'écran s'ouvre là) ; en dessous, les
// suivants, en gris. Chaque trophée s'ouvre en fiche. À l'ouverture, la ligne se remplit jusqu'à « Vous êtes
// ici », les nouveaux se retournent et scintillent ; un nouveau grade se fête une fois. Les records en bas.

/// Le haut de l'écran : le grade, la barre vers le suivant, les plus proches, le partage.
public struct PaliersEnTete: Sendable, Hashable {
    public let grade: Trophees.Metal
    /// Les trophées gagnés.
    public let compte: Int
    /// « Grade Argent » (18 pt, gras, encre).
    public let titre: Libelle
    /// « 12 trophées gagnés · encore 13 pour Or », ou « 60 trophées gagnés » au dernier grade (13 pt, atténué).
    public let sous: Libelle
    /// De 0 à 1, depuis le seuil du grade jusqu'à celui du suivant ; nil au dernier grade (pas de barre).
    public let barre: Float?
    /// « Les plus proches » ; nil quand il n'y en a aucun (et la section disparaît).
    public let prochesTitre: Libelle?
    /// Au plus trois, sans le prochain (qui a déjà sa carte « Vous êtes ici »).
    public let proches: [PaliersProche]
    /// « Partager mon grade » ; nil sans trophée gagné (pas de bouton).
    public let partager: Libelle?

    /// La couleur de la barre : le ton foncé du grade ; son fond, la même à 0x30 d'opacité.
    public var couleurBarre: TropheeCouleur { TropheeTeintes.de(grade).fonce }
}

/// Un des plus proches : l'objet (gris, 30 pt, opacité 0,85), ce qu'il demande, où l'on en est.
public struct PaliersProche: Sendable, Hashable, Identifiable {
    public let niveau: Trophees.Niveau
    public var id: String { niveau.cle }
    /// « 40 jours de pratique » (14 pt, encre).
    public let description: Libelle
    /// « 31 / 40 » (13 pt, gras, couleur de marque), borné au seuil.
    public let progres: Libelle

    /// Lu d'un seul tenant : la description, puis le progrès (joints par « , »).
    public var accessibilite: [Libelle] { [description, progres] }
}

/// Une puce du filtre : « Tous », puis chaque famille.
public struct PaliersFiltre: Sendable, Hashable, Identifiable {
    /// nil : toutes les familles.
    public let famille: Trophees.Famille?
    public var id: String { famille?.cle ?? "tous" }
    public let titre: Libelle
    /// La puce choisie : fond de marque, texte sur marque ; les autres : bord fin (couleur « line »), encre.
    public let choisi: Bool
    /// « Montrer les trophées : Tous ».
    public let accessibilite: Libelle
}

/// La bannière d'un changement de grade sur la ligne (aux 10ᵉ, 25ᵉ et 50ᵉ trophées, sans filtre).
public struct PaliersBanniere: Sendable, Hashable {
    /// L'encre d'une bannière atteinte, lisible sur le dégradé du métal dans les deux thèmes.
    public static let encreAtteinte = TropheeCouleur(0x1A, 0x13, 0x06)

    public let grade: Trophees.Metal
    /// Le rang du trophée qui fait atteindre le grade.
    public let rang: Int
    /// Atteint : vive, du dégradé du métal ; à venir : grise.
    public let atteint: Bool

    public init(grade: Trophees.Metal, rang: Int, atteint: Bool) {
        self.grade = grade
        self.rang = rang
        self.atteint = atteint
    }

    /// « Grade Argent atteint » ou « Grade Argent » (15 pt, gras).
    public var titre: Libelle {
        atteint ? Libelle("grade_atteint", .libelle(TropheeTextes.metal(grade)))
                : TropheeTextes.grade(grade)
    }

    /// « au 10ᵉ trophée » (13 pt, opacité 0,85).
    public var sous: Libelle { Libelle("grade_au", .entier(rang)) }

    /// La médaille de 34 pt : du grade, ou grise à venir.
    public var medaille: Trophees.Metal? { atteint ? grade : nil }

    /// Le fond, un dégradé de gauche à droite (clair puis foncé) ; nil à venir : le jeton « line » de la
    /// palette, uni (visible dans les deux thèmes, 04/11).
    public var degrade: TropheeTeintes? { atteint ? TropheeTeintes.de(grade) : nil }

    /// L'encre des deux textes ; nil à venir : le jeton « muted » de la palette.
    public var encre: TropheeCouleur? { atteint ? PaliersBanniere.encreAtteinte : nil }
}

/// Une étape de la ligne : le trait, l'objet, ce qu'il demande, le petit texte.
public struct PaliersEtape: Sendable, Hashable {
    public let niveau: Trophees.Niveau
    /// Le métal de l'objet et du trait : celui du grade que ce trophée a fait atteindre ; nil (gris) à venir.
    public let metal: Trophees.Metal?
    public let gagne: Bool
    /// Ce qu'il demande (15 pt ; gagné : gras, encre ; à venir : atténué).
    public let description: Libelle
    /// Gagné le…, gagné, ou « 3 / 7 » (12 pt, atténué) ; nil : rien sous la description.
    public let sous: TropheeSous?
    /// Gagné depuis la dernière visite : il se retourne puis scintille.
    public let neuf: Bool
    /// L'étape pousse (le trait grandit vers le bas, puis l'objet paraît) après ce délai (ms) ; nil : pas
    /// d'animation (filtre changé, ou étape à venir).
    public let retardPousse: Int?
    /// Le retournement d'un trophée neuf, après ce délai (ms) ; nil s'il n'est pas neuf.
    public let retardRetournement: Int?

    /// Le côté de l'objet : 52 pt gagné, 44 pt à venir (dans une colonne de 60 × 72 pt).
    public var coteObjet: Double { gagne ? 52 : 44 }
    /// L'opacité de l'objet : un léger voile sur le gris (04/11).
    public var opaciteObjet: Double { metal == nil ? 0.8 : 1 }
    /// Le trait : un dégradé de haut en bas (clair puis foncé) du métal ; nil à venir : le jeton « muted »
    /// à 0x40 d'opacité, uni.
    public var trait: TropheeTeintes? { metal.map { TropheeTeintes.de($0) } }

    /// Lu d'un seul tenant : la description, puis le petit texte (joints par « , »).
    public func accessibilite(dateLongue: (JourCivil) -> String) -> [Libelle] {
        guard let sous else { return [description] }
        return [description, sous.libelle(dateLongue: dateLongue)]
    }
}

/// La carte « Vous êtes ici · prochain objectif ».
public struct PaliersIci: Sendable, Hashable {
    /// « VOUS ÊTES ICI · PROCHAIN OBJECTIF » (13 pt, gras, marque, interlettrage 0,06 em).
    public static let titre = Libelle("trophees_ici")

    public let niveau: Trophees.Niveau
    /// Ce qu'il demande (19 pt, gras, encre).
    public let description: Libelle
    /// La barre, de 0 à 1 (10 pt de haut, couleur de marque).
    public let fraction: Float
    /// La valeur atteinte, bornée au seuil.
    public let valeur: Int
    public let seuil: Int
    /// Presque plein (à 90 % ou plus) : la barre pulse une fois, à l'ouverture.
    public var pulser: Bool { fraction >= 0.9 }

    /// « 31 / 40 · encore 9 » (14 pt, gras, marque).
    public var encore: Libelle { encore(valeur) }

    /// Le même texte pendant que le compte monte de 0 à `valeur` (animation D) : `x` à la place de la valeur.
    public func encore(_ x: Int) -> Libelle {
        TropheeTextes.encore(x, seuil)
    }
}

/// Une ligne de la colonne des trophées, dans l'ordre.
public enum PaliersLigne: Sendable, Hashable, Identifiable {
    case banniere(PaliersBanniere)
    case etape(PaliersEtape)
    case ici(PaliersIci)
    /// « Tous les trophées sont gagnés ! » (18 pt, gras, encre), à la place de « Vous êtes ici ».
    case tousGagnes(Libelle)
    /// « … et 97 autres trophées plus loin » (13 pt, atténué, centré).
    case autres(Libelle)

    public var id: String {
        switch self {
        case .banniere(let b): "banniere-\(b.rang)-\(b.atteint)"
        case .etape(let e): e.niveau.cle
        case .ici: PaliersModele.idIci
        case .tousGagnes: "tous"
        case .autres: "autres"
        }
    }
}

/// La carte des records.
public struct PaliersRecords: Sendable, Hashable {
    /// « Records » (17 pt, gras, encre).
    public let titre: Libelle
    /// Plus longue série, meilleure journée, meilleure semaine, meilleur mois (15 pt, encre).
    public let lignes: [Libelle]
}

/// La fête d'un nouveau grade (PaliersActivity.fete), une fois : des rayons lents derrière la médaille, qui
/// passe de l'ancien métal au nouveau.
public struct PaliersFeteGrade: Sendable, Hashable {
    public let nouveau: Trophees.Metal
    /// Le métal d'avant, qui s'efface.
    public let ancien: Trophees.Metal
    public let compte: Int
    /// « Nouveau grade : Argent » (24 pt, gras, encre, centré).
    public let titre: Libelle
    /// « 10 trophées gagnés » (15 pt, atténué, centré).
    public let sous: Libelle
    /// « Prochain grade : Or, au 25ᵉ trophée. » (13 pt, atténué, centré) ; nil au dernier grade.
    public let prochain: Libelle?
    /// « Continuer ».
    public let bouton = Libelle("celebration_continue")

    public init(grade: Trophees.Metal, compte: Int) {
        nouveau = grade
        ancien = Trophees.Metal.allCases[max(grade.ordinal - 1, 0)]
        self.compte = compte
        titre = Libelle("grade_nouveau", .libelle(TropheeTextes.metal(grade)))
        sous = Libelle("grade_sous_max", .entier(compte))
        if let suivant = Trophees.seuilsGrades.first(where: { $0 > compte }) {
            prochain = Libelle("grade_prochain", .libelle(TropheeTextes.metal(Trophees.grade(suivant))), .entier(suivant))
        } else {
            prochain = nil
        }
    }

    /// Les rayons : le ton clair du nouveau métal, à 0x70 d'opacité, en dégradé radial vers le transparent.
    public var rayons: TropheeCouleur { TropheeTeintes.de(nouveau).clair.opacite(0x70) }
}

/// Le partage du grade (PaliersActivity.partager) : une image carrée et une phrase.
public struct PaliersPartage: Sendable, Hashable {
    public let grade: Trophees.Metal
    public let compte: Int

    public init(grade: Trophees.Metal, compte: Int) {
        self.grade = grade
        self.compte = compte
    }

    /// Le texte joint à l'image (EXTRA_TEXT) : « Grade Argent sur MyHitbodedut : 12 trophées, jour après jour. »
    public var texte: Libelle {
        Libelle("grade_partage_texte", .libelle(TropheeTextes.metal(grade)), .entier(compte))
    }
    /// Le titre du choix de l'app (createChooser) : « Partager mon grade ».
    public var titreChoix: Libelle { Libelle("grade_partager") }
    /// Sur l'image : « Grade Argent » (gras).
    public var titreImage: Libelle { TropheeTextes.grade(grade) }
    /// Sur l'image : « 12 trophées gagnés ».
    public var sousImage: Libelle { Libelle("grade_sous_max", .entier(compte)) }
    /// Sur l'image, en pied : « MyHitbodedut » (gras, opacité 180/255).
    public var marque: Libelle { Libelle("app_name") }
}

/// Ce que l'écran calcule de la pratique à chaque ouverture.
struct PaliersDonnees: Sendable {
    let pratique: Trophees.Pratique
    /// Le jour de gain de chaque niveau gagné, par sa clé.
    let dates: [String: JourCivil]
    /// Les gagnés, dans l'ordre du chemin.
    let faits: [Trophees.Niveau]
    /// Le rang de chaque gagné parmi eux, de 1.
    let rangDe: [String: Int]
    let records: Paliers.Records
    /// Ce qui sera retenu comme vu.
    let marques: Set<String>
    let gagnes: Set<String>
}

/// L'écran des trophées et des paliers.
@MainActor
@Observable
public final class PaliersModele {

    /// Le titre du bandeau (21 pt, gras, blanc).
    nonisolated public static let titre = Libelle("trophees_paliers_titre")
    /// Les trophées à venir montrés sous « Vous êtes ici » ; le reste est annoncé d'une ligne.
    nonisolated public static let montres = 15
    /// L'identifiant de la ligne « Vous êtes ici », où l'écran défile à l'ouverture.
    nonisolated public static let idIci = "ici"

    private let magasin: Magasin
    private let horloge: any Horloge
    private var donnees: PaliersDonnees

    /// La famille montrée seule ; nil : toutes. À garder pour le rendre au retour (`@SceneStorage` de sa clé,
    /// `filtreCle`, comme `onSaveInstanceState` d'Android).
    public private(set) var filtre: Trophees.Famille?
    /// Vrai après l'ouverture : la ligne se remplit, les nouveaux se retournent, le compte monte. Faux dès que
    /// le filtre change (Android redessine sans animer).
    public private(set) var animer = false
    /// Les clés des trophées gagnés depuis la dernière visite (rien la toute première fois).
    public private(set) var neufs: Set<String> = []
    /// La fête d'un nouveau grade à montrer (un dialogue) ; nil sinon.
    public private(set) var feteGrade: PaliersFeteGrade? = nil
    /// La fiche ouverte ; nil sinon.
    public private(set) var fiche: TropheeFiche? = nil

    public init(magasin: Magasin, horloge: any Horloge, filtre: Trophees.Famille? = nil) {
        self.magasin = magasin
        self.horloge = horloge
        self.filtre = filtre
        donnees = PaliersModele.calculer(magasin: magasin, horloge: horloge)
    }

    /// La famille d'une clé gardée (`Famille.cle`) ; nil pour toutes ou une clé inconnue.
    nonisolated public static func famille(cle: String?) -> Trophees.Famille? {
        guard let cle else { return nil }
        return Trophees.Famille.allCases.first { $0.cle == cle }
    }

    /// La clé du filtre, à garder.
    public var filtreCle: String? { filtre?.cle }

    /// L'image du bandeau (64 × 78 pt sur grand écran, 50 × 60 sinon), au féminin pour qui l'a choisi.
    public var imageBandeau: String {
        Personnage.pour(Adresse.parse(magasin.reglages.adresse), "char_open_arms")
    }

    // MARK: Les actions

    /// L'écran paraît (onResume) : tout se recalcule, les nouveaux sont repérés et un nouveau grade se fête une
    /// fois ; puis le grade, les paliers et les trophées gagnés sont retenus comme vus (l'accueil ne les refête
    /// pas). Lève si les réglages ne s'écrivent pas (l'écran reste préparé).
    public func ouvrir() async throws {
        let d = PaliersModele.calculer(magasin: magasin, horloge: horloge)
        donnees = d
        let reglages = magasin.reglages
        if let vus = reglages.tropheesVus {
            var nouveaux = Set<String>()
            for t in d.faits where !vus.contains(t.cle) { nouveaux.insert(t.cle) }
            neufs = nouveaux
        } else {
            neufs = []
        }
        animer = true
        let n = d.faits.count
        let grade = Trophees.grade(n)
        // 0 sans trophée, 1 bronze, 2 argent… ; le bronze ne se fête pas (c'est le premier trophée).
        let niveauGrade = n == 0 ? 0 : grade.ordinal + 1
        if let vu = reglages.gradeVu, niveauGrade > vu, grade != .bronze {
            feteGrade = PaliersFeteGrade(grade: grade, compte: n)
        }
        let marques = d.marques
        let gagnes = d.gagnes
        try await magasin.modifierReglages { r in
            r.setGradeVu(niveauGrade)
            r.setPaliersVus(marques)
            r.setTropheesVus(gagnes)
        }
    }

    /// Une puce du filtre touchée : la ligne se redessine, sans animation.
    public func choisirFiltre(_ famille: Trophees.Famille?) {
        filtre = famille
        animer = false
        neufs = []
    }

    /// Un trophée touché (une étape, « Vous êtes ici » ou un des plus proches) : sa fiche s'ouvre.
    public func ouvrirFiche(_ niveau: Trophees.Niveau) {
        let d = donnees
        let rang = d.rangDe[niveau.cle] ?? (d.faits.count + 1)
        fiche = TropheeFiche(niveau: niveau, pratique: d.pratique, dates: d.dates, rangGlobal: rang)
    }

    public func fermerFiche() {
        fiche = nil
    }

    public func fermerFeteGrade() {
        feteGrade = nil
    }

    // MARK: Ce qui s'affiche

    /// Le prochain objectif montré : sans filtre, le plus proche d'être atteint (`Trophees.prochain`) ; filtré,
    /// le premier à gagner de la famille, dans l'ordre du chemin.
    private var prochainMontre: Trophees.Niveau? {
        let p = donnees.pratique
        guard let f = filtre else { return Trophees.prochain(p) }
        return Trophees.chemin.first { $0.famille == f && !Trophees.gagne(p, $0) }
    }

    public var enTete: PaliersEnTete {
        let d = donnees
        let p = d.pratique
        let n = d.faits.count
        let grade = Trophees.grade(n)
        let suivant = Trophees.seuilsGrades.first { $0 > n }
        let sous: Libelle
        var barre: Float?
        if let suivant {
            sous = Libelle("grade_sous", .entier(n), .entier(suivant - n),
                           .libelle(TropheeTextes.metal(Trophees.grade(suivant))))
            let de = Trophees.seuilsGrades.last { $0 <= n } ?? 0
            barre = Float(n - de) / Float(suivant - de)
        } else {
            sous = Libelle("grade_sous_max", .entier(n))
        }
        // Le prochain a déjà sa carte « Vous êtes ici » : pas deux fois le même (04/11). Sans filtre, toujours.
        let prochainCle = Trophees.prochain(p)?.cle
        var proches: [PaliersProche] = []
        for t in Trophees.plusProches(p, k: 4) where t.cle != prochainCle && proches.count < 3 {
            proches.append(PaliersProche(niveau: t, description: TropheeTextes.description(t),
                                         progres: TropheeTextes.progres(min(Trophees.valeur(p, t.famille), t.seuil), t.seuil)))
        }
        return PaliersEnTete(grade: grade, compte: n, titre: TropheeTextes.grade(grade), sous: sous, barre: barre,
                             prochesTitre: proches.isEmpty ? nil : Libelle("trophees_proches_titre"),
                             proches: proches, partager: n > 0 ? Libelle("grade_partager") : nil)
    }

    /// Les puces : « Tous », puis chaque famille dans l'ordre de Kotlin.
    public var filtres: [PaliersFiltre] {
        var familles: [Trophees.Famille?] = [nil]
        for f in Trophees.Famille.allCases { familles.append(f) }
        return familles.map { f in
            let titre = f.map { TropheeTextes.nom($0) } ?? Libelle("trophees_filtre_tous")
            return PaliersFiltre(famille: f, titre: titre, choisi: f == filtre,
                                 accessibilite: Libelle("trophees_filtre", .libelle(titre)))
        }
    }

    /// La ligne : les gagnés (et leurs bannières), « Vous êtes ici » (ou « tous gagnés »), les quinze suivants,
    /// puis le compte des autres.
    public var lignes: [PaliersLigne] {
        let d = donnees
        let p = d.pratique
        let f = filtre
        let n = d.faits.count
        // Filtrée, la ligne n'a pas de bannières ; le k-ième trophée (de 1) a le métal du grade qu'il fait atteindre.
        let passage: (Int) -> Bool = { k in f == nil && k > 0 && Trophees.seuilsGrades.contains(k) }
        let montres = d.faits.filter { f == nil || $0.famille == f }
        var resultat: [PaliersLigne] = []
        var rangNeuf = 0
        for (i, t) in montres.enumerated() {
            let k = d.rangDe[t.cle] ?? 0
            if passage(k) {
                resultat.append(.banniere(PaliersBanniere(grade: Trophees.grade(k), rang: k, atteint: true)))
            }
            let neuf = neufs.contains(t.cle)
            var retournement: Int?
            if neuf {
                retournement = 400 + rangNeuf * 120
                rangNeuf += 1
            }
            // B : la ligne se remplit, les six dernières étapes une à une.
            let pousse: Int? = animer ? max(i - (montres.count - 6), 0) * 90 : nil
            resultat.append(.etape(PaliersEtape(niveau: t, metal: Trophees.grade(k), gagne: true,
                                                description: TropheeTextes.description(t),
                                                sous: TropheeSous.pour(t, dates: d.dates), neuf: neuf,
                                                retardPousse: pousse, retardRetournement: retournement)))
        }
        let prochain = prochainMontre
        if let prochain {
            if passage(n + 1) {
                resultat.append(.banniere(PaliersBanniere(grade: Trophees.grade(n + 1), rang: n + 1, atteint: false)))
            }
            let valeur = min(Trophees.valeur(p, prochain.famille), prochain.seuil)
            resultat.append(.ici(PaliersIci(niveau: prochain, description: TropheeTextes.description(prochain),
                                            fraction: Trophees.fraction(p, prochain), valeur: valeur,
                                            seuil: prochain.seuil)))
        } else {
            resultat.append(.tousGagnes(Libelle("trophees_tous")))
        }
        let futurs = Trophees.chemin.filter { t in
            (f == nil || t.famille == f) && !Trophees.gagne(p, t) && t != prochain
        }
        for (k, t) in futurs.prefix(PaliersModele.montres).enumerated() {
            let rang = n + 2 + k
            if passage(rang) {
                resultat.append(.banniere(PaliersBanniere(grade: Trophees.grade(rang), rang: rang, atteint: false)))
            }
            let v = Trophees.valeur(p, t.famille)
            resultat.append(.etape(PaliersEtape(niveau: t, metal: nil, gagne: false,
                                                description: TropheeTextes.description(t),
                                                sous: v > 0 ? .progres(valeur: min(v, t.seuil), seuil: t.seuil) : nil,
                                                neuf: false, retardPousse: nil, retardRetournement: nil)))
        }
        if futurs.count > PaliersModele.montres {
            resultat.append(.autres(Libelle("trophees_autres", .entier(futurs.count - PaliersModele.montres))))
        }
        return resultat
    }

    /// Les records : la plus longue série, puis le meilleur jour, la meilleure semaine (dimanche à samedi) et le
    /// meilleur mois hébreu.
    public var records: PaliersRecords {
        let r = donnees.records
        return PaliersRecords(titre: Libelle("paliers_records"), lignes: [
            Libelle("record_serie", .libelle(TropheeTextes.valeurPalier(.serie, donnees.pratique.meilleureSerie))),
            Libelle("record_jour", .libelle(Store.formatDuration(r.jour))),
            Libelle("record_semaine", .libelle(Store.formatDuration(r.semaine))),
            Libelle("record_mois", .libelle(Store.formatDuration(r.mois))),
        ])
    }

    /// Le partage du grade ; nil sans trophée (pas de bouton).
    public var partage: PaliersPartage? {
        let n = donnees.faits.count
        return n > 0 ? PaliersPartage(grade: Trophees.grade(n), compte: n) : nil
    }

    // MARK: Le calcul

    private static func calculer(magasin: Magasin, horloge: any Horloge) -> PaliersDonnees {
        let journal = magasin.journal
        let reglages = magasin.reglages
        let aujourdhui = horloge.aujourdhui
        let fuseau = horloge.fuseau.identifiant
        let bilan = Store.bilan(journal: journal, reglages: reglages, aujourdhui: aujourdhui, fuseauTelephone: fuseau)
        let pratique = Store.pratique(journal: journal, reglages: reglages, aujourdhui: aujourdhui,
                                      fuseauTelephone: fuseau)
        let dates = Store.datesTrophees(journal: journal, reglages: reglages, fuseauTelephone: fuseau)
        let faits = Trophees.chemin.filter { Trophees.gagne(pratique, $0) }
        var rangDe: [String: Int] = [:]
        for (i, t) in faits.enumerated() { rangDe[t.cle] = i + 1 }
        // Le mois hébreu de chaque jour, hors d'Israël comme sur Android.
        let records = Paliers.records(bilan.minutes) { jour in
            let hebreu = CalendrierJuif.jour(jour, enIsrael: false)
            return String(hebreu.anneeHebraique) + "-" + String(hebreu.moisHebreu)
        }
        var gagnes = Set<String>()
        for t in Trophees.gagnes(pratique) { gagnes.insert(t.cle) }
        return PaliersDonnees(pratique: pratique, dates: dates, faits: faits, rangDe: rangDe, records: records,
                              marques: Paliers.marques(Paliers.etats(bilan), bilan), gagnes: gagnes)
    }
}
