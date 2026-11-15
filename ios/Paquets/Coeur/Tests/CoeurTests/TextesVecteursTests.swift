import Foundation
import Testing
@testable import Coeur

/// Les textes de prière devant la JVM (Tests/Vecteurs/textes.json, tools/vecteurs_ios/VecteursTextes.kt) : le code
/// Kotlin d'Android a répondu sur des balayages plus larges que ceux de ses tests. Le jour hébreu et la longueur du
/// mois de chaque jour de 1950 à 2099 (KosherJava d'un côté, l'arithmétique de Tehilim.swift de l'autre : ICU, le
/// calendrier hébreu de Foundation, se trompe d'un jour d'octobre 2045 à novembre 2046), la
/// portion de chaque jour du mois et de la semaine, les versets de chaque portion, les traductions, la coupe d'un
/// verset en unités UTF-16 (voyelles, espaces d'Unicode), les lignes de l'écran Tfilot, les bornes de la hitbodedout
/// guidée et des questions. Puis les tables du Kotlin (tables.json) que les sources Swift recopient.
@Suite("Textes devant la JVM")
struct TextesVecteursTests {

    private func vecteurs() throws -> ObjetJSON { try Depot.vecteurs("textes.json") }

    private func tables() throws -> ObjetJSON { try Depot.vecteurs("tables.json") }

    private func lireLivre() throws -> Tehilim { try Tehilim.lire(Depot.contenu("tehilim.json")) }

    private func lignes(_ cle: String) throws -> [[JSON]] {
        try vecteurs().tableau(cle)?.compactMap { valeur -> [JSON]? in
            if case .tableau(let r) = valeur { return r }
            return nil
        } ?? []
    }

    /// Quatre colonnes à partir de `k` : début, fin, premier verset, dernier verset (null : jusqu'au bout).
    private func portion(_ r: [JSON], _ k: Int) -> Portion {
        Portion(r.entier(k), r.entier(k + 1), r.entier(k + 2), r.estNul(k + 3) ? nil : r.entier(k + 3))
    }

    private func texte(_ ligne: TefilotRules.Ligne) -> String {
        switch ligne {
        case let .titre(sujet, nombre):
            return "titre \(sujet.cle) \(nombre)"
        case let .priere(sujet, entree):
            return "priere \(sujet.cle) \(entree.id)" + (TefilotRules.prevenir(entree) ? " prevenir" : "")
        }
    }

    // MARK: Le cycle de Tehilim

    @Test func leJourHebreuEtLaLongueurDuMoisDeChaqueJour() throws {
        let premiers = try vecteurs().textes("moisHebreux").map { $0.components(separatedBy: " ") }
        #expect(premiers.count > 1_800)
        var fautes: [String] = []
        var jours = 0
        for (rang, p) in premiers.enumerated() {
            guard p.count == 2, let debut = JourCivil(iso: p[0]), let longueur = Int(p[1]) else {
                fautes.append("ligne illisible : \(p)")
                continue
            }
            if rang + 1 < premiers.count, let iso = premiers[rang + 1].first, let suivant = JourCivil(iso: iso),
               suivant.jourJulien - debut.jourJulien != longueur {
                fautes.append("\(p[0]) : le mois suivant commence le \(iso)")
            }
            for k in 0..<longueur {
                let d = debut.plus(jours: k)
                let h = CycleTehilim.jourHebreu(d)
                if h.jour != k + 1 || h.longueur != longueur {
                    fautes.append("\(d.iso) : \(h.jour)/\(h.longueur) au lieu de \(k + 1)/\(longueur)")
                }
                jours += 1
            }
        }
        #expect(fautes.isEmpty, "\(fautes.prefix(20))")
        #expect(jours > 54_000)
        for r in try lignes("jourHebreu") {
            let h = CycleTehilim.jourHebreu(JourCivil.du(r.texte(0)))
            #expect(h.jour == r.entier(1) && h.longueur == r.entier(2), "\(r.texte(0)) : \(h.jour)/\(h.longueur)")
        }
    }

