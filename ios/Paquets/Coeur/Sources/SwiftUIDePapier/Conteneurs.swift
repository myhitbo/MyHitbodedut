import Foundation

public enum HorizontalAlignment: Equatable, Sendable { case leading, center, trailing }
public enum VerticalAlignment: Equatable, Sendable { case top, center, bottom, firstTextBaseline }

nonisolated public struct VStack<Content: View>: View {
    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
    public var body: Never { corpsPrimitif() }
}

nonisolated public struct HStack<Content: View>: View {
    public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
    public var body: Never { corpsPrimitif() }
}

nonisolated public struct Spacer: View {
    public init(minLength: CGFloat? = nil) {}
    public var body: Never { corpsPrimitif() }
}

nonisolated public struct List<SelectionValue: Hashable, Content: View>: View {
    public var body: Never { corpsPrimitif() }
}

extension List where SelectionValue == Never {
    public init(@ViewBuilder content: () -> Content) {}
}

nonisolated public struct ForEach<Data: RandomAccessCollection, ID: Hashable, Content: View>: View {
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder content: @escaping (Data.Element) -> Content) {}
    public var body: Never { corpsPrimitif() }
}

extension ForEach where ID == Data.Element.ID, Data.Element: Identifiable {
    public init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {}
}

nonisolated public struct Section<Parent: View, Content: View, Footer: View>: View {
    public var body: Never { corpsPrimitif() }
}

extension Section where Parent == EmptyView, Footer == EmptyView {
    public init(@ViewBuilder content: () -> Content) {}
}

extension Section where Footer == EmptyView {
    public init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Parent) {}
}

nonisolated public struct NavigationStack<Data, Root: View>: View {
    public var body: Never { corpsPrimitif() }
}

extension NavigationStack where Data == Never {
    public init(@ViewBuilder root: () -> Root) {}
}

nonisolated public struct Button<Label: View>: View {
    public init(action: @escaping @MainActor () -> Void, @ViewBuilder label: () -> Label) {}
    public var body: Never { corpsPrimitif() }
}

extension Button where Label == Text {
    public init(_ titleKey: LocalizedStringKey, action: @escaping @MainActor () -> Void) {}
}

extension View {
    public func navigationTitle(_ title: Text) -> some View { self }
    public func navigationTitle(_ titleKey: LocalizedStringKey) -> some View { self }
    public func font(_ font: Font?) -> some View { self }
    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> some View { self }
    public func padding(_ length: CGFloat? = nil) -> some View { self }
}
