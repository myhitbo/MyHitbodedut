import Foundation
import Testing
@testable import Coeur

/// Les tables écrites dans le Kotlin d'Android (ROADMAP, tâche 6), lues sur la JVM par
/// tools/vecteurs_ios/VecteursTables.kt et recopiées dans Contenu/tables.json par l'export : les comptes du
/// critère de fin, et ce que le Swift en a déjà repris. Puis les cas communs de la normalisation de la
/// recherche, écrits par Android, que RechercheGlobale.swift rend à l'identique (recherche.py aussi, à l'export).
@Suite("Tables du Kotlin")
struct TablesTests {

    private func tables() throws -> ObjetJSON { try Depot.vecteurs("tables.json") }

    private func objets(_ t: [JSON]) -> [ObjetJSON] { t.indices.compactMap { t.objet($0) } }

    @Test func lesComptesDuCritereDeFin() throws {
        let t = try tables()
        let echelles = try #require(t.objet("paliers")?.objet("echelles"))
        #expect(echelles.cles == ["serie", "jour", "semaine", "mois", "cumul", "jours"])
        let trophees = try #require(t.objet("trophees"))
        let familles = objets(trophees.tableau("familles") ?? [])
        #expect(familles.count == 11)
        let niveaux = familles.map { ($0.tableau("seuils") ?? []).count }.reduce(0, +)
        #expect(niveaux == 128)
        #expect(trophees.tableau("chemin")?.count == 128)
        #expect(t.objet("tehilim")?.tableau("mois")?.count == 30)
        #expect(t.objet("tehilim")?.tableau("semaine")?.count == 7)
        #expect(t.tableau("sujets")?.count == 10)
        #expect(t.tableau("hitbodedut")?.count == 5)
        #expect(t.objet("personnageFeminin")?.count == 21)
        #expect(t.objet("zmanim")?.tableau("profil")?.count == 15)
    }

    @Test func lesSeuilsMontentEtLeCheminSuitLeCout() throws {
        let trophees = try #require(try tables().objet("trophees"))
        for f in objets(trophees.tableau("familles") ?? []) {
            let s = f.tableau("seuils") ?? []
            let seuils = s.indices.map { s.entier($0) }
            #expect(seuils == seuils.sorted() && Set(seuils).count == seuils.count, "\(f.texte("cle"))")
        }
        let chemin = objets(trophees.tableau("chemin") ?? [])
        let couts = chemin.map { $0.double("cout") }
        #expect(couts == couts.sorted())
        let metaux: Set<String> = ["BRONZE", "ARGENT", "OR", "PLATINE"]
        let inconnus = chemin.map { $0.texte("metal") }.filter { !metaux.contains($0) }
        #expect(inconnus.isEmpty)
    }

    @Test func lesPortionsCouvrentLesCentCinquantePsaumes() throws {
        let tehilim = try #require(try tables().objet("tehilim"))
        for cle in ["mois", "semaine"] {
            var suivant = 1
            for p in objets(tehilim.tableau(cle) ?? []) {
                let debut = p.entier("debut"), fin = p.entier("fin")
                // Le psaume 119 se partage en deux jours du mois.
                if debut == suivant - 1 && debut == 119 { continue }
                #expect(debut == suivant, "\(cle) : \(debut) au lieu de \(suivant)")
                suivant = fin + 1
            }
            #expect(suivant == 151, "\(cle)")
        }
        let tikkun = try tables().tableau("tikkun") ?? []
        let ordre = tikkun.indices.map { tikkun.entier($0) }
        #expect(ordre == [16, 32, 41, 42, 59, 77, 90, 105, 137, 150])
    }

    @Test func leProfilDesZmanimEstCeluiDeZmanimSwift() throws {
        let z = try #require(try tables().objet("zmanim"))
        let profil = objets(z.tableau("profil") ?? []).map {
            Zmanim.Entree(cle: $0.texte("cle"), methode: Zmanim.Methode($0.texte("methode"), $0.texte("parametres")))
        }
        #expect(profil == Zmanim.profil)
        let a = z.tableau("allumages") ?? []
        let allumages = a.indices.map { a.entier($0) }
        #expect(allumages == Zmanim.allumages)
    }

    @Test func lesRessourcesNommeesExistent() throws {
        let t = try tables()
        var noms: [String] = []
        for cle in ["sujets", "sujetsTefila"] { noms += objets(t.tableau(cle) ?? []).map { $0.texte("titre") } }
        for h in objets(t.tableau("hitbodedut") ?? []) { noms += [h.texte("titre"), h.texte("invite"), h.texte("illustration")] }
        let q = t.tableau("questions") ?? []
        noms += q.indices.map { q.texte($0) }
        for e in objets(t.objet("presentation")?.tableau("ecrans") ?? []) { noms += [e.texte("titre"), e.texte("corps"), e.texte("illustration")] }
        for c in objets(t.tableau("conseils") ?? []) { noms += [c.texte("titre"), c.texte("corps"), c.texte("illustration")] }
        for (a, b) in t.objet("personnageFeminin")?.paires ?? [] { noms += [a, b.commeTexte] }
        let mal = noms.filter { !$0.hasPrefix("string/") && !$0.hasPrefix("drawable/") }
        #expect(mal.isEmpty, "identifiants non traduits en noms : \(mal)")
        // Chaque illustration est livrée dans Images/.
        let images = Set(noms.filter { $0.hasPrefix("drawable/") }.map { String($0.dropFirst("drawable/".count)) })
        let absentes = try images.filter { try Depot.lire("../Images/\($0).webp") == nil }.sorted()
        #expect(absentes.isEmpty, "\(absentes)")
    }

    @Test func lesPolicesConnuesEtLeursSignesAbsents() throws {
        let p = try #require(try tables().objet("polices"))
        let cles = p.tableau("cles") ?? []
        let polices = cles.indices.map { cles.texte($0) }
        #expect(polices == ["serif", "sans", "arrondie", "frank", "david", "rachi", "miriam"])
        let absents = try #require(p.objet("absents"))
        #expect(!absents.a("sans"), "la police sans empattement a tous les signes")
        for (cle, valeur) in absents.paires {
            let hors = valeur.commeTexte.unicodeScalars.filter { !(0x0591...0x05C7).contains($0.value) }
            #expect(hors.isEmpty, "\(cle)")
        }
    }

    @Test func laNormalisationDeLaRechercheEstCelleDAndroid() throws {
        let cas = try Depot.vecteurs("normalisation.json").tableau("cas") ?? []
        #expect(cas.count >= 20)
        for case .tableau(let c) in cas {
            let rendu = RechercheGlobale.nu(c.texte(0))
            #expect(rendu.egalUnites(c.texte(1)), "« \(c.texte(0)) » : « \(rendu) » au lieu de « \(c.texte(1)) »")
        }
    }
}
