import Foundation
import Testing
@testable import Coeur

/// Le journal d'Android (Store.kt, JournalPlus.kt). D'abord JournalCarnetTest et le cas « journal, les
/// minutes du mois et le resume » de DixAmeliorationsTest, portés tels quels ; les trois autres cas de
/// DixAmeliorationsTest (Levana, widget, recherche) sont portés avec leurs règles. Puis
/// `Tests/Vecteurs/modele.json` (tools/vecteurs_ios/VecteursModele.kt) : les journées que Store écrit
/// dans la préférence « days », celles qu'il relit d'un texte posé à la main et le texte qu'il réécrit
/// alors, le journal enrichi, le résumé, les minutes du mois et le prénom. Un texte long y est jugé par
/// sa longueur en unités UTF-16 et son empreinte (String.hashCode de Java).
@Suite("Modèle du journal")
struct ModeleTests {

    // MARK: JournalCarnetTest

    @Test func leResumeDitLeSujetLHumeurLaGratitudeEtLaChoseATravailler() {
        let complet = JournalPlus.resume(JournalPlus.Plus(avant: 2, apres: 4, gratitude: "merci", travail: "la patience"),
                                         gratitude: "G", travail: "T", sujets: "Sujet : Famille")
        let attenduComplet = "Sujet : Famille\n\u{2066}\u{1F641} \u{2192} \u{1F642}\u{2069}\nG : merci\nT : la patience"
        let completConforme = complet.egalUnites(attenduComplet)
        #expect(completConforme, "\(complet)")

        let travail = JournalPlus.resume(JournalPlus.Plus(travail: "\u{E9}couter"), gratitude: "G", travail: "T")
        let travailConforme = travail.egalUnites("T : \u{E9}couter")
        #expect(travailConforme, "\(travail)")

        // L'ancien appel, sans travail ni sujet, rend ce qu'il rendait.
        let ancien = JournalPlus.resume(JournalPlus.Plus(avant: 2, apres: 4, gratitude: "merci"), gratitude: "G")
        let ancienConforme = ancien.egalUnites("\u{2066}\u{1F641} \u{2192} \u{1F642}\u{2069}\nG : merci")
        #expect(ancienConforme, "\(ancien)")
    }

    @Test func uneChoseATravaillerSuffitACeQueLeJourNeSoitPasVide() {
        let vide = JournalPlus.Plus(travail: "x").vide
        #expect(!vide)
    }

    // MARK: DixAmeliorationsTest

    @Test func journalLesMinutesDuMoisEtLeResume() {
        let jours: [JourCivil: Journee] = [
            JourCivil.du("2026-10-01"): Journee(minutes: 20, note: ""),
            JourCivil.du("2026-10-03"): Journee(minutes: 0, note: "note", noteSeule: true),
            JourCivil.du("2026-10-31"): Journee(minutes: 45, note: ""),
        ]
        let m = JournalPlus.minutesDuMois(jours, annee: 2026, mois: 10)
        #expect(m.count == 31)
        let premier = m[0], troisieme = m[2], dernier = m[30]
        #expect(premier == 20)
        #expect(troisieme == 0)
        #expect(dernier == 45)
        let resume = JournalPlus.resume(JournalPlus.Plus(avant: 2, apres: 4, gratitude: "merci"), gratitude: "G")
        let resumeConforme = resume.egalUnites("\u{2066}\u{1F641} \u{2192} \u{1F642}\u{2069}\nG : merci")
        #expect(resumeConforme, "\(resume)")
        let rien = JournalPlus.resume(JournalPlus.Plus(), gratitude: "G")
        #expect(rien == "")
    }

    // MARK: Ce que les vecteurs ne disent pas

    @Test func unJourNouveauSeRangeALaFinEtUnJourRetireSOte() {
        var journal = Journal()
        let a = JourCivil.du("2025-10-05"), b = JourCivil.du("2025-09-01"), c = JourCivil.du("2025-10-01")
        journal.addSession(minutes: 5, date: a)
        journal.setNote(date: b, note: "avant")
        journal.addSession(minutes: 2, theme: "gratitude", date: c)
        let ordre = journal.dates, ordreAttendu = [a, b, c]
        #expect(ordre == ordreAttendu)
        let texte = journal.daysTexte
        let attendu = "{\"2025-10-05\":{\"minutes\":5,\"note\":\"\"},\"2025-09-01\":{\"minutes\":0,\"note\":\"avant\",\"note_seule\":true},"
            + "\"2025-10-01\":{\"minutes\":2,\"note\":\"\",\"themes\":[\"gratitude\"]}}"
        #expect(texte == attendu)

        // Retiré puis remis, le jour revient à la fin, comme dans la LinkedHashMap d'Android.
        journal.unmarkToday(a)
        journal.addSession(minutes: 1, date: a)
        let apres = journal.dates, apresAttendu = [b, c, a]
        #expect(apres == apresAttendu)
        let faits = journal.joursFaits
        let faitsAttendus: Set<JourCivil> = [a, c]
        #expect(faits == faitsAttendus)
        let total = journal.totalMinutes
        #expect(total == 3)
        let pratique = journal.aDejaPratique
        #expect(pratique)
        let seule = journal.isDone(b)
        #expect(!seule)
    }

