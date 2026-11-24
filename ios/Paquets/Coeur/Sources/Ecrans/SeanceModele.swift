import Foundation
import Observation
import Coeur

// L'écran de séance (SessionActivity.kt, activity_session.xml) : le choix de la durée, puis le décompte ; le
// mot de 'hizouk du moment (ChizukCard.kt), la hitbodedout guidée (HitbodedutCard.kt, view_hitbodedut.xml),
// « Je n'arrive pas à parler » et ses questions (QuestionsBlocage), le sujet, la ligne de musique, la pratique
// calme (PratiqueCalme.kt) et la lueur du souffle (SouffleView.kt). La séance elle-même vit dans
// `SeanceEnCours`, partagée : elle continue hors de l'écran.
//
// La vue appelle `ouvrir` en paraissant (onCreate et sa demande de départ), `revenir` au retour au premier plan
// (onResume), et `actualiser` chaque seconde (le `tick` d'Android) ; le décompte, elle l'anime elle-même
// (TimelineView) d'après `decompte` et `texteDecompte(a:)`.
//
// Le 'hizouk est tiré ici comme ChizukBag.draw le fait (le sac dans les réglages, Store de Coeur) : sans
// dépendre de l'écran du 'hizouk, encore en chantier. Les images passent par `Personnage.pour` (צדקת).

/// La demande avec laquelle l'écran s'ouvre (les extras d'Android).
public enum SeanceDemande: Sendable, Hashable {
    /// Ouvrir l'écran, sans plus.
    case aucune
    /// « Commencer » d'un rappel, de l'accueil, du bouclier ou d'un raccourci (EXTRA_START_NOW) : la séance
    /// part seule à la durée habituelle, sauf s'il y en a déjà une.
    case commencer
}

/// Les écrans que la séance ouvre par-dessus elle.
public enum SeanceRoute: Sendable, Hashable, Identifiable {
    /// Le bravo de fin de séance, ou « ’Hazak » après un abandon (CelebrationActivity).
    case celebration(CelebrationDemande)
    /// « Écrire » : la note du jour (NoteDialog), la séance déjà partie.
    case note(JourCivil)
    /// « Prier » : l'écran des prières (TefilotActivity), la séance déjà partie.
    case tefilot

    public var id: String {
        switch self {
        case .celebration(let demande): "celebration-\(demande.annulee)-\(demande.minutes)"
        case .note(let jour): "note-\(jour.iso)"
        case .tefilot: "tefilot"
        }
    }
}

/// Les dialogues de l'écran.
public enum SeanceDialogue: String, Sendable, Hashable, Identifiable, CaseIterable {
    /// « Terminer la hitbodedout ? » (confirmFinish).
    case terminer
    /// « Abandonner la hitbodedout ? » (confirmCancel).
    case abandonner
    /// « Sur quoi voulez-vous parler ? » : la liste des sujets, « Aucun » en tête (pickTheme).
    case sujet
    /// « Durée de la hitbodedout, en minutes » : un champ numérique (DureeSeance.saisir).
    case duree

    public var id: String { rawValue }

    public var titre: Libelle {
        switch self {
        case .terminer: Libelle("session_finish_title")
        case .abandonner: Libelle("session_cancel_title")
        case .sujet: Libelle("session_theme_title")
        case .duree: Libelle("duration_custom_title")
        }
    }

    /// Le texte sous le titre ; nil pour la liste et le champ.
    public var message: Libelle? {
        switch self {
        case .terminer: Libelle("session_finish_message")
        case .abandonner: Libelle("session_cancel_message")
        case .sujet, .duree: nil
        }
    }

    /// Le bouton qui confirme ; nil pour la liste (toucher un sujet le choisit). « OK » du champ : la clé
    /// `action_ok` est à ajouter au catalogue (android.R.string.ok n'y est pas).
    public var confirmer: Libelle? {
        switch self {
        case .terminer: Libelle("session_finish_now")
        case .abandonner: Libelle("session_cancel")
        case .sujet: nil
        case .duree: Libelle("action_ok")
        }
    }

    /// Le bouton qui renonce : « Retour » ; la liste se ferme d'un toucher à côté.
    public var retour: Libelle? {
        self == .sujet ? nil : Libelle("action_back")
    }

    /// Le bouton qui confirme détruit-il quelque chose ? (« Abandonner » : rien ne sera enregistré.)
    public var destructif: Bool {
        self == .abandonner
    }
}

