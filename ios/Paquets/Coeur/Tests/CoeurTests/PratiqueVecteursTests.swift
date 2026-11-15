import Foundation
import Testing
@testable import Coeur

/// Les règles de la pratique devant la JVM (Tests/Vecteurs/pratique.json, tools/vecteurs_ios/VecteursPratique.kt) :
/// le code Kotlin d'Android a répondu, cas par cas, sur des balayages plus larges que ceux de ses tests — séances
/// sans début, horloges qui reculent, chiffres d'autres écritures, Float de Kotlin, changements d'heure de cinq
/// fuseaux, minuit qui n'existe pas à Santiago.
@Suite("Pratique devant la JVM")
struct PratiqueVecteursTests {

    private func vecteurs() throws -> ObjetJSON { try Depot.vecteurs("pratique.json") }

    private func lignes(_ cle: String) throws -> [[JSON]] {
        try vecteurs().tableau(cle)?.compactMap { valeur -> [JSON]? in
            if case .tableau(let r) = valeur { return r }
            return nil
        } ?? []
    }

    private func textes(_ cle: String) throws -> [[String]] {
        let liste = try vecteurs().tableau(cle) ?? []
        return liste.indices.map { liste.texte($0).components(separatedBy: "|") }
    }

    /// « 2026-11-02T00:30 » ou « 2026-11-02T23:59:59 », comme `LocalDateTime.toString()`.
    private func civile(_ texte: String) -> DateHeure? {
        let morceaux = texte.components(separatedBy: "T")
        guard morceaux.count == 2, let jour = JourCivil(iso: morceaux[0]) else { return nil }
        let h = morceaux[1].components(separatedBy: ":").compactMap { Int($0) }
        guard h.count >= 2 else { return nil }
        return DateHeure(jour, heure: h[0], minute: h[1], seconde: h.count > 2 ? h[2] : 0)
    }

