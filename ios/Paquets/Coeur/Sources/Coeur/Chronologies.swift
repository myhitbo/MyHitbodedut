import Foundation

/// Les chronologies des vignettes des zmanim pour WidgetKit (PORTAGE.md § 2.2.3).
///
/// Sur Android, la vignette est une image redessinée par une alarme au prochain changement (ZmanimVignette.programmer,
/// ZmanimTic). WidgetKit demande la liste, calculée d'avance, de ce que le widget montrera et quand : une entrée par
/// zman du jour au lieu choisi, une au milieu de la nuit d'hier tel que ZmanimWidget.prochaine le compte, la première
/// à l'instant du calcul ; le jour hébreu bascule à l'entrée de tsét (ZmanimVignette.jourHebreuAffiche). Entre deux
/// entrées, rien de ce qui s'affiche ne change, hormis le temps qui reste et la jauge, que l'app dessine avec
/// `Text(timerInterval:)` depuis `debut` et `limite`. La chronologie va jusqu'au minuit suivant du lieu, l'instant
/// de la prochaine recharge (`recharge`).
///
/// Ce qui s'affiche est celui de ZmanimVignette.vues, sans les vues : la date hébraïque et la pastille en tête (la
/// fête du jour, sinon la paracha de la semaine), la prière du moment et sa limite (`ZmanimWidget.prochaine`), et
/// selon la famille les trois zmanim à venir (moyenne) ou la journée entière et son prochain zman (grande). Sans
/// lieu, « zmanim_choisir_lieu » et la date du téléphone, qui change à minuit. Rien ne lit l'heure, le fuseau de la
/// machine ni les réglages : le lieu, `maintenant` (millisecondes Unix), le fuseau du téléphone et Israël ou diaspora
/// sont passés, les zmanim aussi s'il le faut (`horaires`). Jugé par `Tests/Vecteurs/chronologies.json`
/// (tools/vecteurs_ios/VecteursChronologies.kt).
public enum Chronologies {

    /// Les trois tailles (ZmanimVignette.Taille) : une famille de widget chacune.
    public enum Famille: String, Sendable, Hashable, CaseIterable {
        /// 2 × 2 : la prière du moment, l'heure où elle se ferme, une jauge.
        case petite
        /// 4 × 2 : la même, le temps qui reste, la série, les trois zmanim à venir.
        case moyenne
        /// 4 × 4 : la même et la journée entière, le prochain zman en évidence.
        case grande
    }

    /// Un zman montré : sa clé (son nom est la chaîne « zman_<clé> ») et son instant.
    public struct ZmanAffiche: Sendable, Hashable {
        public let cle: String
        public let instant: Int64

        public init(cle: String, instant: Int64) {
            self.cle = cle
            self.instant = instant
        }

        /// Le nom de sa chaîne (ZmanimVignette.NOMS).
        public var libelle: String { "zman_" + cle }
    }

    /// Ce que la vignette montre.
    public struct Affichage: Sendable, Hashable {
        /// La date civile dont le jour hébreu est montré : le lendemain une fois tsét passée.
        public let jourHebreu: JourCivil
        /// `CalendrierJuif.Jour.dateHebraique` de `jourHebreu`.
        public let dateHebraique: String
        /// La fête du jour, sinon la paracha de la semaine (« widget_paracha ») ; nil sans l'une ni l'autre.
        public let pastille: Libelle?
        /// « chaharit », « minha » ou « arvit » ; nil sans lieu.
        public let priere: String?
        /// Où la prière se ferme, en millisecondes Unix ; nil quand aucune limite n'est affichée.
        public let limite: Int64?
        /// Où commence la fenêtre de la jauge (ZmanimVignette.debut).
        public let debut: Int64?
        /// La moyenne : les trois zmanim à venir (une case vide est nil). Vide pour les autres.
        public let prochains: [ZmanAffiche?]
        /// La grande : la journée d'aujourd'hui, ou de demain une fois la nuit tombée. Vide pour les autres.
        public let journee: [ZmanAffiche]
        /// La grande : l'indice du prochain zman dans `journee`.
        public let prochain: Int?

        /// La ligne de la prière : « Cha'harit », « Min'ha », « Arvit », ou l'invitation à choisir un lieu.
        public var titre: Libelle {
            guard let priere else { return Libelle("zmanim_choisir_lieu") }
            switch priere {
            case "chaharit": return Libelle("widget_zmanim_chaharit")
            case "minha": return Libelle("widget_zmanim_minha")
            default: return Libelle("widget_zmanim_arvit")
            }
        }
    }

    public struct Entree: Sendable, Hashable {
        /// Quand l'entrée commence à s'afficher, en millisecondes Unix.
        public let instant: Int64
        public let affichage: Affichage
    }

