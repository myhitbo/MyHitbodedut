/// Chabbat, les fêtes et le compte du Omer en vol (VolCalendrier.kt, 28/10) : la règle de
/// JourAffiche.horaires (isAssurBemelacha de KosherJava), appliquée aux chki'a et aux tsét de la route
/// au lieu de celles d'un lieu fixe.
///
///  - chki'a la veille d'un jour chômé : entrée (et l'heure d'allumage, `minutes` avant cette chki'a) ;
///  - tsét d'un jour chômé suivi d'un jour ouvré : sortie ;
///  - tsét d'un jour chômé suivi d'un autre : le jour suivant commence ;
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

        public init(type: Genre, instant: Int64, date: JourCivil, chabbat: Bool, fetes: [String], omer: Int = 0,
                    allumage: Int64? = nil, latitude: Double, longitude: Double) {
            self.type = type
            self.instant = instant
            self.date = date
            self.chabbat = chabbat
            self.fetes = fetes
            self.omer = omer
            self.allumage = allumage
            self.latitude = latitude
            self.longitude = longitude
        }
    }

    public static func jalons(_ calcul: Vol.Calcul, enIsrael: Bool, minutes: Int) -> [Jalon] {
        var res: [Jalon] = []
        for e in calcul.enVol where e.cle == "chkia" || e.cle == "tset" {
            let jour = Vol.jourNautique(e.instant, e.longitude)
            let aujourdhui = CalendrierJuif.jour(jour, enIsrael: enIsrael)
            let demain = CalendrierJuif.jour(jour.plus(jours: 1), enIsrael: enIsrael)
            func jalon(_ type: Genre, _ j: CalendrierJuif.Jour, allumage: Int64? = nil, omer: Int = 0) -> Jalon {
                Jalon(type: type, instant: e.instant, date: j.date, chabbat: j.date.jourDeSemaine == 7, fetes: j.fetes,
                      omer: omer, allumage: allumage, latitude: e.latitude, longitude: e.longitude)
            }
            if e.cle == "chkia" && demain.chome && !aujourdhui.chome {
                res.append(jalon(.entree, demain, allumage: e.instant - Int64(minutes) * 60_000))
            }
            if e.cle == "tset" {
                if aujourdhui.chome && !demain.chome { res.append(jalon(.sortie, aujourdhui)) }
                if aujourdhui.chome && demain.chome { res.append(jalon(.enchainement, demain)) }
                if demain.omer > 0 { res.append(jalon(.omer, demain, omer: demain.omer)) }
            }
        }
        return res
    }
}
