import Foundation
import Observation
import Coeur

// Le défilement automatique des écrans de lecture (ReglagesLecture.kt, 16/11 ; le même sur le web et le Nokia) :
// un bouton de la barre le lance ou l'arrête ; tant qu'il défile, une petite commande flottante [−] [N] [+] [pause]
// règle la vitesse, de 1 à 10. Le niveau vaut pour tous les écrans de lecture : il vit dans le `Magasin`, sous la
// clé d'Android (`lecture_defilement_vitesse`) ; qu'il défile ou non ne se garde pas.
//
// La vue donne l'horloge (chaque image d'un TimelineView(.animation)) : à chaque image, elle demande à `avancer` où mettre
// le texte. Les fractions de point s'accumulent d'une image à l'autre, comme le `scrollBy(0, Int)` d'Android :
// mille petites images font le même chemin qu'une grande. Un doigt sur le texte l'arrête, comme sur Android, le
// site et le Nokia (la vue, DefilementAutoVue.swift) ; le bout du texte, le bouton ❚❚ et « Masquer » aussi.

/// Le défilement automatique d'un écran de lecture.
@MainActor
@Observable
public final class DefilementAuto {
    private let magasin: Magasin

    /// Le texte défile tout seul (le bouton de la barre, ou la commande flottante).
    public private(set) var actif = false
    /// Les fractions de point pas encore parcourues, gardées pour l'image suivante.
    @ObservationIgnored private var reste: Double = 0

    public init(magasin: Magasin) {
        self.magasin = magasin
    }

    // MARK: La vitesse

    /// La vitesse, en points par seconde, d'un niveau (1 à 10) pour une taille de lettres (0,8 à 2) :
    /// 6 × 1,4^(n − 1) × échelle. Des lettres plus grandes font défiler plus vite, pour le même nombre de lignes.
    public nonisolated static func vitesse(_ niveau: Int, echelle: Double) -> Double {
        6 * pow(1.4, Double(niveau - 1)) * echelle
    }

    /// Le niveau choisi, de 1 à 10 (3 par défaut).
    public var niveau: Int {
        magasin.reglages.lectureDefilementVitesse
    }

    /// La vitesse d'aujourd'hui, en points par seconde, à la taille de lettres choisie.
    public var pointsParSeconde: Double {
        DefilementAuto.vitesse(niveau, echelle: Double(magasin.reglages.lectureEchelle))
    }

    /// [−] se touche : le niveau n'est pas au plus lent.
    public var moinsViteActif: Bool { niveau > Reglages.defilementMin }
    /// [+] se touche : le niveau n'est pas au plus rapide.
    public var plusViteActif: Bool { niveau < Reglages.defilementMax }

    // MARK: Ce que la vue montre

    /// La commande flottante [−] [N] [+] [pause] se montre.
    public var commandeVisible: Bool { actif }

    /// Garder l'écran allumé (`isIdleTimerDisabled`) : tant que le texte défile tout seul.
    public var garderEcranAllume: Bool { actif }

    /// Le nom du bouton de la barre : « Défilement automatique », ou « Arrêter le défilement » quand il défile.
    public var libelleBouton: Libelle {
        Libelle(actif ? "lecture_defiler_pause" : "lecture_defiler")
    }

    /// « Vitesse 3 sur 10 », pour la lecture d'écran du chiffre de la commande.
    public var libelleVitesse: Libelle {
        Libelle("lecture_vitesse", .entier(niveau))
    }

    // MARK: Les actions

    /// Le bouton de la barre : lance le défilement, ou l'arrête.
    public func basculer() {
        if actif { arreter() } else { lancer() }
    }

    /// Lance le défilement, d'où est le texte.
    public func lancer() {
        actif = true
        reste = 0
    }

    /// [pause] de la commande, le bout du texte, un doigt sur le texte, « Masquer » ou l'écran quitté : le
    /// défilement s'arrête.
    public func arreter() {
        actif = false
        reste = 0
    }

    /// [+] : un niveau de plus, jusqu'à 10.
    public func plusVite() async throws {
        try await regler(niveau + 1)
    }

    /// [−] : un niveau de moins, jusqu'à 1.
    public func moinsVite() async throws {
        try await regler(niveau - 1)
    }

    private func regler(_ voulu: Int) async throws {
        let nouveau = min(max(voulu, Reglages.defilementMin), Reglages.defilementMax)
        if nouveau == niveau { return }
        try await magasin.modifierReglages { $0.setLectureDefilementVitesse(nouveau) }
    }

    /// Une image : où mettre le texte, à `position` (en points, du haut), après `ecoule` secondes, sans dépasser
    /// `fin` (le plus bas où le texte peut aller). Seuls des points entiers s'ajoutent ; les fractions attendent
    /// l'image suivante. Au bout, le défilement s'arrête et `finAtteinte` le dit. Rien ne bouge à l'arrêt.
    public func avancer(position: Double, ecoule: TimeInterval, fin: Double) -> (position: Double, finAtteinte: Bool) {
        guard actif else { return (position, false) }
        if position >= fin {
            arreter()
            return (max(position, fin), true)
        }
        let total = reste + pointsParSeconde * max(ecoule, 0)
        // Un millionième de point de marge : la somme de mille petits pas en flottant peut manquer l'entier d'un
        // cheveu, là où un seul grand pas l'atteint.
        let pas = (total + 1e-6).rounded(.down)
        reste = max(total - pas, 0)
        let suivante = position + pas
        if suivante >= fin {
            arreter()
            return (fin, true)
        }
        return (suivante, false)
    }
}
