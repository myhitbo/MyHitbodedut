import Foundation
import Testing
@testable import Coeur

/// Ce que la recherche d'Android répond (tools/export_contenu/tables/src/Recherche.kt, sur le
/// Kotlin de l'app) : la normalisation des cas communs, et 144 recherches sur l'index.
struct VecteursRecherche: Decodable {
    struct Cas: Decodable {
        let q: String
        let langue: String
        let rite: String
        let portee: String
        /// [sorte, id, titre, extrait] ; le titre du Ben Ich Haï en « ben_ish_hai:<année>:<numéro>:<section> ».
        let resultats: [[String]]
    }

    let normalisation: [[String]]
    let parSorte: Int
    let recherches: [Cas]

    enum CodingKeys: String, CodingKey {
        case normalisation, recherches
        case parSorte = "par_sorte"
    }

    static func lire() throws -> VecteursRecherche {
        try JSONDecoder().decode(VecteursRecherche.self,
                                 from: Depot.donnees("ios/Paquets/Coeur/Tests/Ressources/vecteurs_recherche.json"))
    }
}

@Suite("Recherche")
struct RechercheTests {

    private func index() throws -> IndexRecherche {
        try IndexRecherche(chemin: Depot.racine.appendingPathComponent("ios/Ressources/Contenu/recherche.sqlite"))
    }

    /// HalakhaActivity ne se compile pas hors d'Android : les vecteurs portent les champs de son titre.
    private func attendu(_ r: [String]) throws -> RechercheGlobale.Resultat {
        let sorte = try #require(RechercheGlobale.Sorte(rawValue: r[0]))
        var titre = r[2]
        if titre.hasPrefix("ben_ish_hai:") {
            let champs = titre.split(separator: ":", maxSplits: 3, omittingEmptySubsequences: false).map(String.init)
            titre = RechercheGlobale.sourceBenIshHai(annee: try #require(Int(champs[1])),
                                                     numero: try #require(Int(champs[2])), section: champs[3])
        }
        return RechercheGlobale.Resultat(sorte: sorte, id: r[1], titre: titre, extrait: r[3])
    }

    // MARK: La normalisation

    @Test func laNormalisationRendCeQueRendLeKotlin() throws {
        let v = try VecteursRecherche.lire()
        #expect(v.normalisation.count >= 30)
        for cas in v.normalisation {
            #expect(RechercheGlobale.nu(cas[0]) == cas[1], "\(cas[0].unicodeScalars.map { String($0.value, radix: 16) })")
        }
    }

    /// DixAmeliorationsTest.
    @Test func sansVoyellesNiBalisesNiAccents() {
        #expect(RechercheGlobale.nu("<b>בָּרוּךְ</b> אַתָּה") == "ברוך אתה")
        #expect(RechercheGlobale.nu("Birkot hacha’har Prières") == "birkot hachahar prieres")
        #expect(RechercheGlobale.nuHalakha("מִי־כָמֹכָה") == "מי כמכה")
    }

    @Test func lExtraitEncadreLaTrouvaille() {
        #expect(RechercheGlobale.extrait(nu: "abc", "b") == "abc")
        let long = String(repeating: "x", count: 40) + "cible" + String(repeating: "y", count: 60)
        let e = RechercheGlobale.extrait(nu: long, "cible")
        #expect(e == "…" + String(repeating: "x", count: 30) + "cible" + String(repeating: "y", count: 50) + "…")
        // Introuvable (la halakha cherche avec sa propre normalisation) : depuis le début.
        #expect(RechercheGlobale.extrait(nu: "abcdef", "zz") == "abcdef")
    }

    @Test func lesPortees() {
        #expect(RechercheGlobale.Portee.tout.sortes == Set(RechercheGlobale.Sorte.allCases))
        #expect(RechercheGlobale.Portee.tefilot.sortes == [.siddour])
        #expect(RechercheGlobale.Portee.halakhot.sortes == [.halakha])
        #expect(RechercheGlobale.Portee.sefarim.sortes == [.livre])
        #expect(RechercheGlobale.Portee.hilloulot.sortes == [.hilloula])
    }

    // MARK: L'index, jugé sur le Kotlin

    @Test func chaqueRechercheRendLesResultatsDuKotlin() throws {
        let v = try VecteursRecherche.lire()
        #expect(v.parSorte == RechercheGlobale.parSorte)
        #expect(v.recherches.count == 144)
        let index = try index()
        for cas in v.recherches {
            let attendus = try cas.resultats.map(attendu)
            let trouves = try index.chercher(cas.q, langue: cas.langue, rite: try #require(Nusah(rawValue: cas.rite)),
                                             portee: try #require(RechercheGlobale.Portee(rawValue: cas.portee)))
            let nom = "« \(cas.q) » \(cas.langue) \(cas.rite) \(cas.portee)"
            #expect(trouves.count == attendus.count, "\(nom) : \(trouves.count) résultats au lieu de \(attendus.count)")
            if let i = trouves.indices.first(where: { $0 < attendus.count && trouves[$0] != attendus[$0] }) {
                Issue.record("\(nom), résultat \(i) : \(trouves[i]) au lieu de \(attendus[i])")
            }
        }
    }

    /// HalakhaTest, YalkutYosefTest : « ציצית » trouve sans voyelles ; une seule lettre ne cherche pas.
    @Test func laHalakhaSeChercheSansVoyelles() throws {
        let r = try index().chercher("ציצית", langue: "he", rite: .edot, portee: .halakhot)
        #expect(r.filter { $0.titre.hasPrefix("בן איש חי") }.count > 10)
        #expect(r.contains { $0.titre.hasPrefix("ילקוט יוסף") })
        #expect(try index().chercher("צ", langue: "he", rite: .edot).isEmpty)
    }

    /// HilloulotTest : par nom, en hébreu, en français et en anglais, avec ou sans accents.
    @Test func lesHilloulotSeCherchentParNom() throws {
        let i = try index()
        #expect(try !i.chercher("צבי הירש חיות", langue: "he", rite: .edot, portee: .hilloulot).isEmpty)
        #expect(try i.chercher("א", langue: "he", rite: .edot, portee: .hilloulot).isEmpty)
        #expect(try !i.chercher("Chelah", langue: "fr", rite: .edot, portee: .hilloulot).isEmpty)
        #expect(try !i.chercher("Shelah", langue: "en", rite: .edot, portee: .hilloulot).isEmpty)
        #expect(try i.chercher("Moché", langue: "fr", rite: .edot, portee: .hilloulot).count
                == i.chercher("moche", langue: "fr", rite: .edot, portee: .hilloulot).count)
    }

    /// Trente par sorte ; la halakha en a deux, le Yalkout Yossef et le Ben Ich Haï, trente chacun.
    @Test func unResultatParPriereEtTrenteParSorte() throws {
        let r = try index().chercher("ברוך", langue: "fr", rite: .edot)
        for sorte in RechercheGlobale.Sorte.allCases {
            let plafond = RechercheGlobale.parSorte * (sorte == .halakha ? 2 : 1)
            #expect(r.filter { $0.sorte == sorte }.count <= plafond, "\(sorte)")
        }
        let prieres = r.filter { $0.sorte == .siddour }.map(\.id)
        #expect(!prieres.isEmpty && Set(prieres).count == prieres.count)
    }
}