/// Le grand chiffre sous le personnage.
public enum SeanceDecompte: Sendable, Hashable {
    /// À l'arrêt : la durée de la prochaine séance (« 15 min »), que le bouton principal lancera.
    case duree(Libelle)
    /// Une séance minutée : le temps qui reste jusqu'à `fin` (millisecondes Unix), « mm:ss ».
    case reste(fin: Int64)
    /// Une séance sans durée : le temps passé depuis `debut`, « mm:ss ».
    case ecoule(debut: Int64)
    /// Le décompte est masqué : le chiffre disparaît (GONE), la légende le dit.
    case masque
}

/// Une durée proposée (5, 10, 15, 30 min, 1 h, 1 h 30), en deux rangées de trois.
public struct SeanceDureeProposee: Sendable, Hashable, Identifiable {
    public let minutes: Int
    public let libelle: Libelle
    public var id: Int { minutes }
}

/// Une entrée de la liste des sujets : « Aucun » (nil) en tête, puis les dix sujets.
public struct SeanceChoixSujet: Sendable, Hashable, Identifiable {
    public let theme: Theme?
    public let libelle: Libelle
    public var id: String { theme?.cle ?? "" }
}

/// La carte de 'hizouk (view_chizuk.xml, ChizukCard.bind) : tout ce qu'elle montre, prêt à afficher.
public struct SeanceCarteChizuk: Sendable, Equatable {
    public let id: String
    public let moment: Moment
    /// L'illustration du moment (Poses.ofMoment), au féminin s'il le faut ; elle ne change pas d'un tirage à
    /// l'autre.
    public let image: String
    /// Le nom du moment, en tête de carte (« Pour commencer », « Quand les mots ne viennent pas »…).
    public let titre: Libelle
    /// Le badge « à relire » (seulement en debug).
    public let aRelire: Bool
    /// Le premier texte : l'hébreu, ou la traduction seule si les langues de lecture n'ont pas l'hébreu.
    public let texte: String
    /// Sa langue (« he », « fr », « en »).
    public let langueTexte: String
    /// L'hébreu, de droite à gauche ; une traduction seule, de gauche à droite.
    public let texteDroiteAGauche: Bool
    /// La traduction sous le filet ; nil quand il n'y a qu'un texte.
    public let second: String?
    /// La source, dans la langue de l'app.
    public let reference: String

    public init(item: ChizukItem, chizuk: Chizuk, moment: Moment, mode: LanguesTexte.Mode, langue: String,
                adresse: Adresse?) {
        let hebreu = ChizukRules.hebrew(chizuk, item)
        let textes = LanguesTexte.textes(mode, hebreu, item.fr.estBlanc ? nil : item.fr,
                                         item.en.estBlanc ? nil : item.en)
        let premier = textes.first ?? (langue: "he", texte: hebreu)
        id = item.id
        self.moment = moment
        image = Personnage.pour(adresse, Poses.ofMoment(moment))
        titre = Libelle(SeanceCarteChizuk.cleMoment(moment))
        aRelire = ChizukRules.needsProofreading(item)
        texte = premier.texte
        langueTexte = premier.langue
        texteDroiteAGauche = premier.langue.egalUnites("he")
        let suivant = textes.count > 1 ? textes[1].texte : ""
        second = suivant.estBlanc ? nil : suivant
        reference = Reference.localise(item.ref, langue)
    }

    /// `Moment.labelRes`.
    public static func cleMoment(_ moment: Moment) -> String {
        switch moment {
        case .ouverture: "moment_ouverture"
        case .blocage: "moment_blocage"
        case .porte: "moment_porte"
        case .relance: "moment_relance"
        case .cloture: "moment_cloture"
        case .lieu: "moment_lieu"
        case .demande: "chizuk_demande_title"
        }
    }

    /// Les langues de lecture (`LanguesTexte.mode(context)`) : le choix enregistré, sinon celles de la langue
    /// de l'app.
    public static func mode(_ reglages: Reglages, langue: String) -> LanguesTexte.Mode {
        if let cle = reglages.lectureLangues, let mode = LanguesTexte.Mode(rawValue: cle) {
            return mode
        }
        return LanguesTexte.defaut(langue)
    }
}

/// Le tirage d'un texte de 'hizouk pour un moment (`ChizukBag.draw`) : dans ce que la compilation a le droit de
/// montrer, sans remise, jamais le dernier sorti en tête d'un nouveau cycle ; le sac reste dans les réglages.
public enum SeanceTirage {
    public static func tirer(_ chizuk: Chizuk, moment: Moment, debug: Bool, reglages: inout Reglages,
                             melange: ([String]) -> [String]) -> String? {
        let vivier = ChizukRules.forMoment(chizuk, moment, debug: debug).map { $0.id }
        let tirage = ChizukBag.next(remaining: Store.chizukBag(reglages: reglages, moment: moment), pool: vivier,
                                    last: Store.chizukLast(reglages: reglages, moment: moment), shuffle: melange)
        Store.setChizukBag(reglages: &reglages, moment: moment, bag: tirage.remaining, last: tirage.id)
        return tirage.id
    }
}

