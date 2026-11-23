import Foundation
import Observation
import Coeur

// Les zmanim en vol (VolActivity.kt, activity_vol.xml ; LecteurBillet.kt et VolAlerte.kt pour le billet et les
// notifications) : on saisit le vol (une phrase, le billet, ou les tuiles : aéroports et heures du billet, à
// l'heure de chaque aéroport) ; l'écran montre la prière du moment et son compte à rebours, la frise des zmanim
// de la route, Chabbat, fêtes et Omer, les rappels, la fiabilité. Le calcul est celui de Coeur (Vol, VolPriere,
// VolCalendrier, VolRappels), hors ligne ; rien ne sort du téléphone sans les services en ligne, qui n'existent
// qu'avec un relais (`VolEnLigne`).

// MARK: Ce que montre l'écran

/// Un dialogue de l'écran.
public enum VolDialogue: Sendable, Hashable {
    /// Une boîte « OK » (message d'Android) : un vol incomplet ou invalide, le GPS, le suivi en direct.
    case message(Libelle)
    /// « Chercher la route en ligne ? » (vol_en_ligne_titre, vol_en_ligne_aide ; « Activer et chercher »,
    /// « Annuler ») : la loupe touchée, services en ligne éteints.
    case enLigne
    /// La recherche d'un aéroport (vol_choisir_aeroport) pour la tuile donnée.
    case aeroport(VolTuile.Genre)
    /// Le choix de la date puis de l'heure, à l'heure locale de l'aéroport, ouvert sur `initiale`.
    case heure(VolChampHeure, initiale: DateHeure)
}

/// Ce que fixe le choix d'une heure.
public enum VolChampHeure: Sendable, Hashable {
    case decollage
    case atterrissage
    /// L'heure de départ qui manque à la saisie rapide (un code-barres n'en porte pas) : elle s'ouvre d'elle-même.
    case saisieRapide
}

/// Les volets repliés de l'écran (« Titre ⌄ ») : ouverts, ils le restent quand l'écran se redessine.
public enum VolVolet: String, Sendable, Hashable, CaseIterable {
    /// « Méthode et sources ».
    case sources
    /// « Comment c'est calculé ? ».
    case commentCalcule
    /// « Préciser la position ».
    case preciser
}

/// Une tuile du formulaire : l'étiquette en petit, la valeur (ou l'invite, plus pâle), un chevron.
public struct VolTuile: Sendable, Hashable, Identifiable {
    public enum Genre: String, Sendable, Hashable {
        case depart, arrivee, decollage, atterrissage
    }

    public let genre: Genre
    public let etiquette: Libelle
    /// « LYS · Lyon », « mar. 17 nov. 2026 · 11:00 » ; nil tant que rien n'est choisi.
    public let valeur: String?
    /// « Choisir un aéroport », « Choisir la date et l'heure ».
    public let invite: Libelle

    public var id: String { genre.rawValue }
}

/// Une ligne de la recherche d'aéroport : le code dans une pastille, la ville, puis l'aéroport et le pays.
public struct VolAeroportLigne: Sendable, Hashable, Identifiable {
    public let aeroport: Vol.Aeroport
    /// « TLV ».
    public var iata: String { aeroport.iata }
    /// La ville, ou le nom local de l'aéroport sans ville.
    public let titre: String
    /// « Ben Gourion · IL » : des noms propres et un code pays, rien à traduire.
    public let detail: String

    public var id: String { aeroport.iata }
}

/// Le vol calculé, replié en résumé : « LY81 · TLV → BKK », « Modifier », les heures du billet.
public struct VolResume: Sendable, Hashable {
    public let titre: Libelle
    /// « mer. 28 ⁦19:20 TLV⁩ » : le décollage à l'heure du départ.
    public let depart: String
    /// L'atterrissage à l'heure de l'arrivée.
    public let arrivee: String
}

/// Le ciel de la carte de la prière : un dégradé selon l'heure.
public enum VolCiel: String, Sendable, Hashable {
    /// L'aube : #2B3F6E → #8C5A7A → #E0906B.
    case chaharit
    /// L'or de l'après-midi : #17525A → #6E7A3E → #C9962E.
    case minha
    /// La nuit : #0E1530 → #1E2A55 → #3E4F86.
    case arvit
    /// Hors de la fenêtre du calcul : la couleur de marque, puis la marque assombrie de 35 %.
    case aucun
}

/// La prière du moment mise en avant.
public struct VolCartePriere: Sendable, Hashable {
    public let ciel: VolCiel
    /// « Cha'harit » ; nil hors de la fenêtre du calcul.
    public let nom: Libelle?
    /// « Le calcul couvre le vol et les 6 heures qui l'entourent. » (sans prière) ou « jusqu'à l'aube, sans limite
    /// affichée » (sans limite).
    public let message: Libelle?
    /// « encore 1 h 11 min », en grand.
    public let compte: Libelle?
    /// « jusqu'à mar. 10 ⁦18:42 TLV⁩ · ⁦11:42 JFK⁩ ».
    public let jusqua: Libelle?
    /// « +12 min si le départ a 30 min de retard ».
    public let ecart: Libelle?
    /// La limite, en millisecondes Unix.
    public let limite: Int64?
}

/// Le ciel d'un point de la frise : son icône et sa teinte.
public enum VolCielFrise: String, Sendable, Hashable {
    case nuit, aube, jour, crepuscule
    /// Le décollage et l'atterrissage : l'avion, à la couleur de marque.
    case bout
    /// « Maintenant » : un rond cerclé de la marque.
    case maintenant

    /// L'icône d'Android (res/drawable) ; nil pour « maintenant ».
    public var icone: String? {
        switch self {
        case .nuit: return "ic_frise_nuit"
        case .aube: return "ic_frise_aube"
        case .jour: return "ic_frise_jour"
        case .crepuscule: return "ic_frise_crepuscule"
        case .bout: return "ic_frise_avion"
        case .maintenant: return nil
        }
    }

    /// La teinte (ARGB) ; nil : la couleur de marque.
    public var teinte: UInt32? {
        switch self {
        case .nuit: return 0xFF3E_4F86
        case .aube: return 0xFFD4_856B
        case .jour: return 0xFFC9_9A2E
        case .crepuscule: return 0xFFB5_543A
        case .bout, .maintenant: return nil
        }
    }

    /// La couleur de ciel d'un zman (CIEL de VolActivity) ; le jour à défaut.
    static func de(_ cle: String) -> VolCielFrise {
        switch cle {
        case "chatsot_layla", "tset", "tset_rt": return .nuit
        case "alot", "misheyakir", "netz": return .aube
        case "chkia": return .crepuscule
        default: return .jour
        }
    }
}

