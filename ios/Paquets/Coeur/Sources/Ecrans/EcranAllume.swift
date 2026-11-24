import Foundation
import Coeur

// L'écran qui ne s'éteint pas (FLAG_KEEP_SCREEN_ON et keepScreenOn d'Android, `isIdleTimerDisabled` d'iOS) : iOS n'a
// qu'un seul interrupteur pour toute l'app, là où Android en a un par fenêtre et un par vue. Chaque écran qui veut
// l'écran allumé le demande ici sous son nom, et le retire en partant ; l'écran reste allumé tant qu'une demande
// reste. Le défilement automatique qui s'arrête rend ainsi l'écran à ce qu'il était : allumé si la séance le veut
// encore, à la veille du téléphone sinon (vérification du 24/11 : sur Android, keepScreenOn s'ajoute au drapeau de
// la fenêtre sans y toucher). La vue applique la réponse (DefilementAutoVue.swift, `EcranAllume`).

/// Les demandes d'écran allumé de l'app.
@MainActor
public final class EcranAllumeDemandes {
    /// Celles de l'app : un seul interrupteur, `isIdleTimerDisabled`.
    public static let app = EcranAllumeDemandes()

    /// Qui demande l'écran allumé.
    public private(set) var demandeurs: Set<String> = []

    public init() {}

    /// L'écran reste allumé : une demande au moins.
    public var allume: Bool {
        !demandeurs.isEmpty
    }

    /// `qui` demande l'écran allumé, ou retire sa demande ; rend ce que l'écran doit faire.
    @discardableResult
    public func garder(_ allume: Bool, pour qui: String) -> Bool {
        if allume {
            demandeurs.insert(qui)
        } else {
            demandeurs.remove(qui)
        }
        return self.allume
    }
}

/// Les crochets des captures d'écran de la CI (App/Captures.swift, ECRANS.md « Les captures ») pour les écrans de
/// lecture : de quoi photographier ce qu'un toucher ouvrirait. Faux hors des captures : rien ne change.
@MainActor
public enum LectureCaptures {
    /// Les barres de lecture s'ouvrent dépliées (A−, %, A+, …, le défilement automatique) au lieu de la pastille.
    public static var barreDepliee = false
    /// Un long livre s'ouvre sur la liste de ses chapitres (FLECTURE-03).
    public static var chapitresOuverts = false
}

/// L'écran reste allumé pendant qu'on lit (VeilleLecture.kt, audit du 12/11, FLECTURE-01) : avec la mise en veille
/// courante de trente secondes, il s'éteignait au milieu de la Amida ou d'un psaume lu lentement. Avec
/// discernement : dix minutes sans toucher l'écran et la veille du téléphone reprend, pour qu'un téléphone posé,
/// ouvert sur une page, ne vide pas sa batterie ; et le réglage « Garder l'écran allumé pendant la lecture »
/// (`lecture_ecran_allume`, allumé d'origine) le coupe. Aux quatre écrans de lecture d'Android : le lecteur du
/// siddour et des livres, les Tehilim, le Tikoun, une entrée de la bibliothèque.
///
/// L'écran prévient de chaque toucher, de son retour au premier plan et de son départ ; la vue tient l'horloge
/// (VeilleLectureVue, cible Vues) et demande l'écran allumé à `EcranAllumeDemandes` tant que `allume` le dit. Le
/// défilement automatique qui s'arrête compte comme un toucher : Android repousse la veille à chaque minute de
/// défilement, l'écran reste donc allumé dix minutes après, le temps de finir la page.
@MainActor
public final class VeilleLecture {
    /// Sans toucher pendant ce temps (en millisecondes), la veille du téléphone reprend (DELAI_MS).
    public static let delai: Int64 = 10 * 60_000

    private let magasin: Magasin
    /// Jusqu'à quand l'écran reste allumé (millisecondes Unix) ; nil : rien à garder.
    public private(set) var jusqua: Int64? = nil

    public init(magasin: Magasin) {
        self.magasin = magasin
    }

    /// Le réglage « Garder l'écran allumé pendant la lecture ».
    public var permise: Bool {
        magasin.reglages.lectureEcranAllume
    }

    /// Un toucher, ou l'écran qui revient, à `maintenant` : dix minutes de plus, si le réglage le veut. Rend
    /// l'échéance, nil si rien n'est à garder.
    @discardableResult
    public func toucher(_ maintenant: Int64) -> Int64? {
        jusqua = permise ? maintenant + VeilleLecture.delai : nil
        return jusqua
    }

    /// L'écran de lecture quitte le premier plan : plus rien à garder allumé.
    public func arreter() {
        jusqua = nil
    }

    /// À `maintenant`, l'écran reste-t-il allumé ? Le réglage coupé entre-temps relâche aussitôt.
    public func allume(_ maintenant: Int64) -> Bool {
        guard permise, let jusqua else { return false }
        return maintenant < jusqua
    }
}
