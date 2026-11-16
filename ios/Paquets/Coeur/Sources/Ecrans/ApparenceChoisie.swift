import Foundation
import Coeur

/// Ce que les réglages disent de l'apparence de l'app (Apparence.kt, Personnage.kt) : le fond, l'accent, le mode
/// clair ou sombre, et l'adresse qui choisit le personnage. La vue racine de l'app en tire la palette, le mode
/// imposé à la fenêtre et la variante des illustrations ; la décision est ici, testée sous Linux, la vue n'a
/// plus qu'à l'appliquer.
public struct ApparenceChoisie: Sendable, Equatable {

    /// Le mode clair ou sombre (Apparence.Mode) : « auto » suit le téléphone.
    public enum Mode: String, Sendable, CaseIterable {
        case auto, clair, sombre
    }

    public let fond: Fond
    public let accent: Accent
    public let mode: Mode
    /// צדיק, צדקת, ou nil tant que rien n'est choisi : le personnage reste alors le hassid.
    public let adresse: Adresse?

    public init(fond: Fond = .vert, accent: Accent = .vert, mode: Mode = .auto, adresse: Adresse? = nil) {
        self.fond = fond
        self.accent = accent
        self.mode = mode
        self.adresse = adresse
    }

    /// Lue dans les réglages : une clé absente ou inconnue donne la valeur d'origine d'Android (vert, vert,
    /// « auto », aucune adresse), comme `Fond.parse`, `Accent.parse`, `Mode.parse` et `Adresse.parse`.
    public init(_ reglages: Reglages) {
        self.init(fond: reglages.fond,
                  accent: reglages.accent,
                  mode: Mode(rawValue: reglages.modeApparence) ?? .auto,
                  adresse: Adresse.parse(reglages.adresse))
    }

    /// La nuit imposée à l'app : vrai pour « sombre », faux pour « clair », nil pour suivre le téléphone
    /// (AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM).
    public var nuitImposee: Bool? {
        switch mode {
        case .auto: nil
        case .clair: false
        case .sombre: true
        }
    }

    /// Le nom de l'image à montrer pour une illustration d'Android (R.drawable.x) : sa pose féminine pour qui
    /// a choisi צדקת (Personnage.pour), elle-même sinon.
    public func image(_ nom: String) -> String {
        Personnage.pour(adresse, nom)
    }
}
