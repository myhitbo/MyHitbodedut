import Foundation

/// La prière du moment et sa limite, que montrent les vignettes des zmanim (ZmanimWidget.kt ; les trois
/// tailles sont dans ZmanimVignette) : Cha'harit jusqu'au sof zman tefila (GRA), Min'ha jusqu'à la
/// chki'a, Arvit jusqu'au milieu de la nuit. La vignette elle-même (AppWidgetProvider et sa mise à jour)
/// reste à l'app. Jugée par `Tests/Vecteurs/vignettes.json` (tools/vecteurs_ios/VecteursVignettes.kt).
public enum ZmanimWidget {

    /// `horaires` : les zmanim du jour civil de `maintenant` au lieu choisi, par clé (`Zmanim.Zman.cle`) ;
    /// une clé absente est un zman qui n'existe pas ce jour-là. Rend la prière (« chaharit », « minha »
    /// ou « arvit ») et sa limite, nil quand aucune n'est affichée. Tout se compare sur la ligne du temps.
    public static func prochaine(horaires: [String: DateHeureZonee],
                                 maintenant: DateHeureZonee) -> (priere: String, limite: DateHeureZonee?) {
        // Après minuit et avant l'aube, c'est encore la nuit d'Arvit (audit du 16/10) : jusqu'au milieu de
        // la nuit d'hier s'il n'est pas passé, sans limite affichée ensuite.
        if let alot = horaires["alot"], maintenant < alot {
            guard let milieu = horaires["chatsot_layla"] else { return ("arvit", nil) }
            let hier = veille(milieu)
            return ("arvit", maintenant < hier ? hier : nil)
        }
        let limites: [(String, DateHeureZonee?)] = [
            ("chaharit", horaires["szt_gra"]), ("minha", horaires["chkia"]), ("arvit", horaires["chatsot_layla"]),
        ]
        for (priere, limite) in limites {
            if let limite, maintenant < limite { return (priere, limite) }
        }
        return ("arvit", nil)
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
