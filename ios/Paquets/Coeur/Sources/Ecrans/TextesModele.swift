import Foundation
import Observation
import Coeur

// L'onglet Textes (le panneau `texts_scroll` de MainActivity.kt et activity_main.xml, 14/10) : le titre, la
// recherche, « Reprendre » le dernier texte lu puis les favoris et la ligne des marque-pages (RepriseFavoris.kt),
// la carte des textes (Tikoun, siddour, Tehilim, Tefilot, livres, sources, 'hizouk, conseils, et la relecture en
// debug), puis « Autour de la hitbodedout » : la musique, avec son interrupteur, et les rappels. Chaque ligne garde
// son état sur sa deuxième ligne (les psaumes déjà dits, la portion du jour, le morceau choisi, les rappels).
//
// Android remplit le panneau à chaque retour sur l'écran (onResume → refresh) : ici `actualiser()`, qui prend
// l'heure et relit les contenus dont les lignes ont besoin (le siddour du nusah choisi, l'index des livres, le
// Tikoun, la bibliothèque pour la source du jour). Les réglages se lisent dans le `Magasin` à chaque fois : un
// favori posé dans une lecture se voit au retour.
//
// La source du jour (SourceDuJour.carte) est, sur Android, une carte de l'accueil (`accueil_moment`), pas de ce
// panneau : le modèle la rend (`sourceDuJour`) pour qui l'affiche, et `TextesSourceDuJour.choisir` sert aussi bien
// l'onglet Aujourd'hui.
//
// Ce fichier ne dépend que des fondations d'Ecrans et de Coeur : les écrans qu'il ouvre se nomment par
// `TextesRoute`, que le câblage relie à leurs modèles.

// MARK: Les écrans ouverts

/// Les écrans qu'ouvre l'onglet Textes, pour `navigationDestination(for:)`. Les paramètres portent les noms de
/// ceux des modèles ouverts.
public enum TextesRoute: Sendable, Hashable {
    /// RechercheActivity (recherche_button) : RechercheModele.
    case recherche
    /// TikkunFlowActivity (tikkun_button) : TikkunModele.
    case tikkun
    /// SiddurActivity (siddur_button) : SiddourModele.
    case siddour
    /// TehilimActivity (tehilim_button) : TehilimModele.
    case tehilim
    /// TefilotActivity (tefilot_button) : TefilotModele.
    case tefilot
    /// LibraryActivity : les livres seuls (livres_button, EXTRA_LIVRES) ou les sources (library_button) ;
    /// BibliothequeModele(livresSeuls:).
    case bibliotheque(livresSeuls: Bool)
    /// ChizukActivity (chizuk_button) : ChizukModele.
    case chizuk
    /// TipsActivity (tips_button) : ConseilsModele.
    case conseils
    /// ProofreadActivity (proofread_button), en debug seulement.
    case relecture
    /// MusicActivity (music_button) : MusiqueModele.
    case musique
    /// RemindersActivity (reminders_button).
    case rappels
    /// SiddurLectureActivity.ouvrir (le siddour) ou ouvrirLivre (un livre) : la reprise et les favoris ;
    /// LectureCible(id:livre:), sans marque-page : le lecteur reprend à la place gardée.
    case lecture(id: String, livre: Bool)
    /// RepriseFavoris.listeSignets : la feuille de tous les marque-pages (`recueil` nil) ; LectureMarquesModele.
    case marquesPages(recueil: String?)
    /// LibraryEntryActivity (EXTRA_ID) : la source du jour, « Lire la suite » ; BibliothequeEntreeModele(id:).
    case entreeBibliotheque(id: String)
}

// MARK: Ce qui s'affiche

/// Un nom à montrer : un titre hébreu tel quel (déjà masqué pour la police choisie), ou une chaîne de l'interface.
public enum TextesNom: Sendable, Hashable {
    case hebreu(String)
    case libelle(Libelle)
}

/// Une ligne de « Reprendre », des favoris ou des marque-pages (RepriseFavoris.ligne).
public struct TextesRepriseLigne: Sendable, Equatable, Identifiable {

