import Foundation

extension View {
    public func navigationTitle(_ title: Text) -> some View { self }
    public func navigationTitle(_ titleKey: LocalizedStringKey) -> some View { self }
}
