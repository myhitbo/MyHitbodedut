import Foundation
import Observation
import Coeur

// La lecture des Tehilim (TehilimLectureActivity.kt, activity_tehilim_lecture.xml) : un psaume, ou une portion d'un
// seul trait. Chaque verset porte son numéro en lettres, petit et discret. Un psaume seul a deux boutons, précédent
// et suivant ; une portion n'en a aucun. Un appui long sur un verset le marque ou le démarque (28/10) ; ouvert
// depuis un marque-page (MARQUE_VERSET), le verset marqué vient en haut de l'écran.
//
// Les langues de lecture (04/11) : l'hébreu seul garde un bloc par psaume, d'un seul tenant ; avec une traduction,
// chaque verset a son bloc, l'hébreu et la traduction l'un sous l'autre. Le bouton de lecture (`barre`) règle la
// taille, la nuit, la police et les langues ; le texte se refait de lui-même (propriétés calculées sur le `Magasin`).
//
// Pas d'image pendant une prière (13/10) : le modèle n'en rend aucune.

/// Une traduction d'un verset, dans l'ordre des langues choisies.
public struct TehilimTraduction: Sendable, Equatable, Identifiable {
    /// « fr » ou « en ».
    public let langue: String
    public let texte: String

    public var id: String { langue }
}

/// Un verset affiché.
public struct TehilimVerset: Sendable, Equatable, Identifiable {
    /// « v:<psaume>:<verset> » : unique dans la lecture, cible des défilements.
    public let id: String
    public let psaume: Int
    public let verset: Int
    /// Le numéro du verset en lettres (« ג׳ »), devant l'hébreu : 70 % de la taille du texte, couleur discrète,
    /// ou celle des titres si le verset est marqué.
    public let numero: String
    /// L'hébreu, ses signes absents de la police masqués ; nil quand les langues choisies l'écartent.
    public let hebreu: String?
    /// Sans l'hébreu, le numéro en chiffres (« 3 ») devant la première traduction (75 % de sa taille, discret ou
    /// couleur des titres si marqué) ; nil avec l'hébreu.
    public let numeroLatin: String?
    /// Les traductions, dans l'ordre des langues choisies ; vide en hébreu seul.
    public let traductions: [TehilimTraduction]
    /// Un marque-page est posé sur ce verset.
    public let marque: Bool
}

/// Un psaume affiché : son titre, puis ses versets.
public struct TehilimPsaume: Sendable, Equatable, Identifiable {
    /// « p:<psaume> ».
    public let id: String
    public let numero: Int
    /// « תהילים כ״ה », en toutes langues (`tikkun_psalm_he`).
    public let titre: Libelle
    /// Le premier psaume de la lecture : pas de marge au-dessus de son titre (24 pt pour les suivants).
    public let premier: Bool
    public let versets: [TehilimVerset]
}

/// Une demande de défilement : aller à l'élément `cible` (son id), en haut de l'écran à 8 points près ; nil, tout
/// en haut. `jeton` change à chaque demande, pour qu'une même cible demandée deux fois se rejoigne deux fois.
public struct TehilimDefilement: Sendable, Equatable {
    public let cible: String?
    public let jeton: Int
}

/// La lecture d'un psaume ou d'une portion.
@MainActor
@Observable
public final class TehilimLectureModele {

    /// La clé des marque-pages des Tehilim (TehilimLectureActivity.CLE) : le psaume en section, le verset en bloc.
    public static let cleMarques = "t:tehilim"

    private let magasin: Magasin
    private let contenus: ContenusApp
    /// « fr », « en » ou « he ».
    public let langue: String
    /// Le bouton de lecture : taille des lettres, lecture de nuit, police, langues (pas de nusah ici).
    public let barre: TehilimBarreLecture

    public private(set) var etat: TehilimEtat = .chargement
    /// Ce qu'on lit : la portion reçue, puis le psaume voisin choisi par précédent ou suivant.
    public private(set) var portion: Portion
    private var livre: Tehilim?
    /// MARQUE_VERSET : le verset où se placer à l'ouverture ; 0 sans marque-page.
    private let marqueVerset: Int

