import AlarmKit
import Coeur
import Ecrans
import Foundation
import SwiftUI

// La minuterie système (tâche 17, PORTAGE.md § 2.2.1 ; la règle dans Ecrans/MinuterieSeance.swift) : une alarme
// d'AlarmKit à heure fixe, la fin d'une séance minutée, que le système fait sonner malgré le silencieux et la
// concentration. Seulement l'alerte (le titre et « Arrêter », que le système fournit) : ni décompte, qui ferait double
// avec la Live Activity de la séance et demanderait sa propre Live Activity dans l'extension des widgets, ni bouton de
// plus. L'app ne pose aucune autre alarme : retirer « l'alarme de la séance », c'est retirer toutes les siennes.
// Sans autorisation (NSAlarmKitUsageDescription), rien n'est posé.

/// Ce que l'alarme porte avec elle : rien.
struct AlarmeSeance: AlarmMetadata {}

struct MinuterieAlarmes: MinuterieSysteme {
    let traducteur: Traducteur

    /// La couleur de la marque (MARQUE de BoussoleDessin, colors.xml « brand ») : celle de l'alarme à l'écran.
    private static let teinte = Color(.sRGB, red: 0x16 / 255, green: 0x77 / 255, blue: 0x5A / 255, opacity: 1)

    func etat() async -> EtatMinuterie {
        switch AlarmManager.shared.authorizationState {
        case .authorized: .accordee
        case .notDetermined: .aDemander
        case .denied: .refusee
        @unknown default: .refusee
        }
    }

    func demanderAutorisation() async -> Bool {
        do {
            return try await AlarmManager.shared.requestAuthorization() == .authorized
        } catch {
            return false
        }
    }

    func poser(fin: Int64, titre: Libelle) async -> Bool {
        guard AlarmManager.shared.authorizationState == .authorized else { return false }
        await retirer()
        let alerte = AlarmPresentation.Alert(title: LocalizedStringResource(String.LocalizationValue(traducteur.texte(titre))))
        let attributs = AlarmAttributes<AlarmeSeance>(presentation: AlarmPresentation(alert: alerte), metadata: nil,
                                                      tintColor: MinuterieAlarmes.teinte)
        let heure = Date(timeIntervalSince1970: TimeInterval(fin) / 1000)
        let configuration = AlarmManager.AlarmConfiguration<AlarmeSeance>.alarm(schedule: .fixed(heure),
                                                                                attributes: attributs)
        do {
            _ = try await AlarmManager.shared.schedule(id: UUID(), configuration: configuration)
            return true
        } catch {
            return false
        }
    }

    func retirer() async {
        let alarmes = (try? AlarmManager.shared.alarms) ?? []
        for alarme in alarmes {
            try? AlarmManager.shared.cancel(id: alarme.id)
        }
    }
}
