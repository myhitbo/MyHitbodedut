import Foundation
import Observation
import Coeur

// La recherche dans toute l'application (RechercheActivity.kt, 14/10) : un champ, la portée (19/10), les
// résultats par sorte (siddour, livres, halakha, hilloulot) ; chacun ouvre son écran. La recherche tourne hors du
// fil de l'interface : chaque frappe annule la précédente, et seule la dernière demandée s'affiche.
//
// Android relit tout le corpus à chaque recherche, après 300 ms d'attente ; ici l'index (RechercheIndex.swift) se
// prépare une fois, et une recherche y prend quelques millisecondes : l'attente n'a plus lieu d'être (`delai`
// la rétablit au besoin). La langue est celle de l'app (`Traducteur.langue`), celle des titres traduits et des
// noms des hilloulot ; le siddour est celui du noussa'h des réglages, lu à chaque recherche.

// MARK: L'index partagé

/// L'index de la recherche globale, préparé une fois pour l'app : la vue de la recherche peut s'ouvrir et se
/// fermer sans le refaire. Un autre noussa'h choisi, seul le siddour se réindexe (`RechercheIndex.avec`).
/// Une préparation en cours sert toutes les demandes du même noussa'h.
public actor RecherchePreparateur {

    private let contenus: ContenusApp
    private let hilloulot: HilloulotContenus
    /// « fr », « en » ou « he » : celle des titres traduits.
    public let langue: String

    private var pret: RechercheIndex?
    private var tache: Task<RechercheIndex?, Never>?
    private var tacheNusah: Nusah?

    public init(contenus: ContenusApp, hilloulot: HilloulotContenus, langue: String) {
        self.contenus = contenus
        self.hilloulot = hilloulot
        self.langue = langue
    }

    /// L'index sur le siddour de ce noussa'h, préparé hors du fil principal à la première demande (des secondes
    /// sur un téléphone ancien) ; nil si le siddour n'a pu être lu (la recherche ne trouve rien, comme
    /// `runCatching { … }.getOrDefault(emptyList())` d'Android), et une prochaine demande réessaie.
    public func index(_ nusah: Nusah) async -> RechercheIndex? {
        if let pret, pret.nusah == nusah { return pret }
        if let tache, tacheNusah == nusah { return await tache.value }
        let precedent = pret
        let contenus = self.contenus
        let hilloulot = self.hilloulot
        let langue = self.langue
        let nouvelle = Task.detached(priority: .userInitiated) { () async -> RechercheIndex? in
            if let precedent {
                guard let siddur = try? await contenus.siddur(nusah) else { return nil }
                return precedent.avec(siddur: siddur, nusah: nusah)
            }
            guard let sources = await RechercheSources.charger(contenus: contenus, hilloulot: hilloulot,
                                                               nusah: nusah) else { return nil }
            return RechercheIndex(sources, langue: langue)
        }
        tache = nouvelle
        tacheNusah = nusah
        let index = await nouvelle.value
        if tacheNusah == nusah {
            tache = nil
            tacheNusah = nil
            if let index { pret = index }
        }
        return index
    }
}

// MARK: Ce que l'écran montre

/// Où en est l'index.
public enum RechercheEtat: Sendable, Equatable {
    /// L'index se prépare : le champ s'utilise déjà, la première recherche l'attendra.
    case preparation
    case pret
    /// Le siddour n'a pu être lu : aucune recherche ne trouve rien.
    case erreur
}

/// Les écrans qu'ouvre un résultat (RechercheActivity.ligne), pour `NavigationLink(value:)` et
/// `navigationDestination(for:)`.
public enum RechercheRoute: Sendable, Hashable {
    /// `SiddurLectureActivity.ouvrir(id)` : le lecteur du siddour, sur ce texte (du noussa'h des réglages).
    case siddour(String)
    /// `SiddurLectureActivity.ouvrirLivre(id)` : le lecteur, sur un livre entier (`LIVRE` vrai).
    case livre(String)
    /// HalakhaActivity, `EXTRA_RECHERCHE` : l'écran de la halakha, son champ rempli de la recherche telle que
    /// tapée (`HalakhaModele(… recherche:)`).
    case halakha(recherche: String)
    /// HilloulotActivity, `EXTRA_RECHERCHE` : l'écran des hilloulot, son champ rempli de la recherche
    /// (`HilloulotModele(… recherche:)`).
    case hilloulot(recherche: String)
}

