/// Chabbat, les fêtes et le compte du Omer en vol (VolCalendrier.kt, 28/10) : la règle de
/// JourAffiche.horaires (isAssurBemelacha de KosherJava), appliquée aux chki'a et aux tsét de la route
/// au lieu de celles d'un lieu fixe.
///
///  - chki'a la veille d'un jour chômé : entrée (et l'heure d'allumage, `minutes` avant cette chki'a) ;
///  - tsét d'un jour chômé suivi d'un jour ouvré : sortie ;
///  - tsét d'un jour chômé suivi d'un autre : le jour suivant commence ; sauf une fête un vendredi (audit du
///    12/11, FCALENDRIER-01) : Chabbat entre à la chki'a, avec l'allumage avant elle, comme une veille ;
///  - tsét pendant le Omer : le jour qui se compte ce soir.
///
/// Le jour civil est celui du point sous l'avion (fuseau nautique, comme Vol) ; Israël ou diaspora, le
/// réglage de l'application. Ce sont deux choix de calcul, pas des règles : ZMANIM.md, « En vol ». Aucun
/// conseil n'est donné (allumer à bord, compter avant ou après une escale…).
public enum VolCalendrier {

    /// Le `Type` de Kotlin (un nom que Swift réserve aux métatypes). Valeurs brutes : les noms de Kotlin en minuscules.
    public enum Genre: String, Sendable, Hashable {
        case entree
        case sortie
        case enchainement
        case omer
    }

    public struct Jalon: Sendable, Hashable {
        public var type: Genre
        /// Millisecondes Unix : la chki'a ou la tsét de la route.
        public var instant: Int64
        /// Le jour qui commence (entrée, enchaînement, Omer) ou qui finit (sortie), au point sous l'avion.
        public var date: JourCivil
        public var chabbat: Bool
        /// Les clés « fete_<clé> » de ce jour.
        public var fetes: [String]
        public var omer: Int
        /// L'allumage, `minutes` avant la chki'a (millisecondes Unix) : à l'entrée seulement.
        public var allumage: Int64?
        public var latitude: Double
        public var longitude: Double
        /// Pas de tsét à 8,5° sous l'avion après cette chki'a (vol polaire, audit du 16/11) : un repère de repli,
        /// dit comme un choix de calcul. Omer : la chki'a (Kitsour YY 489:18 admet le compte en bein
        /// hachmachot ; MB 489:14). Sortie et enchaînement : Rabbénou Tam (72 min), plus strict, jamais la chki'a.
        public var repli: Bool

        public init(type: Genre, instant: Int64, date: JourCivil, chabbat: Bool, fetes: [String], omer: Int = 0,
                    allumage: Int64? = nil, latitude: Double, longitude: Double, repli: Bool = false) {
            self.type = type
            self.instant = instant
            self.date = date
            self.chabbat = chabbat
            self.fetes = fetes
            self.omer = omer
            self.allumage = allumage
            self.latitude = latitude
            self.longitude = longitude
            self.repli = repli
        }
    }

    /// Une ligne de date franchie pendant le Omer (audit du 16/11) : le compte personnel et celui du lieu ne
    /// coïncident plus ; l'écran donne les avis (Rav Chlomo Zalman Auerbach : sans bénédiction ; le Rabbi de
    /// Loubavitch : le compte personnel ; Kitsour YY 489 : par analogie, les deux comptes sans bénédiction) sans
    /// trancher.
    public static func ligneDateOmer(_ calcul: Vol.Calcul, enIsrael: Bool) -> Bool {
        calcul.lignesDate.contains { l in
            [l.avant, l.apres, l.avant.plus(jours: 1), l.apres.plus(jours: 1)].contains {
                CalendrierJuif.jour($0, enIsrael: enIsrael).omer > 0
            }
        }
    }

    /// Après la chki'a `e`, le prochain repère de la nuit ou du matin n'est pas un tsét : il manque (audit du 16/11).
    public static func tsetManque(_ calcul: Vol.Calcul, _ e: Vol.Evenement) -> Bool {
        let reperes: Set<String> = ["tset", "alot", "misheyakir", "netz", "chkia"]
        return calcul.evenements.first { $0.instant > e.instant && reperes.contains($0.cle) }?.cle != "tset"
    }

    public static func jalons(_ calcul: Vol.Calcul, enIsrael: Bool, minutes: Int) -> [Jalon] {
        var res: [Jalon] = []
        for e in calcul.enVol where e.cle == "chkia" || e.cle == "tset" {
            let jour = Vol.jourNautique(e.instant, e.longitude)
            let aujourdhui = CalendrierJuif.jour(jour, enIsrael: enIsrael)
            let demain = CalendrierJuif.jour(jour.plus(jours: 1), enIsrael: enIsrael)
            func jalon(_ type: Genre, _ j: CalendrierJuif.Jour, allumage: Int64? = nil, omer: Int = 0,
                       ev: Vol.Evenement? = nil, repli: Bool = false) -> Jalon {
                let ev = ev ?? e
                return Jalon(type: type, instant: ev.instant, date: j.date, chabbat: j.date.jourDeSemaine == 7, fetes: j.fetes,
                             omer: omer, allumage: allumage, latitude: ev.latitude, longitude: ev.longitude, repli: repli)
            }
            let vendredi = jour.jourDeSemaine == 6
            let repli = e.cle == "chkia" && tsetManque(calcul, e)
            // Rabbénou Tam après cette chki'a, s'il est dans le vol : le repli de la sortie.
            let rt = repli ? calcul.enVol.first { $0.cle == "tset_rt" && $0.instant > e.instant } : nil
            if e.cle == "chkia" && demain.chome && (!aujourdhui.chome || vendredi) {
                res.append(jalon(.entree, demain, allumage: e.instant - Int64(minutes) * 60_000))
            }
            if e.cle == "tset" {
                if aujourdhui.chome && !demain.chome { res.append(jalon(.sortie, aujourdhui)) }
                if aujourdhui.chome && demain.chome && !vendredi { res.append(jalon(.enchainement, demain)) }
                if demain.omer > 0 { res.append(jalon(.omer, demain, omer: demain.omer)) }
            }
            if repli {
                if let rt, aujourdhui.chome && !demain.chome { res.append(jalon(.sortie, aujourdhui, ev: rt, repli: true)) }
                if let rt, aujourdhui.chome && demain.chome && !vendredi {
                    res.append(jalon(.enchainement, demain, ev: rt, repli: true))
                }
                if demain.omer > 0 { res.append(jalon(.omer, demain, omer: demain.omer, repli: true)) }
            }
        }
        // sortedBy : un tri stable.
        return res.enumerated().sorted { ($0.element.instant, $0.offset) < ($1.element.instant, $1.offset) }.map(\.element)
    }
}