    @Test func lesCoupesComptentDesUnitesUTF16() {
        var journal = Journal()
        let jour = JourCivil.du("2025-10-07")
        journal.setNote(date: jour, note: String(repeating: "\u{05D0}\u{05B8}", count: 2100))
        let note = journal[jour]?.note ?? ""
        let unites = note.utf16.count, caracteres = note.count
        #expect(unites == 4000)
        #expect(caracteres == 2000)

        journal.setFirstName("  " + String(repeating: "\u{05E9}\u{05C1}\u{05B8}", count: 20) + "  ")
        let prenom = journal.prenom.utf16.count
        #expect(prenom == 40)

        var plus = JournalPlus.Plus(gratitude: String(repeating: "\u{1F600}", count: 120))
        journal.ecrirePlus(plus, pour: jour)
        plus = journal.lirePlus(jour)
        let gratitude = plus.gratitude.utf16.count
        #expect(gratitude == 200)
    }

    @Test func unJournalIllisibleGardeSaPremiereCopie() {
        let illisible = Journal(daysTexte: "{")
        let copie = illisible.corrompu
        #expect(copie == "{")
        let vide = illisible.daysTexte
        #expect(vide == "{}")
        let encore = Journal(daysTexte: "pas du json", corrompu: "{")
        let premiere = encore.corrompu
        #expect(premiere == "{")
        let lisible = Journal(daysTexte: "{}")
        let aucune = lisible.corrompu
        #expect(aucune == nil)
    }

    @Test func lesDeuxLecturesDuJournalSAccordent() throws {
        let texte = "{\"2025-10-02\":{\"minutes\":3,\"note\":\"b\"},\"2025-10-01\":{\"minutes\":1,\"note\":\"a\",\"themes\":[\"x\"]}}"
        let parTexte = Journal(daysTexte: texte, prenom: "Moshe")
        let parObjet = Journal(days: try ObjetJSON(texte: texte), prenom: "Moshe")
        #expect(parTexte == parObjet)
        let relu = parObjet.daysTexte
        #expect(relu == texte)
    }

    @Test func uneDateValideSeReecritALIdentique() {
        let valides = ["2026-09-29", "2024-02-29", "0000-02-29", "9999-12-31", "-0001-01-01", "+10000-01-01"]
        for cle in valides {
            let iso = Journal.dateValide(cle)?.iso
            #expect(iso == cle, "\(cle)")
        }
        let refusees = ["2026-9-29", "2026-02-30", "2025-02-29", "+2026-09-29", "10000-01-01", "-0000-01-01", " 2026-09-29",
                        "2026-09-29 ", "2026-09-29T00:00", "", "2026/09/29", "\u{FF12}026-09-29"]
        for cle in refusees {
            let date = Journal.dateValide(cle)
            #expect(date == nil, "\(cle)")
        }
    }

    // MARK: Les vecteurs de la JVM

    private struct Trace: Decodable {
        let longueur: Int
        let empreinte: Int32
        let texte: String?
    }

    private struct JourneeV: Decodable {
        let date: String
        let minutes: Int
        let note: Trace
        let themes: [String]
        let noteSeule: Bool
    }

    /// Un argument d'une opération : un entier, un texte ou rien.
    private enum Arg: Decodable {
        case entier(Int)
        case texte(String)
        case nul

        init(from decoder: any Decoder) throws {
            let c = try decoder.singleValueContainer()
            if c.decodeNil() {
                self = .nul
            } else if let n = try? c.decode(Int.self) {
                self = .entier(n)
            } else {
                self = .texte(try c.decode(String.self))
            }
        }

        var entier: Int {
            if case .entier(let n) = self { return n }
            return 0
        }

        var texte: String? {
            if case .texte(let s) = self { return s }
            return nil
        }
    }

    private struct Etape: Decodable {
        let op: String
        let args: [Arg]
        let days: Trace
        let journees: [JourneeV]?
    }

