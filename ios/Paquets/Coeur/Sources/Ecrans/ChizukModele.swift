import Foundation
import Observation
import Coeur

// « J'ai besoin de 'hizouk » (ChizukActivity.kt, ChizukCard.kt, ChizukBag.kt) : un texte à la demande, hors
// séance. « Un autre » tire dans tout le vivier publiable (Moment.demande), sans remise ; « Garder » le met dans
// les textes gardés, sur l'appareil ; « Partager » le fait sortir de l'appareil, d'un geste de l'utilisateur.
//
// Le sac du tirage et les textes gardés vivent dans les réglages, sous les clés d'Android (`chizuk_bag_demande`,
// `chizuk_last_demande`, `chizuk_favoris`) : `ChizukSac` les lit et les écrit par `Store` de Coeur (Store.kt).

/// Où en est l'écran.
public enum ChizukEtat: Sendable, Equatable {
    case chargement
    case pret
    /// chizuk.json n'a pu être lu.
    case erreur
}

/// Les écrans qu'ouvre le 'hizouk.
public enum ChizukRoute: Sendable, Hashable {
    /// SessionActivity : « Commencer une hitbodedout ».
    case seance
}

/// La carte de 'hizouk remplie (view_chizuk.xml, `ChizukCard.bind`) : tout ce qu'elle montre, prêt à afficher.
public struct ChizukCarte: Sendable, Equatable {
    /// L'identifiant du texte.
    public let id: String
    /// L'illustration du moment (Poses.ofMoment), au féminin s'il le faut ; elle ne change pas d'un tirage à
    /// l'autre.
    public let image: String
    /// Le nom du moment, en tête de la carte : « J'ai besoin de 'hizouk » pour la demande.
    public let moment: Libelle
    /// Le badge « à relire » : un texte que la release refuserait (seulement en debug).
    public let aRelire: Bool
    /// Le premier texte : l'hébreu (sans nikkoud si l'édition ne le permet pas), ou la traduction seule si les
    /// langues de lecture n'ont pas l'hébreu.
    public let texte: String
    /// La langue du premier texte (« he », « fr », « en »).
    public let langueTexte: String
    /// Vrai pour l'hébreu : de droite à gauche, aligné au début ; faux : une traduction seule, de gauche à droite.
    public let texteDroiteAGauche: Bool
    /// Le second texte, sous le filet : la traduction ; nil quand il n'y en a qu'un (en hébreu, ou une langue seule).
    public let second: String?
    /// La source, dans la langue de l'app (Reference.localise).
    public let reference: String

    /// La carte d'un texte pour un moment, dans les langues de lecture `mode` et la langue de l'app `langue`.
    public init(item: ChizukItem, chizuk: Chizuk, moment: Moment, mode: LanguesTexte.Mode, langue: String,
                adresse: Adresse?) {
        let hebreu = ChizukRules.hebrew(chizuk, item)
        let textes = LanguesTexte.textes(mode, hebreu, item.fr.estBlanc ? nil : item.fr,
                                         item.en.estBlanc ? nil : item.en)
        let premier = textes.first ?? (langue: "he", texte: hebreu)
        id = item.id
        image = Personnage.pour(adresse, Poses.ofMoment(moment))
        self.moment = Libelle(ChizukCarte.libelle(moment))
        aRelire = ChizukRules.needsProofreading(item)
        texte = premier.texte
        langueTexte = premier.langue
        texteDroiteAGauche = premier.langue.egalUnites("he")
        let suivant = textes.count > 1 ? textes[1].texte : ""
        second = suivant.estBlanc ? nil : suivant
        reference = Reference.localise(item.ref, langue)
    }

    /// La clé du nom d'un moment (`Moment.labelRes`).
    public static func libelle(_ moment: Moment) -> String {
        switch moment {
        case .ouverture: return "moment_ouverture"
        case .blocage: return "moment_blocage"
        case .porte: return "moment_porte"
        case .relance: return "moment_relance"
        case .cloture: return "moment_cloture"
        case .lieu: return "moment_lieu"
        case .demande: return "chizuk_demande_title"
        }
    }
}

/// Un texte gardé, dans la liste sous les boutons.
public struct ChizukGarde: Sendable, Equatable, Identifiable {
    public let id: String
    /// La traduction de la langue de l'app, ou l'hébreu à défaut (en hébreu).
    public let texte: String
    /// La source, dans la langue de l'app.
    public let reference: String

    /// Ce que montre la ligne d'Android : le texte, un saut de ligne, la source ; trois lignes au plus.
    public var ligne: String {
        texte + "\n" + reference
    }
}

/// Le sac du tirage et les textes gardés, dans les réglages (Store.kt : chizukBag, chizukLast, setChizukBag,
/// chizukFavoris, basculerChizukFavori, portés dans `Store` de Coeur), et le tirage qui les relie
/// (`ChizukBag.draw`). Les autres écrans qui tirent un texte (ouverture, blocage, porte…) s'en servent de même.
public enum ChizukSac {

