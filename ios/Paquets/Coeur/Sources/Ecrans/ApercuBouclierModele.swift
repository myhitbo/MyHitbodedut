import Foundation
import Observation
import Coeur
import Barriere

// « Voir l'écran « Je suis avec Hachem » maintenant » (SettingsActivity.previewGate, GateService.preview,
// BlockerView en mode PREVIEW). Sur iOS, deux outils de confiance (PORTAGE.md § 2.1.8) : la réplique du bouclier,
// dessinée dans l'app d'après le même instantané et la même règle que l'extension (`PlanBouclier`), visage par visage ;
// et l'essai réel, qui retient les applications choisies deux minutes, à n'importe quelle heure, avec le vrai bouclier
// « APERÇU, AUCUN EFFET ».

/// L'aperçu du bouclier et l'essai réel.
@MainActor
@Observable
public final class ApercuBouclierModele {

    /// Les visages qu'on peut feuilleter : l'invite et sa deuxième page, la séance, l'essai.
    public static let faces: [FaceBouclier] = [.invite, .autreReponse, .seance, .apercu]

    private let magasin: Magasin
    private let horloge: any Horloge
    private let traducteur: Traducteur
    private let palette: Palette?
    private let systeme: any BarriereSysteme

    /// Le visage montré.
    public var face: FaceBouclier = .invite
    /// L'instantané tel que l'app le dépose pour les extensions, dans la langue de l'app.
    public private(set) var instantane: Etat
    public private(set) var autorise = false
    public private(set) var selection = SelectionResume()
    /// Le système a été lu une fois : avant, l'essai n'est ni proposé ni refusé.
    public private(set) var systemeLu = false
    /// La fin de l'essai demandé, en millisecondes Unix.
    public private(set) var finEssai: Int64? = nil
    /// Le message bref à montrer ; `messageVu()` l'efface.
    public private(set) var message: Libelle? = nil

    public init(magasin: Magasin, horloge: any Horloge, traducteur: Traducteur, palette: Palette?,
                systeme: any BarriereSysteme) {
        self.magasin = magasin
        self.horloge = horloge
        self.traducteur = traducteur
        self.palette = palette
        self.systeme = systeme
        instantane = Etat()
        instantane = calculer()
    }

    /// Relit l'autorisation et la sélection, et refait l'instantané (la série, la durée, les couleurs ont pu changer).
    public func rafraichir() async {
        autorise = await systeme.autorise()
        selection = await systeme.selection()
        systemeLu = true
        instantane = calculer()
    }

    private func calculer() -> Etat {
        let traducteur = self.traducteur
        return EtatBarriere.etat(journal: magasin.journal, reglages: magasin.reglages, millis: horloge.maintenant,
                                 fuseau: horloge.fuseau, nombreDeJetons: selection.nombre, palette: palette,
                                 textes: { traducteur.texte($0) })
    }

    // MARK: La réplique

    /// Ce que le bouclier porte pour le visage montré.
    public var contenu: ContenuBouclier {
        PlanBouclier.contenu(face, etat: instantane)
    }

    /// L'image du personnage, sous le nom des images de l'app (sans « .webp »).
    public var image: String {
        let nom = contenu.icone
        return nom.hasSuffix(".webp") ? String(nom.dropLast(5)) : nom
    }

    /// Le nom d'un visage, pour le choisir.
    public func libelle(_ face: FaceBouclier) -> Libelle {
        switch face {
        case .invite: Libelle("bouclier_visage_invite")
        case .autreReponse: Libelle("bouclier_autre_reponse")
        case .seance: Libelle("blocker_session_title")
        case .apercu: Libelle("bouclier_visage_essai")
        case .levee(let etat): GateStatus.titleOf(etat)
        }
    }

    /// Ce que la réplique dit d'elle-même.
    public var explication: Libelle { Libelle("bouclier_apercu_explication") }

    // MARK: L'essai réel

    /// L'essai court-il encore ?
    public var essaiEnCours: Bool {
        guard let finEssai else { return false }
        return finEssai > horloge.maintenant
    }

    /// Le bouton « Faire un essai » agit : l'accès accordé, au moins une application, pas d'essai en cours.
    public var essaiPossible: Bool {
        systemeLu && autorise && !selection.vide && !essaiEnCours
    }

    /// Ce que dit la ligne sous le bouton : pourquoi l'essai n'est pas possible, jusqu'à quand il court, ou ce qu'il fait.
    public var etatEssai: Libelle {
        if essaiEnCours, let finEssai {
            let fin = EtatBarriere.horodatage(millis: finEssai, fuseau: horloge.fuseau)
            return Libelle("bouclier_essai_en_cours", .texte(Store.formatMinutes(fin.minutes)))
        }
        if systemeLu && !autorise { return Libelle("bouclier_essai_sans_acces") }
        if systemeLu && selection.vide { return Libelle("apps_none_warning") }
        return Libelle("bouclier_essai_explication")
    }

    /// « Faire un essai de deux minutes ».
    public func essayer() async {
        guard essaiPossible else { return }
        guard let fin = await systeme.essayer() else {
            message = Libelle("bouclier_essai_echec")
            return
        }
        finEssai = fin
        face = .apercu
        message = Libelle("bouclier_essai_lance")
    }

    public func messageVu() {
        message = nil
    }
}
