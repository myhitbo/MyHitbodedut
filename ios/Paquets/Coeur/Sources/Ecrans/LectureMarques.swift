import Foundation
import Observation
import Coeur

// La feuille de tous les marque-pages (RepriseFavoris.listeSignets, 28/10) : d'abord tous, puis filtrés par
// recueil (סידור, תהילים, ספרים) ou par texte (שחרית, מנחה…), dans l'ordre du recueil — le siddour d'abord, puis
// les Tehilim, puis les livres —, chacun à sa place dans son texte. Ouverte depuis la ligne « סימניות · n » du
// siddour (recueil « s »), de la bibliothèque des livres (« l ») ou de l'accueil (tous).

/// Un filtre de la feuille : une puce, à choix unique.
public struct LectureMarquesFiltre: Sendable, Equatable, Identifiable {
    /// « * », « s », « t », « l », ou la clé d'un texte (« s:chaharit »).
    public let id: String
    /// « Tout », « Siddour », « Tehilim », « Livres », ou le titre hébreu d'un texte (dans la police choisie).
    public let nom: LectureNom
}

/// Une ligne de la feuille : le texte en petit, les premiers mots du paragraphe dessous.
public struct LectureMarquesLigne: Sendable, Equatable, Identifiable {
    /// La clé, le nusah et la place : unique.
    public let id: String
    /// Le titre du texte, en 13, discret, de droite à gauche, avec l'icône du recueil (14 points) au bout.
    public let titre: LectureNom
    /// « ic_marque_etude » pour un livre, « ic_marque_priere » sinon, teinte de la couleur de marque.
    public let icone: String
    /// Les premiers mots, suivis de « … », en 17, sur une ligne, de droite à gauche.
    public let apercu: String
    public let route: LectureRoute
}

@MainActor
@Observable
public final class LectureMarquesModele {
    private let magasin: Magasin
    private let contenus: ContenusApp
    /// « s », « l », ou nil pour tous.
    public let recueil: String?

    private var siddur: Siddur?
    private var livres: Siddur?
    /// Le filtre choisi : « * » d'abord.
    public private(set) var filtre = "*"

    public init(magasin: Magasin, contenus: ContenusApp, recueil: String?) {
        self.magasin = magasin
        self.contenus = contenus
        self.recueil = recueil
    }

    /// Lit le siddour du nusah choisi et l'index des livres : de quoi nommer et ranger les textes.
    public func charger() async {
        siddur = try? await contenus.siddur(magasin.reglages.siddurNusah)
        livres = try? await contenus.livres()
    }

    /// Le titre de la feuille : « Marque-pages », et un bouton OK.
    public var titre: Libelle {
        Libelle("marques_titre")
    }

    /// Les marque-pages du recueil dont le texte existe encore, dans l'ordre où ils sont gardés.
    public var marques: [MarquesPages.Marque] {
        LecturePreferences.marques(magasin.reglages).filter { m in
            (recueil.map { m.cle.commenceParUnites($0 + ":") } ?? true) && nom(m.cle) != nil
        }
    }

    /// Les puces : Tout ; chaque recueil présent ; et chaque texte, quand il y en a plus d'un hors des Tehilim.
    public var filtres: [LectureMarquesFiltre] {
        let marques = self.marques
        var sortie = [LectureMarquesFiltre(id: "*", nom: .libelle(Libelle("recherche_tout")))]
        if marques.contains(where: { $0.cle.commenceParUnites("s:") }) {
            sortie.append(LectureMarquesFiltre(id: "s", nom: .libelle(Libelle("siddur_title"))))
        }
        if marques.contains(where: { $0.cle.commenceParUnites("t:") }) {
            sortie.append(LectureMarquesFiltre(id: "t", nom: .libelle(Libelle("tehilim_title"))))
        }
        if marques.contains(where: { $0.cle.commenceParUnites("l:") }) {
            sortie.append(LectureMarquesFiltre(id: "l", nom: .libelle(Libelle("livres_title"))))
        }
        // Un texte par puce, pour le siddour et les livres ; les Tehilim n'en ont qu'un, déjà nommé.
        let parTexte = textes(marques).filter { !$0.commenceParUnites("t:") }
        if parTexte.count > 1 {
            for cle in parTexte {
                sortie.append(LectureMarquesFiltre(id: cle, nom: nom(cle) ?? .hebreu(cle)))
            }
        }
        return sortie
    }

