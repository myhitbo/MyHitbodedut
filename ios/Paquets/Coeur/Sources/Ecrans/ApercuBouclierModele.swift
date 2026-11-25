import Foundation
import Observation
import Coeur
import Barriere

// L'aperçu du bouclier (« Voir l'écran « Je suis avec Hachem » maintenant » des réglages, GateService.preview
// d'Android ; PORTAGE.md § 2.1.4, § 2.1.8). Sur Android, l'aperçu posait le vrai écran de garde par-dessus tout.
// Sur iOS, le bouclier est dessiné par le système, dans une extension : l'app en montre une réplique, les trois
// visages composés par la même règle que l'extension (`VisageBouclier.contenu`, module Barriere), avec les mêmes
// textes (`EtatBarriere.libelles`), et propose l'essai réel, qui pose le vrai bouclier « APERÇU, AUCUN EFFET »
// deux minutes sur les applications choisies.

// MARK: Le service

/// L'essai réel (§ 2.1.8) : l'app retient les applications choisies pendant deux minutes, à n'importe quelle
/// heure, derrière le vrai bouclier « APERÇU, AUCUN EFFET ». Dans l'app : Managed Settings et Device Activity
/// (App/Services/SystemeBarriere.swift).
public protocol BouclierEssai: Sendable {
    /// Commence l'essai ; rend sa fin en millisecondes Unix, ou nil s'il n'a pu commencer (Temps d'écran non
    /// autorisé, aucune application choisie, l'entitlement Family Controls absent, le groupe d'apps absent).
    func commencerEssai() async -> Int64?
}

/// Un essai qui rend ce qu'on lui a dit de rendre, et compte les demandes.
public actor FauxBouclierEssai: BouclierEssai {
    public private(set) var demandes = 0
    private let fin: Int64?

    public init(fin: Int64?) {
        self.fin = fin
    }

    public func commencerEssai() -> Int64? {
        demandes += 1
        return fin
    }
}

// MARK: Les textes du bouclier

extension EtatBarriere.TextesBouclier {
    /// Le libellé d'une place du bouclier, comme `Etat.Bouclier[_:]` en donne le texte à l'extension.
    public subscript(_ texte: TexteBouclier) -> Libelle {
        switch texte {
        case .question: question
        case .sousTitre: sousTitre
        case .serie: serie
        case .commencer: commencer
        case .autreReponse: autreReponse
        case .dejaFaite: dejaFaite
        case .plusTard: plusTard
        case .seanceTitre: seanceTitre
        case .seanceSousTitre: seanceSousTitre
        case .revenir: revenir
        case .apercu: apercu
        case .fermerApercu: fermerApercu
        }
    }
}

// MARK: Le modèle

/// Un visage de la réplique : son nom dans le sélecteur, la pose du hassid et ce que porte le bouclier.
public struct ApercuBouclierVisage: Identifiable, Sendable, Equatable {
    public let visage: VisageBouclier
    /// Le nom du visage dans le sélecteur (« Rien de fait », « Séance en cours », « Essai »).
    public let nom: Libelle
    /// La pose du hassid (`Poses.call`, `Poses.during`), que l'illustration de l'app met au féminin s'il le faut.
    public let image: String
    public let contenu: ContenuBouclier<Libelle>

    public var id: VisageBouclier { visage }
}

/// L'écran de l'aperçu du bouclier, poussé depuis la carte de la barrière des réglages.
@MainActor
@Observable
public final class ApercuBouclierModele {

    /// Le visage montré.
    public var choisi: VisageBouclier = .invite
    /// La fin de l'essai réel lancé depuis cet écran ; nil sans essai.
    public private(set) var finEssai: Int64? = nil
    /// Une demande d'essai est en cours : le bouton attend.
    public private(set) var essaiEnDemande = false
    /// Le message à montrer (l'essai qui n'a pu commencer) ; `messageVu()` l'efface.
    public var message: Libelle? = nil

    /// Les textes du bouclier, relus par `actualiser()` : la série et la durée habituelle changent.
    private var textes: EtatBarriere.TextesBouclier
    /// Le jour qui choisit la pose du hassid (Character.call, Character.during : une par jour).
    private var jour: JourCivil

