import Foundation
import Observation

// SwiftUI « de papier » : les signatures de SwiftUI, sans rendu, pour que la CI Linux type-checke les vues
// de la cible Vues (sur iPhone, elles importent le vrai SwiftUI). Chaque déclaration recopie celle d'Apple
// (étiquettes, génériques, valeurs par défaut, isolement) ; rien n'y est inventé. Une vue qui compile ici
// peut encore échouer sur Xcode si une signature diverge : on corrige alors le papier, d'après Apple.

@MainActor @preconcurrency
public protocol View {
    associatedtype Body: View
    @ViewBuilder @MainActor @preconcurrency var body: Self.Body { get }
}

extension Never: View {
    public typealias Body = Never
    public var body: Never { fatalError("Never.body") }
}

/// Une vue primitive : son corps n'est jamais lu.
func corpsPrimitif() -> Never { fatalError("vue primitive") }

nonisolated public struct EmptyView: View {
    public init() {}
    public var body: Never { corpsPrimitif() }
}

nonisolated public struct TupleView<T>: View {
    public var value: T
    public init(_ value: T) { self.value = value }
    public var body: Never { corpsPrimitif() }
}

nonisolated public struct _ConditionalContent<TrueContent: View, FalseContent: View>: View {
    enum Branche { case vrai(TrueContent), faux(FalseContent) }
    let branche: Branche
    public var body: Never { corpsPrimitif() }
}

nonisolated public struct AnyView: View {
    public init<V: View>(_ view: V) {}
    public var body: Never { corpsPrimitif() }
}

extension Optional: View where Wrapped: View {
    public typealias Body = Never
    public var body: Never { corpsPrimitif() }
}

@resultBuilder
public struct ViewBuilder {
    public static func buildExpression<Content: View>(_ content: Content) -> Content { content }
    public static func buildBlock() -> EmptyView { EmptyView() }
    public static func buildBlock<Content: View>(_ content: Content) -> Content { content }
    public static func buildBlock<each Content: View>(_ content: repeat each Content) -> TupleView<(repeat each Content)> {
        TupleView((repeat each content))
    }
    public static func buildIf<Content: View>(_ content: Content?) -> Content? { content }
    public static func buildEither<TrueContent: View, FalseContent: View>(first: TrueContent) -> _ConditionalContent<TrueContent, FalseContent> {
        _ConditionalContent(branche: .vrai(first))
    }
    public static func buildEither<TrueContent: View, FalseContent: View>(second: FalseContent) -> _ConditionalContent<TrueContent, FalseContent> {
        _ConditionalContent(branche: .faux(second))
    }
    public static func buildLimitedAvailability<Content: View>(_ content: Content) -> AnyView { AnyView(content) }
}
