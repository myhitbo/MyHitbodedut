import Foundation
import SwiftUI
import Coeur
import Ecrans

// Ce que le journal et « Mon parcours » ont en commun : le graphique du mois (JournalPlus.Graphique d'Android),
// le vert du bandeau (bg_hero.xml, bg_carte_sombre.xml) et l'écriture des dates dans la langue de l'app.

// MARK: Le graphique du mois

/// Le graphique des minutes du mois (JournalPlus.Graphique.onDraw) : une barre blanche par jour du mois, à
/// l'échelle du plus long, plus basse et pâle pour un jour vide, et un point au-dessus de celle d'aujourd'hui.
/// Les mesures sont celles du modèle (`JournalGraphique`). Le 1ᵉʳ du mois est au début de la ligne : à gauche,
/// à droite en hébreu. `libelle` : ce que dit VoiceOver ; sans libellé, le graphique est décoratif.
public struct JournalGraphiqueVue: View {
    private let graphique: JournalGraphique
    private let libelle: Text?
    @Environment(\.layoutDirection) private var sens

    public init(graphique: JournalGraphique, libelle: Text? = nil) {
        self.graphique = graphique
        self.libelle = libelle
    }

    public var body: some View {
        let miroir = sens == .rightToLeft
        let dessin = Canvas { contexte, taille in
            dessiner(contexte, taille, miroir: miroir)
        }
        .frame(maxWidth: .infinity)
        .frame(height: CGFloat(JournalGraphique.hauteur))
        // Le miroir est calculé ici : le dessin lui-même ne se retourne pas.
        .environment(\.layoutDirection, .leftToRight)
        if let libelle {
            dessin
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(libelle)
                .accessibilityAddTraits(.isImage)
        } else {
            dessin
                .accessibilityHidden(true)
        }
    }

    private func dessiner(_ contexte: GraphicsContext, _ taille: CGSize, miroir: Bool) {
        let barres = graphique.barres
        guard !barres.isEmpty, taille.width > 0 else { return }
        let hauteur = Double(taille.height)
        let largeur = Double(taille.width)
        let pas = largeur / Double(barres.count)
        let l = JournalGraphique.largeurBarre(largeur: largeur, nombre: barres.count)
        for (i, barre) in barres.enumerated() {
            let x = miroir
                ? largeur - Double(i + 1) * pas + (pas - l) / 2
                : Double(i) * pas + (pas - l) / 2
            let h = JournalGraphique.hauteurBarre(barre, hauteur: hauteur)
            let rect = CGRect(x: x, y: hauteur - h, width: l, height: h)
            let couleur = barre.faite ? Color.white : Color.white.opacity(JournalGraphique.opaciteVide)
            contexte.fill(Path(roundedRect: rect, cornerRadius: CGFloat(l / 2), style: .circular),
                          with: .color(couleur))
            if barre.aujourdhui {
                let r = JournalGraphique.rayonPoint
                let centreX = x + l / 2
                let centreY = hauteur - h - JournalGraphique.ecartPoint
                let point = CGRect(x: centreX - r, y: centreY - r, width: 2 * r, height: 2 * r)
                contexte.fill(Path(ellipseIn: point), with: .color(Color.white))
            }
        }
    }
}

// MARK: Le vert du bandeau

/// Le dégradé de bg_hero.xml et de bg_carte_sombre.xml : à 225°, de l'accent (`brand`, en haut du côté de la fin)
/// vers le vert sombre (`brandDark`, dès 55 %). Il ne se retourne pas en hébreu, comme sur Android.
@MainActor
enum JournalDegrade {
    static func vert(_ palette: PaletteApp, _ schema: ColorScheme) -> LinearGradient {
        let marque = palette.couleur(.brand, schema: schema)
        let sombre = palette.couleur(.brandDark, schema: schema)
        return LinearGradient(stops: [
            Gradient.Stop(color: marque, location: 0),
            Gradient.Stop(color: sombre, location: 0.55),
            Gradient.Stop(color: sombre, location: 1),
        ], startPoint: UnitPoint(x: 1, y: 0), endPoint: UnitPoint(x: 0, y: 1))
    }
}

