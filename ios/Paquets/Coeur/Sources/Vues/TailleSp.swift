import SwiftUI

extension View {
    /// La police du téléphone à la taille d'Android, en sp (18, 24…), mise à l'échelle de la taille du texte
    /// choisie dans les réglages (Dynamic Type) comme le style `relativeA`, ce que fait le sp d'Android. Pour les
    /// titres que `.system(size:)` figeait : l'audit d'accessibilité les relevait (tâche 29, ios-captures.yml).
    public func tailleSp(_ sp: CGFloat, poids: Font.Weight = .regular, design: Font.Design = .default,
                         relativeA style: Font.TextStyle = .body) -> some View {
        modifier(TailleSp(sp: sp, poids: poids, design: design, style: style))
    }
}

/// La taille suit Dynamic Type par `@ScaledMetric`, comme `PoliceHebraiqueModificateur` pour les textes saints.
private struct TailleSp: ViewModifier {
    let poids: Font.Weight
    let design: Font.Design
    @ScaledMetric private var taille: CGFloat

    init(sp: CGFloat, poids: Font.Weight, design: Font.Design, style: Font.TextStyle) {
        self.poids = poids
        self.design = design
        _taille = ScaledMetric(wrappedValue: sp, relativeTo: style)
    }

    func body(content: Content) -> some View {
        content.font(.system(size: taille, weight: poids, design: design))
    }
}
