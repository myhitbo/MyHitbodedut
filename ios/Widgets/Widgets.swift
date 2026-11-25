import SwiftUI
import WidgetKit

/// Les widgets de l'app (tâche 25) : la série (StreakWidget.kt, WidgetsSerie.swift), les zmanim (ZmanimVignette.kt,
/// WidgetsZmanim.swift), la boussole (BoussoleWidget.kt), et la Live Activity de la séance (ActiviteSeance.swift).
@main
struct WidgetsMyHitbodedut: WidgetBundle {
    var body: some Widget {
        WidgetSerie()
        WidgetZmanim()
        WidgetBoussole()
        ActiviteSeanceWidget()
    }
}

// MARK: - La boussole

/// Le widget de la boussole (BoussoleWidget.kt, 2×2) : la direction de Jérusalem depuis le lieu des zmanim, en
/// degrés depuis le nord, sur une rose fixe (le nord en haut). Le toucher ouvre la boussole de l'app
/// (`myhitbodedut://boussole`, App/Liens.swift). Le widget ne calcule rien : l'app dépose la direction et les
/// textes, dans sa langue, dans le groupe d'apps (App/Services/SystemeWidgets.swift) et recharge le widget.
struct WidgetBoussole: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "boussole", provider: FournisseurBoussole()) { etat in
            VueBoussole(etat: etat)
                .containerBackground(for: .widget) { Color(red: 0.98, green: 0.97, blue: 0.94) }
                .widgetURL(URL(string: "myhitbodedut://boussole"))
        }
        .configurationDisplayName(Text(verbatim: "MyHitbodedut"))
        .description(Text(verbatim: "→ ירושלים"))
        .supportedFamilies([.systemSmall])
    }
}

/// Ce que montre le widget, lu dans le groupe d'apps.
struct EtatBoussole: TimelineEntry {
    let date: Date
    /// Les degrés depuis le nord, nil sans lieu choisi.
    let degres: Int?
    /// « N » dans la langue de l'app.
    let nord: String
    /// « Vers Jérusalem ».
    let titre: String
    /// La lecture pour VoiceOver, ou « Choisir le lieu » sans lieu.
    let lecture: String

    /// Les clés que dépose l'app (BoussolePartagee, App/Services/SystemeWidgets.swift).
    static func lire(_ date: Date = .now) -> EtatBoussole {
        let partage = UserDefaults(suiteName: "group.com.myhitbodedut")
        let degres = partage?.object(forKey: "boussole.degres") as? Int
        return EtatBoussole(date: date, degres: degres,
                            nord: partage?.string(forKey: "boussole.nord") ?? "N",
                            titre: partage?.string(forKey: "boussole.titre") ?? "",
                            lecture: partage?.string(forKey: "boussole.lecture") ?? "")
    }
}

/// Une seule entrée : la direction ne change qu'avec le lieu, et l'app recharge alors le widget.
struct FournisseurBoussole: TimelineProvider {
    func placeholder(in context: Context) -> EtatBoussole {
        EtatBoussole(date: .now, degres: 135, nord: "N", titre: "", lecture: "")
    }

    func getSnapshot(in context: Context, completion: @escaping (EtatBoussole) -> Void) {
        completion(EtatBoussole.lire())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EtatBoussole>) -> Void) {
        completion(Timeline(entries: [EtatBoussole.lire()], policy: .never))
    }
}

/// BoussoleDessin.rose : un cadran, le nord en haut, la flèche vers Jérusalem et ses degrés au centre.
struct VueBoussole: View {
    let etat: EtatBoussole

    /// Les couleurs fixes du widget d'Android (brand, ink, muted).
    private let marque = Color(red: 0.10, green: 0.43, blue: 0.36)
    private let encre = Color(red: 0.11, green: 0.13, blue: 0.12)
    private let pale = Color(red: 0.45, green: 0.48, blue: 0.47)

    var body: some View {
        GeometryReader { geo in
            let cote = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .strokeBorder(pale.opacity(0.5), lineWidth: 2)
                Text(verbatim: etat.nord)
                    .font(.system(size: cote * 0.12, weight: .bold))
                    .foregroundStyle(encre)
                    .offset(y: -cote * 0.36)
                if let degres = etat.degres {
                    Fleche()
                        .fill(marque)
                        .frame(width: cote * 0.16, height: cote * 0.62)
                        .rotationEffect(.degrees(Double(degres)))
                    Text(verbatim: "\(degres)°")
                        .font(.system(size: cote * 0.13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(encre)
                        .padding(.horizontal, 6)
                        .background(Capsule().fill(Color.white.opacity(0.85)))
                } else {
                    Text(verbatim: etat.lecture)
                        .font(.system(size: cote * 0.1, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(pale)
                        .padding(cote * 0.18)
                }
            }
            .frame(width: cote, height: cote)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // La rose ne se retourne pas en hébreu : le nord reste en haut, l'est à droite.
            .environment(\.layoutDirection, .leftToRight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: etat.lecture.isEmpty ? etat.titre : etat.lecture))
    }
}

/// Une flèche verticale, la pointe en haut : tournée des degrés depuis le nord, elle montre Jérusalem.
struct Fleche: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.32))
        p.addLine(to: CGPoint(x: rect.midX + rect.width * 0.18, y: rect.minY + rect.height * 0.32))
        p.addLine(to: CGPoint(x: rect.midX + rect.width * 0.18, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX - rect.width * 0.18, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX - rect.width * 0.18, y: rect.minY + rect.height * 0.32))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.32))
        p.closeSubpath()
        return p
    }
}