/// La carte de la hitbodedout guidée (view_hitbodedut.xml, HitbodedutCard.bind) : un temps à la fois.
public struct SeanceGuide: Sendable, Equatable {
    /// L'indice du temps, de 0 à 4.
    public let etape: Int
    /// L'illustration du temps, au féminin s'il le faut.
    public let image: String
    /// La pastille « 2 / 5 ».
    public let rang: Libelle
    /// L'intitulé hébreu, de droite à gauche, en police hébraïque, gras.
    public let hebreu: String
    public let titre: Libelle
    public let invitation: Libelle
    /// L'invitation du temps pour le sujet choisi (guide_sujets.json) ; nil : caché.
    public let sujet: String?
    /// La source, dans la langue de l'app, de droite à gauche.
    public let source: String
    /// « Précédent » : invisible (sa place gardée) au premier temps.
    public let precedentVisible: Bool
    /// « Suivant » : invisible (sa place gardée) au dernier temps.
    public let suivantVisible: Bool
}

/// La carte « une question à la fois » (session_questions).
public struct SeanceQuestion: Sendable, Equatable {
    /// Le rang de la question, de 0 à 9.
    public let rang: Int
    /// La question.
    public let texte: Libelle
    /// « Question 3 sur 10 », en petites capitales espacées.
    public let position: Libelle
    /// La jauge fine, de 0 à 100.
    public let progression: Int
}

/// La lueur du souffle (SouffleView.kt) : derrière le minuteur, elle grandit en quatre secondes et décroît en
/// six, sans fin. Elle ne compte rien. « Réduire les animations » : elle reste, immobile, à `phaseImmobile`.
public enum SeanceSouffle {
    /// Un souffle : dix secondes.
    public static let cycle: Int64 = 10_000
    /// La part de l'inspiration : 40 % (4 s).
    public static let inspiration = 0.4
    /// La phase de la lueur immobile.
    public static let phaseImmobile = 0.6
    /// Le rayon de la lueur, en part du plus petit côté (la largeur de la vue, la hauteur de l'écran).
    public static let rayon = 0.42
    /// Le dégradé radial de la menthe : opacité 1 au centre, 90/255 à 55 % du rayon, 0 au bord.
    public static let degrade: [(position: Double, opacite: Double)] = [(0, 1), (0.55, 90.0 / 255), (1, 0)]

    /// La phase (0 : expiré, 1 : inspiré) à `millis` depuis n'importe quelle origine fixe ; chaque moitié adoucie
    /// par la courbe (0,45 ; 0 ; 0,55 ; 1) d'Android (PathInterpolator).
    public static func phase(_ millis: Int64) -> Double {
        let t = Double(Kotlin.floorMod(Int(millis % cycle), Int(cycle))) / Double(cycle)
        if t < inspiration { return doux(t / inspiration) }
        return 1 - doux((t - inspiration) / (1 - inspiration))
    }

    /// L'échelle de la lueur : de 0,78 à 1.
    public static func echelle(_ phase: Double) -> Double {
        0.78 + 0.22 * phase
    }

    /// L'opacité de la lueur : de 0,16 à 0,42.
    public static func opacite(_ phase: Double) -> Double {
        0.16 + 0.26 * phase
    }

    /// La courbe de Bézier cubique (0,0) (0,45 ; 0) (0,55 ; 1) (1,1), lue en x.
    static func doux(_ x: Double) -> Double {
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        var bas = 0.0
        var haut = 1.0
        for _ in 0..<48 {
            let milieu = (bas + haut) / 2
            if bezier(milieu, 0.45, 0.55) < x {
                bas = milieu
            } else {
                haut = milieu
            }
        }
        return bezier((bas + haut) / 2, 0, 1)
    }

    private static func bezier(_ s: Double, _ p1: Double, _ p2: Double) -> Double {
        let r = 1 - s
        return 3 * r * r * s * p1 + 3 * r * s * s * p2 + s * s * s
    }
}

/// L'écran de séance.
@MainActor
@Observable
public final class SeanceModele {

    /// Six secondes sans toucher, et la pratique devient calme (PratiqueCalme.DELAI_MS).
    public static let delaiCalme: Int64 = 6_000
    /// Le fondu d'entrée dans le calme, et celui de la sortie, en millisecondes ; 0 si les animations sont
    /// réduites.
    public static let fonduCalme = 900
    public static let fonduReveil = 250
    /// Le fond assombri du calme : brand_dark mêlé de noir à 55 %.
    public static let assombrissement = 0.55

