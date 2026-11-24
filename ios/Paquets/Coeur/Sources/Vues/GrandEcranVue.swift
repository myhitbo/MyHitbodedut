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

/// Deux colonnes sur l'iPad (tâche 29). Android n'a pour la tablette que ses marges et garde une colonne ; ici, quand la
/// place entre les marges en tient deux (`GrandEcran.deuxColonnes`), un écran met côte à côte ses deux moitiés,
/// coupées par l'écran lui-même là où leurs hauteurs s'équilibrent (Zmanim, le calendrier, le Chemin, les réglages,
/// l'accueil Sérénité).
/// Sinon (l'iPhone, debout ou couché ; l'iPad mini debout, une fenêtre étroite ; les tailles d'accessibilité du
/// texte), la colonne de toujours, au point près : la seconde moitié sous la première, à `espacement`, comme si leurs
/// éléments étaient ceux d'une même `VStack(alignment: .leading, spacing: espacement)`.
///
/// La place se lit à la mise en page (`DispositionColonnes`, d'après la largeur proposée), sans mesure ni état : rien
/// n'est reconstruit quand l'iPad tourne ou partage son écran, et rien ne se dessine d'abord en une colonne. En hébreu
/// et en arabe, les colonnes s'inversent d'elles-mêmes (la première à droite). Chaque moitié est un conteneur
/// d'accessibilité : VoiceOver lit toute la première colonne, puis la seconde, et non les deux ligne à ligne.
public struct DeuxColonnes<Premiere: View, Seconde: View>: View {
    private let espacement: CGFloat
    private let premiere: Premiere
    private let seconde: Seconde
    @Environment(\.dynamicTypeSize) private var taille
    @Environment(\.verticalSizeClass) private var classeVerticale

    public init(espacement: CGFloat, @ViewBuilder premiere: () -> Premiere, @ViewBuilder seconde: () -> Seconde) {
        self.espacement = espacement
        self.premiere = premiere()
        self.seconde = seconde()
    }

    public var body: some View {
        DispositionColonnes(texteAccessible: taille.isAccessibilitySize, hauteurCompacte: classeVerticale == .compact,
                            espacement: espacement) {
            VStack(alignment: .leading, spacing: espacement) {
                premiere
            }
            .accessibilityElement(children: .contain)
            VStack(alignment: .leading, spacing: espacement) {
                seconde
            }
            .accessibilityElement(children: .contain)
        }
    }
}

/// La mise en page de `DeuxColonnes` : ses deux moitiés côte à côte, séparées de `espacement`, quand la largeur
/// proposée (la place entre les marges de l'écran) en tient deux ; l'une sous l'autre sinon, par une
/// `VStackLayout(alignment: .leading, spacing: espacement)`, celle d'une `VStack`.
struct DispositionColonnes: Layout {
    let texteAccessible: Bool
    let hauteurCompacte: Bool
    let espacement: CGFloat

    private var pile: VStackLayout {
        VStackLayout(alignment: .leading, spacing: espacement)
    }

    /// La largeur d'une colonne, ou nil pour une seule colonne.
    private func largeurColonne(_ proposition: ProposedViewSize, _ elements: Subviews) -> CGFloat? {
        guard elements.count == 2, let largeur = proposition.width, largeur.isFinite,
              GrandEcran.deuxColonnes(place: Double(largeur), texteAccessible: texteAccessible,
                                      hauteurCompacte: hauteurCompacte) else { return nil }
        return (largeur - espacement) / 2
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let colonne = largeurColonne(proposal, subviews) else {
            var cachePile = pile.makeCache(subviews: subviews)
            return pile.sizeThatFits(proposal: proposal, subviews: subviews, cache: &cachePile)
        }
        let hauteur = subviews.map { $0.sizeThatFits(ProposedViewSize(width: colonne, height: nil)).height }.max() ?? 0
        return CGSize(width: colonne * 2 + espacement, height: hauteur)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let colonne = largeurColonne(proposal, subviews) else {
            var cachePile = pile.makeCache(subviews: subviews)
            pile.placeSubviews(in: bounds, proposal: proposal, subviews: subviews, cache: &cachePile)
            return
        }
        // De gauche à droite ; SwiftUI retourne les positions en hébreu et en arabe.
        for (rang, element) in subviews.enumerated() {
            element.place(at: CGPoint(x: bounds.minX + CGFloat(rang) * (colonne + espacement), y: bounds.minY),
                          anchor: .topLeading, proposal: ProposedViewSize(width: colonne, height: nil))
        }
    }
}
