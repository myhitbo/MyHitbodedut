import Foundation

/// « Chabbat dans 3 h » (ChabbatAlerte.kt, demande du 13/10) : une alerte trois heures avant l'allumage
/// des bougies du vendredi, au lieu choisi pour les zmanim et avec les minutes d'allumage des réglages.
/// Sans lieu, pas d'heure d'allumage : rien n'est programmé. Ici le seul calcul de l'instant ; la
/// notification et sa programmation, une seule alarme reprogrammée à chaque déclenchement, restent à
/// l'app. Jugée par `Tests/Vecteurs/rappels.json` (tools/vecteurs_ios/VecteursRappels.kt).
public enum ChabbatAlerte {

    /// L'avance de l'alerte sur l'allumage, en heures.
    public static let avanceHeures = 3

    /// Le prochain moment d'alerte après `maintenant` : l'allumage du vendredi qui vient (ou de la
    /// semaine suivante, si celui-ci est passé) moins trois heures. `allumage` donne l'heure d'allumage
    /// d'une date, ou nil si elle n'existe pas (sur l'app : `Zmanim.allumage` au lieu des alertes).
    /// L'alerte garde le fuseau de l'heure d'allumage ; les trois heures sont du temps écoulé
    /// (`minus(Duration.ofHours(3))`), pas trois heures d'horloge.
    public static func prochaine(maintenant: DateHeureZonee, allumage: (JourCivil) -> DateHeureZonee?) -> DateHeureZonee? {
        var vendredi = maintenant.jour
        while vendredi.jourDeSemaine != jourDuVendredi { vendredi = vendredi.plus(jours: 1) }
        for _ in 0..<2 {
            if let alerte = allumage(vendredi)?.plus(heures: -avanceHeures), alerte > maintenant { return alerte }
            vendredi = vendredi.plus(jours: 7)
        }
        return nil
    }

    /// Le vendredi dans la numérotation de `JourCivil.jourDeSemaine` (1 = dimanche … 7 = samedi).
    private static let jourDuVendredi = 6
}
