import Foundation
import SwiftUI
import Coeur
import Ecrans

// Le système visuel de l'app (Apparence.kt d'Android, PORTAGE.md § 1.1) : les treize jetons de la Palette de
// Coeur, de jour et de nuit, portés par l'environnement SwiftUI. Une vue ne nomme jamais une couleur : elle
// nomme un jeton (`.foregroundStyle(Teinte(.ink))`, `.background(.jeton(.paper))`), que l'environnement
// résout d'après la palette choisie et le mode clair ou sombre de l'écran, comme `?attr/mhInk` sur Android.

extension Color {
    /// La couleur opaque d'un jeton, dans l'espace sRGB où Android écrit ses `#RRGGBB`.
    public init(_ couleur: Couleur) {
        self.init(.sRGB,
                  red: Double(couleur.rouge) / 255,
                  green: Double(couleur.vert) / 255,
                  blue: Double(couleur.bleu) / 255,
                  opacity: 1)
    }
}

/// La palette de l'app : un fond et un accent, avec leurs treize couleurs de jour et de nuit (palettes.json,
/// lu par `Palettes` de Coeur). L'écran prend celles du jour ou de la nuit selon son `colorScheme`.
public struct PaletteApp: Sendable, Equatable {
    public let fond: Fond
    public let accent: Accent
    private let jour: [Jeton: Couleur]
    private let nuit: [Jeton: Couleur]

    /// La combinaison choisie, lue dans `palettes.json` (Palettes vérifie ses 72 combinaisons).
    public init(palettes: Palettes, fond: Fond, accent: Accent) {
        let deJour = palettes.palette(fond: fond, accent: accent, nuit: false)
        let deNuit = palettes.palette(fond: fond, accent: accent, nuit: true)
        self.init(fond: fond, accent: accent,
                  jour: Dictionary(uniqueKeysWithValues: Jeton.allCases.map { ($0, deJour[$0]) }),
                  nuit: Dictionary(uniqueKeysWithValues: Jeton.allCases.map { ($0, deNuit[$0]) }))
    }

    private init(fond: Fond, accent: Accent, jour: [Jeton: Couleur], nuit: [Jeton: Couleur]) {
        self.fond = fond
        self.accent = accent
        self.jour = jour
        self.nuit = nuit
    }

    /// La palette de l'apparence choisie ; celle d'origine si `palettes.json` n'a pu être lu (aperçus, ou un
    /// paquet d'app sans contenus) : l'écran reste lisible, aux couleurs d'Android par défaut.
    public static func choisie(_ palettes: Palettes?, _ apparence: ApparenceChoisie) -> PaletteApp {
        guard let palettes else { return .origine }
        return PaletteApp(palettes: palettes, fond: apparence.fond, accent: apparence.accent)
    }

    /// La couleur d'un jeton, de jour ou de nuit.
    public func couleur(_ jeton: Jeton, nuit: Bool) -> Couleur {
        (nuit ? self.nuit : jour)[jeton] ?? .noir
    }

    /// La couleur d'un jeton pour le mode de l'écran.
    public func couleur(_ jeton: Jeton, schema: ColorScheme) -> Color {
        Color(couleur(jeton, nuit: schema == .dark))
    }

    /// La palette d'origine d'Android, fond vert et accent vert : values/colors.xml de jour, values-night de
    /// nuit (les valeurs de palettes.json pour « vert/vert », recopiées). Valeur par défaut de l'environnement.
    public static let origine = PaletteApp(
        fond: .vert, accent: .vert,
        jour: lire([
            .brand: "#16775A", .brandDark: "#173C32", .mint: "#DFF5E8", .onBrand: "#FFFFFF",
            .onPlate: "#16775A", .stageSoft: "#F1FAF4", .dayDone: "#16775A", .paper: "#F4F7F2",
            .card: "#FFFFFF", .line: "#DCE7DF", .ink: "#172B27", .muted: "#5E706A", .dayTodo: "#EDF2EE",
        ]),
        nuit: lire([
            .brand: "#6CD3A8", .brandDark: "#173C32", .mint: "#DFF5E8", .onBrand: "#0D1A15",
            .onPlate: "#16775A", .stageSoft: "#F1FAF4", .dayDone: "#16775A", .paper: "#101A16",
            .card: "#1A2B24", .line: "#2C4239", .ink: "#E6EFE9", .muted: "#9CB0A6", .dayTodo: "#22382F",
        ]))

    private static func lire(_ hex: [Jeton: String]) -> [Jeton: Couleur] {
        hex.mapValues { Couleur(hex: $0) ?? .noir }
    }
}

extension ApparenceChoisie {
    /// Le mode imposé à la fenêtre (`preferredColorScheme`) : nil pour suivre le téléphone.
    public var schema: ColorScheme? {
        guard let nuit = nuitImposee else { return nil }
        return nuit ? .dark : .light
    }
}

private struct ClePalette: EnvironmentKey {
    static let defaultValue = PaletteApp.origine
}

extension EnvironmentValues {
    /// La palette de l'app, posée par la vue racine d'après les réglages.
    public var paletteApp: PaletteApp {
        get { self[ClePalette.self] }
        set { self[ClePalette.self] = newValue }
    }
}

/// Un jeton de la palette, en style de forme : résolu à l'affichage d'après la palette de l'environnement et
/// le mode clair ou sombre de l'écran. `Teinte(.ink)`, ou `.jeton(.ink)` là où un style est attendu.
public struct Teinte: ShapeStyle {
    public let jeton: Jeton

    public init(_ jeton: Jeton) {
        self.jeton = jeton
    }

    public func resolve(in environment: EnvironmentValues) -> Color {
        environment.paletteApp.couleur(jeton, schema: environment.colorScheme)
    }
}

extension ShapeStyle where Self == Teinte {
    /// `.foregroundStyle(.jeton(.muted))`.
    public static func jeton(_ jeton: Jeton) -> Teinte {
        Teinte(jeton)
    }
}
