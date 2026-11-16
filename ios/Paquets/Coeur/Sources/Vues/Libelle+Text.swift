import Foundation
import SwiftUI
import Coeur
import Ecrans

// Les chaînes que rendent les modèles d'écran : un `Libelle` (la clé d'Android et ses arguments), résolu dans la
// langue de l'app par le `Traducteur` d'Ecrans, que la vue racine pose dans l'environnement. Une clé simple,
// sans argument, s'écrit directement `Text("cle")` : le catalogue compilé du paquet de l'app la traduit.

extension Text {
    /// Le texte d'un libellé dans la langue du traducteur (`getString`, `getQuantityString` d'Android) ; sa clé
    /// si rien ne se résout. Le texte est montré tel quel : il n'est pas relu comme une clé du catalogue.
    public init(_ libelle: Libelle, traducteur: Traducteur) {
        self.init(verbatim: traducteur.texte(libelle))
    }
}

private struct CleTraducteur: EnvironmentKey {
    /// Sans traducteur posé (un aperçu) : aucun gabarit, chaque libellé montre sa clé, ce qui se voit.
    static let defaultValue = Traducteur(langue: "en", simples: [:])
}

extension EnvironmentValues {
    /// Le traducteur de l'app, posé par la vue racine.
    public var traducteur: Traducteur {
        get { self[CleTraducteur.self] }
        set { self[CleTraducteur.self] = newValue }
    }
}

/// Un libellé résolu par le traducteur de l'environnement : `TexteLibelle(modele.titre)`. Là où il faut un
/// `Text` (concaténation, `Label`), lire le traducteur avec `@Environment(\.traducteur)` et écrire
/// `Text(libelle, traducteur:)`.
public struct TexteLibelle: View {
    @Environment(\.traducteur) private var traducteur
    private let libelle: Libelle

    public init(_ libelle: Libelle) {
        self.libelle = libelle
    }

    public var body: some View {
        Text(libelle, traducteur: traducteur)
    }
}