    /// La séance partagée.
    public let seance: SeanceEnCours
    private let contenus: ContenusApp
    /// « fr », « en » ou « he ».
    public let langue: String
    /// Vrai en debug : les textes non relus passent aussi, avec leur badge.
    public let debug: Bool
    private let melange: @Sendable ([String]) -> [String]

    private var magasin: Magasin { seance.magasin }
    private var horloge: any Horloge { seance.horloge }

    /// Le temps courant de la hitbodedout guidée : il appartient à la séance et repart à zéro avec elle.
    public private(set) var guideEtape = 0
    /// La question en cours de « Je ne sais pas quoi dire » ; -1 : aucune.
    public private(set) var questionRang = -1
    /// Monte à chaque « Question suivante » : la vue fond la carte (Effets.fondu).
    public private(set) var changementsQuestion = 0
    /// L'écran ouvert par-dessus (le bravo, la note, les prières) ; la vue le remet à nil en le fermant.
    public var route: SeanceRoute? = nil
    /// Le dialogue ouvert ; la vue le remet à nil en le fermant.
    public var dialogue: SeanceDialogue? = nil
    /// La pratique est calme : tout s'efface sauf le minuteur, sa lueur, « Terminer », le guide et la question.
    public private(set) var calme = false
    /// VoiceOver est actif : rien ne s'efface (un bouton invisible resterait atteignable). La vue le tient à jour.
    public private(set) var lecteurEcran = false
    /// Le texte de 'hizouk sur la carte ; nil : la carte est cachée.
    public private(set) var carteId: String? = nil
    public private(set) var carteMoment: Moment = .ouverture
    /// Monte à chaque nouveau tirage : la vue peut fondre la carte.
    public private(set) var tirages = 0

    private var chizuk: Chizuk? = nil
    private var sujetsGuide: ObjetJSON? = nil
    private var charge = false
    /// Pour repérer la fin d'une séance, qu'elle vienne du décompte ou du bouton.
    private var etaitEnCours = false
    /// Une séance abandonnée n'est pas une séance close : pas de mot de fin.
    private var abandon = false
    /// La pratique suivie par le calme, et le dernier geste.
    private var calmeSuivi = false
    private var derniereActivite: Int64 = 0

    /// `melange` : le mélange du vivier de 'hizouk quand un sac se remplit ; un mélange fixe dans les tests.
    public init(seance: SeanceEnCours, contenus: ContenusApp, langue: String, debug: Bool,
                melange: @escaping @Sendable ([String]) -> [String] = { $0.shuffled() }) {
        self.seance = seance
        self.contenus = contenus
        self.langue = ChizukCard.language(langue)
        self.debug = debug
        self.melange = melange
    }

    // MARK: La vie de l'écran

    /// L'écran paraît (onCreate, onNewIntent) : les textes sont lus et le mot d'ouverture tiré, une fois ;
    /// une demande de départ lance la séance à la durée habituelle s'il n'y en a pas déjà une ; puis `revenir`.
    public func ouvrir(_ demande: SeanceDemande = .aucune) async {
        if !charge {
            charge = true
            chizuk = try? await contenus.chizuk()
            sujetsGuide = try? await contenus.guideSujets()
            await tirer(.ouverture)
        }
        if demande == .commencer && !seance.enCours {
            do {
                try await lancer(magasin.reglages.targetMinutes)
            } catch {
                // La séance est partie ; son écriture se refera à la prochaine.
            }
        }
        await revenir()
    }

    /// Le retour au premier plan (onResume) : une séance restée sans suivi est réconciliée, puis l'écran est
    /// rendu.
    public func revenir() async {
        do {
            try await seance.reconcilier()
        } catch {
            // Le changement reste en mémoire ; la prochaine écriture l'emportera.
        }
        await actualiser()
    }

    /// Chaque seconde (`render`) : la séance arrivée à son terme est close ; au passage de « en cours » à
    /// « terminée », le mot de clôture est tiré (pas après un abandon) ; à l'arrêt, un bravo en attente s'ouvre ;
    /// six secondes sans geste pendant la pratique, et elle devient calme.
    public func actualiser() async {
        do {
            try await seance.actualiser()
        } catch {
            // Le changement reste en mémoire ; la prochaine écriture l'emportera.
        }
        let enCours = seance.enCours
        let finie = etaitEnCours && !enCours
        // Retenu avant de tirer : un autre tour (la boucle d'une seconde, « Terminer ») qui passerait pendant
        // l'écriture du sac ne tirerait pas un second mot de clôture.
        etaitEnCours = enCours
        if finie {
            if abandon {
                abandon = false
            } else {
                await tirer(.cloture)
            }
        }
        suivreCalme(enCours)
        if !enCours {
            questionRang = -1
            if route == nil, let demande = await CelebrationDemande.prendre(magasin) {
                route = .celebration(demande)
            }
        }
    }