    public struct Chronologie: Sendable, Hashable {
        /// Dans l'ordre du temps, la première à l'instant du calcul.
        public let entrees: [Entree]
        /// Le minuit suivant du lieu (du téléphone sans lieu) : quand WidgetKit doit redemander la chronologie.
        public let recharge: Int64
    }

    /// Les zmanim d'un jour au lieu donné, par clé (`Zmanim.Zman.cle`), en millisecondes Unix ; un zman absent
    /// manque. Le type est propre à ce fichier : PlanNotifications.swift, qui a le même, n'est pas encore construit
    /// (Package.swift, `enChantierSources`).
    public typealias Horaires = (_ lieu: Zmanim.Lieu, _ jour: JourCivil) -> [String: Int64]

    // MARK: La chronologie

    /// La chronologie du reste de la journée, avec les zmanim de `Zmanim`.
    public static func chronologie(famille: Famille, lieu: Zmanim.Lieu?, maintenant: Int64, fuseauTelephone: Fuseau,
                                   enIsrael: Bool) -> Chronologie {
        chronologie(famille: famille, lieu: lieu, maintenant: maintenant, fuseauTelephone: fuseauTelephone,
                    enIsrael: enIsrael, horaires: { l, jour in horairesCalcules(l, jour) })
    }

    /// La chronologie du reste de la journée du lieu : une entrée à `maintenant`, puis une à chaque zman du jour et au
    /// milieu de la nuit d'hier, jusqu'au minuit suivant, exclu.
    public static func chronologie(famille: Famille, lieu: Zmanim.Lieu?, maintenant: Int64, fuseauTelephone: Fuseau,
                                   enIsrael: Bool, horaires: Horaires) -> Chronologie {
        let zone = zoneDe(lieu, fuseauTelephone)
        let ici = DateHeureZonee(millis: maintenant, fuseau: zone)
        let minuit = DateHeureZonee(DateHeure(ici.jour.plus(jours: 1)), fuseau: zone).millis
        var duJour: [String: Int64] = [:]
        var demain: [String: Int64] = [:]
        var instants: Set<Int64> = [maintenant]
        if let lieu {
            duJour = horaires(lieu, ici.jour)
            demain = horaires(lieu, ici.jour.plus(jours: 1))
            for t in duJour.values { instants.insert(t) }
            if let milieu = duJour["chatsot_layla"] {
                instants.insert(veille(DateHeureZonee(millis: milieu, fuseau: zone)).millis)
            }
        }
        let tries = instants.filter { $0 >= maintenant && $0 < minuit }.sorted()
        let entrees = tries.map { t in
            Entree(instant: t, affichage: affichage(famille: famille, aLieu: lieu != nil, maintenant: t, zone: zone,
                                                     duJour: duJour, demain: demain, enIsrael: enIsrael))
        }
        return Chronologie(entrees: entrees, recharge: minuit)
    }

    /// Ce que la vignette montre à `maintenant`, avec les zmanim de `Zmanim`.
    public static func affichage(famille: Famille, lieu: Zmanim.Lieu?, maintenant: Int64, fuseauTelephone: Fuseau,
                                 enIsrael: Bool) -> Affichage {
        affichage(famille: famille, lieu: lieu, maintenant: maintenant, fuseauTelephone: fuseauTelephone,
                  enIsrael: enIsrael, horaires: { l, jour in horairesCalcules(l, jour) })
    }

    /// Ce que la vignette montre à `maintenant` (ZmanimVignette.vues).
    public static func affichage(famille: Famille, lieu: Zmanim.Lieu?, maintenant: Int64, fuseauTelephone: Fuseau,
                                 enIsrael: Bool, horaires: Horaires) -> Affichage {
        let zone = zoneDe(lieu, fuseauTelephone)
        let jour = DateHeureZonee(millis: maintenant, fuseau: zone).jour
        var duJour: [String: Int64] = [:]
        var demain: [String: Int64] = [:]
        if let lieu {
            duJour = horaires(lieu, jour)
            demain = horaires(lieu, jour.plus(jours: 1))
        }
        return affichage(famille: famille, aLieu: lieu != nil, maintenant: maintenant, zone: zone, duJour: duJour,
                         demain: demain, enIsrael: enIsrael)
    }

    // MARK: Aides

    /// Les zmanim de `Zmanim.jour`, en millisecondes Unix (comme `PlanNotifications.horairesCalcules`).
    private static func horairesCalcules(_ lieu: Zmanim.Lieu, _ jour: JourCivil) -> [String: Int64] {
        var res: [String: Int64] = [:]
        for z in Zmanim.jour(lieu: lieu, date: jour) {
            if let instant = z.instant {
                res[z.cle] = Kotlin.versLong((instant.timeIntervalSince1970 * 1000).rounded())
            }
        }
        return res
    }