    @Test func laPortionDuJourDuMois() throws {
        let cas = try lignes("duMois")
        #expect(cas.count == 68)
        for r in cas {
            let obtenue = CycleTehilim.duMois(r.entier(0), longueur: r.entier(1))
            let attendue = portion(r, 2)
            #expect(obtenue == attendue, "\(r.entier(0))/\(r.entier(1))")
        }
    }

    @Test func laPortionDuJourDeLaSemaine() throws {
        let cas = try lignes("deLaSemaine")
        #expect(cas.count == 7)
        for r in cas {
            let date = JourCivil.du(r.texte(0))
            let obtenue = CycleTehilim.deLaSemaine(date)
            let attendue = portion(r, 1)
            #expect(obtenue == attendue, "\(r.texte(0))")
            // Un nombre hors de 1 à 7 revient dans la semaine, par le reste de sa division par 7.
            let ramenee = CycleTehilim.deLaSemaine(jourDeSemaine: date.jourDeSemaine + 7 * 3)
            let enArriere = CycleTehilim.deLaSemaine(jourDeSemaine: date.jourDeSemaine - 7 * 5)
            #expect(ramenee == attendue && enArriere == attendue, "\(r.texte(0))")
        }
        let samedi = CycleTehilim.deLaSemaine(jourDeSemaine: 0)
        #expect(samedi == Portion(120, 150))
    }

    @Test func lesVersetsDeChaquePortion() throws {
        let livre = try lireLivre()
        let portions = try vecteurs().objets("portions")
        #expect(portions.count == 39)
        for o in portions {
            let p = portion(o.tableau("portion") ?? [], 0)
            let bornes = o.tableau("psaumes") ?? []
            let premier = bornes.entier(0), dernier = bornes.entier(1)
            #expect(p.psaumes == premier..<max(premier, dernier + 1), "\(p)")
            #expect(p.partielle == o.booleen("partielle"), "\(p)")
            for ligne in o.textes("versets") {
                let c = ligne.components(separatedBy: " ").compactMap { Int($0) }
                try #require(c.count == 3, "« \(ligne) »")
                let v = p.versets(c[0], total: livre.versets(c[0]).count)
                #expect(v == c[1]..<max(c[1], c[2] + 1), "\(p) : psaume \(c[0]), \(v)")
            }
        }
    }

    // MARK: Le livre

    @Test func lesPsaumesEtLeursTraductions() throws {
        let livre = try lireLivre()
        let v = try vecteurs()
        #expect(livre.versetsTotal == v.entier("versetsTotal"))
        let attendus = v.tableau("versetsParPsaume") ?? []
        let comptes = (-1...152).map { livre.versets($0).count }
        let comptesAttendus = attendus.indices.map { attendus.entier($0) }
        #expect(comptes == comptesAttendus)
        for r in try lignes("traductions") {
            let t = livre.traduction(r.texte(0), psaume: r.entier(1), verset: r.entier(2))
            let ou = "\(r.texte(0)) \(r.entier(1)):\(r.entier(2))"
            if r.estNul(3) {
                #expect(t == nil, "\(ou)")
            } else {
                #expect(t?.egalUnites(r.texte(3)) == true, "\(ou) : « \(t ?? "nil") »")
            }
        }
        for r in try lignes("traductionsPresentes") {
            var presentes = 0
            for p in 1...Tehilim.nombreDePsaumes {
                for verset in stride(from: 1, through: livre.versets(p).count, by: 1) where livre.traduction(r.texte(0), psaume: p, verset: verset) != nil {
                    presentes += 1
                }
            }
            #expect(presentes == r.entier(1), "\(r.texte(0))")
        }
    }

    // MARK: Le Tikoun

    @Test func laCoupeDUnVerset() throws {
        let cas = try lignes("coupes")
        #expect(cas.count >= 16)
        for r in cas {
            let arret = r.estNul(1) ? nil : Arret(avant: r.texte(1), note: "")
            let coupe = Verset(numero: 1, he: r.texte(0), arret: arret).coupe()
            let ou = "« \(r.texte(0)) » avant « \(r.texte(1)) »"
            if r.estNul(2) {
                #expect(coupe == nil, "\(ou)")
            } else {
                let c = try #require(coupe, "\(ou) : pas de coupe")
                #expect(c.avant.egalUnites(r.texte(2)), "\(ou) : « \(c.avant) »")
                #expect(c.apres.egalUnites(r.texte(3)), "\(ou) : « \(c.apres) »")
            }
        }
    }

