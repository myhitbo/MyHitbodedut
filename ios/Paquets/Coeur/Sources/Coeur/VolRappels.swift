/// Les rappels pendant un vol (VolRappels.kt, 28/10) : Tefilat haDerekh cinq minutes après le décollage prévu
/// (délai choisi par l'utilisateur ; les sources la placent après le décollage, ZMANIM.md « En vol »), le début de
/// chaque prière dans l'avion et l'approche de sa limite, le compte du Omer du soir.
///
/// Les bornes des prières sont celles de l'application (HorairePriere, ZmanimWidget.prochaine) : Min'ha de min'ha
/// guedola à la chki'a, Arvit de la sortie des étoiles au milieu de la nuit, Cha'harit jusqu'à la fin du temps de la
/// tefila (GRA). Seul le début de Cha'harit n'y était pas : le lever du soleil (netz), le temps de la prière au
/// départ (Choul'han Aroukh O.H. 89, 1). Le Omer : les jalons de VolCalendrier. Les instants sont des millisecondes
/// Unix. Jugé par `Tests/Vecteurs/vol_suite.json` (tools/vecteurs_ios/VecteursVolSuite.kt), section « vols ».
public enum VolRappels {

    /// Le `Type` de Kotlin (un nom que Swift réserve aux métatypes), dans l'ordre de sa déclaration. Valeurs brutes :
    /// les noms de Kotlin en minuscules.
    public enum Genre: String, Sendable, Hashable, CaseIterable {
        case tefilatHaderekh = "tefilat_haderekh"
        case priere
        case priereFin = "priere_fin"
        case omer

        /// `ordinal` de Kotlin : il départage deux rappels du même instant.
        fileprivate var rang: Int {
            switch self {
            case .tefilatHaderekh: return 0
            case .priere: return 1
            case .priereFin: return 2
            case .omer: return 3
            }
        }
    }

    public struct Rappel: Sendable, Hashable {
        public var type: Genre
        public var instant: Int64
        /// « chaharit », « minha », « arvit » : la prière qui commence ou finit ; au décollage, celle du moment.
        public var priere: String?
        public var limite: Int64?
        public var omer: Int

        public init(type: Genre, instant: Int64, priere: String? = nil, limite: Int64? = nil, omer: Int = 0) {
            self.type = type
            self.instant = instant
            self.priere = priere
            self.limite = limite
            self.omer = omer
        }
    }

    /// 5 minutes, en millisecondes.
    public static let apresDecollage: Int64 = 5 * 60_000
    /// 30 minutes, en millisecondes.
    public static let avantLimite: Int64 = 30 * 60_000

    /// Une prière : le zman qui l'ouvre, celui qui la ferme (le `Triple` de Kotlin).
    public struct Borne: Sendable, Hashable {
        public let priere: String
        public let debut: String
        public let fin: String
    }

    public static let bornes: [Borne] = [
        Borne(priere: "chaharit", debut: "netz", fin: "szt_gra"),
        Borne(priere: "minha", debut: "minha_gedola", fin: "chkia"),
        Borne(priere: "arvit", debut: "tset", fin: "chatsot_layla"),
    ]

    /// Une prière ouverte et sa limite (la paire de Kotlin).
    public struct Ouverte: Sendable, Hashable {
        public var priere: String
        public var limite: Int64

        public init(priere: String, limite: Int64) {
            self.priere = priere
            self.limite = limite
        }
    }

    /// La prière ouverte à `t` et sa limite, aux bornes ci-dessus ; nil entre deux prières.
    public static func ouverte(_ calcul: Vol.Calcul, _ t: Int64) -> Ouverte? {
        let ev = calcul.evenements
        for b in bornes {
            guard let d = ev.last(where: { $0.cle == b.debut && $0.instant <= t }) else { continue }
            guard let f = ev.first(where: { $0.cle == b.fin && $0.instant > d.instant }) else { continue }
            if t < f.instant { return Ouverte(priere: b.priere, limite: f.instant) }
        }
        return nil
    }

    public static func rappels(_ calcul: Vol.Calcul, enIsrael: Bool) -> [Rappel] {
        let plan = calcul.plan
        func dansLAvion(_ t: Int64) -> Bool {
            t >= plan.decollage && t <= plan.atterrissage
        }
        var res: [Rappel] = []
        let t0 = plan.decollage + apresDecollage
        if dansLAvion(t0) {
            let o = ouverte(calcul, t0)
            res.append(Rappel(type: .tefilatHaderekh, instant: t0, priere: o?.priere, limite: o?.limite))
        }
        for b in bornes {
            for d in calcul.evenements where d.cle == b.debut && dansLAvion(d.instant) && d.instant > t0 {
                let limite = calcul.evenements.first(where: { $0.cle == b.fin && $0.instant > d.instant })?.instant
                res.append(Rappel(type: .priere, instant: d.instant, priere: b.priere, limite: limite))
            }
            // L'approche de la limite (sauf Arvit, qui se dit encore après le milieu de la nuit) : seulement si la
            // prière est déjà ouverte à ce moment-là.
            if b.priere == "arvit" { continue }
            for f in calcul.evenements where f.cle == b.fin {
                let t = f.instant - avantLimite
                if dansLAvion(t) && t > t0 && ouverte(calcul, t)?.priere == b.priere {
                    res.append(Rappel(type: .priereFin, instant: t, priere: b.priere, limite: f.instant))
                }
            }
        }
        for j in VolCalendrier.jalons(calcul, enIsrael: enIsrael, minutes: 0) where j.type == .omer {
            res.append(Rappel(type: .omer, instant: j.instant, omer: j.omer))
        }
        // `sortedWith(compareBy({ instant }, { ordinal }))`, stable : à égalité, l'ordre d'ajout.
        return res.enumerated()
            .sorted { ($0.element.instant, $0.element.type.rang, $0.offset) < ($1.element.instant, $1.element.type.rang, $1.offset) }
            .map { $0.element }
    }
}
