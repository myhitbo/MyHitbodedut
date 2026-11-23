import SwiftUI

// Les grandes tailles de texte (tâche 29). Android écrit ses tailles en sp et laisse ses TextView passer à la ligne ;
// l'audit d'accessibilité d'Xcode monte la taille du texte jusqu'à la plus grande (AX5) et relève chaque texte qui
// ne grandit pas (« Dynamic Type font sizes are unsupported »), qui grandit mais se coupe ou rétrécit
// (« partially unsupported », « Text clipped »). Ces outils gardent le dessin d'Android à la taille ordinaire du
// texte (Large, celle du téléphone neuf) et laissent la place au texte au-delà.

extension DynamicTypeSize {
    /// Au-dessus de la taille ordinaire (Large) : le texte n'est plus tenu sur un nombre de lignes, ni rétréci.
    var agrandie: Bool { self > .large }
}

extension View {
    /// `lineLimit(lignes)` jusqu'à la taille ordinaire du texte ; au-delà, le texte passe à la ligne autant qu'il
    /// le faut (une TextView d'Android sans maxLines).
    public func lignesAuPlus(_ lignes: Int) -> some View {
        modifier(LignesAuPlus(lignes: lignes, facteur: 1))
    }

    /// Une ligne, rétrécie jusqu'à `facteur` s'il le faut, jusqu'à la taille ordinaire du texte ; au-delà, le
    /// texte garde sa taille et passe à la ligne.
    public func uneLigne(retrecie facteur: CGFloat) -> some View {
        modifier(LignesAuPlus(lignes: 1, facteur: facteur))
    }

    /// Le grand contenu (le visualiseur de grand contenu d'iOS, comme pour la barre d'onglets du système) : un
    /// élément trop petit pour grandir avec le texte (une case du calendrier, un onglet) se montre en grand quand
    /// on appuie longuement dessus, aux tailles d'accessibilité.
    public func grandContenu(_ titre: Text) -> some View {
        accessibilityShowsLargeContentViewer {
            titre
        }
    }
}

private struct LignesAuPlus: ViewModifier {
    let lignes: Int
    let facteur: CGFloat
    @Environment(\.dynamicTypeSize) private var taille

    func body(content: Content) -> some View {
        if taille.agrandie {
            content
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        } else if facteur < 1 {
            content
                .lineLimit(lignes)
                .minimumScaleFactor(facteur)
        } else {
            // Sans `minimumScaleFactor` : celui que pose la vue autour reste valable.
            content
                .lineLimit(lignes)
        }
    }
}

/// Une rangée qui se met en colonne aux tailles d'accessibilité (AX1 à AX5) : un libellé et sa valeur, des
/// chiffres côte à côte, des boutons. Côte à côte, chacun n'aurait plus que quelques lettres par ligne.
public struct RangeeAdaptable<Contenu: View>: View {
    private let alignement: VerticalAlignment
    private let alignementColonne: HorizontalAlignment
    private let espacement: CGFloat?
    private let contenu: Contenu
    @Environment(\.dynamicTypeSize) private var taille

    public init(alignement: VerticalAlignment = .center, colonne alignementColonne: HorizontalAlignment = .leading,
                espacement: CGFloat? = nil, @ViewBuilder contenu: () -> Contenu) {
        self.alignement = alignement
        self.alignementColonne = alignementColonne
        self.espacement = espacement
        self.contenu = contenu()
    }

    public var body: some View {
        let disposition = taille.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: alignementColonne, spacing: espacement))
            : AnyLayout(HStackLayout(alignment: alignement, spacing: espacement))
        disposition {
            contenu
        }
    }
}

/// Une tuile qui grandit avec son texte (les tuiles de Bento, de hauteur fixe sur Android) : ses éléments sont posés
/// les uns sur les autres comme dans une `ZStack`, chacun sur toute la tuile (sa propre `frame` le range dans un
/// coin) ; la tuile a au moins `minimum` de haut, et plus si le texte du haut et celui du bas ne tiennent plus,
/// l'un au-dessus de l'autre, aux grandes tailles du texte. Un élément décoratif (`roleDansTuile(.decor)`) ne
/// compte pas dans la hauteur.
public struct TuileExtensible: Layout {
    private let minimum: CGFloat
    private let ecart: CGFloat

    public init(minimum: CGFloat, ecart: CGFloat = 8) {
        self.minimum = minimum
        self.ecart = ecart
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let largeur = proposal.width
        var haut: CGFloat = 0
        var bas: CGFloat = 0
        for element in subviews {
            let role = element[RoleDansTuile.self]
            guard role != .decor else { continue }
            let h = element.sizeThatFits(ProposedViewSize(width: largeur, height: nil)).height
            if role == .bas { bas = max(bas, h) } else { haut = max(haut, h) }
        }
        let contenu = haut + bas + (haut > 0 && bas > 0 ? ecart : 0)
        let w = largeur ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        return CGSize(width: w, height: max(minimum, contenu))
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for element in subviews {
            element.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
        }
    }
}

/// La place d'un élément dans une `TuileExtensible` : en haut (par défaut), en bas, ou décoratif.
public enum RoleDansTuile: LayoutValueKey, Sendable {
    case haut, bas, decor
    public static let defaultValue = RoleDansTuile.haut
}

extension View {
    public func roleDansTuile(_ role: RoleDansTuile) -> some View {
        layoutValue(key: RoleDansTuile.self, value: role)
    }
}

extension View {
    /// Les boutons de lecture au bas d'un texte qui défile (la pastille « Aa », la barre dépliée, la commande du
    /// défilement automatique) : posés sous le texte, dans la marge du bas (`safeAreaInset`), sur une bande du fond
    /// du texte tant qu'ils se voient. Flottants par-dessus le texte, comme sur Android, ils en couvraient des lignes
    /// (couché surtout, captures du 23/11) ; ici, aucune ligne n'est jamais sous eux. Effacés au défilement, la bande
    /// s'efface aussi et le texte passe dessous.
    public func boutonsDeLecture<Fond: ShapeStyle, Boutons: View>(fond: Fond, visibles: Bool,
                                                                  @ViewBuilder _ boutons: () -> Boutons) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            boutons()
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background {
                    Rectangle()
                        .fill(fond)
                        .opacity(visibles ? 1 : 0)
                        .ignoresSafeArea(edges: .bottom)
                }
                .accessibilityIdentifier("barre-bas")
        }
    }

    /// Les hauteurs d'une feuille : celles demandées à la taille ordinaire du texte ; la seule grande aux tailles
    /// d'accessibilité, où une demi-feuille ne montrait plus que deux lignes.
    public func hauteursDeFeuille(_ hauteurs: Set<PresentationDetent>) -> some View {
        modifier(HauteursDeFeuille(hauteurs: hauteurs))
    }
}

private struct HauteursDeFeuille: ViewModifier {
    let hauteurs: Set<PresentationDetent>
    @Environment(\.dynamicTypeSize) private var taille

    func body(content: Content) -> some View {
        content.presentationDetents(taille.isAccessibilitySize ? [.large] : hauteurs)
    }
}
