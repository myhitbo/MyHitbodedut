import Foundation

/// Une clé du catalogue de chaînes, littérale ou interpolée.
public struct LocalizedStringKey: Equatable, ExpressibleByStringInterpolation, Sendable {
    let cle: String
    public init(_ value: String) { cle = value }
    public init(stringLiteral value: String) { cle = value }
    public init(stringInterpolation: StringInterpolation) { cle = stringInterpolation.morceaux }

    public struct StringInterpolation: StringInterpolationProtocol {
        var morceaux = ""
        public init(literalCapacity: Int, interpolationCount: Int) {}
        public mutating func appendLiteral(_ literal: String) { morceaux += literal }
        public mutating func appendInterpolation(_ string: String) { morceaux += "%@" }
        public mutating func appendInterpolation<Subject: CustomStringConvertible>(_ value: Subject) { morceaux += "%@" }
        public mutating func appendInterpolation(_ text: Text) { morceaux += "%@" }
    }
}

nonisolated public struct Text: View, Equatable, Sendable {
    let contenu: String
    public init(_ key: LocalizedStringKey, tableName: String? = nil, bundle: Bundle? = nil, comment: StaticString? = nil) {
        contenu = key.cle
    }
    @_disfavoredOverload
    public init<S: StringProtocol>(_ content: S) { contenu = String(content) }
    public init(verbatim content: String) { contenu = content }
    public var body: Never { corpsPrimitif() }

    public func font(_ font: Font?) -> Text { self }
    public func bold() -> Text { self }
    public func italic() -> Text { self }
    public func monospacedDigit() -> Text { self }
    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> Text { self }
}

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