    private struct Scenario: Decodable {
        let nom: String
        let etapes: [Etape]
    }

    private struct Relecture: Decodable {
        let texte: String
        let nombre: Int
        let journees: [JourneeV]?
        let corrompu: Bool
        let reecrit: Trace
    }

    private struct PlusV: Decodable {
        let avant: Int
        let apres: Int
        let gratitude: String
        let travail: String
        let vide: Bool
    }

    private struct Lu: Decodable {
        let date: String
        let plus: PlusV
    }

    private struct EcriturePlus: Decodable {
        let date: String
        let plus: PlusV
        let brut: Trace
        let relu: PlusV
    }

    private struct CasPlus: Decodable {
        let brut: String?
        let lus: [Lu]
        let ecritures: [EcriturePlus]
    }

    private struct Resume: Decodable {
        let plus: PlusV
        let gratitude: String
        let travail: String
        let sujets: String
        let resume: String
    }

    private struct MoisV: Decodable {
        let annee: Int
        let mois: Int
        let minutes: [Int]
    }

    private struct Mois: Decodable {
        let journees: [JourneeV]
        let mois: [MoisV]
    }

    private struct Prenom: Decodable {
        let nom: String
        let garde: String?
        let lu: String
    }

    private struct Constantes: Decodable {
        let noteMax: Int
        let gratitudeMax: Int
        let humeurs: [String]
    }

    private struct Vecteurs: Decodable {
        let constantes: Constantes
        let scenarios: [Scenario]
        let relectures: [Relecture]
        let plus: [CasPlus]
        let resumes: [Resume]
        let mois: [Mois]
        let prenoms: [Prenom]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/modele.json"))
    }

    /// Le texte d'iOS a-t-il les unités, l'empreinte et, s'il est court, le texte même de celui d'Android ?
    private func conforme(_ texte: String, _ trace: Trace) -> Bool {
        if texte.utf16.count != trace.longueur || Kotlin.hashCode(texte) != trace.empreinte { return false }
        if let attendu = trace.texte { return texte.egalUnites(attendu) }
        return true
    }

    private func memesUnites(_ a: [String], _ b: [String]) -> Bool {
        guard a.count == b.count else { return false }
        for (x, y) in zip(a, b) where !x.egalUnites(y) {
            return false
        }
        return true
    }

    /// Les journées d'iOS, dans l'ordre du journal, sont-elles celles qu'Android a relues ?
    private func conformes(_ journal: Journal, _ attendues: [JourneeV]) -> Bool {
        guard journal.dates.count == attendues.count else { return false }
        for (date, v) in zip(journal.dates, attendues) {
            guard let j = journal[date], date.iso.egalUnites(v.date), j.minutes == v.minutes, conforme(j.note, v.note),
                  memesUnites(j.themes, v.themes), j.noteSeule == v.noteSeule else { return false }
        }
        return true
    }

    private func plus(_ v: PlusV) -> JournalPlus.Plus {
        JournalPlus.Plus(avant: v.avant, apres: v.apres, gratitude: v.gratitude, travail: v.travail)
    }

    private func conforme(_ p: JournalPlus.Plus, _ v: PlusV) -> Bool {
        p.avant == v.avant && p.apres == v.apres && p.gratitude.egalUnites(v.gratitude) && p.travail.egalUnites(v.travail)
            && p.vide == v.vide
    }

    @Test func lesConstantesSontCellesDAndroid() throws {
        let c = try vecteurs().constantes
        #expect(Journal.noteMax == c.noteMax)
        #expect(JournalPlus.gratitudeMax == c.gratitudeMax)
        let humeurs = memesUnites(JournalPlus.humeurs, c.humeurs)
        #expect(humeurs, "\(JournalPlus.humeurs) ≠ \(c.humeurs)")
    }

    @Test func lesJourneesEcritesParStore() throws {
        let v = try vecteurs()
        var etapes = 0
        for s in v.scenarios {
            var journal = Journal()
            for (rang, e) in s.etapes.enumerated() {
                switch e.op {
                case "addSession":
                    let lue = e.args[3].texte.flatMap { JourCivil(iso: $0) }
                    let date = try #require(lue, "\(s.nom), étape \(rang)")
                    journal.addSession(minutes: e.args[0].entier, note: e.args[1].texte, theme: e.args[2].texte, date: date)
                case "setNote":
                    let lue = e.args[0].texte.flatMap { JourCivil(iso: $0) }
                    let date = try #require(lue, "\(s.nom), étape \(rang)")
                    journal.setNote(date: date, note: e.args[1].texte ?? "")
                default:
                    Issue.record("opération inconnue : \(e.op)")
                }
                let days = journal.daysTexte
                let identique = conforme(days, e.days)
                #expect(identique, "\(s.nom), étape \(rang) (\(e.op)) : \(days.prefix(300))")
                if let attendues = e.journees {
                    let memes = conformes(journal, attendues)
                    #expect(memes, "\(s.nom) : les journées relues")
                }
                etapes += 1
            }
        }
        #expect(etapes > 50)
    }

