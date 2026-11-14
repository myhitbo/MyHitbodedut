/// Les trois anneaux de l'accueil, à la manière des anneaux d'activité d'Apple (Anneaux.kt, demande du
/// 01/10) : de l'intérieur vers l'extérieur,
///
///  - le JOUR : les minutes faites aujourd'hui sur l'objectif quotidien ;
///  - la SEMAINE : les jours faits sur les jours dus (`JaugeSemaine`) ;
///  - la SÉRIE : les jours d'affilée sur le prochain palier.
///
/// Un anneau ne se « ferme » pas à l'objectif : au-delà, il repasse sur lui-même, comme chez Apple où
/// 150 % font un tour et demi. C'est la fraction brute qui le dit ; le dessin en tire les tours entiers
/// et le reste. Les fractions sont en simple précision, comme les `Float` de Kotlin, et les entiers
/// suivent les 32 bits d'un `Int` de Kotlin. Jugés par `Tests/Vecteurs/anneaux.json`
/// (tools/vecteurs_ios/VecteursAnneaux.kt).
public enum Anneaux {

    /// Les paliers de la série ; au-delà du dernier, de 365 en 365.
    public static let paliers: [Int] = [7, 14, 30, 60, 100, 180, 365]

    /// Le nom de chaque cas est celui de l'énumération Kotlin (`name`).
    public enum Quel: String, Sendable, CaseIterable {
        case jour = "JOUR"
        case semaine = "SEMAINE"
        case serie = "SERIE"
    }

    public struct Anneau: Hashable, Sendable {
        public let quel: Quel
        public let fait: Int
        public let objectif: Int

        public init(quel: Quel, fait: Int, objectif: Int) {
            self.quel = quel
            self.fait = fait
            self.objectif = objectif
        }

        /// Peut dépasser 1 : c'est le second tour. Sans objectif, rien.
        public var fraction: Float {
            objectif <= 0 ? 0 : Float(fait) / Float(objectif)
        }

        /// Les tours complets déjà faits : `Float.toInt()`, vers zéro, borné aux 32 bits de Kotlin.
        public var tours: Int { Kotlin.versInt(Double(fraction)) }

        /// Ce qui dépasse les tours complets, de 0 à 1, en simple précision comme sur Android.
        public var reste: Float { fraction - Float(tours) }

        public var atteint: Bool { objectif > 0 && fait >= objectif }
    }

    public struct Etat: Hashable, Sendable {
        public let jour: Anneau
        public let semaine: Anneau
        public let serie: Anneau

        public init(jour: Anneau, semaine: Anneau, serie: Anneau) {
            self.jour = jour
            self.semaine = semaine
            self.serie = serie
        }

        /// Du centre vers l'extérieur : l'ordre de dessin.
        public var duCentre: [Anneau] { [jour, semaine, serie] }

        /// Le premier anneau, depuis le centre, qui porte ce nom. nil là où Kotlin lève
        /// (`NoSuchElementException`) : un état bâti à la main sans anneau de ce nom.
        public func anneau(_ quel: Quel) -> Anneau? {
            for a in duCentre where a.quel == quel { return a }
            return nil
        }
    }

    /// Le palier que vise la série : le premier qui l'atteint ou la dépasse, pour que le jour où l'on y
    /// arrive l'anneau soit plein. Le lendemain le palier suivant commence, et l'anneau repart plus bas :
    /// c'est voulu, un palier atteint est acquis, le suivant est à faire.
    public static func palier(_ serie: Int) -> Int {
        for p in paliers where p >= serie { return p }
        // Au-delà d'un an : le prochain multiple de 365, sur les 32 bits d'un `Int` de Kotlin. Au-delà
        // de 2 147 483 283 jours, l'addition déborde et Kotlin rend un palier négatif sans lever : de même ici.
        let jours = Int32(truncatingIfNeeded: serie)
        return Int(((jours &+ 364) / 365) &* 365)
    }

    public static func etat(minutesJour: Int, objectifJour: Int, semaine: JaugeSemaine.Progression,
                            serie: Int) -> Etat {
        let jours = max(serie, 0)
        return Etat(
            jour: Anneau(quel: .jour, fait: max(minutesJour, 0), objectif: max(objectifJour, 0)),
            semaine: Anneau(quel: .semaine, fait: semaine.faits, objectif: semaine.dus),
            serie: Anneau(quel: .serie, fait: jours, objectif: palier(jours)))
    }

    /// Ce qui rend « nouveau » un anneau fermé : la date pour le jour, le dimanche de la semaine pour la
    /// semaine, le palier pour la série. Un anneau se fête une fois par marque, pas à chaque ouverture de
    /// l'accueil (demande du 04/10 : des animations automatiques). Les dates s'écrivent comme
    /// `LocalDate.toString()` (`JourCivil.iso`).
    public static func marque(_ anneau: Anneau, aujourdhui: JourCivil) -> String? {
        guard anneau.atteint else { return nil }
        switch anneau.quel {
        case .jour:
            return "jour:\(aujourdhui.iso)"
        case .semaine:
            // `jourDeSemaine` vaut 1 le dimanche : on recule d'autant de jours moins un.
            return "semaine:\(aujourdhui.plus(jours: 1 - aujourdhui.jourDeSemaine).iso)"
        case .serie:
            return "serie:\(anneau.objectif)"
        }
    }

    /// Les marques des anneaux fermés en ce moment : ce qu'on garde une fois la fête faite.
    public static func marques(_ etat: Etat, aujourdhui: JourCivil) -> Set<String> {
        var resultat = Set<String>()
        for a in etat.duCentre {
            if let m = marque(a, aujourdhui: aujourdhui) { resultat.insert(m) }
        }
        return resultat
    }

    /// Les anneaux fermés qui n'ont pas encore été fêtés, du centre vers l'extérieur. Une marque est
    /// faite de lettres ASCII, de chiffres et de signes : l'égalité de Swift (à l'équivalence canonique
    /// près) y est celle de Kotlin, unité par unité.
    public static func aFeter(_ etat: Etat, aujourdhui: JourCivil, dejaFetes: Set<String>) -> [Quel] {
        var resultat: [Quel] = []
        for a in etat.duCentre {
            if let m = marque(a, aujourdhui: aujourdhui), !dejaFetes.contains(m) { resultat.append(a.quel) }
        }
        return resultat
    }

    /// L'objectif quotidien effectif : celui qui est réglé, sinon la durée habituelle d'une hitbodedout.
    /// Un objectif nul ou négatif n'a pas de sens ; il retombe sur la durée, une minute au moins.
    public static func objectifEffectif(regle: Int, dureeHabituelle: Int) -> Int {
        regle > 0 ? regle : max(dureeHabituelle, 1)
    }
}
