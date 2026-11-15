import Foundation

// Ce que les vignettes des zmanim et de la série décident sans écran : `ZmanimWidget.prochaine`, la part pure de
// `ZmanimVignette.kt` et, pour WidgetKit, leurs chronologies (PORTAGE.md § 2.2.3). Android redessine ses vignettes
// par des alarmes, au prochain changement ou dix minutes au plus tard (`ZmanimTic`) ; iOS demande d'avance la
// liste de ce que la vignette montrera et quand : une entrée par zman, une au changement de jour hébreu (à tsét),
// une à minuit. Le temps qui reste et la jauge s'animent d'eux-mêmes (`Text(timerInterval:)`).
// Jugé par `Tests/Vecteurs/barriere.json` et `pratique.json`.

/// `ZmanimWidget.prochaine` : la prière du moment et sa limite.
public enum ZmanimWidget {

    /// Cha'harit jusqu'au sof zman tefila (GRA), Min'ha jusqu'à la chki'a, Arvit jusqu'au milieu de la nuit. Après
    /// minuit et avant l'aube, c'est encore la nuit d'Arvit (audit du 16/10) : jusqu'au milieu de la nuit d'hier
    /// (celui d'aujourd'hui, un jour civil plus tôt) s'il n'est pas passé, sans limite ensuite.
    public static func prochaine(_ horaires: [String: DateHeureZonee],
                                 maintenant: DateHeureZonee) -> (priere: String, limite: DateHeureZonee?) {
        if let alot = horaires["alot"], maintenant < alot {
            let hier = horaires["chatsot_layla"]?.plus(jours: -1)
            if let hier, maintenant < hier { return ("arvit", hier) }
            return ("arvit", nil)
        }
        let limites: [(String, DateHeureZonee?)] = [
            ("chaharit", horaires["szt_gra"]), ("minha", horaires["chkia"]), ("arvit", horaires["chatsot_layla"]),
        ]
        for (priere, limite) in limites {
            if let limite, maintenant < limite { return (priere, limite) }
        }
        return ("arvit", nil)
    }

    /// Le libellé de la prière (`widget_zmanim_chaharit`…).
    public static func cle(_ priere: String) -> String {
        switch priere {
        case "chaharit": "widget_zmanim_chaharit"
        case "minha": "widget_zmanim_minha"
        default: "widget_zmanim_arvit"
        }
    }
}

/// `ZmanimVignette.kt` (28/10, 02/11) : les trois vignettes des zmanim, sans leur dessin.
public enum ZmanimVignette {

    static let pasMaxMinutes = 10

    /// `JOURNEE` : la journée telle que la grande vignette la montre, dans l'ordre.
    public static let journee = ["alot", "netz", "szks_gra", "szt_gra", "chatsot", "minha_gedola", "plag", "chkia", "tset"]

    /// Le prochain instant où la vignette d'Android change : le prochain horaire, minuit du lieu (la date en tête),
    /// minuit du téléphone, et au plus tard dans dix minutes.
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

    /// `debut` : où commence la fenêtre de la prière du moment, pour la jauge : l'aube, la fin de Cha'harit, la chki'a.
    public static func debut(_ priere: String, _ horaires: [String: DateHeureZonee]) -> DateHeureZonee? {
        switch priere {
        case "chaharit": horaires["alot"]
        case "minha": horaires["szt_gra"]
        default: horaires["chkia"]
        }
    }

    /// `ecoule` : la part écoulée de la fenêtre, de 0 à 1000, comptée en secondes entières (`Duration.seconds`) ;
    /// 0 sans bornes.
    public static func ecoule(debut: DateHeureZonee?, fin: DateHeureZonee?, maintenant: DateHeureZonee) -> Int {
        guard let debut, let fin, fin > debut else { return 0 }
        let total = Double(secondes(debut, fin))
        let part = Double(secondes(debut, maintenant)) / total * 1000
        return min(max(Kotlin.versInt(part), 0), 1000)
    }