/// Une ligne de la frise.
public struct VolPointFrise: Sendable, Hashable, Identifiable {
    /// Le rang dans la frise.
    public let id: Int
    public let ciel: VolCielFrise
    /// « Décollage LYS », « Tsét hakokhavim », « Maintenant » (à écrire en capitales).
    public let nom: Libelle
    /// L'heure du départ, en gras : « mar. 17 ⁦11:00 LYS⁩ » ; nil pour « maintenant ».
    public let heureDepart: String?
    /// « ⁦16:05 TLV⁩ », plus légère, après « · ».
    public let heureArrivee: String?
    /// « au-dessus de 44,1° N, 12,3° E · +12 min si le départ a 30 min de retard ».
    public let detail: Libelle?
    /// La dernière ligne : son trait vers la suivante est caché.
    public let dernier: Bool
}

/// La frise du vol : du décollage à l'atterrissage, une icône par zman, et « maintenant » à sa place.
public struct VolFrise: Sendable, Hashable {
    /// Aucun zman pendant le vol : « Aucun zman pendant ce vol. » à la place de la frise.
    public let vide: Bool
    /// « Si le vol est retardé, les horaires changeront en conséquence. », dit une fois en tête.
    public let noteRetard: Bool
    public let points: [VolPointFrise]
}

/// Un jalon de Chabbat, d'une fête ou du Omer pendant le vol.
public struct VolJalonLigne: Sendable, Hashable, Identifiable {
    public let id: Int
    /// « Entrée de Chabbat : chki'a mar. 10 ⁦18:42 TLV⁩ · ⁦11:42 JFK⁩ », en gras.
    public let texte: Libelle
    /// « Allumage, 18 min avant la chki'a : … » ; à l'entrée seulement.
    public let allumage: Libelle?
    /// « au-dessus de … », en petit.
    public let position: Libelle
    /// Vol polaire sans tsét après cette chki'a : le repère de repli est dit (audit du 16/11) ; nil sinon.
    public let repli: Libelle?
}

/// Chabbat, fêtes et Omer sur la route (VolCalendrier) : des heures, sans conseil.
public struct VolCarteJalons: Sendable, Hashable {
    /// La ligne de date est franchie (audit du 16/11) : son tracé est discuté ; nil sinon.
    public let ligneDateDiscutee: Libelle?
    /// Pendant le Omer, la ligne de date donne deux comptes (VolCalendrier.ligneDateOmer) ; nil sinon.
    public let omerLigneDate: Libelle?
    public let lignes: [VolJalonLigne]
    /// « Jour civil du point sous l'avion ; calendrier d'Israël, d'après le réglage de l'application. »
    public let note: Libelle
}

/// Un rappel à venir : son titre et son heure.
public struct VolRappelLigne: Sendable, Hashable, Identifiable {
    public let id: Int
    public let titre: Libelle
    public let heure: String
}

/// Les rappels pendant le vol : l'interrupteur, puis chaque rappel à venir.
public struct VolCarteRappels: Sendable, Hashable {
    /// L'interrupteur « Me rappeler pendant le vol ».
    public let actifs: Bool
    /// « Les notifications de l'application sont désactivées… » (rappels actifs seulement).
    public let sansPermission: Bool
    /// « Plus aucun rappel pendant ce vol. » (rappels actifs seulement).
    public let aucun: Bool
    /// Vide si les rappels sont éteints.
    public let lignes: [VolRappelLigne]
    /// La note en pied (rappels actifs seulement), 12 pt, pâle. Celle d'Android nomme Android : une clé propre à
    /// iOS est demandée (voir le rapport de la tâche 26) ; d'ici là, la phrase d'Android.
    public let note: Libelle?
}

/// Le suivi en direct, sous « Préciser la position » ; seulement avec un relais.
public struct VolSuiviDirect: Sendable, Hashable {
    /// L'interrupteur des services en ligne (vol_direct_activer).
    public let actif: Bool
    /// Le bouton : « Position en direct », ou « Demande de la position… » désactivé pendant la demande.
    public let bouton: Libelle
    public let enCours: Bool
}

/// La position et sa précision.
public struct VolCarteFiabilite: Sendable, Hashable {
    /// La pastille « 📍 Estimation sur la route prévue » (sans relevé) ; sinon `releve`.
    public let pastille: Bool
    /// « Route recalée sur le relevé GPS de … (au-dessus de …), … ».
    public let releve: Libelle?
    /// Le bouton GPS : « Position réelle (GPS) », ou « Recherche du signal GPS… » pendant le relevé ; nil sans
    /// service de localisation (un aperçu).
    public let gps: Libelle?
    public let gpsEnCours: Bool
    /// Le lien « Revenir à la route prévue » : un relevé est gardé.
    public let oublier: Bool
    /// nil sans relais : rien du suivi en direct n'apparaît.
    public let direct: VolSuiviDirect?
    /// Les réserves du calcul, dans l'ordre de `Vol.Reserve`.
    public let reserves: [Libelle]
    /// Les passages de la ligne de changement de date.
    public let lignesDate: [Libelle]
}

/// Les cartes du vol calculé, dans l'ordre : l'essentiel d'abord (la prière, la frise, Chabbat et fêtes), puis les
/// rappels, la position en dernier.
public struct VolCartes: Sendable, Hashable {
    public let priere: VolCartePriere
    public let frise: VolFrise
    public let jalons: VolCarteJalons?
    public let rappels: VolCarteRappels
    public let fiabilite: VolCarteFiabilite
}

/// La zone des résultats, sous le formulaire.
public enum VolResultats: Sendable, Hashable {
    /// Aucun vol calculé : rien.
    case aucun
    /// Le calcul tourne : une carte « Calcul en cours… ».
    case enCours
    case cartes(VolCartes)
}

// MARK: Le modèle

/// L'écran du vol (VolActivity.kt).
///
/// Il reçoit le `Magasin` (le vol gardé, ses rappels, Israël ou diaspora, l'allumage, les interrupteurs), les
/// aéroports (lus hors du fil principal, comme Android le fait depuis le 04/11), l'horloge, le `Notificateur` des
/// Services et de quoi retirer les notifications du vol, la localisation (le relevé « GPS »), le lecteur de billet,
/// les services en ligne (avec le relais seulement), le `Traducteur` (la langue, et les listes jointes comme
/// Android les joint) et l'écriture des heures (`VolFormats`).
///
/// La vue appelle `apparaitre()` à l'affichage, puis `battre()` toutes les 30 secondes (le compte à rebours, la
/// place de « maintenant ») ; elle lit les propriétés et appelle les actions, sans autre logique.
@MainActor
@Observable
public final class VolModele {

    private let magasin: Magasin
    private let horloge: any Horloge
    private let chargerAeroports: @Sendable () async throws -> [Vol.Aeroport]
    private let notificateur: any Notificateur
    private let retrait: (any VolRetraitNotifications)?
    private let localisation: (any Localisation)?
    private let lecteurBillet: (any VolLecteurBillet)?
    private let enLigne: VolEnLigne?
    private let traducteur: Traducteur
    /// L'écriture des heures et des dates.
    public let formats: VolFormats

    // MARK: L'état

    /// Les aéroports sont lus : le formulaire peut s'afficher. Avant, une seule carte « Calcul en cours… ».
    public private(set) var pret = false
    /// La liste des aéroports n'a pu être lue : le formulaire s'affiche, aucune recherche n'aboutit.
    public private(set) var aeroportsIllisibles = false
    @ObservationIgnored private var aeroports: [Vol.Aeroport] = []