    public enum Genre: Sendable, Equatable {
        /// « Reprendre la lecture » : le dernier texte lu.
        case reprise
        /// Un favori (l'étoile de l'écran de lecture), le plus récent en tête.
        case favori
        /// « Marque-pages · n » : tous les marque-pages, qui ouvre leur feuille.
        case signets
    }

    /// « reprise », « favori:<rang>:<clé> », « signets » : unique.
    public let id: String
    public let genre: Genre
    /// L'en-tête au-dessus de la ligne (12 sp, capitales, couleur de marque) : « Reprendre la lecture » sur la
    /// reprise, « Favoris » sur le premier favori seulement ; nil sinon.
    public let entete: Libelle?
    /// Le titre du texte, en 19 sp, encre, de droite à gauche, dans la police hébraïque choisie, suivi de « ›».
    /// Pour la ligne des marque-pages : « Marque-pages », que suit « · n » (`nombre`).
    public let titre: TextesNom
    /// Le nombre de marque-pages, sur la seule ligne des marque-pages.
    public let nombre: Int?
    /// L'icône au bout de la ligne des marque-pages (ic_marque_priere, 18 points, teinte de marque) ; nil ailleurs.
    public let icone: String?
    public let route: TextesRoute

    public init(id: String, genre: Genre, entete: Libelle?, titre: TextesNom, nombre: Int?, icone: String?,
                route: TextesRoute) {
        self.id = id
        self.genre = genre
        self.entete = entete
        self.titre = titre
        self.nombre = nombre
        self.icone = icone
        self.route = route
    }
}

/// Une ligne de section (SectionRow) : le titre, son état ou son indication dessous, le chevron ; l'interrupteur
/// de la musique sur sa seule ligne.
public struct TextesEntree: Sendable, Equatable, Identifiable {
    /// L'identifiant de la vue d'Android : « tikkun_button », « music_button »…
    public let id: String
    /// En 15 sp, encre (SettingLabelStacked).
    public let titre: Libelle
    /// En 13 sp, discret, deux lignes au plus (SectionState) ; nil : pas de deuxième ligne.
    public let etat: Libelle?
    /// La position de l'interrupteur (music_switch_main), sur la ligne de la musique seulement ; nil ailleurs.
    public let interrupteur: Bool?
    public let route: TextesRoute

    public init(id: String, titre: Libelle, etat: Libelle?, interrupteur: Bool? = nil, route: TextesRoute) {
        self.id = id
        self.titre = titre
        self.etat = etat
        self.interrupteur = interrupteur
        self.route = route
    }
}

/// La carte de la source du jour (SourceDuJour.carte) : un paragraphe des sources de la bibliothèque, le même
/// toute la journée et pour tous, et « Lire la suite ».
public struct TextesSourceDuJour: Sendable, Equatable {
    /// L'identifiant de la source, qu'ouvre « Lire la suite ».
    public let id: String
    /// « Source du jour » : 12 sp, capitales, couleur de marque.
    public let entete: Libelle
    /// L'extrait (320 unités au plus, coupé à un mot, « … »), en 18 sp, encre, de droite à gauche, dans la police
    /// hébraïque choisie (déjà masqué pour elle).
    public let extrait: String
    /// La référence dans la langue de l'app (Reference.localise) : 13 sp, italique, discrète.
    public let reference: String
    /// Le bouton à contour, toute la largeur : « Lire la suite ».
    public let bouton: Libelle

    public init(id: String, entete: Libelle, extrait: String, reference: String, bouton: Libelle) {
        self.id = id
        self.entete = entete
        self.extrait = extrait
        self.reference = reference
        self.bouton = bouton
    }

    public var route: TextesRoute {
        .entreeBibliotheque(id: id)
    }

