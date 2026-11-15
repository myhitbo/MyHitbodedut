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
