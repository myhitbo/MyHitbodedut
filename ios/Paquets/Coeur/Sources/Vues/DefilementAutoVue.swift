import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
import UIKit.UIGestureRecognizerSubclass
#endif
import Coeur
import Ecrans

// Le défilement automatique des écrans de lecture (ReglagesLecture.kt, 16/11), commun au siddour (LectureVue),
// aux Tehilim (TehilimLectureVue), au Tikoun (TikkunVue), aux sources de la bibliothèque (BibliothequeEntreeVue), à
// la halakha (HalakhaVue, le Ben Ish 'Haï compris) et aux hilloulot (HilloulotVue) : le bouton ▶︎/❚❚ de la barre de
// lecture, la commande flottante [−] [N] [+] [❚❚] tant que le texte défile, et le moteur qui fait avancer la liste à
// chaque image. Ce qui se montre, la vitesse et le pas de chaque image se décident dans DefilementAuto (cible
// Ecrans).
//
// Le moteur : un TimelineView(.animation), présent seulement pendant le défilement, donne l'intervalle entre deux
// images ; `avancer` dit où mettre le texte, `ScrollPosition.scrollTo(y:)` l'y met. Un doigt posé n'importe où sur
// le texte l'arrête, sur une partie qui se touche aussi (la tête d'un tsadik, une flèche de la halakha, le bouton de
// Sefaria) : `ToucherDuTexte` voit l'appui avant tout autre geste et le laisse passer, comme l'indicateur de
// défilement d'Android (vérification du 24/11) ; le glissé (phase `tracking` ou `interacting`) aussi. Le bouton le
// relance. L'écran reste allumé tant qu'il défile, puis revient à ce qu'il était (`EcranAllume`).

/// Ce que le moteur lit de la liste : où est le texte et jusqu'où il peut descendre, en points depuis le haut du
/// contenu (les marges du conteneur comprises, pour parler comme `scrollTo(y:)`).
struct DefilementMesure: Equatable {
    let haut: Double
    let fin: Double

    init(_ geometrie: ScrollGeometry) {
        haut = Double(geometrie.contentOffset.y + geometrie.contentInsets.top)
        fin = max(0, Double(geometrie.contentSize.height + geometrie.contentInsets.top
                            + geometrie.contentInsets.bottom - geometrie.containerSize.height))
    }
}

/// Le moteur, posé sur le ScrollView du texte, avec la `ScrollPosition` qu'il suit déjà.
struct DefilementMoteur: ViewModifier {
    let defilement: DefilementAuto
    @Binding var position: ScrollPosition

    /// Rien de mesuré encore (la liste n'a pas bougé depuis son apparition) : le haut, et pas de bout connu ; le
    /// premier pas fait bouger la liste, qui se mesure alors.
    @State private var haut: Double = 0
    @State private var fin: Double = .infinity
    @Environment(\.scenePhase) private var phase

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: DefilementMesure.self, of: { DefilementMesure($0) }, action: { _, mesure in
                haut = mesure.haut
                fin = mesure.fin
            })
            // Le doigt posé sur le texte arrête le défilement, comme sur Android, le site et le Nokia :
            // on reprend la main, et le bouton le relance.
            .onScrollPhaseChange { _, phase in
                if phase == .tracking || phase == .interacting {
                    arreter()
                }
            }
            #if canImport(UIKit)
            .gesture(ToucherDuTexte { arreter() })
            #endif
            .background {
                if defilement.actif {
                    TimelineView(.animation) { contexte in
                        Color.clear
                            .onChange(of: contexte.date) { avant, apres in
                                image(apres.timeIntervalSince(avant))
                            }
                    }
                    .accessibilityHidden(true)
                }
            }
            .onChange(of: defilement.garderEcranAllume, initial: true) { _, allume in
                EcranAllume.garder(allume, pour: demandeur)
            }
            // L'écran s'en va (une autre app, l'écran verrouillé) : le défilement s'arrête.
            .onChange(of: phase) { _, nouvelle in
                if nouvelle == .background { arreter() }
            }
            .onDisappear {
                defilement.arreter()
                EcranAllume.garder(false, pour: demandeur)
            }
    }

    /// Le nom de ce défilement parmi ceux qui demandent l'écran allumé.
    private var demandeur: String {
        "defilement-" + String(UInt(bitPattern: ObjectIdentifier(defilement).hashValue))
    }

    private func arreter() {
        if defilement.actif { defilement.arreter() }
    }

    /// Une image : le texte avance des points entiers que la vitesse a faits depuis la précédente.
    private func image(_ ecoule: TimeInterval) {
        // Une image en retard (une saccade, le retour d'une pause) ne fait pas sauter le texte.
        let pas = defilement.avancer(position: haut, ecoule: min(max(ecoule, 0), 0.1), fin: fin)
        guard pas.position != haut else { return }
        haut = pas.position
        position.scrollTo(y: CGFloat(pas.position))
    }
}