    public func choisirFiltre(_ id: String) {
        filtre = id
    }

    /// Les marque-pages du filtre, dans l'ordre du recueil, puis de la section et du paragraphe.
    public var lignes: [LectureMarquesLigne] {
        let filtre = self.filtre
        var retenues: [(rang: Int, marque: MarquesPages.Marque)] = []
        for (rang, m) in marques.enumerated() {
            let garde: Bool
            if filtre == "*" {
                garde = true
            } else if filtre.contains(":") {
                garde = m.cle.egalUnites(filtre)
            } else {
                garde = m.cle.commenceParUnites(filtre + ":")
            }
            if garde { retenues.append((rang: rang, marque: m)) }
        }
        // sortedWith(compareBy(ordre, section, bloc)) : stable, d'où le rang en dernier.
        let ordres = retenues.map { ordre($0.marque.cle) }
        let indices = retenues.indices.sorted { a, b in
            let x = retenues[a].marque, y = retenues[b].marque
            if ordres[a] != ordres[b] { return ordres[a] < ordres[b] }
            if x.section != y.section { return x.section < y.section }
            if x.bloc != y.bloc { return x.bloc < y.bloc }
            return retenues[a].rang < retenues[b].rang
        }
        return indices.map { i in
            let m = retenues[i].marque
            return LectureMarquesLigne(id: "\(m.cle)|\(m.nusah)|\(m.section)|\(m.bloc)",
                                       titre: nom(m.cle) ?? .hebreu(m.cle),
                                       icone: LectureModele.icone(etude: m.cle.commenceParUnites("l:")),
                                       apercu: m.apercu + "\u{2026}", route: .marque(m))
        }
    }

    // MARK: Les aides

    private var police: PoliceHebraique.Police {
        LecturePreferences.police(magasin.reglages)
    }

    /// `RepriseFavoris.titre` : le nom d'une clé « s:id », « l:id » ou « t:tehilim » ; nil si le texte n'existe pas.
    private func nom(_ cle: String) -> LectureNom? {
        if cle.egalUnites(LecturePreferences.cleTehilim) { return .libelle(Libelle("tehilim_title")) }
        let id = cle.apresUnites(":")
        let source = cle.commenceParUnites("l:") ? livres : siddur
        guard let he = source?.texte(id)?.titre.he else { return nil }
        return .hebreu(PoliceHebraique.masque(he, police: police))
    }

    /// `RepriseFavoris.ordre` : le siddour d'abord, puis les Tehilim, puis les livres, chacun dans son ordre.
    private func ordre(_ cle: String) -> Int {
        if cle.commenceParUnites("t:") { return 5_000 }
        let livre = cle.commenceParUnites("l:")
        let id = cle.apresUnites(":")
        let textes = (livre ? livres : siddur)?.textes ?? []
        let rang = textes.firstIndex { $0.id == id } ?? -1
        return (livre ? 10_000 : 0) + rang
    }

    /// Les clés des textes marqués, distinctes, dans l'ordre du recueil (un tri stable).
    private func textes(_ marques: [MarquesPages.Marque]) -> [String] {
        var vues: [String] = []
        for m in marques where !vues.contains(where: { $0.egalUnites(m.cle) }) {
            vues.append(m.cle)
        }
        let ordres = vues.map { ordre($0) }
        return vues.indices.sorted { a, b in
            ordres[a] != ordres[b] ? ordres[a] < ordres[b] : a < b
        }.map { vues[$0] }
    }
}
