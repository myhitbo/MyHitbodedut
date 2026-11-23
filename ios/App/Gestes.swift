import Coeur
import Ecrans
import SwiftUI
import Vues

/// Ce qui vient d'hors de l'app et ce qui la fait repasser (tâches 17, 19, 25) : les adresses ouvertes par les
/// widgets et la Live Activity (`onOpenURL`), les réponses aux notifications (l'aiguillage), puis le planificateur
/// des notifications et les widgets, à chaque retour au premier plan, en partant en arrière-plan, au début et à la
/// fin d'une séance (BootReceiver, Reminder.reschedule, StreakWidget.refresh d'Android). La racine le pose une fois,
/// avec de quoi ouvrir un écran.
struct GestesExterieurs: ViewModifier {
    let app: ModelesApp
    let ouvrir: @MainActor (LienApp) -> Void
    @Environment(\.scenePhase) private var phase

    init(app: ModelesApp, ouvrir: @escaping @MainActor (LienApp) -> Void) {
        self.app = app
        self.ouvrir = ouvrir
    }

    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                if let lien = LienApp(url: url) { Aiguillage.commun.recevoir(.ouvrir(lien)) }
            }
            .onAppear { traiter() }
            .onChange(of: Aiguillage.commun.gestes) { _, _ in traiter() }
            .onChange(of: phase) { _, nouvelle in
                switch nouvelle {
                case .active:
                    replanifier()
                case .background:
                    replanifier()
                    RafraichissementWidgets.redessiner()
                default:
                    break
                }
            }
            // Une séance commencée tait les rappels et pose sa notification de fin ; close, elle allonge la série.
            .onChange(of: app.seance.suivie) { _, _ in replanifier() }
            .onChange(of: app.seance.inscriptions) { _, _ in
                replanifier()
                RafraichissementWidgets.redessiner()
            }
    }

    private func replanifier() {
        let planificateur = app.planificateur
        Task { await planificateur.replanifier() }
    }

    /// Les gestes en attente, un à un : un écran ouvert, « Plus tard », « Terminer maintenant ».
    private func traiter() {
        while let geste = Aiguillage.commun.prendre() {
            switch geste {
            case .ouvrir(.terminerSeance):
                let seance = app.seance
                Task { try? await seance.terminer() }
            case .ouvrir(let lien):
                ouvrir(lien)
            case .reporter:
                let planificateur = app.planificateur
                Task { try? await planificateur.reporter() }
            case .rien:
                break
            }
        }
    }
}

/// L'ajout de temps à un jour, gardé le temps de la feuille ; un jour à venir n'ouvre rien.
struct AjoutTempsFeuille: View {
    let fabrique: @MainActor () -> AjoutTempsModele?
    let fermer: @MainActor () -> Void
    @State private var modele: AjoutTempsModele? = nil
    @State private var construit = false

    init(fabrique: @escaping @MainActor () -> AjoutTempsModele?, fermer: @escaping @MainActor () -> Void) {
        self.fabrique = fabrique
        self.fermer = fermer
    }

    var body: some View {
        Group {
            if let modele {
                AjoutTempsVue(modele: modele, fermer: fermer)
            } else {
                Color.clear
            }
        }
        .onAppear {
            guard !construit else { return }
            construit = true
            modele = fabrique()
            if modele == nil { fermer() }
        }
    }
}
