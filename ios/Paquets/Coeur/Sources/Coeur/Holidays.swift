import Foundation
import KosherSwift
import Synchronization

/// Calendrier hébraïque, hors ligne : la transposition de `Holidays.kt`, sur KosherSwift 1.10.11.
public enum Holidays {

    /// Shabbat ou Yom Tov : le jour où la pratique n'est pas attendue.
    public static func isRestDay(_ date: JourCivil, inIsrael: Bool) -> Bool {
        avecCalendrier(date, inIsrael) { $0.isAssurBemelacha() }
    }

    /// Yom Tov seul, samedis ordinaires exclus.
    public static func isYomTov(_ date: JourCivil, inIsrael: Bool) -> Bool {
        avecCalendrier(date, inIsrael) { $0.isYomTovAssurBemelacha() }
    }

    /// Vrai si le lendemain est chômé : la fête entre au coucher du soleil.
    public static func isEveOfRestDay(_ date: JourCivil, inIsrael: Bool) -> Bool {
        isRestDay(date.plus(jours: 1), inIsrael: inIsrael)
    }

    /// Israël par défaut si le téléphone est à l'heure de Jérusalem, diaspora partout ailleurs.
    public static func defaultInIsrael(timeZoneId: String) -> Bool {
        ["Asia/Jerusalem", "Asia/Tel_Aviv", "Israel"].contains(timeZoneId)
    }

    private static let verrou = Mutex(())

    /// Le jour civil à midi UTC, lu en UTC : aucun fuseau ne peut le déplacer.
    private static func avecCalendrier(_ date: JourCivil, _ inIsrael: Bool, _ lire: (JewishCalendar) -> Bool) -> Bool {
        verrou.withLock { _ in
            let utc = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
            let midi = Date(timeIntervalSince1970: Double(date.jourJulien - 2_440_588) * 86_400 + 43_200)
            return lire(JewishCalendar(workingDate: midi, timezone: utc, inIsrael: inIsrael))
        }
    }
}
