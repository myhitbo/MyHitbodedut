import Foundation

/// Chabbat, les fêtes et le compte du Omer en vol (VolCalendrier.kt, 28/10) : la règle de
/// JourAffiche.horaires, appliquée aux chki'a et aux tsét de la route au lieu de celles d'un lieu fixe.
///  - chki'a la veille d'un jour chômé : entrée (et l'allumage, `minutes` avant cette chki'a) ;
///  - tsét d'un jour chômé suivi d'un jour ouvré : sortie ;
///  - tsét d'un jour chômé suivi d'un autre : le jour suivant commence ;
///  - tsét pendant le Omer : le jour qui se compte ce soir.
/// Le jour civil est celui du point sous l'avion (fuseau nautique). Aucun conseil n'est donné.
public enum VolCalendrier {

    public enum Sorte: String, Sendable { case entree, sortie, enchainement, omer }

    public struct Jalon: Sendable, Equatable {
        public let type: Sorte
        public let instant: Int64
        /// Le jour qui commence (entrée, enchaînement, Omer) ou qui finit (sortie), au point sous l'avion.
        public let date: JourCivil
        public let chabbat: Bool
        /// Les clés « fete_<clé> » de ce jour.
        public let fetes: [String]
        public let omer: Int
        /// L'allumage, `minutes` avant la chki'a : à l'entrée seulement.
        public let allumage: Int64?
        public let latitude: Double
        public let longitude: Double
    }

    public static func jalons(_ calcul: Vol.Calcul, enIsrael: Bool, minutes: Int) -> [Jalon] {
        calcul.enVol.flatMap { e -> [Jalon] in
            guard e.cle == "chkia" || e.cle == "tset", let fuseau = Fuseau(Vol.fuseauNautique(e.longitude)) else { return [] }
            let jour = fuseau.jour(millis: e.instant)
            let aujourdhui = CalendrierJuif.jour(jour, enIsrael: enIsrael)
            let demain = CalendrierJuif.jour(jour.plus(jours: 1), enIsrael: enIsrael)
            func jalon(_ type: Sorte, _ j: CalendrierJuif.Jour, allumage: Int64? = nil, omer: Int = 0) -> Jalon {
                Jalon(type: type, instant: e.instant, date: j.date, chabbat: j.date.jourDeSemaine == 7, fetes: j.fetes, omer: omer,
                      allumage: allumage, latitude: e.latitude, longitude: e.longitude)
            }
            var liste: [Jalon] = []
            if e.cle == "chkia" && demain.chome && !aujourdhui.chome {
                liste.append(jalon(.entree, demain, allumage: e.instant - Int64(minutes) * 60_000))
            }
            if e.cle == "tset" {
                if aujourdhui.chome && !demain.chome { liste.append(jalon(.sortie, aujourdhui)) }
                if aujourdhui.chome && demain.chome { liste.append(jalon(.enchainement, demain)) }
                if demain.omer > 0 { liste.append(jalon(.omer, demain, omer: demain.omer)) }
            }
            return liste
        }
    }
}

/// La prière du moment en vol (VolPriere.kt) : les horaires de la route passés à la règle de
/// ZmanimWidget.prochaine, qui n'est pas réécrite.
public enum VolPriere {

    /// Ce que couvre encore la fenêtre de calcul autour du vol (Vol.marge, moins un jour).
    public static let couvert: Int64 = 6 * 3_600_000

    /// La prière du moment et sa limite ; nil loin du vol : la fenêtre ne couvre plus.
    public static func priere(_ calcul: Vol.Calcul, _ maintenant: Int64) -> (priere: String, limite: Int64?)? {
        if maintenant < calcul.plan.decollage - couvert || maintenant > calcul.plan.atterrissage + couvert { return nil }
        let horaires = Vol.horaires(calcul, maintenant).mapValues { DateHeureZonee(millis: $0, fuseau: .utc) }
        let r = PriereDuMoment.prochaine(horaires, DateHeureZonee(millis: maintenant, fuseau: .utc))
        return (r.priere, r.limite?.millis)
    }
}

/// Les rappels pendant un vol (VolRappels.kt, 28/10) : Tefilat haDerekh cinq minutes après le décollage
/// prévu, le début de chaque prière dans l'avion et l'approche de sa limite, le compte du Omer du soir.
/// Les bornes sont celles de l'application ; seul le début de Cha'harit n'y était pas : le lever du soleil.
public enum VolRappels {

    public enum Sorte: Int, Sendable, Comparable {
        case tefilatHaderekh, priere, priereFin, omer

        public static func < (a: Sorte, b: Sorte) -> Bool { a.rawValue < b.rawValue }

        /// Le nom de Kotlin (« TEFILAT_HADEREKH »).
        public var nom: String {
            switch self {
            case .tefilatHaderekh: "TEFILAT_HADEREKH"
            case .priere: "PRIERE"
            case .priereFin: "PRIERE_FIN"
            case .omer: "OMER"
            }
        }
    }

    public struct Rappel: Sendable, Equatable {
        public let type: Sorte
        public let instant: Int64
        /// « chaharit », « minha », « arvit » : la prière qui commence ou finit ; au décollage, celle du moment.
        public let priere: String?
        public let limite: Int64?
        public let omer: Int

        public init(type: Sorte, instant: Int64, priere: String? = nil, limite: Int64? = nil, omer: Int = 0) {
            self.type = type
            self.instant = instant
            self.priere = priere
            self.limite = limite
            self.omer = omer
        }
    }

    public static let apresDecollage: Int64 = 5 * 60_000
    public static let avantLimite: Int64 = 30 * 60_000