extension View {
    /// Le défilement automatique de ce ScrollView, par sa `ScrollPosition`.
    func defilementAutomatique(_ defilement: DefilementAuto, position: Binding<ScrollPosition>) -> some View {
        modifier(DefilementMoteur(defilement: defilement, position: position))
    }
}

/// L'écran qui ne s'éteint pas (FLAG_KEEP_SCREEN_ON d'Android) : allumé tant qu'un écran le demande
/// (`EcranAllumeDemandes`, cible Ecrans) ; la dernière demande retirée, la veille du téléphone reprend.
@MainActor
enum EcranAllume {
    static func garder(_ allume: Bool, pour qui: String) {
        let reste = EcranAllumeDemandes.app.garder(allume, pour: qui)
        #if canImport(UIKit)
        if UIApplication.shared.isIdleTimerDisabled != reste {
            UIApplication.shared.isIdleTimerDisabled = reste
        }
        #endif
    }
}

// MARK: L'écran allumé pendant qu'on lit

/// VeilleLecture.kt à l'écran (FLECTURE-01), sur un écran de lecture entier : chaque toucher (`ToucherDuTexte`, la
/// barre comprise, comme onUserInteraction), l'apparition de l'écran et son retour au premier plan repoussent la
/// veille de dix minutes, si le réglage le veut ; son départ la relâche. Le défilement automatique qui s'arrête
/// compte comme un toucher. L'écran allumé se demande à `EcranAllume`, sous le nom de cette veille.
struct VeilleLectureVue: ViewModifier {
    let veille: VeilleLecture
    /// Le texte défile tout seul : son arrêt repousse la veille.
    let defilant: Bool

    @Environment(\.scenePhase) private var phase
    /// Change à chaque toucher : la tâche qui attend l'échéance repart.
    @State private var jeton = 0

    func body(content: Content) -> some View {
        content
            #if canImport(UIKit)
            .gesture(ToucherDuTexte { toucher() })
            #endif
            .onAppear { toucher() }
            .onChange(of: phase) { _, nouvelle in
                switch nouvelle {
                case .active: toucher()
                case .background: relacher()
                default: break
                }
            }
            .onChange(of: defilant) { _, actif in
                if !actif { toucher() }
            }
            // Le réglage changé ailleurs : la veille suit aussitôt.
            .onChange(of: veille.permise) {
                toucher()
            }
            .onDisappear { relacher() }
            .task(id: jeton) {
                await attendre()
            }
    }

    private var demandeur: String {
        "veille-" + String(UInt(bitPattern: ObjectIdentifier(veille).hashValue))
    }

    private static func maintenant() -> Int64 {
        Int64((Date().timeIntervalSince1970 * 1000).rounded())
    }

    private func toucher() {
        veille.toucher(VeilleLectureVue.maintenant())
        jeton &+= 1
    }

    private func relacher() {
        veille.arreter()
        EcranAllume.garder(false, pour: demandeur)
    }

    /// Allumé jusqu'à l'échéance du dernier toucher, puis la veille du téléphone ; un toucher entre-temps relance.
    private func attendre() async {
        let debut = VeilleLectureVue.maintenant()
        guard let jusqua = veille.jusqua, veille.allume(debut) else {
            EcranAllume.garder(false, pour: demandeur)
            return
        }
        EcranAllume.garder(true, pour: demandeur)
        try? await Task.sleep(for: .milliseconds(jusqua - debut))
        guard !Task.isCancelled else { return }
        EcranAllume.garder(veille.allume(VeilleLectureVue.maintenant()), pour: demandeur)
    }
}

extension View {
    /// L'écran allumé pendant qu'on lit (VeilleLecture.kt), sur la racine d'un écran de lecture.
    func veilleDeLecture(_ veille: VeilleLecture, defilant: Bool) -> some View {
        modifier(VeilleLectureVue(veille: veille, defilant: defilant))
    }
}