/// Le fond du bandeau (bg_hero.xml) : le dégradé vert, coins bas de 20, et un filet de lumière de 1 point en bas,
/// à 36 points des bords, blanc à 25 % au centre. Il monte sous la barre d'état.
struct JournalBandeauFond: View {
    @Environment(\.paletteApp) private var palette
    @Environment(\.colorScheme) private var schema

    var body: some View {
        UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20, style: .continuous)
            .fill(JournalDegrade.vert(palette, schema))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.25),
                                                  Color.white.opacity(0)],
                                         startPoint: UnitPoint(x: 0, y: 0.5), endPoint: UnitPoint(x: 1, y: 0.5)))
                    .frame(height: 1)
                    .padding(.horizontal, 36)
            }
            .environment(\.layoutDirection, .leftToRight)
            .ignoresSafeArea(edges: .top)
            .accessibilityHidden(true)
    }
}

/// La carte verte (bg_carte_sombre.xml) : le même dégradé, coins de 20, sans bordure.
struct JournalCarteVerteFond: View {
    @Environment(\.paletteApp) private var palette
    @Environment(\.colorScheme) private var schema

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(JournalDegrade.vert(palette, schema))
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityHidden(true)
    }
}

// MARK: Les dates

/// Un jour écrit dans la langue de l'app, au calendrier grégorien (`DateTimeFormatter` d'Android avec la locale
/// de l'app, et non celle du téléphone).
enum JournalDates {

    /// La ligne du journal : « EEEE d MMMM yyyy », première lettre en capitale (« Jeudi 12 novembre 2026 ») ;
    /// le jour en ISO s'il ne s'écrit pas (Android montre alors la date telle quelle).
    static func ligne(_ jour: JourCivil, langue: String) -> String {
        guard let texte = ecrire(jour, langue: langue, motif: "EEEE d MMMM yyyy", style: nil),
              let premiere = texte.first else { return jour.iso }
        let locale = Locale(identifier: langue)
        return String(premiere).uppercased(with: locale) + String(texte.dropFirst())
    }

    /// Le mois du graphique : « MMMM yyyy » (« novembre 2026 »).
    static func mois(_ jour: JourCivil, langue: String) -> String {
        ecrire(jour, langue: langue, motif: "MMMM yyyy", style: nil) ?? jour.iso
    }

    /// Le titre de la fenêtre d'un jour : la date entière (`FormatStyle.FULL`), « jeudi 12 novembre 2026 ».
    static func complete(_ jour: JourCivil, langue: String) -> String {
        ecrire(jour, langue: langue, motif: nil, style: .full) ?? jour.iso
    }

    private static func ecrire(_ jour: JourCivil, langue: String, motif: String?,
                               style: DateFormatter.Style?) -> String? {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = .gmt
        // Midi : aucun changement d'heure ne fait glisser le jour.
        let composantes = DateComponents(year: jour.annee, month: jour.mois, day: jour.jour, hour: 12)
        guard let date = calendrier.date(from: composantes) else { return nil }
        let format = DateFormatter()
        format.calendar = calendrier
        format.timeZone = .gmt
        format.locale = Locale(identifier: langue)
        if let motif {
            format.dateFormat = motif
        } else if let style {
            format.dateStyle = style
            format.timeStyle = .none
        }
        return format.string(from: date)
    }
}

// MARK: La confidentialité

/// Les notes ne se montrent pas dans l'aperçu du sélecteur d'apps (FLAG_SECURE d'Android) : dès que la scène
/// n'est plus active, un voile couvre l'écran, le fond `paper` et le hassid qui écrit. iOS n'interdit pas la
/// capture d'écran ; l'aperçu, lui, ne montre que le voile.
struct JournalVoile: ViewModifier {
    let actif: Bool
    let image: String
    @Environment(\.scenePhase) private var phase

    func body(content: Content) -> some View {
        content
            .overlay {
                if actif && phase != .active {
                    ZStack {
                        Rectangle()
                            .fill(Teinte(.paper))
                        Illustration(decorative: image, hauteur: 190)
                            .frame(width: 180)
                    }
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                }
            }
    }
}