/// Une puce de la portée (19/10) : un seul choix, toujours un.
public struct RecherchePortee: Sendable, Equatable, Identifiable {
    public var id: String { portee.rawValue }
    public let portee: RechercheGlobale.Portee
    /// « Tout », « Prières », « Halakhot », « Livres », « Hilloulot ».
    public let libelle: Libelle
    public let choisie: Bool
}

/// Un résultat : une carte qu'on touche.
public struct RechercheLigne: Sendable, Equatable, Identifiable {
    /// « SIDDOUR#0 » : unique dans la liste.
    public let id: String
    /// Le titre hébreu du texte, la source d'une halakha, ou le nom d'un tsadik : 16 sp, gras, encre, police
    /// hébraïque, sens d'après son premier caractère fort.
    public let titre: String
    /// La traduction du titre, l'extrait autour de la trouvaille, ou l'hébreu et l'année d'un tsadik : 13 sp,
    /// atténué, deux lignes au plus ; nil s'il est blanc.
    public let extrait: String?
    public let route: RechercheRoute
}

/// Les résultats d'une sorte, sous son titre (13 sp, gras, couleur de marque).
public struct RechercheGroupe: Sendable, Equatable, Identifiable {
    public var id: String { sorte.rawValue }
    public let sorte: RechercheGlobale.Sorte
    /// Les noms des filtres (audit 1.390) : « Prières », « Livres », « Halakhot », « Hilloulot ».
    public let titre: Libelle
    public let lignes: [RechercheLigne]
}

/// Ce que montre la liste sous la portée.
public struct RechercheResultats: Sendable, Equatable {
    /// Le texte cherché, tel que tapé.
    public let texte: String
    /// « Résultats : 47 », même à zéro.
    public let nombre: Libelle
    /// Dans l'ordre des sortes (siddour, livres, halakha, hilloulot), sans les sortes vides.
    public let groupes: [RechercheGroupe]
}

/// Une recherche finie.
private struct RechercheTrouves: Sendable {
    let texte: String
    let resultats: [RechercheGlobale.Resultat]
}

// MARK: Le modèle

/// L'écran de la recherche globale. Il s'ouvre sans paramètre.
@MainActor
@Observable
public final class RechercheModele {

    private let magasin: Magasin
    private let preparateur: RecherchePreparateur
    /// L'attente après une frappe avant de chercher (300 ms sur Android) ; zéro par défaut, l'index étant prompt.
    private let delai: Duration

    /// Le texte du champ.
    public private(set) var texte = ""
    /// Où chercher : tout, par défaut.
    public private(set) var portee: RechercheGlobale.Portee = .tout
    public private(set) var etat: RechercheEtat = .preparation
    /// Une recherche tourne : la vue peut montrer une discrète roue (Android ne montre rien).
    public private(set) var enCours = false

    /// La dernière recherche finie, montrée jusqu'à ce que la suivante finisse.
    private var trouves: RechercheTrouves?

    @ObservationIgnored private var tacheRecherche: Task<Void, Never>?
    @ObservationIgnored private var demande = 0

    public init(magasin: Magasin, preparateur: RecherchePreparateur, delai: Duration = .zero) {
        self.magasin = magasin
        self.preparateur = preparateur
        self.delai = delai
    }

    /// Un préparateur à soi (les tests, les aperçus) : l'app partage le sien entre les ouvertures de l'écran.
    public convenience init(magasin: Magasin, contenus: ContenusApp, hilloulot: HilloulotContenus, langue: String) {
        self.init(magasin: magasin, preparateur: RecherchePreparateur(contenus: contenus, hilloulot: hilloulot,
                                                                      langue: langue))
    }

    // MARK: Ce qui s'affiche

    /// « Rechercher dans le siddour, les livres, la halakha, les hilloulot » : l'indice du champ, qui a le focus
    /// à l'ouverture.
    public var indice: Libelle {
        Libelle("recherche_indice")
    }

    /// La police hébraïque des réglages de lecture, celle du titre de chaque résultat (PoliceHebraique.appliquer).
    public var police: PoliceHebraique.Police {
        PoliceHebraique.Police(rawValue: magasin.reglages.lecturePolice) ?? .serif
    }

    /// Les cinq puces, dans l'ordre de RechercheGlobale.Portee.
    public var portees: [RecherchePortee] {
        let choisie = portee
        return RechercheGlobale.Portee.allCases.map {
            RecherchePortee(portee: $0, libelle: Libelle(RechercheModele.cle($0)), choisie: $0 == choisie)
        }
    }

