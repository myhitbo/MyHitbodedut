import Foundation
import Testing
@testable import Coeur

/// Paliers, trophées et règles de texte devant la JVM (Tests/Vecteurs/recompenses.json,
/// tools/vecteurs_ios/VecteursRecompenses.kt) : vingt-quatre historiques tirés au hasard (jours chômés, notes,
/// Tikoun) rendus en trophées, dates de gain, paliers et bilans ; toutes les références des données dans les trois
/// langues ; les nombres de 1 à 999 ; l'aération de paragraphes du siddour ; le mélange et la danse.
@Suite("Récompenses devant la JVM")
struct RecompensesVecteursTests {

    private func vecteurs() throws -> ObjetJSON { try Depot.vecteurs("recompenses.json") }

    private func lignes(_ cle: String) throws -> [[JSON]] {
        try vecteurs().tableau(cle)?.compactMap { valeur -> [JSON]? in
            if case .tableau(let r) = valeur { return r }
            return nil
        } ?? []
    }

    private func textes(_ t: [JSON]?) -> [String] {
        guard let t else { return [] }
        return t.indices.map { t.texte($0) }
    }

    private func entiers(_ t: [JSON]?) -> [Int] {
        guard let t else { return [] }
        return t.indices.map { t.entier($0) }
    }

    @Test func paliers() throws {
        let cas = try lignes("paliers")
        #expect(cas.count == 6 * 67 * 2)
        for r in cas {
            let piste = try #require(Paliers.Piste(rawValue: r.texte(0)))
            let e = Paliers.etat(piste, r.entier(1), objectifJour: r.entier(2))
            let obtenu = [Double(e.atteint), Double(e.prochain), Double(e.rang), Double(e.avancee)]
            let attendu = [r.double(3), r.double(4), r.double(5), r.double(6)]
            #expect(obtenu == attendu, "\(r.texte(0)) \(r.entier(1)) \(r.entier(2))")
        }
    }

