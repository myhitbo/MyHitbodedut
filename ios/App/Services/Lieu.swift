import CoreLocation
import Ecrans
import Foundation

// La position du téléphone (PORTAGE.md § 2.2.5), l'adaptateur de `Localisation` (Services.swift), de
// `LieuAutorisation` (LieuModele) et de `BoussoleAutorisationLieu` (BoussoleServices) sur CoreLocation :
// - pour les zmanim et la boussole (ChoixLieu.kt) : la position approximative, demandée seulement au toucher de
//   « Ma position » (ou reprise sans bruit quand elle est déjà permise), quand l'app est ouverte. Une position
//   connue de moins de deux minutes suffit ; sinon on attend 25 secondes au plus, puis on prend la dernière
//   connue. `NSLocationDefaultAccuracyReduced` fait proposer la position approximative par défaut, comme
//   ACCESS_COARSE_LOCATION ;
// - pour le vol (VolActivity.releverGps) : la position précise, sans réseau (l'iPhone garde le GPS en mode avion),
//   attendue 2 min 30 au plus, la précision complète demandée pour une fois (`requestTemporaryFullAccuracyAuthorization`,
//   clé « vol » de `NSLocationTemporaryUsageDescriptionDictionary`). Refusée : « Sans la localisation précise, le
//   calcul reste sur la route prévue. »
//
// Rien ne tourne en arrière-plan : l'app ne demande pas la localisation permanente.

/// Une demande de position, l'une après l'autre.
@MainActor
final class LieuSysteme: NSObject, Localisation, LieuAutorisation, BoussoleAutorisationLieu {

    enum Precision {
        /// Les zmanim, la boussole : au kilomètre près.
        case approchee
        /// Le relevé du vol : le GPS.
        case gps
    }

    /// ChoixLieu : une position de moins de deux minutes vaut une position fraîche…
    private static let fraicheur: TimeInterval = 120
    /// … si elle est à 5 km près (APPROCHE_M) : la position est arrondie au kilomètre, attendre mieux ne sert à rien.
    private static let approche: CLLocationAccuracy = 5_000
    /// ChoixLieu : 25 secondes ; VolActivity.GPS_MS : 2 min 30, le premier relevé sans réseau est long.
    private static func delai(_ precision: Precision) -> Duration {
        precision == .gps ? .seconds(150) : .seconds(25)
    }

    private let gestionnaire = CLLocationManager()
    private let precision: Precision
    private var attentesAutorisation: [CheckedContinuation<Void, Never>] = []
    private var attentePosition: CheckedContinuation<CLLocation?, Never>?
    private var debutReleve = Date.distantPast
    private var minuterie: Task<Void, Never>?

    init(precision: Precision) {
        self.precision = precision
        super.init()
        gestionnaire.delegate = self
        gestionnaire.desiredAccuracy = precision == .gps ? kCLLocationAccuracyBest : kCLLocationAccuracyKilometer
    }

    // MARK: Ce qui est permis, sans rien demander

    func localisationPermise() async -> Bool {
        LieuSysteme.permise(gestionnaire.authorizationStatus)
    }

    private static func permise(_ statut: CLAuthorizationStatus) -> Bool {
        statut == .authorizedWhenInUse || statut == .authorizedAlways
    }

    // MARK: La position

    func positionApprochee() async -> ReponseLocalisation {
        if gestionnaire.authorizationStatus == .notDetermined {
            await demanderAutorisation()
        }
        guard LieuSysteme.permise(gestionnaire.authorizationStatus) else { return .refusee }
        if precision == .gps, gestionnaire.accuracyAuthorization == .reducedAccuracy {
            await demanderPrecision()
            guard gestionnaire.accuracyAuthorization == .fullAccuracy else { return .refusee }
        }
        if precision == .approchee, let connue = gestionnaire.location,
           -connue.timestamp.timeIntervalSinceNow < LieuSysteme.fraicheur,
           connue.horizontalAccuracy >= 0, connue.horizontalAccuracy <= LieuSysteme.approche {
            return LieuSysteme.reponse(connue)
        }
        if let fraiche = await relever() {
            return LieuSysteme.reponse(fraiche)
        }
        // ChoixLieu.ancienne : faute de position fraîche, la dernière connue, et on le dit. Le vol veut un relevé de
        // maintenant.
        if precision == .approchee, let connue = gestionnaire.location {
            let age = Int64((-connue.timestamp.timeIntervalSinceNow * 1000).rounded())
            return .ancienne(PositionApprochee(latitude: connue.coordinate.latitude,
                                               longitude: connue.coordinate.longitude), age: max(age, 0))
        }
        return .indisponible
    }