    /// Chaque prière : le zman qui l'ouvre, celui qui la ferme.
    public static let bornes: [(priere: String, debut: String, fin: String)] = [
        ("chaharit", "netz", "szt_gra"),
        ("minha", "minha_gedola", "chkia"),
        ("arvit", "tset", "chatsot_layla"),
    ]

    /// La prière ouverte à `t` et sa limite ; nil entre deux prières.
    public static func ouverte(_ calcul: Vol.Calcul, _ t: Int64) -> (priere: String, limite: Int64)? {
        let ev = calcul.evenements
        for b in bornes {
            guard let d = ev.last(where: { $0.cle == b.debut && $0.instant <= t }),
                  let f = ev.first(where: { $0.cle == b.fin && $0.instant > d.instant }) else { continue }
            if t < f.instant { return (b.priere, f.instant) }
        }
        return nil
    }

    public static func rappels(_ calcul: Vol.Calcul, enIsrael: Bool) -> [Rappel] {
        let plan = calcul.plan
        func dansLAvion(_ t: Int64) -> Bool { t >= plan.decollage && t <= plan.atterrissage }
        var res: [Rappel] = []
        let t0 = plan.decollage + apresDecollage
        if dansLAvion(t0) {
            let o = ouverte(calcul, t0)
            res.append(Rappel(type: .tefilatHaderekh, instant: t0, priere: o?.priere, limite: o?.limite))
        }
        for b in bornes {
            for d in calcul.evenements where d.cle == b.debut && dansLAvion(d.instant) && d.instant > t0 {
                let limite = calcul.evenements.first { $0.cle == b.fin && $0.instant > d.instant }?.instant
                res.append(Rappel(type: .priere, instant: d.instant, priere: b.priere, limite: limite))
            }
            // L'approche de la limite (sauf Arvit, qui se dit encore après le milieu de la nuit) :
            // seulement si la prière est déjà ouverte à ce moment-là.
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
        // sortedWith(compareBy({ instant }, { type })) : stable.
        return res.enumerated().sorted { ($0.element.instant, $0.element.type.rawValue, $0.offset) < ($1.element.instant, $1.element.type.rawValue, $1.offset) }
            .map { $0.element }
    }

    /// Une alerte passée de plus de 20 minutes n'est plus montrée (VolAlerte.TOLERANCE_MS).
    public static let tolerance: Int64 = 20 * 60_000

    /// Les rappels dus maintenant, pas encore montrés (VolAlerte.dus) : plusieurs peuvent tomber à la même minute.
    public static func dus(_ rappels: [Rappel], vu: Int64, maintenant: Int64) -> [Rappel] {
        rappels.filter { $0.instant > vu && $0.instant <= maintenant + 60_000 && $0.instant > maintenant - tolerance }
    }
}

/// Le code-barres d'une carte d'embarquement (CarteEmbarquement.kt, 04/11) : le format BCBP de l'IATA
/// (résolution 792). On n'en lit que le premier tronçon : départ, arrivée, compagnie, numéro, jour de
/// l'année. Le nom du passager et le numéro de réservation ne sont ni lus ni gardés.
public enum CarteEmbarquement {

    public struct Troncon: Sendable, Equatable {
        public let depart: String
        public let arrivee: String
        public let compagnie: String
        public let numero: String
        public let date: JourCivil?
    }

    private static let aeroport = ExpressionReguliere("[A-Z]{3}")
    private static let compagnie = ExpressionReguliere("[A-Z0-9]{2,3}")
    private static let vol = ExpressionReguliere("[0-9]{1,4}[A-Z]?")

    /// « M1DUPONT/JEAN        EABC123 LYSTLVLY 0382 316Y012A0001 100 » → LYS, TLV, LY, LY382, le 316e
    /// jour, l'année la plus proche d'aujourd'hui.
    public static func lire(_ code: String, aujourdhui: JourCivil) -> Troncon? {
        let u = Array(code.utf16)
        guard u.count >= 47, u[0] == 0x4D, (0x30...0x39).contains(u[1]) else { return nil }
        func morceau(_ a: Int, _ b: Int) -> String { code.unites(a, b).rogne }
        let de = morceau(30, 33), vers = morceau(33, 36), cie = morceau(36, 39)
        var numero = Array(morceau(39, 44).utf16)
        while numero.first == 0x30 { numero.removeFirst() }
        let n = Unites.texte(numero)
        let jour = Int(morceau(44, 47))
        guard aeroport.couvre(de), aeroport.couvre(vers), compagnie.couvre(cie), vol.couvre(n) else { return nil }
        let date = jour.flatMap { (1...366).contains($0) ? quantieme($0, aujourdhui) : nil }
        return Troncon(depart: de, arrivee: vers, compagnie: cie, numero: cie + n, date: date)
    }

    /// Le jour de l'année le plus proche d'aujourd'hui : l'an dernier, cette année ou l'an prochain.
    private static func quantieme(_ n: Int, _ aujourdhui: JourCivil) -> JourCivil? {
        let candidats = [aujourdhui.annee - 1, aujourdhui.annee, aujourdhui.annee + 1].compactMap { an -> JourCivil? in
            guard n <= (JourCivil.estBissextile(an) ? 366 : 365), let premier = JourCivil(annee: an, mois: 1, jour: 1) else { return nil }
            return premier.plus(jours: n - 1)
        }
        var meilleur: JourCivil?
        for c in candidats where meilleur == nil || abs(c.jourJulien - aujourdhui.jourJulien) < abs(meilleur!.jourJulien - aujourdhui.jourJulien) {
            meilleur = c
        }
        return meilleur
    }
}