    /// Le vol gardé (Store.vol) : celui des résultats et du résumé ; nil tant qu'aucun vol complet n'est calculé.
    public private(set) var plan: Vol.Plan?

    /// Le champ du numéro (12 caractères au plus, en capitales, sans suggestions).
    public var numeroSaisi = ""
    public private(set) var depart: Vol.Aeroport?
    public private(set) var arrivee: Vol.Aeroport?
    /// Le décollage, à l'heure locale de l'aéroport de départ (celle du billet).
    public private(set) var decollage: DateHeure?
    /// L'atterrissage, à l'heure locale de l'aéroport d'arrivée.
    public private(set) var atterrissage: DateHeure?
    /// Une date sans heure (code-barres, « demain ») : le choix de l'heure s'ouvre sur elle.
    public private(set) var dateSeule: JourCivil?
    /// L'arrivée a été estimée d'après la distance : on le dit sous la tuile.
    public private(set) var arriveeEstimee = false

    /// Le texte de la saisie rapide, gardé quand l'écran se redessine.
    public var phrase = ""
    /// Ce que la saisie rapide a compris, ou ce qui manque : une ligne par `Libelle` ; nil avant toute saisie.
    public private(set) var rapide: [Libelle]?

    /// Le formulaire rouvert pour modifier le vol calculé.
    public private(set) var modifier = false

    public private(set) var calcul: Vol.Calcul?
    public private(set) var calculEnCours = false
    public private(set) var gpsEnCours = false
    public private(set) var directEnCours = false
    public private(set) var routeEnCours = false
    /// Ce qu'a donné la loupe (route trouvée, introuvable, erreur).
    public private(set) var routeTexte: Libelle?
    /// Le champ de l'indicatif radio du suivi en direct (9 caractères au plus, en capitales).
    public var indicatifSaisi = ""

    public private(set) var voletsOuverts: Set<VolVolet> = []
    public private(set) var dialogue: VolDialogue?

    /// Le champ de la recherche d'aéroport.
    public private(set) var recherche = ""
    @ObservationIgnored private var trouves: [Vol.Aeroport] = []
    /// Les résultats de la recherche.
    public private(set) var lignesAeroports: [VolAeroportLigne] = []

    /// L'instant que montrent les résultats, avancé par `battre()`.
    public private(set) var maintenant: Int64
    /// L'autorisation de notifier : sans elle, la carte des rappels le dit.
    public private(set) var notificationsAutorisees = true

    /// Chaque calcul lancé ou vol effacé : un calcul fini après un autre n'est pas montré.
    @ObservationIgnored private var generation = 0
    /// Le plan jugé invraisemblable pour lequel l'avertissement a déjà été donné, sans son relevé (FVOL-12).
    @ObservationIgnored private var avertiPour: Vol.Plan?
    /// La lecture des aéroports est lancée : un second `apparaitre()` ne la refait pas.
    @ObservationIgnored private var lectureLancee = false

    /// - Parameters:
    ///   - aeroports: la liste des aéroports, lue une fois (`VolModele.lireAeroports(lecteur:)`).
    ///   - retrait: ce qui retire les notifications du vol ; sans lui, elles ne sont que remplacées.
    ///   - localisation: le relevé de position ; sans elle, pas de bouton GPS.
    ///   - lecteurBillet: la lecture d'un billet ; sans lui, pas de bouton « Importer le billet ».
    ///   - enLigne: la route et le suivi en direct ; sans lui, ou sans relais en HTTPS, rien en ligne.
    public init(magasin: Magasin, horloge: any Horloge,
                aeroports: @escaping @Sendable () async throws -> [Vol.Aeroport],
                notificateur: any Notificateur, retrait: (any VolRetraitNotifications)? = nil,
                localisation: (any Localisation)? = nil, lecteurBillet: (any VolLecteurBillet)? = nil,
                enLigne: VolEnLigne? = nil, traducteur: Traducteur, formats: VolFormats = .neutre) {
        self.magasin = magasin
        self.horloge = horloge
        chargerAeroports = aeroports
        self.notificateur = notificateur
        self.retrait = retrait
        self.localisation = localisation
        self.lecteurBillet = lecteurBillet
        self.enLigne = enLigne
        self.traducteur = traducteur
        self.formats = formats
        maintenant = horloge.maintenant
    }

    /// La lecture des aéroports (`aeroports.json`, `aeroports_noms.json` : Data.aeroports d'Android), index de
    /// recherche préparé, hors du fil principal.
    public nonisolated static func lireAeroports(lecteur: @escaping ContenusApp.Lecteur)
        -> @Sendable () async throws -> [Vol.Aeroport] {
        {
            guard let lignes = try lecteur("aeroports.json") else { throw ErreurContenu.absent("aeroports.json") }
            let noms = try lecteur("aeroports_noms.json").map { String(decoding: $0, as: UTF8.self) }
            let liste = try Aeroports.parse(String(decoding: lignes, as: UTF8.self), noms: noms)
            Aeroports.preparer(liste)
            return liste
        }
    }

    // MARK: Le cycle de l'écran

    /// À l'affichage : les aéroports la première fois, puis le vol gardé, remis dans le formulaire et recalculé
    /// (le calcul n'est pas gardé, il se refait en un instant).
    public func apparaitre() async {
        maintenant = horloge.maintenant
        guard !lectureLancee else {
            notificationsAutorisees = await notificateur.autorisation()
            return
        }
        lectureLancee = true
        notificationsAutorisees = await notificateur.autorisation()
        do {
            aeroports = try await chargerAeroports()
        } catch {
            aeroports = []
            aeroportsIllisibles = true
        }
        pret = true
        indicatifSaisi = magasin.reglages.volIndicatif
        let enregistre = VolStockage.plan(magasin.reglages, aeroports)
        plan = enregistre
        guard let enregistre else { return }
        numeroSaisi = enregistre.numero
        depart = enregistre.depart
        arrivee = enregistre.arrivee
        decollage = Vol.zone(enregistre.depart.fuseau)?.dateHeure(millis: enregistre.decollage)
        atterrissage = Vol.zone(enregistre.arrivee.fuseau)?.dateHeure(millis: enregistre.atterrissage)
        await lancer(enregistre)
    }

    /// Toutes les 30 secondes : le compte à rebours, la place de « maintenant », les rappels passés.
    public func battre() {
        maintenant = horloge.maintenant
    }

    // MARK: Le bandeau

    /// Le titre du bandeau (blanc, gras).
    public var titre: Libelle {
        Libelle("vol_title")
    }

    /// L'illustration du bandeau, sur sa plaque.
    public var image: String {
        "scene_airport"
    }

    /// La pastille du bandeau : « LY81 · TLV → BKK » une fois le vol calculé, l'invitation sinon.
    public var bandeau: Libelle {
        guard let p = calcul?.plan else { return Libelle("vol_carte_sous") }
        return VolModele.titreVol(p)
    }