    private static func reponse(_ lieu: CLLocation) -> ReponseLocalisation {
        .position(PositionApprochee(latitude: lieu.coordinate.latitude, longitude: lieu.coordinate.longitude))
    }

    /// La question d'iOS (« Autoriser une fois », « Pendant l'utilisation de l'app », « Ne pas autoriser ») ;
    /// rend la main quand la réponse est donnée.
    private func demanderAutorisation() async {
        await withCheckedContinuation { (suite: CheckedContinuation<Void, Never>) in
            attentesAutorisation.append(suite)
            if attentesAutorisation.count == 1 {
                gestionnaire.requestWhenInUseAuthorization()
            }
        }
    }

    private func demanderPrecision() async {
        await withCheckedContinuation { (suite: CheckedContinuation<Void, Never>) in
            gestionnaire.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "vol") { _ in
                suite.resume()
            }
        }
    }

    /// Une position relevée maintenant ; nil au bout du délai, ou si le relevé est refusé.
    private func relever() async -> CLLocation? {
        if attentePosition != nil { finir(nil) }
        return await withCheckedContinuation { (suite: CheckedContinuation<CLLocation?, Never>) in
            attentePosition = suite
            debutReleve = Date()
            gestionnaire.startUpdatingLocation()
            let delai = LieuSysteme.delai(precision)
            minuterie = Task { [weak self] in
                try? await Task.sleep(for: delai)
                guard !Task.isCancelled else { return }
                self?.finir(nil)
            }
        }
    }

    private func finir(_ lieu: CLLocation?) {
        minuterie?.cancel()
        minuterie = nil
        gestionnaire.stopUpdatingLocation()
        let suite = attentePosition
        attentePosition = nil
        suite?.resume(returning: lieu)
    }

    // MARK: Ce que dit CoreLocation

    fileprivate func autorisationChangee(_ statut: CLAuthorizationStatus) {
        guard statut != .notDetermined else { return }
        let attentes = attentesAutorisation
        attentesAutorisation = []
        for suite in attentes { suite.resume() }
    }

    fileprivate func positions(_ releves: [Releve]) {
        guard attentePosition != nil else { return }
        // Une position d'avant le relevé n'est pas un relevé (le GPS du vol, la fraîcheur de ChoixLieu).
        guard let releve = releves.last(where: { $0.instant >= debutReleve.addingTimeInterval(-1) && $0.precision >= 0 })
        else { return }
        finir(CLLocation(latitude: releve.latitude, longitude: releve.longitude))
    }

    fileprivate func echec(_ erreur: CLError.Code?) {
        // « Position inconnue pour l'instant » : CoreLocation continue de chercher, on attend encore.
        if erreur == .locationUnknown { return }
        if attentePosition != nil { finir(nil) }
    }
}

/// Une position reçue de CoreLocation, en valeurs qui passent d'un fil à l'autre.
struct Releve: Sendable {
    let latitude: Double
    let longitude: Double
    let instant: Date
    /// `horizontalAccuracy` : négative, la position n'est pas valable.
    let precision: Double
}

extension LieuSysteme: CLLocationManagerDelegate {
    // CoreLocation rappelle sur le fil où le gestionnaire est né : le fil principal.

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let statut = manager.authorizationStatus
        MainActor.assumeIsolated { autorisationChangee(statut) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let releves = locations.map {
            Releve(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude, instant: $0.timestamp,
                   precision: $0.horizontalAccuracy)
        }
        MainActor.assumeIsolated { positions(releves) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        let code = (error as? CLError)?.code
        MainActor.assumeIsolated { echec(code) }
    }
}
