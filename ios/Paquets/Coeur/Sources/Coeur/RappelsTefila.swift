import Foundation

/// Les rappels de tefila (RappelsTefila.kt, sur le modèle de CalJ) : quelques jours avant, la carte
/// de l'accueil annonce un changement dans la prière. Seulement des changements établis, chacun avec
/// sa source, tirés des conditions du jour (CalendrierJuif) :
/// - pluie : on commence à la demander à Arvit du soir qui ouvre le premier jour (7 'Hechvan en
///   Israël, la tekoufa en diaspora), on cesse à Pessa'h (O.H. 117:1) ;
/// - מַשִּׁיב הָרוּחַ : de Moussaf du 22 Tichri à Moussaf du 15 Nissan (O.H. 114:1) ;
/// - les dix jours de techouva, dès le soir de Roch Hachana (O.H. 582:1) ;
/// - l'omer, dès le second soir de Pessa'h (O.H. 489:1).
public enum RappelsTefila {

    public enum Genre: String, Sendable, CaseIterable {
        case pluieDebut, pluieFin, guechemDebut, guechemFin, dixJours, omer

        /// La référence du Choul'han Aroukh, O.H.
        public var source: String {
            switch self {
            case .pluieDebut, .pluieFin: "117:1"
            case .guechemDebut, .guechemFin: "114:1"
            case .dixJours: "582:1"
            case .omer: "489:1"
            }
        }

        /// Un changement « du soir » commence à Arvit, au soir de la veille ; les autres, dans la
        /// journée (Moussaf).
        public var leSoir: Bool {
            switch self {
            case .pluieDebut, .dixJours, .omer: true
            case .pluieFin, .guechemDebut, .guechemFin: false
            }
        }
    }

    /// `date` : le jour civil du changement.
    public struct Rappel: Sendable, Hashable {
        public let genre: Genre
        public let date: JourCivil

        public init(_ genre: Genre, _ date: JourCivil) {
            self.genre = genre
            self.date = date
        }
    }

    /// Les changements des `avance` jours à venir (aujourd'hui compris), du plus proche au plus
    /// lointain. `sansGuechem` : les Edot de l'hémisphère sud disent מוריד הטל toute l'année ; ni
    /// début ni fin de מַשִּׁיב הָרוּחַ à annoncer.
    public static func prochains(_ aujourdhui: JourCivil, avance: Int = 3, sansGuechem: Bool = false,
                                 jour: (JourCivil) -> CalendrierJuif.Jour) -> [Rappel] {
        let pluie = CalendrierJuif.C.talOumatar
        let tichri = CalendrierJuif.Mois.tichri, nissan = CalendrierJuif.Mois.nissan
        var res: [Rappel] = []
        var veille = jour(aujourdhui.plus(jours: -1))
        for k in 0...avance {
            let d = aujourdhui.plus(jours: k)
            let j = jour(d)
            // Premier jour un samedi : la Amida de Chabbat ne la demande pas, on commence à motsaé Chabbat,
            // soit à Arvit du soir du samedi : le rappel est daté du dimanche (FCALENDRIER-04).
            if j.conditions.contains(pluie) && !veille.conditions.contains(pluie) {
                res.append(Rappel(.pluieDebut, d.jourDeSemaine == 7 ? d.plus(jours: 1) : d))
            }
            if !j.conditions.contains(pluie) && veille.conditions.contains(pluie) { res.append(Rappel(.pluieFin, d)) }
            if !sansGuechem && j.moisHebreu == tichri && j.jourHebreu == 22 { res.append(Rappel(.guechemDebut, d)) }
            if !sansGuechem && j.moisHebreu == nissan && j.jourHebreu == 15 { res.append(Rappel(.guechemFin, d)) }
            if j.moisHebreu == tichri && j.jourHebreu == 1 { res.append(Rappel(.dixJours, d)) }
            if j.omer == 1 { res.append(Rappel(.omer, d)) }
            veille = j
        }
        // Un changement du soir dont le soir est déjà passé n'est plus annoncé.
        return res.filter { !($0.genre.leSoir && !($0.date > aujourdhui)) }
    }
}

/// L'horaire du jour d'une prière, pour sa bannière (HorairePriere.kt), aux bornes du widget :
/// Cha'harit jusqu'à la fin du temps de la tefila (GRA), Min'ha de min'ha guedola au coucher du
/// soleil, Arvit dès la sortie des étoiles. Ici les heures « HH:mm » ; la phrase est celle des chaînes
/// (`banniere_chaharit`, `banniere_minha`, `banniere_arvit`).
public enum HorairePriere {
    /// nil hors de ces trois prières, ou quand une heure manque (soleil de minuit).
    public static func heures(_ id: String, zmanim: [Zmanim.Zman], fuseau: TimeZone) -> [String]? {
        var gregorien = Calendar(identifier: .gregorian)
        gregorien.timeZone = fuseau
        func h(_ cle: String) -> String? {
            guard let instant = zmanim.first(where: { $0.cle == cle })?.instant else { return nil }
            let c = gregorien.dateComponents([.hour, .minute], from: instant)
            let deux = { (n: Int) in n < 10 ? "0\(n)" : "\(n)" }
            return "\(deux(c.hour ?? 0)):\(deux(c.minute ?? 0))"
        }
        switch id {
        case "chaharit": return h("szt_gra").map { [$0] }
        case "minha":
            guard let a = h("minha_gedola"), let b = h("chkia") else { return nil }
            return [a, b]
        case "arvit": return h("tset").map { [$0] }
        default: return nil
        }
    }
}