    /// La carte d'un paragraphe choisi.
    public init(_ pensee: SourceDuJour.Pensee, langue: String, police: PoliceHebraique.Police) {
        self.init(id: pensee.source.id,
                  entete: Libelle("source_du_jour"),
                  extrait: PoliceHebraique.masque(SourceDuJour.extrait(pensee.texte), police: police),
                  reference: Reference.localise(pensee.source.ref, langue),
                  bouton: Libelle("source_du_jour_lire"))
    }

    /// La carte du jour (`SourceDuJour.choix(library, LocalDate.now())`) ; nil si aucune source n'a de paragraphe
    /// assez long.
    public static func choisir(_ bibliotheque: Bibliotheque, jour: JourCivil, langue: String,
                               police: PoliceHebraique.Police) -> TextesSourceDuJour? {
        guard let pensee = SourceDuJour.choix(bibliotheque, jour) else { return nil }
        return TextesSourceDuJour(pensee, langue: langue, police: police)
    }
}

/// Où en est le panneau : les lignes de la reprise, l'état du Tikoun et la source du jour attendent les contenus.
public enum TextesEtat: Sendable, Equatable {
    case chargement
    case pret
}

// MARK: Le service

/// Ce que fait `SessionService.musicChanged` quand l'interrupteur de la musique bouge : la séance en cours suit
/// le réglage (MusiqueLecteur.musiqueChangee dans l'app).
public protocol TextesSignalMusique: Sendable {
    func musiqueChangee() async
}

/// Aucun signal : sans séance à prévenir (aperçus).
public struct TextesSignalMusiqueMuet: TextesSignalMusique {
    public init() {}

    public func musiqueChangee() async {}
}

/// Un signal qui compte ce qu'on lui envoie, pour les tests.
public actor TextesSignalMusiqueFaux: TextesSignalMusique {
    public private(set) var signaux = 0

    public init() {}

    public func musiqueChangee() {
        signaux += 1
    }
}

// MARK: Le modèle

/// Le panneau des textes.
@MainActor
@Observable
public final class TextesModele {
    private let magasin: Magasin
    private let contenus: ContenusApp
    private let horloge: any Horloge
    private let signal: any TextesSignalMusique
    /// « fr », « en » ou « he ».
    public let langue: String
    /// L'édition de debug : la ligne de la relecture s'ajoute à la carte (BuildConfig.DEBUG).
    public let relecture: Bool

    public private(set) var etat: TextesEtat = .chargement
    /// L'instant de l'affichage (onResume) : le jour du Tikoun, la portion de Tehilim et la source du jour.
    private var instant: Int64

    private var siddur: Siddur? = nil
    private var siddurEchec = false
    private var livres: Siddur? = nil
    private var livresEchec = false
    private var tikkun: Tikkun? = nil
    private var pensee: SourceDuJour.Pensee? = nil

    /// La clé des marque-pages des Tehilim (TehilimLectureActivity.CLE).
    public static let cleTehilim = "t:tehilim"

    public init(magasin: Magasin, contenus: ContenusApp, horloge: any Horloge, langue: String,
                signalMusique: any TextesSignalMusique = TextesSignalMusiqueMuet(), relecture: Bool = false) {
        self.magasin = magasin
        self.contenus = contenus
        self.horloge = horloge
        self.signal = signalMusique
        self.langue = ChizukCard.language(langue)
        self.relecture = relecture
        instant = horloge.maintenant
    }

    /// Prend l'heure et relit ce que les lignes nomment : à chaque apparition de l'onglet (onResume). Un contenu
    /// illisible ne montre pas d'erreur : sa ligne se tait, comme les `runCatching` d'Android.
    public func actualiser() async {
        instant = horloge.maintenant
        do {
            siddur = try await contenus.siddur(magasin.reglages.siddurNusah)
            siddurEchec = false
        } catch {
            siddur = nil
            siddurEchec = true
        }
        do {
            livres = try await contenus.livres()
            livresEchec = false
        } catch {
            livres = nil
            livresEchec = true
        }
        tikkun = try? await contenus.tikkun()
        if let bibliotheque = try? await contenus.bibliotheque() {
            pensee = SourceDuJour.choix(bibliotheque, aujourdhui)
        } else {
            pensee = nil
        }
        etat = .pret
    }

