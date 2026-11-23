import Coeur
import Ecrans
import Foundation
import SwiftUI

// Ce que les widgets lisent (tâche 25, PORTAGE.md § 2.2.3) : le journal et les réglages que l'app écrit dans le
// conteneur du groupe d'apps (Depot, en lecture), la langue de l'app et ses catalogues (Chaines/, copiés dans
// l'extension), la palette choisie (palettes.json). Rien d'autre ne passe de l'app aux widgets : ils calculent
// comme elle, avec Coeur, à l'heure où WidgetKit les redemande.

/// L'état lu pour un dessin.
struct EtatWidgets: Sendable {
    let journal: Journal
    let reglages: Reglages
    /// Le fuseau du téléphone.
    let fuseau: Fuseau
    let maintenant: Int64
    /// Les réglages ont été lus dans le conteneur du groupe (faux sans signature, ou avant tout lancement).
    let lu: Bool

    var aujourdhui: JourCivil { fuseau.jour(millis: maintenant) }
    var fuseauTelephone: String { fuseau.identifiant }

    static func lire(_ date: Date = Date()) async -> EtatWidgets {
        let fuseau = Fuseau(TimeZone.current.identifier) ?? .utc
        let maintenant = Int64((date.timeIntervalSince1970 * 1000).rounded())
        guard let dossier = DossierApp.partage else {
            return EtatWidgets(journal: Journal(), reglages: Reglages(), fuseau: fuseau, maintenant: maintenant, lu: false)
        }
        let depot = Depot(dossier: dossier)
        let journal = (try? await depot.journal()) ?? Journal()
        let reglages = (try? await depot.reglages()) ?? Reglages()
        return EtatWidgets(journal: journal, reglages: reglages, fuseau: fuseau, maintenant: maintenant, lu: true)
    }
}

/// La langue et les textes de l'app, lus une fois par processus.
enum TextesWidgets {
    static let traducteur: Traducteur = {
        let langue = DossierApp.langue ?? Traducteur.langueDuTelephone(Locale.preferredLanguages)
        let chaines = Bundle.main.bundleURL.appending(path: "Chaines")
        let catalogues = ["Localizable.xcstrings", "ios.xcstrings"].compactMap { nom in
            try? Data(contentsOf: chaines.appending(path: nom))
        }
        return (try? Traducteur(catalogues: catalogues, langue: langue)) ?? Traducteur(langue: langue, simples: [:])
    }()

    static func texte(_ libelle: Libelle) -> String {
        traducteur.texte(libelle)
    }

    static func texte(_ cle: String) -> String {
        traducteur.texte(Libelle(cle))
    }

    static var deDroiteAGauche: Bool {
        Traducteur.deDroiteAGauche(traducteur.langue)
    }

    static var locale: Locale {
        Locale(identifier: Traducteur.identifiantLocale(traducteur.langue))
    }

    /// Un texte et un minuteur au milieu (« encore 1:23 », « widget_reste ») : le gabarit est coupé autour de
    /// l'argument, le minuteur de SwiftUI vit entre les deux.
    static func autour(_ cle: String) -> (avant: String, apres: String) {
        let marque = "\u{FFFC}"
        let entier = traducteur.texte(Libelle(cle, .texte(marque)))
        guard let place = entier.range(of: marque) else { return (entier + " ", "") }
        return (String(entier[..<place.lowerBound]), String(entier[place.upperBound...]))
    }
}

/// Les couleurs choisies (VignetteDecor, StreakWidget.Teintes) : la palette de palettes.json, celle d'origine sans
/// elle.
enum CouleursWidgets {
    static let palettes: Palettes? = {
        guard let url = Bundle.main.url(forResource: "palettes", withExtension: "json"),
              let donnees = try? Data(contentsOf: url) else { return nil }
        return try? Palettes.lire(donnees)
    }()

    /// La palette des réglages, de jour ou de nuit ; nil sans palettes.json.
    static func palette(_ reglages: Reglages, nuit: Bool) -> Palette? {
        let apparence = ApparenceChoisie(reglages)
        return palettes?.palette(fond: apparence.fond, accent: apparence.accent, nuit: nuit)
    }

    static func couleur(_ c: Couleur) -> Color {
        Color(.sRGB, red: Double(c.rouge) / 255, green: Double(c.vert) / 255, blue: Double(c.bleu) / 255, opacity: 1)
    }

    static func couleur(_ argb: UInt32) -> Color {
        Color(.sRGB, red: Double((argb >> 16) & 0xFF) / 255, green: Double((argb >> 8) & 0xFF) / 255,
              blue: Double(argb & 0xFF) / 255, opacity: Double((argb >> 24) & 0xFF) / 255)
    }

    // Le fond de nuit verte des vignettes des zmanim et leurs encres (ZmanimVignette.kt, bg_widget_zmanim).
    static let nuitVerte = Color(.sRGB, red: 0x12 / 255, green: 0x33 / 255, blue: 0x2A / 255, opacity: 1)
    static let nuitVerteFoncee = Color(.sRGB, red: 0x0A / 255, green: 0x1F / 255, blue: 0x19 / 255, opacity: 1)
    /// FORT : le blanc à 95 %.
    static let fort = couleur(0xF2FF_FFFF)
    /// Le blanc à 65 % des libellés à venir.
    static let doux = couleur(0xA6FF_FFFF)
    /// PASSE : le blanc à 35 %.
    static let passe = couleur(0x59FF_FFFF)
    /// MENTHE.
    static let menthe = couleur(0xFF9F_E3CC)
    /// Les anneaux sur fond sombre (ring_week_on_dark, ring_streak_on_dark).
    static let semaine = couleur(0xFF8C_CBF2)
    static let serie = couleur(0xFFF0_C46A)
}

/// L'heure d'un instant à l'heure d'un fuseau, « HH:mm » (ZmanimVignette.HEURE).
func heureMinute(_ millis: Int64, _ fuseau: Fuseau) -> String {
    let h = fuseau.dateHeure(millis: millis)
    return (h.heure < 10 ? "0" : "") + String(h.heure) + ":" + (h.minute < 10 ? "0" : "") + String(h.minute)
}

func date(_ millis: Int64) -> Date {
    Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
}
