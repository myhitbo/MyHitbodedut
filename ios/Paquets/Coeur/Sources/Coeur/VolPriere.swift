/// La prière du moment en vol (VolPriere.kt, 28/10) : les horaires de la route (`Vol.horaires`) passés à
/// la règle de ZmanimWidget.prochaine, recopiée ici telle quelle tant que la vignette n'est pas portée.
public enum VolPriere {

    /// Ce qui reste couvert par la fenêtre de calcul autour du vol (`Vol.marge`, moins un jour) : 6 heures, en millisecondes.
    public static let couvert: Int64 = 6 * 3_600_000

    /// La prière du moment (« chaharit », « minha », « arvit ») et sa limite (millisecondes Unix), nil sans limite :
    /// la paire de Kotlin.
    public struct Moment: Sendable, Hashable {
        public var priere: String
        public var limite: Int64?

        public init(priere: String, limite: Int64?) {
            self.priere = priere
            self.limite = limite
        }
    }

    /// La prière du moment et sa limite ; nil loin du vol : la fenêtre ne couvre plus.
    public static func priere(_ calcul: Vol.Calcul, _ maintenant: Int64) -> Moment? {
        if maintenant < calcul.plan.decollage - couvert || maintenant > calcul.plan.atterrissage + couvert { return nil }
        return prochaine(Vol.horaires(calcul, maintenant), maintenant)
    }

    /// ZmanimWidget.prochaine, sur des instants UTC (là, `minusDays(1)` retire 24 heures) : Cha'harit jusqu'au sof
    /// zman tefila (GRA), Min'ha jusqu'à la chki'a, Arvit jusqu'à minuit. Après minuit et avant l'aube, c'est encore
    /// la nuit d'Arvit : jusqu'au milieu de la nuit d'hier s'il n'est pas passé, sans limite ensuite.
    private static func prochaine(_ horaires: [String: Int64], _ maintenant: Int64) -> Moment {
        if let alot = horaires["alot"], maintenant < alot {
            var limite: Int64?
            if let minuit = horaires["chatsot_layla"], maintenant < minuit - 86_400_000 { limite = minuit - 86_400_000 }
            return Moment(priere: "arvit", limite: limite)
        }
        for (priere, cle) in [("chaharit", "szt_gra"), ("minha", "chkia"), ("arvit", "chatsot_layla")] {
            if let limite = horaires[cle], maintenant < limite { return Moment(priere: priere, limite: limite) }
        }
        return Moment(priere: "arvit", limite: nil)
    }
}