#if canImport(UIKit)
/// Un doigt posé sur le texte, où que ce soit : `toucher` est appelé dès l'appui, puis le geste échoue aussitôt et
/// laisse le toucher aux boutons, aux liens et au défilement, sans rien retarder ni annuler (IndicateurDefilement
/// d'Android, qui voit passer chaque appui et le rend).
struct ToucherDuTexte: UIGestureRecognizerRepresentable {
    let toucher: @MainActor () -> Void

    func makeUIGestureRecognizer(context: Context) -> Reconnaisseur {
        let reconnaisseur = Reconnaisseur()
        reconnaisseur.cancelsTouchesInView = false
        reconnaisseur.delaysTouchesBegan = false
        reconnaisseur.delaysTouchesEnded = false
        reconnaisseur.toucher = toucher
        return reconnaisseur
    }

    func updateUIGestureRecognizer(_ reconnaisseur: Reconnaisseur, context: Context) {
        reconnaisseur.toucher = toucher
    }

    /// Jamais appelé : le geste n'est jamais reconnu.
    func handleUIGestureRecognizerAction(_ reconnaisseur: Reconnaisseur, context: Context) {}

    final class Reconnaisseur: UIGestureRecognizer {
        var toucher: (@MainActor () -> Void)?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            toucher?()
            // Jamais reconnu : rien n'attend ce geste, rien ne lui cède.
            state = .failed
        }
    }
}
#endif

// MARK: Le bouton de la barre

/// ▶︎ dans la barre de lecture : le texte défile ; ❚❚ : il s'arrête.
struct DefilementBouton: View {
    let defilement: DefilementAuto
    /// La largeur du bouton dans la barre du siddour (30 à 44) ; nil : de 30 à 44 selon la place (Tehilim).
    let cote: CGFloat?

    @Environment(\.traducteur) private var traducteur

    var body: some View {
        Button {
            defilement.basculer()
        } label: {
            Image(systemName: defilement.actif ? "pause.fill" : "play.fill")
                .font(Font.body.weight(.medium))
                .foregroundStyle(Teinte(.onBrand))
                .frame(width: 34, height: 34)
                .background {
                    // En marche, le bouton est cerclé, comme la lune la nuit.
                    Circle().fill(Teinte(.onBrand).opacity(defilement.actif ? 0.25 : 0))
                }
                .frame(width: cote, height: 44)
                .frame(minWidth: cote == nil ? 30 : nil, maxWidth: cote == nil ? 44 : nil)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(defilement.libelleBouton, traducteur: traducteur))
    }
}

// MARK: La commande flottante

/// [−] [N] [+] [❚❚], au-dessus du bouton de lecture tant que le texte défile. Toujours de gauche à droite, comme
/// A− et A+.
struct DefilementCommande: View {
    let defilement: DefilementAuto

    @Environment(\.traducteur) private var traducteur

    var body: some View {
        HStack(spacing: 0) {
            touche("minus", cle: "lecture_moins_vite", actif: defilement.moinsViteActif) {
                moinsVite()
            }
            Text(verbatim: String(defilement.niveau))
                .font(Font.subheadline.bold())
                .monospacedDigit()
                .foregroundStyle(Teinte(.onBrand))
                .frame(minWidth: 28, minHeight: 44)
                .accessibilityLabel(Text(defilement.libelleVitesse, traducteur: traducteur))
                .accessibilityAdjustableAction { sens in
                    if sens == .increment {
                        plusVite()
                    } else if sens == .decrement {
                        moinsVite()
                    }
                }
            touche("plus", cle: "lecture_plus_vite", actif: defilement.plusViteActif) {
                plusVite()
            }
            Rectangle()
                .fill(Teinte(.onBrand).opacity(0x55 / 255.0))
                .frame(width: 1, height: 22)
                .padding(.horizontal, 4)
                .accessibilityHidden(true)
            touche("pause.fill", cle: "lecture_defiler_pause", actif: true) {
                defilement.arreter()
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 44)
        .background(Teinte(.brand).opacity(0xF2 / 255.0), in: Capsule())
        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(Libelle("lecture_defiler"), traducteur: traducteur))
    }

    private func touche(_ symbole: String, cle: String, actif: Bool,
                        action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbole)
                .font(Font.subheadline.weight(.semibold))
                .foregroundStyle(Teinte(.onBrand))
                .opacity(actif ? 1 : 0.4)
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!actif)
        .accessibilityLabel(Text(Libelle(cle), traducteur: traducteur))
    }

    private func plusVite() {
        let defilement = self.defilement
        Task { _ = try? await defilement.plusVite() }
    }

    private func moinsVite() {
        let defilement = self.defilement
        Task { _ = try? await defilement.moinsVite() }
    }
}