    // MARK: Le formulaire

    /// Le numéro saisi, sans les blancs autour.
    public var numero: String {
        numeroSaisi.premieresUnites(12).rogne
    }

    /// Le formulaire et la saisie rapide sont ouverts (aucun vol gardé, ou « Modifier ») ; sinon le résumé.
    public var formulaireOuvert: Bool {
        plan == nil || modifier
    }

    /// Le vol replié en résumé, formulaire fermé.
    public var resume: VolResume? {
        guard !formulaireOuvert, let p = plan else { return nil }
        return VolResume(titre: VolModele.titreVol(p),
                         depart: VolMiseEnPage.heureAeroport(p.depart, p.decollage, formats),
                         arrivee: VolMiseEnPage.heureAeroport(p.arrivee, p.atterrissage, formats))
    }

    /// La flèche du résumé, dans le sens de la lecture.
    public var fleche: String {
        traducteur.langue == "he" ? "\u{2190}" : "\u{2192}"
    }

    /// Le bouton « Importer le billet (PDF ou photo) » existe.
    public var billetDisponible: Bool {
        lecteurBillet != nil
    }

    /// Les tuiles, dans l'ordre : départ, arrivée, puis l'heure de chacun une fois l'aéroport choisi.
    public var tuiles: [VolTuile] {
        var res: [VolTuile] = []
        let aeroport = Libelle("vol_choisir_aeroport")
        let heure = Libelle("vol_choisir_heure")
        res.append(VolTuile(genre: .depart, etiquette: Libelle("vol_depart"),
                            valeur: depart.map(VolMiseEnPage.nomAeroport), invite: aeroport))
        res.append(VolTuile(genre: .arrivee, etiquette: Libelle("vol_arrivee"),
                            valeur: arrivee.map(VolMiseEnPage.nomAeroport), invite: aeroport))
        if let a = depart {
            res.append(VolTuile(genre: .decollage, etiquette: Libelle("vol_decollage", .texte(a.ville.isEmpty ? a.iata : a.ville)),
                                valeur: decollage.map { formats.saisie($0) }, invite: heure))
        }
        if let a = arrivee {
            res.append(VolTuile(genre: .atterrissage,
                                etiquette: Libelle("vol_atterrissage", .texte(a.ville.isEmpty ? a.iata : a.ville)),
                                valeur: atterrissage.map { formats.saisie($0) }, invite: heure))
        }
        return res
    }

    /// « Estimée d'après la distance : à vérifier sur le billet. » sous la tuile de l'atterrissage.
    public var noteArriveeEstimee: Bool {
        arrivee != nil && arriveeEstimee
    }

    /// Le lien « Effacer le vol » : un vol gardé, ou quelque chose de saisi.
    public var peutEffacer: Bool {
        plan != nil || depart != nil || arrivee != nil || !numero.isEmpty
    }

    // MARK: Les services en ligne

    /// Le relais est configuré : la loupe, l'interrupteur, le suivi en direct et la source adsbdb existent.
    public var enLigneDisponible: Bool {
        enLigne?.disponible ?? false
    }

    /// Les services en ligne sont activés (Store.suiviDirect), avec un relais.
    public var enLigneActif: Bool {
        enLigneDisponible && magasin.reglages.suiviDirect
    }

    /// La loupe du champ du numéro : touchable hors recherche.
    public var loupeActive: Bool {
        enLigneDisponible && !routeEnCours
    }

    /// Sous le numéro : ce qu'a donné la loupe, ou « Recherche du vol… ». nil sans relais.
    public var aideRoute: Libelle? {
        guard enLigneDisponible else { return nil }
        return routeTexte ?? (routeEnCours ? Libelle("vol_route_attente") : nil)
    }

    // MARK: Les résultats

    /// La zone des résultats.
    public var resultats: VolResultats {
        if calculEnCours { return .enCours }
        guard let c = calcul else { return .aucun }
        return .cartes(VolCartes(priere: cartePriere(c), frise: frise(c), jalons: carteJalons(c),
                                 rappels: carteRappels(c), fiabilite: carteFiabilite(c)))
    }

    /// « Méthode et sources », replié : la méthode, les aéroports, les routes (avec le relais seulement).
    public var sources: [Libelle] {
        var res = [Libelle("zmanim_a_valider"), Libelle("vol_source_aeroports")]
        if enLigneDisponible { res.append(Libelle("vol_source_adsbdb")) }
        return res
    }

    public func estOuvert(_ volet: VolVolet) -> Bool {
        voletsOuverts.contains(volet)
    }

    /// Israël ou diaspora (Store.inIsrael).
    public var enIsrael: Bool {
        magasin.reglages.inIsrael(fuseauTelephone: horloge.fuseau.identifiant)
    }

    private func cartePriere(_ c: Vol.Calcul) -> VolCartePriere {
        guard let p = VolPriere.priere(c, maintenant) else {
            return VolCartePriere(ciel: .aucun, nom: nil, message: Libelle("vol_hors_fenetre"), compte: nil,
                                  jusqua: nil, ecart: nil, limite: nil)
        }
        let ciel: VolCiel
        switch p.priere {
        case "chaharit": ciel = .chaharit
        case "minha": ciel = .minha
        default: ciel = .arvit
        }
        let nom = VolMiseEnPage.nomPriere(p.priere)
        guard let limite = p.limite else {
            return VolCartePriere(ciel: ciel, nom: nom, message: Libelle("vol_sans_limite"), compte: nil, jusqua: nil,
                                  ecart: nil, limite: nil)
        }
        let minutes = max(0, VolMiseEnPage.minutes(de: maintenant, a: limite))
        let compte = Libelle("vol_dans", .libelle(VolMiseEnPage.dureeEnMots(Int(minutes))))
        let jusqua = Libelle("vol_jusqua", .texte(VolMiseEnPage.texteDeuxHeures(c.plan, limite, formats)))
        var ecart: Libelle?
        if let e = c.enVol.first(where: { $0.instant == limite }), let ms = e.ecartSiRetard { ecart = ecartTexte(ms, c) }
        return VolCartePriere(ciel: ciel, nom: nom, message: nil, compte: compte, jusqua: jusqua, ecart: ecart,
                              limite: limite)
    }

    private func ecartTexte(_ ms: Int64, _ c: Vol.Calcul) -> Libelle {
        VolMiseEnPage.ecart(ms, recale: c.fiabilite != .routePrevue)
    }

    /// Une étape de la frise avant d'être écrite.
    private struct Etape {
        let ciel: VolCielFrise
        let nom: Libelle
        let instant: Int64?
        let detail: Libelle?
    }

