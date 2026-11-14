import Foundation
import Testing
@testable import Coeur

/// Les livres et la table des textes du jour, lus une fois pour toutes les suites.
enum Corpus {
    static let halakha: Result<Halakha.Livre, any Error> = Result { try Halakha.parse(Depot.texte("ben_ish_hai.json")) }
    static let yalkut: Result<YalkutYosef.Livre, any Error> = Result { try YalkutYosef.parse(Depot.texte("yalkut_yosef.json")) }
    static let hilloulot: Result<Hilloulot.Table, any Error> = Result { try Hilloulot.table(Depot.lire) }
    static let bibliotheque: Result<Bibliotheque, any Error> = Result {
        try JSONDecoder().decode(Bibliotheque.self, from: Depot.contenu("bibliotheque.json"))
    }
}

/// Les textes du jour devant la JVM (Tests/Vecteurs/textes_du_jour.json, tools/vecteurs_ios/
/// VecteursTextesDuJour.kt) : trois années, jour après jour, de halakha du Ben Ish 'Haï, de Yalkout
/// Yossef et de clés des hilloulot ; la source du jour ; la Méguila et Birkat haIlanot ; les nombres en
/// lettres, les dates des hilloulot, la forme sans voyelles de la recherche et des recherches dans les
/// trois livres. Aucune valeur n'est recopiée : le code Kotlin d'Android les a écrites.
@Suite("Textes du jour devant la JVM")
struct TextesDuJourTests {

    private static let charge: Result<ObjetJSON, any Error> = Result { try Depot.vecteurs("textes_du_jour.json") }

    private func vecteurs() throws -> ObjetJSON { try Self.charge.get() }

    private func jours() throws -> [JourCivil] {
        let v = try vecteurs()
        let debut = JourCivil.du(v.texte("debut"))
        return (0..<v.entier("nombre")).map { debut.plus(jours: $0) }
    }

    @Test func laHalakhaDuJourSuitLaParachaAVenir() throws {
        let livre = try Corpus.halakha.get()
        let jours = try jours(), attendus = try vecteurs().textes("halakha")
        try #require(attendus.count == jours.count)
        for (d, attendu) in zip(jours, attendus) {
            func rendu(_ israel: Bool) -> String {
                let l = Halakha.pour(livre, d, enIsrael: israel)
                let numeros = l.map { "\($0.annee).\($0.numero)" }.joined(separator: ",")
                let sections = Kotlin.hashCode(l.map { $0.section }.joined(separator: "/"))
                return "\(CalendrierJuif.parachaAVenir(d, enIsrael: israel))|\(numeros)|\(sections)"
            }
            let diaspora = rendu(false), israel = rendu(true)
            let ici = israel == diaspora ? diaspora : "\(diaspora) \(israel)"
            #expect(ici == attendu, "\(d)")
        }
    }

    @Test func leYalkoutYossefSuitSesPeriodes() throws {
        let jours = try jours(), attendus = try vecteurs().textes("yalkut")
        try #require(attendus.count == jours.count)
        for (d, attendu) in zip(jours, attendus) {
            let p = YalkutYosef.periode(d, israel: false)
            #expect("\(p.periode):\(p.rang)" == attendu, "\(d)")
        }
    }

    @Test func lesClesDesHilloulotJourApresJour() throws {
        let jours = try jours(), attendus = try vecteurs().textes("hilloulot")
        try #require(attendus.count == jours.count)
        for (d, attendu) in zip(jours, attendus) {
            let ici = Hilloulot.clesPour(d, enIsrael: false).joined(separator: ",") + "|"
                + Hilloulot.clesPour(d, enIsrael: false, ashkenaz: true).joined(separator: ",")
            #expect(ici == attendu, "\(d)")
        }
    }

    @Test func laSourceDuJourEtSonExtrait() throws {
        let b = try Corpus.bibliotheque.get(), v = try vecteurs()
        #expect(SourceDuJour.candidats(b).count == v.entier("candidats"))
        let attendus = v.textes("sourceDuJour")
        #expect(attendus.count == 400)
        for (i, attendu) in attendus.enumerated() {
            let d = JourCivil.du("2026-09-01").plus(jours: i)
            let p = try #require(SourceDuJour.choix(b, d))
            let rang = b.paragraphes(de: p.source).firstIndex { $0.egalUnites(p.texte) } ?? -1
            #expect("\(p.source.id):\(rang)" == attendu, "\(d)")
        }
        for case .tableau(let e) in v.tableau("extraits") ?? [] {
            let rendu = SourceDuJour.extrait(e.texte(0))
            #expect(rendu.egalUnites(e.texte(1)), "« \(rendu) » au lieu de « \(e.texte(1)) »")
        }
    }

