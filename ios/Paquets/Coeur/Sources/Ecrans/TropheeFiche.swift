import Foundation
import Coeur

// Les textes des trophées (TropheesVue et PaliersVue, PaliersActivity.kt) et la fiche d'un trophée
// (FicheTrophee.kt, 16/10 point 1, 19/10), partagée par l'écran des paliers et la fête de l'accueil.

/// Les libellés des trophées et des paliers : les clés d'Android, que les règles de Coeur (Celebrations)
/// gardent pour elles.
public enum TropheeTextes {

    /// TropheesVue.nom : le nom de la famille (« trophee_serie »). Les clés suivent `Famille.cle`, une à une.
    public static func nom(_ f: Trophees.Famille) -> Libelle {
        Libelle("trophee_" + f.cle)
    }

    /// TropheesVue.description : ce que demande un seuil de la famille (« 40 jours de pratique »), au pluriel
    /// du seuil.
    public static func description(_ f: Trophees.Famille, seuil: Int) -> Libelle {
        Libelle.pluriel("trophee_" + f.cle + "_desc", quantite: seuil, .entier(seuil))
    }

    public static func description(_ n: Trophees.Niveau) -> Libelle {
        description(n.famille, seuil: n.seuil)
    }

    /// TropheesVue.metal : le métal, nommé.
    public static func metal(_ m: Trophees.Metal) -> Libelle {
        switch m {
        case .bronze: Libelle("metal_bronze")
        case .argent: Libelle("metal_argent")
        case .or: Libelle("metal_or")
        case .platine: Libelle("metal_platine")
        }
    }

    /// « Grade Argent » (grade_titre).
    public static func grade(_ m: Trophees.Metal) -> Libelle {
        Libelle("grade_titre", .libelle(metal(m)))
    }

    /// PaliersVue.valeur : des jours pour la série et les jours de pratique, une durée pour le reste
    /// (Store.formatDuration).
    public static func valeurPalier(_ piste: Paliers.Piste, _ v: Int) -> Libelle {
        switch piste {
        case .serie, .jours: Libelle.pluriel("palier_n_jours", quantite: v, .entier(v))
        case .jour, .semaine, .mois, .cumul: Store.formatDuration(v)
        }
    }

    /// « 3 / 7 » (trophee_progres).
    public static func progres(_ valeur: Int, _ seuil: Int) -> Libelle {
        Libelle("trophee_progres", .entier(valeur), .entier(seuil))
    }

    /// « 3 / 7 · encore 4 » (trophee_encore) : `valeur` déjà bornée au seuil.
    public static func encore(_ valeur: Int, _ seuil: Int) -> Libelle {
        Libelle("trophee_encore", .entier(valeur), .entier(seuil), .entier(seuil - valeur))
    }
}

/// Le petit texte sous un trophée : gagné tel jour, gagné, ou où l'on en est.
public enum TropheeSous: Sendable, Hashable {
    /// « Gagné le 3 novembre 2026 » : la date se met en forme dans la vue (format long de la langue de l'app,
    /// `FormatStyle.LONG` d'Android).
    case gagneLe(JourCivil)
    /// « Gagné ✓ » : le jour n'est pas connu.
    case gagne
    /// « 3 / 7 ».
    case progres(valeur: Int, seuil: Int)

    /// Le libellé, la date écrite par `dateLongue` (la vue lui passe son format long).
    public func libelle(dateLongue: (JourCivil) -> String) -> Libelle {
        switch self {
        case .gagneLe(let jour): Libelle("trophee_gagne_le", .texte(dateLongue(jour)))
        case .gagne: Libelle("trophee_gagne")
        case .progres(let valeur, let seuil): TropheeTextes.progres(valeur, seuil)
        }
    }

    /// Gagné : le jour du gain s'il est connu (`Store.datesTrophees`).
    static func pour(_ niveau: Trophees.Niveau, dates: [String: JourCivil]) -> TropheeSous {
        if let jour = dates[niveau.cle] { return .gagneLe(jour) }
        return .gagne
    }
}

