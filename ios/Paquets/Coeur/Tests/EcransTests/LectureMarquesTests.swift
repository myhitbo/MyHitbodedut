import Foundation
import Testing
import Coeur
@testable import Ecrans

/// La feuille des marque-pages (RepriseFavoris.listeSignets) : ce qu'elle garde, ses puces, son ordre (le
/// siddour, puis les Tehilim, puis les livres, chacun à sa place), et ce qu'ouvre chaque ligne.
///
/// Restent au test d'interface : la feuille elle-même, ses puces à choix unique, sa fermeture à l'ouverture d'un
/// texte.
@Suite("Feuille des marque-pages")
@MainActor
struct LectureMarquesTests {

    private static let contenus = ContenusApp(dossier: Fichiers.contenu)

    private let chaharit32 = MarquesPages.Marque(cle: "s:chaharit", nusah: "edot", section: 3, bloc: 2, apercu: "א")
    private let chaharit15 = MarquesPages.Marque(cle: "s:chaharit", nusah: "edot", section: 1, bloc: 5, apercu: "ב")
    private let moharan = MarquesPages.Marque(cle: "l:likoutei_moharan", nusah: "", section: 300, bloc: 1, apercu: "ג")
    private let tehilim = MarquesPages.Marque(cle: "t:tehilim", nusah: "", section: 23, bloc: 4, apercu: "ד")
    private let disparu = MarquesPages.Marque(cle: "s:inexistant", nusah: "edot", section: 0, bloc: 0, apercu: "ה")
    private let minha = MarquesPages.Marque(cle: "s:minha", nusah: "edot", section: 0, bloc: 1, apercu: "ו")

    private func modele(_ recueil: String?) async -> LectureMarquesModele {
        var brut = Reglages().brut
        brut["marques_pages"] = .chaine(MarquesPages.encoder([moharan, chaharit32, disparu, tehilim, chaharit15, minha]))
        let magasin = Magasin.enMemoire(Enregistrement(reglages: Reglages(brut: brut)))
        let m = LectureMarquesModele(magasin: magasin, contenus: Self.contenus, recueil: recueil)
        await m.charger()
        return m
    }

    /// chaharit et minha dans l'ordre du siddour Edot.
    private func ordreSiddour() async throws -> [String] {
        let siddur = try await Self.contenus.siddur(.edot)
        let a = siddur.textes.firstIndex { $0.id == "chaharit" } ?? -1
        let b = siddur.textes.firstIndex { $0.id == "minha" } ?? -1
        return a <= b ? ["s:chaharit", "s:minha"] : ["s:minha", "s:chaharit"]
    }

    @Test func toutesLesMarquesDontLeTexteExiste() async throws {
        let m = await modele(nil)
        let gardees = m.marques
        #expect(gardees == [moharan, chaharit32, tehilim, chaharit15, minha])
        #expect(m.titre.cle == "marques_titre")
        let siddour = try await ordreSiddour()
        let filtres = m.filtres.map { $0.id }
        #expect(filtres == ["*", "s", "t", "l"] + siddour + ["l:likoutei_moharan"])
        let premier = m.filtres.first?.nom
        #expect(premier == .libelle(Libelle("recherche_tout")))
        let tehilimNom = m.filtres.first { $0.id == "t" }?.nom
        #expect(tehilimNom == .libelle(Libelle("tehilim_title")))
    }

    @Test func lOrdreDuRecueilPuisDeLaPlace() async throws {
        let m = await modele(nil)
        let siddour = try await ordreSiddour()
        var attendus: [String] = []
        for cle in siddour {
            if cle == "s:chaharit" {
                attendus += ["s:chaharit|edot|1|5", "s:chaharit|edot|3|2"]
            } else {
                attendus.append("s:minha|edot|0|1")
            }
        }
        attendus += ["t:tehilim||23|4", "l:likoutei_moharan||300|1"]
        let ids = m.lignes.map { $0.id }
        #expect(ids == attendus)
        let derniere = try #require(m.lignes.last)
        #expect(derniere.apercu == "ג\u{2026}")
        #expect(derniere.icone == "ic_marque_etude")
        #expect(derniere.route == .lecture(LectureCible(id: "likoutei_moharan", livre: true,
                                                         marque: LecturePlace(section: 300, bloc: 1))))
        let livres = try await Self.contenus.livres()
        let titre = livres.texte("likoutei_moharan").map { LectureNom.hebreu(PoliceHebraique.masque($0.titre.he, police: .serif)) }
        #expect(derniere.titre == titre)
        let psaume = m.lignes.first { $0.id.hasPrefix("t:") }
        #expect(psaume?.route == .tehilimMarque(psaume: 23, verset: 4))
        #expect(psaume?.icone == "ic_marque_priere")
        #expect(psaume?.titre == .libelle(Libelle("tehilim_title")))
    }

    @Test func unFiltreParRecueilOuParTexte() async throws {
        let m = await modele(nil)
        m.choisirFiltre("l")
        let livres = m.lignes.map { $0.id }
        #expect(livres == ["l:likoutei_moharan||300|1"])
        m.choisirFiltre("s:chaharit")
        let chaharit = m.lignes.map { $0.id }
        #expect(chaharit == ["s:chaharit|edot|1|5", "s:chaharit|edot|3|2"])
        m.choisirFiltre("*")
        let toutes = m.lignes.count
        #expect(toutes == 5)
    }

    @Test func lesMarquesDuSiddourSeules() async throws {
        let m = await modele("s")
        let gardees = m.marques
        #expect(gardees == [chaharit32, chaharit15, minha])
        let siddour = try await ordreSiddour()
        let filtres = m.filtres.map { $0.id }
        #expect(filtres == ["*", "s"] + siddour)
    }

    @Test func lesMarquesDesLivresSeules() async throws {
        let m = await modele("l")
        let filtres = m.filtres.map { $0.id }
        #expect(filtres == ["*", "l"])
        let ids = m.lignes.map { $0.id }
        #expect(ids == ["l:likoutei_moharan||300|1"])
    }
}