    /// nil tant que le texte a moins de deux unités une fois rogné (`texte.trim().length < 2` : la liste est
    /// vide), ou qu'aucune recherche n'a encore fini.
    public var resultats: RechercheResultats? {
        guard let trouves, RechercheModele.assezLong(trouves.texte) else { return nil }
        let police = self.police
        var groupes: [RechercheGroupe] = []
        for sorte in RechercheGlobale.Sorte.allCases {
            var lignes: [RechercheLigne] = []
            for (i, r) in trouves.resultats.enumerated() where r.sorte == sorte {
                // Le titre, en police hébraïque : ses signes absents masqués, comme PoliceHebraique.appliquer.
                lignes.append(RechercheLigne(id: "\(sorte.rawValue)#\(i)", titre: PoliceHebraique.masque(r.titre, police: police),
                                             extrait: r.extrait.estBlanc ? nil : r.extrait,
                                             route: RechercheModele.route(r)))
            }
            if !lignes.isEmpty {
                groupes.append(RechercheGroupe(sorte: sorte, titre: Libelle(RechercheModele.cle(sorte)), lignes: lignes))
            }
        }
        return RechercheResultats(texte: trouves.texte,
                                  nombre: Libelle("hilloulot_resultats", .entier(trouves.resultats.count)),
                                  groupes: groupes)
    }

    /// Ce qu'ouvre un résultat.
    public nonisolated static func route(_ r: RechercheGlobale.Resultat) -> RechercheRoute {
        switch r.sorte {
        case .siddour: .siddour(r.id)
        case .livre: .livre(r.id)
        case .halakha: .halakha(recherche: r.id)
        case .hilloula: .hilloulot(recherche: r.id)
        }
    }

    /// Le libellé d'une puce de portée.
    public nonisolated static func cle(_ portee: RechercheGlobale.Portee) -> String {
        switch portee {
        case .tout: "recherche_tout"
        case .tefilot: "recherche_tefilot"
        case .halakhot: "recherche_halakhot"
        case .sefarim: "recherche_sefarim"
        case .hilloulot: "hilloulot_title"
        }
    }

    /// Le titre d'un groupe de résultats.
    public nonisolated static func cle(_ sorte: RechercheGlobale.Sorte) -> String {
        switch sorte {
        case .siddour: "recherche_tefilot"
        case .livre: "recherche_livres"
        case .halakha: "recherche_halakhot"
        case .hilloula: "hilloulot_title"
        }
    }

    private nonisolated static func assezLong(_ texte: String) -> Bool {
        texte.rogne.utf16.count >= 2
    }

    // MARK: Les actions

    /// Prépare l'index du noussa'h des réglages ; rend la main quand il est prêt. Le champ s'utilise avant.
    public func charger() async {
        let index = await preparateur.index(magasin.reglages.siddurNusah)
        etat = index == nil ? .erreur : .pret
    }

    /// Le texte du champ a changé.
    public func chercher(_ texte: String) {
        self.texte = texte
        lancer()
    }

    /// Une puce de portée : la recherche se refait sur le dernier texte.
    public func choisirPortee(_ portee: RechercheGlobale.Portee) {
        guard portee != self.portee else { return }
        self.portee = portee
        lancer()
    }

    /// Attend la fin de la recherche lancée (les tests, les aperçus).
    public func attendre() async {
        while true {
            let tache = tacheRecherche
            if let tache { await tache.value }
            if tache == tacheRecherche { return }
        }
    }

    // MARK: En arrière-plan

    /// Annule la recherche précédente et lance celle-ci ; un texte trop court vide la liste sur-le-champ.
    private func lancer() {
        demande += 1
        let numero = demande
        tacheRecherche?.cancel()
        let texte = self.texte
        guard RechercheModele.assezLong(texte) else {
            tacheRecherche = nil
            trouves = nil
            enCours = false
            return
        }
        let portee = self.portee
        let nusah = magasin.reglages.siddurNusah
        let preparateur = self.preparateur
        let delai = self.delai
        enCours = true
        tacheRecherche = Task {
            if delai > .zero {
                do {
                    try await Task.sleep(for: delai)
                } catch {
                    return
                }
            }
            guard numero == self.demande else { return }
            let index = await preparateur.index(nusah)
            guard numero == self.demande else { return }
            self.etat = index == nil ? .erreur : .pret
            var resultats: [RechercheGlobale.Resultat] = []
            if let index {
                resultats = await Task.detached(priority: .userInitiated) {
                    index.chercher(texte, portee: portee)
                }.value
            }
            guard numero == self.demande else { return }
            self.trouves = RechercheTrouves(texte: texte, resultats: resultats)
            self.enCours = false
        }
    }
}