    // MARK: Ce qui s'affiche

    /// La séance court.
    public var enCours: Bool {
        seance.enCours
    }

    /// « HITBODEDOUT », petit, espacé, en menthe.
    public var titre: Libelle {
        Libelle("session_screen_title")
    }

    /// Le personnage : seul, tourné vers le haut pendant la séance ; à l'arrêt, la joie si la journée est faite,
    /// l'appel sinon. Il change d'un jour à l'autre, jamais sous les yeux.
    public var image: String {
        let jour = horloge.aujourdhui
        let pose: String
        if enCours {
            pose = Poses.during(jour)
        } else if magasin.journal.isDone(jour) {
            pose = Poses.joy(jour)
        } else {
            pose = Poses.call(jour)
        }
        return Personnage.pour(adresse, pose)
    }

    /// Le grand chiffre. Le filtre du mode de concentration (`ConcentrationFiltre`, propre à iOS) le masque aussi.
    public var decompte: SeanceDecompte {
        let reglages = magasin.reglages
        guard enCours else { return .duree(Store.formatDuration(reglages.targetMinutes)) }
        if masqueParConcentration { return .masque }
        switch Store.sessionCounter(reglages: reglages) {
        case .masque: return .masque
        case .ecoule: return .ecoule(debut: Store.sessionStartedAt(reglages: reglages))
        case .reste: return .reste(fin: Store.sessionEndsAt(reglages: reglages))
        }
    }

    /// Le chiffre à l'instant `maintenant` (millisecondes Unix) : « mm:ss » restant ou écoulé, jamais négatif ;
    /// nil à l'arrêt (le chiffre est alors `decompte`, une durée) et sous un décompte masqué.
    public func texteDecompte(a maintenant: Int64) -> String? {
        switch decompte {
        case .duree, .masque: return nil
        case .reste(let fin): return SeanceModele.minutesSecondes(max(fin &- maintenant, 0))
        case .ecoule(let debut): return SeanceModele.minutesSecondes(max(maintenant &- debut, 0))
        }
    }

    /// Ce que VoiceOver dit du chiffre pendant la séance (« Il reste 12 min », « Depuis 5 min ») ; nil à l'arrêt.
    public var decompteAccessible: Libelle? {
        guard enCours else { return nil }
        return masqueParConcentration ? Libelle("session_running_hidden") : seance.texteEnCours
    }

    /// Le décompte est masqué par le filtre du mode de concentration (propre à iOS, PORTAGE.md § 2.2.6), et non
    /// par le réglage « Masquer le décompte » : sans le son de fin de ce réglage.
    private var masqueParConcentration: Bool {
        enCours && ConcentrationFiltre.masqueDecompte(magasin.reglages)
    }

    /// « %02d:%02d » des minutes et des secondes (Locale.US) ; les minutes au-delà de 99 s'écrivent en entier.
    public static func minutesSecondes(_ millis: Int64) -> String {
        deuxChiffres(millis / 60_000) + ":" + deuxChiffres((millis / 1_000) % 60)
    }

    /// La légende sous le chiffre.
    public var legende: Libelle {
        let reglages = magasin.reglages
        if enCours {
            // Masqué par le seul filtre de concentration : aucun son ne préviendra (session_hidden_caption le promet).
            if masqueParConcentration && Store.sessionCounter(reglages: reglages) != .masque {
                return Libelle("session_running_hidden")
            }
            switch Store.sessionCounter(reglages: reglages) {
            case .masque: return Libelle("session_hidden_caption")
            case .ecoule: return Libelle("session_open_caption")
            case .reste:
                return Libelle("session_target", .libelle(Store.formatDuration(Store.sessionTarget(reglages: reglages))))
            }
        }
        // Fait, le grand chiffre reste la durée de la prochaine : la légende dit ce qui a été fait (13/10).
        let jour = horloge.aujourdhui
        if magasin.journal.isDone(jour) {
            let minutes = magasin.journal.record(jour)?.minutes ?? 0
            return Libelle("session_idle_done", .libelle(Store.formatDuration(minutes)))
        }
        return Libelle("session_idle_caption")
    }