    // MARK: L'en-tête

    /// « Bibliothèque » : 24 sp, gras, encre.
    public var titre: Libelle {
        Libelle("nav_texts")
    }

    /// Le bouton à contour de la recherche, toute la largeur, le texte au début.
    public var recherche: Libelle {
        Libelle("recherche_indice")
    }

    public var routeRecherche: TextesRoute {
        .recherche
    }

    // MARK: Reprendre, favoris, marque-pages

    /// La police hébraïque choisie : celle des titres de la reprise et de l'extrait de la source du jour.
    public var police: PoliceHebraique.Police {
        PoliceHebraique.Police(rawValue: magasin.reglages.lecturePolice) ?? .serif
    }

    /// RepriseFavoris.lignes : « Reprendre » le dernier texte lu, puis les favoris (l'en-tête sur le premier), puis
    /// la ligne des marque-pages s'il y en a. Un texte qui n'existe plus est passé sous silence ; un recueil qui
    /// n'a pu être lu tait toute la liste (le `runCatching` de MainActivity). Vide avant `actualiser()`.
    public var reprise: [TextesRepriseLigne] {
        guard etat == .pret else { return [] }
        let reglages = magasin.reglages
        var lignes: [TextesRepriseLigne] = []
        if let cle = Store.derniereLecture(reglages: reglages) {
            switch nomDe(cle) {
            case .echec:
                return []
            case .absent:
                break
            case .nom(let nom):
                lignes.append(TextesRepriseLigne(id: "reprise", genre: .reprise, entete: Libelle("reprise_titre"),
                                                 titre: nom, nombre: nil, icone: nil, route: TextesModele.route(cle)))
            }
        }
        var premier = true
        for (rang, cle) in Store.favoris(reglages: reglages).enumerated() {
            switch nomDe(cle) {
            case .echec:
                return []
            case .absent:
                continue
            case .nom(let nom):
                lignes.append(TextesRepriseLigne(id: "favori:\(rang):\(cle)", genre: .favori,
                                                 entete: premier ? Libelle("favoris_titre") : nil,
                                                 titre: nom, nombre: nil, icone: nil, route: TextesModele.route(cle)))
                premier = false
            }
        }
        var nombre = 0
        for marque in Store.marques(reglages: reglages) {
            switch nomDe(marque.cle) {
            case .echec:
                return []
            case .absent:
                continue
            case .nom:
                nombre += 1
            }
        }
        if nombre > 0 {
            // SiddurLectureActivity.icone(recueil == "l") : sans recueil, l'icône des prières.
            lignes.append(TextesRepriseLigne(id: "signets", genre: .signets, entete: nil,
                                             titre: .libelle(Libelle("marques_titre")), nombre: nombre,
                                             icone: "ic_marque_priere", route: .marquesPages(recueil: nil)))
        }
        return lignes
    }

    // MARK: Les cartes

    /// La carte des textes, dans l'ordre d'activity_main.xml ; la relecture au bout, en debug.
    public var entrees: [TextesEntree] {
        var lignes = [
            TextesEntree(id: "tikkun_button", titre: Libelle("tikkun_title"), etat: etatTikkun, route: .tikkun),
            TextesEntree(id: "siddur_button", titre: Libelle("siddur_title"), etat: Libelle("siddur_hint"),
                         route: .siddour),
            TextesEntree(id: "tehilim_button", titre: Libelle("tehilim_title"), etat: etatTehilim, route: .tehilim),
            TextesEntree(id: "tefilot_button", titre: Libelle("tefilot_title"), etat: Libelle("tefilot_hint"),
                         route: .tefilot),
            TextesEntree(id: "livres_button", titre: Libelle("livres_title"), etat: Libelle("livres_hint"),
                         route: .bibliotheque(livresSeuls: true)),
            TextesEntree(id: "library_button", titre: Libelle("library_title"), etat: Libelle("library_hint"),
                         route: .bibliotheque(livresSeuls: false)),
            TextesEntree(id: "chizuk_button", titre: Libelle("chizuk_demande_title"),
                         etat: Libelle("chizuk_demande_hint"), route: .chizuk),
            TextesEntree(id: "tips_button", titre: Libelle("tips_title"), etat: Libelle("tips_hint"),
                         route: .conseils),
        ]
        if relecture {
            lignes.append(TextesEntree(id: "proofread_button", titre: Libelle("proofread_open"), etat: nil,
                                       route: .relecture))
        }
        return lignes
    }

