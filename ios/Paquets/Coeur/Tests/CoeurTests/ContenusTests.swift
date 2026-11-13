import Foundation
import Testing
@testable import Coeur

/// DataLoadTest, VillesTest et LicencesEditionsTest d'Android, portés sur les contenus exportés.
@Suite("Contenus")
struct ContenusTests {

    private func chizuk() throws -> Chizuk { try JSONDecoder().decode(Chizuk.self, from: Depot.contenu("chizuk.json")) }
    private func bibliotheque() throws -> Bibliotheque {
        try JSONDecoder().decode(Bibliotheque.self, from: Depot.contenu("bibliotheque.json"))
    }

    private func doublons(_ ids: [String]) -> [String] {
        Dictionary(grouping: ids, by: { $0 }).filter { $0.value.count > 1 }.map(\.key).sorted()
    }

    // MARK: DataLoadTest

    @Test func leFichierChizukSeCharge() throws {
        let c = try chizuk()
        #expect(c.version == "0.2")
        #expect(!c.items.isEmpty)
        #expect(!c.editions.isEmpty)
        #expect(c.items.count == 171)
    }

    @Test func lesIdentifiantsChizukSontUniques() throws {
        let ids = try chizuk().items.map(\.id)
        #expect(doublons(ids).isEmpty, "\(doublons(ids))")
    }

    @Test func chaqueItemChizukPorteAuMoinsUnMomentConnu() throws {
        for item in try chizuk().items {
            #expect(!item.moments.isEmpty, "\(item.id) : aucun moment reconnu")
        }
    }

    @Test func chaqueItemChizukDesigneUneEditionDeclaree() throws {
        let c = try chizuk()
        for item in c.items {
            #expect(c.editions[item.edition] != nil, "\(item.id) : édition « \(item.edition) » absente de _meta")
        }
    }

    @Test func leFichierBibliothequeSeCharge() throws {
        let b = try bibliotheque()
        #expect(b.version == "0.1")
        #expect(!b.sections.isEmpty)
        #expect(!b.entrees.isEmpty)
    }

    @Test func lesIdentifiantsDeLaBibliothequeSontUniques() throws {
        let ids = try bibliotheque().entrees.map(\.id)
        #expect(doublons(ids).isEmpty, "\(doublons(ids))")
    }

    @Test func lesDeuxNaturesDEntreeSontTypees() throws {
        let entrees = try bibliotheque().entrees
        var sources = 0, articles = 0
        for entree in entrees {
            switch entree {
            case .source(let s):
                sources += 1
                #expect(!s.paragraphes.isEmpty, "\(s.id) : source sans paragraphe")
            case .article(let a):
                articles += 1
                #expect(!a.titre.trimmingCharacters(in: .whitespaces).isEmpty, "\(a.id) : article sans titre")
            }
        }
        #expect(sources > 0)
        #expect(articles > 0)
    }

    @Test func laSousSectionViseeParLaSpecificationExiste() throws {
        let b = try bibliotheque()
        let section = try #require(b.sections.first { $0.id == "sichat-chaverim" })
        #expect(section.titre.he == "שיחת חברים")
        let sous = try #require(b.sousSection("hitbodedut-ma-velama"), "sous-section « התבודדות מה ולמה » absente")
        #expect(sous.titre.he == "התבודדות מה ולמה")
    }

    // MARK: LicencesEditionsTest

    @Test func aucuneEditionSansLicence() throws {
        let editions = Array(try chizuk().editions.values) + Array(try bibliotheque().editions.values)
        #expect(!editions.isEmpty)
        for e in editions {
            #expect(!e.licence.trimmingCharacters(in: .whitespaces).isEmpty, "\(e.cle) : licence vide")
            #expect(e.licence.lowercased() != "unknown", "\(e.cle) : licence « unknown »")
        }
    }

    @Test func uneEditionEnTexteSeulNeRepriendPasSaVocalisation() throws {
        let editions = Array(try chizuk().editions.values) + Array(try bibliotheque().editions.values)
        let texteSeul = editions.filter { $0.licence.contains("texte seul") }
        #expect(Set(texteSeul.map(\.cle)) == ["sh", "shr", "le", "lt"], "les quatre éditions en texte seul ont changé")
        for e in texteSeul {
            #expect(!e.nikkoudOk, "\(e.cle) : édition en texte seul, nikkoud_ok doit rester faux")
        }
    }

    // MARK: VillesTest

    @Test func lesVillesSontLuesEtBienFormees() throws {
        let villes = try Villes.lire(Depot.contenu("villes.json"))
        #expect(villes.count == 51)
        #expect(Set(villes.map(\.id)).count == villes.count)
        for v in villes {
            #expect(!v.nom.he.isEmpty && !v.nom.fr.isEmpty && !v.nom.en.isEmpty, "\(v.id)")
            #expect((-90.0...90.0).contains(v.latitude) && (-180.0...180.0).contains(v.longitude), "\(v.id)")
            #expect(TimeZone(identifier: v.fuseau) != nil, "\(v.id) : fuseau \(v.fuseau)")
        }
        let premiere = try #require(villes.first)
        #expect(premiere.nom.fr == "Jérusalem")
        #expect(premiere.enIsrael)
        #expect(!villes.contains { $0.enIsrael && $0.fuseau != "Asia/Jerusalem" })
    }

    @Test func laSourceDesVillesEstCiteeCommeCCBYLeDemande() throws {
        let json = String(decoding: try Depot.contenu("villes.json"), as: UTF8.self)
        #expect(json.contains("GeoNames") && json.contains("CC-BY 4.0"))
        let xcstrings = try JSONSerialization.jsonObject(
            with: Depot.donnees("ios/Ressources/Chaines/Localizable.xcstrings")) as? [String: Any]
        let chaines = try #require(xcstrings?["strings"] as? [String: Any])
        for langue in ["fr", "en", "he"] {
            let cite = chaines.values.contains { entree in
                let loc = (entree as? [String: Any])?["localizations"] as? [String: Any]
                let unite = (loc?[langue] as? [String: Any])?["stringUnit"] as? [String: Any]
                return (unite?["value"] as? String)?.contains("GeoNames") == true
            }
            #expect(cite, "\(langue) : GeoNames n'est cité dans aucune chaîne")
        }
    }
}
