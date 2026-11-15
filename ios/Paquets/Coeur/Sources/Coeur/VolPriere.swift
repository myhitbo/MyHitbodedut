/// La prière du moment en vol (VolPriere.kt, 28/10) : les horaires de la route (`Vol.horaires`) passés à
/// `ZmanimWidget.prochaine`, dont la règle n'est pas réécrite. Tout y est en UTC, comme `atZone(ZoneOffset.UTC)`.
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
        let utc = Fuseau.utc
        let horaires = Vol.horaires(calcul, maintenant).mapValues { DateHeureZonee(millis: $0, fuseau: utc) }
        let r = ZmanimWidget.prochaine(horaires: horaires, maintenant: DateHeureZonee(millis: maintenant, fuseau: utc))
        return Moment(priere: r.priere, limite: r.limite?.millis)
    }
}
