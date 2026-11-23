// Le bouclier de Temps d'écran (PORTAGE.md § 2.1.4, § 2.1.10) : ce que l'extension du bouclier montre et ce que
// l'extension d'action fait de chaque bouton, d'après l'instantané et la boîte. C'est l'écran de garde d'Android
// (BlockerView.kt, GateService.showOverlay) ramené à ce qu'un bouclier peut porter : une icône, un titre, un
// sous-titre, un bouton principal, un bouton secondaire et son sous-menu. Les trois issues d'Android (Commencer, « Je
// l'ai faite sans le téléphone », Plus tard) tiennent dans le principal et le sous-menu du secondaire ; si le
// sous-menu ne paraît pas, le secondaire redessine le bouclier en deuxième page. Les deux extensions calculent le même
// visage par cette règle : le bouton touché est toujours celui qui était dessiné.

/// Le visage montré. Les trois premiers sont les modes de BlockerView ; les deux autres sont propres à iOS.
public enum FaceBouclier: Sendable, Hashable {
    /// Rien n'a encore été fait aujourd'hui (PROMPT) : « Commencer maintenant », et « Autre réponse ».
    case invite
    /// La deuxième page de l'invite, après « Autre réponse » : « Je l'ai faite sans le téléphone », « Plus tard ».
    case autreReponse
    /// Une hitbodedout est en cours (SESSION_RUNNING) : y revenir.
    case seance
    /// L'essai réel (PREVIEW) : « APERÇU, AUCUN EFFET », « Fermer l'aperçu ».
    case apercu
    /// Le bouclier est resté posé alors que la règle n'en veut plus (la séance vient de finir app fermée, le report a
    /// été pris, la fenêtre est passée sans réveil de la surveillance) : l'état du moment, et « Continuer », qui lève
    /// tout (§ 2.1.10). L'état est celui de la règle (`Evaluation.regle`).
    case levee(GateState)
}

/// Ce que le bouclier porte, déjà traduit : l'extension recopie ces champs dans sa `ShieldConfiguration`.
public struct ContenuBouclier: Sendable, Equatable {
    /// Le nom du fichier de l'image du personnage, à côté de l'instantané ; vide sans image.
    public var icone: String
    public var titre: String
    public var sousTitre: String
    public var principal: String
    /// nil : pas de bouton secondaire.
    public var secondaire: String?
    /// Les entrées du sous-menu du bouton secondaire (iOS 26.4) ; vide sans sous-menu.
    public var sousMenu: [String]
    /// Les couleurs de l'apparence choisie.
    public var apparence: ApparenceBouclier

    public init(icone: String, titre: String, sousTitre: String, principal: String, secondaire: String?,
                sousMenu: [String], apparence: ApparenceBouclier) {
        self.icone = icone
        self.titre = titre
        self.sousTitre = sousTitre
        self.principal = principal
        self.secondaire = secondaire
        self.sousMenu = sousMenu
        self.apparence = apparence
    }
}

/// Le bouton touché, comme `ShieldAction` le dit.
public enum AppuiBouclier: Sendable, Equatable {
    case principal
    case secondaire
    /// L'entrée du sous-menu, à partir de 0.
    case sousMenu(Int)
}

/// Ce que l'extension d'action fait d'un appui (les fermetures de BlockerView).
public enum GesteBouclier: String, Sendable, Equatable, CaseIterable {
    /// onStartSession : écrire la demande dans la boîte, ouvrir l'app (ou, à défaut, la notification qui l'ouvre).
    case commencer
    /// onStartSession pendant une séance : rouvrir l'app sur la séance.
    case revenir
    /// Le bouclier se redessine en deuxième page (`.defer`).
    case autreReponse
    /// onAlreadyDone : « Je l'ai faite sans le téléphone » (Store.addSession(context, 0)), le bouclier levé.
    case dejaFaite
    /// onSnooze : le report (Store.snooze), le bouclier levé, la surveillance réveillée à sa fin.
    case plusTard
    /// onDismiss de l'aperçu : l'essai levé.
    case fermerApercu
    /// Le bouclier resté posé à tort : tout lever.
    case continuer
    /// Un bouton que ce visage n'a pas.
    case rien
}

/// La règle du bouclier.
public enum PlanBouclier {

    /// Après « Autre réponse », la deuxième page reste le temps de choisir : cinq minutes, puis l'invite revient.
    public static let dureeDeuxiemePage: Int64 = 5 * 60_000