    /// « Musique : <titre> » ; en lecture aléatoire, le morceau qui joue réellement, ou « Aléatoire » avant le
    /// premier ; nil sans musique (la ligne est cachée).
    public var ligneMusique: Libelle? {
        let reglages = magasin.reglages
        guard reglages.musicEnabled else { return nil }
        let etat = MusicLibrary.Etat(names: reglages.musicNames, userTracks: reglages.musicUserTracks,
                                     trackId: reglages.musicTrackId)
        guard let choisi = MusicLibrary.selected(etat) else { return nil }
        if reglages.musicShuffle {
            guard let enCoursId = reglages.musicNow else {
                return Libelle("session_music_line", .libelle(Libelle("music_shuffle_short")))
            }
            let morceau = MusicLibrary.byId(etat, enCoursId) ?? choisi
            return Libelle("session_music_line", SeanceModele.argument(morceau.title))
        }
        return Libelle("session_music_line", SeanceModele.argument(choisi.title))
    }

    /// Le bouton principal, juste sous le minuteur : « Terminer maintenant » pendant la séance, « Commencer,
    /// 15 min » à l'arrêt.
    public var libellePrincipal: Libelle {
        if enCours { return Libelle("session_finish_now") }
        return Libelle("session_start", .libelle(Store.formatDuration(magasin.reglages.targetMinutes)))
    }

    /// Le bouton texte sous lui : « Abandonner » pendant la séance ; nil à l'arrêt (caché).
    public var libelleSecondaire: Libelle? {
        enCours ? Libelle("session_cancel") : nil
    }

    /// Le bouton du sujet : « Sujet : aucun (facultatif) » ou « Sujet : Gratitude ».
    public var libelleSujet: Libelle {
        guard let theme = seance.sujet else { return Libelle("session_theme_none") }
        return Libelle("session_theme_chosen", .libelle(Libelle(theme.titre)))
    }

    /// La liste des sujets : « Aucun » en tête, c'est la valeur de départ et le choix le plus fréquent.
    public var choixSujets: [SeanceChoixSujet] {
        [SeanceChoixSujet(theme: nil, libelle: Libelle("session_theme_none_short"))]
            + Theme.allCases.map { SeanceChoixSujet(theme: $0, libelle: Libelle($0.titre)) }
    }

    /// Le sujet coché dans la liste.
    public var sujetChoisi: Theme? {
        seance.sujet
    }

    /// Les durées, « Durée réglable… », « Sans durée » et « Commencer simplement » : à l'arrêt seulement.
    public var choixVisibles: Bool {
        !enCours
    }

    /// Les six durées proposées, en deux rangées de trois.
    public var durees: [SeanceDureeProposee] {
        DureeSeance.proposees.map { SeanceDureeProposee(minutes: $0, libelle: Store.formatDuration($0)) }
    }

    public var libelleDureeReglable: Libelle { Libelle("duration_custom") }
    public var libelleSansDuree: Libelle { Libelle("session_open") }
    /// Le champ de la durée réglable : son indication, et son texte de départ (la durée habituelle, tout
    /// sélectionné).
    public var indicationDuree: Libelle { Libelle("duration_custom_hint") }
    public var saisieInitiale: String { String(magasin.reglages.targetMinutes) }

    /// « Commencer simplement » : quatre façons d'entrer, qui démarrent tout de suite.
    public var libellesSimplement: [Libelle] {
        ["simplement_parler", "simplement_ecrire", "simplement_prier", "simplement_question"].map { Libelle($0) }
    }

    /// « Je n'arrive pas à parler » : pendant la séance, et seulement s'il y a un texte à donner.
    public var blocageVisible: Bool {
        guard enCours, let chizuk else { return false }
        return !ChizukRules.forMoment(chizuk, .blocage, debug: debug).isEmpty
    }

    public var libelleBlocage: Libelle { Libelle("chizuk_stuck") }

    /// La carte de 'hizouk ; nil : cachée (rien d'affichable).
    public var carte: SeanceCarteChizuk? {
        guard let chizuk, let id = carteId, let item = chizuk.item(id) else { return nil }
        return SeanceCarteChizuk(item: item, chizuk: chizuk, moment: carteMoment,
                                 mode: SeanceCarteChizuk.mode(magasin.reglages, langue: langue), langue: langue,
                                 adresse: adresse)
    }

