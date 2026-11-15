import Foundation

// Les règles des rappels et des alertes, sans notification ni alarme : `ReminderRule.kt`, la part pure de
// `Reminder.kt`, `ChabbatAlerte.kt` et `LevanaAlerte.kt`. Android pose une alarme et décide quand elle sonne ;
// iOS décide à la programmation (PORTAGE.md § 2.2.2) : `PlanNotifications` applique ces règles d'avance.
// Jugé par `Tests/Vecteurs/barriere.json` (tools/vecteurs_ios/VecteursBarriere.kt).

/// `ReminderRule.kt` : quand le rappel se tait, et quand tombe le prochain.
///
/// Le calendrier hébraïque raisonne en date civile, alors que la fête entre au coucher du soleil la veille :
/// faute de coucher calculé, la veille d'un jour chômé, plus aucun rappel après midi.
public enum ReminderRule {

    public static let minutesParJour = 24 * 60

    /// `NO_SUNSET_CUTOFF_MINUTES` : la limite retenue faute de coucher du soleil calculable.
    public static let limiteSansCoucher = 12 * 60

    /// Les heures (minutes depuis minuit) hors du jour sont ignorées, les doublons aussi ; triées.
    static func propres(_ heures: [Int]) -> [Int] {
        var vues = Set<Int>()
        return heures.filter { (0..<minutesParJour).contains($0) && vues.insert($0).inserted }.sorted()
    }

    /// `minutesUntilNext` : dans combien de minutes tombe le prochain rappel ; quand toutes les heures sont
    /// passées, la première du lendemain. nil sans heure réglée : rien à programmer.
    public static func minutesAvantProchain(_ maintenant: Int, heures: [Int]) -> Int? {
        let p = propres(heures)
        guard let premiere = p.first else { return nil }
        if let suivante = p.first(where: { $0 > maintenant }) { return suivante - maintenant }
        return (minutesParJour - maintenant) + premiere
    }

    /// `prochainDeclenchement` : le prochain rappel, recalculé à l'heure civile du fuseau, pour qu'un changement
    /// d'heure ne le décale pas (revue du 29/09) ; aujourd'hui puis demain. Une heure qui n'existe pas ce jour-là
    /// (passage à l'heure d'été) est avancée de la durée du trou.
    public static func prochainDeclenchement(_ maintenant: DateHeureZonee, heures: [Int]) -> DateHeureZonee? {
        let p = propres(heures)
        let jour = maintenant.jour
        for decalage in 0...1 {
            for h in p {
                let t = DateHeureZonee(DateHeure(jour.plus(jours: decalage), heure: h / 60, minute: h % 60),
                                       fuseau: maintenant.fuseau)
                if t > maintenant { return t }
            }
        }
        return nil
    }

    /// `shouldNotify` : le rappel sonne-t-il à `maintenant` (minutes depuis minuit) ? Jamais une journée faite ni un
    /// jour chômé ; la veille d'un jour chômé, avant le coucher du soleil, ou avant midi sans coucher connu.
    public static func doitSonner(maintenant: Int, faite: Bool, repos: Bool, veilleDeRepos: Bool, coucher: Int?) -> Bool {
        if faite { return false }
        if repos { return false }
        if !veilleDeRepos { return true }
        return maintenant < (coucher ?? limiteSansCoucher)
    }

    /// `Reminder.SNOOZE_MINUTES` : « Plus tard » sur la notification reporte le rappel d'une demi-heure.
    public static let reportMinutes = 30
}

/// `ChabbatAlerte.kt` (13/10) : « Chabbat dans 3 h », trois heures avant l'allumage du vendredi, au lieu des
/// zmanim et avec les minutes d'allumage des réglages. Sans lieu, pas d'heure d'allumage : rien n'est programmé.
public enum ChabbatAlerte {

    /// `AVANCE_HEURES`.
    public static let avanceHeures = 3

    /// `prochaine` : l'allumage du vendredi qui vient (ou du suivant, si l'alerte de celui-ci est passée) moins
    /// trois heures, strictement après `maintenant`. `allumage` donne l'heure d'allumage d'un jour, ou nil.
    public static func prochaine(_ maintenant: DateHeureZonee, allumage: (JourCivil) -> DateHeureZonee?) -> DateHeureZonee? {
        var vendredi = maintenant.jour
        while vendredi.jourDeSemaine != 6 { vendredi = vendredi.plus(jours: 1) }
        for _ in 0..<2 {
            if let alerte = allumage(vendredi)?.plus(heures: -avanceHeures), alerte > maintenant { return alerte }
            vendredi = vendredi.plus(jours: 7)
        }
        return nil
    }

    /// Les `nombre` alertes à venir, chacune cherchée depuis la précédente : iOS les pose toutes d'avance.
    public static func suivantes(_ maintenant: DateHeureZonee, nombre: Int,
                                 allumage: (JourCivil) -> DateHeureZonee?) -> [DateHeureZonee] {
        var resultat: [DateHeureZonee] = []
        var depuis = maintenant
        while resultat.count < nombre, let a = prochaine(depuis, allumage: allumage) {
            resultat.append(a)
            depuis = a
        }
        return resultat
    }

