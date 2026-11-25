import Coeur
import Ecrans
import Foundation
import ImageIO
import SwiftUI
import WidgetKit

// Ce que les widgets de la série et des zmanim partagent : la lecture de ce que l'app dépose dans le groupe d'apps
// (App/Services/SystemeWidgets.swift), les textes dans la langue de l'app, les couleurs choisies, le décor de la
// vignette (VignetteDecor), les liens qui ouvrent l'app.
//
// Le widget calcule lui-même ce qu'il montre, avec Coeur et Ecrans (VignetteSerie, VignetteZmanim, Chronologies) :
// l'app ne dépose que le journal et les réglages (une copie, par le Depot de Coeur) et sa langue. Ce qui change à
// heure dite (minuit, chaque zman, tsét) est dans la chronologie, sans réveiller l'app.

/// Ce que l'app a déposé, relu au moment de calculer une chronologie.
struct WidgetsDepot: Sendable {
    let journal: Journal
    let reglages: Reglages
    /// « fr », « en » ou « he » : la langue de l'app, celle de ses textes.
    let langue: String

    /// La copie du journal et des réglages (WidgetsPartage.dossier, dans le conteneur du groupe) ; un journal et des
    /// réglages neufs tant que l'app n'a rien déposé, ou si le groupe d'apps n'est pas accordé à la signature.
    static func lire() async -> WidgetsDepot {
        let langue = WidgetsDepot.langue()
        guard let conteneur = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WidgetsPartage.groupe) else {
            return WidgetsDepot(journal: Journal(), reglages: Reglages(), langue: langue)
        }
        let depot = Depot(dossier: conteneur.appending(path: WidgetsPartage.dossier, directoryHint: .isDirectory))
        var journal = Journal()
        var reglages = Reglages()
        do {
            journal = try await depot.journal()
            reglages = try await depot.reglages()
        } catch {
            // Un fichier illisible est mis de côté par le dépôt ; le widget montre l'état neuf jusqu'au prochain dépôt.
        }
        return WidgetsDepot(journal: journal, reglages: reglages, langue: langue)
    }

    /// La langue déposée par l'app ; avant le premier dépôt, celle du téléphone ramenée à fr, en ou he.
    static func langue() -> String {
        if let deposee = UserDefaults(suiteName: WidgetsPartage.groupe)?.string(forKey: WidgetsPartage.langue) {
            return Traducteur.langueApp(deposee)
        }
        return Traducteur.langueApp(Locale.preferredLanguages.first)
    }
}

/// Les ressources livrées dans l'extension (projet-commun.yml, cible Widgets) : le catalogue d'Android sous Chaines/,
/// les illustrations sous Images/, palettes.json et chizuk.json.
enum WidgetsRessources {

    static var paquet: URL { Bundle.main.bundleURL }

    /// Le traducteur des `Libelle` dans `langue`. Sans catalogue lisible, chaque libellé montre sa clé (comme l'app).
    static func traducteur(_ langue: String) -> Traducteur {
        let fichier = paquet.appending(path: "Chaines/Localizable.xcstrings", directoryHint: .notDirectory)
        if let catalogue = try? Data(contentsOf: fichier),
           let traducteur = try? Traducteur(catalogue: catalogue, langue: langue) {
            return traducteur
        }
        return Traducteur(langue: langue, simples: [:])
    }

    /// Les 72 palettes ; nil si le fichier manque (le widget prend alors ses couleurs d'origine).
    static func palettes() -> Palettes? {
        guard let url = Bundle.main.url(forResource: "palettes", withExtension: "json"),
              let donnees = try? Data(contentsOf: url) else { return nil }
        return try? Palettes.lire(donnees)
    }

