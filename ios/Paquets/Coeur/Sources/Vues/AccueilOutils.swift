import Accessibility
import Foundation
import SwiftUI
import Coeur
import Ecrans

// Ce que partagent les vues de l'accueil (AccueilVue.swift, AccueilJauge.swift, AccueilSections.swift,
// AccueilCartes.swift) : les couleurs que nomme le modèle (`AccueilCouleur`, `AccueilFondJour`), l'écriture d'un
// `AccueilTexte`, les dates écrites dans la langue de l'app, le bouton qui se creuse et le message bref. Aucune
// décision ici : le modèle (`AccueilModele`) a tout dit.

// MARK: Les couleurs

/// Les couleurs de l'accueil. `brand`, `ink`, `muted`, `dayTodo`… sont des jetons de la palette ; `ring_week`,
/// `ring_streak`, `day_exempt` et `white` sont écrites en dur par Android (res/values/colors.xml, et values-night
/// pour la nuit), que la palette n'a pas : elles sont recopiées ici telles quelles.
enum AccueilCouleurs {

    /// La couleur d'une `AccueilCouleur`, de jour ou de nuit.
    static func couleur(_ couleur: AccueilCouleur, palette: PaletteApp, nuit: Bool) -> Couleur {
        switch couleur {
        case .brand: return palette.couleur(.brand, nuit: nuit)
        case .ink: return palette.couleur(.ink, nuit: nuit)
        case .muted: return palette.couleur(.muted, nuit: nuit)
        case .ringWeek: return fixe(nuit ? "#6FB7E8" : "#2E7DB3")
        case .ringStreak: return fixe(nuit ? "#E8B45C" : "#B8780F")
        case .white: return fixe("#FFFFFF")
        }
    }

    /// day_exempt : le fond d'un jour exempté de la bande de la semaine.
    static func jourExempte(nuit: Bool) -> Couleur {
        fixe(nuit ? "#36322A" : "#F3EEE2")
    }

    /// La couleur d'un anneau (AnneauxDessin : `brand`, `ring_week`, `ring_streak`).
    static func anneau(_ quel: Anneaux.Quel, palette: PaletteApp, nuit: Bool) -> Couleur {
        switch quel {
        case .jour: return couleur(.brand, palette: palette, nuit: nuit)
        case .semaine: return couleur(.ringWeek, palette: palette, nuit: nuit)
        case .serie: return couleur(.ringStreak, palette: palette, nuit: nuit)
        }
    }

    /// `ColorUtils.blendARGB(a, b, part)` d'Android : `part` de `b` dans `a`, composante par composante.
    static func melange(_ a: Couleur, _ b: Couleur, part: Double) -> Couleur {
        func canal(_ x: UInt8, _ y: UInt8) -> UInt8 {
            let v = Double(x) * (1 - part) + Double(y) * part
            return UInt8(min(max(v.rounded(), 0), 255))
        }
        return Couleur(rouge: canal(a.rouge, b.rouge), vert: canal(a.vert, b.vert), bleu: canal(a.bleu, b.bleu))
    }

    private static func fixe(_ hex: String) -> Couleur {
        Couleur(hex: hex) ?? .noir
    }
}

/// Une `AccueilCouleur` en style de forme, résolue d'après la palette et le mode de l'écran, comme `Teinte`.
struct AccueilTeinte: ShapeStyle {
    let couleur: AccueilCouleur

    init(_ couleur: AccueilCouleur) {
        self.couleur = couleur
    }

    func resolve(in environment: EnvironmentValues) -> Color {
        Color(AccueilCouleurs.couleur(couleur, palette: environment.paletteApp,
                                      nuit: environment.colorScheme == .dark))
    }
}

/// day_exempt en style de forme.
struct AccueilTeinteExempte: ShapeStyle {
    init() {}

    func resolve(in environment: EnvironmentValues) -> Color {
        Color(AccueilCouleurs.jourExempte(nuit: environment.colorScheme == .dark))
    }
}

// MARK: Les textes

/// L'écriture d'un `AccueilTexte` : une chaîne de l'interface par le traducteur, ou le texte tel quel.
enum AccueilEcriture {
    static func texte(_ texte: AccueilTexte, _ traducteur: Traducteur) -> String {
        switch texte {
        case .libelle(let libelle): return traducteur.texte(libelle)
        case .brut(let brut): return brut
        }
    }

