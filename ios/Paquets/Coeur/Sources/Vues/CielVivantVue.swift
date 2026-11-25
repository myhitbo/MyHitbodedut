import Combine
import Foundation
import SwiftUI
import Coeur

// Le ciel vivant des vues (CielVivant.kt, HorlogeCiel, GardeCiel d'Android ; 24/11) : l'horloge qui fait bouger les
// ciels, ce qui l'arrête, et ce que le ciel du Jour sait de la page (ses textes, ses anneaux).

/// L'horloge d'un ciel animé (HorlogeCiel et GardeCiel d'Android) : au plus une image toutes les `CielVivant.imageMs`
/// (20 par seconde), et seulement quand l'appareil le permet — ni « Réduire les animations » (Accessibilité), ni le
/// mode Économie d'énergie — que l'app est active (pas une scène inactive ni en arrière-plan) et que le ciel est à
/// l'écran (pas un autre onglet, pas un écran poussé par-dessus). Sinon la TimelineView est en pause, et le ciel est
/// dessiné dans sa pose de repos, la même à chaque fois : `contenu(nil)`. En marche, `contenu` reçoit les secondes
/// écoulées depuis que le ciel est apparu ; rien n'est créé d'une image à l'autre que ce dessin.
///
///     CielVivantHorloge { secondes in Canvas { … } }
struct CielVivantHorloge<Contenu: View>: View {
    @ViewBuilder let contenu: (Double?) -> Contenu

    @Environment(\.accessibilityReduceMotion) private var reduireSysteme
    @Environment(\.scenePhase) private var scene
    /// Le mode Économie d'énergie, suivi pendant que le ciel est à l'écran.
    @State private var economie = ProcessInfo.processInfo.isLowPowerModeEnabled
    /// Le ciel est à l'écran (onAppear) ; plus du tout quand un autre écran le couvre (onDisappear).
    @State private var visible = false
    /// Le temps du ciel part de son apparition.
    @State private var origine = Date()

    /// « Réduire les animations », ou le ciel immobile que demandent les tests d'interface (`CielImmobile`).
    private var reduire: Bool { reduireSysteme || CielImmobile.demande }

    var body: some View {
        let enMarche = CielVivant.enMarche(permis: CielVivant.permis(reduireAnimations: reduire, economieDEnergie: economie),
                                           sceneActive: scene == .active, visible: visible)
        TimelineView(.animation(minimumInterval: Double(CielVivant.imageMs) / 1000, paused: !enMarche)) { contexte in
            contenu(enMarche ? max(contexte.date.timeIntervalSince(origine), 0) : nil)
        }
        .onAppear {
            visible = true
            economie = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .onDisappear { visible = false }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .receive(on: DispatchQueue.main)) { _ in
            economie = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
}

/// Le ciel immobile des tests d'interface et des captures de la CI (« -cielImmobile ») : sa pose de repos, comme avec
/// « Réduire les animations ». XCTest attend que l'app soit au repos avant chaque mesure, et un ciel qui bouge ne
/// l'est jamais : sur le simulateur de la CI, sans processeur graphique, l'audit des tailles du texte du Jour ne
/// finissait plus (le 25/11). La pose de repos est aussi la plus exigeante pour le contraste : les animations ne font
/// que pâlir le ciel (halo, étoiles), jamais l'aviver ; et une capture la montre la même d'un passage à l'autre.
enum CielImmobile {
    static let demande = ProcessInfo.processInfo.arguments.contains("-cielImmobile")
}

/// Une couleur ARGB des ciels (les entiers de `TeintesCiel` et de `PaysageCiel`), dans l'espace sRGB d'Android.
enum CielCouleur {
    static func couleur(_ argb: UInt32, opacite: Double = 1) -> Color {
        Color(.sRGB, red: Double((argb >> 16) & 0xFF) / 255, green: Double((argb >> 8) & 0xFF) / 255,
              blue: Double(argb & 0xFF) / 255, opacity: Double((argb >> 24) & 0xFF) / 255 * opacite)
    }
}

/// Les teintes du ciel du Jour pour la palette et le mode de l'écran (MainActivity.renderCiel) : celles de
/// `TeintesCiel`, où chaque texte posé sur le ciel garde le contraste de PaletteTests. Nil avec la palette
/// « Contraste élevé » : on l'a choisie pour le plus fort contraste, le papier uni reste.
enum CielDuJourTeintes {
    static func teintes(_ etat: EtatCiel, palette: PaletteApp, sombre: Bool) -> TeintesCiel.Page? {
        guard palette.fond != .contraste else { return nil }
        let encres = TeintesCiel.encresDuJour(encre: palette.couleur(.ink, nuit: sombre),
                                              discret: palette.couleur(.muted, nuit: sombre),
                                              accent: palette.couleur(.brand, nuit: sombre), nuit: sombre)
        return TeintesCiel.pourCiel(etat.hauteur, matin: etat.matin, sombre: sombre, encres: encres,
                                    papier: TeintesCiel.argb(palette.couleur(.paper, nuit: sombre)))
    }
}

// MARK: - Ce que le ciel du Jour sait de la page

/// Où sont les anneaux et ce qui porte du texte, sur la page du Jour (MainActivity.placerCiel) : l'astre passe à côté
/// des anneaux et derrière eux, jamais sous un texte ; aucune étoile sous un texte ; un nuage n'est vif que dans une
/// bande sans texte. Chaque vue le dit d'elle-même (`zoneDuCiel`, `jaugeDuCiel`) ; la page le lit en fond
/// (`backgroundPreferenceValue`).
struct PlanDuCiel {
    var zones: [Anchor<CGRect>] = []
    var jauge: Anchor<CGRect>? = nil
}

struct PlanDuCielCle: PreferenceKey {
    static var defaultValue: PlanDuCiel { PlanDuCiel() }

    static func reduce(value: inout PlanDuCiel, nextValue: () -> PlanDuCiel) {
        let suivant = nextValue()
        value.zones += suivant.zones
        if value.jauge == nil { value.jauge = suivant.jauge }
    }
}

extension View {
    /// Ce que le ciel du Jour évite : un texte, une icône, un bouton, une carte, une case de la semaine, la plaque.
    func zoneDuCiel() -> some View {
        transformAnchorPreference(key: PlanDuCielCle.self, value: .bounds) { plan, ancre in
            plan.zones.append(ancre)
        }
    }

    /// Le carré des anneaux : l'astre passe à côté d'eux, et derrière eux vers midi.
    func jaugeDuCiel() -> some View {
        transformAnchorPreference(key: PlanDuCielCle.self, value: .bounds) { plan, ancre in
            plan.jauge = ancre
        }
    }
}
