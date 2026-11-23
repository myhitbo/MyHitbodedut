import Foundation
import Observation
import Coeur

// Le choix du lieu des zmanim (ChoixLieu.kt, 10/10) : la position du téléphone, ou une ville de la liste
// (GeoNames). La position ne demande que la localisation approximative (31/10) : 3 km d'écart déplacent les
// zmanim de moins d'une minute ; elle n'est demandée qu'au moment où on la choisit, ne sert qu'au calcul et
// reste sur l'appareil.
//
// Une position enregistrée prend le nom de la ville la plus proche (« Ma position · près de Jérusalem »), à moins
// de 60 km (Villes.plusProche), et son altitude ; le fuseau reste celui du téléphone (celui d'une ville voisine
// fausserait les zmanim près d'une frontière), et Israël ou diaspora se lit sur le territoire (TerritoireIsrael),
// pas sur la ville (16/10). Une ville choisie règle Israël d'après son pays (Reglages.setLieuZmanim).
//
// Le nom du lieu est écrit dans les réglages déjà traduit, dans la langue de l'app au moment du choix, comme
// Android : d'où le `Traducteur` reçu.
//
// Ce que fait le système d'Android dans `localiser` (position connue de moins de deux minutes, fournisseurs
// interrogés ensemble, 25 s de délai, dernière position connue à défaut) est l'affaire de l'adaptateur de
// `Localisation` (ios/App/Services) : ici, sa réponse.

// MARK: La position gardée

/// Au sol, le kilomètre suffit (zmanim, direction de Jérusalem) : rien de plus précis n'est gardé
/// (ChoixLieu.PositionSol, examen du 14/11).
public enum PositionSol {
    /// `Math.round(degres * 100.0) / 100.0` : le centième de degré.
    public static func arrondie(_ degres: Double) -> Double {
        Double(Kotlin.arrondiLong(degres * 100.0)) / 100.0
    }

    /// La position arrondie.
    public static func arrondie(_ position: PositionApprochee) -> PositionApprochee {
        PositionApprochee(latitude: arrondie(position.latitude), longitude: arrondie(position.longitude))
    }
}

// MARK: Ce que le système dit sans rien demander

/// L'autorisation de localisation, lue sans la demander : `ChoixLieu.localisationPermise`. Sert à reprendre la
/// position en silence à l'ouverture de l'écran, sans jamais faire paraître la demande d'iOS.
public protocol LieuAutorisation: Sendable {
    /// La localisation (approximative ou précise) est-elle déjà permise ?
    func localisationPermise() async -> Bool
}

/// Une autorisation fixée d'avance, pour les tests et les aperçus.
public actor LieuAutorisationFausse: LieuAutorisation {
    public private(set) var lectures = 0
    private let permise: Bool

    public init(permise: Bool) {
        self.permise = permise
    }

    public func localisationPermise() -> Bool {
        lectures += 1
        return permise
    }
}

// MARK: Ce que l'écran montre

/// Le nom d'une entrée de la liste : « Ma position » (une chaîne), ou le nom d'une ville dans la langue de l'app.
public enum LieuNom: Sendable, Equatable {
    case libelle(Libelle)
    case texte(String)
}

/// Une entrée du dialogue « Choisir le lieu » (ChoixLieu.montrer) : « Ma position » d'abord, puis les villes dans
/// l'ordre de `villes.json`.
public struct LieuOption: Sendable, Equatable, Identifiable {
    /// « position », ou l'identifiant GeoNames de la ville.
    public let id: String
    public let nom: LieuNom
    /// nil pour « Ma position ».
    public let ville: Ville?
}

/// Le message bref d'Android (un `Toast`) ; la vue le montre, puis appelle `messageVu()`.
public enum LieuMessage: Sendable, Equatable {
    /// « Recherche de la position… » (court).
    case attente
    /// « Pas de position fraîche : la dernière connue est utilisée. » (long).
    case ancienne
    /// « Position indisponible : choisissez une ville. » (long).
    case refusee

    public var libelle: Libelle {
        switch self {
        case .attente: Libelle("zmanim_position_attente")
        case .ancienne: Libelle("zmanim_position_ancienne")
        case .refusee: Libelle("zmanim_position_refusee")
        }
    }

