/// Les faces du centre des anneaux (Plaque.kt, demande du 04/10) : le hassid, puis vos chiffres, une face
/// par toucher. Chaque face qui parle d'un anneau le met en avant ; toucher un anneau montre sa face.
///
/// Rien d'un écran ici : l'ordre des faces, les chiffres qu'elles montrent et la meilleure série se
/// vérifient sans appareil. Jugée par `Tests/Vecteurs/plaque.json` (tools/vecteurs_ios/VecteursPlaque.kt).
public enum Plaque {

    /// Dans l'ordre de Kotlin (`entries`) ; le nom de chaque cas est celui de l'énumération Kotlin.
    public enum Face: String, Sendable, CaseIterable {
        case hassid = "HASSID"
        case jour = "JOUR"
        case semaine = "SEMAINE"
        case serie = "SERIE"
        case meilleure = "MEILLEURE"
        case total = "TOTAL"
        case jours = "JOURS"
        case moyenne = "MOYENNE"

        /// L'anneau dont parle la face : nil pour le hassid et pour les chiffres qui ne sont d'aucun anneau.
        public var anneau: Anneaux.Quel? {
            switch self {
            case .jour: return Anneaux.Quel.jour
            case .semaine: return Anneaux.Quel.semaine
            case .serie, .meilleure: return Anneaux.Quel.serie
            case .hassid, .total, .jours, .moyenne: return nil
            }
        }
    }

    /// Le temps sans toucher après lequel le hassid revient, en millisecondes.
    public static let retourMs: Int64 = 8_000

    /// La face d'après, dans l'ordre ; après la dernière, le hassid.
    public static func suivante(_ face: Face) -> Face {
        let faces = Face.allCases
        let rang = faces.firstIndex(of: face) ?? 0
        return faces[(rang + 1) % faces.count]
    }

    /// La face qui parle de cet anneau : la première dans l'ordre (la série avant la meilleure série).
    public static func pour(_ quel: Anneaux.Quel) -> Face {
        for face in Face.allCases where face.anneau == quel { return face }
        return .hassid  // jamais : chaque anneau a sa face
    }

    /// Les minutes moyennes d'un jour de pratique, arrondies ; 0 sans pratique. Le quotient est en simple
    /// précision et arrondi comme par `Math.round(float)` : demis vers plus l'infini, bornes de 32 bits.
    public static func moyenne(totalMinutes: Int, jours: Int) -> Int {
        jours <= 0 ? 0 : Kotlin.arrondiFlottant(Float(totalMinutes) / Float(jours))
    }

    /// La plus longue suite de jours faits. Comme la série du jour, un jour exempté (Chabbat, fête, pause)
    /// ne compte pas et ne casse pas. Comme sur Android, `exempt` n'est demandé que pour un jour non fait,
    /// entre le premier et le dernier jour fait.
    public static func meilleureSerie(_ faits: Set<JourCivil>, exempt: (JourCivil) -> Bool) -> Int {
        guard let premier = faits.min(), let dernier = faits.max() else { return 0 }
        var jour = premier
        var courante = 0
        var meilleure = 0
        while jour <= dernier {
            if faits.contains(jour) {
                courante += 1
                meilleure = max(meilleure, courante)
            } else if !exempt(jour) {
                courante = 0
            }
            jour = jour.plus(jours: 1)
        }
        return meilleure
    }
}