    /// La hitbodedout guidée, pendant la séance et si elle est demandée (Réglages) ; nil : cachée.
    public var guide: SeanceGuide? {
        guard enCours, magasin.reglages.guidedHitbodedut else { return nil }
        let mouvement = Hitbodedut.mouvement(guideEtape)
        var sujet: String? = nil
        if let sujetsGuide {
            sujet = GuideSujets.invitation(sujetsGuide, theme: seance.sujet, cle: mouvement.cle, langue: langue)
        }
        return SeanceGuide(etape: guideEtape, image: Personnage.pour(adresse, mouvement.illustration),
                           rang: Libelle("hitbodedut_step", .entier(guideEtape + 1),
                                         .entier(Hitbodedut.mouvements.count)),
                           hebreu: mouvement.he, titre: Libelle(mouvement.titre), invitation: Libelle(mouvement.invite),
                           sujet: sujet, source: Reference.localise(mouvement.source, langue),
                           precedentVisible: !Hitbodedut.estPremier(guideEtape),
                           suivantVisible: !Hitbodedut.estDernier(guideEtape))
    }

    public var libelleGuidePrecedent: Libelle { Libelle("hitbodedut_previous") }
    public var libelleGuideSuivant: Libelle { Libelle("hitbodedut_next") }

    /// La question en cours, pendant la séance ; nil : la carte est cachée.
    public var question: SeanceQuestion? {
        guard questionRang >= 0, enCours else { return nil }
        let total = QuestionsBlocage.questions.count
        let rang = min(questionRang, total - 1)
        return SeanceQuestion(rang: rang, texte: Libelle(QuestionsBlocage.questions[rang]),
                              position: Libelle("question_rang", .entier(rang + 1), .entier(total)),
                              progression: (rang + 1) * 100 / total)
    }

    public var libelleQuestionSuivante: Libelle { Libelle("question_suivante") }

    /// La lueur du souffle respire : pendant la séance, derrière un minuteur visible.
    public var souffleActif: Bool {
        enCours && Store.sessionCounter(reglages: magasin.reglages) != .masque && !masqueParConcentration
    }

    /// L'opacité de ce qui s'efface au calme (titre, scène, légende, musique, « Abandonner », sujet, carte de
    /// 'hizouk, « Je n'arrive pas à parler ») : 0 au calme, 1 sinon.
    public var opaciteEffacable: Double {
        calme ? 0 : 1
    }

    /// Garder l'écran allumé (FLAG_KEEP_SCREEN_ON, `isIdleTimerDisabled`) : tant que l'écran de séance est
    /// montré, comme Android.
    public var garderEcranAllume: Bool { true }

    // MARK: Les gestes

    /// Le bouton principal : « Terminer maintenant » demande confirmation ; « Commencer » lance la durée
    /// habituelle.
    public func principal() async throws {
        if enCours {
            dialogue = .terminer
            return
        }
        try await lancer(magasin.reglages.targetMinutes)
    }

    /// « Abandonner » demande confirmation.
    public func secondaire() {
        guard enCours else { return }
        dialogue = .abandonner
    }

    /// « Terminer maintenant » confirmé : le temps passé est inscrit s'il fait au moins une minute ; le bravo
    /// suit. La note est proposée par le bravo, après lui (revue du 29/09).
    public func confirmerTerminer() async throws {
        dialogue = nil
        var erreur: (any Error)? = nil
        do {
            try await seance.terminer()
        } catch {
            erreur = error
        }
        await actualiser()
        if let erreur { throw erreur }
    }

    /// « Abandonner » confirmé : rien n'est inscrit ; « ’Hazak » s'ouvre, sans danse.
    public func confirmerAbandonner() async throws {
        dialogue = nil
        abandon = true
        var erreur: (any Error)? = nil
        do {
            try await seance.abandonner()
        } catch {
            erreur = error
        }
        route = .celebration(CelebrationDemande.annulation)
        await actualiser()
        if let erreur { throw erreur }
    }

    /// Une durée proposée : elle lance la séance et devient la durée habituelle. Une écriture refusée de la durée
    /// n'empêche pas la séance de partir (Android l'écrit puis lance, quoi qu'il arrive) ; l'erreur est rendue après.
    public func commencer(minutes: Int) async throws {
        var erreur: (any Error)? = nil
        do {
            try await magasin.modifierReglages { $0.setTargetMinutes(minutes) }
        } catch {
            erreur = error
        }
        try await lancer(minutes)
        if let erreur { throw erreur }
    }

    /// « Durée réglable… » ouvre le champ.
    public func saisirDuree() {
        dialogue = .duree
    }

    /// « OK » du champ : un nombre, ramené entre 1 et 240, lance la séance et devient la durée habituelle ; autre
    /// chose ne fait rien.
    public func validerDuree(_ texte: String) async throws {
        dialogue = nil
        guard let minutes = DureeSeance.lire(texte) else { return }
        try await commencer(minutes: minutes)
    }

    /// « Sans durée » : la séance court jusqu'à ce qu'on l'arrête ; la durée habituelle ne bouge pas.
    public func commencerSansDuree() async throws {
        try await lancer(SessionRule.ouverte)
    }