    // MARK: Tfilot

    @Test func lesLignesDeLEcranTfilot() throws {
        let bibliotheque = try JSONDecoder().decode(Bibliotheque.self, from: Depot.contenu("bibliotheque.json"))
        let obtenues = TefilotRules.lignes(bibliotheque).map { texte($0) }
        let v = try vecteurs()
        let attendues = v.textes("tefilot")
        #expect(obtenues == attendues)
        let essai = try #require(v.objet("tefilotEssai"))
        let petite = try JSONDecoder().decode(Bibliotheque.self, from: Data(essai.texte("json").utf8))
        let lignesEssai = TefilotRules.lignes(petite).map { texte($0) }
        let attenduesEssai = essai.textes("lignes")
        #expect(lignesEssai == attenduesEssai)
        let prieres = TefilotRules.prieres(petite).map(\.id)
        #expect(prieres == ["z1", "inconnu", "sans", "blanc", "h1", "z2", "r1", "majuscule"])
    }

    // MARK: La hitbodedout guidée et les questions

    @Test func lesBornesDeLaHitbodedoutEtDesQuestions() throws {
        let temps = try lignes("hitbodedut")
        #expect(temps.count == 12)
        for r in temps {
            let i = r.entier(0)
            #expect(Hitbodedut.mouvement(i).cle == r.texte(1), "\(i)")
            #expect(Hitbodedut.suivant(i) == r.entier(2), "\(i)")
            #expect(Hitbodedut.precedent(i) == r.entier(3), "\(i)")
            #expect(Hitbodedut.estPremier(i) == r.booleen(4), "\(i)")
            #expect(Hitbodedut.estDernier(i) == r.booleen(5), "\(i)")
        }
        let questions = try lignes("questions")
        #expect(questions.count == 25)
        for r in questions {
            #expect(QuestionsBlocage.suivante(r.entier(0)) == r.entier(1), "\(r.entier(0))")
        }
    }

    // MARK: Les tables du Kotlin

    @Test func lesTablesRecopieesSontCellesDuKotlin() throws {
        let t = try tables()
        let tehilim = try #require(t.objet("tehilim"))
        for (cle, recopiees) in [("mois", CycleTehilim.mois), ("semaine", CycleTehilim.semaine)] {
            let lues = tehilim.objets(cle).map {
                Portion($0.entier("debut"), $0.entier("fin"), $0.entier("debutVerset"),
                        $0.estNul("finVerset") ? nil : $0.entier("finVerset"))
            }
            #expect(lues == recopiees, "\(cle)")
        }
        let tikkun = t.tableau("tikkun") ?? []
        let ordre = tikkun.indices.map { tikkun.entier($0) }
        #expect(ordre == Tikkun.ordre)
        let sujets = t.objets("sujetsTefila").map { "\($0.texte("cle")) \($0.texte("titre"))" }
        let sujetsSwift = SujetTefila.allCases.map { "\($0.cle) string/\($0.titre)" }
        #expect(sujets == sujetsSwift)
        let questions = t.textes("questions")
        let questionsSwift = QuestionsBlocage.questions.map { "string/" + $0 }
        #expect(questions == questionsSwift)
        let temps = t.objets("hitbodedut")
        #expect(temps.count == Hitbodedut.mouvements.count)
        for (o, m) in zip(temps, Hitbodedut.mouvements) {
            #expect(o.texte("cle") == m.cle)
            #expect(o.texte("he").egalUnites(m.he), "« \(m.cle) » : l'hébreu n'est pas celui du Kotlin")
            #expect(o.texte("titre") == "string/" + m.titre, "« \(m.cle) »")
            #expect(o.texte("invite") == "string/" + m.invite, "« \(m.cle) »")
            #expect(o.texte("illustration") == "drawable/" + m.illustration, "« \(m.cle) »")
            #expect(o.texte("source") == m.source, "« \(m.cle) »")
        }
    }
}