    /// Le fuseau du lieu, sinon celui du téléphone (un fuseau inconnu compte comme absent, comme `runCatching`).
    private static func zoneDe(_ lieu: Zmanim.Lieu?, _ fuseauTelephone: Fuseau) -> Fuseau {
        guard let lieu, let zone = Fuseau(lieu.fuseau) else { return fuseauTelephone }
        return zone
    }

    /// `duJour` : les zmanim du jour civil de `maintenant` dans `zone` ; `demain` : ceux du lendemain.
    private static func affichage(famille: Famille, aLieu: Bool, maintenant: Int64, zone: Fuseau, duJour: [String: Int64],
                                  demain: [String: Int64], enIsrael: Bool) -> Affichage {
        let ici = DateHeureZonee(millis: maintenant, fuseau: zone)
        var horaires: [String: DateHeureZonee] = [:]
        for (cle, t) in duJour { horaires[cle] = DateHeureZonee(millis: t, fuseau: zone) }
        // Le jour hébreu commence à la sortie des étoiles du lieu (02/11) : le vendredi soir, la vignette dit déjà
        // Chabbat. Sans lieu, pas de tsét connu : minuit.
        let jourHebreu = ZmanimVignette.jourHebreuAffiche(maintenant: ici, tset: horaires["tset"])
        let jour = CalendrierJuif.jour(jourHebreu, enIsrael: enIsrael)
        var pastille: Libelle?
        for fete in jour.fetes {
            if let cle = Libelles.res(fete) {
                pastille = Libelle(cle)
                break
            }
        }
        if pastille == nil {
            // `with(TemporalAdjusters.nextOrSame(SATURDAY))` : `jourDeSemaine` vaut 7 le samedi.
            let samedi = jourHebreu.plus(jours: 7 - jourHebreu.jourDeSemaine)
            if let paracha = CalendrierJuif.jour(samedi, enIsrael: enIsrael).paracha {
                pastille = Libelle("widget_paracha", .texte(paracha))
            }
        }
        guard aLieu else {
            return Affichage(jourHebreu: jourHebreu, dateHebraique: jour.dateHebraique, pastille: pastille, priere: nil,
                             limite: nil, debut: nil, prochains: [], journee: [], prochain: nil)
        }
        let moment = ZmanimWidget.prochaine(horaires: horaires, maintenant: ici)
        let debut = ZmanimVignette.debut(priere: moment.priere, horaires: horaires)
        // La journée : aujourd'hui, ou demain une fois la nuit tombée.
        var journee = journeeDe(duJour)
        if !journee.contains(where: { $0.instant > maintenant }) {
            journee = journeeDe(demain)
        }
        // `indexOfFirst` : -1 quand aucun n'est à venir, et la moyenne lit alors à partir de -1 (`getOrNull`).
        let prochain = journee.firstIndex { $0.instant > maintenant } ?? -1
        var prochains: [ZmanAffiche?] = []
        var montree: [ZmanAffiche] = []
        var indice: Int?
        switch famille {
        case .petite:
            break
        case .moyenne:
            for k in 0..<3 {
                let i = prochain + k
                prochains.append(i >= 0 && i < journee.count ? journee[i] : nil)
            }
        case .grande:
            montree = journee
            indice = prochain >= 0 ? prochain : nil
        }
        return Affichage(jourHebreu: jourHebreu, dateHebraique: jour.dateHebraique, pastille: pastille,
                         priere: moment.priere, limite: moment.limite?.millis, debut: debut?.millis,
                         prochains: prochains, journee: montree, prochain: indice)
    }

    /// Les zmanim de la journée de la grande vignette, dans l'ordre (ZmanimVignette.journee), ceux qui existent.
    private static func journeeDe(_ horaires: [String: Int64]) -> [ZmanAffiche] {
        var res: [ZmanAffiche] = []
        for cle in ZmanimVignette.journee {
            if let t = horaires[cle] { res.append(ZmanAffiche(cle: cle, instant: t)) }
        }
        return res
    }

    /// `minusDays(1)` de `ZonedDateTime`, comme ZmanimWidget le prend pour le milieu de la nuit d'hier : la même heure
    /// civile la veille, au décalage d'origine s'il y vaut encore (l'heure qui existe deux fois).
    private static func veille(_ instant: DateHeureZonee) -> DateHeureZonee {
        let fuseau = instant.fuseau
        let civile = instant.civile.plus(jours: -1)
        let decalage = Int64(fuseau.decalage(millis: instant.millis)) * 1000
        let commeEnUTC = Int64(civile.jour.jourJulien - 2_440_588) * 86_400_000 + Int64(civile.millisDuJour)
        let garde = commeEnUTC - decalage
        if Int64(fuseau.decalage(millis: garde)) * 1000 == decalage {
            return DateHeureZonee(millis: garde, fuseau: fuseau)
        }
        return DateHeureZonee(civile, fuseau: fuseau)
    }
}
