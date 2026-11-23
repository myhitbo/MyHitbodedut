import Coeur
import CoreMotion
import Ecrans
import Foundation
import UIKit

// Les capteurs de la boussole de Jérusalem (BoussoleActivity.kt), l'adaptateur de `BoussoleCapteur`
// (BoussoleServices.swift) sur CoreMotion, et le rafraîchissement de son widget (BoussoleWidget.refresh).
//
// Android lit le vecteur de rotation, ou l'accéléromètre et le magnétomètre (`getRotationMatrix`). CoreMotion donne
// les deux d'un coup, filtrés par le gyroscope : la gravité et le champ magnétique calibré (`xMagneticNorthZVertical`,
// sans demander la localisation, PORTAGE.md § 2.2.5). La matrice se construit comme sur Android
// (`Boussole.matriceCoreMotion`), ramenée au haut de l'écran tel qu'il est affiché (`Boussole.remapper`) ; le
// modèle y ajoute la déclinaison du lieu (WMM2025) et lisse le cap. La précision du magnétomètre
// (`CMMagneticFieldCalibrationAccuracy`) devient celle d'Android : au plus basse, l'écran invite à dessiner un 8.

@MainActor
final class BoussoleCapteurSysteme: BoussoleCapteur {
    /// SENSOR_DELAY_UI : une vingtaine de mesures par seconde.
    private static let intervalle: TimeInterval = 1.0 / 20

    private let mouvement = CMMotionManager()
    private var suite: AsyncStream<BoussoleMesure>.Continuation?
    private var precision: BoussolePrecision?
    /// Chaque flux a son numéro : la fin d'un flux remplacé n'arrête pas le suivant.
    private var generation = 0

    func disponible() async -> Bool {
        mouvement.isDeviceMotionAvailable
            && CMMotionManager.availableAttitudeReferenceFrames().contains(.xMagneticNorthZVertical)
    }

    func mesures() async -> AsyncStream<BoussoleMesure> {
        arreter()
        generation += 1
        let numero = generation
        let (flux, suite) = AsyncStream.makeStream(of: BoussoleMesure.self, bufferingPolicy: .bufferingNewest(4))
        self.suite = suite
        precision = nil
        // unregisterListener : la tâche qui lit le flux est annulée (l'écran s'en va, l'app passe en arrière-plan).
        suite.onTermination = { [weak self] _ in
            Task { @MainActor in self?.terminer(numero) }
        }
        mouvement.deviceMotionUpdateInterval = BoussoleCapteurSysteme.intervalle
        mouvement.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { [weak self] mouvement, _ in
            guard let mouvement else { return }
            let gravite = [mouvement.gravity.x, mouvement.gravity.y, mouvement.gravity.z]
            let champ = mouvement.magneticField
            let valeurs = [champ.field.x, champ.field.y, champ.field.z]
            let calibrage = champ.accuracy.rawValue
            MainActor.assumeIsolated {
                self?.recevoir(gravite: gravite, champ: valeurs, calibrage: calibrage)
            }
        }
        return flux
    }

    private func recevoir(gravite: [Double], champ: [Double], calibrage: Int32) {
        guard let suite else { return }
        let nouvelle = BoussoleCapteurSysteme.precision(calibrage)
        if nouvelle != precision {
            precision = nouvelle
            suite.yield(.precision(nouvelle))
        }
        guard let matrice = Boussole.matriceCoreMotion(gravite: gravite, champ: champ) else { return }
        suite.yield(.orientation(Boussole.remapper(matrice, rotation: BoussoleCapteurSysteme.rotationEcran())))
    }

    private func terminer(_ numero: Int) {
        guard numero == generation else { return }
        arreter()
    }

    private func arreter() {
        mouvement.stopDeviceMotionUpdates()
        suite?.finish()
        suite = nil
    }

    /// `CMMagneticFieldCalibrationAccuracy` : -1 non calibré, puis basse, moyenne, haute.
    private static func precision(_ calibrage: Int32) -> BoussolePrecision {
        switch calibrage {
        case 0: .basse
        case 1: .moyenne
        case 2: .haute
        default: .nonFiable
        }
    }

    /// La rotation de l'affichage en quarts de tour (Surface.ROTATION_*) : paysage « à droite » (le haut du téléphone
    /// à gauche) est ROTATION_90.
    private static func rotationEcran() -> Int {
        let scene = UIApplication.shared.connectedScenes.lazy.compactMap { $0 as? UIWindowScene }.first
        switch scene?.effectiveGeometry.interfaceOrientation {
        case .landscapeRight: return 1
        case .portraitUpsideDown: return 2
        case .landscapeLeft: return 3
        default: return 0
        }
    }
}

/// BoussoleWidget.refresh : le widget suit le lieu et la méthode.
struct BoussoleRafraichissementSysteme: BoussoleRafraichissement {
    func rafraichir() async {
        await MainActor.run { RafraichissementWidgets.redessiner(GenresWidgets.boussole) }
    }
}
