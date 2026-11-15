// Les ambiances des séances (l'enum Ambiance d'Ambiance.kt) : leurs clés et leurs libellés, recopiés par
// programme du Kotlin, dans le même ordre. Le son (AmbianceSynth, AmbiancePlayer) reste à l'app : il se
// calcule et se joue avec AVAudioEngine (PORTAGE.md § 2.2.4). Aucune ambiance n'est un fichier.

/// Une ambiance sous la musique pendant la hitbodedout, ou le silence ; dans l'ordre de l'écran.
public enum Ambiance: String, Sendable, CaseIterable {
    case silence = "silence"
    case pluie = "pluie"
    case mer = "mer"
    case foret = "foret"
    case feu = "feu"
    case nuit = "nuit"

    /// La clé enregistrée dans les réglages (« ambiance »).
    public var cle: String { rawValue }

    /// La clé de son libellé dans le catalogue (R.string.x d'Android).
    public var titre: String {
        switch self {
        case .silence: return "ambiance_silence"
        case .pluie: return "ambiance_pluie"
        case .mer: return "ambiance_mer"
        case .foret: return "ambiance_foret"
        case .feu: return "ambiance_feu"
        case .nuit: return "ambiance_nuit"
        }
    }

    /// `Ambiance.of` : l'ambiance de cette clé ; une clé inconnue, vide ou absente rend le silence. La
    /// comparaison est celle de Kotlin, unité UTF-16 par unité.
    public static func of(_ cle: String?) -> Ambiance {
        guard let cle else { return .silence }
        return allCases.first { $0.cle.egalUnites(cle) } ?? .silence
    }
}
