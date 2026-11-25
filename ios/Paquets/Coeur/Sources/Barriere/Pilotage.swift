import Foundation

// Ce que les trois extensions de Temps d'écran décident, en règles pures (PORTAGE.md § 2.1.4 à § 2.1.6,
// § 2.1.10) : le visage du bouclier et ce que fait chacun de ses boutons (BlockerView.kt, GateService.kt),
// l'état tel qu'une extension le voit (etat.json, plus ce que la boîte a appris depuis), et l'état voulu des
// magasins nommés à chaque rendez-vous de la surveillance. L'app applique les mêmes règles à chaque changement :
// une seule vérité, testée sous Linux (PilotageTests). Foundation seule, comme le reste du module (§ 2.1.9).

// MARK: Les fichiers

/// Les noms que l'app et les extensions partagent dans le conteneur du groupe d'apps (§ 3.2). L'adresse du
/// conteneur (`FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`) n'existe que sur iOS : chacun
/// la demande au système, puis compose ici.
public enum ConteneurBarriere {
    /// Le groupe d'apps de l'app, des widgets et des extensions (project.yml).
    public static let groupe = "group.com.myhitbodedut"
    /// Le dossier de la barrière dans le conteneur du groupe : etat.json, boite.jsonl, selection.plist…
    public static let dossier = "barriere"
    /// La pose du bouclier « rien de fait » et de l'essai (Character.call), copiée du paquet de l'app.
    public static let imageAppel = "bouclier_appel.webp"
    /// La pose du bouclier « séance en cours » (Character.during), copiée du paquet de l'app.
    public static let imagePriere = "bouclier_priere.webp"
    /// Les cinquante derniers événements versés par l'app (le journal de la barrière, § 2.1.8) ; l'app seule
    /// l'écrit, au même format que la boîte.
    public static let historique = "historique.jsonl"

    /// Le dossier de la barrière sous un conteneur.
    public static func repertoire(dans conteneur: URL) -> URL {
        conteneur.appendingPathComponent(dossier, isDirectory: true)
    }

    /// Un fichier du dossier de la barrière sous un conteneur.
    public static func fichier(_ nom: String, dans conteneur: URL) -> URL {
        repertoire(dans: conteneur).appendingPathComponent(nom, isDirectory: false)
    }
}

// MARK: Le décor du bouclier

/// Ce que l'app dépose pour le bouclier à côté d'etat.json (barriere/bouclier.json) : les couleurs de la palette
/// choisie, que l'extension ne sait pas lire dans palettes.json, et l'essai réel en cours. L'app seule l'écrit ;
/// le décodage est tolérant comme celui d'`Etat`.
public struct DecorBouclier: Codable, Sendable, Equatable {

    public static let nomFichier = "bouclier.json"

    /// L'essai réel (§ 2.1.8) : de `debut` à `fin`, en millisecondes Unix.
    public struct Essai: Codable, Sendable, Equatable {
        public var debut: Int64
        public var fin: Int64

        public init(debut: Int64, fin: Int64) {
            self.debut = debut
            self.fin = fin
        }

