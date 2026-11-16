import Coeur
import SwiftUI

/// L'app vide de la tâche 3 : elle prouve la chaîne, du dépôt à l'iPhone (recette R1).
/// Elle affiche sa version, son identifiant et le moteur de Coeur, preuve que le paquet est lié.
@main
struct MyHitbodedutApp: App {
    var body: some Scene {
        WindowGroup {
            Accueil()
        }
    }
}

struct Accueil: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("MyHitbodedut")
                .font(.largeTitle.bold())
            Text("Version \(valeur("CFBundleShortVersionString")) (\(valeur("CFBundleVersion")))")
            Text(Bundle.main.bundleIdentifier ?? "—")
                .font(.footnote.monospaced())
            Text(Zmanim.moteur)
                .font(.footnote)
                .foregroundStyle(.secondary)
            #if SANS_BARRIERE
            Text("Construction sans barrière")
                .font(.footnote)
                .foregroundStyle(.secondary)
            #endif
        }
        .multilineTextAlignment(.center)
        .padding()
    }

    private func valeur(_ cle: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: cle) as? String ?? "?"
    }
}