    /// Des libellés lus d'un trait, joints par `separateur` (les `contentDescription` d'Android).
    static func joints(_ libelles: [Libelle], _ traducteur: Traducteur, separateur: String) -> String {
        libelles.map { traducteur.texte($0) }.joined(separator: separateur)
    }

    /// Des textes lus d'un trait, joints par `separateur`.
    static func joints(_ textes: [AccueilTexte], _ traducteur: Traducteur, separateur: String) -> String {
        textes.map { texte($0, traducteur) }.joined(separator: separateur)
    }
}

// MARK: Les dates

/// Les dates que la vue écrit dans la langue de l'app (`DateTimeFormatter` d'Android avec la langue de l'app), au
/// calendrier grégorien.
enum AccueilDates {

    /// « dim. », « Sun », « יום א׳ » : le jour de la semaine en abrégé (« EEE »), sur la bande de la semaine.
    static func jourAbrege(_ jour: JourCivil, langue: String) -> String {
        ecrire(jour, langue: langue) { $0.dateFormat = "EEE" }
    }

    /// « Mardi » : le jour en toutes lettres (« EEEE »), majuscule initiale (`replaceFirstChar { titlecase }`).
    static func jourEnLettres(_ jour: JourCivil, langue: String) -> String {
        let texte = ecrire(jour, langue: langue) { $0.dateFormat = "EEEE" }
        guard let premiere = texte.first else { return texte }
        return String(premiere).capitalized(with: Locale(identifier: langue)) + String(texte.dropFirst())
    }

    /// « mardi 24 novembre 2026 » : la date en entier (`FormatStyle.FULL`), titre de la boîte d'un jour.
    static func complete(_ jour: JourCivil, langue: String) -> String {
        ecrire(jour, langue: langue) { format in
            format.dateStyle = .full
            format.timeStyle = .none
        }
    }

    private static func ecrire(_ jour: JourCivil, langue: String, _ regler: (DateFormatter) -> Void) -> String {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = .gmt
        // Midi : aucun changement d'heure ne fait glisser le jour.
        let composantes = DateComponents(year: jour.annee, month: jour.mois, day: jour.jour, hour: 12)
        guard let date = calendrier.date(from: composantes) else { return jour.iso }
        let format = DateFormatter()
        format.calendar = calendrier
        format.timeZone = .gmt
        format.locale = Locale(identifier: langue)
        regler(format)
        return format.string(from: date)
    }
}

// MARK: Les effets

/// Une carte qui « se creuse » sous le doigt (Effets.presse) : 98 % en 110 ms, retour en 160 ms. Rien quand on
/// réduit les animations.
struct AccueilBoutonCreux: ButtonStyle {
    init() {}

    func makeBody(configuration: Configuration) -> some View {
        AccueilCorpsCreux(configuration: configuration)
    }
}

private struct AccueilCorpsCreux: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.accessibilityReduceMotion) private var reduireAnimations

    init(configuration: ButtonStyleConfiguration) {
        self.configuration = configuration
    }

    private var creuse: Bool {
        configuration.isPressed && !reduireAnimations
    }

    var body: some View {
        configuration.label
            .scaleEffect(creuse ? 0.98 : 1)
            .animation(reduireAnimations ? nil : .easeOut(duration: creuse ? 0.11 : 0.16), value: creuse)
    }
}

/// Un mot bref (un `Toast` d'Android) : il s'efface au bout de `duree` ms (2 s pour un toast court, 3,5 s pour un
/// long), puis `fin` le retire du modèle ; VoiceOver l'annonce.
struct AccueilMessageBref: View {
    let message: Libelle
    let duree: Int
    let fin: @MainActor () -> Void
    @Environment(\.traducteur) private var traducteur

    init(message: Libelle, duree: Int, fin: @escaping @MainActor () -> Void) {
        self.message = message
        self.duree = duree
        self.fin = fin
    }

    var body: some View {
        Text(message, traducteur: traducteur)
            .font(.subheadline)
            .foregroundStyle(Teinte(.paper))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Teinte(.ink).opacity(0.9), in: Capsule())
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .allowsHitTesting(false)
            .task(id: message) {
                AccessibilityNotification.Announcement(traducteur.texte(message)).post()
                do {
                    try await Task.sleep(for: .milliseconds(duree))
                    fin()
                } catch {
                    // Un autre message l'a remplacé, ou l'écran s'en va : rien à faire.
                }
            }
    }
}