    /// « Autour de la hitbodedout » : 12 sp, capitales, espacé, discret, au-dessus de la seconde carte.
    public var titreAutour: Libelle {
        Libelle("section_around")
    }

    /// La seconde carte : la musique (avec son interrupteur), puis les rappels.
    public var autour: [TextesEntree] {
        [
            TextesEntree(id: "music_button", titre: Libelle("music_title"), etat: etatMusique,
                         interrupteur: musiqueActive, route: .musique),
            TextesEntree(id: "reminders_button", titre: Libelle("reminders_title"), etat: etatRappels,
                         route: .rappels),
        ]
    }

    // MARK: Les états des lignes

    /// renderTikkun : les psaumes déjà dits ce jour du Tikoun (il bascule à 4 h) ; nil tant que le Tikoun n'est
    /// pas lu, ou s'il n'a pu l'être.
    public var etatTikkun: Libelle? {
        guard let tikkun else { return nil }
        let dits = Store.tikkunDone(reglages: magasin.reglages, maintenant: horloge.fuseau.dateHeure(millis: instant)).count
        let total = tikkun.psaumes.count
        if dits == 0 {
            return Libelle("tikkun_progress_none", .entier(total), .entier(tikkun.versets))
        }
        if dits == total {
            return Libelle("tikkun_progress_all")
        }
        return Libelle("tikkun_progress", .entier(dits), .entier(total))
    }

    /// renderTehilim : la portion du jour du mois hébraïque (le jour change à minuit), « Aujourd'hui : Tehilim 1 à 9 ».
    public var etatTehilim: Libelle {
        let (jour, longueur) = CycleTehilim.jourHebreu(aujourdhui)
        return Libelle("tehilim_today", .libelle(TextesModele.portion(CycleTehilim.duMois(jour, longueur), langue: langue)))
    }

    /// renderMusic : éteinte, aucun morceau, lecture aléatoire, ou le morceau choisi, avec le volume.
    public var etatMusique: Libelle {
        let reglages = magasin.reglages
        let bibliotheque = MusicLibrary.Etat(names: reglages.musicNames, userTracks: reglages.musicUserTracks,
                                             trackId: reglages.musicTrackId)
        let morceau = MusicLibrary.selected(bibliotheque)
        if !reglages.musicEnabled {
            return Libelle("music_off_summary")
        }
        guard let morceau else {
            return Libelle("music_none_summary")
        }
        if reglages.musicShuffle {
            return Libelle("music_shuffle_summary", .entier(reglages.musicVolume))
        }
        let nomMorceau: Libelle.Argument
        switch morceau.title {
        case .nom(let nom):
            nomMorceau = .texte(nom)
        case .libelle(let libelle):
            nomMorceau = .libelle(libelle)
        }
        return Libelle("music_on_summary", nomMorceau, .entier(reglages.musicVolume))
    }

    /// renderReminders : éteints, sans heure, ou le nombre d'heures réglées.
    public var etatRappels: Libelle {
        let reglages = magasin.reglages
        let heures = reglages.reminderTimes
        if !reglages.reminderEnabled {
            return Libelle("reminders_off")
        }
        if heures.isEmpty {
            return Libelle("reminders_none")
        }
        return Libelle.pluriel("reminders_count", quantite: heures.count, .entier(heures.count))
    }

    // MARK: La musique

    /// L'interrupteur de la musique (music_switch_main) : le réglage « music_enabled ».
    public var musiqueActive: Bool {
        magasin.reglages.musicEnabled
    }