    /// Les textes de ’hizouk ; nil s'ils manquent.
    static func chizuk() -> Chizuk? {
        guard let url = Bundle.main.url(forResource: "chizuk", withExtension: "json"),
              let donnees = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Chizuk.self, from: donnees)
    }

    /// Une illustration d'Android (Images/<nom>.webp), réduite à la lecture : les originaux font 900 px de haut, et
    /// un widget n'a que quelques dizaines de mégaoctets de mémoire.
    static func image(_ nom: String, cotePixels: Int) -> CGImage? {
        let url = paquet.appending(path: "Images/\(nom).webp", directoryHint: .notDirectory)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(cotePixels, 64),
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

/// Le fuseau du téléphone (le widget vit sur iOS : il le lit ici, et le passe aux règles).
enum WidgetsHorloge {
    static var fuseau: Fuseau { Fuseau(TimeZone.current.identifier) ?? .utc }

    static func millis(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }

    static func date(_ millis: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
    }
}

/// Les liens profonds de l'app (App/Liens.swift a les mêmes).
enum WidgetsLiens {
    static let accueil = URL(string: "myhitbodedut://aujourdhui")
    static let seance = URL(string: "myhitbodedut://seance")
    static let commencer = URL(string: "myhitbodedut://commencer")
    static let zmanim = URL(string: "myhitbodedut://zmanim")

    static func url(_ destination: VignetteSerie.Destination) -> URL? {
        switch destination {
        case .accueil: accueil
        // « Terminer » est une intention, pas un lien (WidgetsSerie.swift, SerieBouton) ; à défaut, l'écran de séance.
        case .seance, .terminer: seance
        case .commencer: commencer
        }
    }
}

// MARK: - Les couleurs

extension Color {
    /// Un jeton de la palette.
    init(_ couleur: Couleur) {
        self.init(red: Double(couleur.rouge) / 255, green: Double(couleur.vert) / 255, blue: Double(couleur.bleu) / 255)
    }

    /// Un entier 0xRRGGBB, opaque.
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Les couleurs de la vignette de la série (StreakWidget.Teintes) : la couleur des boutons choisie, en dégradé, et
/// des jetons fixes de la palette, qui ne basculent pas la nuit (day_done, brand_dark, mint, stage_soft, on_plate).
/// La nuit, le dégradé fonce (VignetteDecor.degrade).
struct WidgetsTeintes: Sendable {
    let clair: Color
    let fonce: Color
    /// Les chiffres, le temps, le texte du jour.
    let encre: Color
    /// Les libellés : la couleur claire de la palette.
    let douce: Color
    /// Le bouton : une pastille claire, et son encre.
    let pastille: Color
    let surPastille: Color
    let jourFait: Color
    let surJourFait: Color
    /// La flamme allumée, et l'anneau de la série (ring_streak_on_dark).
    let flamme: Color
    /// L'anneau de la semaine (ring_week_on_dark).
    let semaine: Color
    /// La plaque claire sous le hassid.
    let plaque: Color

    /// ring_streak_on_dark et ring_week_on_dark d'Android (values/colors.xml), qui ne sont pas dans palettes.json.
    static let serieSurFonce: UInt32 = 0xF0C46A
    static let semaineSurFonce: UInt32 = 0x8CCBF2

    /// `palette` : celle des réglages, de jour ou de nuit selon `nuit` ; nil sans palettes.json, et le widget prend le
    /// vert d'origine.
    init(palette: Palette?, nuit: Bool) {
        let semaine = Color(hex: WidgetsTeintes.semaineSurFonce)
        let serie = Color(hex: WidgetsTeintes.serieSurFonce)
        guard let palette else {
            clair = Color(hex: 0x2E7D6B)
            fonce = Color(hex: 0x0F3F36)
            encre = .white
            douce = Color(hex: 0x9FE3CC)
            pastille = Color(hex: 0xE8F3EF)
            surPastille = Color(hex: 0x0F3F36)
            jourFait = Color(hex: 0x9FE3CC)
            surJourFait = Color(hex: 0x0F3F36)
            flamme = serie
            self.semaine = semaine
            plaque = Color(hex: 0xE8F3EF)
            return
        }
        let bouts = VignetteDecor.degrade(palette, nuit: nuit)
        clair = Color(bouts.clair)
        fonce = Color(bouts.fonce)
        encre = .white
        douce = Color(palette[.mint])
        pastille = Color(palette[.stageSoft])
        surPastille = Color(palette[.onPlate])
        jourFait = Color(palette[.mint])
        surJourFait = Color(palette[.brandDark])
        flamme = serie
        self.semaine = semaine
        plaque = Color(palette[.stageSoft])
    }
}

/// Les palettes de jour et de nuit des réglages : la vue choisit d'après le mode imposé ou celui du téléphone.
struct WidgetsApparence: Sendable {
    let jour: Palette?
    let nuit: Palette?
    /// Vrai pour « sombre », faux pour « clair », nil pour suivre le téléphone.
    let nuitImposee: Bool?

    init(reglages: Reglages, palettes: Palettes?) {
        let apparence = ApparenceChoisie(reglages)
        jour = palettes?.palette(fond: apparence.fond, accent: apparence.accent, nuit: false)
        nuit = palettes?.palette(fond: apparence.fond, accent: apparence.accent, nuit: true)
        nuitImposee = apparence.nuitImposee
    }

    func teintes(_ schema: ColorScheme) -> WidgetsTeintes {
        let estNuit = nuitImposee ?? (schema == .dark)
        return WidgetsTeintes(palette: estNuit ? nuit : jour, nuit: estNuit)
    }
}

// MARK: - Le décor

/// Le fond de la vignette de la série (StreakWidget.fond) : le dégradé de la palette en diagonale, du coin des
/// anneaux vers le foncé, deux grands arcs pâles venus du coin opposé, comme un écho des anneaux, et un liseré clair
/// sur le bord haut. Les coins sont ceux du système (containerBackground).
struct WidgetsFondSerie: View {
    let teintes: WidgetsTeintes
    @Environment(\.layoutDirection) private var sens

    var body: some View {
        GeometryReader { geo in
            let largeur = geo.size.width
            let hauteur = geo.size.height
            let m = min(largeur, hauteur)
            let rtl = sens == .rightToLeft
            let cx = rtl ? -m * 0.1 : largeur + m * 0.1
            let cy = hauteur + m * 0.15
            ZStack {
                LinearGradient(colors: [teintes.clair, teintes.fonce],
                               startPoint: rtl ? .topTrailing : .topLeading,
                               endPoint: rtl ? .bottomLeading : .bottomTrailing)
                Circle()
                    .stroke(Color.white.opacity(Double(VignetteDecor.arcExterieur)), lineWidth: m * 0.10)
                    .frame(width: m * 1.9, height: m * 1.9)
                    .position(x: cx, y: cy)
                Circle()
                    .stroke(Color.white.opacity(Double(VignetteDecor.arcInterieur)), lineWidth: m * 0.07)
                    .frame(width: m * 1.24, height: m * 1.24)
                    .position(x: cx, y: cy)
                ContainerRelativeShape()
                    .strokeBorder(LinearGradient(colors: [Color.white.opacity(Double(VignetteDecor.lisere)), .clear],
                                                 startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.6)),
                                  lineWidth: 1)
            }
            // Le dégradé et les arcs sont déjà placés selon le sens : rien ne se retourne.
            .environment(\.layoutDirection, .leftToRight)
        }
    }
}

/// Le fond des vignettes des zmanim (bg_widget_nuit.xml) : une nuit verte profonde, du haut à gauche vers le bas à
/// droite, et un filet clair. Lisible sur tout fond d'écran, sans dépendre du thème.
struct WidgetsFondNuit: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0D2422), Color(hex: 0x12302D), Color(hex: 0x1B4640)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            ContainerRelativeShape()
                .strokeBorder(Color.white.opacity(0x26 / 255), lineWidth: 1)
        }
    }
}

