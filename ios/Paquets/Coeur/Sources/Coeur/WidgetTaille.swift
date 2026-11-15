// Quelle version de la vignette pour quelle place (WidgetTaille.kt, demande du 28/09) : une case, le
// compte et une coche ; la taille habituelle, la jauge et le bouton ; une grande place, la semaine et
// un texte du jour en plus. Les tailles sont en points (dp sur Android), recopiées par programme du
// Kotlin. `largeurType` × `hauteurType` : la place qu'elle a d'ordinaire (2 × 2, 4 × 2, 4 × 4 cases),
// celle qu'on dessine quand rien ne dit la sienne.

/// Les trois versions de la vignette, de la plus petite à la plus grande.
public enum WidgetTaille: Sendable, CaseIterable {
    case petite, moyenne, grande

    private var dimensions: (largeurMin: Float, hauteurMin: Float, largeurType: Float, hauteurType: Float) {
        switch self {
        case .petite: return (40, 40, 150, 150)
        case .moyenne: return (160, 110, 320, 150)
        case .grande: return (250, 250, 320, 320)
        }
    }

    public var largeurMin: Float { dimensions.largeurMin }
    public var hauteurMin: Float { dimensions.hauteurMin }
    public var largeurType: Float { dimensions.largeurType }
    public var hauteurType: Float { dimensions.hauteurType }

    /// La plus grande version qui tient dans la place donnée ; la petite si aucune n'y tient (NaN compris,
    /// qui ne tient nulle part, comme sur Android).
    public static func pour(largeur: Float, hauteur: Float) -> WidgetTaille {
        allCases.last { largeur >= $0.largeurMin && hauteur >= $0.hauteurMin } ?? .petite
    }
}