        private enum CodingKeys: String, CodingKey {
            case debut, fin
        }

        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            debut = (try? c.decodeIfPresent(Int64.self, forKey: .debut)) ?? 0
            fin = (try? c.decodeIfPresent(Int64.self, forKey: .fin)) ?? 0
        }
    }

    /// `brand_dark` : le fond de l'écran de garde (view_blocker.xml). Les valeurs par défaut sont celles de la
    /// palette d'origine (fond et accent verts, de jour).
    public var fond = "#173C32"
    /// `brand` : le bouton principal.
    public var bouton = "#16775A"
    /// `on_brand` : le texte du bouton principal.
    public var texteBouton = "#FFFFFF"
    /// Le titre, blanc sur le fond (`@color/white`).
    public var titre = "#FFFFFF"
    /// `mint` : le sous-titre, la série et le bouton secondaire.
    public var sousTitre = "#DFF5E8"
    /// L'essai réel demandé dans l'app ; nil sans essai.
    public var essai: Essai?

    public init() {}

    /// Le décor lu d'un fichier ; nil si ce n'est pas un objet JSON.
    public static func lire(_ donnees: Data) -> DecorBouclier? {
        try? JSONDecoder().decode(DecorBouclier.self, from: donnees)
    }

    /// Le fichier, clés triées.
    public func donnees() throws -> Data {
        let encodeur = JSONEncoder()
        encodeur.outputFormatting = [.sortedKeys]
        return try encodeur.encode(self)
    }

    /// Les trois composantes d'une couleur `#RRGGBB`, entre 0 et 1 ; nil pour toute autre écriture.
    public static func composantes(_ hex: String) -> (rouge: Double, vert: Double, bleu: Double)? {
        let unites = Array(hex.utf8)
        guard unites.count == 7, unites[0] == 0x23 else { return nil }
        var valeur: UInt32 = 0
        for u in unites.dropFirst() {
            let chiffre: UInt32
            switch u {
            case 0x30...0x39: chiffre = UInt32(u - 0x30)
            case 0x41...0x46: chiffre = UInt32(u - 0x41) + 10
            case 0x61...0x66: chiffre = UInt32(u - 0x61) + 10
            default: return nil
            }
            valeur = valeur * 16 + chiffre
        }
        return (rouge: Double((valeur >> 16) & 0xFF) / 255,
                vert: Double((valeur >> 8) & 0xFF) / 255,
                bleu: Double(valeur & 0xFF) / 255)
    }

    private enum CodingKeys: String, CodingKey {
        case fond, bouton
        case texteBouton = "texte_bouton"
        case titre
        case sousTitre = "sous_titre"
        case essai
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaut = DecorBouclier()
        fond = (try? c.decodeIfPresent(String.self, forKey: .fond)) ?? defaut.fond
        bouton = (try? c.decodeIfPresent(String.self, forKey: .bouton)) ?? defaut.bouton
        texteBouton = (try? c.decodeIfPresent(String.self, forKey: .texteBouton)) ?? defaut.texteBouton
        titre = (try? c.decodeIfPresent(String.self, forKey: .titre)) ?? defaut.titre
        sousTitre = (try? c.decodeIfPresent(String.self, forKey: .sousTitre)) ?? defaut.sousTitre
        essai = try? c.decodeIfPresent(Essai.self, forKey: .essai)
    }
}

// MARK: Le visage du bouclier

/// Les trois issues de l'écran de garde d'Android (BlockerMode), dans un seul bouclier (§ 2.1.4).
public enum VisageBouclier: String, Sendable, CaseIterable {
    /// `PROMPT` : rien n'a encore été fait aujourd'hui.
    case invite
    /// `SESSION_RUNNING` : une séance est en cours, la seule issue est d'y retourner.
    case seance
    /// `PREVIEW` : l'essai réel, sans effet.
    case apercu

    /// Le visage à montrer à `millis` : l'essai d'abord (le service d'Android ne réévaluait plus pendant
    /// l'aperçu), puis la séance inscrite dans etat.json, sinon l'invitation. Une séance minutée dont la fin
    /// est passée garde son visage : « Revenir à la hitbodedout » ouvre l'app, qui la clôt et l'inscrit.
    public static func actuel(etat: Etat?, decor: DecorBouclier?, evenements: [Evenement],
                              millis: Int64) -> VisageBouclier {
        if PilotageBarriere.essaiEnCours(decor: decor, evenements: evenements, millis: millis) { return .apercu }
        if etat?.seance != nil { return .seance }
        return .invite
    }
}

/// L'illustration du visage : le hassid qui appelle (`Character.call`) ou en prière (`Character.during`).
public enum PoseBouclier: String, Sendable, CaseIterable {
    case appel
    case priere

    /// Le fichier que l'app dépose dans le dossier de la barrière pour cette pose.
    public var fichier: String {
        switch self {
        case .appel: ConteneurBarriere.imageAppel
        case .priere: ConteneurBarriere.imagePriere
        }
    }
}

/// Les textes d'un bouclier, ceux d'`Etat.Bouclier` (chaînes `blocker_*`).
public enum TexteBouclier: String, Sendable, CaseIterable {
    case question, sousTitre, serie, commencer, autreReponse, dejaFaite, plusTard, seanceTitre, seanceSousTitre,
         revenir, apercu, fermerApercu
}

/// Un bouton du bouclier : le principal, le secondaire, ou une entrée du sous-menu du secondaire (iOS 26.4),
/// numérotée depuis 0.
public enum BoutonBouclier: Sendable, Equatable {
    case principal
    case secondaire
    case sousMenu(Int)
}

