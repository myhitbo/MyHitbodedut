import Foundation
import Testing
@testable import Coeur

/// Le calendrier des prières et JourAffiche devant la JVM (audit halakhique du 16/11) :
/// `Tests/Vecteurs/calendrier.json`, écrit par tools/vecteurs_ios/VecteursCalendrier.kt. Les conditions déduites
/// (C.DERIVEES) de chaque jour de 5786 et 5787 en diaspora, en Israël et à Jérusalem, le Chabbat spécial, les
/// repères, la période sans musique, ce que SiddurJour.conditionsPour ajoute ou retire selon le noussa'h, les
/// ajouts de JourAffiche ; puis la note du Yom tov chéni, le Tikoun 'hatsot et Ra'hel, la prière ouvrable,
/// Ilanot, l'allumage à Jérusalem, la suggestion du siddour, les horaires du jour (à une seconde) et le jour
/// hébreu d'une prière.
@Suite("Calendrier des prières (vecteurs)")
struct CalendrierVecteursTests {

    private typealias C = CalendrierJuif.C

    private static let vecteurs: Result<ObjetJSON, any Error> = Result {
        try ObjetJSON(texte: String(decoding: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/calendrier.json"), as: UTF8.self))
    }

    private func v() throws -> ObjetJSON { try Self.vecteurs.get() }

    private static let nusahs: [Nusah] = [.edot, .sefard, .ashkenaz]

    private func textes(_ t: [JSON]?) -> [String] { (t ?? []).indices.map { (t ?? []).texte($0) } }

    private func optionnels(_ t: [JSON]?) -> [String?] {
        let t = t ?? []
        return t.indices.map { t.estNul($0) ? nil : t.texte($0) }
    }

    /// « +d3 -t5 » : ce que `apres` ajoute puis retire à `avant`, en rangs dans les listes.
    private func ecart(_ avant: Set<String>, _ apres: Set<String>) -> String {
        func code(_ c: String) -> String {
            if let i = C.derivees.firstIndex(of: c) { return "d\(i)" }
            if let k = C.toutes.firstIndex(of: c) { return "t\(k)" }
            return "?" + c
        }
        let plus = apres.subtracting(avant).map { "+" + code($0) }.sorted()
        let moins = avant.subtracting(apres).map { "-" + code($0) }.sorted()
        return (plus + moins).joined(separator: " ")
    }

    @Test func lesListesDeConditionsSontCellesDAndroid() throws {
        let v = try v()
        #expect(C.derivees == textes(v.tableau("derivees")))
        #expect(C.toutes == textes(v.tableau("toutes")))
    }

    @Test func chaqueJourChaqueLieuCommeSurAndroid() throws {
        let v = try v()
        let lieux = try #require(v.tableau("lieux"))
        let jours = try #require(v.tableau("jours"))
        #expect(jours.count > 750)
        var ecarts: [String] = []
        func note(_ ou: String, _ egal: Bool, _ detail: @autoclosure () -> String) {
            if !egal && ecarts.count < 40 { ecarts.append("\(ou) : \(detail())") }
        }
        for rang in jours.indices {
            let jour = try #require(jours.objet(rang))
            let date = JourCivil.du(jour.texte("date"))
            let musique: String? = jour.estNul("musique") ? nil : jour.texte("musique")
            note(date.iso, CalendrierJuif.periodeSansMusique(date) == musique, "musique")
            let parLieu = try #require(jour.tableau("lieux"))
            for k in lieux.indices {
                let lieu = try #require(lieux.objet(k)), attendu = try #require(parLieu.objet(k))
                let israel = lieu.booleen("israel"), muree = lieu.booleen("muree")
                let ou = "\(date.iso) \(lieu.texte("nom"))"
                let j = CalendrierJuif.jour(date, enIsrael: israel, mukafChoma: muree)
                let d = C.derivees.indices.filter { j.conditions.contains(C.derivees[$0]) }
                let dAttendus = (attendu.tableau("d") ?? []).indices.map { attendu.tableau("d")!.entier($0) }
                note(ou, d == dAttendus, "dérivées en trop \(Set(d).subtracting(dAttendus).map { C.derivees[$0] }.sorted()), "
                     + "manque \(Set(dAttendus).subtracting(d).map { C.derivees[$0] }.sorted())")
                let t = C.toutes.indices.filter { j.conditions.contains(C.toutes[$0]) }
                let tAttendus = (attendu.tableau("t") ?? []).indices.map { attendu.tableau("t")!.entier($0) }
                note(ou, t == tAttendus, "conditions \(t) au lieu de \(tAttendus)")
                let speciale: String? = attendu.estNul("s") ? nil : attendu.texte("s")
                note(ou, j.parachaSpeciale == speciale, "Chabbat spécial « \(j.parachaSpeciale ?? "nil") »")
                if let reperes = attendu.tableau("r") {
                    for (n, nusah) in Self.nusahs.enumerated() {
                        let lus = CalendrierJuif.reperes(date, enIsrael: israel, nusah: nusah.rawValue)
                        note(ou, lus == textes(reperes.tableau(n)), "repères \(nusah.rawValue) \(lus)")
                    }
                }
                let p = textes(attendu.tableau("p"))
                for (n, nusah) in Self.nusahs.enumerated() {
                    let e = ecart(j.conditions, SiddurJour.conditionsPour(nusah, enIsrael: israel, j.conditions))
                    note(ou, n < p.count && e == p[n], "conditionsPour \(nusah.rawValue) « \(e) »")
                }
                let pa = textes(attendu.tableau("pa"))
                let autres = [
                    ecart(j.conditions, SiddurJour.conditionsPour(.edot, enIsrael: israel, j.conditions, sansTahanounFinTichri: false)),
                    ecart(j.conditions, SiddurJour.conditionsPour(.sefard, enIsrael: israel, j.conditions, sansTahanounFinTichri: true)),
                    ecart(j.conditions, SiddurJour.conditionsPour(.edot, enIsrael: israel, j.conditions, sud: true)),
                    ecart(j.conditions, SiddurJour.conditionsPour(.ashkenaz, enIsrael: israel,
                                                                  SiddurJour.avecSansTahanoun(j.conditions, true))),
                ]
                note(ou, autres == pa, "conditionsPour (variantes) \(autres)")
                let a = attendu.tableau("a") ?? []
                var ajouts = Self.nusahs.map { JourAffiche.ajouts(j.conditions, nusah: $0, enIsrael: israel) }
                ajouts.append(JourAffiche.ajouts(SiddurJour.avecSansTahanoun(j.conditions, true), nusah: .ashkenaz, enIsrael: israel))
                note(ou, ajouts == a.indices.map { textes(a.tableau($0)) }, "ajouts \(ajouts)")
            }
        }
        #expect(ecarts.isEmpty, "\(ecarts.joined(separator: "\n"))")
    }

    @Test func lAfficheDuJourCommeSurAndroid() throws {
        let v = try v()
        let affiche = try #require(v.tableau("affiche"))
        var ecarts: [String] = []
        for rang in affiche.indices {
            let o = try #require(affiche.objet(rang))
            let date = JourCivil.du(o.texte("date"))
            var ytc: [String?] = []
            for (statut, lieu) in [(true, false), (false, true)] {
                for n in Self.nusahs { ytc.append(JourAffiche.noteYomTovCheni(date, statutIsrael: statut, lieuEnIsrael: lieu, nusah: n)) }
            }
            if ytc != optionnels(o.tableau("ytc")) { ecarts.append("\(date.iso) : Yom tov chéni \(ytc)") }
            let sans = [JourAffiche.sansTikounHatsot(date, enIsrael: false), JourAffiche.sansTikounHatsot(date, enIsrael: true)]
            let sansAttendus = (o.tableau("sansTikoun") ?? []).indices.map { o.tableau("sansTikoun")!.booleen($0) }
            if sans != sansAttendus { ecarts.append("\(date.iso) : sans Tikoun \(sans)") }
            let rahel = Self.nusahs.map { JourAffiche.tikounRahelDeMidi(date, nusah: $0) }
            if rahel != (o.tableau("rahel") ?? []).indices.map({ o.tableau("rahel")!.booleen($0) }) {
                ecarts.append("\(date.iso) : Tikoun Ra'hel \(rahel)")
            }
            var ouvrable: [String?] = []
            for israel in [false, true] {
                for (m, h) in [("chaharit", 8), ("minha", 14), ("arvit", 20), ("birkot_hachahar", 6)] {
                    ouvrable.append(JourAffiche.momentOuvrable(m, date: date, heure: h, enIsrael: israel))
                }
            }
            if ouvrable != optionnels(o.tableau("ouvrable")) { ecarts.append("\(date.iso) : prière ouvrable \(ouvrable)") }
            var ilanot: [Bool] = []
            for lat in [32.0, -33.0] {
                for n in [nil, Nusah.edot, .sefard, .ashkenaz] { ilanot.append(SiddurMoment.ilanot(date, latitude: lat, nusah: n)) }
            }
            if ilanot != (o.tableau("ilanot") ?? []).indices.map({ o.tableau("ilanot")!.booleen($0) }) {
                ecarts.append("\(date.iso) : Ilanot \(ilanot)")
            }
        }
        #expect(ecarts.isEmpty, "\(ecarts.prefix(30).joined(separator: "\n"))")
    }

    @Test func laLigneDeDateLAllumageEtLaSuggestion() throws {
        let v = try v()
        let ligne = try #require(v.tableau("ligneDate"))
        for k in ligne.indices {
            let t = try #require(ligne.tableau(k))
            #expect(JourAffiche.ligneDateDiscutee(t.double(0)) == t.booleen(1), "\(t.double(0))")
        }
        let allumage = try #require(v.tableau("allumage"))
        for k in allumage.indices {
            let t = try #require(allumage.tableau(k))
            let n = try #require(Nusah(rawValue: t.texte(0)))
            let proposition: String? = t.estNul(3) ? nil : t.texte(3)
            #expect(JourAffiche.propositionAllumage(nusah: n, mukafChoma: t.booleen(1), minutes: t.entier(2)) == proposition, "\(t)")
            #expect(JourAffiche.coutumeJerusalem(nusah: n, mukafChoma: t.booleen(1), minutes: t.entier(2)) == t.booleen(4), "\(t)")
        }
        let suggestion = try #require(v.tableau("suggestion"))
        for k in suggestion.indices {
            let t = try #require(suggestion.tableau(k))
            let minutes = t.entier(0)
            let rendue = SiddurMoment.suggestion(heure: minutes / 60, minute: minutes % 60, sansTikoun: t.booleen(1))
            #expect(rendue == t.texte(2), "\(minutes) min, \(t.booleen(1))")
        }
        let priere = try #require(v.tableau("jourDeLaPriere"))
        let d = JourCivil.du("2026-11-17")
        for k in priere.indices {
            let t = try #require(priere.tableau(k))
            let jour = CalendrierJuif.jourDeLaPriere(t.texte(0), date: d, heure: t.entier(1), apresSortie: t.booleen(2))
            #expect(jour.jourJulien - d.jourJulien == t.entier(3), "\(t)")
        }
        let nuit = try #require(v.tableau("nuit"))
        for k in nuit.indices {
            let t = try #require(nuit.tableau(k))
            let apres: Bool? = t.estNul(1) ? nil : t.booleen(1)
            let avant: Bool? = t.estNul(2) ? nil : t.booleen(2)
            #expect(CalendrierJuif.nuit(heure: t.entier(0), apresSortie: apres, avantAube: avant) == t.booleen(3), "\(t)")
        }
    }

    private static let lieux: [String: Zmanim.Lieu] = [
        "Jérusalem": Zmanim.Lieu(nom: "Jérusalem", latitude: 31.76904, longitude: 35.21633, fuseau: "Asia/Jerusalem"),
        "Paris": Zmanim.Lieu(nom: "Paris", latitude: 48.85341, longitude: 2.3488, fuseau: "Europe/Paris"),
        "Londres": Zmanim.Lieu(nom: "Londres", latitude: 51.50853, longitude: -0.12574, fuseau: "Europe/London"),
        "New York": Zmanim.Lieu(nom: "New York", latitude: 40.71427, longitude: -74.00597, fuseau: "America/New_York"),
    ]

    /// Les horaires du jour (entrée, sortie, jeûne, 'hamets), profil commun et Edot : chaque ligne, sa méthode et
    /// son statut à l'identique, son instant à une seconde.
    @Test func lesHorairesDuJourCommeSurAndroid() throws {
        let horaires = try #require(try v().tableau("horaires"))
        #expect(horaires.count > 300)
        var ecarts: [String] = []
        for k in horaires.indices {
            let o = try #require(horaires.objet(k))
            let lieu = try #require(Self.lieux[o.texte("lieu")])
            let nusah: Nusah? = o.texte("nusah") == "edot" ? .edot : nil
            let ou = "\(o.texte("lieu")) \(o.texte("date")) \(o.booleen("israel") ? "Israël" : "diaspora") \(o.texte("nusah"))"
            let lignes = JourAffiche.horaires(lieu: lieu, date: .du(o.texte("date")), enIsrael: o.booleen("israel"), minutes: 18,
                                              nusah: nusah)
            let attendues = o.tableau("lignes") ?? []
            if lignes.count != attendues.count {
                ecarts.append("\(ou) : \(lignes.map(\.cle)) au lieu de \(attendues.indices.map { attendues.tableau($0)?.texte(0) ?? "" })")
                continue
            }
            for (z, i) in zip(lignes, attendues.indices) {
                guard let a = attendues.tableau(i) else { continue }
                let memes = z.cle == a.texte(0) && z.methode.cle == a.texte(1) && z.methode.parametres == a.texte(2)
                    && z.statut.rawValue.uppercased() == a.texte(3)
                var proche = a.estNul(4) == (z.instant == nil)
                if let instant = z.instant, !a.estNul(4) {
                    proche = abs(instant.timeIntervalSince1970 * 1000 - Double(a.long(4))) <= 1000
                }
                if !memes || !proche { ecarts.append("\(ou) : \(z.cle) \(z.methode) \(z.statut) \(String(describing: z.instant)) contre \(a)") }
            }
        }
        #expect(ecarts.isEmpty, "\(ecarts.prefix(20).joined(separator: "\n"))")
    }

    /// La suggestion du siddour toutes les heures (à la 17ᵉ minute), d'après les zmanim du lieu.
    @Test func laSuggestionDuSiddourCommeSurAndroid() throws {
        let moments = try #require(try v().tableau("moments"))
        for k in moments.indices {
            let o = try #require(moments.objet(k))
            let lieu = try #require(Self.lieux[o.texte("lieu")])
            let nusah = try #require(Nusah(rawValue: o.texte("nusah")))
            let instants = o.tableau("instants") ?? []
            let attendus = optionnels(o.tableau("moments"))
            for (i, attendu) in zip(instants.indices, attendus) {
                let maintenant = Date(timeIntervalSince1970: Double(instants.long(i)) / 1000)
                let rendu = JourAffiche.momentDuSiddour(lieu: lieu, maintenant: maintenant,
                                                        enIsrael: lieu.fuseau == "Asia/Jerusalem", nusah: nusah)
                #expect(rendu == attendu, "\(o.texte("lieu")) \(o.texte("date")) \(nusah.rawValue), \(i) h 17")
            }
        }
    }
}
