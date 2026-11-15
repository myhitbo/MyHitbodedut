import Foundation
import Coeur

// Ce que la boussole de Jérusalem demande au système (BoussoleActivity.kt) et que les fondations n'ont pas
// (Services.swift) : le capteur d'orientation, la question « la localisation est-elle déjà permise ? » sans
// rien demander, et le rafraîchissement du widget de la boussole. Des protocoles sans API d'Apple, que le
// modèle reçoit ; leurs adaptateurs viendront dans ios/App/Services/ (CoreMotion, CoreLocation, WidgetKit) ;
// leurs faux, ci-dessous, servent aux tests et aux aperçus.

// MARK: Le capteur d'orientation

/// La précision du magnétomètre (`SensorManager.SENSOR_STATUS_*` d'Android ; sur iOS
/// `CMMagneticFieldCalibrationAccuracy`, ou le `headingAccuracy` de `CLHeading`).
public enum BoussolePrecision: Sendable, Hashable, CaseIterable {
    /// SENSOR_STATUS_UNRELIABLE ou NO_CONTACT ; `.uncalibrated`, un `headingAccuracy` négatif.
    case nonFiable
    /// SENSOR_STATUS_ACCURACY_LOW ; `.low`.
    case basse
    /// SENSOR_STATUS_ACCURACY_MEDIUM ; `.medium`.
    case moyenne
    /// SENSOR_STATUS_ACCURACY_HIGH ; `.high`.
    case haute

    /// La boussole est à calibrer (« dessinez un 8 ») : au plus SENSOR_STATUS_ACCURACY_LOW
    /// (BoussoleActivity.onAccuracyChanged).
    public var aCalibrer: Bool {
        self == .nonFiable || self == .basse
    }
}

/// Une mesure du capteur d'orientation, toujours depuis le nord **magnétique** : le modèle y ajoute la
/// déclinaison du lieu des zmanim (Magnetisme, WMM2025), comme Android y ajoute celle de `GeomagneticField`.
public enum BoussoleMesure: Sendable, Hashable {
    /// La matrice de rotation Est-Nord-Haut ← écran : neuf Float, ligne par ligne, déjà ramenée au haut de
    /// l'écran tel qu'il est affiché (le `remapCoordinateSystem` d'Android). Le modèle en tire le cap par
    /// `Boussole.capDevant`, qui tient le téléphone à plat comme droit (bug du 02/11, RepriseBoussoleTest).
    /// C'est la mesure à préférer : CoreMotion (`xMagneticNorthZVertical`) la donne.
    case orientation([Float])
    /// Un cap déjà calculé, en degrés depuis le nord magnétique, dans le sens des aiguilles
    /// (`CLHeading.magneticHeading`) : pour un adaptateur qui n'aurait pas la matrice.
    case cap(Double)
    /// La précision du magnétomètre a changé (onAccuracyChanged).
    case precision(BoussolePrecision)
}

/// Le capteur d'orientation du téléphone (`CMMotionManager` dans l'app ; `SensorManager` sur Android).
public protocol BoussoleCapteur: Sendable {
    /// Le téléphone a-t-il de quoi trouver le nord (BoussoleActivity.aBoussole) ? Sans rien démarrer.
    func disponible() async -> Bool
    /// Les mesures, de l'appel jusqu'à la fin du flux : la tâche qui le lit est annulée (l'écran s'en va) ou
    /// l'adaptateur le termine. L'adaptateur démarre le capteur à l'appel et l'arrête à la fin du flux
    /// (`onTermination`), comme `registerListener` et `unregisterListener` d'Android.
    func mesures() async -> AsyncStream<BoussoleMesure>
}

/// Un capteur qui envoie ce qu'on lui dit d'envoyer, à chaque flux encore ouvert.
public actor BoussoleFauxCapteur: BoussoleCapteur {
    private let present: Bool
    private var suites: [AsyncStream<BoussoleMesure>.Continuation] = []
    /// Les flux demandés (`mesures()`), fermés compris.
    public private(set) var abonnements = 0

    public init(disponible: Bool = true) {
        present = disponible
    }

    public func disponible() -> Bool {
        present
    }

    public func mesures() -> AsyncStream<BoussoleMesure> {
        let (flux, suite) = AsyncStream.makeStream(of: BoussoleMesure.self)
        suites.append(suite)
        abonnements += 1
        return flux
    }

    /// Envoie la mesure à chaque flux encore ouvert ; rend le nombre de flux qui l'ont reçue.
    @discardableResult
    public func envoyer(_ mesure: BoussoleMesure) -> Int {
        var ouvertes: [AsyncStream<BoussoleMesure>.Continuation] = []
        for suite in suites {
            if case .terminated = suite.yield(mesure) { continue }
            ouvertes.append(suite)
        }
        suites = ouvertes
        return ouvertes.count
    }

    /// Termine tous les flux ouverts (le capteur s'est arrêté).
    public func terminer() {
        for suite in suites {
            suite.finish()
        }
        suites = []
    }
}

// MARK: La localisation déjà permise

/// La question que ChoixLieu pose avant de reprendre la position sans bruit, à l'ouverture de l'écran
/// (`localisationPermise`) : la `Localisation` des fondations, elle, demande l'autorisation si iOS ne l'a pas
/// encore demandée, ce que la reprise silencieuse ne doit jamais faire.
public protocol BoussoleAutorisationLieu: Sendable {
    /// La localisation, approximative ou exacte, est-elle déjà permise ? Sans rien demander
    /// (`CLLocationManager.authorizationStatus` dans l'app).
    func localisationPermise() async -> Bool
}

/// Une autorisation fixée d'avance, qui compte les questions.
public actor BoussoleFausseAutorisationLieu: BoussoleAutorisationLieu {
    private let permise: Bool
    public private(set) var questions = 0

    public init(permise: Bool) {
        self.permise = permise
    }

    public func localisationPermise() -> Bool {
        questions += 1
        return permise
    }
}

// MARK: Le widget de la boussole

/// Le widget de la boussole suit le lieu et la méthode (BoussoleWidget.refresh, appelé par l'écran) :
/// `WidgetCenter.reloadTimelines(ofKind:)` dans l'app.
public protocol BoussoleRafraichissement: Sendable {
    func rafraichir() async
}

/// Un rafraîchissement qui ne fait que compter.
public actor BoussoleFauxRafraichissement: BoussoleRafraichissement {
    public private(set) var rafraichissements = 0

    public init() {}

    public func rafraichir() {
        rafraichissements += 1
    }
}