    @Test func historiques() throws {
        let v = try vecteurs()
        let origine = JourCivil.du(v.objet("_meta")?.texte("origine") ?? "")
        let historiques = (v.tableau("historiques") ?? []).compactMap { valeur -> ObjetJSON? in
            if case .objet(let o) = valeur { return o }
            return nil
        }
        #expect(historiques.count == 24)
        for (k, h) in historiques.enumerated() {
            func jour(_ n: Int) -> JourCivil { origine.plus(jours: n) }
            var minutes: [JourCivil: Int] = [:]
            for case .tableau(let p) in h.tableau("minutes") ?? [] { minutes[jour(p.entier(0))] = p.entier(1) }
            let notes = Set(entiers(h.tableau("notes")).map(jour))
            let tikkun = Set(entiers(h.tableau("tikkun")).map(jour))
            let samedi = h.booleen("samedi")
            let exempte = { (d: JourCivil) in samedi && d.jourDeSemaine == 7 }
            let serie = Plaque.meilleureSerie(Set(minutes.keys), exempte: exempte)
            #expect(serie == h.entier("serie"), "historique \(k)")
            let p = Trophees.Pratique(minutes: minutes, notes: notes.count, meilleureSerie: serie, tikkun: tikkun)
            let valeurs = Trophees.Famille.allCases.map { Trophees.valeur(p, $0) }
            #expect(valeurs == entiers(h.tableau("valeurs")), "historique \(k)")
            let progres = Trophees.Famille.allCases.map { f -> [Int] in
                let pr = Trophees.progres(p, f)
                return [pr.valeur, pr.cible]
            }
            let progresAttendus = (h.tableau("progres") ?? []).map { j -> [Int] in
                if case .tableau(let t) = j { return entiers(t) }
                return []
            }
            #expect(progres == progresAttendus, "historique \(k)")
            let gagnes = Trophees.gagnes(p)
            #expect(gagnes.map { $0.cle }.sorted() == textes(h.tableau("gagnes")), "historique \(k)")
            let prochain = Trophees.prochain(p)?.cle
            #expect(prochain == (h.estNul("prochain") ? nil : h.texte("prochain")), "historique \(k)")
            let proches = Trophees.plusProches(p).map { $0.cle }
            #expect(proches == textes(h.tableau("proches")), "historique \(k)")
            let proche = Trophees.proche(p)?.cle
            #expect(proche == (h.estNul("proche") ? nil : h.texte("proche")), "historique \(k)")
            // Les gagnés dans l'ordre de Kotlin (famille, puis rang), un sur trois déjà vu.
            let ordonnes = gagnes.sorted { ($0.famille.rang, $0.rang) < ($1.famille.rang, $1.rang) }.map { $0.cle }
            let tropheesVus = Set(ordonnes.enumerated().filter { $0.offset % 3 == 0 }.map { $0.element })
            let lesVus: [Set<String>?] = [nil, [], ["chai"], tropheesVus]
            let nouveaux = lesVus.map { vus in Trophees.nouveaux(gagnes, vus: vus).map { $0.cle } }
            let nouveauxAttendus = (h.tableau("nouveaux") ?? []).map { j -> [String] in
                if case .tableau(let t) = j { return textes(t) }
                return []
            }
            #expect(nouveaux == nouveauxAttendus, "historique \(k)")
            let dates = Trophees.datesGain(minutes, notes: notes, tikkun: tikkun, exempte: exempte)
            let datesObtenues = dates.keys.sorted().map { "\($0) \(dates[$0]?.iso ?? "")" }
            let datesAttendues = (h.tableau("dates") ?? []).map { j -> String in
                if case .tableau(let t) = j { return "\(t.texte(0)) \(jour(t.entier(1)).iso)" }
                return ""
            }
            #expect(datesObtenues == datesAttendues, "historique \(k)")

            // Les paliers du jour « aujourdhui ».
            let b = entiers(h.tableau("bilan"))
            let aujourdhui = jour(h.entier("aujourdhui"))
            let bilan = Paliers.Bilan(aujourdhui: aujourdhui, minutes: minutes, serie: b[0], debutMoisHebreu: jour(b[1]),
                                      objectifJour: b[2])
            let etats = Paliers.etats(bilan)
            let etatsObtenus = etats.map { "\($0.piste.cle) \($0.valeur) \($0.atteint) \($0.prochain) \($0.rang)" }
            let etatsAttendus = (h.tableau("etats") ?? []).map { j -> String in
                if case .tableau(let t) = j { return "\(t.texte(0)) \(t.entier(1)) \(t.entier(2)) \(t.entier(3)) \(t.entier(4))" }
                return ""
            }
            #expect(etatsObtenus == etatsAttendus, "historique \(k)")
            let marques = Paliers.marques(etats, bilan)
            #expect(marques.sorted() == textes(h.tableau("marques")), "historique \(k)")
            let vus = Set(textes(h.tableau("vus")))
            let nouveauxPaliers = Paliers.nouveaux(etats, bilan, vus: vus).map { $0.piste.cle }
            #expect(nouveauxPaliers == textes(h.tableau("nouveaux_paliers")), "historique \(k)")
            #expect(Paliers.aLaUne(etats)?.piste.cle == h.texte("a_la_une"), "historique \(k)")
            let r = Paliers.records(minutes) { "\($0.annee)-\($0.mois)" }
            #expect([r.jour, r.semaine, r.mois] == entiers(h.tableau("records")), "historique \(k)")
            let semaine = BilanSemaine.precedente(aujourdhui, minutes: minutes, dates: dates)
            if h.estNul("semaine") {
                #expect(semaine == nil, "historique \(k)")
            } else {
                let s = h.tableau("semaine") ?? []
                let obtenu = semaine.map { "\($0.debut.iso) \($0.minutes) \($0.jours) \($0.precedente) \($0.record) \($0.trophees.map { $0.cle })" }
                let attendu = "\(jour(s.entier(0)).iso) \(s.entier(1)) \(s.entier(2)) \(s.entier(3)) \(s.booleen(4)) \(textes(s.tableau(5)))"
                #expect(obtenu == attendu, "historique \(k)")
            }
        }
    }