    private func frise(_ c: Vol.Calcul) -> VolFrise {
        let enVol = c.enVol
        if enVol.isEmpty { return VolFrise(vide: true, noteRetard: false, points: []) }
        let ecarts = enVol.compactMap { $0.ecartSiRetard }.sorted()
        let median: Int64? = ecarts.isEmpty ? nil : ecarts[ecarts.count / 2]
        let trajet = c.plan
        var etapes: [Etape] = []
        etapes.append(Etape(ciel: .bout, nom: Libelle("vol_frise_decollage", .texte(trajet.depart.iata)),
                            instant: trajet.decollage, detail: nil))
        var place = maintenant < trajet.decollage || maintenant > trajet.atterrissage
        for e in enVol {
            if !place && maintenant < e.instant {
                etapes.append(Etape(ciel: .maintenant, nom: Libelle("vol_frise_maintenant"), instant: nil, detail: nil))
                place = true
            }
            // L'écart d'une ligne n'y figure que s'il s'éloigne de 5 min ou plus de l'écart médian.
            let position = VolMiseEnPage.position(e.latitude, e.longitude, formats)
            var detail = position
            if let ecart = e.ecartSiRetard, let median, Swift.abs(ecart - median) >= 5 * 60_000 {
                // « %1$@ · %2$@ » : la jointure de VolActivity, dans les trois langues.
                detail = Libelle("zmanim_lieu_detail", .libelle(position), .libelle(ecartTexte(ecart, c)))
            }
            etapes.append(Etape(ciel: VolCielFrise.de(e.cle), nom: VolMiseEnPage.nomZman(e.cle), instant: e.instant,
                                detail: detail))
        }
        etapes.append(Etape(ciel: .bout, nom: Libelle("vol_frise_atterrissage", .texte(trajet.arrivee.iata)),
                            instant: trajet.atterrissage, detail: nil))
        var points: [VolPointFrise] = []
        for (rang, etape) in etapes.enumerated() {
            var heures: VolDeuxHeures?
            if let t = etape.instant { heures = VolMiseEnPage.deuxHeures(trajet, t, formats) }
            points.append(VolPointFrise(id: rang, ciel: etape.ciel, nom: etape.nom, heureDepart: heures?.depart,
                                        heureArrivee: heures?.arrivee, detail: etape.detail,
                                        dernier: rang == etapes.count - 1))
        }
        return VolFrise(vide: false, noteRetard: median != nil, points: points)
    }

    private func carteJalons(_ c: Vol.Calcul) -> VolCarteJalons? {
        let israel = enIsrael
        let minutes = magasin.reglages.allumage
        let jalons = VolCalendrier.jalons(c, enIsrael: israel, minutes: minutes)
        if jalons.isEmpty && c.lignesDate.isEmpty { return nil }
        var lignes: [VolJalonLigne] = []
        for (rang, j) in jalons.enumerated() {
            var noms: [Libelle] = []
            if j.chabbat { noms.append(Libelle("vol_chabbat")) }
            for fete in j.fetes {
                if let cle = Libelles.res("fete_" + fete) { noms.append(Libelle(cle)) }
            }
            let nom = noms.map { traducteur.texte($0) }.joined(separator: " · ")
            let heure = VolMiseEnPage.texteDeuxHeures(c.plan, j.instant, formats)
            let texte: Libelle
            switch j.type {
            case .entree: texte = Libelle("vol_jalon_entree", .texte(nom), .texte(heure))
            case .sortie: texte = Libelle("vol_jalon_sortie", .texte(nom), .texte(heure))
            case .enchainement: texte = Libelle("vol_jalon_enchainement", .texte(nom), .texte(heure))
            case .omer: texte = Libelle("vol_jalon_omer", .texte(String(j.omer)), .texte(heure))
            }
            let allumage = j.allumage.map {
                Libelle("vol_jalon_allumage", .texte(String(minutes)), .texte(VolMiseEnPage.texteDeuxHeures(c.plan, $0, formats)))
            }
            lignes.append(VolJalonLigne(id: rang, texte: texte, allumage: allumage,
                                        position: VolMiseEnPage.position(j.latitude, j.longitude, formats),
                                        repli: j.repli ? Libelle("vol_jalon_repli") : nil))
        }
        let note = Libelle("vol_jalons_note", .libelle(Libelle(israel ? "vol_jalons_israel" : "vol_jalons_diaspora")))
        return VolCarteJalons(ligneDateDiscutee: c.lignesDate.isEmpty ? nil : Libelle("ligne_date_discutee"),
                              omerLigneDate: VolCalendrier.ligneDateOmer(c, enIsrael: israel) ? Libelle("vol_omer_ligne_date") : nil,
                              lignes: lignes, note: note)
    }

    private func carteRappels(_ c: Vol.Calcul) -> VolCarteRappels {
        let actifs = magasin.reglages.volRappelsActifs
        guard actifs else {
            return VolCarteRappels(actifs: false, sansPermission: false, aucun: false, lignes: [], note: nil)
        }
        let aVenir = VolRappels.rappels(c, enIsrael: enIsrael, nusah: magasin.reglages.siddurNusah).filter { $0.instant > maintenant }
        let lignes = aVenir.enumerated().map { rang, r in
            VolRappelLigne(id: rang, titre: VolMiseEnPage.titreRappel(r),
                           heure: VolMiseEnPage.texteDeuxHeures(c.plan, r.instant, formats))
        }
        return VolCarteRappels(actifs: true, sansPermission: !notificationsAutorisees, aucun: aVenir.isEmpty,
                               lignes: lignes, note: Libelle("vol_rappels_note"))
    }

    private func carteFiabilite(_ c: Vol.Calcul) -> VolCarteFiabilite {
        var releve: Libelle?
        if let r = c.plan.releve, c.fiabilite != .routePrevue {
            releve = Libelle(c.fiabilite == .releveDirect ? "vol_fiabilite_direct" : "vol_fiabilite_gps",
                             .texte(VolMiseEnPage.texteDeuxHeures(c.plan, r.instant, formats)),
                             .libelle(VolMiseEnPage.position(r.latitude, r.longitude, formats)))
        }
        var direct: VolSuiviDirect?
        if enLigneDisponible {
            direct = VolSuiviDirect(actif: magasin.reglages.suiviDirect,
                                    bouton: Libelle(directEnCours ? "vol_direct_attente" : "vol_direct_bouton"),
                                    enCours: directEnCours)
        }
        var reserves: [Libelle] = []
        for r in Vol.Reserve.allCases where c.reserves.contains(r) {
            reserves.append(VolMiseEnPage.reserve(r))
            // Les zmanim absents, nommés à la suite de la réserve (FVOL-11).
            if r == .absent && !c.absents.isEmpty {
                let noms = c.absents.map { cle in traducteur.texte(Libelle(Libelles.res("zman_" + cle) ?? cle)) }
                reserves.append(Libelle("vol_reserve_absents", .texte(noms.joined(separator: ", "))))
            }
        }
        let lignesDate = c.lignesDate.map { l in
            Libelle("vol_ligne_date", .texte(VolMiseEnPage.texteDeuxHeures(c.plan, l.instant, formats)),
                    .texte(formats.jour(l.avant)), .texte(formats.jour(l.apres)))
        }
        return VolCarteFiabilite(pastille: releve == nil, releve: releve,
                                 gps: localisation == nil ? nil : Libelle(gpsEnCours ? "vol_gps_attente" : "vol_gps"),
                                 gpsEnCours: gpsEnCours, oublier: c.plan.releve != nil, direct: direct,
                                 reserves: reserves, lignesDate: lignesDate)
    }