/// La fiche d'un trophée (FicheTrophee.montrer) : l'objet, ce qu'il demande, le jour gagné ou la progression.
/// Ouverte d'un toucher sur l'écran des paliers, et d'elle-même à l'accueil quand un trophée est gagné
/// (`feter`) : alors l'objet se retourne, des confettis tombent sur tout l'écran et des étincelles du métal
/// jaillissent autour de lui.
public struct TropheeFiche: Sendable, Hashable, Identifiable {

    /// Ce que la fiche dit sous le nom.
    public enum Etat: Sendable, Hashable {
        /// Gagné : le jour (ou « Gagné ✓ »), puis « En Argent : c'était votre 12ᵉ trophée. ».
        case gagne(sous: TropheeSous, grade: Libelle)
        /// À gagner : la barre (de 0 à 1) et « 3 / 7 · encore 4 ».
        case aGagner(fraction: Float, encore: Libelle)
    }

    /// Le bouton qui ferme la fiche (en bas, à droite en LTR).
    public static let bouton = Libelle("celebration_continue")
    /// Le retournement de l'objet d'un trophée gagné, après ce délai (ms).
    public static let retardRetournement = 150
    /// Les étincelles d'une fête, après ce délai (ms).
    public static let retardEtincelles = 700

    public let niveau: Trophees.Niveau
    public var id: String { niveau.cle }
    public let gagne: Bool
    /// Le métal de l'objet : celui du grade qu'il a fait atteindre (`Trophees.grade(rangGlobal)`) s'il est
    /// gagné ; nil (gris) sinon.
    public let metal: Trophees.Metal?
    /// Son rang parmi les trophées gagnés, de 1 (le suivant des gagnés s'il ne l'est pas).
    public let rangGlobal: Int
    /// Ce qu'il demande, en titre (20 pt, gras, centré).
    public let titre: Libelle
    /// « Nom de la famille · Niveau 3 sur 24 » : les deux parties, que la vue joint par « · ».
    public let nom: Libelle
    public let niveauCourt: Libelle
    public let etat: Etat
    /// Une fête : confettis, étincelles, vibration longue.
    public let feter: Bool

    public init(niveau: Trophees.Niveau, pratique: Trophees.Pratique, dates: [String: JourCivil], rangGlobal: Int,
                feter: Bool = false) {
        self.niveau = niveau
        self.rangGlobal = rangGlobal
        self.feter = feter
        let gagne = Trophees.gagne(pratique, niveau)
        self.gagne = gagne
        let metal: Trophees.Metal? = gagne ? Trophees.grade(rangGlobal) : nil
        self.metal = metal
        titre = TropheeTextes.description(niveau)
        nom = TropheeTextes.nom(niveau.famille)
        niveauCourt = Libelle("trophee_niveau_court", .entier(niveau.rang), .entier(niveau.famille.seuils.count))
        if let metal {
            etat = .gagne(sous: TropheeSous.pour(niveau, dates: dates),
                          grade: Libelle("trophee_detail_grade", .libelle(TropheeTextes.metal(metal)), .entier(rangGlobal)))
        } else {
            let v = min(Trophees.valeur(pratique, niveau.famille), niveau.seuil)
            etat = .aGagner(fraction: min(max(Trophees.fraction(pratique, niveau), 0), 1),
                            encore: TropheeTextes.encore(v, niveau.seuil))
        }
    }

    /// L'objet se retourne à l'ouverture (seulement gagné).
    public var retourner: Bool { gagne }
    /// Les confettis sur tout l'écran, les étincelles et la vibration : seulement pour une fête, et jamais
    /// quand « Réduire les animations » est actif (la vue le vérifie : `AnimationsTrophees.actives`).
    public var confettis: Bool { feter }

    /// La description pour l'accessibilité : le titre, le nom et le niveau (l'objet, décoratif, est caché).
    public var accessibilite: [Libelle] { [titre, nom, niveauCourt] }
}
