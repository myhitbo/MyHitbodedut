import Coeur
import Ecrans
import SwiftUI
import WidgetKit

// Les trois vignettes des zmanim (ZmanimVignette.kt, demande du 28/10 : « trois différentes, trois tailles, très
// classe »), sur un même fond de nuit verte, et leur pendant sur l'écran verrouillé :
// - petite : la prière du moment, l'heure où elle se ferme, une jauge ;
// - moyenne : la même, le temps qui reste, la série, les trois zmanim à venir ;
// - grande : la même et la journée entière, le prochain zman en évidence.
// La date hébraïque et la fête du jour, ou la paracha de la semaine, en tête ; elles changent à la sortie des étoiles
// du lieu. La chronologie vient de Coeur (`Chronologies`, PORTAGE.md § 2.2.3) : une entrée à chaque zman, et toutes
// les dix minutes entre deux (le temps qui reste et la jauge, ZmanimVignette.PAS_MAX_MINUTES), jusqu'au minuit du
// lieu. Le toucher ouvre Zmanim.

struct EntreeZmanim: TimelineEntry {
    let date: Date
    let affichage: Chronologies.Affichage
    /// La série (Store.streak), sur la moyenne.
    let serie: Int
    /// Le fuseau du lieu, où s'écrivent les heures.
    let fuseau: Fuseau

    /// L'aperçu du sélecteur : le gabarit, sans lieu.
    static func exemple(_ date: Date = Date()) -> EntreeZmanim {
        let fuseau = Fuseau(TimeZone.current.identifier) ?? .utc
        let maintenant = Int64(date.timeIntervalSince1970 * 1000)
        return EntreeZmanim(date: date, affichage: Chronologies.affichage(famille: .moyenne, lieu: nil, maintenant: maintenant,
                                                                        fuseauTelephone: fuseau, enIsrael: false),
                            serie: 7, fuseau: fuseau)
    }
}

/// Une fermeture de WidgetKit portée par une tâche : elle n'est appelée qu'une fois, de cette tâche.
struct Rendu<T>: @unchecked Sendable {
    let rendre: (T) -> Void
}

struct FournisseurZmanim: TimelineProvider {
    let famille: Chronologies.Famille

    /// ZmanimVignette.PAS_MAX_MINUTES.
    private static let pas: Int64 = 10 * 60_000

    func placeholder(in context: Context) -> EntreeZmanim {
        .exemple()
    }

    func getSnapshot(in context: Context, completion: @escaping (EntreeZmanim) -> Void) {
        let rendu = Rendu(rendre: completion)
        let famille = self.famille
        Task {
            let chronologie = await FournisseurZmanim.chronologie(famille)
            rendu.rendre(chronologie.entries.first ?? .exemple())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EntreeZmanim>) -> Void) {
        let rendu = Rendu(rendre: completion)
        let famille = self.famille
        Task { rendu.rendre(await FournisseurZmanim.chronologie(famille)) }
    }

    static func chronologie(_ famille: Chronologies.Famille) async -> Timeline<EntreeZmanim> {
        let etat = await EtatWidgets.lire()
        let lieu = etat.reglages.lieuZmanim
        let enIsrael = etat.reglages.inIsrael(fuseauTelephone: etat.fuseauTelephone)
        let chrono = Chronologies.chronologie(famille: famille, lieu: lieu, maintenant: etat.maintenant,
                                              fuseauTelephone: etat.fuseau, enIsrael: enIsrael)
        let serie = Store.streak(journal: etat.journal, reglages: etat.reglages, aujourdhui: etat.aujourdhui,
                                 fuseauTelephone: etat.fuseauTelephone)
        let fuseau = lieu.flatMap { Fuseau($0.fuseau) } ?? etat.fuseau
        var entrees: [EntreeZmanim] = []
        for (rang, entree) in chrono.entrees.enumerated() {
            let fin = rang + 1 < chrono.entrees.count ? chrono.entrees[rang + 1].instant : chrono.recharge
            var t = entree.instant
            // Sans lieu, rien ne change avant minuit : une seule entrée.
            repeat {
                entrees.append(EntreeZmanim(date: date(t), affichage: entree.affichage, serie: serie, fuseau: fuseau))
                t += pas
            } while lieu != nil && t < fin
        }
        if entrees.isEmpty { entrees = [.exemple()] }
        return Timeline(entries: entrees, policy: .after(date(chrono.recharge)))
    }
}

// MARK: Les vues

/// Ce que les trois tailles partagent : la date hébraïque et la pastille, la prière et sa limite, la jauge, le reste.
private struct ZmanimTete: View {
    let entree: EntreeZmanim
    let grand: Bool

