import Foundation

/// La prière du moment et sa limite, que montrent les vignettes des zmanim (ZmanimWidget.kt ; les trois
/// tailles sont dans ZmanimVignette) : Cha'harit jusqu'au sof zman tefila (GRA), Min'ha jusqu'à la
/// chki'a, Arvit jusqu'au milieu de la nuit. La vignette elle-même (AppWidgetProvider et sa mise à jour)
/// reste à l'app. Jugée par `Tests/Vecteurs/vignettes.json` (tools/vecteurs_ios/VecteursVignettes.kt).
public enum ZmanimWidget {

    /// La prière du moment (13/11 ; audit du 12/11, FVOL-05). `debut` nil : elle est ouverte, jusqu'à `limite`
    /// (nil : sans limite affichée). `debut` non nil : aucune prière n'est ouverte, la prochaine, `priere`, commence
    /// à `debut` et se fermera à `limite`.
    public struct Moment: Sendable, Hashable {
        public let priere: String
        public let limite: DateHeureZonee?
        public let debut: DateHeureZonee?

        public init(priere: String, limite: DateHeureZonee?, debut: DateHeureZonee? = nil) {
            self.priere = priere
            self.limite = limite
            self.debut = debut
        }
    }

    /// `horaires` : les zmanim du jour civil de `maintenant` au lieu choisi, par clé (`Zmanim.Zman.cle`) ; une clé
    /// absente est un zman qui n'existe pas ce jour-là. Cha'harit jusqu'au sof zman tefila (GRA), Min'ha de min'ha
    /// guedola à la chki'a, Arvit jusqu'au milieu de la nuit. Entre la fin de Cha'harit et min'ha guedola, aucune
    /// prière n'est ouverte : Min'ha est annoncée avec l'heure où elle commence (FVOL-05). Sans min'ha guedola dans
    /// `horaires`, l'ancienne règle. Tout se compare sur la ligne du temps.
    public static func prochaine(horaires: [String: DateHeureZonee], maintenant: DateHeureZonee) -> Moment {
        // Après minuit et avant l'aube, c'est encore la nuit d'Arvit (audit du 16/10) : jusqu'au milieu de la nuit
        // d'hier s'il n'est pas passé, sans limite affichée ensuite. Sans aube (Londres, Berlin… autour du
        // solstice, FCALENDRIER-08), michéyakir puis le lever en tiennent lieu.
        if let alot = horaires["alot"] ?? horaires["misheyakir"] ?? horaires["netz"], maintenant < alot {
            guard let milieu = horaires["chatsot_layla"] else { return Moment(priere: "arvit", limite: nil) }
            let hier = veille(milieu)
            if maintenant < hier { return Moment(priere: "arvit", limite: hier) }
            return Moment(priere: "arvit", limite: nil)
        }
        if let finChaharit = horaires["szt_gra"], maintenant < finChaharit {
            return Moment(priere: "chaharit", limite: finChaharit)
        }
        let chkia = horaires["chkia"]
        // Une min'ha guedola d'après la chki'a est celle du lendemain (en vol, sans repère d'aube) : Min'ha est
        // ouverte.
        if let guedola = horaires["minha_gedola"], maintenant < guedola, chkia.map({ guedola < $0 }) ?? true {
            return Moment(priere: "minha", limite: chkia, debut: guedola)
        }
        for (priere, limite) in [("minha", chkia), ("arvit", horaires["chatsot_layla"])] {
            if let limite, maintenant < limite { return Moment(priere: priere, limite: limite) }
        }
        return Moment(priere: "arvit", limite: nil)
    }

    /// `minusDays(1)` de `ZonedDateTime` : la même heure civile, la veille. Dans l'heure qui existe deux
    /// fois, java.time garde le décalage d'origine s'il y vaut encore (`ZonedDateTime.ofLocal`), là où
    /// `DateHeureZonee.plus(jours:)` prend toujours le premier : le milieu de la nuit du 26 octobre 2026 à
    /// Paris, 2 h 27 en heure d'hiver, donne la veille à 2 h 27 d'hiver, une heure après 2 h 27 d'été.
    /// Hors de cette heure-là, les deux s'accordent (et l'heure qui manque est avancée de la même façon).
    private static func veille(_ instant: DateHeureZonee) -> DateHeureZonee {
        let fuseau = instant.fuseau
        let civile = instant.civile.plus(jours: -1)
        let decalage = Int64(fuseau.decalage(millis: instant.millis)) * 1000
        // L'heure civile de la veille comptée comme si elle était en UTC, puis ramenée par le décalage d'origine.
        let commeEnUTC = Int64(civile.jour.jourJulien - 2_440_588) * 86_400_000 + Int64(civile.millisDuJour)
        let garde = commeEnUTC - decalage
        if Int64(fuseau.decalage(millis: garde)) * 1000 == decalage {
            return DateHeureZonee(millis: garde, fuseau: fuseau)
        }
        return DateHeureZonee(civile, fuseau: fuseau)
    }
}