    // MARK: Les actions : la saisie rapide et le billet

    /// « Remplir le vol » : la phrase lue sur le téléphone (SaisieVol), puis appliquée.
    public func remplir() async {
        await appliquer(SaisieVol.lire(phrase, aeroports, horloge.aujourdhui), source: nil)
    }

    /// Le billet choisi (PDF ou photo) : son code-barres, puis la carte d'embarquement qu'il porte.
    public func importerBillet(_ fichier: URL) async {
        guard let lecteurBillet else { return }
        rapide = [Libelle("vol_rapide_lecture")]
        await lireBillet(await lecteurBillet.code(fichier))
    }

    /// Le code-barres lu par l'appareil photo (VisionKit, sur iOS seulement) : la carte d'embarquement qu'il porte,
    /// comme un billet importé.
    public func lireCodeBillet(_ code: String) async {
        await lireBillet(code)
    }

    /// Le contenu d'un code-barres (nil : aucun trouvé) : la carte d'embarquement (CarteEmbarquement), appliquée au
    /// formulaire, ou ce qui manque (lireBillet de VolActivity).
    private func lireBillet(_ code: String?) async {
        guard let code, let troncon = CarteEmbarquement.lire(code, horloge.aujourdhui) else {
            rapide = [Libelle(code == nil ? "vol_rapide_billet_sans_code" : "vol_rapide_billet_illisible")]
            return
        }
        let p = SaisieVol.Proposition(numero: troncon.numero, compagnie: troncon.compagnie,
                                      depart: Aeroports.parIata(aeroports, troncon.depart),
                                      arrivee: Aeroports.parIata(aeroports, troncon.arrivee), date: troncon.date)
        await appliquer(p, source: Libelle("vol_rapide_billet_lu"))
    }

    /// Remplit le formulaire avec ce qui a été compris ; l'arrivée manquante est estimée d'après la distance.
    /// Complet, le vol se calcule aussitôt ; sinon on dit ce qui manque, et l'heure de départ manquante s'ouvre
    /// d'elle-même (appliquer de VolActivity).
    private func appliquer(_ p: SaisieVol.Proposition, source: Libelle?) async {
        if p.vide {
            rapide = [Libelle("vol_rapide_rien")]
            return
        }
        if let n = p.numero { numeroSaisi = n }
        if let d = p.depart { depart = d }
        if let a = p.arrivee { arrivee = a }
        if p.depart != nil || p.arrivee != nil { routeTexte = nil }
        let jour = p.date ?? decollage?.jour
        if let jour, let h = p.heureDepart {
            decollage = DateHeure(jour, heure: h.heure, minute: h.minute)
        } else if let jour {
            dateSeule = jour
        }
        arriveeEstimee = false
        if let d = depart, let a = arrivee, let t1 = decollage {
            let i1 = Vol.instant(t1, d)
            let za = Vol.zone(a.fuseau)
            if let ha = p.heureArrivee, let i1, za != nil {
                // L'arrivée donnée : le premier jour où elle tombe après le départ (vol de nuit), deux jours au plus.
                var t2 = DateHeure(p.dateArrivee ?? jour ?? t1.jour, heure: ha.heure, minute: ha.minute)
                var n = 0
                while !VolModele.apres(Vol.instant(t2, a), i1) && n < 2 {
                    n += 1
                    t2 = t2.plus(jours: 1)
                }
                atterrissage = t2
            } else if let i1, let za {
                atterrissage = za.dateHeure(millis: i1 + SaisieVol.dureeEstimee(d, a))
                arriveeEstimee = true
            }
        }
        var compris: [String] = []
        if let nom = p.numero ?? p.compagnie { compris.append(nom) }
        if depart != nil || arrivee != nil {
            compris.append((depart?.iata ?? "?") + " \u{2192} " + (arrivee?.iata ?? "?"))
        }
        if let t = decollage {
            compris.append(formats.saisie(t))
        } else if let j = dateSeule {
            compris.append(formats.jour(j))
        }
        var manque: [Libelle] = []
        if depart == nil { manque.append(Libelle("vol_depart")) }
        if arrivee == nil { manque.append(Libelle("vol_arrivee")) }
        if decollage == nil { manque.append(Libelle("vol_rapide_heure")) }
        var lignes: [Libelle] = []
        if let source { lignes.append(source) }
        lignes.append(Libelle("vol_rapide_compris", .texte(compris.joined(separator: " · "))))
        if arriveeEstimee { lignes.append(Libelle("vol_rapide_estimee")) }
        if !manque.isEmpty {
            lignes.append(Libelle("vol_rapide_manque", .texte(manque.map { traducteur.texte($0) }.joined(separator: ", "))))
        }
        rapide = lignes
        if enLigneDisponible && !numero.isEmpty && (depart == nil || arrivee == nil) {
            // Le numéro sans la route : la loupe s'en charge (avec l'accord si besoin).
            await loupe()
        } else if depart != nil && decollage == nil {
            dialogue = .heure(.saisieRapide, initiale: dateSeule.map { DateHeure($0, heure: 12) } ?? maintenantLocal)
        } else if depart != nil && arrivee != nil && decollage != nil && atterrissage != nil {
            await calculer()
        }
    }

    /// `isAfter` d'un instant qui peut manquer : faux sans instant.
    private nonisolated static func apres(_ t: Int64?, _ reference: Int64) -> Bool {
        guard let t else { return false }
        return t > reference
    }

    /// L'heure du téléphone à la minute (`LocalDateTime.now().withSecond(0)`), quand rien d'autre n'ouvre le choix.
    private var maintenantLocal: DateHeure {
        let d = horloge.dateHeure
        return DateHeure(d.jour, heure: d.heure, minute: d.minute)
    }

    // MARK: Les actions : les tuiles

    /// Une tuile touchée : la recherche d'un aéroport, ou le choix d'une heure.
    public func toucher(_ genre: VolTuile.Genre) {
        switch genre {
        case .depart, .arrivee:
            recherche = ""
            trouves = []
            lignesAeroports = []
            dialogue = .aeroport(genre)
        case .decollage:
            guard depart != nil else { return }
            dialogue = .heure(.decollage, initiale: decollage ?? dateSeule.map { DateHeure($0, heure: 12) } ?? maintenantLocal)
        case .atterrissage:
            guard arrivee != nil else { return }
            dialogue = .heure(.atterrissage, initiale: atterrissage ?? decollage ?? maintenantLocal)
        }
    }

    /// La recherche dans les aéroports : code, ville ou nom, en lettres latines ou en hébreu (Aeroports.chercher).
    /// La vue l'appelle 120 ms après la dernière lettre.
    public func chercherAeroport(_ texte: String) {
        recherche = texte
        trouves = Aeroports.chercher(aeroports, texte)
        let langue = traducteur.langue
        lignesAeroports = trouves.map { a in
            let local = Aeroports.nomLocal(a, langue)
            return VolAeroportLigne(aeroport: a, titre: a.ville.isEmpty ? local : a.ville, detail: local + " · " + a.pays)
        }
    }