    /// Le `Toast.LENGTH_LONG` d'Android ; court sinon.
    public var long: Bool {
        self != .attente
    }
}

// MARK: Le modèle

/// Le choix du lieu, partagé par l'onglet Zmanim, le calendrier, la boussole et l'accueil.
@MainActor
@Observable
public final class LieuModele {

    /// Six heures : au retour sur l'accueil, une position plus vieille se reprend (02/11).
    public static let sixHeures: Int64 = 6 * 3_600_000
    /// Deux heures (ChoixLieu.FOND_MAX_MS) : sans bruit, une position connue plus vieille ne remplace pas un lieu
    /// périmé par un changement de fuseau, à qui elle donnerait le nouveau fuseau sans être du nouvel endroit.
    public static let deuxHeures: Int64 = 2 * 3_600_000

    private let magasin: Magasin
    private let contenus: ContenusApp?
    private let localisation: (any Localisation)?
    private let autorisation: (any LieuAutorisation)?
    private let horloge: any Horloge
    private let traducteur: Traducteur

    /// Les villes de `villes.json` ; vides tant qu'elles ne sont pas lues (`charger()`), ou si elles n'ont pu
    /// l'être.
    public private(set) var villes: [Ville] = []
    /// Le dialogue « Choisir le lieu » est-il ouvert ?
    public var dialogueOuvert = false
    /// Le message bref à montrer ; nil sinon.
    public private(set) var message: LieuMessage?
    /// Une demande de position est en cours.
    public private(set) var enCours = false
    @ObservationIgnored private var villesLues = false

    public init(magasin: Magasin, contenus: ContenusApp?, localisation: (any Localisation)?,
                autorisation: (any LieuAutorisation)?, horloge: any Horloge, traducteur: Traducteur) {
        self.magasin = magasin
        self.contenus = contenus
        self.localisation = localisation
        self.autorisation = autorisation
        self.horloge = horloge
        self.traducteur = traducteur
    }

    /// « fr », « en » ou « he » : la langue des noms de ville.
    public var langue: String {
        traducteur.langue
    }

    /// Lit les villes, une fois.
    public func charger() async {
        guard !villesLues, let contenus else { return }
        if let lues = try? await contenus.villes() {
            villes = lues
            villesLues = true
        }
    }

    // MARK: Le dialogue

    /// Le titre du dialogue : « Choisir le lieu ».
    public var titre: Libelle {
        Libelle("zmanim_choisir_lieu")
    }

    /// « Ma position », puis les villes dans la langue de l'app (`nom.forLanguage(langue)`).
    public var options: [LieuOption] {
        var options = [LieuOption(id: "position", nom: .libelle(Libelle("zmanim_position")), ville: nil)]
        let langue = self.langue
        for ville in villes {
            options.append(LieuOption(id: String(ville.id), nom: .texte(ville.nom.pour(langue)), ville: ville))
        }
        return options
    }

    /// Le bandeau ou la carte « Choisir le lieu » ont été touchés.
    public func montrer() {
        dialogueOuvert = true
    }

    /// Une entrée du dialogue : la position (demandée au besoin), ou la ville. Le dialogue se ferme.
    public func choisir(_ option: LieuOption) async throws {
        dialogueOuvert = false
        if let ville = option.ville {
            try await choisirVille(ville)
        } else {
            try await maPosition()
        }
    }

    /// Une ville de la liste : son nom dans la langue de l'app, ses coordonnées, son altitude et son fuseau ;
    /// Israël d'après son pays.
    public func choisirVille(_ ville: Ville) async throws {
        let lieu = Zmanim.Lieu(nom: ville.nom.pour(langue), latitude: ville.latitude, longitude: ville.longitude,
                               altitude: ville.altitude, fuseau: ville.fuseau)
        let maintenant = horloge.maintenant, aujourdhui = horloge.aujourdhui, fuseau = horloge.fuseau.identifiant
        try await magasin.modifierReglages {
            $0.setLieuZmanim(lieu, ville: ville, maintenant: maintenant, aujourdhui: aujourdhui, fuseauTelephone: fuseau)
        }
    }

    // MARK: La position

