import Foundation

/// La part pure des rappels de la journée (Reminder.kt) : l'instant de l'alarme à poser, et le report.
///
/// Plusieurs heures peuvent être réglées : un rappel unique se rate facilement. Une seule alarme est
/// posée à la fois, celle du prochain rappel, et elle se reprogramme à chaque déclenchement : rien à
/// nettoyer quand la liste change. Restent à l'app le récepteur, la notification et ses actions,
/// l'alarme elle-même (AlarmManager sur Android) et la règle du silence au déclenchement
/// (`ReminderRule.shouldNotify`). Sans vecteurs : sur Android ce calcul est écrit dans
/// `reschedule(context)`, qui lit l'horloge et pose l'alarme, et la JVM de l'oracle ne peut pas l'appeler.
public enum Reminder {

    /// Report demandé depuis la notification, en minutes.
    public static let snoozeMinutes = 30

    /// `reschedule(context)` sans Android : l'instant (millisecondes Unix) où poser l'alarme, ou nil pour
    /// n'en poser aucune. Rappels désactivés : rien. Sinon le prochain rappel réglé, à moins qu'un report
    /// encore à venir (`reminderSnoozedUntil`, 0 sans report) ne tombe avant : il passe alors devant.
    public static func reschedule(reminderEnabled: Bool, maintenant: DateHeureZonee, reminderTimes: [Int],
                                  reminderSnoozedUntil: Int64) -> Int64? {
        if !reminderEnabled { return nil }
        let prochain = ReminderRule.prochainDeclenchement(maintenant: maintenant, heures: reminderTimes)?.millis
        let reporte = reminderSnoozedUntil
        if reporte > maintenant.millis {
            guard let regle = prochain else { return reporte }
            return reporte < regle ? reporte : regle
        }
        return prochain
    }

    /// `snooze(context)` sans Android : la fin du report, `snoozeMinutes` après `maintenant`
    /// (millisecondes Unix), sans toucher aux heures réglées. L'addition déborde en silence comme celle
    /// d'un `Long`.
    public static func snooze(maintenant: Int64) -> Int64 {
        maintenant &+ Int64(snoozeMinutes) &* 60_000
    }
}