/// Ce qu'un appui demande (les rappels de BlockerView : onStartSession, onAlreadyDone, onSnooze, onDismiss).
public enum ActionBouclier: String, Sendable, CaseIterable {
    /// « Commencer maintenant » : l'app s'ouvre et démarre la séance à la durée habituelle.
    case commencer
    /// « Revenir à la hitbodedout » : l'app s'ouvre sur la séance.
    case revenir
    /// « Je l'ai déjà faite » : une séance close à cet instant (`Store.addSession(context, 0)`).
    case dejaFaite
    /// « Plus tard (15 min) » : le report (`Store.snooze`).
    case plusTard
    /// « Fermer l'aperçu » : l'essai est levé.
    case fermerApercu
    /// Rien : le secondaire qui ouvre son sous-menu, ou un bouton absent de ce visage.
    case aucune
}

/// Ce que porte un visage du bouclier : `Texte` vaut `String` dans l'extension (les textes d'etat.json) et un
/// libellé dans la réplique de l'app, composés par la même règle (`VisageBouclier.contenu`).
public struct ContenuBouclier<Texte: Sendable & Equatable>: Sendable, Equatable {
    public var pose: PoseBouclier
    /// « APERÇU, AUCUN EFFET » (blocker_preview_badge) ; nil hors de l'essai.
    public var badge: Texte?
    public var titre: Texte
    /// Le sous-titre, puis la série : deux lignes de l'écran d'Android, un seul sous-titre sur iOS.
    public var lignes: [Texte]
    public var principal: Texte
    /// Le bouton secondaire ; nil s'il n'y en a pas.
    public var secondaire: Texte?
    /// Les entrées du sous-menu du secondaire, dans l'ordre (le système ajoute « Annuler »).
    public var sousMenu: [Texte]

    public init(pose: PoseBouclier, badge: Texte?, titre: Texte, lignes: [Texte], principal: Texte,
                secondaire: Texte?, sousMenu: [Texte]) {
        self.pose = pose
        self.badge = badge
        self.titre = titre
        self.lignes = lignes
        self.principal = principal
        self.secondaire = secondaire
        self.sousMenu = sousMenu
    }
}

extension ContenuBouclier where Texte == String {
    /// Le sous-titre du vrai bouclier, qui n'a qu'un champ : le badge de l'essai, le sous-titre et la série, un
    /// par ligne, les vides sautés.
    public var sousTitre: String {
        var morceaux: [String] = []
        if let badge, !badge.isEmpty { morceaux.append(badge) }
        for ligne in lignes where !ligne.isEmpty {
            morceaux.append(ligne)
        }
        return morceaux.joined(separator: "\n")
    }
}

extension VisageBouclier {

    /// Ce que porte le visage (le `when (mode)` de BlockerView), ses textes donnés par `texte`. « Je l'ai déjà
    /// faite » et « Plus tard » passent sous le bouton secondaire « Autre réponse », dans le sous-menu d'iOS 26.4.
    public func contenu<Texte: Sendable & Equatable>(_ texte: (TexteBouclier) -> Texte) -> ContenuBouclier<Texte> {
        switch self {
        case .invite:
            return ContenuBouclier(pose: .appel, badge: nil, titre: texte(.question),
                                   lignes: [texte(.sousTitre), texte(.serie)], principal: texte(.commencer),
                                   secondaire: texte(.autreReponse), sousMenu: [texte(.dejaFaite), texte(.plusTard)])
        case .seance:
            // Le bouclier est figé à son apparition : la phrase sans décompte (EtatBarriere.libelles).
            return ContenuBouclier(pose: .priere, badge: nil, titre: texte(.seanceTitre),
                                   lignes: [texte(.seanceSousTitre)], principal: texte(.revenir), secondaire: nil,
                                   sousMenu: [])
        case .apercu:
            // L'écran tel qu'il sera, sans ses issues : PREVIEW de BlockerView.
            return ContenuBouclier(pose: .appel, badge: texte(.apercu), titre: texte(.question),
                                   lignes: [texte(.sousTitre), texte(.serie)], principal: texte(.fermerApercu),
                                   secondaire: nil, sousMenu: [])
        }
    }

    /// Ce que demande un appui sur `bouton` dans ce visage.
    public func action(_ bouton: BoutonBouclier) -> ActionBouclier {
        switch (self, bouton) {
        case (.invite, .principal): .commencer
        case (.invite, .sousMenu(0)): .dejaFaite
        case (.invite, .sousMenu(1)): .plusTard
        case (.seance, .principal): .revenir
        case (.apercu, .principal): .fermerApercu
        default: .aucune
        }
    }
}

