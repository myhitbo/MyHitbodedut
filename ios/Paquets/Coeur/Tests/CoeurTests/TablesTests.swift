import Foundation
import Testing
@testable import Coeur

/// Les tables du Kotlin (Contenu/tables.json, tools/export_contenu/tables) : leurs comptes, et les
/// tables qu'iOS a déjà écrites en Swift, comparées à celles d'Android (ROADMAP.md tâche 6).
@Suite("Tables du Kotlin")
struct TablesTests {

    private func tables() throws -> TablesKotlin { try TablesKotlin.lire(Depot.contenu("tables.json")) }

    @Test func lesComptesDuCritere() throws {
        let t = try tables()
        #expect(t.paliers.count == 6)
        #expect(t.trophees.familles.count == 11)
        #expect(t.trophees.chemin.count == 128)
        #expect(t.trophees.familles.map(\.seuils.count).reduce(0, +) == 128)
        #expect(t.tehilim.mois.count == 30)
        #expect(t.tehilim.semaine.count == 7)
        #expect(t.sujetsTefila.sujets.count == 10)
        #expect(t.sujetsSeance.count == 10)
        #expect(t.hitbodedut.mouvements.count == 5)
        #expect(t.posesFeminines.count == 21)
        #expect(t.zmanim.profil.count == 15)
    }

    @Test func lesEchellesEtLeCheminSontEnOrdre() throws {
        let t = try tables()
        for (piste, e) in t.paliers {
            #expect(e.echelle == e.echelle.sorted() && Set(e.echelle).count == e.echelle.count, "\(piste)")
            #expect(e.pas > 0, "\(piste)")
        }
        #expect(Set(t.paliers.keys) == ["serie", "jour", "semaine", "mois", "cumul", "jours"])
        // Le chemin va du moins coûteux au plus coûteux ; chaque famille y monte rang par rang.
        let couts = t.trophees.chemin.map(\.cout)
        #expect(couts == couts.sorted())
        for f in t.trophees.familles {
            #expect(t.trophees.chemin.filter { $0.famille == f.cle }.map(\.seuil) == f.seuils, "\(f.cle)")
        }
        #expect(t.trophees.metaux == ["bronze", "argent", "or", "platine"])
    }

    @Test func lesPortionsCouvrentLesCentCinquantePsaumes() throws {
        let t = try tables().tehilim
        #expect(t.psaumes == 150)
        for cycle in [t.mois, t.semaine] {
            #expect(cycle.first?.debut == 1 && cycle.last?.fin == 150)
        }
        // Le psaume 119 coupé en deux, les jours 25 et 26.
        #expect(t.mois[24].debut == 119 && t.mois[24].fin == 119 && t.mois[24].finVerset == 96)
        #expect(t.mois[25].debutVerset == 97 && t.mois[25].finVerset == 176)
        #expect(t.finMoisCourt.debut == 140 && t.finMoisCourt.fin == 150)
    }

    @Test func leProfilDesZmanimEstCeluiDuKotlin() throws {
        let z = try tables().zmanim
        #expect(Zmanim.profil.map { "\($0.cle) \($0.methode.cle) \($0.methode.parametres)" }
                == z.profil.map { "\($0.cle) \($0.methode) \($0.parametres)" })
        #expect(Zmanim.allumages == z.allumages)
        #expect(Zmanim.allumageDefaut == z.allumageDefaut)
        #expect(Zmanim.methodeAllumage(minutes: z.allumageDefaut).cle == z.allumage)
    }

    @Test func lesFetesEtLesConditionsSontCellesDuKotlin() throws {
        let c = try tables().calendrier
        #expect(CalendrierJuif.fetes == Dictionary(uniqueKeysWithValues: c.fetes.map { ($0.index, $0.cle) }))
        #expect(CalendrierJuif.C.toutes == c.conditions)
        #expect(CalendrierJuif.C.derivees == c.derivees)
    }

    @Test func lesNombresEnLettresSontCeuxDuKotlin() throws {
        let lettres = try tables().references.lettres
        #expect(lettres.count == 999)
        for n in 1...999 {
            #expect(Reference.lettres(n) == lettres[n - 1], "\(n)")
        }
        #expect(Reference.lettres(0) == "0" && Reference.lettres(1000) == "1000")
    }

    @Test func lesFenetresDuYalkoutYossef() throws {
        let y = try tables().yalkutYosef
        #expect(y.parJour == 2)
        #expect(y.fenetre(mois: CalendrierJuif.Mois.nissan, jour: 15, embolismique: false) == "pessah")
        #expect(y.fenetre(mois: CalendrierJuif.Mois.adar, jour: 14, embolismique: false) == "pourim")
        // L'année embolismique : Pourim en Adar II, rien en Adar I.
        #expect(y.fenetre(mois: CalendrierJuif.Mois.adarII, jour: 14, embolismique: true) == "pourim")
        #expect(y.fenetre(mois: CalendrierJuif.Mois.adar, jour: 14, embolismique: true) == nil)
        #expect(y.fenetre(mois: CalendrierJuif.Mois.hechvan, jour: 10, embolismique: false) == nil)
    }

    @Test func lesNomsDeRessourcesExistent() throws {
        let t = try tables()
        let chaines = Set(try Catalogue.lire().strings.keys)
        let titres = t.hitbodedut.mouvements.flatMap { [$0.titre, $0.invite] } + t.sujetsTefila.sujets.map(\.titre)
            + t.sujetsSeance.map(\.titre) + t.questions + t.presentation.ecrans.flatMap { [$0.titre, $0.corps] }
            + t.conseils.flatMap { [$0.titre, $0.corps] }
        for cle in titres {
            #expect(chaines.contains(cle), "\(cle) : absente de Localizable.xcstrings")
        }
        let images = t.hitbodedut.mouvements.map(\.illustration) + t.presentation.ecrans.map(\.illustration)
            + t.conseils.map(\.illustration) + t.posesFeminines.flatMap { [$0.masculin, $0.feminin] }
            + t.personnage.appel + t.personnage.seance + t.personnage.joie + Array(t.personnage.moments.values)
        for nom in images {
            let url = Depot.racine.appendingPathComponent("ios/Ressources/Images/\(nom).webp")
            #expect(FileManager.default.fileExists(atPath: url.path), "\(nom) : absente de Images/")
        }
    }

    @Test func lesPolicesEtLeursSignesAbsents() throws {
        let p = try tables().polices
        #expect(p.map(\.cle) == ["serif", "sans", "arrondie", "frank", "david", "rachi", "miriam"])
        #expect(p.first { $0.cle == "sans" }?.fichiers == [])
        #expect(p.first { $0.cle == "serif" }?.fichiers == ["hebreu_serif_regular", "hebreu_serif_bold"])
        for f in p.flatMap(\.fichiers) {
            let url = Depot.racine.appendingPathComponent("ios/Ressources/Polices/\(f).ttf")
            #expect(FileManager.default.fileExists(atPath: url.path), "\(f)")
        }
        // Le meteg (U+05BD) est masqué dans Noto Serif Hebrew ; les te'amim dans Frank Ruhl.
        #expect(p.first { $0.cle == "serif" }?.absents == ["05BD"])
        #expect(p.first { $0.cle == "frank" }?.absents.contains("0591") == true)
    }
}
