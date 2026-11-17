import Foundation

/// Faut-il sonner le rappel maintenant, et quand sonne le prochain (ReminderRule.kt).
///
/// Le calendrier hébraïque raisonne en date civile, alors que la fête entre au coucher du soleil la
/// veille : un rappel du soir tomberait en pleine entrée de Chabbat ou de Yom Tov. Avec un lieu de zmanim
/// réglé, l'heure d'allumage des bougies sert de limite (FBARRIERE-12) ; sans lieu, midi reste la limite sûre.
///
/// Les heures réglées sont des minutes depuis minuit ; « maintenant » se passe en argument, rien ici ne
/// lit l'horloge. Jugée par `Tests/Vecteurs/rappels.json` (tools/vecteurs_ios/VecteursRappels.kt).
public enum ReminderRule {

    /// Limite retenue faute de coucher du soleil calculable : midi.
    public static let noSunsetCutoffMinutes = 12 * 60

    public static let minutesParJour = 24 * 60

    /// Dans combien de minutes tombe le prochain rappel ?
    ///
    /// Quand toutes les heures sont déjà passées, on repart sur la première du lendemain, d'où le retour
    /// à travers minuit plutôt qu'un simple « première heure après maintenant ». Rend nil si aucune heure
    /// n'est réglée : il n'y a alors rien à programmer, et l'appelant annule l'alarme au lieu d'en poser une.
    /// Les soustractions débordent en silence, comme celles d'un `Int` de Kotlin (32 bits), pour qu'un
    /// « maintenant » insensé reçoive la réponse d'Android plutôt qu'un arrêt.
    public static func minutesUntilNext(nowMinutes: Int, heures: [Int]) -> Int? {
        let propres = heuresDuJour(heures)
        guard let premiere = propres.first else { return nil }
        let maintenant = Int32(truncatingIfNeeded: nowMinutes)
        if let suivante = propres.first(where: { Int32($0) > maintenant }) {
            return Int(Int32(suivante) &- maintenant)
        }
        return Int((Int32(minutesParJour) &- maintenant) &+ Int32(premiere))
    }

    /// L'instant du prochain rappel, dans le fuseau de `maintenant`.
    ///
    /// Calculé en heure murale, jour par jour : ajouter des minutes à l'instant présent décalait le rappel
    /// d'une heure les jours de changement d'heure (revue du 29/09). Une heure qui n'existe pas ce jour-là
    /// (2 h 30 au passage à l'heure d'été) est repoussée d'autant, et celle qui existe deux fois est la
    /// première, comme `ZonedDateTime.of`. Comme sur Android, les candidats d'aujourd'hui puis de demain
    /// sont pris dans l'ordre des heures, et le premier qui tombe après maintenant l'emporte : le jour du
    /// passage à l'heure d'été, 2 h 30 (devenue 3 h 30) passe devant 3 h 20.
    public static func prochainDeclenchement(maintenant: DateHeureZonee, heures: [Int]) -> DateHeureZonee? {
        let propres = heuresDuJour(heures)
        let jour = maintenant.jour
        for decalage in 0...1 {
            for heure in propres {
                let civile = DateHeure(jour.plus(jours: decalage), heure: heure / 60, minute: heure % 60)
                let candidat = DateHeureZonee(civile, fuseau: maintenant.fuseau)
                if candidat > maintenant { return candidat }
            }
        }
        return nil
    }

    public static func shouldNotify(nowMinutes: Int, doneToday: Bool, todayIsRestDay: Bool,
                                    tomorrowIsRestDay: Bool, sunsetMinutes: Int?) -> Bool {
        if doneToday { return false }
        if todayIsRestDay { return false }
        if !tomorrowIsRestDay { return true }
        let cutoff = sunsetMinutes ?? noSunsetCutoffMinutes
        return nowMinutes < cutoff
    }

    /// Les heures du jour seules, sans doublon, dans l'ordre :
    /// `filter { it in 0 until MINUTES_PAR_JOUR }.distinct().sorted()`.
    private static func heuresDuJour(_ heures: [Int]) -> [Int] {
        Set(heures.filter { $0 >= 0 && $0 < minutesParJour }).sorted()
    }
}
