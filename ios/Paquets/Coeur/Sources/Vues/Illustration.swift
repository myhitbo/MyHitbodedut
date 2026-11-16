import Foundation
import SwiftUI
import UIKit
import Coeur
import Ecrans

/// Une illustration d'Android (`R.drawable.x`, un WebP de `drawable-nodpi`), par son nom : « char_welcome ».
/// Les images sont dans le paquet de l'app sous `Images/` (ios/Ressources/Images, copiées par l'export).
///
/// Le personnage passe par l'apparence de l'environnement (`ApparenceChoisie.image`, `Personnage.pour`) : qui a
/// choisi צדקת voit la pose féminine, comme le PersonnageViewInflater d'Android. L'image garde ses proportions
/// dans la place qu'on lui donne ; elle ne se retourne pas en hébreu (les dessins d'Android ne le font pas).
///
/// Une illustration qui dit quelque chose porte son libellé ; une illustration d'ornement est décorative, et
/// VoiceOver la passe (`importantForAccessibility="no"` d'Android).
public struct Illustration: View {
    @Environment(\.apparence) private var apparence
    private let nom: String
    private let libelle: Text?
    private let hauteur: CGFloat?

    /// Une illustration qui dit quelque chose : `libelle` est lu par VoiceOver.
    public init(_ nom: String, libelle: Text, hauteur: CGFloat? = nil) {
        self.nom = nom
        self.libelle = libelle
        self.hauteur = hauteur
    }

    /// Une illustration d'ornement, que VoiceOver passe.
    public init(decorative nom: String, hauteur: CGFloat? = nil) {
        self.nom = nom
        libelle = nil
        self.hauteur = hauteur
    }

    public var body: some View {
        if let image = Illustration.image(apparence.image(nom)) {
            let dessin = Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(height: hauteur)
            if let libelle {
                dessin.accessibilityLabel(libelle)
            } else {
                dessin.accessibilityHidden(true)
            }
        } else {
            // Une image absente du paquet (un export incomplet) laisse sa place vide plutôt que d'arrêter l'app.
            Color.clear
                .frame(height: hauteur)
                .accessibilityHidden(true)
        }
    }

    /// L'image `Images/<nom>.webp` du paquet de l'app ; iOS lit le WebP (ImageIO).
    private static func image(_ nom: String) -> UIImage? {
        guard let chemin = Bundle.main.path(forResource: nom, ofType: "webp", inDirectory: "Images") else {
            return nil
        }
        return UIImage(contentsOfFile: chemin)
    }
}

private struct CleApparence: EnvironmentKey {
    static let defaultValue = ApparenceChoisie()
}

extension EnvironmentValues {
    /// L'apparence tirée des réglages (fond, accent, mode, adresse), posée par la vue racine : les illustrations
    /// y lisent l'adresse qui choisit le personnage.
    public var apparence: ApparenceChoisie {
        get { self[CleApparence.self] }
        set { self[CleApparence.self] = newValue }
    }
}