    /// Hors du mois de Pourim (Adar d'une année simple, Adar II d'une embolismique), aucune fête de Pourim :
    /// la Méguila n'est cherchée que là, et le fichier ne doit rien nommer d'autre.
    @Test func laMeguilaDansLeSiddour() throws {
        let jours = try jours()
        let cas = try vecteurs().tableau("megila") ?? []
        #expect(cas.count == 8)
        for case .objet(let o) in cas {
            let moment = o.texte("moment"), muree = o.booleen("muree"), israel = o.booleen("israel")
            var rendus = Set<String>()
            for d in jours {
                let h = CalendrierJuif.dateJuive(moment == "arvit" ? d.plus(jours: 1) : d)
                guard h.mois == (h.embolismique ? CalendrierJuif.Mois.adarII : CalendrierJuif.Mois.adar) else { continue }
                if SiddurMoment.megila(moment, d, israel: israel, mukafChoma: muree) { rendus.insert(d.iso) }
            }
            #expect(rendus == Set(o.textes("jours")), "\(moment) muree=\(muree) israel=\(israel)")
        }
    }

    @Test func birkatHaIlanot() throws {
        let jours = try jours()
        for case .objet(let o) in try vecteurs().tableau("ilanot") ?? [] {
            let latitude: Double? = o.estNul("latitude") ? nil : o.double("latitude")
            let rendus = Set(jours.filter { SiddurMoment.ilanot($0, latitude: latitude) }.map(\.iso))
            #expect(rendus == Set(o.textes("jours")), "\(latitude.map { String($0) } ?? "sans latitude")")
        }
    }

    @Test func lesNombresEnLettres() throws {
        let attendus = try vecteurs().textes("lettres")
        try #require(attendus.count == 999)
        for (i, attendu) in attendus.enumerated() {
            let rendu = Reference.lettres(i + 1)
            #expect(rendu.egalUnites(attendu), "\(i + 1) : \(rendu) au lieu de \(attendu)")
        }
    }

    @Test func lesDatesDesHilloulotEtLeurRang() throws {
        let t = try Corpus.hilloulot.get()
        let lignes = try vecteurs().tableau("dates") ?? []
        #expect(lignes.count == t.cles.count)
        for (k, ligne) in lignes.enumerated() {
            guard case .tableau(let r) = ligne else {
                Issue.record("ligne \(k) : pas un tableau")
                continue
            }
            let cle = r.texte(0)
            #expect(k < t.cles.count && t.cles[k] == cle, "\(k) : \(cle)")
            #expect(Hilloulot.dateDe(cle).egalUnites(r.texte(1)), "\(cle) : \(Hilloulot.dateDe(cle))")
            #expect(Hilloulot.rangDansLAnnee(cle) == r.entier(2), "\(cle)")
        }
    }

    @Test func laFormeSansVoyellesDeLaRecherche() throws {
        let cas = try vecteurs().tableau("nu") ?? []
        #expect(cas.count > 20)
        for case .tableau(let r) in cas {
            let rendu = RechercheGlobale.nu(r.texte(0))
            #expect(rendu.egalUnites(r.texte(1)), "« \(r.texte(0)) » : « \(rendu) » au lieu de « \(r.texte(1)) »")
        }
    }

    @Test func lesRecherchesDansLesTroisLivres() throws {
        let h = try Corpus.halakha.get(), y = try Corpus.yalkut.get(), t = try Corpus.hilloulot.get()
        let cas = try vecteurs().tableau("recherches") ?? []
        #expect(cas.count == 20)
        for case .tableau(let r) in cas {
            let q = r.texte(0)
            let rh = Halakha.recherche(h, q), ry = YalkutYosef.recherche(y, q), rt = Hilloulot.recherche(t, q)
            let rendu = [rh.count, Int(Kotlin.hashCode(rh.map { "\($0.annee)/\($0.section)/\($0.numero)" }.joined(separator: "\n"))),
                         ry.count, Int(Kotlin.hashCode(ry.map { "\($0.siman)/\($0.lettre)" }.joined(separator: "\n"))),
                         rt.count, Int(Kotlin.hashCode(rt.map { "\($0.cle)/\($0.hilloula.he)" }.joined(separator: "\n")))]
            let attendu = (1...6).map { r.entier($0) }
            #expect(rendu == attendu, "« \(q) »")
        }
    }
}
