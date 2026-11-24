import Coeur
import Ecrans
import Foundation

/// Le planificateur des notifications de l'app (PORTAGE.md § 2.2.2) : `PlanNotifications.planifier` de Coeur, le
/// plan entier d'après le journal et les réglages, puis sa pose par le `SystemeNotificateur`. Il remplace
/// `Reminder.reschedule`, `ChabbatAlerte.programmer`, `LevanaAlerte.programmer` et `VolAlerte.programmer`
/// d'Android : iOS ne réveille pas l'app pour une notification locale, tout est donc posé d'avance, et repassé à
/// chaque ouverture, séance, changement de réglage ou de lieu.
///
/// C'est la `PresentationRappels` de la présentation ; l'accueil (`SystemeAccueil`) et les réglages
/// (`SystemeEffetsReglages`) s'en servent aussi.
///
/// Le plan porte, pour chaque notification, une seconde ligne, des boutons et le texte du siddour qu'elle ouvre,
/// que `NotificationPrevue` des Services n'a pas : il est donc posé tel quel par `SystemeNotificateur.poser(plan:)`
/// plutôt que converti en `NotificationPrevue`, ce qui perdrait la seconde ligne (la phrase du trophée tout proche,
/// la prière du moment sous Tefilat haDerekh).
@MainActor
final class SystemeRappels: PresentationRappels {

    private let magasin: Magasin
    private let notificateur: SystemeNotificateur
    private let traducteur: Traducteur
    private let horloge: any Horloge
    /// La lecture des aéroports (`VolModele.lireAeroports`) : les heures du vol s'écrivent à l'heure des deux
    /// aéroports, comme l'écran du vol les écrit. Lue au premier vol gardé, puis gardée.
    private let lireAeroports: (@Sendable () async throws -> [Vol.Aeroport])?
    private var aeroports: [Vol.Aeroport]?

    init(magasin: Magasin, notificateur: SystemeNotificateur, traducteur: Traducteur,
         horloge: any Horloge = HorlogeSysteme(),
         aeroports: (@Sendable () async throws -> [Vol.Aeroport])? = nil) {
        self.magasin = magasin
        self.notificateur = notificateur
        self.traducteur = traducteur
        self.horloge = horloge
        lireAeroports = aeroports
    }

    // MARK: PresentationRappels

    /// Les réglages viennent d'être changés par la présentation : le plan les suit, avec le journal du magasin.
    func replanifier(_ reglages: Reglages) async {
        await replanifier(journal: magasin.journal, reglages: reglages)
    }

    // MARK: Ce que l'app fait de plus

    /// Le plan d'après le magasin tel qu'il est.
    func replanifier() async {
        await replanifier(journal: magasin.journal, reglages: magasin.reglages)
    }

    /// Le plan d'après ce journal et ces réglages, calculé hors du fil principal (les zmanim de dix jours, les
    /// prochains Chabbat et la Levana), puis posé.
    func replanifier(journal: Journal, reglages: Reglages) async {
        let maintenant = horloge.maintenant
        let fuseau = horloge.fuseau
        let formats = VolFormats.langue(traducteur.langue)
        let vol = await volGarde(reglages)
        let plan = await Task.detached(priority: .utility) {
            SystemeRappels.calculer(journal: journal, reglages: reglages, maintenant: maintenant, fuseau: fuseau,
                                    vol: vol, formats: formats)
        }.value
        await notificateur.poser(plan: plan)
    }

    /// Le vol gardé dans les réglages, s'il a des rappels à poser ; nil sinon, ou si les aéroports ne se lisent pas
    /// (les heures s'écrivent alors comme `Instant.toString()`, ce que fait le plan sans vol).
    private func volGarde(_ reglages: Reglages) async -> Vol.Plan? {
        guard reglages.volRappelsActifs, !VolStockage.rappels(reglages).isEmpty else { return nil }
        if aeroports == nil, let lireAeroports {
            aeroports = try? await lireAeroports()
        }
        guard let aeroports else { return nil }
        return VolStockage.plan(reglages, aeroports)
    }

    private nonisolated static func calculer(journal: Journal, reglages: Reglages, maintenant: Int64, fuseau: Fuseau,
                                             vol: Vol.Plan?, formats: VolFormats) -> [NotificationPlanifiee] {
        PlanNotifications.planifier(
            reglages: reglages, journal: journal, volRappels: VolStockage.rappels(reglages),
            maintenant: maintenant, fuseau: fuseau,
            horaires: { lieu, jour in PlanNotifications.horairesCalcules(lieu, jour) },
            allumage: { lieu, jour, minutes in PlanNotifications.allumageCalcule(lieu, jour, minutes) },
            heureVol: { t in
                guard let vol else { return PlanNotifications.instantTexte(t) }
                return VolMiseEnPage.texteDeuxHeures(vol, t, formats)
            })
    }
}