    /// `Duration.between(a, b).seconds` : les secondes entières, arrondies vers moins l'infini.
    private static func secondes(_ a: DateHeureZonee, _ b: DateHeureZonee) -> Int64 {
        let ecart = b.millis - a.millis
        let q = ecart / 1000
        return ecart % 1000 < 0 ? q - 1 : q
    }

    /// Les zmanim d'un jour au lieu, à l'heure du lieu (`Zmanim.jour(…).associate { it.cle to it.local }`) ; un zman
    /// absent ce jour-là n'a pas de clé.
    public static func horaires(_ lieu: Zmanim.Lieu, _ date: JourCivil) -> [String: DateHeureZonee] {
        guard let fuseau = Fuseau(lieu.fuseau) else { return [:] }
        var h: [String: DateHeureZonee] = [:]
        for z in Zmanim.jour(lieu: lieu, date: date) {
            if let t = z.instant { h[z.cle] = DateHeureZonee(millis: Zmanim.millis(t), fuseau: fuseau) }
        }
        return h
    }

    // MARK: Ce que la vignette montre à un instant

    /// Un zman de la journée montrée.
    public struct ZmanDuJour: Sendable, Equatable {
        public let cle: String
        public let quand: DateHeureZonee
    }

    /// Ce que les vignettes montrent à partir de `quand` (`ZmanimVignette.vues`, sans le dessin).
    public struct Vue: Sendable, Equatable {
        /// L'instant où cette vue devient la bonne : la date de l'entrée de chronologie.
        public let quand: DateHeureZonee
        /// La date civile dont la vignette montre le jour hébreu (la date et la fête ou la paracha en tête).
        public let jourHebreu: JourCivil
        /// « chaharit », « minha », « arvit » ; nil sans lieu (« Choisir un lieu »).
        public let priere: String?
        /// L'heure où la prière se ferme ; nil sans limite.
        public let limite: DateHeureZonee?
        /// Le début de la jauge.
        public let debutJauge: DateHeureZonee?
        /// La journée : aujourd'hui, ou demain une fois la nuit tombée.
        public let journee: [ZmanDuJour]
        /// Le rang du prochain zman dans `journee` (mis en évidence) ; nil si tous sont passés.
        public let prochain: Int?
    }

    /// La vue au lieu à `maintenant` (à l'heure du lieu), d'après les horaires du jour et du lendemain.
    public static func vue(_ maintenant: DateHeureZonee, aujourdhui: [String: DateHeureZonee],
                           demain: [String: DateHeureZonee]) -> Vue {
        let p = ZmanimWidget.prochaine(aujourdhui, maintenant: maintenant)
        var liste = journee.compactMap { k in aujourdhui[k].map { ZmanDuJour(cle: k, quand: $0) } }
        if !liste.contains(where: { $0.quand > maintenant }) {
            liste = journee.compactMap { k in demain[k].map { ZmanDuJour(cle: k, quand: $0) } }
        }
        return Vue(quand: maintenant, jourHebreu: jourHebreuAffiche(maintenant, tset: aujourdhui["tset"]),
                   priere: p.priere, limite: p.limite, debutJauge: debut(p.priere, aujourdhui), journee: liste,
                   prochain: liste.firstIndex { $0.quand > maintenant })
    }

    /// Sans lieu : la date du téléphone, qui change à minuit ; aucune prière.
    public static func vueSansLieu(_ maintenant: DateHeureZonee) -> Vue {
        Vue(quand: maintenant, jourHebreu: maintenant.jour, priere: nil, limite: nil, debutJauge: nil, journee: [],
            prochain: nil)
    }

    // MARK: Chronologie (WidgetKit)

