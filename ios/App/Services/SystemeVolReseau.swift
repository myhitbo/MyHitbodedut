import Coeur
import Ecrans
import Foundation

/// Ce qui lit une adresse pour l'écran du vol (`Reseau` et `SuiviVol.Relais` d'Android) : `URLSession`, en HTTPS
/// seulement, sans suivre de redirection (la réponse 3xx est rendue telle quelle), sans cache ni cookie, avec les
/// délais d'Android (20 s sans réponse). Rend le code HTTP et le corps, quel que soit le code ; lève sans connexion,
/// comme l'`IOException` de Kotlin.
struct SystemeVolReseau: VolReseau {

    /// Une adresse qui n'est pas en HTTPS : rien ne part.
    struct NonSecurisee: Error, Sendable {
        let adresse: String
    }

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 40
        configuration.waitsForConnectivity = false
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    func lire(_ adresse: String) async throws -> RouteVol.Reponse {
        guard let url = URL(string: adresse), url.scheme?.lowercased() == "https" else {
            throw NonSecurisee(adresse: adresse)
        }
        var requete = URLRequest(url: url)
        requete.timeoutInterval = 20
        requete.setValue("application/json", forHTTPHeaderField: "Accept")
        let (donnees, reponse) = try await session.data(for: requete, delegate: SystemeSansRedirection())
        let code = (reponse as? HTTPURLResponse)?.statusCode ?? 0
        return RouteVol.Reponse(code: code, corps: String(decoding: donnees, as: UTF8.self))
    }
}

/// Le délégué d'une requête du vol : aucune redirection n'est suivie (`instanceFollowRedirects = false`).
final class SystemeSansRedirection: NSObject, URLSessionTaskDelegate, Sendable {

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
