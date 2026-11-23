import Foundation
import Coeur

/// Le texte de 'hizouk du grand widget de la série (StreakWidget.texteDuJour, widget_large.xml) : un par jour, parmi
/// ceux de l'ouverture de la hitbodedout ; le même toute la journée, car le widget se redessine souvent et un texte qui
/// changerait à chaque fois ne se lirait jamais jusqu'au bout. L'hébreu, à droite quelle que soit la langue, et sa
/// référence dans la langue de l'app.
public struct WidgetTexteDuJour: Sendable, Hashable {
    public let hebreu: String
    public let reference: String

    public init(hebreu: String, reference: String) {
        self.hebreu = hebreu
        self.reference = reference
    }

    /// Le 1er janvier 1970 en jour julien : `toEpochDay()` vaut `jourJulien` moins ce nombre.
    private static let jourJulien1970 = 2_440_588

    /// `textes[(LocalDate.now().toEpochDay() % textes.size)]` parmi `ChizukRules.forMoment(OUVERTURE)` ; nil sans texte
    /// (le widget garde alors sa place vide, comme `return` d'Android). `debug` : les textes non relus passent aussi.
    public static func choisir(_ chizuk: Chizuk, jour: JourCivil, langue: String, debug: Bool) -> WidgetTexteDuJour? {
        let textes = ChizukRules.forMoment(chizuk, .ouverture, debug: debug)
        guard !textes.isEmpty else { return nil }
        let epoque = jour.jourJulien - jourJulien1970
        let rang = ((epoque % textes.count) + textes.count) % textes.count
        let item = textes[rang]
        return WidgetTexteDuJour(hebreu: ChizukRules.hebrew(chizuk, item), reference: Reference.localise(item.ref, langue))
    }
}
