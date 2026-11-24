import CoreLocation
import Ecrans
import Foundation

/// La position du téléphone (ChoixLieu.localiser d'Android) : `CLLocationManager`, en précision réduite, une fois.
/// Une position de l'ordre du kilomètre suffit aux zmanim et à la ville la plus proche (31/10) ; elle n'est
/// demandée qu'au moment où l'on choisit « Ma position », et reste sur l'appareil.
///
/// C'est aussi la question « la localisation est-elle déjà permise ? », posée sans rien demander, de l'écran du
/// lieu (`LieuAutorisation`) et de la boussole (`BoussoleAutorisationLieu`) : le même gestionnaire la connaît.
///
/// Comme Android : l'autorisation d'abord si iOS ne l'a pas encore demandée ; puis une position fraîche, attendue
/// 25 s au plus ; à défaut, la dernière position connue du système ; sinon « indisponible ». Une autorisation
/// refusée ou restreinte rend « refusée » : l'écran propose une ville.
///
/// Les rappels du délégué arrivent sur le fil principal, où le gestionnaire a été créé (CoreLocation les livre sur
/// la boucle du fil qui l'a créé) ; seules des valeurs partageables (`CLLocation`, une erreur) en sortent.
@MainActor
final class SystemeLocalisation: NSObject, Localisation, LieuAutorisation, BoussoleAutorisationLieu,
                                 CLLocationManagerDelegate {

    /// Le délai d'une position fraîche (ChoixLieu : 25 s).
    static let delai: Duration = .seconds(25)

    private let gestionnaire: CLLocationManager
    /// Ceux qui attendent la réponse d'iOS à la demande d'autorisation.
    private var attentesAutorisation: [CheckedContinuation<Void, Never>] = []
    /// Ceux qui attendent une position : une seule demande au système pour tous.
    private var attentesPosition: [CheckedContinuation<ReponseLocalisation, Never>] = []
    /// La minuterie de la demande en cours.
    private var minuterie: Task<Void, Never>?

    /// `reduite` : la précision réduite (de l'ordre du kilomètre), celle que l'app demande partout.
    init(reduite: Bool = true) {
        gestionnaire = CLLocationManager()
        super.init()
        gestionnaire.desiredAccuracy = reduite ? kCLLocationAccuracyReduced : kCLLocationAccuracyHundredMeters
        gestionnaire.delegate = self
    }

    // MARK: LieuAutorisation, BoussoleAutorisationLieu

    func localisationPermise() async -> Bool {
        SystemeLocalisation.permise(gestionnaire.authorizationStatus)
    }

    // MARK: Localisation

    func positionApprochee() async -> ReponseLocalisation {
        if gestionnaire.authorizationStatus == .notDetermined {
            await withCheckedContinuation { (suite: CheckedContinuation<Void, Never>) in
                attentesAutorisation.append(suite)
                if attentesAutorisation.count == 1 {
                    gestionnaire.requestWhenInUseAuthorization()
                }
            }
        }
        switch gestionnaire.authorizationStatus {
        case .notDetermined, .denied, .restricted:
            return .refusee
        default:
            break
        }
        return await withCheckedContinuation { (suite: CheckedContinuation<ReponseLocalisation, Never>) in
            attentesPosition.append(suite)
            if attentesPosition.count == 1 {
                demanderPosition()
            }
        }
    }

    private func demanderPosition() {
        gestionnaire.requestLocation()
        minuterie?.cancel()
        minuterie = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: SystemeLocalisation.delai)
            } catch {
                return
            }
            self?.repondre(nil)
        }
    }

    /// Rend la position à tous ceux qui l'attendent : `position`, sinon la dernière connue, sinon « indisponible ».
    private func repondre(_ position: CLLocation?) {
        guard !attentesPosition.isEmpty else { return }
        minuterie?.cancel()
        minuterie = nil
        let reponse: ReponseLocalisation
        if let lieu = position ?? gestionnaire.location {
            reponse = .position(PositionApprochee(latitude: lieu.coordinate.latitude,
                                                  longitude: lieu.coordinate.longitude))
        } else {
            reponse = .indisponible
        }
        let attentes = attentesPosition
        attentesPosition = []
        for attente in attentes {
            attente.resume(returning: reponse)
        }
    }

    private func autorisationChangee() {
        guard gestionnaire.authorizationStatus != .notDetermined, !attentesAutorisation.isEmpty else { return }
        let attentes = attentesAutorisation
        attentesAutorisation = []
        for attente in attentes {
            attente.resume()
        }
    }

    private static func permise(_ statut: CLAuthorizationStatus) -> Bool {
        statut == .authorizedWhenInUse || statut == .authorizedAlways
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            self?.autorisationChangee()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let derniere = locations.last
        Task { @MainActor [weak self] in
            self?.repondre(derniere)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor [weak self] in
            self?.repondre(nil)
        }
    }
}
