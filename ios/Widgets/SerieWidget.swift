import Coeur
import Ecrans
import SwiftUI
import WidgetKit

// La série sur l'écran d'accueil, et de quoi commencer d'un geste (StreakWidget.kt, widget_small.xml,
// widget_streak.xml, widget_large.xml). Elle suit la place qu'on lui donne (WidgetTaille) : petite, les anneaux et la
// série en pastille ; moyenne, les anneaux d'un côté, de l'autre la salutation, les minutes du jour, la semaine et le
// bouton ; grande, la semaine en sept pastilles en plus. Elle porte les couleurs choisies (VignetteDecor) : un dégradé
// de la couleur des boutons, plus sombre la nuit.
//
// Le bouton part droit sur la séance et la lance (« Commencer ») ; pendant une hitbodedout, il la termine sans ouvrir
// l'app (« Terminer maintenant », TerminerSeanceIntent), comme le bouton de la notification. Le reste ouvre l'app ;
// pendant une hitbodedout, son écran. Elle se redessine quand l'app part en arrière-plan, après chaque séance, juste
// après minuit (programmerMinuit), et toutes les heures (updatePeriodMillis).

struct EntreeSerie: TimelineEntry {
    let date: Date
    let serie: Int
    let enCours: Bool
    let fait: Bool
    /// Chabbat, Yom Tov ou pause : rien n'est attendu aujourd'hui.
    let repos: Bool
    let semaine: [CaseSemaine]
    let anneaux: Anneaux.Etat
    let prenom: String
    let dejaPratique: Bool
    let reglages: Reglages

    static func lire(_ etat: EtatWidgets, date: Date) -> EntreeSerie {
        let millis = Int64(date.timeIntervalSince1970 * 1000)
        let jour = etat.fuseau.jour(millis: millis)
        let telephone = etat.fuseauTelephone
        return EntreeSerie(
            date: date,
            serie: Store.streak(journal: etat.journal, reglages: etat.reglages, aujourdhui: jour, fuseauTelephone: telephone),
            enCours: Store.isSessionRunning(reglages: etat.reglages, millis: millis),
            fait: Store.isDone(journal: etat.journal, date: jour),
            repos: Store.isExempt(reglages: etat.reglages, date: jour, fuseauTelephone: telephone),
            semaine: Store.currentWeek(journal: etat.journal, reglages: etat.reglages, aujourdhui: jour,
                                       fuseauTelephone: telephone),
            anneaux: Store.anneaux(journal: etat.journal, reglages: etat.reglages, aujourdhui: jour,
                                   fuseauTelephone: telephone),
            prenom: etat.journal.firstName,
            dejaPratique: Store.aDejaPratique(journal: etat.journal),
            reglages: etat.reglages)
    }

    /// L'aperçu du sélecteur : les chiffres d'exemple d'Android (widget_apercu_serie, widget_apercu_minutes).
    static func exemple() -> EntreeSerie {
        let anneaux = Anneaux.Etat(jour: Anneaux.Anneau(quel: .jour, fait: 15, objectif: 20),
                                   semaine: Anneaux.Anneau(quel: .semaine, fait: 4, objectif: 6),
                                   serie: Anneaux.Anneau(quel: .serie, fait: 7, objectif: 14))
        return EntreeSerie(date: Date(), serie: 7, enCours: false, fait: false, repos: false, semaine: [],
                           anneaux: anneaux, prenom: "", dejaPratique: true, reglages: Reglages())
    }
}

struct FournisseurSerie: TimelineProvider {
    func placeholder(in context: Context) -> EntreeSerie {
        .exemple()
    }

    func getSnapshot(in context: Context, completion: @escaping (EntreeSerie) -> Void) {
        let rendu = Rendu(rendre: completion)
        Task { rendu.rendre(EntreeSerie.lire(await EtatWidgets.lire(), date: Date())) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EntreeSerie>) -> Void) {
        let rendu = Rendu(rendre: completion)
        Task {
            let etat = await EtatWidgets.lire()
            let maintenant = Date()
            var dates = [maintenant]
            // La fin d'une séance minutée : le bouton redevient « Commencer ».
            let fin = Store.sessionEndsAt(reglages: etat.reglages)
            if fin > etat.maintenant { dates.append(date(fin)) }
            // Juste après minuit : sans cela, la coche de la veille restait jusqu'à une heure (programmerMinuit).
            let minuit = etat.fuseau.millis(DateHeure(etat.aujourdhui.plus(jours: 1))) + 60_000
            dates.append(date(minuit))
            let entrees = dates.sorted().map { EntreeSerie.lire(etat, date: $0) }
            rendu.rendre(Timeline(entries: entrees, policy: .after(maintenant.addingTimeInterval(3600))))
        }
    }
}

