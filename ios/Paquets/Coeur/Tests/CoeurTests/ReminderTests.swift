import Foundation
import Testing
@testable import Coeur

/// La part pure de Reminder.kt, qu'aucun test d'Android ne couvre : sur Android ce calcul est écrit dans
/// `reschedule(context)` et `snooze(context)`, qui lisent l'horloge et posent l'alarme, et la JVM de
/// l'oracle ne peut pas les appeler. Les attendus suivent la lecture du Kotlin : le prochain rappel
/// réglé, à moins qu'un report encore à venir ne tombe avant. Le prochain rappel lui-même est jugé par
/// les vecteurs (ReminderRuleTests). Reste à Android `le bouton commencer du rappel ouvre l ecran de
/// seance` (FiabiliteTest), qui lit le texte de Reminder.kt.
@Suite("Rappel : l'alarme et le report")
struct ReminderTests {

    private static let paris: Fuseau = {
        guard let fuseau = Fuseau("Europe/Paris") else { preconditionFailure("le fuseau Europe/Paris manque") }
        return fuseau
    }()

    private let minute: Int64 = 60_000

    private func a(_ jour: String, _ heure: Int, _ minute: Int = 0) -> DateHeureZonee {
        DateHeureZonee(DateHeure(JourCivil.du(jour), heure: heure, minute: minute), fuseau: Self.paris)
    }

    @Test func rappelsDesactivesAucuneAlarme() {
        let maintenant = a("2026-09-29", 6, 30)
        let quand = Reminder.reschedule(reminderEnabled: false, maintenant: maintenant, reminderTimes: [7 * 60],
                                        reminderSnoozedUntil: maintenant.millis + 10 * minute)
        #expect(quand == nil)
    }

    @Test func sansHeureNiReportAucuneAlarme() {
        let quand = Reminder.reschedule(reminderEnabled: true, maintenant: a("2026-09-29", 6, 30), reminderTimes: [],
                                        reminderSnoozedUntil: 0)
        #expect(quand == nil)
    }

    @Test func sansReportLeProchainRappelRegle() {
        let quand = Reminder.reschedule(reminderEnabled: true, maintenant: a("2026-09-29", 6, 30),
                                        reminderTimes: [7 * 60, 20 * 60], reminderSnoozedUntil: 0)
        let septHeures = a("2026-09-29", 7).millis
        #expect(quand == septHeures)
    }

    /// Un report passe devant le prochain rappel réglé s'il tombe avant.
    @Test func leReportPasseDevantSIlTombeAvant() {
        let maintenant = a("2026-09-29", 6, 30)
        let reporte = maintenant.millis + 20 * minute
        let quand = Reminder.reschedule(reminderEnabled: true, maintenant: maintenant, reminderTimes: [7 * 60],
                                        reminderSnoozedUntil: reporte)
        #expect(quand == reporte)
    }

    @Test func leRappelRegleResteSIlTombeAvantLeReport() {
        let maintenant = a("2026-09-29", 6, 50)
        let quand = Reminder.reschedule(reminderEnabled: true, maintenant: maintenant, reminderTimes: [7 * 60],
                                        reminderSnoozedUntil: maintenant.millis + 30 * minute)
        let septHeures = a("2026-09-29", 7).millis
        #expect(quand == septHeures)
        // À égalité, le rappel réglé reste : le report ne passe devant que s'il tombe avant.
        let egalite = Reminder.reschedule(reminderEnabled: true, maintenant: maintenant, reminderTimes: [7 * 60],
                                          reminderSnoozedUntil: septHeures)
        #expect(egalite == septHeures)
    }

    /// Un report échu, ou qui tombe à l'instant même, ne compte plus.
    @Test func unReportEchuNeComptePlus() {
        let maintenant = a("2026-09-29", 6, 30)
        let septHeures = a("2026-09-29", 7).millis
        let echu = Reminder.reschedule(reminderEnabled: true, maintenant: maintenant, reminderTimes: [7 * 60],
                                       reminderSnoozedUntil: maintenant.millis - minute)
        #expect(echu == septHeures)
        let pile = Reminder.reschedule(reminderEnabled: true, maintenant: maintenant, reminderTimes: [7 * 60],
                                       reminderSnoozedUntil: maintenant.millis)
        #expect(pile == septHeures)
        let sansRienDautre = Reminder.reschedule(reminderEnabled: true, maintenant: maintenant, reminderTimes: [],
                                                 reminderSnoozedUntil: maintenant.millis)
        #expect(sansRienDautre == nil)
    }

    @Test func unReportSansHeureRegleeSonneQuandMeme() {
        let maintenant = a("2026-09-29", 6, 30)
        let reporte = Reminder.snooze(maintenant: maintenant.millis)
        let quand = Reminder.reschedule(reminderEnabled: true, maintenant: maintenant, reminderTimes: [],
                                        reminderSnoozedUntil: reporte)
        #expect(quand == reporte)
    }

    @Test func leReportDureTrenteMinutes() {
        let maintenant: Int64 = 1_800_000_000_000
        let reporte = Reminder.snooze(maintenant: maintenant)
        #expect(reporte == maintenant + 30 * minute)
        let duree = Reminder.snoozeMinutes
        #expect(duree == 30)
    }

    private struct Vecteurs: Decodable {
        struct Constantes: Decodable { let snoozeMinutes: Int }
        let constantes: Constantes
    }

    @Test func laDureeDuReportEstCelleDAndroid() throws {
        let vecteurs = try JSONDecoder().decode(Vecteurs.self,
                                                from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/rappels.json"))
        let duree = Reminder.snoozeMinutes
        #expect(duree == vecteurs.constantes.snoozeMinutes)
    }
}
