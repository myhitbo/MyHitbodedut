/// L'arithmétique d'une séance (SessionRule.kt), à l'écart de tout écran pour qu'elle puisse être
/// mise à l'épreuve.
///
/// Une séance a une durée choisie, ou pas de durée du tout. La séance ouverte n'a pas de fin
/// inscrite : c'est la durée nulle qui la désigne, et rien d'autre que le geste de celui qui prie
/// ne l'arrête. Sa durée réelle est mesurée comme celle des autres, pour que la série et le total
/// continuent de compter.
///
/// Les instants sont des millisecondes Unix, « maintenant » compris : rien ici ne lit l'horloge.
/// Un instant insensé (une préférence abîmée, une horloge déréglée) reçoit la réponse d'Android,
/// jamais un arrêt : les soustractions débordent en silence comme celles d'un `Long`.
/// Jugée par `Tests/Vecteurs/seance.json` (tools/vecteurs_ios/VecteursSeance.kt).
public enum SessionRule {

    /// La durée d'une séance sans durée.
    public static let ouverte = 0

    /// La plus longue séance qu'on puisse choisir ; une séance ouverte s'y arrête aussi.
    public static let plafondOuverte = 240

    /// Ce que le compteur d'une séance en cours a le droit de dire.
    public enum Compteur: Sendable, Hashable, CaseIterable {
        /// Le temps restant, pour une séance minutée.
        case reste
        /// Le temps déjà passé, pour une séance ouverte.
        case ecoule
        /// Rien : le compteur est masqué jusqu'au signal de fin.
        case masque
    }

    /// La séance joue-t-elle du son ? Le morceau choisi, ou une ambiance sous lui (examen du 14/11, FBARRIERE-16).
    public static func joueDuSon(musique: Bool, ambiance: Ambiance) -> Bool {
        musique || ambiance != .silence
    }

    /// Un autre morceau a été choisi dans l'écran Musique pendant que celui de la séance est chargé (qu'il joue ou
    /// soit en pause) : hors lecture aléatoire, il prend sa place. `retenu` est le morceau que la bibliothèque
    /// retient, pas l'identifiant enregistré (FSEANCE-07).
    public static func autreMorceau(aleatoire: Bool, charge: Bool, retenu: String?, joue: String?) -> Bool {
        !aleatoire && charge && retenu != nil && retenu != joue
    }

    /// La notification de fin part-elle sans son ni vibration ? Quand on termine soi-même, et quand le décompte
    /// masqué joue sa sonnerie, pour ne pas sonner deux fois ; en vibreur ou en silencieux la sonnerie est muette,
    /// la notification garde alors son canal ordinaire (FSEANCE-06).
    public static func finSilencieuse(avantTerme: Bool, masque: Bool, sonnerieAudible: Bool) -> Bool {
        avantTerme || (masque && sonnerieAudible)
    }

    /// Le choix est fait une fois ici pour tous les endroits qui affichent un compteur : sur Android
    /// l'écran de séance, la notification en cours et l'écran de barrage. Le masquage l'emporte sur
    /// le reste : promettre « rien à l'écran » et laisser le chiffre ailleurs ne serait pas tenir parole.
    public static func compteur(ouverte: Bool, masque: Bool) -> Compteur {
        if masque { return .masque }
        return ouverte ? .ecoule : .reste
    }

    public static func estOuverte(debutMillis: Int64, duree: Int) -> Bool {
        debutMillis > 0 && duree == SessionRule.ouverte
    }

    /// Une séance ouverte court tant qu'elle n'a pas été close à la main ; une séance minutée court
    /// jusqu'à son terme.
    public static func enCours(debutMillis: Int64, finMillis: Int64, duree: Int, maintenant: Int64) -> Bool {
        if estOuverte(debutMillis: debutMillis, duree: duree) { return true }
        return finMillis > maintenant
    }

    /// Les minutes pleines écoulées depuis le début.
    public static func minutesEcoulees(debutMillis: Int64, maintenant: Int64) -> Int {
        if debutMillis <= 0 { return 0 }
        return max(0, minutes(maintenant &- debutMillis))
    }

