import Foundation
import Coeur
import Barriere

// Ce que les écrans de la barrière demandent au système, au-delà de la carte d'état des réglages
// (`ReglagesBarriereSysteme`) : la sélection de Temps d'écran (FamilyActivitySelection, ses jetons comptés), l'essai réel
// et le journal de la barrière (PORTAGE.md § 2.1.3, § 2.1.8). L'adaptateur est dans ios/App/Services/TempsEcran.swift ;
// le faux, ci-dessous, sert aux tests et aux aperçus.

/// La sélection de Temps d'écran, comptée : l'app ne voit ni les noms ni les icônes, seulement des jetons (§ 2.1.3).
public struct SelectionResume: Sendable, Equatable {
    public var applications: Int
    public var categories: Int
    public var sites: Int

    public init(applications: Int = 0, categories: Int = 0, sites: Int = 0) {
        self.applications = applications
        self.categories = categories
        self.sites = sites
    }

    /// Ce que l'instantané compte : une application, une catégorie ou un site vaut un.
    public var nombre: Int { max(applications, 0) + max(categories, 0) + max(sites, 0) }

    public var vide: Bool { nombre == 0 }
}

/// La barrière vue des écrans qui la règlent et l'expliquent.
public protocol BarriereSysteme: Sendable {
    /// L'autorisation de Temps d'écran est-elle accordée ?
    func autorise() async -> Bool
    /// La sélection enregistrée ; vide s'il n'y en a pas.
    func selection() async -> SelectionResume
    /// L'essai réel (§ 2.1.8) : les applications choisies retenues deux minutes avec le bouclier « APERÇU, AUCUN EFFET ».
    /// Rend la fin de l'essai (millisecondes Unix), ou nil s'il n'a pu commencer.
    func essayer() async -> Int64?
    /// Les cinquante derniers événements de la barrière, du plus ancien au plus récent, la boîte comprise.
    func journal() async -> [Evenement]
}

/// Une barrière qui rend ce qu'on lui a dit de rendre, et retient les essais demandés.
public actor FausseBarriereSysteme: BarriereSysteme {
    private var accordee: Bool
    private var choisies: SelectionResume
    private var evenements: [Evenement]
    private let dureeEssai: Int64?
    public private(set) var essais = 0

    /// `dureeEssai` : nil, l'essai ne commence pas ; sinon sa fin, comptée de 0.
    public init(autorise: Bool = true, selection: SelectionResume = SelectionResume(), journal: [Evenement] = [],
                dureeEssai: Int64? = 120_000) {
        accordee = autorise
        choisies = selection
        evenements = journal
        self.dureeEssai = dureeEssai
    }

    public func regler(autorise: Bool, selection: SelectionResume) {
        accordee = autorise
        choisies = selection
    }

    public func autorise() -> Bool {
        accordee
    }

    public func selection() -> SelectionResume {
        choisies
    }

    public func essayer() -> Int64? {
        essais += 1
        return dureeEssai
    }

    public func journal() -> [Evenement] {
        evenements
    }
}