extension Etat.Bouclier {
    /// Le texte d'etat.json pour une place du bouclier.
    public subscript(_ texte: TexteBouclier) -> String {
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

// MARK: L'état vu par une extension

extension Etat {

    /// L'état tel qu'une extension le voit à `millis` : etat.json, plus ce que la boîte a appris depuis que l'app
    /// l'a écrit. Un « Je l'ai déjà faite » vaut une séance close (`JourneeValidee.avec`) ; un « Plus tard »
    /// prolonge le report de la durée qu'il porte ; une séance minutée dont la fin est passée vaut une séance
    /// close à sa fin (l'app, endormie, ne l'a pas encore inscrite) et n'est plus en cours. Rejouer deux fois le
    /// même événement ne change rien : l'app peut réécrire etat.json avant d'avoir vidé la boîte.
    public func vu(avec evenements: [Evenement], millis: Int64, fuseau: TimeZone) -> Etat {
        var resultat = self
        resultat.journee = journee.avec(evenements)
        for evenement in evenements where evenement.genre == Evenement.Genre.plusTard.rawValue {
            let minutes = Int(evenement.detail) ?? snoozeMinutes
            let fin = evenement.quand.millis + Int64(minutes) * 60_000
            if fin > resultat.snoozedUntil { resultat.snoozedUntil = fin }
        }
        if let seance, seance.fin > 0, seance.fin <= millis {
            let close = Evenement(quand: Horodatage(millis: seance.fin, fuseau: fuseau), genre: .dejaFaite)
            resultat.journee = resultat.journee.avec([close])
            resultat.seance = nil
        }
        return resultat
    }
}

// MARK: Les magasins et la surveillance

/// Les activités surveillées (§ 2.1.5, § 2.1.6, § 2.1.10) : cinq des vingt que le système accepte.
public enum ActiviteBarriere: String, Sendable, CaseIterable {
    /// De `window_start` à `window_end`, chaque jour.
    case fenetre
    /// De 00:00 à 00:15, chaque jour : la fenêtre de nuit, le jour chômé qui commence, `fenetreFaite`.
    case minuit
    /// Un seul intervalle, qui commence à la fin du report.
    case report
    /// Un seul intervalle, qui commence à la fin prévue de la séance.
    case seance
    /// Un seul intervalle, qui commence à la fin de l'essai réel.
    case essai

    /// Les activités d'un seul intervalle : arrêtées dès que leur début est reçu.
    public var ponctuelle: Bool {
        switch self {
        case .fenetre, .minuit: false
        case .report, .seance, .essai: true
        }
    }
}

/// Le début ou la fin d'un intervalle surveillé (`intervalDidStart`, `intervalDidEnd`).
public enum BorneActivite: String, Sendable {
    case debut
    case fin
}

/// Un réveil de l'extension de surveillance.
public struct RendezVous: Sendable, Equatable {
    public var activite: ActiviteBarriere
    public var borne: BorneActivite

    public init(_ activite: ActiviteBarriere, _ borne: BorneActivite) {
        self.activite = activite
        self.borne = borne
    }

    /// Ce que l'extension écrit dans la boîte (`reveil`) : « fenetre:debut ».
    public var detail: String { activite.rawValue + ":" + borne.rawValue }
}

/// L'état voulu des trois magasins nommés : chacun porte les jetons de la sélection et n'est qu'activé ou
/// désactivé (`isActive`, iOS 26.5).
public struct ConsigneMagasins: Sendable, Equatable {
    /// `barriere` : la barrière veille.
    public var barriere: Bool
    /// `seance` : une séance est en cours (« Hitbodedout en cours », même hors de la fenêtre).
    public var seance: Bool
    /// `essai` : l'essai réel de deux minutes.
    public var essai: Bool

    public init(barriere: Bool, seance: Bool, essai: Bool) {
        self.barriere = barriere
        self.seance = seance
        self.essai = essai
    }
}

/// La règle des magasins, pour l'extension de surveillance à ses rendez-vous et pour l'app à chaque changement.
public enum PilotageBarriere {

    /// Les noms des magasins (`ManagedSettingsStore.Name`).
    public static let magasinBarriere = "barriere"
    public static let magasinSeance = "seance"
    public static let magasinEssai = "essai"

    /// L'essai réel dure deux minutes (§ 2.1.8).
    public static let dureeEssai: Int64 = 2 * 60_000
    /// Le détail des événements `essai` de la boîte.
    public static let debutEssai = "debut"
    public static let finEssai = "fin"

    /// L'essai court à `millis` : déposé par l'app, pas encore fini, et pas levé par « Fermer l'aperçu »
    /// (un événement `essai` « fin » de la boîte, postérieur à son début).
    public static func essaiEnCours(decor: DecorBouclier?, evenements: [Evenement], millis: Int64) -> Bool {
        guard let essai = decor?.essai, essai.debut <= millis, millis < essai.fin else { return false }
        for evenement in evenements where evenement.genre == Evenement.Genre.essai.rawValue {
            if evenement.detail == finEssai, evenement.quand.millis >= essai.debut { return false }
        }
        return true
    }

    /// L'état voulu des magasins à `millis`. Sans etat.json (l'app ne l'a jamais écrit), ni barrière ni séance.
    ///
    /// La barrière veille quand la règle d'Android le dit (`Evaluation.regle`, sur l'état vu) et qu'aucune séance
    /// ne court : pendant une séance, c'est le magasin `seance` qui retient, à toute heure (§ 2.1.10).
    ///
    /// Un rendez-vous compte à sa borne, même reçu un peu avant : au début de `fenetre`, la fenêtre est ouverte ;
    /// au début de `report`, le report est fini ; au début de `seance`, la séance est close ; au début d'`essai`,
    /// l'essai est fini. À la fin de `fenetre`, la barrière se lève.
    public static func consigne(etat: Etat?, decor: DecorBouclier?, evenements: [Evenement], millis: Int64,
                                fuseau: TimeZone, rendezVous: RendezVous? = nil) -> ConsigneMagasins {
        var essai = essaiEnCours(decor: decor, evenements: evenements, millis: millis)
        if rendezVous?.activite == .essai { essai = false }
        guard let etat else { return ConsigneMagasins(barriere: false, seance: false, essai: essai) }
        var vu = etat.vu(avec: evenements, millis: millis, fuseau: fuseau)
        var maintenant = Horodatage(millis: millis, fuseau: fuseau)
        if let rendezVous, rendezVous.borne == .debut {
            switch rendezVous.activite {
            case .fenetre:
                if !Evaluation.inWindow(vu, minutes: maintenant.minutes) { maintenant.minutes = vu.windowStart }
            case .report:
                if vu.snoozedUntil > millis { maintenant = Horodatage(millis: vu.snoozedUntil, fuseau: fuseau) }
            case .seance:
                if let seance = etat.seance, seance.fin > millis {
                    vu = etat.vu(avec: evenements, millis: seance.fin, fuseau: fuseau)
                    maintenant = Horodatage(millis: seance.fin, fuseau: fuseau)
                }
            case .minuit, .essai:
                break
            }
        }
        let seance = vu.seance != nil
        var barriere = !seance && Evaluation.regle(vu, maintenant: maintenant) == .armed
        if rendezVous == RendezVous(.fenetre, .fin) { barriere = false }
        return ConsigneMagasins(barriere: barriere, seance: seance, essai: essai)
    }

    /// L'activité est à arrêter après ce rendez-vous : une activité d'un seul intervalle, dès son début.
    public static func aArreter(_ rendezVous: RendezVous) -> Bool {
        rendezVous.activite.ponctuelle && rendezVous.borne == .debut
    }

    /// L'intervalle d'une activité d'un seul intervalle qui commence à `debut` : l'intervalle minimal que le
    /// système accepte (§ 2.1.6). Planifier le début évite un intervalle trop court.
    public static func intervallePonctuel(debut: Int64) -> (debut: Int64, fin: Int64) {
        (debut, debut + Int64(Evaluation.intervalleMinimum) * 60_000)
    }

    /// L'heure et la minute d'une borne en minutes depuis minuit, ramenée dans la journée.
    public static func heureMinute(_ minutes: Int) -> (heure: Int, minute: Int) {
        let jour = 24 * 60
        let m = ((minutes % jour) + jour) % jour
        return (heure: m / 60, minute: m % 60)
    }

    /// Une borne quotidienne de `DeviceActivitySchedule` (`repeats: true`) : l'heure et la minute seules.
    public static func composantesQuotidiennes(_ minutes: Int) -> DateComponents {
        let borne = heureMinute(minutes)
        return DateComponents(hour: borne.heure, minute: borne.minute)
    }

    /// Une borne d'un seul intervalle (`repeats: false`) : la date et l'heure civiles de `millis` dans `fuseau`,
    /// à la seconde, au calendrier grégorien.
    public static func composantesDate(_ millis: Int64, fuseau: TimeZone) -> DateComponents {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = fuseau
        let instant = Date(timeIntervalSince1970: Double(millis) / 1000)
        return calendrier.dateComponents([.year, .month, .day, .hour, .minute, .second], from: instant)
    }
}
