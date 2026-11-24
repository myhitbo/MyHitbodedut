import CoreLocation
import Ecrans
import Foundation

/// Le capteur d'orientation de la boussole (BoussoleActivity.kt, `SensorManager` d'Android) : le cap de
/// `CLHeading`, depuis le nord **magnétique** (`magneticHeading`), envoyé comme `BoussoleMesure.cap` ; le modèle y
/// ajoute la déclinaison du lieu (Magnetisme, WMM2025), comme Android y ajoute celle de `GeomagneticField`. La
/// précision suit `headingAccuracy` (négative : à calibrer).
///
/// Le cap magnétique ne demande aucune autorisation de localisation (seul le cap géographique, `trueHeading`, en
/// demanderait une). Le cap est celui du haut de l'écran tenu en portrait : l'écran de la boussole se tient droit
/// devant soi ou à plat.
///
/// Un gestionnaire par flux : il démarre à l'appel de `mesures()` et s'arrête à la fin du flux (la tâche qui le
/// lit est annulée), comme `registerListener` et `unregisterListener` d'Android.
@MainActor
final class SystemeBoussoleCapteur: BoussoleCapteur {

    /// Les gestionnaires des flux ouverts, par numéro de flux.
    private var ouverts: [Int: SystemeCapDelegue] = [:]
    private var prochain = 0

    init() {}

    func disponible() async -> Bool {
        CLLocationManager.headingAvailable()
    }

    func mesures() async -> AsyncStream<BoussoleMesure> {
        let (flux, suite) = AsyncStream.makeStream(of: BoussoleMesure.self)
        guard CLLocationManager.headingAvailable() else {
            suite.finish()
            return flux
        }
        prochain += 1
        let numero = prochain
        let delegue = SystemeCapDelegue(suite: suite)
        ouverts[numero] = delegue
        delegue.demarrer()
        suite.onTermination = { _ in
            Task { @MainActor [weak self] in
                self?.fermer(numero)
            }
        }
        return flux
    }

    private func fermer(_ numero: Int) {
        ouverts[numero]?.arreter()
        ouverts[numero] = nil
    }
}

/// Le gestionnaire d'un flux et son délégué : il pousse chaque cap et chaque changement de précision dans le flux.
@MainActor
final class SystemeCapDelegue: NSObject, CLLocationManagerDelegate {

    private let gestionnaire: CLLocationManager
    private let suite: AsyncStream<BoussoleMesure>.Continuation
    private var precision: BoussolePrecision?

    init(suite: AsyncStream<BoussoleMesure>.Continuation) {
        gestionnaire = CLLocationManager()
        self.suite = suite
        super.init()
        gestionnaire.headingFilter = 1
        gestionnaire.headingOrientation = .portrait
        gestionnaire.delegate = self
    }

    func demarrer() {
        gestionnaire.startUpdatingHeading()
    }

    func arreter() {
        gestionnaire.stopUpdatingHeading()
        gestionnaire.delegate = nil
    }

    fileprivate func recevoir(cap: Double, exactitude: Double) {
        let nouvelle = SystemeCapDelegue.precision(exactitude)
        if nouvelle != precision {
            precision = nouvelle
            suite.yield(.precision(nouvelle))
        }
        if cap >= 0 {
            suite.yield(.cap(cap))
        }
    }

    /// `headingAccuracy` (l'écart possible, en degrés) ramené aux paliers d'Android : négatif, le cap n'est pas
    /// fiable ; au-delà de 30°, basse ; de 15°, moyenne ; en deçà, haute.
    private static func precision(_ exactitude: Double) -> BoussolePrecision {
        if exactitude < 0 { return .nonFiable }
        if exactitude > 30 { return .basse }
        if exactitude > 15 { return .moyenne }
        return .haute
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let cap = newHeading.magneticHeading
        let exactitude = newHeading.headingAccuracy
        Task { @MainActor [weak self] in
            self?.recevoir(cap: cap, exactitude: exactitude)
        }
    }

    /// iOS montre lui-même l'écran de calibration quand il en a besoin ; l'app dit aussi « dessinez un 8 ».
    nonisolated func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }
}
