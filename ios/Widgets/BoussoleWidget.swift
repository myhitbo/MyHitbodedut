import Coeur
import Ecrans
import SwiftUI
import UIKit
import WidgetKit

// Le widget de la boussole (BoussoleWidget.kt, 28/10, design C). Un widget ne lit pas la boussole du téléphone : il
// montre la direction principale de Jérusalem par rapport au nord, en haut, pour le lieu des zmanim et la méthode
// choisie, dessinée comme la rose sans capteur de l'app (BoussoleDessin.rose, BoussoleToile.dessinerRoseFixe) : le
// hassid de dos au centre (sa pose féminine pour צדקת, Personnage.pour), le triangle d'or vers Jérusalem, « N » en
// haut, les degrés et « ירושלים » en bas. Il ouvre la boussole vivante au toucher. Redessiné quand le lieu ou la méthode
// changent (l'app le demande), pas à intervalle.

struct EntreeBoussole: TimelineEntry {
    let date: Date
    /// La direction principale, en degrés depuis le nord vrai ; nil sans lieu.
    let principale: Double?
    let lieu: String?
    /// Le hassid de dos (`char_standing_back`, ou sa pose féminine).
    let hassid: String
}

struct FournisseurBoussole: TimelineProvider {
    func placeholder(in context: Context) -> EntreeBoussole {
        EntreeBoussole(date: Date(), principale: 120, lieu: nil, hassid: FournisseurBoussole.image)
    }

    func getSnapshot(in context: Context, completion: @escaping (EntreeBoussole) -> Void) {
        let rendu = Rendu(rendre: completion)
        Task { rendu.rendre(await FournisseurBoussole.entree()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EntreeBoussole>) -> Void) {
        let rendu = Rendu(rendre: completion)
        Task { rendu.rendre(Timeline(entries: [await FournisseurBoussole.entree()], policy: .never)) }
    }

    /// BoussoleWidget.image : `R.drawable.char_standing_back`.
    static let image = "char_standing_back"

    static func entree() async -> EntreeBoussole {
        let etat = await EtatWidgets.lire()
        let hassid = Personnage.pour(etat.reglages.adresse.flatMap { Adresse(rawValue: $0) }, image)
        guard let lieu = etat.reglages.lieuZmanim else {
            return EntreeBoussole(date: Date(), principale: nil, lieu: nil, hassid: hassid)
        }
        let directions = DirectionJerusalem.directions(lieu.latitude, lieu.longitude,
                                                       selonCarte: etat.reglages.boussoleCarte)
        return EntreeBoussole(date: Date(), principale: directions.principale, lieu: lieu.nom, hassid: hassid)
    }
}

/// Les couleurs de la scène (BoussoleDessin.CIEL…), fixes comme une illustration, de jour comme de nuit.
enum CouleursBoussole {
    static let ciel = CouleursWidgets.couleur(0xFFDF_F5E8)
    static let horizon = CouleursWidgets.couleur(0xFF9C_C9B0)
    static let encre = CouleursWidgets.couleur(0xFF17_3C32)
    static let marque = CouleursWidgets.couleur(0xFF16_775A)
    static let or = CouleursWidgets.couleur(0xFFB8_780F)
}

/// Le triangle d'or de la rose (BoussoleDessin.rose), pointé vers le nord sur un carré de 112 unités centré : la vue le
/// tourne de la direction principale autour du centre.
private struct TriangleRose: Shape {
    func path(in rect: CGRect) -> Path {
        let e = min(rect.width, rect.height) / 112
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.midX + x * e, y: rect.midY + y * e) }
        var chemin = Path()
        chemin.move(to: p(0, -53))
        chemin.addLine(to: p(5, -37))
        chemin.addLine(to: p(0, -40))
        chemin.addLine(to: p(-5, -37))
        chemin.closeSubpath()
        return chemin
    }
}

