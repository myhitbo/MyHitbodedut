import Foundation
import Observation
import Coeur

// L'écran Tfilot (TefilotActivity.kt, sur la mise en page de la bibliothèque, activity_library.xml) : les dix
// sujets, et sous chacun ses prières de Likoutei Tefilot. L'écran ne contient aucun texte : il lit la sous-section
// « tefilot-lt » de la bibliothèque (TefilotRules) et ouvre l'entrée choisie dans l'écran qui sait déjà afficher
// une source (LibraryEntryActivity, EXTRA_ID), qui applique la règle de vocalisation.

/// Les écrans qu'ouvre l'écran Tfilot, pour `navigationDestination(for:)`.
public enum TefilotRoute: Sendable, Hashable {
    /// LibraryEntryActivity, `EXTRA_ID` : l'identifiant de l'entrée de la bibliothèque.
    case entree(String)
}

/// Une ligne de la liste : le titre d'un sujet, ou une prière sous ce sujet.
public struct TefilotLigne: Sendable, Equatable, Identifiable {

    public enum Sorte: Sendable, Equatable {
        /// Le titre d'un sujet (item_tefila_sujet) : on ne le touche pas.
        case sujet
        /// Une prière (item_library_entry) : une carte qu'on touche.
        case priere
    }

    /// « sujet:<clé> » ou « priere:<id> » : unique dans la liste.
    public let id: String
    public let sorte: Sorte
    /// Le sujet : son nom (`tefila_…`) au titre d'un sujet, en pastille sur une prière.
    public let sujet: Libelle
    /// « 3 prières », sous le titre d'un sujet ; nil pour une prière.
    public let compte: Libelle?
    /// Le titre hébreu de la prière ; nil pour un sujet.
    public let titre: String?
    /// La référence de la prière dans la langue de l'app (« Likoutei Tefilot I, 52 », « ליקוטי תפילות א, נ״ב ») ;
    /// nil pour un sujet.
    public let reference: String?
    /// La mise en garde, sur la ligne d'après la référence, quand la leçon citée traite d'un autre sujet ; nil sinon.
    public let avertissement: Libelle?
    /// L'illustration de la carte (`Character.ofLibraryEntry` : char_torah pour une source, au féminin s'il le faut) ;
    /// nil pour un sujet.
    public let image: String?
    /// Ce qu'ouvre la carte ; nil pour un sujet.
    public let route: TefilotRoute?
}

/// L'écran Tfilot.
@MainActor
@Observable
public final class TefilotModele {
    private let magasin: Magasin
    private let contenus: ContenusApp
    /// « fr », « en » ou « he ».
    public let langue: String

    public private(set) var etat: TehilimEtat = .chargement
    private var bibliotheque: Bibliotheque? = nil

    public init(magasin: Magasin, contenus: ContenusApp, langue: String) {
        self.magasin = magasin
        self.contenus = contenus
        self.langue = ChizukCard.language(langue)
    }

    /// Lit la bibliothèque. À appeler à l'apparition de l'écran ; une seconde lecture ne coûte rien.
    public func charger() async {
        do {
            bibliotheque = try await contenus.bibliotheque()
            etat = .pret
        } catch {
            etat = .erreur
        }
    }

    // MARK: Le bandeau

    /// « Tefilot ».
    public var titre: Libelle {
        Libelle("tefilot_title")
    }

    /// « Dix sujets, vingt-et-une prières. Rabbi Natan de Breslev. »
    public var sousTitre: Libelle {
        Libelle("tefilot_hint")
    }

    /// Le personnage qui étudie (Character.STUDY), au féminin pour qui a choisi צדקת.
    public var image: String {
        Personnage.pour(adresse, Poses.study)
    }

    // MARK: La liste

    /// Sujet par sujet, dans l'ordre de `SujetTefila` : le titre et le nombre de prières, puis chaque prière dans
    /// l'ordre du fichier. Un sujet sans prière n'a aucune ligne. Vide tant que rien n'est lu.
    public var lignes: [TefilotLigne] {
        guard let bibliotheque else { return [] }
        let adresse = self.adresse
        var resultat: [TefilotLigne] = []
        for ligne in TefilotRules.lignes(bibliotheque) {
            switch ligne {
            case .titre(let sujet, let nombre):
                resultat.append(TefilotLigne(id: "sujet:" + sujet.cle, sorte: .sujet, sujet: Libelle(sujet.titre),
                                             compte: Libelle("tefilot_count", .entier(nombre)), titre: nil,
                                             reference: nil, avertissement: nil, image: nil, route: nil))
            case .priere(let sujet, let entree):
                resultat.append(TefilotLigne(
                    id: "priere:" + entree.id, sorte: .priere, sujet: Libelle(sujet.titre), compte: nil,
                    titre: entree.titreHe, reference: Reference.localise(entree.ref, langue),
                    avertissement: TefilotRules.prevenir(entree) ? Libelle("tefilot_warning") : nil,
                    image: Personnage.pour(adresse, Poses.ofLibraryEntry(.source(entree))), route: .entree(entree.id)))
            }
        }
        return resultat
    }

    private var adresse: Adresse? {
        Adresse.parse(magasin.reglages.adresse)
    }
}