    /// Le sac d'un moment : les identifiants qui n'ont pas encore servi dans le cycle, un par ligne.
    public static func sac(_ reglages: Reglages, moment: Moment) -> [String] {
        Store.chizukBag(reglages: reglages, moment: moment)
    }

    /// Le dernier texte sorti pour ce moment ; nil s'il est blanc.
    public static func dernier(_ reglages: Reglages, moment: Moment) -> String? {
        Store.chizukLast(reglages: reglages, moment: moment)
    }

    /// Le sac tel qu'il reste, et le dernier sorti ; nil retire la clé (`putString(clé, null)`).
    public static func poser(_ reglages: inout Reglages, moment: Moment, sac: [String], dernier: String?) {
        Store.setChizukBag(reglages: &reglages, moment: moment, bag: sac, last: dernier)
    }

    /// Les textes gardés, le plus récent en tête.
    public static func favoris(_ reglages: Reglages) -> [String] {
        Store.chizukFavoris(reglages: reglages)
    }

    /// Retire le texte s'il est gardé, sinon le garde en tête.
    public static func basculerFavori(_ reglages: inout Reglages, id: String) {
        Store.basculerChizukFavori(reglages: &reglages, id: id)
    }

    /// `ChizukBag.draw` : tire un texte pour ce moment dans ce qu'il a le droit de montrer (ChizukRules), et
    /// enregistre le sac restant ; nil quand rien n'est affichable. `melange` mélange le vivier quand le sac est
    /// vide.
    public static func tirer(_ chizuk: Chizuk, moment: Moment, debug: Bool, reglages: inout Reglages,
                             melange: ([String]) -> [String]) -> String? {
        let vivier = ChizukRules.forMoment(chizuk, moment, debug: debug).map { $0.id }
        let tirage = ChizukBag.next(remaining: sac(reglages, moment: moment), pool: vivier,
                                    last: dernier(reglages, moment: moment), shuffle: melange)
        poser(&reglages, moment: moment, sac: tirage.remaining, dernier: tirage.id)
        return tirage.id
    }
}

/// L'écran « J'ai besoin de 'hizouk ».
@MainActor
@Observable
public final class ChizukModele {

    /// Le moment de cet écran : la demande, qui tire dans tout le publiable.
    public static let moment = Moment.demande
    /// Le site, que le partage nomme (CelebrationActivity.LIEN_WEB).
    public static let lienWeb = "https://hil123.github.io/myhitbodedut-web/"

    private let magasin: Magasin
    private let contenus: ContenusApp
    /// « fr », « en » ou « he ».
    public let langue: String
    /// Vrai en debug (`BuildConfig.DEBUG`) : les textes non relus passent aussi, avec leur badge.
    public let debug: Bool
    private let melange: @Sendable ([String]) -> [String]

    public private(set) var etat: ChizukEtat = .chargement
    /// Le texte sur la carte ; nil quand rien n'est affichable. À garder pour le rendre au retour
    /// (`onSaveInstanceState`, `@SceneStorage` dans la vue) et à repasser à `charger(restaurer:)`.
    public private(set) var courantId: String? = nil
    /// Monte à chaque fois que la carte change sous le doigt (« Un autre », un texte gardé touché) : la vue
    /// fond la carte et remonte en haut.
    public private(set) var changements = 0
    private var chizuk: Chizuk? = nil
    private var lance = false

    /// `melange` : le mélange du vivier quand le sac se remplit ; un mélange fixe dans les tests.
    public init(magasin: Magasin, contenus: ContenusApp, langue: String, debug: Bool,
                melange: @escaping @Sendable ([String]) -> [String] = { $0.shuffled() }) {
        self.magasin = magasin
        self.contenus = contenus
        self.langue = ChizukCard.language(langue)
        self.debug = debug
        self.melange = melange
    }

    /// Lit les textes et montre la carte : le texte `restaurer` s'il existe encore (l'écran recréé), sans
    /// tirer ; sinon un tirage. Une fois seulement : rouvrir la vue ne tire pas un autre texte. Une écriture
    /// refusée n'empêche pas la carte ; le sac reste en mémoire, la prochaine écriture l'emportera.
    public func charger(restaurer id: String? = nil) async {
        guard !lance else { return }
        lance = true
        let lu: Chizuk
        do {
            lu = try await contenus.chizuk()
        } catch {
            lance = false
            etat = .erreur
            return
        }
        chizuk = lu
        etat = .pret
        if let id, lu.item(id) != nil {
            courantId = id
            return
        }
        do {
            try await tirer()
        } catch {
            // Le texte tiré est montré quand même (tirer) ; rien d'autre à faire.
        }
    }

    // MARK: Le bandeau

    public var titre: Libelle { Libelle("chizuk_demande_title") }
    public var sousTitre: Libelle { Libelle("chizuk_demande_hint") }

    /// Les bras ouverts (char_open_arms), au féminin s'il le faut.
    public var image: String {
        Personnage.pour(adresse, "char_open_arms")
    }