/// Les couleurs fixes des vignettes des zmanim (ZmanimVignette.FORT, PASSE, MENTHE, et les libellés à 0xA6).
enum WidgetsNuit {
    static let fort = Color.white.opacity(0xF2 / 255)
    static let passe = Color.white.opacity(0x59 / 255)
    static let doux = Color.white.opacity(0xA6 / 255)
    static let pale = Color.white.opacity(0x66 / 255)
    static let menthe = Color(hex: 0x9FE3CC)
}

/// Un texte et un compte à rebours vivant dans la même phrase : « encore 1:23:45 » (widget_reste), « 1:23:45 left ».
/// Le gabarit est résolu avec une marque à la place du temps, puis coupé autour d'elle ; sans marque, le compte seul.
struct WidgetsPhraseMinutee: View {
    let traducteur: Traducteur
    let cle: String
    let jusqua: Date

    private static let marque = "\u{E000}"

    var body: some View {
        let phrase = traducteur.texte(Libelle(cle, .texte(WidgetsPhraseMinutee.marque)))
        let morceaux = phrase.components(separatedBy: WidgetsPhraseMinutee.marque)
        let maintenant = Date.now
        let minuteur = Text(timerInterval: maintenant...max(jusqua, maintenant), countsDown: true)
        if morceaux.count == 2 {
            Text(verbatim: morceaux[0]) + minuteur + Text(verbatim: morceaux[1])
        } else {
            minuteur
        }
    }
}