    /// Les minutes à inscrire au journal quand la séance se clôt.
    ///
    /// Une séance minutée ne compte jamais plus que sa durée : sa fin peut n'être constatée que bien
    /// plus tard (écran éteint, application suspendue ou tuée, téléphone redémarré), et c'est alors
    /// l'heure du constat qui était inscrite — 20 minutes choisies devenaient 60 (revue du 29/09).
    /// Arrêtée avant son terme, elle compte le temps réellement passé.
    ///
    /// Une séance ouverte compte le temps passé, borné à `plafondOuverte` minutes : oubliée en
    /// marche, elle ne doit pas inscrire une journée.
    public static func minutesAInscrire(debutMillis: Int64, finMillis: Int64, maintenant: Int64) -> Int {
        if debutMillis <= 0 { return 0 }
        let minutee = finMillis > 0
        let borne = minutee ? min(maintenant, finMillis) : maintenant
        let passees = max(0, minutes(borne &- debutMillis))
        return minutee ? passees : min(passees, plafondOuverte)
    }

    /// Une séance inscrite dont personne ne s'occupe plus (l'app a été suspendue ou tuée) est-elle
    /// terminée ? Minutée : son terme est passé. Ouverte : elle a atteint le plafond.
    public static func estEchue(debutMillis: Int64, finMillis: Int64, duree: Int, maintenant: Int64) -> Bool {
        if debutMillis <= 0 { return false }
        if estOuverte(debutMillis: debutMillis, duree: duree) {
            let passe = maintenant &- debutMillis
            return passe >= Int64(plafondOuverte) * minute
        }
        return finMillis <= maintenant
    }

    // MARK: Le temps de la séance et « Continuer ? » (24/11)

    /// « Maintenant » pour une séance (décision du 24/11) : le début, plus le temps réellement écoulé depuis, mesuré
    /// sur l'horloge du téléphone qui ne recule ni n'avance jamais (le temps depuis le démarrage, sommeil compris).
    /// Changer l'heure, de fuseau ou passer à l'heure d'hiver pendant une séance ne la raccourcit ni ne l'allonge
    /// plus. Après un redémarrage cette horloge repart de zéro : on revient à l'heure murale, comme quand l'une des
    /// deux mesures du début manque (-1).
    public static func maintenant(debutMur: Int64, debutMonotone: Int64, demarrageDebut: Int,
                                  murActuel: Int64, monotoneActuel: Int64, demarrageActuel: Int) -> Int64 {
        if debutMur > 0 && debutMonotone >= 0 && demarrageDebut >= 0 && demarrageDebut == demarrageActuel
            && monotoneActuel >= debutMonotone {
            return debutMur &+ (monotoneActuel &- debutMonotone)
        }
        return murActuel
    }

    /// La question « Continuer ? » arrive dix secondes avant la fin (demande du 24/11).
    public static let avantFinSuiteMs: Int64 = 10_000

    /// Faut-il poser maintenant la question « Continuer ? » ? Une fois par étape, séance minutée seulement.
    public static func questionDue(fin: Int64, maintenant: Int64, activee: Bool, dejaPosee: Bool) -> Bool {
        activee && !dejaPosee && fin > 0 && maintenant < fin && fin &- maintenant <= avantFinSuiteMs
    }

    /// La nouvelle fin d'une séance prolongée de `minutes` : à partir de la fin prévue, et jamais d'un instant déjà
    /// passé (une réponse donnée après la fin repart de maintenant).
    public static func finProlongee(fin: Int64, maintenant: Int64, minutes: Int) -> Int64 {
        max(fin, maintenant) &+ Int64(minutes) &* minute
    }

    /// Les minutes restantes, arrondies au supérieur : « 1 min » doit s'afficher jusqu'à la toute
    /// fin, pas disparaître à 59 secondes.
    public static func minutesRestantes(finMillis: Int64, maintenant: Int64) -> Int {
        let reste = finMillis &- maintenant
        if reste <= 0 { return 0 }
        return minutes(reste &+ 59_999)
    }

    // MARK: Les minutes d'un Long de Kotlin

    private static let minute: Int64 = 60_000

    /// `(millis / 60_000L).toInt()` de Kotlin : la division tronque vers zéro, et `toInt()` ne garde
    /// que les 32 bits de poids faible, là où `Int32(…)` de Swift s'arrêterait au-delà de 4 000 ans.
    private static func minutes(_ millis: Int64) -> Int {
        Int(Int32(truncatingIfNeeded: millis / minute))
    }
}