    /// Le visage à montrer à `maintenant`, d'après l'instantané et la boîte (non encore versée par l'app). L'essai
    /// passe devant : il se voit sur les applications choisies à toute heure. Sinon la règle d'Android (GateRule.ecran) :
    /// l'invite dans la veille, la séance pendant une hitbodedout ; rien d'autre ne pose de bouclier.
    public static func face(_ etat: Etat, evenements: [Evenement], maintenant: Horodatage) -> FaceBouclier {
        let vu = etat.avec(evenements)
        if vu.essaiEnCours(millis: maintenant.millis) { return .apercu }
        switch Evaluation.bouclier(vu, maintenant: maintenant) {
        case .invite:
            return deuxiemePage(evenements, maintenant: maintenant) ? .autreReponse : .invite
        case .seance:
            return .seance
        case .apercu:
            return .apercu
        case nil:
            return .levee(Evaluation.regle(vu, maintenant: maintenant))
        }
    }

    /// « Autre réponse » a été touché il y a moins de cinq minutes.
    static func deuxiemePage(_ evenements: [Evenement], maintenant: Horodatage) -> Bool {
        for evenement in evenements.reversed() where evenement.genre == Evenement.Genre.autreReponse.rawValue {
            let age = maintenant.millis - evenement.quand.millis
            return age >= 0 && age < dureeDeuxiemePage
        }
        return false
    }

    /// Le contenu d'un visage (BlockerView, mode par mode) : les textes de l'instantané, déjà traduits.
    /// - invite : le hassid qui appelle, la question, « Un moment à l'écart avant le reste. » et la série, « Commencer
    ///   maintenant, 15 min », « Autre réponse » et son sous-menu ;
    /// - deuxième page : les mêmes textes, « Je l'ai faite sans le téléphone » et « Plus tard (15 min) » ;
    /// - séance : le hassid en prière, « Hitbodedout en cours », la phrase sans décompte (le bouclier est figé à son
    ///   apparition), « Revenir à la hitbodedout » ;
    /// - aperçu : le hassid qui appelle, la question, « APERÇU, AUCUN EFFET », « Fermer l'aperçu » ;
    /// - levée : la joie du jour, le titre et le détail de la carte d'état, « Continuer ».
    public static func contenu(_ face: FaceBouclier, etat: Etat) -> ContenuBouclier {
        let b = etat.bouclier
        let apparence = b.apparence
        let invite = lignes(b.sousTitre, b.serie)
        switch face {
        case .invite:
            return ContenuBouclier(icone: apparence.iconeAppel, titre: b.question, sousTitre: invite, principal: b.commencer,
                                   secondaire: b.autreReponse, sousMenu: [b.dejaFaite, b.plusTard], apparence: apparence)
        case .autreReponse:
            return ContenuBouclier(icone: apparence.iconeAppel, titre: b.question, sousTitre: invite, principal: b.dejaFaite,
                                   secondaire: b.plusTard, sousMenu: [], apparence: apparence)
        case .seance:
            return ContenuBouclier(icone: apparence.iconeSeance, titre: b.seanceTitre, sousTitre: b.seanceSousTitre,
                                   principal: b.revenir, secondaire: nil, sousMenu: [], apparence: apparence)
        case .apercu:
            return ContenuBouclier(icone: apparence.iconeAppel, titre: b.question, sousTitre: lignes(b.apercu, b.sousTitre),
                                   principal: b.fermerApercu, secondaire: nil, sousMenu: [], apparence: apparence)
        case .levee(let etatRegle):
            return ContenuBouclier(icone: apparence.iconeJoie, titre: b.titresLeve[etatRegle.rawValue] ?? "",
                                   sousTitre: b.detailsLeve[etatRegle.rawValue] ?? "", principal: b.continuer,
                                   secondaire: nil, sousMenu: [], apparence: apparence)
        }
    }

    /// Ce que fait un appui sur le visage dessiné.
    public static func geste(_ face: FaceBouclier, _ appui: AppuiBouclier) -> GesteBouclier {
        switch (face, appui) {
        case (.invite, .principal): .commencer
        // Sans sous-menu, le secondaire redessine en deuxième page ; avec lui, ses deux entrées.
        case (.invite, .secondaire): .autreReponse
        case (.invite, .sousMenu(0)): .dejaFaite
        case (.invite, .sousMenu(1)): .plusTard
        case (.autreReponse, .principal): .dejaFaite
        case (.autreReponse, .secondaire): .plusTard
        case (.seance, .principal): .revenir
        case (.apercu, .principal): .fermerApercu
        case (.levee, .principal): .continuer
        default: .rien
        }
    }

    /// Deux lignes, la seconde omise si elle est vide.
    private static func lignes(_ premiere: String, _ seconde: String) -> String {
        if seconde.isEmpty { return premiere }
        if premiere.isEmpty { return seconde }
        return premiere + "\n" + seconde
    }
}