    /// `Zmanim.allumage(lieu, d, minutes).local` : l'allumage au lieu, à l'heure du lieu.
    public static func allumage(_ lieu: Zmanim.Lieu, _ date: JourCivil, minutes: Int) -> DateHeureZonee? {
        guard let fuseau = Fuseau(lieu.fuseau), let t = Zmanim.allumage(lieu: lieu, date: date, minutes: minutes).instant
        else { return nil }
        return DateHeureZonee(millis: Zmanim.millis(t), fuseau: fuseau)
    }
}

/// `LevanaAlerte.kt` (14/10) : le rappel de Birkat haLevana à la sortie des étoiles du premier soir possible, du
/// motsaé Chabbat conseillé et du dernier soir, selon l'usage suivi.
public enum LevanaAlerte {

    public enum Soir: String, Sendable, CaseIterable {
        case premier = "PREMIER", motsae = "MOTSAE", dernier = "DERNIER"

        /// La chaîne du titre de la notification.
        public var cleTitre: String {
            switch self {
            case .premier: "levana_rappel_premier"
            case .motsae: "levana_rappel_motsae"
            case .dernier: "levana_rappel_dernier"
            }
        }
    }

    /// `soirs` : les soirs à rappeler d'une fenêtre, à partir de `depuis`, dans l'ordre des jours.
    public static func soirs(_ f: Levana.Fenetre, depuis: JourCivil, fuseau: Fuseau) -> [(jour: JourCivil, soir: Soir)] {
        let premier = f.premierSoir(fuseau)
        let dernier = f.dernierSoir(fuseau)
        var liste: [(jour: JourCivil, soir: Soir)] = [(premier, .premier)]
        if let m = Levana.motsaeChabbat(f, premier, fuseau), m != premier, m != dernier { liste.append((m, .motsae)) }
        if dernier != premier { liste.append((dernier, .dernier)) }
        // sortedBy, stable.
        return liste.enumerated().filter { !($0.element.jour < depuis) }
            .sorted { ($0.element.jour, $0.offset) < ($1.element.jour, $1.offset) }
            .map { $0.element }
    }

    /// `prochain` : le prochain rappel strictement après `maintenant`, à `heure` du soir dit, tant que la fenêtre
    /// n'est pas fermée ; trois fenêtres au plus.
    public static func prochain(_ maintenant: DateHeureZonee, usage: Levana.Usage,
                                heure: (JourCivil) -> DateHeureZonee) -> (quand: DateHeureZonee, soir: Soir)? {
        let fuseau = maintenant.fuseau
        var date = maintenant.jour
        for _ in 0..<3 {
            let f = Levana.fenetre(date, fuseau, usage)
            for (jour, soir) in soirs(f, depuis: maintenant.jour, fuseau: fuseau) {
                let quand = heure(jour)
                if quand > maintenant && !(quand.millis > f.fin) { return (quand, soir) }
            }
            date = f.dernierSoir(fuseau).plus(jours: 1)
        }
        return nil
    }

    /// Les `nombre` rappels à venir, chacun cherché depuis le précédent.
    public static func suivants(_ maintenant: DateHeureZonee, nombre: Int, usage: Levana.Usage,
                                heure: (JourCivil) -> DateHeureZonee) -> [(quand: DateHeureZonee, soir: Soir)] {
        var resultat: [(quand: DateHeureZonee, soir: Soir)] = []
        var depuis = maintenant
        while resultat.count < nombre, let r = prochain(depuis, usage: usage, heure: heure) {
            resultat.append(r)
            depuis = r.quand
        }
        return resultat
    }

    /// `heure` : la sortie des étoiles au lieu des alertes ce soir-là, sinon 20 h, vue de `fuseau`.
    public static func heure(_ date: JourCivil, lieu: Zmanim.Lieu?, fuseau: Fuseau) -> DateHeureZonee {
        if let lieu, let t = Zmanim.jour(lieu: lieu, date: date).first(where: { $0.cle == "tset" })?.instant {
            return DateHeureZonee(millis: Zmanim.millis(t), fuseau: fuseau)
        }
        return DateHeureZonee(DateHeure(date, heure: 20), fuseau: fuseau)
    }

    /// `VueJour.usageLevana` : l'usage réglé, sinon celui du noussa'h.
    public static func usage(_ reglages: Reglages) -> Levana.Usage {
        reglages.levanaUsage ?? Levana.Usage.duNusah(reglages.nusah)
    }
}

extension Zmanim {
    /// Un instant de KosherSwift en millisecondes Unix.
    static func millis(_ d: Date) -> Int64 { Int64((d.timeIntervalSince1970 * 1000).rounded(.down)) }
}