/// La rose sans capteur (BoussoleDessin.rose), sur le carré de 112 unités centré de la maquette.
struct BoussoleRoseVue: View {
    let entree: EntreeBoussole

    var body: some View {
        GeometryReader { geo in
            let cote = min(geo.size.width, geo.size.height)
            let e = cote / 112
            ZStack {
                RoundedRectangle(cornerRadius: 12 * e, style: .circular)
                    .fill(CouleursBoussole.ciel)
                Circle()
                    .stroke(CouleursBoussole.horizon, lineWidth: 1.2 * e)
                    .frame(width: 88 * e, height: 88 * e)
                // Le hassid de dos, étiré dans son cadre comme drawBitmap (x -12, y -33, 26 × 81).
                if let image = BoussoleRoseVue.image(entree.hassid) {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: 26 * e, height: 81 * e)
                        .position(x: (56 + 1) * e, y: (56 + 7.5) * e)
                }
                if let principale = entree.principale {
                    TriangleRose()
                        .fill(CouleursBoussole.or)
                        .rotationEffect(.degrees(principale))
                    texte(String(DirectionJerusalem.degres(principale)) + "°", taille: 10, couleur: CouleursBoussole.encre,
                          x: 38, base: 51, e: e)
                }
                texte(TextesWidgets.texte("boussole_nord"), taille: 9, gras: true, couleur: CouleursBoussole.encre,
                      x: 0, base: -42, e: e)
                texte(BoussoleRoseVue.jerusalem, taille: 9, gras: true, serif: true, couleur: CouleursBoussole.marque,
                      x: -36, base: 51, e: e)
            }
            .frame(width: cote, height: cote)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // La rose ne se retourne pas en hébreu : le nord reste en haut, l'est à droite.
            .environment(\.layoutDirection, .leftToRight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: description))
    }

    /// « ירושלים » (BoussoleDessin.JERUSALEM).
    static let jerusalem = "ירושלים"

    /// Un texte centré en `x`, sa ligne de base en `base` (drawText d'Android, Align.CENTER), à une taille en unités de
    /// la scène : la ligne de base d'une police est à peu près aux trois quarts de sa hauteur.
    private func texte(_ chaine: String, taille: CGFloat, gras: Bool = false, serif: Bool = false, couleur: Color,
                       x: CGFloat, base: CGFloat, e: CGFloat) -> some View {
        Text(verbatim: chaine)
            .font(.system(size: taille * e, weight: gras ? .bold : .regular, design: serif ? .serif : .default))
            .foregroundStyle(couleur)
            .lineLimit(1)
            .fixedSize()
            .position(x: (56 + x) * e, y: (56 + base - taille * 0.35) * e)
    }

    /// L'image du hassid copiée dans l'extension (projet-commun.yml) ; nil si elle manque.
    private static func image(_ nom: String) -> UIImage? {
        guard let url = Bundle.main.url(forResource: nom, withExtension: "webp") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private var description: String {
        guard let principale = entree.principale, let lieu = entree.lieu else {
            return TextesWidgets.texte("zmanim_choisir_lieu")
        }
        return TextesWidgets.texte(Libelle("boussole_widget_lecture", .texte(lieu),
                                           .entier(DirectionJerusalem.degres(principale))))
    }
}

struct BoussoleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: GenresWidgets.boussole, provider: FournisseurBoussole()) { entree in
            BoussoleRoseVue(entree: entree)
                .padding(4)
                // Le vert menthe de la scène (bg_widget_boussole).
                .containerBackground(for: .widget) { CouleursBoussole.ciel }
                .widgetURL(LienApp.boussole.url)
                .environment(\.locale, TextesWidgets.locale)
        }
        .configurationDisplayName(Text(verbatim: TextesWidgets.texte("boussole_widget_label")))
        .description(Text(verbatim: TextesWidgets.texte("boussole_widget_description")))
        .supportedFamilies([.systemSmall])
    }
}
