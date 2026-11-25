import AppIntents
import Coeur
import Ecrans
import Foundation
import SwiftUI
import WidgetKit

// MARK: - Le widget

/// Le widget de la série (StreakWidget.kt, demande du 28/09 : il suit la place qu'on lui donne) :
/// - petit : les anneaux et le hassid, la série en pastille ;
/// - moyen : les anneaux d'un côté, de l'autre la salutation, les minutes du jour en grands chiffres, la semaine et le
///   bouton ;
/// - grand : la semaine en sept pastilles et un texte de ’hizouk du jour en plus ;
/// - écran verrouillé : la série et sa flamme (rond), la série et l'état du jour (rectangle), la série en une ligne.
///
/// Les couleurs sont celles des réglages (VignetteDecor), le hassid prie pendant la séance, dont le temps défile en
/// direct (`Text(timerInterval:)` au lieu du Chronometer). Le toucher ouvre l'app, ou l'écran de la séance en cours ;
/// le bouton lance la séance (`myhitbodedut://commencer`), ou pendant qu'elle dure la termine sans rien ouvrir, par
/// l'intention « Terminer » de la Live Activity (`ActiviteSeanceTerminer`), que le système exécute dans l'app.
struct WidgetSerie: Widget {
    var body: some WidgetConfiguration {
        // Le nom et la description de la galerie, dans la langue de l'app.
        let traducteur = WidgetsRessources.traducteur(WidgetsDepot.langue())
        return StaticConfiguration(kind: WidgetsPartage.serie, provider: FournisseurSerie()) { entree in
            VueSerie(entree: entree)
        }
        .configurationDisplayName(Text(verbatim: traducteur.texte(cle: "widget_label")))
        .description(Text(verbatim: traducteur.texte(cle: "widget_description")))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

// MARK: - La chronologie

struct EntreeSerie: TimelineEntry, Sendable {
    let date: Date
    let affichage: VignetteSerie.Affichage
    let traducteur: Traducteur
    let apparence: WidgetsApparence

    func texte(_ libelle: Libelle) -> String {
        traducteur.texte(libelle)
    }

    /// La galerie et l'attente : un journal neuf, à l'instant.
    static func apercu() -> EntreeSerie {
        let maintenant = Date.now
        let langue = WidgetsDepot.langue()
        let affichage = VignetteSerie.affichage(journal: Journal(), reglages: Reglages(),
                                                maintenant: WidgetsHorloge.millis(maintenant),
                                                fuseauTelephone: WidgetsHorloge.fuseau, chizuk: nil, langue: langue)
        return EntreeSerie(date: maintenant, affichage: affichage, traducteur: WidgetsRessources.traducteur(langue),
                           apparence: WidgetsApparence(reglages: Reglages(), palettes: WidgetsRessources.palettes()))
    }
}

/// Une entrée à chaque changement connu d'avance (VignetteSerie.chronologie) : minuit, la salutation, la fin de la
/// séance. L'app recharge le widget quand le journal ou les réglages changent (SystemeWidgets.rafraichir).
struct FournisseurSerie: TimelineProvider {

    func placeholder(in context: Context) -> EntreeSerie {
        EntreeSerie.apercu()
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (EntreeSerie) -> Void) {
        let grande = context.family == .systemLarge
        Task {
            let calcul = await FournisseurSerie.calculer(maintenant: .now, avecTexte: grande)
            completion(calcul.entrees.first ?? EntreeSerie.apercu())
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<EntreeSerie>) -> Void) {
        let grande = context.family == .systemLarge
        Task {
            let calcul = await FournisseurSerie.calculer(maintenant: .now, avecTexte: grande)
            completion(Timeline(entries: calcul.entrees, policy: .after(calcul.recharge)))
        }
    }

    /// `avecTexte` : la grande seule lit les textes de ’hizouk.
    static func calculer(maintenant: Date, avecTexte: Bool) async -> (entrees: [EntreeSerie], recharge: Date) {
        let depot = await WidgetsDepot.lire()
        let traducteur = WidgetsRessources.traducteur(depot.langue)
        let apparence = WidgetsApparence(reglages: depot.reglages, palettes: WidgetsRessources.palettes())
        let chizuk = avecTexte ? WidgetsRessources.chizuk() : nil
        let fuseau = WidgetsHorloge.fuseau
        let chronologie = VignetteSerie.chronologie(reglages: depot.reglages, maintenant: WidgetsHorloge.millis(maintenant),
                                                    fuseauTelephone: fuseau)
        var entrees: [EntreeSerie] = []
        for instant in chronologie.instants {
            let affichage = VignetteSerie.affichage(journal: depot.journal, reglages: depot.reglages, maintenant: instant,
                                                    fuseauTelephone: fuseau, chizuk: chizuk, langue: depot.langue)
            entrees.append(EntreeSerie(date: WidgetsHorloge.date(instant), affichage: affichage,
                                       traducteur: traducteur, apparence: apparence))
        }
        return (entrees, WidgetsHorloge.date(chronologie.recharge))
    }
}

// MARK: - Les vues

struct VueSerie: View {
    let entree: EntreeSerie

    @Environment(\.widgetFamily) private var famille
    @Environment(\.colorScheme) private var schema

    var body: some View {
        let teintes = entree.apparence.teintes(schema)
        contenu(teintes)
            .containerBackground(for: .widget) {
                if VueSerie.estSurEcranAccueil(famille) {
                    WidgetsFondSerie(teintes: teintes)
                } else {
                    Color.clear
                }
            }
            .widgetURL(WidgetsLiens.url(entree.affichage.destination))
    }

    @ViewBuilder
    private func contenu(_ teintes: WidgetsTeintes) -> some View {
        switch famille {
        case .systemSmall:
            SeriePetite(entree: entree, teintes: teintes)
        case .systemLarge:
            SerieGrande(entree: entree, teintes: teintes)
        case .accessoryCircular:
            SerieRond(entree: entree)
        case .accessoryRectangular:
            SerieRectangle(entree: entree)
        case .accessoryInline:
            SerieLigne(entree: entree)
        default:
            SerieMoyenne(entree: entree, teintes: teintes)
        }
    }

    static func estSurEcranAccueil(_ famille: WidgetFamily) -> Bool {
        switch famille {
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge: true
        default: false
        }
    }
}

/// widget_small : les anneaux et le hassid, la série dans sa pastille en bas (ou le temps de la séance).
private struct SeriePetite: View {
    let entree: EntreeSerie
    let teintes: WidgetsTeintes

    var body: some View {
        GeometryReader { geo in
            let cote = max(min(geo.size.width, geo.size.height - 12) - 16, 40)
            ZStack(alignment: .bottom) {
                SerieJauge(affichage: entree.affichage, teintes: teintes, cote: cote)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(Text(verbatim: entree.texte(entree.affichage.lectureAnneaux)))
                SeriePastille(entree: entree, teintes: teintes, taille: 14)
                    .padding(.bottom, 8)
            }
        }
    }
}

/// widget_streak : les anneaux (deux cinquièmes), et à côté la salutation et la pastille, les minutes du jour (ou le
/// temps de la séance), la semaine, le bouton.
private struct SerieMoyenne: View {
    let entree: EntreeSerie
    let teintes: WidgetsTeintes

    var body: some View {
        GeometryReader { geo in
            let cote = max(min((geo.size.width - 40) * 0.4, geo.size.height - 24), 40)
            HStack(spacing: 12) {
                SerieJauge(affichage: entree.affichage, teintes: teintes, cote: cote)
                    .accessibilityLabel(Text(verbatim: entree.texte(entree.affichage.lectureAnneaux)))
                SerieColonne(entree: entree, teintes: teintes, tailleMinutes: 26)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// widget_large : la moyenne, puis la semaine en sept pastilles et le texte du jour sur un voile.
private struct SerieGrande: View {
    let entree: EntreeSerie
    let teintes: WidgetsTeintes

    var body: some View {
        GeometryReader { geo in
            let cote = max(min((geo.size.width - 44) * 0.4, 116), 40)
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    SerieJauge(affichage: entree.affichage, teintes: teintes, cote: cote)
                        .accessibilityLabel(Text(verbatim: entree.texte(entree.affichage.lectureAnneaux)))
                    SerieColonne(entree: entree, teintes: teintes, tailleMinutes: 28)
                }
                SerieSemaine(entree: entree, teintes: teintes)
                if let texte = entree.affichage.texteDuJour {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: texte.hebreu)
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(teintes.encre)
                            .lineLimit(3)
                            .environment(\.layoutDirection, .rightToLeft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(verbatim: texte.reference)
                            .font(.system(size: 11))
                            .foregroundStyle(teintes.douce)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(Double(VignetteDecor.voilePanneau))))
                    .frame(maxHeight: .infinity)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

/// La colonne de texte de la moyenne et de la grande.
private struct SerieColonne: View {
    let entree: EntreeSerie
    let teintes: WidgetsTeintes
    let tailleMinutes: CGFloat

    var body: some View {
        let a = entree.affichage
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(verbatim: entree.texte(a.salutation))
                    .font(.system(size: 12))
                    .foregroundStyle(teintes.douce)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SeriePastille(entree: entree, teintes: teintes, taille: 12, compteurPossible: false)
            }
            if a.compteurMontre, let seance = a.seance {
                SerieCompteur(seance: seance)
                    .font(.system(size: tailleMinutes, weight: .light).monospacedDigit())
                    .foregroundStyle(teintes.encre)
                    .lineLimit(1)
            } else {
                SerieMinutes(entree: entree, teintes: teintes, taille: tailleMinutes)
            }
            Text(verbatim: entree.texte(a.libelleSemaine))
                .font(.system(size: 12))
                .foregroundStyle(teintes.douce)
                .lineLimit(1)
            SerieBouton(entree: entree, teintes: teintes)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Le bouton : « Commencer » ouvre la séance qui part seule ; « Terminer maintenant » la clôt dans l'app, sans
/// l'ouvrir (le même service, la même action que le bouton de la notification d'Android).
private struct SerieBouton: View {
    let entree: EntreeSerie
    let teintes: WidgetsTeintes

    var body: some View {
        let a = entree.affichage
        if a.destinationBouton == .terminer {
            Button(intent: ActiviteSeanceTerminer()) {
                etiquette
            }
            .buttonStyle(.plain)
        } else if let lien = WidgetsLiens.url(a.destinationBouton) {
            Link(destination: lien) {
                etiquette
            }
        }
    }

    private var etiquette: some View {
        Text(verbatim: entree.texte(entree.affichage.bouton))
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(teintes.surPastille)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(teintes.pastille))
    }
}

/// « 12 / 20 min » : les minutes faites en grands chiffres, l'objectif et l'unité en plus petit, dans la couleur des
/// libellés (StreakWidget.minutes).
private struct SerieMinutes: View {
    let entree: EntreeSerie
    let teintes: WidgetsTeintes
    let taille: CGFloat

    var body: some View {
        let texte = entree.texte(entree.affichage.minutes)
        let nombre = String(entree.affichage.minutesFaites)
        if let plage = texte.range(of: nombre) {
            Text(verbatim: String(texte[..<plage.lowerBound]))
                .font(.system(size: taille * 0.5))
                .foregroundStyle(teintes.douce)
            + Text(verbatim: nombre)
                .font(.system(size: taille, weight: .light).monospacedDigit())
                .foregroundStyle(teintes.encre)
            + Text(verbatim: String(texte[plage.upperBound...]))
                .font(.system(size: taille * 0.5))
                .foregroundStyle(teintes.douce)
        } else {
            Text(verbatim: texte)
                .font(.system(size: taille, weight: .light))
                .foregroundStyle(teintes.encre)
        }
    }
}

/// Le temps de la séance en direct (Store.sessionCounter) : le temps restant d'une séance minutée, le temps passé
/// d'une séance ouverte. Le système le fait défiler sans redessiner le widget.
private struct SerieCompteur: View {
    let seance: VignetteSerie.Seance

    var body: some View {
        let debut = WidgetsHorloge.date(seance.debut)
        if seance.compteur == .reste {
            let fin = WidgetsHorloge.date(seance.fin)
            Text(timerInterval: debut...max(fin, debut), countsDown: true)
        } else {
            Text(timerInterval: debut...Date.distantFuture, countsDown: false)
        }
    }
}

/// La série dans sa pastille sombre : la flamme, allumée quand le jour est fait ou qu'il n'attend rien, et le compte ;
/// sur la petite, pendant la séance, le temps qui défile à la place du compte.
private struct SeriePastille: View {
    let entree: EntreeSerie
    let teintes: WidgetsTeintes
    let taille: CGFloat
    var compteurPossible = true

    var body: some View {
        let a = entree.affichage
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: taille * 0.9))
                .foregroundStyle(a.flammeAllumee ? teintes.flamme : teintes.encre.opacity(150 / 255))
            if compteurPossible, a.compteurMontre, let seance = a.seance {
                SerieCompteur(seance: seance)
                    .font(.system(size: taille, weight: .semibold).monospacedDigit())
                    .foregroundStyle(teintes.encre)
                    .lineLimit(1)
                    .fixedSize()
            } else {
                Text(verbatim: String(a.serie))
                    .font(.system(size: taille, weight: .semibold).monospacedDigit())
                    .foregroundStyle(teintes.encre)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.black.opacity(Double(VignetteDecor.voileBadge))))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: entree.texte(a.lectureSerie)))
    }
}

/// Les sept jours, comme sur l'accueil : fait (un disque plein et une coche), Shabbat (ש sur un disque voilé), pause
/// (un tiret), à faire (un cercle, franc pour aujourd'hui, pâle pour la suite). La lettre du jour au-dessus.
private struct SerieSemaine: View {
    let entree: EntreeSerie
    let teintes: WidgetsTeintes

    var body: some View {
        let lettres = SerieSemaine.lettres(entree.traducteur.langue)
        HStack(spacing: 0) {
            ForEach(entree.affichage.semaine, id: \.date) { jour in
                VStack(spacing: 3) {
                    Text(verbatim: lettres[(jour.date.jourDeSemaine - 1) % 7])
                        .font(.system(size: 10))
                        .foregroundStyle(jour.estAujourdhui ? teintes.encre : teintes.douce)
                        .lineLimit(1)
                    ZStack {
                        pastille(jour)
                            .frame(width: 22, height: 22)
                        Text(verbatim: marque(jour.marque))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(jour.etat == .fait ? teintes.surJourFait : teintes.douce)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func pastille(_ jour: VignetteSerie.Jour) -> some View {
        switch jour.etat {
        case .fait:
            Circle().fill(teintes.jourFait)
        case .repos:
            Circle().fill(teintes.encre.opacity(0x2E / 255))
        case .aujourdhui:
            Circle().strokeBorder(teintes.encre, lineWidth: 1.5)
        case .avenir:
            Circle().strokeBorder(teintes.encre.opacity(0x55 / 255), lineWidth: 1.5)
        case .passe:
            Circle().strokeBorder(teintes.encre.opacity(0x8C / 255), lineWidth: 1.5)
        }
    }

    private func marque(_ marque: VignetteSerie.Marque) -> String {
        switch marque {
        case .coche: "✓"
        case .chabbat: entree.traducteur.texte(cle: "week_shabbat_mark")
        case .tiret: "–"
        case .aucune: ""
        }
    }

    /// La lettre de chaque jour, du dimanche au samedi, dans la langue de l'app (le motif « EEEEE » d'Android).
    static func lettres(_ langue: String) -> [String] {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.locale = Locale(identifier: langue)
        let lettres = calendrier.veryShortStandaloneWeekdaySymbols
        return lettres.count == 7 ? lettres : ["S", "M", "T", "W", "T", "F", "S"]
    }
}

/// Les trois anneaux de l'accueil, le hassid en leur creux, sur un disque sombre qui les détache du dégradé, dans un
/// halo clair (StreakWidget.jauge, AnneauxDessin) : du centre vers l'extérieur le jour, la semaine, la série. Un
/// anneau qui dépasse son objectif repasse sur lui-même, plus sombre.
struct SerieJauge: View {
    let affichage: VignetteSerie.Affichage
    let teintes: WidgetsTeintes
    let cote: CGFloat

    @Environment(\.layoutDirection) private var sens
    @Environment(\.displayScale) private var echelle

    var body: some View {
        let retrait = cote * 0.06
        let s = cote - 2 * retrait
        let epaisseur = s * 0.062
        let ecart = s * 0.016
        let anneaux = affichage.anneaux
        let couleurs = [teintes.douce, teintes.semaine, teintes.flamme]
        let marge = 3 * epaisseur + 2 * ecart + s * 0.02
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color.white.opacity(Double(VignetteDecor.halo)),
                                              Color.white.opacity(Double(VignetteDecor.halo)), .clear],
                                     center: .center, startRadius: 0, endRadius: cote / 2))
            Circle()
                .fill(Color.black.opacity(Double(VignetteDecor.voileAnneaux)))
                .frame(width: s, height: s)
            ForEach(0..<3, id: \.self) { i in
                // Le jour au centre, la série dehors.
                let anneau = anneaux.duCentre[i]
                let diametre = s - epaisseur - CGFloat(2 - i) * 2 * (epaisseur + ecart)
                SerieAnneau(anneau: anneau, couleur: couleurs[i], epaisseur: epaisseur,
                            inverse: sens == .rightToLeft)
                    .frame(width: diametre, height: diametre)
            }
            Circle()
                .fill(teintes.plaque)
                .frame(width: s - 2 * marge, height: s - 2 * marge)
            if let image = WidgetsRessources.image(affichage.personnage,
                                                   cotePixels: Int((s - 2 * marge) * 1.4 * echelle)) {
                Image(decorative: image, scale: echelle)
                    .resizable()
                    .scaledToFill()
                    // Le plan rapproché : de la tête aux genoux, la tête juste sous le bord de la plaque.
                    .frame(width: s - 2 * marge, height: (s - 2 * marge) * 1.3, alignment: .top)
                    .offset(y: (s - 2 * marge) * 0.12)
                    .frame(width: s - 2 * marge, height: s - 2 * marge)
                    .clipShape(Circle())
            }
        }
        .frame(width: cote, height: cote)
        .environment(\.layoutDirection, .leftToRight)
    }
}

/// Un anneau : la piste pâle entière, le premier tour plein s'il est fait, puis le tour en cours depuis le haut dans
/// le sens de lecture.
private struct SerieAnneau: View {
    let anneau: Anneaux.Anneau
    let couleur: Color
    let epaisseur: CGFloat
    let inverse: Bool

    var body: some View {
        let reste = CGFloat(max(min(anneau.reste, 1), 0))
        ZStack {
            Circle()
                .stroke(Color.white.opacity(60 / 255), lineWidth: epaisseur)
            if anneau.tours >= 1 {
                Circle()
                    .stroke(couleur, lineWidth: epaisseur)
            }
            if reste > 0 {
                Circle()
                    .trim(from: 0, to: reste)
                    .stroke(anneau.tours >= 1 ? couleur.mix(with: .black, by: 0.25) : couleur,
                            style: StrokeStyle(lineWidth: epaisseur, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .scaleEffect(x: inverse ? -1 : 1, y: 1)
            }
        }
    }
}

// MARK: - L'écran verrouillé

/// La flamme et le compte, dans le rond de l'écran verrouillé.
private struct SerieRond: View {
    let entree: EntreeSerie

    var body: some View {
        let a = entree.affichage
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: a.flammeAllumee ? "flame.fill" : "flame")
                    .font(.system(size: 14, weight: .semibold))
                    .widgetAccentable()
                Text(verbatim: String(a.serie))
                    .font(.system(size: 20, weight: .semibold).monospacedDigit())
                    .minimumScaleFactor(0.6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: entree.texte(a.lectureSerie)))
    }
}

/// La série, et l'état du jour ou le temps de la séance.
private struct SerieRectangle: View {
    let entree: EntreeSerie

    var body: some View {
        let a = entree.affichage
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: a.flammeAllumee ? "flame.fill" : "flame")
                    .widgetAccentable()
                Text(verbatim: entree.texte(a.lectureSerie))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(verbatim: entree.texte(a.salutation))
                .font(.caption)
                .lineLimit(1)
            if a.compteurMontre, let seance = a.seance {
                SerieCompteur(seance: seance)
                    .font(.caption.monospacedDigit())
            } else {
                Text(verbatim: entree.texte(a.minutes))
                    .font(.caption.monospacedDigit())
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// La série en une ligne, au-dessus de l'heure.
private struct SerieLigne: View {
    let entree: EntreeSerie

    var body: some View {
        let a = entree.affichage
        Label {
            Text(verbatim: entree.texte(a.lectureSerie))
        } icon: {
            Image(systemName: a.flammeAllumee ? "flame.fill" : "flame")
        }
    }
}