    private let magasin: Magasin
    private let horloge: any Horloge
    private let essai: (any BouclierEssai)?

    /// `essai` : nil là où l'essai réel n'existe pas (la construction sans barrière).
    public init(magasin: Magasin, horloge: any Horloge, essai: (any BouclierEssai)?) {
        self.magasin = magasin
        self.horloge = horloge
        self.essai = essai
        let aujourdhui = horloge.aujourdhui
        jour = aujourdhui
        textes = EtatBarriere.libelles(journal: magasin.journal, reglages: magasin.reglages, aujourdhui: aujourdhui,
                                       fuseauTelephone: horloge.fuseau.identifiant)
    }

    /// Un écran d'aperçu (les aperçus de Xcode) : un magasin en mémoire, un essai qui ne commence pas.
    public static func apercu(_ enregistrement: Enregistrement = Enregistrement()) -> ApercuBouclierModele {
        ApercuBouclierModele(magasin: Magasin.enMemoire(enregistrement), horloge: HorlogeSysteme(),
                             essai: FauxBouclierEssai(fin: nil))
    }

    /// Relit la série, la durée habituelle et le jour (à l'apparition de l'écran).
    public func actualiser() {
        let aujourdhui = horloge.aujourdhui
        jour = aujourdhui
        textes = EtatBarriere.libelles(journal: magasin.journal, reglages: magasin.reglages, aujourdhui: aujourdhui,
                                       fuseauTelephone: horloge.fuseau.identifiant)
    }

    // MARK: Les textes de l'écran

    /// Le titre : celui de la ligne des réglages qui mène ici.
    public var titre: Libelle { Libelle("action_preview_gate") }

    /// Ce que montre l'écran, et ce qui en diffère sur l'iPhone.
    public var introduction: Libelle { Libelle("apercu_bouclier_intro") }

    // MARK: Les visages

    /// Les trois visages, dans l'ordre de BlockerMode.
    public var visages: [ApercuBouclierVisage] {
        VisageBouclier.allCases.map { composer($0) }
    }

    /// Le visage choisi.
    public var visage: ApercuBouclierVisage {
        composer(choisi)
    }

    private func composer(_ visage: VisageBouclier) -> ApercuBouclierVisage {
        let textes = self.textes
        let contenu = visage.contenu { textes[$0] }
        let image: String
        switch contenu.pose {
        case .appel: image = Poses.call(jour)
        case .priere: image = Poses.during(jour)
        }
        return ApercuBouclierVisage(visage: visage, nom: ApercuBouclierModele.nom(visage), image: image,
                                    contenu: contenu)
    }

    /// Le nom d'un visage dans le sélecteur.
    public static func nom(_ visage: VisageBouclier) -> Libelle {
        switch visage {
        case .invite: Libelle("apercu_bouclier_visage_invite")
        case .seance: Libelle("apercu_bouclier_visage_seance")
        case .apercu: Libelle("apercu_bouclier_visage_essai")
        }
    }

    // MARK: L'essai réel

    /// L'essai réel existe dans cette construction.
    public var essaiDisponible: Bool { essai != nil }

    public var titreEssai: Libelle { Libelle("apercu_bouclier_essai_titre") }

    public var explicationEssai: Libelle { Libelle("apercu_bouclier_essai_detail") }

    public var boutonEssai: Libelle { Libelle("apercu_bouclier_essai_bouton") }

    /// « Essai lancé jusqu'à 14:02 : ouvrez une application choisie. » ; nil avant tout essai.
    public var etatEssai: Libelle? {
        guard let fin = finEssai else { return nil }
        let minutes = horloge.fuseau.dateHeure(millis: fin).minutesDuJour
        return Libelle("apercu_bouclier_essai_en_cours", .texte(Store.formatMinutes(minutes)))
    }

    /// « Faire un essai » : l'essai réel, ou le message qui dit pourquoi il n'a pu commencer.
    public func faireEssai() async {
        guard let essai, !essaiEnDemande else { return }
        essaiEnDemande = true
        let fin = await essai.commencerEssai()
        essaiEnDemande = false
        if let fin {
            finEssai = fin
        } else {
            message = Libelle("apercu_bouclier_essai_impossible")
        }
    }

    public func messageVu() {
        message = nil
    }
}