    /// « Ma position » (et « Actualiser ma position » de la boussole) : demandée au système, l'autorisation
    /// d'abord si iOS ne l'a pas encore demandée. « Recherche de la position… » le temps de la réponse ; un refus
    /// ou une absence de réponse : « Position indisponible : choisissez une ville. ».
    public func maPosition() async throws {
        try await localiser(silencieux: false)
    }

    /// À l'ouverture de l'écran (onResume de Zmanim, de la boussole) : si le lieu est la position du téléphone et
    /// que la localisation est déjà permise, la reprendre sans rien dire ; rien n'est demandé.
    public func rafraichir() async throws {
        let reglages = magasin.reglages
        guard reglages.lieuZmanim != nil, reglages.lieuVille == -1, let autorisation else { return }
        guard await autorisation.localisationPermise() else { return }
        try await localiser(silencieux: true)
    }

    /// Au retour sur l'accueil (02/11) : la position n'est reprise que si elle est périmée par un changement de
    /// fuseau, ou vieille de plus de six heures.
    public func rafraichirSiBesoin() async throws {
        let reglages = magasin.reglages
        let age = horloge.maintenant - reglages.lieuDepuis
        if reglages.lieuPerime(fuseauTelephone: horloge.fuseau.identifiant) || age < 0 || age >= LieuModele.sixHeures {
            try await rafraichir()
        }
    }

    /// Le message a été montré.
    public func messageVu() {
        message = nil
    }

    private func localiser(silencieux: Bool) async throws {
        guard let localisation else {
            if !silencieux { message = .refusee }
            return
        }
        if !silencieux { message = .attente }
        enCours = true
        let reponse = await localisation.positionApprochee()
        enCours = false
        switch reponse {
        case .position(let position):
            if message == .attente { message = nil }
            try await enregistrer(position)
        case .ancienne(let position, let age):
            // ChoixLieu.ancienne : après un voyage, une position d'avant le départ ne remplace pas la périmée.
            if silencieux && magasin.reglages.lieuPerime(fuseauTelephone: horloge.fuseau.identifiant)
                && age > LieuModele.deuxHeures {
                return
            }
            if !silencieux { message = .ancienne }
            try await enregistrer(position)
        case .refusee, .indisponible:
            if !silencieux { message = .refusee }
        }
    }

    /// ChoixLieu.enregistrerPosition : la ville la plus proche nomme la position et donne son altitude ; le fuseau
    /// est celui du téléphone. Israël ou diaspora se lit sur le territoire, et ne fait que poser la question
    /// (audit du 16/11, Store.setLieuPosition) : le statut suit la résidence, pas le lieu.
    public func enregistrer(_ position: PositionApprochee) async throws {
        await charger()
        let lieu = LieuModele.lieu(position, villes: villes, fuseauTelephone: horloge.fuseau, traducteur: traducteur)
        let maintenant = horloge.maintenant, aujourdhui = horloge.aujourdhui, fuseau = horloge.fuseau.identifiant
        try await magasin.modifierReglages { (reglages: inout Reglages) -> Void in
            reglages.setLieuZmanim(lieu, ville: nil, maintenant: maintenant, aujourdhui: aujourdhui, fuseauTelephone: fuseau)
        }
    }

    /// Le lieu d'une position, arrondie au kilomètre (PositionSol) : « Ma position · près de <ville> » (dans la
    /// langue du traducteur) et l'altitude de la ville la plus proche à moins de 60 km ; sinon « Ma position » et le
    /// niveau de la mer.
    public static func lieu(_ brute: PositionApprochee, villes: [Ville], fuseauTelephone: Fuseau,
                            traducteur: Traducteur) -> Zmanim.Lieu {
        let position = PositionSol.arrondie(brute)
        let proche = Villes.plusProche(villes, position.latitude, position.longitude)
        let nom: String
        if let proche {
            nom = traducteur.texte(Libelle("zmanim_position_pres", .texte(proche.nom.pour(traducteur.langue))))
        } else {
            nom = traducteur.texte(Libelle("zmanim_position"))
        }
        return Zmanim.Lieu(nom: nom, latitude: position.latitude, longitude: position.longitude,
                           altitude: proche?.altitude ?? 0, fuseau: fuseauTelephone.identifiant)
    }
}