    private func zone(_ id: String) throws -> Fuseau { try #require(Fuseau(id), "fuseau « \(id) » inconnu") }

    private func instant(_ r: [JSON], _ k: Int, _ fuseau: Fuseau) -> DateHeureZonee? {
        r.estNul(k) ? nil : DateHeureZonee(millis: r.long(k), fuseau: fuseau)
    }

    // MARK: Séance

    @Test func seances() throws {
        let cas = try textes("seances")
        #expect(cas.count == 136)
        for c in cas {
            let debut = Int64(c[0]) ?? -1, fin = Int64(c[1]) ?? -1, duree = Int(c[2]) ?? -1, maintenant = Int64(c[3]) ?? -1
            let obtenu = [
                "\(SessionRule.estOuverte(debut: debut, duree: duree))",
                "\(SessionRule.enCours(debut: debut, fin: fin, duree: duree, maintenant: maintenant))",
                "\(SessionRule.minutesEcoulees(debut: debut, maintenant: maintenant))",
                "\(SessionRule.minutesAInscrire(debut: debut, fin: fin, maintenant: maintenant))",
                "\(SessionRule.estEchue(debut: debut, fin: fin, duree: duree, maintenant: maintenant))",
                "\(SessionRule.minutesRestantes(fin: fin, maintenant: maintenant))",
            ]
            let attendu = Array(c[4...])
            #expect(obtenu == attendu, "\(c[0...3])")
        }
        for r in try lignes("compteurs") {
            #expect(SessionRule.compteur(ouverte: r.booleen(0), masque: r.booleen(1)).rawValue == r.texte(2))
        }
    }

    @Test func dureesSaisiesEtProposees() throws {
        let saisies = try lignes("durees_saisies")
        #expect(saisies.count == 34)
        for r in saisies {
            let attendu: Int? = r.estNul(1) ? nil : r.entier(1)
            #expect(DureeSeance.lire(r.texte(0)) == attendu, "« \(r.texte(0)) »")
        }
        let proposees = try vecteurs().tableau("durees_proposees") ?? []
        let attendues = proposees.indices.map { proposees.entier($0) }
        #expect(DureeSeance.proposees == attendues)
        for r in try lignes("durees_courtes") {
            #expect(JaugeSemaine.dureeCourte(r.entier(0)) == r.texte(1), "\(r.entier(0))")
        }
    }

    // MARK: Anneaux

    @Test func paliersEtAnneaux() throws {
        let paliers = try vecteurs().tableau("paliers") ?? []
        #expect(paliers.count == 1504)
        for i in paliers.indices {
            #expect(Anneaux.palier(i - 3) == paliers.entier(i), "série \(i - 3)")
        }
        for r in try lignes("anneaux") {
            let a = Anneaux.Anneau(quel: .jour, fait: r.entier(0), objectif: r.entier(1))
            let obtenu = [Double(a.fraction), Double(a.tours), Double(a.reste)]
            let attendu = [r.double(2), r.double(3), r.double(4)]
            #expect(obtenu == attendu, "\(r.entier(0)) sur \(r.entier(1))")
            #expect(a.atteint == r.booleen(5))
        }
        for r in try lignes("objectifs") {
            #expect(Anneaux.objectifEffectif(regle: r.entier(0), dureeHabituelle: r.entier(1)) == r.entier(2))
        }
    }

    @Test func etatsEtFetes() throws {
        let mercredi = JourCivil.du("2026-10-07")
        let cas = try lignes("etats")
        #expect(cas.count == 192)
        for r in cas {
            let e = Anneaux.etat(minutesJour: r.entier(0), objectifJour: r.entier(1),
                                 semaine: JaugeSemaine.Progression(faits: r.entier(2), dus: r.entier(3)), serie: r.entier(4))
            let titre = "\(r.entier(0))|\(r.entier(1))|\(r.entier(2))|\(r.entier(3))|\(r.entier(4))"
            for (k, a) in e.duCentre.enumerated() {
                let obtenu = "\(a.quel.rawValue) \(a.fait) \(a.objectif) \(Double(a.fraction))"
                let attendu = "\(r.texte(5 + 4 * k)) \(r.entier(6 + 4 * k)) \(r.entier(7 + 4 * k)) \(r.double(8 + 4 * k))"
                #expect(obtenu == attendu, "\(titre)")
            }
            let marques = r.tableau(17) ?? []
            let attendues = Set(marques.indices.map { marques.texte($0) })
            let deja = Anneaux.marques(e, aujourdhui: mercredi)
            #expect(deja == attendues, "\(titre)")
            for (rang, decalage) in [0, 1, 4].enumerated() {
                let jour = mercredi.plus(jours: decalage)
                let paire = r.tableau(18 + rang) ?? []
                let sans = paire.tableau(0) ?? [], avec = paire.tableau(1) ?? []
                let sansAttendu = sans.indices.map { sans.texte($0) }
                let avecAttendu = avec.indices.map { avec.texte($0) }
                let sansObtenu = Anneaux.aFeter(e, aujourdhui: jour, dejaFetes: []).map { $0.rawValue }
                let avecObtenu = Anneaux.aFeter(e, aujourdhui: jour, dejaFetes: deja).map { $0.rawValue }
                #expect(sansObtenu == sansAttendu, "\(titre) \(jour)")
                #expect(avecObtenu == avecAttendu, "\(titre) \(jour)")
            }
        }
    }

    @Test func jauges() throws {
        let dimanche = JourCivil.du("2026-09-27")
        for r in try lignes("jauges") {
            let cases = r.tableau(0) ?? []
            let jours = cases.indices.map { i in
                CaseSemaine(date: dimanche.plus(jours: i), faite: cases.texte(i).contains("f"),
                            exemptee: cases.texte(i).contains("x"), chabbat: i == 6, aVenir: false)
            }
            let p = JaugeSemaine.progression(jours)
            let obtenu = [Double(p.faits), Double(p.dus), Double(p.fraction)]
            let attendu = [r.double(1), r.double(2), r.double(3)]
            #expect(obtenu == attendu)
        }
    }

    // MARK: Plaque

    @Test func facesMoyennesEtMeilleuresSeries() throws {
        for r in try lignes("faces") {
            let face = try #require(Plaque.Face(rawValue: r.texte(0)))
            let anneau: String? = r.estNul(1) ? nil : r.texte(1)
            #expect(face.anneau?.rawValue == anneau)
            #expect(Plaque.suivante(face).rawValue == r.texte(2))
        }
        let faces = try lignes("faces")
        let ordre = faces.map { $0.texte(0) }
        let ordreSwift = Plaque.Face.allCases.map { $0.rawValue }
        #expect(ordre == ordreSwift)
        for r in try lignes("faces_anneaux") {
            let quel = try #require(Anneaux.Quel(rawValue: r.texte(0)))
            #expect(Plaque.pour(quel).rawValue == r.texte(1))
        }
        for r in try lignes("moyennes") {
            #expect(Plaque.moyenne(totalMinutes: r.entier(0), jours: r.entier(1)) == r.entier(2), "\(r.entier(0)) / \(r.entier(1))")
        }
        let origine = JourCivil.du("2026-01-01")
        let series = try lignes("meilleures_series")
        #expect(series.count == 150)
        for r in series {
            let f = r.tableau(0) ?? [], x = r.tableau(1) ?? []
            let faits = Set(f.indices.map { origine.plus(jours: f.entier($0)) })
            let exemptes = Set(x.indices.map { origine.plus(jours: x.entier($0)) })
            let samedi = r.booleen(2)
            let obtenu = Plaque.meilleureSerie(faits) { exemptes.contains($0) || (samedi && $0.jourDeSemaine == 7) }
            #expect(obtenu == r.entier(3))
        }
    }

    // MARK: Salutation, sujets, adresse

    @Test func salutations() throws {
        let cas = try lignes("salutations")
        #expect(cas.count == 26)
        for r in cas {
            let h = r.entier(0)
            let obtenu = [Salutation.partie(h).rawValue, "string/" + Salutation.mot(h), "string/" + Salutation.chaine(h)]
            #expect(obtenu == [r.texte(1), r.texte(2), r.texte(3)], "\(h) h")
        }
    }

    @Test func sujets() throws {
        let themes = try lignes("themes")
        let cles = themes.map { $0.texte(1) }
        let clesSwift = Theme.allCases.map { $0.cle }
        #expect(cles == clesSwift)
        for r in themes {
            let theme = try #require(Theme(rawValue: r.texte(1)))
            #expect(theme.rawValue.uppercased() == r.texte(0))
            #expect("string/" + theme.titre == r.texte(2))
        }
        for r in try lignes("themes_lus") {
            let cle: String? = r.estNul(0) ? nil : r.texte(0)
            let attendu: String? = r.estNul(1) ? nil : r.texte(1)
            #expect(ThemeRules.parse(cle)?.rawValue.uppercased() == attendu, "« \(cle ?? "null") »")
        }
        for r in try lignes("themes_frequents") {
            let l = r.tableau(0) ?? []
            let liste = l.indices.map { l.texte($0) }
            let obtenu = ThemeRules.frequents(liste, max: r.entier(1)).map { "\($0.theme.rawValue.uppercased()) \($0.compte)" }
            let a = r.tableau(2) ?? []
            let attendu = a.indices.map { i -> String in
                let paire = a.tableau(i) ?? []
                return "\(paire.texte(0)) \(paire.entier(1))"
            }
            #expect(obtenu == attendu, "\(liste)")
        }
    }

    @Test func adresses() throws {
        let noms: [Adresse: String] = [.homme: "HOMME", .femme: "FEMME"]
        for r in try lignes("adresses") {
            let cle: String? = r.estNul(0) ? nil : r.texte(0)
            let attendu: String? = r.estNul(1) ? nil : r.texte(1)
            let obtenu = Adresse.parse(cle).flatMap { noms[$0] }
            #expect(obtenu == attendu, "« \(cle ?? "null") »")
        }
        for r in try lignes("adresses_mots") {
            let adresse: Adresse? = r.estNul(0) ? nil : Adresse.allCases.first { noms[$0] == r.texte(0) }
            #expect("string/" + Adresse.bravo(pour: adresse) == r.texte(1))
            #expect("string/" + Adresse.hazak(pour: adresse) == r.texte(2))
            let nom = adresse.map { "string/" + $0.nom }
            let nomAttendu: String? = r.estNul(3) ? nil : r.texte(3)
            #expect(nom == nomAttendu)
        }
    }

    // MARK: Ce que Store.kt décide

    @Test func fenetres() throws {
        let d = JourCivil.du("2026-11-02")
        let jeux: [Set<JourCivil>] = [[], [d], [d.plus(jours: 1)], [d.plus(jours: -1)]]
        let cas = try textes("fenetres")
        #expect(cas.count == 378)
        for c in cas {
            let maintenant = try #require(civile(c[2]), "\(c[2])")
            let faitA = c[3] == "-" ? nil : civile(c[3])
            #expect(c[3] == "-" || faitA != nil, "\(c[3])")
            let obtenu = jeux.map { j -> String in
                let faite = Pratique.fenetreFaite(debut: Int(c[0]) ?? -1, fin: Int(c[1]) ?? -1, maintenant: maintenant,
                                                  faitA: faitA) { j.contains($0) }
                return faite ? "1" : "0"
            }.joined()
            #expect(obtenu == c[4], "\(c[0...3])")
        }
    }

    @Test func reprisesEtTikkun() throws {
        for r in try lignes("reprises") {
            let valable = Pratique.repriseValable(r.texte(0), quand: r.long(1), maintenant: r.long(2))
            #expect(valable == r.booleen(3), "\(r.texte(0)) \(r.long(1)) \(r.long(2))")
        }
        for r in try lignes("tikkun") {
            let t = try #require(civile(r.texte(0)), "\(r.texte(0))")
            #expect(Pratique.jourTikkun(t) == r.texte(1), "\(r.texte(0))")
        }
    }

    @Test func rappels() throws {
        let cas = try textes("rappels")
        #expect(cas.count == 120)
        for c in cas {
            let fuseau = try zone(c[0])
            let maintenant = DateHeureZonee(millis: Int64(c[1]) ?? 0, fuseau: fuseau)
            let heures = c[2].isEmpty ? [] : c[2].components(separatedBy: ",").compactMap { Int($0) }
            let p = ReminderRule.prochainDeclenchement(maintenant, heures: heures)
            let local = p.map { "\($0.jour.iso) " + String($0.civile.description.dropFirst(11).prefix(5)) }
            let millis = p.map { "\($0.millis)" } ?? "-"
            #expect(millis == c[3], "\(c[0]) \(c[1]) [\(c[2])]")
            #expect((local ?? "-") == c[4], "\(c[0]) \(c[1]) [\(c[2])]")
        }
    }

    @Test func vignettes() throws {
        let cas = try lignes("vignettes")
        #expect(cas.count == 108)
        for r in cas {
            let fuseau = try zone(r.texte(0))
            let maintenant = DateHeureZonee(millis: r.long(1), fuseau: fuseau)
            let h = r.tableau(2) ?? []
            let horaires = h.indices.map { instant(h, $0, fuseau) }
            let prochain = ZmanimVignette.prochainChangement(horaires, maintenant: maintenant, minuitTelephone: instant(r, 3, fuseau))
            #expect(prochain.millis == r.long(4), "\(r.texte(0)) \(r.long(1))")
        }
        for r in try lignes("vignettes_jours") {
            let fuseau = try zone(r.texte(0))
            let jour = ZmanimVignette.jourHebreuAffiche(DateHeureZonee(millis: r.long(1), fuseau: fuseau), tset: instant(r, 2, fuseau))
            #expect(jour.iso == r.texte(3))
        }
    }
}