    private var a: Chronologies.Affichage { entree.affichage }
    private var maintenant: Int64 { Int64(entree.date.timeIntervalSince1970 * 1000) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(verbatim: a.dateHebraique)
                    .font(.system(size: grand ? 14 : 12, weight: .semibold))
                    .foregroundStyle(CouleursWidgets.doux)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let pastille = a.pastille {
                    Text(verbatim: TextesWidgets.texte(pastille))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(CouleursWidgets.menthe)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                }
            }
            Text(verbatim: TextesWidgets.texte(a.titre))
                .font(.system(size: grand ? 24 : 20, weight: .bold))
                .foregroundStyle(CouleursWidgets.fort)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let ligne = limiteTexte {
                Text(verbatim: ligne)
                    .font(.system(size: 13))
                    .foregroundStyle(CouleursWidgets.menthe)
                    .lineLimit(1)
            }
            if let ouverte = limiteOuverte {
                ProgressView(value: Double(ZmanimVignette.ecoule(debut: a.debut.map { zonee($0) }, fin: zonee(ouverte),
                                                                 maintenant: zonee(maintenant))), total: 1000)
                    .progressViewStyle(.linear)
                    .tint(CouleursWidgets.menthe)
                    .padding(.top, 4)
                    .accessibilityHidden(true)
            }
        }
    }

    /// Ouverte : sa limite ; pas encore ouverte (FVOL-05), ni jauge ni temps restant.
    private var limiteOuverte: Int64? {
        a.ouverture == nil ? a.limite : nil
    }

    /// « jusqu'à 9:12 », ou « dès 12:05 » ; rien sans limite.
    private var limiteTexte: String? {
        if let ouverture = a.ouverture {
            return TextesWidgets.texte(Libelle("widget_des", .texte(heureMinute(ouverture, entree.fuseau))))
        }
        if let limite = a.limite {
            return TextesWidgets.texte(Libelle("widget_jusqua", .texte(heureMinute(limite, entree.fuseau))))
        }
        return nil
    }

    private func zonee(_ millis: Int64) -> DateHeureZonee {
        DateHeureZonee(millis: millis, fuseau: entree.fuseau)
    }
}

/// « encore 1:23 » (widget_reste), le temps jusqu'à la limite de la prière ouverte.
private func resteTexte(_ entree: EntreeZmanim) -> String? {
    guard entree.affichage.ouverture == nil, let limite = entree.affichage.limite else { return nil }
    let maintenant = Int64(entree.date.timeIntervalSince1970 * 1000)
    let minutes = max(Int((limite - maintenant) / 60_000), 0)
    let duree = String(minutes / 60) + ":" + (minutes % 60 < 10 ? "0" : "") + String(minutes % 60)
    return TextesWidgets.texte(Libelle("widget_reste", .texte(duree)))
}

