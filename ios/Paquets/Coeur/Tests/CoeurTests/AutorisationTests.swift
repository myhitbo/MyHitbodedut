import Foundation
import Testing
@testable import Coeur

/// Les cas de SettingsTest d'Android qui portent sur Autorisation et PermissionRules ; le reste de
/// SettingsTest lit l'écran des réglages et reste à Android. Les chaînes de la batterie et de la
/// superposition, sans objet sur iOS, ne sont pas exportées dans le catalogue (export.py, EXCLUES) : le
/// cas des trois langues y vérifie celles qui le sont. Rejoue aussi `interface_b.json`.
@Suite("Autorisation")
struct AutorisationTests {

    private struct Fichier: Decodable {
        let autorisations: Autorisations
    }

    private struct Autorisations: Decodable {
        let entrees: [Entree]
        let demandees: [Demande]
        let manquantes: [Manque]
    }

    private struct Entree: Decodable {
        let nom: String
        let cle: String
        let titre: String
        let pourquoi: String
        let barriere: Bool
    }

    /// [avec la barrière, noms].
    private struct Demande: Decodable {
        let avecBarriere: Bool
        let noms: [String]

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            avecBarriere = try c.decode(Bool.self)
            noms = try c.decode([String].self)
        }
    }

    /// [avec la barrière, masque des accordées (bit i : la i-ième), noms des manquantes].
    private struct Manque: Decodable {
        let avecBarriere: Bool
        let masque: Int
        let noms: [String]

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            avecBarriere = try c.decode(Bool.self)
            masque = try c.decode(Int.self)
            noms = try c.decode([String].self)
        }
    }

    private func vecteurs() throws -> Autorisations {
        let donnees = try Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/interface_b.json")
        return try JSONDecoder().decode(Fichier.self, from: donnees).autorisations
    }

    private func noms(_ liste: [Autorisation]) -> [String] {
        liste.map { String(describing: $0).uppercased() }
    }

    /// Les quatre autorisations, dans l'ordre d'utilité décroissante. Les deux dernières ne servent qu'à
    /// la barrière : l'édition légère n'en a pas, et ne doit donc pas les réclamer.
    @Test func lEditionLegereNeDemandeQueCeDontElleSeSert() {
        let toutes = PermissionRules.demandees(avecBarriere: true)
        #expect(toutes.count == 4)
        let legere = PermissionRules.demandees(avecBarriere: false)
        let attendues: [Autorisation] = [.notifications, .batterie]
        #expect(legere == attendues)
        let barrieres = legere.filter { $0.barriere }
        #expect(barrieres.isEmpty)
    }

    @Test func lesAutorisationsSontDistinctesEtOrdonneesParUtilite() {
        let toutes = Autorisation.allCases
        let cles = Set(toutes.map(\.cle))
        let titres = Set(toutes.map(\.titre))
        let raisons = Set(toutes.map(\.pourquoi))
        #expect(cles.count == toutes.count)
        #expect(titres.count == toutes.count)
        #expect(raisons.count == toutes.count)
        // Celles de la barrière ferment la marche : elles ne concernent qu'une édition sur deux.
        let barriere = toutes.map(\.barriere)
        let triee = barriere.sorted { !$0 && $1 }
        #expect(barriere == triee)
    }

    /// Ce qui manque se compte à partir de la même liste, pas d'une autre.
    @Test func leCompteDeCeQuiManqueSuitLEdition() {
        let rien = PermissionRules.manquantes(avecBarriere: true) { _ in true }
        #expect(rien.isEmpty, "tout accordé : rien ne doit manquer")
        let toutes = PermissionRules.manquantes(avecBarriere: true) { _ in false }
        #expect(toutes.count == 4)
        let legere = PermissionRules.manquantes(avecBarriere: false) { _ in false }
        #expect(legere.count == 2)
        // Une seule manquante, et c'est bien celle-là qui est rendue.
        let une = PermissionRules.manquantes(avecBarriere: true) { $0 != .batterie }
        let attendue: [Autorisation] = [.batterie]
        #expect(une == attendue)
    }

    @Test func chaqueAutorisationASonTitreEtSaRaisonDansLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        let exportees = Autorisation.allCases.filter { $0 != .batterie && $0 != .overlay }
        let cles = exportees.flatMap { [$0.titre, $0.pourquoi] } + ["settings_title", "action_open", "settings_all_granted"]
        for langue in Catalogue.langues {
            let simples = catalogue.simples(langue)
            for cle in cles {
                let texte = simples[cle] ?? ""
                #expect(!texte.blanc, "\(langue) : « \(cle) » manquant")
            }
            let pluriel = catalogue.pluriels(langue)["permissions_missing[other]"] ?? ""
            #expect(!pluriel.blanc, "\(langue) : le pluriel permissions_missing manque")
        }
    }

    @Test func lesAutorisationsRepondentCommeAndroid() throws {
        let v = try vecteurs()
        let toutes = Autorisation.allCases
        #expect(toutes.count == v.entrees.count)
        for (rang, e) in v.entrees.enumerated() where rang < toutes.count {
            let a = toutes[rang]
            let nom = String(describing: a).uppercased()
            #expect(nom == e.nom, "rang \(rang)")
            #expect(a.cle == e.cle, "\(e.nom)")
            #expect(a.titre == e.titre, "\(e.nom)")
            #expect(a.pourquoi == e.pourquoi, "\(e.nom)")
            #expect(a.barriere == e.barriere, "\(e.nom)")
        }
        for d in v.demandees {
            let rendues = noms(PermissionRules.demandees(avecBarriere: d.avecBarriere))
            #expect(rendues == d.noms, "demandees(\(d.avecBarriere))")
        }
        #expect(v.manquantes.count == 32)
        for m in v.manquantes {
            let rendues = noms(PermissionRules.manquantes(avecBarriere: m.avecBarriere) { a in
                let rang = toutes.firstIndex(of: a) ?? 0
                return m.masque & (1 << rang) != 0
            })
            #expect(rendues == m.noms, "manquantes(\(m.avecBarriere), \(m.masque))")
        }
    }
}