    /// La dernière demande de défilement ; la vue la suit (`onChange`).
    public private(set) var defilement: TehilimDefilement?
    private var jeton = 0
    /// L'élément en haut de l'écran, que la vue signale : on y revient quand la taille ou les langues changent.
    @ObservationIgnored private var tete: String?
    /// Un message bref (le Toast d'Android) : « Marque-page posé », « Marque-page retiré ». La vue l'efface.
    public private(set) var message: Libelle?

    public init(magasin: Magasin, contenus: ContenusApp, langue: String, cible: TehilimLectureCible) {
        self.magasin = magasin
        self.contenus = contenus
        self.langue = ChizukCard.language(langue)
        barre = TehilimBarreLecture(magasin: magasin, langue: langue)
        portion = cible.portion
        marqueVerset = cible.marqueVerset
        barre.surChangement = { [weak self] in
            self?.garderPlace()
        }
    }

    /// Lit le livre, puis se place au verset du marque-page s'il y en a un. À appeler à l'apparition de l'écran.
    public func charger() async {
        do {
            livre = try await contenus.tehilim()
            etat = .pret
        } catch {
            etat = .erreur
            return
        }
        if marqueVerset > 0 {
            allerAuVerset(psaume: portion.debut, verset: marqueVerset)
        }
    }

    // MARK: Le bandeau

    /// « Tehilim 25 », « Tehilim 1 à 9 », « Tehilim 119, versets 1 à 96 ».
    public var titre: Libelle {
        TehilimTexte.portion(portion, langue: langue)
    }

    /// Le nombre de versets lus.
    public var nombreVersets: Int {
        guard let livre else { return 0 }
        var total = 0
        for n in portion.psaumes {
            total += portion.versets(n, livre.versets(n).count).nombre
        }
        return total
    }

    /// « 22 versets » ; nil tant que le livre n'est pas lu.
    public var sousTitre: Libelle? {
        guard livre != nil else { return nil }
        let n = nombreVersets
        return Libelle.pluriel("tehilim_verses", quantite: n, .entier(n))
    }

    // MARK: Le texte

    /// L'hébreu seul : un bloc par psaume, les versets à la suite (une demi-ligne entre deux) ; sinon un bloc par
    /// verset, l'hébreu et ses traductions l'un sous l'autre.
    public var hebreuSeul: Bool {
        barre.langues == .he
    }

    /// Les psaumes de la portion, chacun avec ses versets à lire ; vide tant que rien n'est lu.
    public var psaumes: [TehilimPsaume] {
        guard let livre else { return [] }
        let mode = barre.langues
        let police = barre.police
        var marques = Set<String>()
        for m in MarquesPages.duTexte(TehilimMarques.toutes(magasin.reglages), cle: TehilimLectureModele.cleMarques,
                                      nusah: "") {
            marques.insert(TehilimLectureModele.idVerset(m.section, m.bloc))
        }
        var resultat: [TehilimPsaume] = []
        var premier = true
        for n in portion.psaumes {
            let tous = livre.versets(n)
            var versets: [TehilimVerset] = []
            for v in portion.versets(n, tous.count) {
                guard v >= 1, v <= tous.count else { continue }
                let texte = tous[v - 1]
                let id = TehilimLectureModele.idVerset(n, v)
                let marque = marques.contains(id)
                if mode == .he {
                    versets.append(TehilimVerset(id: id, psaume: n, verset: v, numero: Reference.lettres(v),
                                                 hebreu: PoliceHebraique.masque(texte, police: police),
                                                 numeroLatin: nil, traductions: [], marque: marque))
                    continue
                }
                let textes = LanguesTexte.textes(mode, texte, livre.traduction("fr", n, v), livre.traduction("en", n, v))
                var hebreu: String?
                var traductions: [TehilimTraduction] = []
                for t in textes {
                    if t.langue.egalUnites("he") {
                        hebreu = PoliceHebraique.masque(t.texte, police: police)
                    } else {
                        traductions.append(TehilimTraduction(langue: t.langue, texte: t.texte))
                    }
                }
                versets.append(TehilimVerset(id: id, psaume: n, verset: v, numero: Reference.lettres(v), hebreu: hebreu,
                                             numeroLatin: hebreu == nil ? String(v) : nil, traductions: traductions,
                                             marque: marque))
            }
            resultat.append(TehilimPsaume(id: "p:" + String(n), numero: n,
                                          titre: Libelle("tikkun_psalm_he", .texte(Reference.lettres(n))),
                                          premier: premier, versets: versets))
            premier = false
        }
        return resultat
    }

