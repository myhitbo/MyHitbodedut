/// Les rappels pendant un vol (VolRappels.kt, 28/10) : Tefilat haDerekh cinq minutes après le décollage prévu
/// (délai choisi par l'utilisateur ; les sources la placent après le décollage, ZMANIM.md « En vol »), le début de
/// chaque prière dans l'avion et l'approche de sa limite, le compte du Omer du soir.
///
/// Les bornes des prières sont celles de la bannière des prières (HorairePriere) : Min'ha de min'ha guedola à la
/// chki'a, Arvit de la sortie des étoiles au milieu de la nuit, Cha'harit jusqu'à la fin du temps de la tefila
/// (GRA). La carte « Prière du moment » (ZmanimWidget.prochaine) a les mêmes limites et, depuis le 13/11 (FVOL-05),
/// le même début de Min'ha ; elle garde ses propres débuts pour Cha'harit (l'aube) et Arvit (la chki'a). Seul le
/// début de Cha'harit n'était pas dans la bannière : le lever du soleil (netz), le temps de la prière au départ
/// (Choul'han Aroukh O.H. 89, 1). Le Omer : les jalons de VolCalendrier. Les instants sont des millisecondes
/// Unix. Jugé par `Tests/Vecteurs/vol_suite.json` (tools/vecteurs_ios/VecteursVolSuite.kt), section « vols ».
public enum VolRappels {

    /// Le `Type` de Kotlin (un nom que Swift réserve aux métatypes), dans l'ordre de sa déclaration. Valeurs brutes :
    /// les noms de Kotlin en minuscules.
    public enum Genre: String, Sendable, Hashable, CaseIterable {
        case tefilatHaderekh = "tefilat_haderekh"
        case priere
        case priereFin = "priere_fin"
        case omer
        /// À l'atterrissage d'un vol d'une heure douze ou plus, le rappel de bénir dans les trois jours (audit du 16/11).
        case hagomel
        /// « Plus que 30 min pour le Chema » (audit du 16/11).
        case chemaFin = "chema_fin"

        /// `ordinal` de Kotlin : il départage deux rappels du même instant.
        fileprivate var rang: Int {
            switch self {
            case .tefilatHaderekh: return 0
            case .priere: return 1
            case .priereFin: return 2
            case .omer: return 3
            case .hagomel: return 4
            case .chemaFin: return 5
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
        /// Cha'harit : la fin du Chema du rite (`chemaCle`) et celle de l'autre avis (audit du 16/11).
        public var chema: Int64?
        public var chemaCle: String?
        public var chemaAutre: Int64?

        public init(type: Genre, instant: Int64, priere: String? = nil, limite: Int64? = nil, omer: Int = 0,
                    chema: Int64? = nil, chemaCle: String? = nil, chemaAutre: Int64? = nil) {
            self.type = type
            self.instant = instant
            self.priere = priere
            self.limite = limite
            self.omer = omer
            self.chema = chema
            self.chemaCle = chemaCle
            self.chemaAutre = chemaAutre
        }
    }

    /// 5 minutes, en millisecondes.
    public static let apresDecollage: Int64 = 5 * 60_000
    /// 30 minutes, en millisecondes.
    public static let avantLimite: Int64 = 30 * 60_000

    /// Hagomel après un vol (audit du 16/11) : « הטס במטוס שיעור שעה ושתים עשרה דקות… יברך ברכת הגומל » (Kitsour
    /// Yalkut Yosef 219:20-21). Le texte du rappel suit le noussa'h (VolAlerte.textes) : en Ashkenaz et en Sfard,
    /// « selon votre usage » (Choul'han Aroukh O.H. 219:7 ; Igrot Moché O.H. 2). 72 minutes, en millisecondes.
    public static let dureeHagomel: Int64 = 72 * 60_000

    /// La fin du Chema que suivent les rappels (audit du 16/11) : le Maguen Avraham pour les Edot (Kitsour Yalkut
    /// Yosef 89:4), le Gra pour les autres ; l'autre avis est toujours nommé dans le texte. En vol, le profil est le
    /// profil commun (Vol) : la fin MGA y est en 72 min fixes.
    public static func cleChema(_ nusah: Nusah?) -> String {
        nusah == .edot ? "szks_mga" : "szks_gra"
    }

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
            // Arvit sans tsét sous l'avion : dès la chki'a, le repère de repli (audit du 16/11).
            guard let d = ev.last(where: {
                ($0.cle == b.debut || (b.priere == "arvit" && $0.cle == "chkia" && VolCalendrier.tsetManque(calcul, $0)))
                    && $0.instant <= t
            }) else { continue }
            guard let f = ev.first(where: { $0.cle == b.fin && $0.instant > d.instant }) else { continue }
            if t < f.instant { return Ouverte(priere: b.priere, limite: f.instant) }
        }
        return nil
    }

