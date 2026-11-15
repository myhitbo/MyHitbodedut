import Foundation

/// Ce que `Store.kt` décide de la pratique sans contexte Android : le jour exempté, la série, la semaine, les
/// anneaux, la fenêtre de « Je suis avec Hachem », la reprise d'une prière, le jour du Tikoun. Le jour et l'heure
/// qu'il est sont passés en argument ; le journal et les réglages sont ceux de `Sauvegarde.swift`.
/// Jugé par `Tests/Vecteurs/pratique.json`.
public enum Pratique {

    /// `Store.DEFAULT_TARGET` : 15 minutes, ce que le conseil n° 2 recommande pour commencer (revue du 29/09).
    public static let dureeParDefaut = 15

    /// `Store.PRIERE_REPRISE_MS` : une prière du siddour reprend où on l'a laissée seulement dans les trois heures.
    public static let priereRepriseMillis: Int64 = 3 * 60 * 60 * 1000

    /// `Store.joursFaits` : les journées qui comptent, faites ou déclarées, pas les notes seules.
    public static func joursFaits(_ journal: Journal) -> Set<JourCivil> {
        Set(journal.jours.filter { $0.value.faite }.keys)
    }

    /// `Store.isExempt` : une date mise en pause, ou un Chabbat ou un Yom Tov quand l'option est active.
    public static func exempte(_ date: JourCivil, _ reglages: Reglages) -> Bool {
        if reglages.joursPause.contains(date.iso) { return true }
        return reglages.pauseShabbat && Holidays.isRestDay(date, inIsrael: reglages.enIsrael)
    }

    /// `Store.streak` : les jours consécutifs validés jusqu'à aujourd'hui (ou hier, si aujourd'hui reste à faire) ;
    /// un jour exempté ne compte pas et ne casse pas. Dix ans au plus.
    public static func serie(faits: Set<JourCivil>, aujourdhui: JourCivil, exempte: (JourCivil) -> Bool) -> Int {
        var jour = aujourdhui
        if !faits.contains(jour) && !exempte(jour) { jour = jour.plus(jours: -1) }
        var compte = 0
        for _ in 0..<3650 {
            if faits.contains(jour) {
                compte += 1
            } else if !exempte(jour) {
                return compte
            }
            jour = jour.plus(jours: -1)
        }
        return compte
    }

    /// `Store.meilleureSerie` : la plus longue série jamais tenue, au moins la série en cours.
    public static func meilleureSerie(faits: Set<JourCivil>, aujourdhui: JourCivil, exempte: (JourCivil) -> Bool) -> Int {
        max(Plaque.meilleureSerie(faits, exempte: exempte), serie(faits: faits, aujourdhui: aujourdhui, exempte: exempte))
    }

    /// `Store.currentWeek` : la semaine en cours, du dimanche au samedi, comme se compte la semaine juive.
    public static func semaine(aujourdhui: JourCivil, faits: Set<JourCivil>, exempte: (JourCivil) -> Bool) -> [CaseSemaine] {
        let dimanche = aujourdhui.plus(jours: 1 - aujourdhui.jourDeSemaine)
        return (0...6).map { k in
            let jour = dimanche.plus(jours: k)
            return CaseSemaine(date: jour, faite: faits.contains(jour), exemptee: exempte(jour), chabbat: k == 6,
                               aVenir: jour > aujourdhui)
        }
    }

    /// `Store.dailyGoal` : l'objectif réglé, sinon la durée habituelle.
    public static func objectifJour(_ reglages: Reglages) -> Int {
        Anneaux.objectifEffectif(regle: reglages.objectifJour, dureeHabituelle: reglages.duree)
    }

    /// `Store.anneaux` : les trois anneaux de l'accueil, ce jour-là.
    public static func anneaux(_ d: Donnees, aujourdhui: JourCivil, exempte: (JourCivil) -> Bool) -> Anneaux.Etat {
        let faits = joursFaits(d.journal)
        return Anneaux.etat(minutesJour: d.journal.jours[aujourdhui]?.minutes ?? 0, objectifJour: objectifJour(d.reglages),
                            semaine: JaugeSemaine.progression(semaine(aujourdhui: aujourdhui, faits: faits, exempte: exempte)),
                            serie: serie(faits: faits, aujourdhui: aujourdhui, exempte: exempte))
    }

    /// `Store.fenetreFaite` (02/11) : la fenêtre est-elle déjà honorée ? Une fenêtre qui passe minuit (21:00–02:00)
    /// appartient au soir où elle commence ; elle est honorée par une séance close après la fin de la fenêtre
    /// précédente (le même jour à `fin`). Sans heure connue, le jour de la fenêtre fait foi. Fenêtre dans la
    /// journée : le jour civil seul. Les minutes sont comptées depuis minuit.
    public static func fenetreFaite(debut: Int, fin: Int, maintenant: DateHeure, faitA: DateHeure?,
                                    faitLe: (JourCivil) -> Bool) -> Bool {
        if debut <= fin { return faitLe(maintenant.jour) }
        let jour = maintenant.heure * 60 + maintenant.minute < fin ? maintenant.jour.plus(jours: -1) : maintenant.jour
        guard let faitA else { return faitLe(jour) }
        return !(faitA < DateHeure(jour, heure: fin / 60, minute: fin % 60))
    }