    static func idVerset(_ psaume: Int, _ verset: Int) -> String {
        "v:" + String(psaume) + ":" + String(verset)
    }

    // MARK: Précédent, suivant

    /// Un psaume seul se lit de proche en proche ; une portion d'un trait, sans bouton.
    public var navigationVisible: Bool {
        portion.debut == portion.fin && !portion.partielle
    }

    /// « Psaume précédent » se voit dès le psaume 2 ; au psaume 1, sa place reste vide (INVISIBLE).
    public var precedentVisible: Bool {
        portion.debut > 1
    }

    /// « Psaume suivant » se voit jusqu'au psaume 149 ; au psaume 150, sa place reste vide.
    public var suivantVisible: Bool {
        portion.debut < Tehilim.nombreDePsaumes
    }

    /// Le psaume d'avant, lu depuis le haut.
    public func precedent() {
        guard navigationVisible, precedentVisible else { return }
        afficher(Portion(portion.debut - 1, portion.debut - 1))
    }

    /// Le psaume d'après, lu depuis le haut.
    public func suivant() {
        guard navigationVisible, suivantVisible else { return }
        afficher(Portion(portion.debut + 1, portion.debut + 1))
    }

    private func afficher(_ p: Portion) {
        portion = p
        tete = nil
        demander(nil)
    }

    // MARK: Les marque-pages

    /// Un appui long sur un verset : le marque, ou le démarque s'il l'était ; un message bref le dit. Rend vrai si
    /// le verset est maintenant marqué. La place reste. Hors du livre, rien.
    @discardableResult
    public func basculerMarque(psaume n: Int, verset v: Int) async throws -> Bool {
        guard let livre else { return false }
        let tous = livre.versets(n)
        guard v >= 1, v <= tous.count else { return false }
        let apercu = Reference.lettres(n) + ", " + Reference.lettres(v) + " · " + MarquesPages.apercu(tous[v - 1], mots: 5)
        let marque = MarquesPages.Marque(cle: TehilimLectureModele.cleMarques, nusah: "", section: n, bloc: v,
                                         apercu: apercu)
        let pose = !TehilimMarques.toutes(magasin.reglages).contains { $0.memePlace(marque) }
        message = Libelle(pose ? "marque_posee" : "marque_retiree")
        try await magasin.modifierReglages { TehilimMarques.basculer(&$0, marque) }
        return pose
    }

    /// Le message bref s'est effacé.
    public func finMessage() {
        message = nil
    }

    // MARK: Le défilement

    /// La vue signale l'élément en haut de l'écran (un titre de psaume ou un verset).
    public func teteVisible(_ id: String) {
        tete = id
    }

    /// Le verset `verset` du psaume `psaume` en haut de l'écran, s'il est affiché.
    public func allerAuVerset(psaume: Int, verset: Int) {
        let id = TehilimLectureModele.idVerset(psaume, verset)
        for p in psaumes where p.numero == psaume {
            if p.versets.contains(where: { $0.id == id }) {
                demander(id)
            }
            return
        }
    }

    /// La taille, la nuit, la police ou les langues ont changé : l'élément de tête reste en tête.
    private func garderPlace() {
        guard let tete else { return }
        demander(tete)
    }

    private func demander(_ cible: String?) {
        jeton += 1
        defilement = TehilimDefilement(cible: cible, jeton: jeton)
    }
}