    /// « Aucun aéroport trouvé. » : rien pour un texte non vide.
    public var rechercheVide: Bool {
        lignesAeroports.isEmpty && !recherche.estBlanc
    }

    /// Un aéroport touché dans la recherche.
    public func choisirAeroport(_ a: Vol.Aeroport) {
        guard case .aeroport(let genre)? = dialogue else { return }
        dialogue = nil
        if genre == .depart { depart = a } else { arrivee = a }
    }

    /// « Entrée » dans la recherche : le premier résultat.
    public func validerRecherche() {
        guard let premier = trouves.first else { return }
        choisirAeroport(premier)
    }

    /// La date et l'heure choisies (à la minute), à l'heure locale de l'aéroport.
    public func choisirHeure(_ civile: DateHeure) async {
        guard case .heure(let champ, _)? = dialogue else { return }
        dialogue = nil
        let t = DateHeure(civile.jour, heure: civile.heure, minute: civile.minute)
        switch champ {
        case .decollage:
            decollage = t
        case .atterrissage:
            atterrissage = t
            arriveeEstimee = false
        case .saisieRapide:
            await appliquer(SaisieVol.Proposition(date: t.jour, heureDepart: SaisieVol.Heure(t.heure, t.minute)), source: nil)
        }
    }

    /// « OK », « Annuler », ou le dialogue refermé.
    public func fermerDialogue() {
        dialogue = nil
    }

    public func basculerVolet(_ volet: VolVolet) {
        if voletsOuverts.contains(volet) {
            voletsOuverts.remove(volet)
        } else {
            voletsOuverts.insert(volet)
        }
    }

    // MARK: Les actions : le calcul

    /// « Calculer » : le vol vérifié, gardé, puis calculé.
    public func calculer() async {
        guard let d = depart, let a = arrivee, let t1 = decollage, let t2 = atterrissage else {
            dialogue = .message(Libelle("vol_incomplet"))
            return
        }
        guard let i1 = Vol.instant(t1, d), let i2 = Vol.instant(t2, a) else {
            dialogue = .message(Libelle("vol_invalide_fuseau_inconnu"))
            return
        }
        // Le même vol, calculé à nouveau, garde son relevé ; un autre vol l'efface.
        var garde: Vol.Plan?
        if let p = plan, p.depart == d, p.arrivee == a, p.decollage == i1, p.atterrissage == i2 { garde = p }
        let nouveau = Vol.Plan(numero: numero, depart: d, arrivee: a, decollage: i1, atterrissage: i2,
                               releve: garde?.releve, sourceReleve: garde?.sourceReleve ?? .gps)
        if let invalide = Vol.verifier(nouveau) {
            dialogue = .message(VolMiseEnPage.invalide(invalide))
            return
        }
        // Une durée que la distance ne permet pas : on avertit une fois, un second toucher passe outre (FVOL-12).
        var sansReleve = nouveau
        sansReleve.releve = nil
        if Vol.invraisemblable(nouveau) && avertiPour != sansReleve {
            avertiPour = sansReleve
            let minutes = Int((i2 - i1) / 60_000)
            dialogue = .message(Libelle("vol_invraisemblable", .texte(String(Kotlin.arrondiLong(Vol.distanceKm(nouveau)))),
                                        .libelle(VolMiseEnPage.dureeEnMots(minutes))))
            return
        }
        modifier = false
        await garder(nouveau)
        await lancer(nouveau)
    }

    /// « Modifier » : le formulaire rouvert.
    public func modifierVol() {
        modifier = true
    }

    /// « Effacer le vol » : le vol, ses rappels et leurs notifications, et tout ce qui a été saisi.
    public func effacer() async {
        generation += 1
        calculEnCours = false
        calcul = nil
        plan = nil
        numeroSaisi = ""
        depart = nil
        arrivee = nil
        decollage = nil
        atterrissage = nil
        modifier = false
        phrase = ""
        rapide = nil
        dateSeule = nil
        arriveeEstimee = false
        await ecrireReglages { r in
            r = VolStockage.avecRappels(VolStockage.avecPlan(r, nil), [])
        }
        await retrait?.retirer(prefixe: VolNotifications.prefixe)
    }

    /// Le calcul, hors du fil principal (deux passes de Vol : le vol, puis 30 min de retard) ; puis ses rappels.
    private func lancer(_ p: Vol.Plan) async {
        if Vol.verifier(p) != nil { return }
        generation += 1
        let numeroCalcul = generation
        calculEnCours = true
        calcul = nil
        let c = await Task.detached(priority: .userInitiated) { Vol.calculer(p) }.value
        guard numeroCalcul == generation else { return }
        calculEnCours = false
        calcul = c
        maintenant = horloge.maintenant
        // Les rappels suivent le dernier calcul (un relevé les recale aussi).
        let rappels = VolRappels.rappels(c, enIsrael: enIsrael, nusah: magasin.reglages.siddurNusah)
        await ecrireReglages { r in
            r = VolStockage.avecRappels(r, rappels)
        }
        await programmerRappels()
    }

    /// Le vol gardé (Store.setVol).
    private func garder(_ p: Vol.Plan?) async {
        plan = p
        await ecrireReglages { r in
            r = VolStockage.avecPlan(r, p)
        }
    }

    /// Pose les notifications des rappels gardés, celles d'avant retirées : rien si les rappels sont éteints.
    private func programmerRappels() async {
        await retrait?.retirer(prefixe: VolNotifications.prefixe)
        guard let p = plan else { return }
        let formats = self.formats
        let liste = VolNotifications.prevues(reglages: magasin.reglages, rappels: VolStockage.rappels(magasin.reglages),
                                             maintenant: horloge.maintenant,
                                             heure: { t in VolMiseEnPage.texteDeuxHeures(p, t, formats) })
        if liste.isEmpty { return }
        do {
            try await notificateur.programmer(liste.map { $0.prevue })
        } catch {
            // Une notification refusée par le système n'empêche pas l'écran : la carte des rappels reste juste.
        }
    }

    /// Les notifications que l'écran pose pour le vol gardé, maintenant : celles que le `Notificateur` doit tenir.
    public var notificationsPrevues: [VolNotification] {
        guard let p = plan else { return [] }
        let formats = self.formats
        return VolNotifications.prevues(reglages: magasin.reglages, rappels: VolStockage.rappels(magasin.reglages),
                                        maintenant: horloge.maintenant,
                                        heure: { t in VolMiseEnPage.texteDeuxHeures(p, t, formats) })
    }

    // MARK: Les actions : les rappels