// MARK: Les vues

struct SerieVue: View {
    let entree: EntreeSerie
    @Environment(\.widgetFamily) private var famille

    var body: some View {
        switch famille {
        case .systemSmall:
            ZStack(alignment: .bottomTrailing) {
                SerieAnneaux(anneaux: entree.anneaux, enCours: entree.enCours, fait: entree.fait)
                    .padding(6)
                badge
            }
        case .systemLarge:
            VStack(alignment: .leading, spacing: 12) {
                moyenne
                semaine
                Spacer(minLength: 0)
            }
        default:
            moyenne
        }
    }

    private var moyenne: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                SerieAnneaux(anneaux: entree.anneaux, enCours: entree.enCours, fait: entree.fait)
                badge
            }
            .frame(width: 110, height: 110)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: salutation)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(couleurs.mint)
                    .lineLimit(2)
                Text(verbatim: TextesWidgets.texte(Libelle("widget_minutes", .entier(entree.anneaux.jour.fait),
                                                           .entier(entree.anneaux.jour.objectif))))
                    .font(.system(size: 22, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(verbatim: TextesWidgets.texte(Libelle.pluriel("week_gauge", quantite: entree.anneaux.semaine.fait,
                                                                   .entier(entree.anneaux.semaine.fait),
                                                                   .entier(entree.anneaux.semaine.objectif))))
                    .font(.system(size: 11))
                    .foregroundStyle(couleurs.mint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                bouton
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Pendant la hitbodedout, « Terminer maintenant » sans ouvrir l'app ; sinon « Commencer », qui la lance.
    @ViewBuilder
    private var bouton: some View {
        let libelle = TextesWidgets.texte(entree.enCours ? "session_finish_now" : "widget_start")
        let etiquette = Text(verbatim: libelle)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(couleurs.surPastille)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(couleurs.pastille))
        if entree.enCours {
            Button(intent: TerminerSeanceIntent()) { etiquette }
                .buttonStyle(.plain)
        } else {
            Link(destination: LienApp.seance(demarrer: true).url) { etiquette }
        }
    }

    /// La série dans sa pastille : la flamme s'allume quand le jour est fait, ou qu'il n'attend rien.
    private var badge: some View {
        let allumee = entree.fait || entree.repos
        return HStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .foregroundStyle(allumee ? CouleursWidgets.serie : Color.white.opacity(0.6))
            Text(verbatim: String(entree.serie))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .font(.system(size: 13, weight: .bold))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.black.opacity(Double(VignetteDecor.voileBadge))))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: descriptionSerie))
    }

    private var descriptionSerie: String {
        if entree.serie == 0 {
            // « à relancer » ne se dit qu'à qui a déjà pratiqué (FDONNEES-29).
            return TextesWidgets.texte(entree.dejaPratique ? "status_streak_none" : "status_streak_first")
        }
        return TextesWidgets.texte(Libelle.pluriel("status_streak", quantite: entree.serie, .entier(entree.serie)))
    }

    /// La première ligne : pendant la hitbodedout, qu'elle est en cours ; sinon bonjour ou bonsoir avec le prénom ;
    /// sans prénom, l'état du jour (un jour de repos ne sonne pas comme un reproche).
    private var salutation: String {
        if entree.enCours { return TextesWidgets.texte("widget_running") }
        let prenom = entree.prenom
        if !prenom.isEmpty {
            let heure = Calendar.current.component(.hour, from: entree.date)
            return TextesWidgets.texte(Libelle(Salutation.chaine(heure), .texte(prenom)))
        }
        if entree.fait { return TextesWidgets.texte("widget_done") }
        if entree.repos { return TextesWidgets.texte("widget_rest") }
        return TextesWidgets.texte("widget_todo")
    }

    /// La semaine en sept pastilles, du dimanche au samedi.
    private var semaine: some View {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.locale = TextesWidgets.locale
        let initiales = calendrier.veryShortStandaloneWeekdaySymbols
        return HStack(spacing: 6) {
            ForEach(Array(entree.semaine.enumerated()), id: \.offset) { rang, jour in
                VStack(spacing: 3) {
                    Text(verbatim: rang < initiales.count ? initiales[rang] : "")
                        .font(.system(size: 11))
                        .foregroundStyle(couleurs.mint)
                    ZStack {
                        Circle()
                            .fill(jour.done ? couleurs.mint : Color.white.opacity(0.12))
                        if jour.done {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(couleurs.fonce)
                        } else if jour.exempt {
                            Circle().fill(Color.white.opacity(0.5)).frame(width: 5, height: 5)
                        }
                    }
                    .frame(width: 26, height: 26)
                    .opacity(jour.future ? 0.5 : 1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(Double(VignetteDecor.voilePanneau))))
    }

    /// Les jetons fixes de la palette choisie (StreakWidget.Teintes) : ils ne basculent pas la nuit.
    private var couleurs: TeintesSerie {
        TeintesSerie(entree.reglages)
    }
}

/// Les couleurs de la vignette (StreakWidget.Teintes) : day_done, brand_dark, mint, stage_soft, on_plate de la palette
/// choisie, qui ne basculent pas la nuit ; celles d'origine sans palettes.json.
struct TeintesSerie {
    let mint: Color
    let pastille: Color
    let surPastille: Color
    let fonce: Color
    /// Les deux bouts du dégradé : « day_done » et « brand_dark », en ARGB.
    let jourFait: UInt32
    let brandDark: UInt32

    init(_ reglages: Reglages) {
        if let palette = CouleursWidgets.palette(reglages, nuit: false) {
            mint = CouleursWidgets.couleur(palette[.mint])
            pastille = CouleursWidgets.couleur(palette[.stageSoft])
            surPastille = CouleursWidgets.couleur(palette[.onPlate])
            fonce = CouleursWidgets.couleur(palette[.brandDark])
            jourFait = VignetteDecor.argb(palette[.dayDone])
            brandDark = VignetteDecor.argb(palette[.brandDark])
        } else {
            mint = CouleursWidgets.couleur(0xFFDF_F5E8)
            pastille = CouleursWidgets.couleur(0xFFF1_FAF4)
            surPastille = CouleursWidgets.couleur(0xFF16_775A)
            fonce = CouleursWidgets.couleur(0xFF17_3C32)
            jourFait = 0xFF16_775A
            brandDark = 0xFF17_3C32
        }
    }
}

/// Les anneaux du jour, de la semaine et de la série (AnneauxDessin), sur fond sombre, autour du personnage.
struct SerieAnneaux: View {
    let anneaux: Anneaux.Etat
    let enCours: Bool
    let fait: Bool

    var body: some View {
        GeometryReader { geo in
            let cote = min(geo.size.width, geo.size.height)
            let epaisseur = max(cote * 0.075, 5)
            ZStack {
                anneau(anneaux.serie, CouleursWidgets.serie, rayon: cote / 2, epaisseur: epaisseur)
                anneau(anneaux.semaine, CouleursWidgets.semaine, rayon: cote / 2 - epaisseur * 1.35, epaisseur: epaisseur)
                anneau(anneaux.jour, CouleursWidgets.menthe, rayon: cote / 2 - epaisseur * 2.7, epaisseur: epaisseur)
                Image(systemName: enCours ? "figure.mind.and.body" : (fait ? "checkmark" : "sun.horizon"))
                    .font(.system(size: cote * 0.2, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: cote, height: cote)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: TextesWidgets.texte(Libelle("widget_minutes", .entier(anneaux.jour.fait),
                                                                       .entier(anneaux.jour.objectif)))))
    }

    private func anneau(_ a: Anneaux.Anneau, _ couleur: Color, rayon: CGFloat, epaisseur: CGFloat) -> some View {
        let part = a.objectif > 0 ? min(Double(a.fait) / Double(a.objectif), 1) : 0
        return ZStack {
            Circle().stroke(Color.white.opacity(60.0 / 255), lineWidth: epaisseur)
            Circle()
                .trim(from: 0, to: part)
                .stroke(couleur, style: StrokeStyle(lineWidth: epaisseur, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: max(rayon * 2 - epaisseur, 1), height: max(rayon * 2 - epaisseur, 1))
    }
}

/// Le fond de la vignette : le dégradé de la couleur des boutons choisie, plus sombre la nuit (VignetteDecor).
private struct SerieFond: View {
    let reglages: Reglages
    @Environment(\.colorScheme) private var schema

    var body: some View {
        let teintes = TeintesSerie(reglages)
        let bouts = VignetteDecor.degrade(jourFait: teintes.jourFait, brandDark: teintes.brandDark, nuit: schema == .dark)
        LinearGradient(colors: [CouleursWidgets.couleur(bouts.clair), CouleursWidgets.couleur(bouts.fonce)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct SerieWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: GenresWidgets.serie, provider: FournisseurSerie()) { entree in
            SerieVue(entree: entree)
                .containerBackground(for: .widget) { SerieFond(reglages: entree.reglages) }
                .widgetURL(entree.enCours ? LienApp.seance(demarrer: false).url : LienApp.accueil.url)
                .environment(\.locale, TextesWidgets.locale)
                .environment(\.layoutDirection, TextesWidgets.deDroiteAGauche ? .rightToLeft : .leftToRight)
        }
        .configurationDisplayName(Text(verbatim: TextesWidgets.texte("widget_label")))
        .description(Text(verbatim: TextesWidgets.texte("widget_description")))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