    /// renderSwitches : la musique allumée ou éteinte, puis la séance en cours prévenue (SessionService.musicChanged).
    /// Le changement se voit tout de suite ; une écriture refusée rend son erreur, la séance est prévenue quand
    /// même (le réglage a changé en mémoire). Une position inchangée ne fait rien.
    public func basculerMusique(_ actif: Bool) async throws {
        guard actif != magasin.reglages.musicEnabled else { return }
        do {
            try await magasin.modifierReglages { $0.setMusicEnabled(actif) }
        } catch {
            await signal.musiqueChangee()
            throw error
        }
        await signal.musiqueChangee()
    }

    // MARK: La source du jour

    /// La source du jour (SourceDuJour.carte) : le paragraphe choisi à `actualiser()` pour le jour qu'il est ; nil
    /// avant, sans bibliothèque, ou sans paragraphe assez long. Sur Android, une carte de l'accueil.
    public var sourceDuJour: TextesSourceDuJour? {
        guard let pensee else { return nil }
        return TextesSourceDuJour(pensee, langue: langue, police: police)
    }

    // MARK: Les aides

    /// Le jour civil de l'affichage, dans le fuseau du téléphone (`LocalDate.now()`).
    private var aujourdhui: JourCivil {
        horloge.fuseau.jour(millis: instant)
    }

    private enum TitreLu {
        case nom(TextesNom)
        /// Le texte n'existe pas (ou plus) : la ligne se tait.
        case absent
        /// Le recueil n'a pu être lu : toute la liste se tait.
        case echec
    }

    /// RepriseFavoris.titre : le titre hébreu d'une clé « s:id » (le siddour du nusah choisi) ou « l:id » (l'index
    /// des livres), « Tehilim » pour « t:tehilim ».
    private func nomDe(_ cle: String) -> TitreLu {
        if cle.egalUnites(TextesModele.cleTehilim) { return .nom(.libelle(Libelle("tehilim_title"))) }
        let id = cle.apresUnites(":")
        let recueil: Siddur?
        if cle.commenceParUnites("l:") {
            if livresEchec { return .echec }
            recueil = livres
        } else {
            if siddurEchec { return .echec }
            recueil = siddur
        }
        guard let he = recueil?.texte(id)?.titre.he else { return .absent }
        return .nom(.hebreu(PoliceHebraique.masque(he, police: police)))
    }

    /// RepriseFavoris.ouvrir : un livre par ouvrirLivre, le reste par ouvrir. « t:tehilim » (que ni la reprise ni
    /// les favoris d'Android n'écrivent) ouvre le livre de Tehilim plutôt qu'un texte du siddour qui n'existe pas.
    static func route(_ cle: String) -> TextesRoute {
        if cle.egalUnites(cleTehilim) { return .tehilim }
        return .lecture(id: cle.apresUnites(":"), livre: cle.commenceParUnites("l:"))
    }

    /// TehilimTexte.portion (TehilimActivity.kt) : « Tehilim 25 », « Tehilim 1 à 9 », « Tehilim 119, versets 1 à
    /// 96 » ; les numéros en lettres en hébreu.
    static func portion(_ p: Portion, langue: String) -> Libelle {
        if p.partielle {
            return Libelle("tehilim_range_verses", .texte(nombre(p.debut, langue: langue)),
                           .texte(nombre(p.debutVerset, langue: langue)), .texte(nombre(p.finVerset ?? 0, langue: langue)))
        }
        if p.debut == p.fin {
            return Libelle("tehilim_single", .texte(nombre(p.debut, langue: langue)))
        }
        return Libelle("tehilim_range", .texte(nombre(p.debut, langue: langue)), .texte(nombre(p.fin, langue: langue)))
    }

    /// TehilimTexte.nombre : en lettres en hébreu (« כ״ה »), en chiffres sinon.
    private static func nombre(_ n: Int, langue: String) -> String {
        ChizukCard.language(langue).egalUnites("he") ? Reference.lettres(n) : String(n)
    }
}