    @Test func referencesEtLettres() throws {
        let refs = try lignes("references")
        #expect(refs.count > 60)
        for r in refs {
            let ref = r.texte(0)
            let obtenu = "\(Reference.connue(ref))|\(Reference.localise(ref, "en"))|\(Reference.localise(ref, "iw"))|\(Reference.localise(ref, "fr"))"
            let attendu = "\(r.booleen(1))|\(r.texte(2))|\(r.texte(3))|\(r.texte(4))"
            #expect(obtenu.egalUnites(attendu), "« \(ref) » : \(obtenu)")
        }
        let lettres = try vecteurs().tableau("lettres") ?? []
        #expect(lettres.count == 1002)
        for i in lettres.indices {
            #expect(Reference.lettres(i - 1).egalUnites(lettres.texte(i)), "\(i - 1)")
        }
    }

    @Test func langues() throws {
        for r in try lignes("langues") {
            let l: String? = r.estNul(0) ? nil : r.texte(0)
            let permises = RegleLangue.permises(l ?? "").sorted()
            let obtenu = "\(RegleLangue.normalise(l)) \(permises) \(RegleLangue.traduit(l ?? "")) \(LanguesTexte.defaut(l ?? "").cle)"
            let attendu = "\(r.texte(1)) \(textes(r.tableau(2))) \(r.booleen(3)) \(r.texte(4))"
            #expect(obtenu == attendu, "« \(l ?? "null") »")
        }
        for r in try lignes("replis") {
            let repli = LangueApp.repli(textes(r.tableau(0)))
            #expect(repli == (r.estNul(1) ? nil : r.texte(1)))
        }
        for r in try lignes("textes") {
            let mode = try #require(LanguesTexte.Mode(rawValue: r.texte(0)))
            let fr: String? = r.estNul(2) ? nil : r.texte(2)
            let en: String? = r.estNul(3) ? nil : r.texte(3)
            let rendus = LanguesTexte.textes(mode, he: r.texte(1), fr: fr, en: en).map { "\($0.langue)=\($0.texte)" }
            let attendus = (r.tableau(4) ?? []).map { j -> String in
                if case .tableau(let t) = j { return "\(t.texte(0))=\(t.texte(1))" }
                return ""
            }
            #expect(rendus == attendus, "\(r.texte(0))")
            #expect(LanguesTexte.manque(mode, aTraduction: true) == r.booleen(5))
            #expect(LanguesTexte.manque(mode, aTraduction: false) == r.booleen(6))
        }
    }

    @Test func aerationEtApercus() throws {
        let cas = try lignes("aeration")
        #expect(cas.count == 30)
        for r in cas {
            let t = r.texte(0)
            #expect(Aeration.psaume(t) == r.booleen(1), "\(t.premieresUnites(40))")
            #expect(Aeration.aerer(t).egalUnites(r.texte(2)), "\(t.premieresUnites(40))")
            #expect(MarquesPages.apercu(t).egalUnites(r.texte(3)), "\(t.premieresUnites(40))")
        }
    }

    @Test func melangesEtDanse() throws {
        for r in try lignes("melanges") {
            let graine = Int32(r.entier(0))
            let ids = (1...r.entier(1)).map { $0 < 10 ? "m0\($0)" : "m\($0)" }
            var m = MelangeMusique(hasard: HasardKotlin(graine: graine))
            let suite = (0..<(ids.count * 3)).map { _ in m.suivant(ids) ?? "" }
            #expect(suite == textes(r.tableau(2)), "graine \(graine)")
        }
        for r in try lignes("danse") {
            let t = Float(r.double(0))
            let p = DanseMesure.pas(t)
            let obtenu = [Double(p.hauteur), Double(p.flexion), Double(p.balance), Double(p.poseB)]
            let attendu = [r.double(1), r.double(2), r.double(3), r.double(4)]
            // sin de la JVM et celui de la libm peuvent différer d'une unité au dernier chiffre.
            let ecart = zip(obtenu, attendu).map { abs($0 - $1) }.max() ?? 0
            #expect(ecart <= 1e-6, "\(t) : \(obtenu) au lieu de \(attendu)")
        }
    }
}