    /// La chronologie des vignettes pour les `heures` à venir : la vue de `maintenant`, puis une à chaque instant où
    /// elle change — chaque zman du jour et du lendemain, le milieu de la nuit d'hier (fin d'Arvit avant l'aube),
    /// minuit du lieu et, s'il est donné, minuit du téléphone (la série). `horaires` donne ceux d'un jour du lieu.
    /// `maintenant` est à l'heure du lieu.
    public static func chronologie(depuis maintenant: DateHeureZonee, heures: Int = 24,
                                   fuseauTelephone: Fuseau? = nil,
                                   horaires: (JourCivil) -> [String: DateHeureZonee]) -> [Vue] {
        let fin = maintenant.plus(heures: heures)
        var memoire: [JourCivil: [String: DateHeureZonee]] = [:]
        func du(_ jour: JourCivil) -> [String: DateHeureZonee] {
            if let h = memoire[jour] { return h }
            let h = horaires(jour)
            memoire[jour] = h
            return h
        }
        var instants: Set<Int64> = []
        var jour = maintenant.jour
        while !(fin.jour < jour) {
            let h = du(jour)
            for t in h.values { instants.insert(t.millis) }
            if let nuit = h["chatsot_layla"]?.plus(jours: -1) { instants.insert(nuit.millis) }
            instants.insert(DateHeureZonee(DateHeure(jour), fuseau: maintenant.fuseau).millis)
            jour = jour.plus(jours: 1)
        }
        instants.formUnion(minuits(maintenant, fin, fuseauTelephone))
        var vues = [vue(maintenant, aujourdhui: du(maintenant.jour), demain: du(maintenant.jour.plus(jours: 1)))]
        for t in instants.filter({ $0 > maintenant.millis && $0 <= fin.millis }).sorted() {
            let a = DateHeureZonee(millis: t, fuseau: maintenant.fuseau)
            vues.append(vue(a, aujourdhui: du(a.jour), demain: du(a.jour.plus(jours: 1))))
        }
        return vues
    }

    /// La chronologie sans lieu : la vue de `maintenant`, puis une à chaque minuit du téléphone.
    public static func chronologieSansLieu(depuis maintenant: DateHeureZonee, heures: Int = 24) -> [Vue] {
        let fin = maintenant.plus(heures: heures)
        return [vueSansLieu(maintenant)] + minuits(maintenant, fin, maintenant.fuseau).sorted().map {
            vueSansLieu(DateHeureZonee(millis: $0, fuseau: maintenant.fuseau))
        }
    }

    /// Les minuits de `fuseau` strictement après `debut`, jusqu'à `fin` comprise.
    static func minuits(_ debut: DateHeureZonee, _ fin: DateHeureZonee, _ fuseau: Fuseau?) -> Set<Int64> {
        guard let fuseau else { return [] }
        var resultat: Set<Int64> = []
        var jour = DateHeureZonee(millis: debut.millis, fuseau: fuseau).jour.plus(jours: 1)
        while true {
            let minuit = DateHeureZonee(DateHeure(jour), fuseau: fuseau)
            if minuit.millis > fin.millis { break }
            if minuit.millis > debut.millis { resultat.insert(minuit.millis) }
            jour = jour.plus(jours: 1)
        }
        return resultat
    }
}

/// La vignette de la série (`StreakWidget.kt`) : sa coche change à minuit (Android la redessinait une minute après,
/// `programmerMinuit`) et à la fin d'une séance minutée. Le reste se lit du journal à la date de l'entrée.
public enum VignetteSerie {

    /// Les instants de la chronologie : maintenant, la fin de la séance en cours si elle tombe dans l'horizon, chaque
    /// minuit du téléphone.
    public static func chronologie(depuis maintenant: DateHeureZonee, finSeance: Int64? = nil, heures: Int = 24) -> [DateHeureZonee] {
        let fin = maintenant.plus(heures: heures)
        var instants = ZmanimVignette.minuits(maintenant, fin, maintenant.fuseau)
        if let finSeance, finSeance > maintenant.millis, finSeance <= fin.millis { instants.insert(finSeance) }
        return [maintenant] + instants.sorted().map { DateHeureZonee(millis: $0, fuseau: maintenant.fuseau) }
    }
}