    // MARK: La carte

    /// La carte du texte courant ; nil : la carte est cachée (rien d'affichable, ou pas encore lu).
    public var carte: ChizukCarte? {
        guard let chizuk, let id = courantId, let item = chizuk.item(id) else { return nil }
        return ChizukCarte(item: item, chizuk: chizuk, moment: ChizukModele.moment, mode: modeLangues,
                           langue: langue, adresse: adresse)
    }

    /// Les langues de lecture : le choix enregistré, sinon celles de la langue de l'app.
    public var modeLangues: LanguesTexte.Mode {
        BibliothequeLecture.mode(magasin.reglages, langue: langue)
    }

    // MARK: Les boutons

    /// « Garder » et « Partager » ne servent que s'il y a un texte sur la carte.
    public var actionsActives: Bool {
        carte != nil
    }

    /// Le texte courant est-il gardé ?
    public var garde: Bool {
        guard let id = courantId else { return false }
        return ChizukSac.favoris(magasin.reglages).contains { $0.egalUnites(id) }
    }

    /// « Gardé ✓ » ou « Garder ».
    public var libelleGarder: Libelle {
        Libelle(garde ? "chizuk_garde" : "chizuk_garder")
    }

    public var libelleAutre: Libelle { Libelle("chizuk_autre") }
    /// Aussi le titre de la feuille de partage.
    public var libellePartager: Libelle { Libelle("chizuk_partager") }
    public var libelleCommencer: Libelle { Libelle("chizuk_commencer") }
    /// « Commencer une hitbodedout » ouvre la séance.
    public var routeCommencer: ChizukRoute { .seance }

    /// « Un autre » : un nouveau tirage dans le sac, jamais le texte qui vient de sortir (ChizukBag). Une
    /// écriture refusée rend son erreur, le texte tiré est montré quand même.
    public func unAutre() async throws {
        guard chizuk != nil else { return }
        defer { changements += 1 }
        try await tirer()
    }

    /// « Garder » : garde le texte courant en tête des textes gardés, ou le retire s'il y est.
    public func garder() async throws {
        guard actionsActives, let id = courantId else { return }
        try await magasin.modifierReglages { ChizukSac.basculerFavori(&$0, id: id) }
    }

    // MARK: Les textes gardés

    /// « Textes gardés » ; la vue le montre en capitales.
    public var titreGardes: Libelle { Libelle("chizuk_favoris") }

    /// Les textes gardés qui existent encore, le plus récent en tête ; vide : le titre et la liste sont cachés.
    public var gardes: [ChizukGarde] {
        guard let chizuk else { return [] }
        return ChizukSac.favoris(magasin.reglages).compactMap { (id: String) -> ChizukGarde? in
            guard let item = chizuk.item(id) else { return nil }
            let traduction = ChizukCard.translationOf(item, langue)
            let texte = traduction.estBlanc ? ChizukRules.hebrew(chizuk, item) : traduction
            return ChizukGarde(id: item.id, texte: texte, reference: Reference.localise(item.ref, langue))
        }
    }

    /// Toucher un texte gardé le remet sur la carte, sans rien tirer.
    public func montrer(_ id: String) {
        guard chizuk?.item(id) != nil else { return }
        courantId = id
        changements += 1
    }

    // MARK: Le partage

    /// « Essayez, vous aussi, gratuitement : <lien> », la dernière ligne du texte partagé.
    public var lienPartage: Libelle {
        Libelle("partage_lien", .texte(ChizukModele.lienWeb))
    }

    /// Le texte que la feuille de partage envoie (ChizukPartage) : l'hébreu, la traduction de la langue de l'app
    /// s'il y en a une, « — » et la source, puis la ligne du lien, que `resoudre` met dans la langue de l'app
    /// (`Traducteur.texte`). nil sans texte sur la carte.
    public func textePartage(_ resoudre: (Libelle) -> String) -> String? {
        guard let chizuk, let id = courantId, let item = chizuk.item(id) else { return nil }
        return ChizukPartage.texte(ChizukRules.hebrew(chizuk, item), ChizukCard.translationOf(item, langue),
                                   Reference.localise(item.ref, langue), resoudre(lienPartage))
    }

    // MARK: Le tirage

    /// Tire et enregistre le sac. Si l'écriture échoue, le changement reste en mémoire : le texte tiré est le
    /// dernier sorti qu'elle garde, et il est montré avant que l'erreur remonte.
    private func tirer() async throws {
        guard let chizuk else { return }
        let moment = ChizukModele.moment
        let debug = self.debug
        let melange = self.melange
        let tire: String?
        do {
            tire = try await magasin.modifierReglages { reglages in
                ChizukSac.tirer(chizuk, moment: moment, debug: debug, reglages: &reglages, melange: melange)
            }
        } catch {
            courantId = ChizukSac.dernier(magasin.reglages, moment: moment)
            throw error
        }
        courantId = tire
    }

    private var adresse: Adresse? {
        Adresse.parse(magasin.reglages.adresse)
    }
}
