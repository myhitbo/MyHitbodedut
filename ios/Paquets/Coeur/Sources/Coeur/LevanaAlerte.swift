/// Le rappel de Birkat haLevana (LevanaAlerte.kt) : le premier soir possible, le motsaé Chabbat conseillé et
/// le dernier soir, selon l'usage suivi, à l'heure du soir que donne l'app (la sortie des étoiles au lieu
/// choisi, sinon 20 h). Seul le calcul est ici : cette heure (`heure(context, zone)`), l'alarme
/// (`programmer`) et la notification (`LevanaAlerteReceiver`) restent à l'app.
public enum LevanaAlerte {

    /// Le nom est celui de l'énumération d'Android, que l'app garde entre deux rappels (`levana_rappel_soir`).
    public enum Soir: String, CaseIterable, Sendable {
        case premier = "PREMIER"
        case motsae = "MOTSAE"
        case dernier = "DERNIER"

        /// Le titre de la notification : le nom de sa chaîne (`R.string.levana_rappel_…`).
        public var titre: String {
            switch self {
            case .premier: "levana_rappel_premier"
            case .motsae: "levana_rappel_motsae"
            case .dernier: "levana_rappel_dernier"
            }
        }
    }

    /// Les soirs à rappeler d'une fenêtre, à partir de `depuis`, dans l'ordre des dates.
    public static func soirs(_ f: Levana.Fenetre, depuis: JourCivil, fuseau: Fuseau) -> [(jour: JourCivil, soir: Soir)] {
        let premier = f.premierSoir(fuseau)
        let dernier = f.dernierSoir(fuseau)
        var liste: [(jour: JourCivil, soir: Soir)] = [(jour: premier, soir: Soir.premier)]
        if let motsae = Levana.motsaeChabbat(f, premier, fuseau: fuseau), motsae != premier, motsae != dernier {
            liste.append((jour: motsae, soir: Soir.motsae))
        }
        if dernier != premier {
            liste.append((jour: dernier, soir: Soir.dernier))
        }
        // `sortedBy` de Kotlin est stable : à date égale, l'ordre d'ajout.
        let gardes = Array(liste.enumerated()).filter { rappel in rappel.element.jour >= depuis }
        let tries = gardes.sorted { a, b in
            a.element.jour != b.element.jour ? a.element.jour < b.element.jour : a.offset < b.offset
        }
        return tries.map { rappel in rappel.element }
    }

    /// Le prochain rappel après `maintenant` : le soir, à `heure` de ce jour-là. Trois fenêtres sont
    /// essayées ; un soir dont l'heure passe la fin de sa fenêtre est sauté.
    public static func prochain(_ maintenant: DateHeureZonee, usage: Levana.Usage,
                                heure: (JourCivil) -> DateHeureZonee) -> (quand: DateHeureZonee, soir: Soir)? {
        let fuseau = maintenant.fuseau
        let aujourdhui = maintenant.jour
        var date = aujourdhui
        for _ in 0..<3 {
            let f = Levana.fenetre(date, fuseau: fuseau, usage: usage)
            for rappel in soirs(f, depuis: aujourdhui, fuseau: fuseau) {
                let quand = heure(rappel.jour)
                if quand > maintenant && quand.millis <= f.fin { return (quand: quand, soir: rappel.soir) }
            }
            date = f.dernierSoir(fuseau).plus(jours: 1)
        }
        return nil
    }
}
