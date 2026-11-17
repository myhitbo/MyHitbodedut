import Foundation
import Testing
@testable import Coeur

/// Les ajouts de Store.kt du 13 au 16/11 devant la JVM (`Tests/Vecteurs/store.json`, tools/vecteurs_ios/VecteursStore.kt) :
/// l'historique daté d'un réglage (HistoriqueReglage.kt, FDONNEES-05), `Store.dateValide` (revue du 15/11) et
/// `Store.jourCorrige` (FDONNEES-04, FDONNEES-14).
@Suite struct HistoriqueReglageTests {

    private struct Fichier: Decodable {
        struct Historique: Decodable {
            struct Decode: Decodable {
                let brut: String?
                let encode: String
                /// Pour chaque jour de `jours` : [valeurLe(actuelle: false), valeurLe(actuelle: true)].
                let valeurs: [[Bool]]
            }
            /// [jour, ancienne, nouvelle].
            struct Pas: Decodable {
                let jour: String
                let ancienne: Bool
                let nouvelle: Bool

                init(from decoder: any Decoder) throws {
                    var c = try decoder.unkeyedContainer()
                    jour = try c.decode(String.self)
                    ancienne = try c.decode(Bool.self)
                    nouvelle = try c.decode(Bool.self)
                }
            }
            struct Changement: Decodable {
                let suite: [Pas]
                let apres: [String]
            }
            let origine: String
            let max: Int
            let jours: [String]
            let decodes: [Decode]
            let changements: [Changement]
        }
        /// [minutes ou null, note, noteSeule, nouvelles minutes, garde, null ou [minutes, note, noteSeule, thèmes]].
        struct Correction: Decodable {
            let minutes: Int?
            let note: String
            let seule: Bool
            let nouvelles: Int
            let garde: Bool
            let resultat: Journee?

            init(from decoder: any Decoder) throws {
                var c = try decoder.unkeyedContainer()
                minutes = try c.decodeIfPresent(Int.self)
                note = try c.decode(String.self)
                seule = try c.decode(Bool.self)
                nouvelles = try c.decode(Int.self)
                garde = try c.decode(Bool.self)
                if try c.decodeNil() {
                    resultat = nil
                } else {
                    var r = try c.nestedUnkeyedContainer()
                    let m = try r.decode(Int.self)
                    let n = try r.decode(String.self)
                    let s = try r.decode(Bool.self)
                    let t = try r.decode([String].self)
                    resultat = Journee(minutes: m, note: n, themes: t, noteSeule: s)
                }
            }
        }
        let historique: Historique
        let datesValides: [[String?]]
        let joursCorriges: [Correction]
    }

    private func fichier() throws -> Fichier {
        try JSONDecoder().decode(Fichier.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/store.json"))
    }

    @Test func lHistoriqueSeLitSEcritEtSeJugeCommeSurLaJVM() throws {
        let h = try fichier().historique
        #expect(h.origine == HistoriqueReglage.origine.iso)
        #expect(h.max == HistoriqueReglage.max)
        let jours = try h.jours.map { try #require(JourCivil(iso: $0)) }
        #expect(h.decodes.count == 11)
        for d in h.decodes {
            let lu = HistoriqueReglage.decoder(d.brut)
            #expect(HistoriqueReglage.encoder(lu) == d.encode, "« \(d.brut ?? "null") »")
            for (jour, attendu) in zip(jours, d.valeurs) {
                let sans = HistoriqueReglage.valeurLe(lu, jour, actuelle: false)
                let avec = HistoriqueReglage.valeurLe(lu, jour, actuelle: true)
                #expect([sans, avec] == attendu, "« \(d.brut ?? "null") » le \(jour.iso)")
            }
        }
        #expect(h.changements.count == 5)
        for c in h.changements {
            var histoire: [HistoriqueReglage.Entree] = []
            for (pas, attendu) in zip(c.suite, c.apres) {
                let jour = try #require(JourCivil(iso: pas.jour))
                histoire = HistoriqueReglage.apresChangement(histoire, aujourdhui: jour, ancienne: pas.ancienne,
                                                             nouvelle: pas.nouvelle)
                #expect(HistoriqueReglage.encoder(histoire) == attendu, "le \(pas.jour)")
            }
        }
    }

    @Test func lesDatesValidesCommeSurLaJVM() throws {
        let v = try fichier().datesValides
        #expect(v.count == 11)
        for ligne in v {
            let cle = try #require(ligne.first ?? nil)
            let attendue = ligne.count > 1 ? ligne[1] : nil
            #expect(Store.dateValide(cle)?.iso == attendue, "« \(cle) »")
            #expect(Journal.dateValide(cle)?.iso == attendue, "« \(cle) »")
        }
    }

    @Test func laCorrectionDUnJourCommeSurLaJVM() throws {
        let v = try fichier().joursCorriges
        #expect(v.count == 60)
        for c in v {
            let existant = c.minutes.map { Journee(minutes: $0, note: c.note, themes: ["t"], noteSeule: c.seule) }
            let obtenu = Journal.jourCorrige(existant, minutes: c.nouvelles, garde: c.garde)
            #expect(obtenu == c.resultat, "\(c.minutes.map(String.init) ?? "rien"), « \(c.note) », \(c.nouvelles) min, garde \(c.garde)")
        }
    }

    /// Une humeur ou une gratitude garde la ligne du jour, sans le valider (FDONNEES-14) ; corriger à zéro retire
    /// la journée et, aujourd'hui, l'instant de la séance (FDONNEES-04).
    @Test func lJournalEnrichiGardeLaLigne() throws {
        let jour = try #require(JourCivil(iso: "2026-11-10"))
        var journal = Journal()
        journal.ecrirePlus(JournalPlus.Plus(avant: 3, apres: 0, gratitude: "", travail: ""), pour: jour)
        journal.setNote(date: jour, note: "")
        let ligne = journal.jours[jour]
        #expect(ligne == Journee(minutes: 0, note: "", themes: [], noteSeule: true))
        #expect(ligne?.faite == false)
        // Une note seule effacée, l'humeur gardée : la ligne reste.
        journal.setNote(date: jour, note: "une note")
        journal.setNote(date: jour, note: "")
        #expect(journal.jours[jour] != nil)
        // Sans rien d'enrichi : la ligne s'en va.
        journal.ecrirePlus(JournalPlus.Plus(avant: 0, apres: 0, gratitude: "", travail: ""), pour: jour)
        journal.setNote(date: jour, note: "")
        #expect(journal.jours[jour] == nil)
    }
}