struct ZmanimPetiteVue: View {
    let entree: EntreeZmanim

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZmanimTete(entree: entree, grand: false)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ZmanimMoyenneVue: View {
    let entree: EntreeZmanim

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                ZmanimTete(entree: entree, grand: false)
                if let reste = resteTexte(entree) {
                    Text(verbatim: reste)
                        .font(.system(size: 12))
                        .foregroundStyle(CouleursWidgets.doux)
                }
                Spacer(minLength: 0)
                Text(verbatim: TextesWidgets.texte(Libelle.pluriel("widget_zmanim_serie", quantite: entree.serie,
                                                                   .entier(entree.serie))))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CouleursWidgets.doux)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(entree.affichage.prochains.enumerated()), id: \.offset) { rang, zman in
                    if let zman {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(verbatim: TextesWidgets.texte(zman.libelle))
                                .font(.system(size: 11))
                                .foregroundStyle(CouleursWidgets.doux)
                                .lineLimit(1)
                            Text(verbatim: heureMinute(zman.instant, entree.fuseau))
                                .font(.system(size: 16, weight: .semibold).monospacedDigit())
                                .foregroundStyle(rang == 0 ? CouleursWidgets.menthe : CouleursWidgets.fort)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ZmanimGrandeVue: View {
    let entree: EntreeZmanim

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZmanimTete(entree: entree, grand: true)
            if let reste = resteTexte(entree) {
                Text(verbatim: reste)
                    .font(.system(size: 12))
                    .foregroundStyle(CouleursWidgets.doux)
            }
            let maintenant = Int64(entree.date.timeIntervalSince1970 * 1000)
            VStack(spacing: 2) {
                ForEach(Array(entree.affichage.journee.enumerated()), id: \.offset) { rang, zman in
                    let prochain = rang == entree.affichage.prochain
                    let passe = zman.instant <= maintenant
                    HStack {
                        Text(verbatim: TextesWidgets.texte(zman.libelle))
                            .foregroundStyle(prochain ? CouleursWidgets.menthe : (passe ? CouleursWidgets.passe : CouleursWidgets.doux))
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(verbatim: heureMinute(zman.instant, entree.fuseau))
                            .monospacedDigit()
                            .foregroundStyle(prochain ? CouleursWidgets.menthe : (passe ? CouleursWidgets.passe : CouleursWidgets.fort))
                    }
                    .font(.system(size: 13, weight: prochain ? .bold : .regular))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background {
                        if prochain { RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.1)) }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// L'écran verrouillé : la prière du moment et sa limite, sur une ligne ou dans un rectangle.
struct ZmanimVerrouilleVue: View {
    let entree: EntreeZmanim
    @Environment(\.widgetFamily) private var famille

    init(entree: EntreeZmanim) {
        self.entree = entree
    }

    var body: some View {
        let a = entree.affichage
        let titre = TextesWidgets.texte(a.titre)
        let limite: String? = a.ouverture.map {
            TextesWidgets.texte(Libelle("widget_des", .texte(heureMinute($0, entree.fuseau))))
        } ?? a.limite.map { TextesWidgets.texte(Libelle("widget_jusqua", .texte(heureMinute($0, entree.fuseau)))) }
        switch famille {
        case .accessoryInline:
            Text(verbatim: limite.map { titre + " · " + $0 } ?? titre)
        default:
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: a.dateHebraique)
                    .font(.caption2)
                    .lineLimit(1)
                Text(verbatim: titre)
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                if let limite {
                    Text(verbatim: limite)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: Les widgets

/// Le fond de nuit verte des vignettes (bg_widget_zmanim), et ce qu'elles partagent : la langue, le sens, le toucher.
private struct ZmanimHabit: ViewModifier {
    func body(content: Content) -> some View {
        content
            .containerBackground(for: .widget) {
                LinearGradient(colors: [CouleursWidgets.nuitVerte, CouleursWidgets.nuitVerteFoncee],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .widgetURL(LienApp.zmanim.url)
            .environment(\.locale, TextesWidgets.locale)
            .environment(\.layoutDirection, TextesWidgets.deDroiteAGauche ? .rightToLeft : .leftToRight)
    }
}

struct ZmanimPetitWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: GenresWidgets.zmanimPetit, provider: FournisseurZmanim(famille: .petite)) { entree in
            ZmanimPetiteVue(entree: entree).modifier(ZmanimHabit())
        }
        .configurationDisplayName(Text(verbatim: TextesWidgets.texte("widget_zmanim_petit_label")))
        .description(Text(verbatim: TextesWidgets.texte("widget_zmanim_petit_description")))
        .supportedFamilies([.systemSmall])
    }
}

struct ZmanimWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: GenresWidgets.zmanim, provider: FournisseurZmanim(famille: .moyenne)) { entree in
            ZmanimMoyenneVue(entree: entree).modifier(ZmanimHabit())
        }
        .configurationDisplayName(Text(verbatim: TextesWidgets.texte("widget_zmanim_label")))
        .description(Text(verbatim: TextesWidgets.texte("widget_zmanim_description")))
        .supportedFamilies([.systemMedium])
    }
}

struct ZmanimGrandWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: GenresWidgets.zmanimGrand, provider: FournisseurZmanim(famille: .grande)) { entree in
            ZmanimGrandeVue(entree: entree).modifier(ZmanimHabit())
        }
        .configurationDisplayName(Text(verbatim: TextesWidgets.texte("widget_zmanim_grand_label")))
        .description(Text(verbatim: TextesWidgets.texte("widget_zmanim_grand_description")))
        .supportedFamilies([.systemLarge])
    }
}

struct ZmanimVerrouilleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: GenresWidgets.verrouille, provider: FournisseurZmanim(famille: .petite)) { entree in
            ZmanimVerrouilleVue(entree: entree)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(LienApp.zmanim.url)
                .environment(\.locale, TextesWidgets.locale)
                .environment(\.layoutDirection, TextesWidgets.deDroiteAGauche ? .rightToLeft : .leftToRight)
        }
        .configurationDisplayName(Text(verbatim: TextesWidgets.texte("widget_zmanim_petit_label")))
        .description(Text(verbatim: TextesWidgets.texte("widget_zmanim_petit_description")))
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}
