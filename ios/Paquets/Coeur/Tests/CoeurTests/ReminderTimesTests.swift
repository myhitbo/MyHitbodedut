import Foundation
import Testing
@testable import Coeur

/// ReminderTimesTest d'Android, porté : plusieurs heures de rappel, le calcul de la prochaine, et les libellés que
/// l'écran promet à leur sujet (cherchés dans le catalogue exporté plutôt que dans les strings.xml d'Android).
@Suite("ReminderTimes")
struct ReminderTimesTests {

    private let jour = ReminderRule.minutesParJour

    @Test func laProchaineHeureDuJourEstRetenue() {
        let heures = [7 * 60, 13 * 60, 21 * 60]
        #expect(ReminderRule.minutesAvantProchain(6 * 60, heures: heures) == 60)
        #expect(ReminderRule.minutesAvantProchain(8 * 60, heures: heures) == 5 * 60)
        #expect(ReminderRule.minutesAvantProchain(20 * 60, heures: heures) == 60)
    }

    /// Quand toutes les heures sont passées, on repart sur la première du lendemain : le cas qu'un simple « première
    /// heure supérieure à maintenant » manque, en ne rendant rien.
    @Test func apresLaDerniereHeureOnPasseAuLendemain() {
        let heures = [7 * 60, 21 * 60]
        let attendu = (jour - 22 * 60) + 7 * 60
        #expect(ReminderRule.minutesAvantProchain(22 * 60, heures: heures) == attendu)
        #expect(ReminderRule.minutesAvantProchain(22 * 60, heures: [7 * 60]) == 9 * 60)
    }

    @Test func uneHeureQuiVientDePasserNEstPasRedonnee() {
        // À l'heure pile, le rappel vient de sonner : la prochaine est ailleurs.
        #expect(ReminderRule.minutesAvantProchain(7 * 60, heures: [7 * 60, 19 * 60]) == 12 * 60)
    }

    @Test func sansHeureRegleeIlNYARienAProgrammer() {
        #expect(ReminderRule.minutesAvantProchain(10 * 60, heures: []) == nil)
    }

    @Test func lesHeuresSontTrieesDedoubleesEtBorneesAuJour() {
        let sales = [21 * 60, 7 * 60, 7 * 60, -30, jour + 10, 13 * 60]
        #expect(ReminderRule.minutesAvantProchain(6 * 60, heures: sales) == 60)
        // Une valeur hors du jour ne doit jamais être choisie comme prochaine.
        #expect(ReminderRule.minutesAvantProchain(7 * 60, heures: sales) == 6 * 60)
    }

    @Test func leResultatTombeToujoursDansLesVingtQuatreHeures() throws {
        let heures = [0, 8 * 60, 23 * 60 + 59]
        for maintenant in stride(from: 0, to: jour, by: 37) {
            let dans = try #require(ReminderRule.minutesAvantProchain(maintenant, heures: heures))
            #expect(dans >= 1 && dans <= jour, "\(maintenant) -> \(dans)")
        }
    }

    /// La règle de silence ne change pas parce qu'il y a plusieurs heures : un jour de repos reste muet, et la veille
    /// se tait après midi.
    @Test func plusieursHeuresNeContournentPasLaRegleDuRepos() {
        for heure in [7 * 60, 13 * 60, 21 * 60] {
            #expect(!ReminderRule.doitSonner(maintenant: heure, faite: false, repos: true, veilleDeRepos: false, coucher: nil),
                    "un jour de repos doit rester muet à \(heure)")
        }
        #expect(ReminderRule.doitSonner(maintenant: 7 * 60, faite: false, repos: false, veilleDeRepos: true, coucher: nil))
        #expect(!ReminderRule.doitSonner(maintenant: 13 * 60, faite: false, repos: false, veilleDeRepos: true, coucher: nil))
    }

    /// L'écran des rappels annonce ces trois états ; ils doivent exister.
    @Test func lesLibellesDEtatDesRappelsExistentDansLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        let cles = ["reminders_off", "reminders_none", "reminders_permission_missing", "reminder_action_start",
                    "reminder_action_later"]
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for cle in cles {
                #expect(chaines[cle] != nil, "\(langue) : « \(cle) » manquant")
            }
            let pluriels = catalogue.pluriels(langue).keys.filter { $0.hasPrefix("reminders_count[") }
            #expect(!pluriels.isEmpty, "\(langue) : le pluriel reminders_count manque")
        }
    }
}