    /// `Store.repriseValable` : une prière (« s:… ») reprend seulement juste après une interruption ; un livre,
    /// toujours. Une place enregistrée sans heure repart du début.
    public static func repriseValable(_ cle: String, quand: Int64, maintenant: Int64) -> Bool {
        guard cle.commenceParUnites("s:") else { return true }
        let ecart = maintenant &- quand
        return quand > 0 && ecart >= 0 && ecart < priereRepriseMillis
    }

    /// `Store.jourTikkun` : le jour du Tikoun bascule à 4 h, pas à minuit (bug du 02/11).
    public static func jourTikkun(_ maintenant: DateHeure) -> String {
        maintenant.plus(heures: -4).jour.iso
    }
}

/// `AjoutTemps.kt` (16/10) : du temps s'ajoute à n'importe quel jour jusqu'à aujourd'hui, jamais à un jour à venir.
/// Le dialogue reviendra avec l'écran.
public enum AjoutTemps {
    public static func possible(_ date: JourCivil, aujourdhui: JourCivil) -> Bool {
        !(date > aujourdhui)
    }
}

/// `ReminderRule.prochainDeclenchement` : le prochain rappel, recalculé à chaque fois à l'heure civile du fuseau,
/// pour qu'un changement d'heure ne le décale pas (revue du 29/09). Le reste de `ReminderRule` vient avec le
/// planificateur (tâche 12).
public enum ReminderRule {

    public static let minutesParJour = 24 * 60

    /// Les heures (minutes depuis minuit) hors du jour sont ignorées, les doublons aussi ; aujourd'hui puis demain.
    /// Une heure qui n'existe pas ce jour-là (passage à l'heure d'été) est avancée de la durée du trou.
    public static func prochainDeclenchement(_ maintenant: DateHeureZonee, heures: [Int]) -> DateHeureZonee? {
        var vues = Set<Int>()
        let propres = heures.filter { (0..<minutesParJour).contains($0) && vues.insert($0).inserted }.sorted()
        let jour = maintenant.jour
        for decalage in 0...1 {
            for h in propres {
                let t = DateHeureZonee(DateHeure(jour.plus(jours: decalage), heure: h / 60, minute: h % 60),
                                       fuseau: maintenant.fuseau)
                if t > maintenant { return t }
            }
        }
        return nil
    }
}

/// Ce que `ZmanimVignette.kt` décide sans écran (02/11) ; les chronologies des widgets viennent à la tâche 12.
public enum ZmanimVignette {

    static let pasMaxMinutes = 10

    /// Le prochain instant où la vignette change : le prochain horaire, minuit du lieu (la date en tête), minuit
    /// du téléphone, et au plus tard dans dix minutes.
    public static func prochainChangement(_ horaires: [DateHeureZonee?], maintenant: DateHeureZonee,
                                          minuitTelephone: DateHeureZonee? = nil) -> DateHeureZonee {
        let minuitLieu = DateHeureZonee(DateHeure(maintenant.jour.plus(jours: 1)), fuseau: maintenant.fuseau)
        let auPlusTard = maintenant.plus(minutes: pasMaxMinutes)
        let candidats = horaires.compactMap { $0 } + [minuitLieu, minuitTelephone, auPlusTard].compactMap { $0 }
        return candidats.filter { $0 > maintenant }.min() ?? auPlusTard
    }

    /// La date civile dont la vignette montre le jour hébreu : celle du lieu, ou le lendemain une fois la sortie
    /// des étoiles passée — le jour hébreu commence le soir.
    public static func jourHebreuAffiche(_ maintenant: DateHeureZonee, tset: DateHeureZonee?) -> JourCivil {
        if let tset, !(maintenant < tset) { return maintenant.jour.plus(jours: 1) }
        return maintenant.jour
    }
}

/// Ce que `BoussoleActivity.kt` calcule sans capteur (02/11) ; l'écran vient à la tâche 25.
public enum Boussole {

    /// `Math.toDegrees` de Java 9 et suivants.
    private static let degresParRadian = 57.29577951308232

    /// Le cap que montre le téléphone, d'après sa matrice de rotation (Est-Nord-Haut ← téléphone, ligne par ligne) :
    /// la somme du haut de l'écran (+Y) et du dos du téléphone (−Z). À plat, le premier donne le cap ; droit, le
    /// second ; entre les deux, ils pointent du même côté.
    public static func capDevant(_ r: [Float]) -> Double {
        let est = r[1] - r[2]
        let nord = r[4] - r[5]
        return DirectionJerusalem.norm(atan2(Double(est), Double(nord)) * degresParRadian)
    }

    /// Un filtre doux sur le cercle : un cinquième du chemin à chaque mesure, par le plus court côté.
    public static func lisser(_ avant: Double?, _ mesure: Double) -> Double {
        guard let avant else { return mesure }
        return DirectionJerusalem.norm(avant + DirectionJerusalem.ecart(mesure, avant) * 0.2)
    }
}