    /// L'interrupteur « Me rappeler pendant le vol » ; allumé, l'autorisation de notifier est demandée au besoin.
    public func basculerRappels(_ actifs: Bool) async {
        await ecrireReglages { r in
            r.setVolRappelsActifs(actifs)
        }
        let accordee = await notificateur.autorisation()
        if actifs && !accordee {
            notificationsAutorisees = await notificateur.demanderAutorisation()
        } else {
            notificationsAutorisees = accordee
        }
        await programmerRappels()
    }

    // MARK: Les actions : la position

    /// « Position réelle (GPS) » : un relevé, qui recale la route s'il tombe pendant le vol prévu.
    public func releverGps() async {
        guard let localisation, !gpsEnCours else { return }
        gpsEnCours = true
        let reponse = await localisation.positionApprochee()
        gpsEnCours = false
        switch reponse {
        case .position(let position):
            let point = Vol.Point(instant: horloge.maintenant, latitude: position.latitude, longitude: position.longitude)
            await appliquerReleve(point, source: .gps)
        case .refusee:
            dialogue = .message(Libelle("vol_gps_refuse"))
        case .indisponible, .ancienne:
            // Le relevé du vol veut un point de maintenant : une position d'avant n'est pas un relevé.
            dialogue = .message(Libelle("vol_gps_echec"))
        }
    }

    /// « Revenir à la route prévue ».
    public func oublierReleve() async {
        await appliquerReleve(nil, source: .gps)
    }

    /// Garde le relevé avec le vol et recalcule ; nil : retour à la route prévue.
    private func appliquerReleve(_ releve: Vol.Point?, source: Vol.SourceReleve) async {
        guard var nouveau = plan else { return }
        nouveau.releve = releve
        nouveau.sourceReleve = source
        if releve != nil && !Vol.releveUtilisable(nouveau) {
            dialogue = .message(Libelle("vol_gps_hors_vol"))
            return
        }
        await garder(nouveau)
        await lancer(nouveau)
    }

    // MARK: Les actions : les services en ligne

    /// La loupe du numéro : services en ligne éteints, on demande d'abord ce qui partira.
    public func loupe() async {
        guard enLigneDisponible else { return }
        if magasin.reglages.suiviDirect {
            await chercherRoute()
        } else {
            dialogue = .enLigne
        }
    }

    /// « Activer et chercher ».
    public func confirmerEnLigne() async {
        guard case .enLigne? = dialogue else { return }
        dialogue = nil
        await ecrireReglages { r in
            r.setSuiviDirect(true)
        }
        await chercherRoute()
    }

    /// L'interrupteur des services en ligne (vol_direct_activer).
    public func basculerEnLigne(_ actif: Bool) async {
        guard enLigneDisponible else { return }
        await ecrireReglages { r in
            r.setSuiviDirect(actif)
        }
    }

    /// La route du numéro saisi (RouteVol, adsbdb.com) : remplit l'arrivée (et le départ) et l'indicatif du suivi
    /// en direct ; les heures restent à saisir. Ne part jamais sans relais ni sans l'interrupteur.
    private func chercherRoute() async {
        guard let enLigne, enLigne.disponible, magasin.reglages.suiviDirect else { return }
        let n = numero
        guard RouteVol.normaliser(n) != nil else {
            routeTexte = Libelle("vol_route_invalide")
            return
        }
        routeEnCours = true
        routeTexte = nil
        let d = depart?.iata
        let r = await VolRequetes.route(n, depart: d, reseau: enLigne.reseau)
        routeEnCours = false
        switch r {
        case .trouve(let indicatif, let compagnie, _, let de, let vers):
            if let indicatif {
                indicatifSaisi = indicatif
                await ecrireReglages { reglages in
                    reglages.setVolIndicatif(indicatif)
                }
            }
            guard let aDe = Aeroports.parIata(aeroports, de), let aVers = Aeroports.parIata(aeroports, vers) else {
                let inconnu = Aeroports.parIata(aeroports, de) == nil ? de : vers
                routeTexte = Libelle("vol_route_inconnue", .texte(inconnu))
                return
            }
            depart = aDe
            arrivee = aVers
            let trouvee = Libelle("vol_route_trouvee", .texte(n.uppercased()), .texte(compagnie), .texte(de), .texte(vers))
            routeTexte = trouvee
            // La route trouvée complète la saisie rapide : arrivée estimée, heure, calcul.
            if rapide != nil {
                let heure = decollage.map { SaisieVol.Heure($0.heure, $0.minute) }
                await appliquer(SaisieVol.Proposition(depart: aDe, arrivee: aVers, date: decollage?.jour ?? dateSeule,
                                                      heureDepart: heure), source: trouvee)
            }
        case .autreDepart(_, _, let escales):
            routeTexte = Libelle("vol_route_autre_depart", .texte(n.uppercased()),
                                 .texte(escales.joined(separator: " \u{2192} ")), .texte(d ?? ""))
        case .introuvable:
            routeTexte = Libelle("vol_route_introuvable")
        case .invalide:
            routeTexte = Libelle("vol_route_invalide")
        case .erreur(let raison):
            routeTexte = Libelle("vol_route_erreur", .libelle(VolMiseEnPage.raison(raison)))
        }
    }

    /// « Position en direct » : l'indicatif et la position estimée partent vers le relais, pendant le vol prévu
    /// seulement.
    public func demanderDirect() async {
        guard let enLigne, enLigne.disponible, magasin.reglages.suiviDirect, !directEnCours else { return }
        guard let indicatif = SuiviVol.normaliser(indicatifSaisi) else {
            dialogue = .message(Libelle("vol_indicatif_invalide"))
            return
        }
        indicatifSaisi = indicatif
        await ecrireReglages { r in
            r.setVolIndicatif(indicatif)
        }
        guard let p = plan else { return }
        let t = horloge.maintenant
        if t < p.decollage || t > p.atterrissage {
            dialogue = .message(Libelle("vol_gps_hors_vol"))
            return
        }
        let estime = Vol.position(p, t)
        directEnCours = true
        let r = await VolRequetes.position(relais: enLigne.relais, indicatif: indicatif, estime: estime,
                                           reseau: enLigne.reseau, horloge: horloge)
        directEnCours = false
        switch r {
        case .trouve(let point, _):
            await appliquerReleve(point, source: .direct)
        case .introuvable:
            dialogue = .message(Libelle("vol_direct_introuvable"))
        case .erreur(let raison):
            dialogue = .message(Libelle("vol_direct_erreur", .libelle(VolMiseEnPage.raison(raison))))
        }
    }

    // MARK: Aides

    /// « LY81 · TLV → BKK » ; « ✈ » sans numéro.
    private static func titreVol(_ p: Vol.Plan) -> Libelle {
        Libelle("vol_carte_vol", .texte(p.numero.isEmpty ? "\u{2708}" : p.numero), .texte(p.depart.iata),
                .texte(p.arrivee.iata))
    }

    /// Change les réglages ; une écriture refusée laisse le changement en mémoire (Magasin), l'écran continue.
    private func ecrireReglages(_ changement: (inout Reglages) -> Void) async {
        do {
            try await magasin.modifierReglages(changement)
        } catch {
            // La prochaine écriture des réglages l'emportera.
        }
    }
}
