import Foundation

public struct Font: Hashable, Sendable {
    let nom: String
    public static let largeTitle = Font(nom: "largeTitle")
    public static let title = Font(nom: "title")
    public static let title2 = Font(nom: "title2")
    public static let title3 = Font(nom: "title3")
    public static let headline = Font(nom: "headline")
    public static let subheadline = Font(nom: "subheadline")
    public static let body = Font(nom: "body")
    public static let callout = Font(nom: "callout")
    public static let footnote = Font(nom: "footnote")
    public static let caption = Font(nom: "caption")
    public static let caption2 = Font(nom: "caption2")
    public func bold() -> Font { self }
    public func monospaced() -> Font { self }
    public func monospacedDigit() -> Font { self }
}

public protocol ShapeStyle: Sendable {}

nonisolated public struct Color: ShapeStyle, View, Hashable {
    let nom: String
    init(nom: String) { self.nom = nom }
    public init(red: Double, green: Double, blue: Double, opacity: Double = 1) { nom = "rvb" }
    public static let primary = Color(nom: "primary")
    public static let secondary = Color(nom: "secondary")
    public static let accentColor = Color(nom: "accent")
    public var body: Never { corpsPrimitif() }
}

public struct HierarchicalShapeStyle: ShapeStyle {
    let niveau: Int
}

extension ShapeStyle where Self == HierarchicalShapeStyle {
    public static var secondary: HierarchicalShapeStyle { HierarchicalShapeStyle(niveau: 2) }
    public static var tertiary: HierarchicalShapeStyle { HierarchicalShapeStyle(niveau: 3) }
}

extension View {
    public func font(_ font: Font?) -> some View { self }
    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> some View { self }
    public func padding(_ length: CGFloat? = nil) -> some View { self }
}