    @Test func lesJourneesReluesEtReecritesParStore() throws {
        let v = try vecteurs()
        #expect(v.relectures.count > 20)
        for (rang, r) in v.relectures.enumerated() {
            let journal = Journal(daysTexte: r.texte)
            let nombre = journal.dates.count
            #expect(nombre == r.nombre, "relecture \(rang) : \(r.texte.prefix(120))")
            let corrompu = journal.corrompu != nil
            #expect(corrompu == r.corrompu, "relecture \(rang) : copie du journal illisible")
            if r.corrompu {
                let copie = journal.corrompu ?? ""
                let copieConforme = copie.egalUnites(r.texte)
                #expect(copieConforme, "relecture \(rang) : la copie est le texte lu")
            }
            let reecrit = journal.daysTexte
            let identique = conforme(reecrit, r.reecrit)
            #expect(identique, "relecture \(rang) : \(reecrit.prefix(300))")
            if let attendues = r.journees {
                let memes = conformes(journal, attendues)
                #expect(memes, "relecture \(rang) : les journées lues")
            }
            // Le journal réécrit se relit à l'identique.
            let relu = Journal(daysTexte: reecrit)
            let stable = relu.daysTexte == reecrit && relu.jours == journal.jours
            #expect(stable, "relecture \(rang) : relu de son propre texte")
        }
    }

    @Test func leJournalEnrichiCommeAndroid() throws {
        let v = try vecteurs()
        for (rang, c) in v.plus.enumerated() {
            var journal = Journal(daysTexte: nil, journalPlusTexte: c.brut)
            for l in c.lus {
                let date = JourCivil.du(l.date)
                let lu = journal.lirePlus(date)
                let memes = conforme(lu, l.plus)
                #expect(memes, "cas \(rang), \(l.date) : \(lu)")
                let parJour = journal.plus[date] ?? JournalPlus.Plus()
                #expect(parJour == lu, "cas \(rang), \(l.date) : les jours du journal enrichi")
            }
            for e in c.ecritures {
                let date = JourCivil.du(e.date)
                journal.ecrirePlus(plus(e.plus), pour: date)
                let brut = journal.journalPlusTexte
                let identique = conforme(brut, e.brut)
                #expect(identique, "cas \(rang), \(e.date) : \(brut.prefix(300))")
                let relu = conforme(journal.lirePlus(date), e.relu)
                #expect(relu, "cas \(rang), \(e.date) : relu")
            }
        }
    }

    @Test func leResumeCommeAndroid() throws {
        let v = try vecteurs()
        #expect(v.resumes.count > 30)
        for r in v.resumes {
            let p = plus(r.plus)
            #expect(p.vide == r.plus.vide, "\(r.plus)")
            let resume = JournalPlus.resume(p, gratitude: r.gratitude, travail: r.travail, sujets: r.sujets)
            let identique = resume.egalUnites(r.resume)
            #expect(identique, "\(r.plus) : « \(resume) » ≠ « \(r.resume) »")
        }
    }

    @Test func lesMinutesDuMoisCommeAndroid() throws {
        let v = try vecteurs()
        for cas in v.mois {
            var jours: [JourCivil: Journee] = [:]
            for j in cas.journees {
                jours[JourCivil.du(j.date)] = Journee(minutes: j.minutes, note: j.note.texte ?? "", themes: j.themes, noteSeule: j.noteSeule)
            }
            for m in cas.mois {
                let minutes = JournalPlus.minutesDuMois(jours, annee: m.annee, mois: m.mois)
                #expect(minutes == m.minutes, "\(m.annee)-\(m.mois)")
            }
        }
    }

    @Test func lePrenomCommeAndroid() throws {
        let v = try vecteurs()
        for p in v.prenoms {
            var journal = Journal()
            journal.setFirstName(p.nom)
            let garde = journal.prenom.egalUnites(p.garde ?? "")
            #expect(garde, "« \(p.nom) » : gardé « \(journal.prenom) »")
            let lu = journal.firstName.egalUnites(p.lu)
            #expect(lu, "« \(p.nom) » : lu « \(journal.firstName) »")
        }
    }
}
