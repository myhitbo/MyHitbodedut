import Foundation
import Testing
@testable import Coeur

/// ReminderTimesTest d'Android, porté : plusieurs heures de rappel, le calcul de la prochaine, et ce que
/// l'écran promet à leur sujet ; puis chaque minute du jour devant `Tests/Vecteurs/rappels.json`, écrit
/// par la JVM (tools/vecteurs_ios/VecteursRappels.kt). Les libellés de strings.xml se vérifient sur le
/// catalogue exporté (values, values-en et values-iw y sont fr, en et he).
@Suite("Rappel : plusieurs heures")
struct ReminderTimesTests {

    private let jour = ReminderRule.minutesParJour

    @Test func laProchaineHeureDuJourEstRetenue() {
        let heures = [7 * 60, 13 * 60, 21 * 60]
        let a6h = ReminderRule.minutesUntilNext(nowMinutes: 6 * 60, heures: heures)
        #expect(a6h == 60)
        let a8h = ReminderRule.minutesUntilNext(nowMinutes: 8 * 60, heures: heures)
        #expect(a8h == 5 * 60)
        let a20h = ReminderRule.minutesUntilNext(nowMinutes: 20 * 60, heures: heures)
        #expect(a20h == 60)
    }

    /// Quand toutes les heures sont passées, on repart sur la première du lendemain. C'est le cas qu'un
    /// simple « première heure supérieure à maintenant » manque, en ne rendant rien.
    @Test func apresLaDerniereHeureOnPasseAuLendemain() {
        let heures = [7 * 60, 21 * 60]
        let attendu = (jour - 22 * 60) + 7 * 60
        let deuxHeures = ReminderRule.minutesUntilNext(nowMinutes: 22 * 60, heures: heures)
        #expect(deuxHeures == attendu)
        let uneHeure = ReminderRule.minutesUntilNext(nowMinutes: 22 * 60, heures: [7 * 60])
        #expect(uneHeure == 9 * 60)
    }

    @Test func uneHeureQuiVientDePasserNEstPasRedonnee() {
        // À l'heure pile, le rappel vient de sonner : la prochaine est ailleurs.
        let heures = [7 * 60, 19 * 60]
        let dans = ReminderRule.minutesUntilNext(nowMinutes: 7 * 60, heures: heures)
        #expect(dans == 12 * 60)
    }

    @Test func sansHeureRegleeIlNYARienAProgrammer() {
        let dans = ReminderRule.minutesUntilNext(nowMinutes: 10 * 60, heures: [])
        #expect(dans == nil)
    }

    @Test func lesHeuresSontTrieesDedupliqueesEtBorneesAuJour() {
        let sales = [21 * 60, 7 * 60, 7 * 60, -30, jour + 10, 13 * 60]
        let a6h = ReminderRule.minutesUntilNext(nowMinutes: 6 * 60, heures: sales)
        #expect(a6h == 60)
        // Une valeur hors jour ne doit jamais être choisie comme prochaine.
        let a7h = ReminderRule.minutesUntilNext(nowMinutes: 7 * 60, heures: sales)
        #expect(a7h == 6 * 60)
    }

    @Test func leResultatTombeToujoursDansLesVingtQuatreHeures() throws {
        let heures = [0, 8 * 60, 23 * 60 + 59]
        for maintenant in stride(from: 0, to: jour, by: 37) {
            let calcule = ReminderRule.minutesUntilNext(nowMinutes: maintenant, heures: heures)
            let dans = try #require(calcule)
            let dansLeJour = dans >= 1 && dans <= jour
            #expect(dansLeJour, "\(maintenant) -> \(dans)")
        }
    }

    /// La règle de silence ne change pas parce qu'il y a plusieurs heures : un jour de repos reste muet,
    /// et la veille se tait après midi.
    @Test func plusieursHeuresNeContournentPasLaRegleDuRepos() {
        for heure in [7 * 60, 13 * 60, 21 * 60] {
            let sonne = ReminderRule.shouldNotify(nowMinutes: heure, doneToday: false, todayIsRestDay: true,
                                                  tomorrowIsRestDay: false, sunsetMinutes: nil)
            #expect(!sonne, "un jour de repos doit rester muet à \(heure)")
        }
        let matin = ReminderRule.shouldNotify(nowMinutes: 7 * 60, doneToday: false, todayIsRestDay: false,
                                              tomorrowIsRestDay: true, sunsetMinutes: nil)
        #expect(matin)
        let apresMidi = ReminderRule.shouldNotify(nowMinutes: 13 * 60, doneToday: false, todayIsRestDay: false,
                                                  tomorrowIsRestDay: true, sunsetMinutes: nil)
        #expect(!apresMidi)
    }

    /// L'écran des rappels annonce ces trois états ; ils doivent exister, et le pluriel du nombre d'heures.
    @Test func lesLibellesDEtatDesRappelsExistentDansLesTroisLangues() throws {
        let cles = ["reminders_off", "reminders_none", "reminders_permission_missing",
                    "reminder_action_start", "reminder_action_later"]
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for cle in cles {
                let present = chaines[cle] != nil
                #expect(present, "\(langue) : « \(cle) » manquant")
            }
            let pluriels = catalogue.pluriels(langue)
            let pluriel = pluriels["reminders_count[other]"] != nil
            #expect(pluriel, "\(langue) : le pluriel reminders_count manque")
        }
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        /// `parMinute` : la réponse à chaque minute du jour, de 0 h 00 à 23 h 59 ; `horsJour` : des paires
        /// [maintenant, réponse] hors du jour, jusqu'aux bornes d'un `Int` de Kotlin.
        struct Liste: Decodable {
            let heures: [Int]
            let parMinute: [Int?]
            let horsJour: [[Int?]]
        }
        let minutesUntilNext: [Liste]
    }

    private static func ecrit(_ valeur: Int?) -> String {
        valeur.map { String($0) } ?? "nil"
    }

    @Test func chaqueMinuteDuJourRepondCommeAndroid() throws {
        let vecteurs = try JSONDecoder().decode(Vecteurs.self,
                                                from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/rappels.json"))
        var fautes: [String] = []
        var cas = 0
        for liste in vecteurs.minutesUntilNext {
            if liste.parMinute.count != jour {
                fautes.append("\(liste.heures) : \(liste.parMinute.count) minutes au lieu de \(jour)")
            }
            for (maintenant, attendu) in liste.parMinute.enumerated() {
                let dans = ReminderRule.minutesUntilNext(nowMinutes: maintenant, heures: liste.heures)
                cas += 1
                if dans != attendu {
                    fautes.append("\(liste.heures) à \(maintenant) : \(Self.ecrit(dans)) au lieu de \(Self.ecrit(attendu))")
                }
            }
            for paire in liste.horsJour {
                guard paire.count == 2, let maintenant = paire[0] else {
                    fautes.append("\(liste.heures) : paire illisible")
                    continue
                }
                let dans = ReminderRule.minutesUntilNext(nowMinutes: maintenant, heures: liste.heures)
                cas += 1
                if dans != paire[1] {
                    fautes.append("\(liste.heures) à \(maintenant) : \(Self.ecrit(dans)) au lieu de \(Self.ecrit(paire[1]))")
                }
            }
        }
        let resume = fautes.prefix(20).joined(separator: " ; ")
        let aucune = fautes.isEmpty
        #expect(aucune, "\(fautes.count) écarts : \(resume)")
        #expect(cas > 15_000)
    }
}
