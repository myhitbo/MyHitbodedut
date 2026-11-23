import SwiftUI
import Ecrans

/// Les marges des grands écrans (tâche 29 ; values-w600dp, -w840dp, -w1200dp d'Android, `GrandEcran`) : posées une
/// fois par la racine, elles écartent des bords le contenu de tous les écrans défilants (`contentMargins` passe par
/// l'environnement jusqu'aux `ScrollView` et aux `List` de la pile et des feuilles), par-dessus leur propre marge de
/// téléphone. Sur un iPhone debout, rien ne change : la marge nulle laisse celle du système (nil), sans changer la
/// structure des vues, que la rotation ne doit pas reconstruire.
struct MargesLarges: ViewModifier {
    @State private var largeur: Double = 0

    func body(content: Content) -> some View {
        let marge = GrandEcran.marge(largeur: largeur)
        content
            .contentMargins(.horizontal, marge > 0 ? CGFloat(marge) : nil, for: .scrollContent)
            .onGeometryChange(for: Double.self, of: { Double($0.size.width) }) { nouvelle in
                largeur = nouvelle
            }
    }
}

extension View {
    /// Les marges des grands écrans, d'après la largeur de cette vue (la fenêtre de l'app, posée à la racine).
    public func margesLarges() -> some View {
        modifier(MargesLarges())
    }
}
