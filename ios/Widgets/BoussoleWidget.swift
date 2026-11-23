import Coeur
import Ecrans
import SwiftUI
import WidgetKit

// Le widget de la boussole (BoussoleWidget.kt, 28/10, design C). Un widget ne lit pas la boussole du téléphone : il
// montre la direction principale de Jérusalem par rapport au nord, en haut, pour le lieu des zmanim et la méthode
// choisie (BoussoleDessin.rose), et ouvre la boussole vivante au toucher. Redessiné quand le lieu ou la méthode
// changent (l'app le demande), pas à intervalle.

struct EntreeBoussole: TimelineEntry {
    let date: Date
    /// La direction principale, en degrés depuis le nord vrai ; nil sans lieu.
    let principale: Double?
    let lieu: String?
}

struct FournisseurBoussole: TimelineProvider {
    func placeholder(in context: Context) -> EntreeBoussole {
        EntreeBoussole(date: Date(), principale: 120, lieu: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (EntreeBoussole) -> Void) {
        let rendu = Rendu(rendre: completion)
        Task { rendu.rendre(await FournisseurBoussole.entree()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EntreeBoussole>) -> Void) {
        let rendu = Rendu(rendre: completion)
        Task { rendu.rendre(Timeline(entries: [await FournisseurBoussole.entree()], policy: .never)) }
    }

    static func entree() async -> EntreeBoussole {
        let etat = await EtatWidgets.lire()
        guard let lieu = etat.reglages.lieuZmanim else {
            return EntreeBoussole(date: Date(), principale: nil, lieu: nil)
        }
        let directions = DirectionJerusalem.directions(lieu.latitude, lieu.longitude,
                                                       selonCarte: etat.reglages.boussoleCarte)
        return EntreeBoussole(date: Date(), principale: directions.principale, lieu: lieu.nom)
    }
}

/// La rose : le nord en haut, la direction de Jérusalem en flèche dorée, ses degrés au centre.
struct BoussoleRoseVue: View {
    let entree: EntreeBoussole

    var body: some View {
        GeometryReader { geo in
            let cote = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 2)
                ForEach(0..<12, id: \.self) { rang in
                    Capsule()
                        .fill(Color.white.opacity(rang % 3 == 0 ? 0.8 : 0.35))
                        .frame(width: 2, height: rang % 3 == 0 ? cote * 0.08 : cote * 0.05)
                        .offset(y: -cote * 0.44)
                        .rotationEffect(.degrees(Double(rang) * 30))
                }
                Text(verbatim: TextesWidgets.texte("boussole_nord"))
                    .font(.system(size: cote * 0.12, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(y: -cote * 0.3)
                if let principale = entree.principale {
                    Capsule()
                        .fill(CouleursWidgets.serie)
                        .frame(width: cote * 0.05, height: cote * 0.34)
                        .offset(y: -cote * 0.17)
                        .rotationEffect(.degrees(principale))
                    Text(verbatim: String(DirectionJerusalem.degres(principale)) + "°")
                        .font(.system(size: cote * 0.14, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Circle().fill(CouleursWidgets.nuitVerteFoncee.opacity(0.8)))
                } else {
                    Text(verbatim: TextesWidgets.texte("zmanim_choisir_lieu"))
                        .font(.system(size: cote * 0.09, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(cote * 0.15)
                }
            }
            .frame(width: cote, height: cote)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // La rose ne se retourne pas en hébreu : le nord reste en haut, l'est à droite.
            .environment(\.layoutDirection, .leftToRight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: description))
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
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [CouleursWidgets.nuitVerte, CouleursWidgets.nuitVerteFoncee],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
                .widgetURL(LienApp.boussole.url)
                .environment(\.locale, TextesWidgets.locale)
        }
        .configurationDisplayName(Text(verbatim: TextesWidgets.texte("boussole_widget_label")))
        .description(Text(verbatim: TextesWidgets.texte("boussole_widget_description")))
        .supportedFamilies([.systemSmall])
    }
}