    /// « Parler » : la séance part.
    public func simplementParler() async throws {
        try await lancer(magasin.reglages.targetMinutes)
    }

    /// « Écrire » : la séance part, et la note du jour s'ouvre.
    public func simplementEcrire() async throws {
        try await lancer(magasin.reglages.targetMinutes)
        route = .note(horloge.aujourdhui)
    }

    /// « Prier » : la séance part, et les prières s'ouvrent.
    public func simplementPrier() async throws {
        try await lancer(magasin.reglages.targetMinutes)
        route = .tefilot
    }

    /// « Une question » : la séance part, et la première question paraît.
    public func simplementQuestion() async throws {
        try await lancer(magasin.reglages.targetMinutes)
        questionRang = 0
    }

    /// « Je n'arrive pas à parler » : un texte du moment « blocage », et sous lui la première question si
    /// aucune n'est encore posée.
    public func bloque() async {
        await tirer(.blocage)
        if questionRang < 0 { questionRang = 0 }
    }

    /// « Question suivante » : après la dernière, on recommence.
    public func questionSuivante() {
        questionRang = QuestionsBlocage.suivante(questionRang)
        changementsQuestion += 1
    }

    public func guidePrecedent() {
        guideEtape = Hitbodedut.precedent(guideEtape)
    }

    public func guideSuivant() {
        guideEtape = Hitbodedut.suivant(guideEtape)
    }

    /// « Sujet : … » ouvre la liste.
    public func choisirSujet() {
        dialogue = .sujet
    }

    /// Un sujet touché dans la liste (nil : « Aucun ») ; il se change aussi pendant la séance.
    public func choisirSujet(_ theme: Theme?) async throws {
        dialogue = nil
        try await magasin.modifierReglages { SeanceSujet.poser(theme, dans: &$0) }
    }

    /// L'écran ouvert par-dessus s'est fermé.
    public func fermerRoute() {
        route = nil
    }

    // MARK: La pratique calme

    /// Un toucher, n'importe où (dispatchTouchEvent) : il réveille l'écran calme et repart pour six secondes.
    /// Rend vrai si ce geste réveille l'écran : il est alors avalé, sans toucher ce qu'il y avait dessous (on
    /// ne touche pas un bouton qu'on ne voyait pas).
    @discardableResult
    public func toucher() -> Bool {
        let avale = calme
        calme = false
        if calmeSuivi { derniereActivite = horloge.maintenant }
        return avale
    }

    /// VoiceOver s'allume ou s'éteint : allumé, l'écran calme revient et ne s'efface plus.
    public func lecteurEcranChange(_ actif: Bool) {
        lecteurEcran = actif
        if actif { calme = false }
    }

    private func suivreCalme(_ enCours: Bool) {
        let maintenant = horloge.maintenant
        if enCours != calmeSuivi {
            calmeSuivi = enCours
            derniereActivite = maintenant
            if !enCours { calme = false }
        }
        if enCours && !calme && !lecteurEcran && maintenant &- derniereActivite >= SeanceModele.delaiCalme {
            calme = true
        }
    }

    // MARK: Aides

    /// Lance une séance de `minutes` : le guide repart au premier temps, le mot d'ouverture est tiré.
    private func lancer(_ minutes: Int) async throws {
        var erreur: (any Error)? = nil
        do {
            try await seance.commencer(minutes: minutes)
        } catch {
            erreur = error
        }
        guideEtape = 0
        await tirer(.ouverture)
        await actualiser()
        if let erreur { throw erreur }
    }

    /// Tire un texte pour ce moment et le montre (ChizukCard.show) ; rien d'affichable : la carte se cache. Une
    /// écriture refusée laisse le sac en mémoire.
    private func tirer(_ moment: Moment) async {
        guard let chizuk else {
            carteId = nil
            return
        }
        var reglages = magasin.reglages
        let id = SeanceTirage.tirer(chizuk, moment: moment, debug: debug, reglages: &reglages, melange: melange)
        carteId = id
        carteMoment = moment
        tirages += 1
        do {
            try await magasin.modifierReglages { $0 = reglages }
        } catch {
            // Le sac reste en mémoire ; la prochaine écriture l'emportera.
        }
    }

    private var adresse: Adresse? {
        Adresse.parse(magasin.reglages.adresse)
    }

    private static func argument(_ titre: MusicLibrary.Titre) -> Libelle.Argument {
        switch titre {
        case .nom(let nom): .texte(nom)
        case .libelle(let libelle): .libelle(libelle)
        }
    }

    private static func deuxChiffres(_ n: Int64) -> String {
        n < 10 ? "0" + String(n) : String(n)
    }
}