    public static func rappels(_ calcul: Vol.Calcul, enIsrael: Bool, nusah: Nusah? = nil) -> [Rappel] {
        let cle = cleChema(nusah)
        let autre = cle == "szks_mga" ? "szks_gra" : "szks_mga"
        let prieres = rappelsPrieres(calcul, enIsrael: enIsrael).map { r -> Rappel in
            guard r.type == .priere && r.priere == "chaharit" else { return r }
            // La première fin du Chema après le lever, avant la fin de la Téfila.
            func fin(_ c: String) -> Int64? {
                calcul.evenements.first { $0.cle == c && $0.instant > r.instant && (r.limite == nil || $0.instant <= r.limite!) }?.instant
            }
            var copie = r
            copie.chema = fin(cle)
            copie.chemaCle = cle
            copie.chemaAutre = fin(autre)
            return copie
        }
        let res = prieres + rappelsChema(calcul, cle, autre)
        // `sortedWith(compareBy({ instant }, { ordinal }))`, stable : à égalité, l'ordre d'ajout.
        return res.enumerated()
            .sorted { ($0.element.instant, $0.element.type.rang, $0.offset) < ($1.element.instant, $1.element.type.rang, $1.offset) }
            .map { $0.element }
    }

    /// « Plus que 30 min pour le Chema » (audit du 16/11) : dans l'avion, après Tefilat haDerekh, et seulement le
    /// matin (une aube passée sous l'avion, sans coucher depuis).
    private static func rappelsChema(_ calcul: Vol.Calcul, _ cle: String, _ autre: String) -> [Rappel] {
        let plan = calcul.plan
        let t0 = plan.decollage + apresDecollage
        let ev = calcul.evenements
        return ev.filter { $0.cle == cle }.compactMap { f -> Rappel? in
            let t = f.instant - avantLimite
            guard let aube = ev.last(where: { $0.cle == "alot" && $0.instant <= t }) else { return nil }
            let coucher = ev.last { $0.cle == "chkia" && $0.instant <= t }
            if t < t0 || t > plan.atterrissage { return nil }
            if let coucher, coucher.instant > aube.instant { return nil }
            let l = ev.first { $0.cle == autre && $0.instant > aube.instant }?.instant
            return Rappel(type: .chemaFin, instant: t, priere: "chaharit", limite: f.instant, chema: f.instant, chemaCle: cle,
                          chemaAutre: l)
        }
    }

    private static func rappelsPrieres(_ calcul: Vol.Calcul, enIsrael: Bool) -> [Rappel] {
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
        // Vol polaire sans tsét (audit du 16/11) : Arvit annoncée à la chki'a, repère de repli
        // (VolCalendrier.tsetManque), comme le Omer ; jamais à Rabbénou Tam.
        for d in calcul.evenements where d.cle == "chkia" && dansLAvion(d.instant) && d.instant > t0
            && VolCalendrier.tsetManque(calcul, d) {
            let limite = calcul.evenements.first { $0.cle == "chatsot_layla" && $0.instant > d.instant }?.instant
            res.append(Rappel(type: .priere, instant: d.instant, priere: "arvit", limite: limite))
        }
        for j in VolCalendrier.jalons(calcul, enIsrael: enIsrael, minutes: 0) where j.type == .omer {
            res.append(Rappel(type: .omer, instant: j.instant, omer: j.omer))
        }
        if plan.atterrissage - plan.decollage >= dureeHagomel { res.append(Rappel(type: .hagomel, instant: plan.atterrissage)) }
        return res
    }
}
