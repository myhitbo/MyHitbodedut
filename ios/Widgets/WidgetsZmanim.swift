import Coeur
import Ecrans
import Foundation
import SwiftUI
import WidgetKit

// MARK: - Le widget

/// Les vignettes des zmanim (ZmanimVignette.kt, demande du 28/10 : « trois différentes, trois tailles, très classe »),
/// sur un même fond de nuit verte :
/// - petite : la prière du moment, l'heure où elle se ferme, une jauge ;
/// - moyenne : la même, le temps qui reste, la série, les trois zmanim à venir ;
/// - grande : la même et la journée entière, le prochain zman en évidence ;
/// - écran verrouillé : la jauge et l'heure limite (rond), la prière, sa limite et le prochain zman (rectangle), la
///   prière et sa limite en une ligne.
///
/// La date hébraïque et la fête du jour, ou la paracha de la semaine, en tête ; elles changent à la sortie des étoiles
/// du lieu, comme le jour hébreu. Android les redessinait par une alarme au prochain changement (ZmanimTic) ; ici, une
/// chronologie d'une entrée par zman (Chronologies), et le temps qui reste défile seul. Le toucher ouvre les zmanim.
struct WidgetZmanim: Widget {
    var body: some WidgetConfiguration {
        let traducteur = WidgetsRessources.traducteur(WidgetsDepot.langue())
        return StaticConfiguration(kind: WidgetsPartage.zmanim, provider: FournisseurZmanim()) { entree in
            VueZmanim(entree: entree)
        }
        .configurationDisplayName(Text(verbatim: traducteur.texte(cle: "widget_zmanim_label")))
        .description(Text(verbatim: traducteur.texte(cle: "widget_zmanim_description")))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

// MARK: - La chronologie

struct EntreeZmanim: TimelineEntry, Sendable {
    let date: Date
    let affichage: VignetteZmanim.Affichage
    let traducteur: Traducteur

    func texte(_ libelle: Libelle) -> String {
        traducteur.texte(libelle)
    }

    /// La galerie et l'attente : sans lieu, à l'instant.
    static func apercu(_ famille: Chronologies.Famille = .moyenne) -> EntreeZmanim {
        let maintenant = Date.now
        let fuseau = WidgetsHorloge.fuseau
        let millis = WidgetsHorloge.millis(maintenant)
        let brut = Chronologies.affichage(famille: famille, lieu: nil, maintenant: millis, fuseauTelephone: fuseau,
                                          enIsrael: false)
        let affichage = VignetteZmanim.affichage(brut, famille: famille, maintenant: millis, fuseau: fuseau, serie: 0)
        return EntreeZmanim(date: maintenant, affichage: affichage,
                            traducteur: WidgetsRessources.traducteur(WidgetsDepot.langue()))
    }
}

struct FournisseurZmanim: TimelineProvider {

    func placeholder(in context: Context) -> EntreeZmanim {
        EntreeZmanim.apercu(FournisseurZmanim.famille(context.family))
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (EntreeZmanim) -> Void) {
        let famille = FournisseurZmanim.famille(context.family)
        Task {
            let calcul = await FournisseurZmanim.calculer(maintenant: .now, famille: famille)
            completion(calcul.entrees.first ?? EntreeZmanim.apercu(famille))
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<EntreeZmanim>) -> Void) {
        let famille = FournisseurZmanim.famille(context.family)
        Task {
            let calcul = await FournisseurZmanim.calculer(maintenant: .now, famille: famille)
            completion(Timeline(entries: calcul.entrees, policy: .after(calcul.recharge)))
        }
    }

    /// Les trois tailles d'Android ; l'écran verrouillé lit ce que lit la moyenne (les zmanim à venir).
    static func famille(_ famille: WidgetFamily) -> Chronologies.Famille {
        switch famille {
        case .systemSmall: .petite
        case .systemLarge, .systemExtraLarge: .grande
        default: .moyenne
        }
    }

    /// Une entrée à l'instant, puis à chaque zman du jour et au milieu de la nuit d'hier, jusqu'au minuit suivant du
    /// lieu (Chronologies) ; et une au minuit du téléphone, s'il vient avant, où la série change.
    static func calculer(maintenant: Date, famille: Chronologies.Famille) async
        -> (entrees: [EntreeZmanim], recharge: Date) {
        let depot = await WidgetsDepot.lire()
        let traducteur = WidgetsRessources.traducteur(depot.langue)
        let reglages = depot.reglages
        let telephone = WidgetsHorloge.fuseau
        let lieu = reglages.lieuZmanim
        let enIsrael = reglages.inIsrael(fuseauTelephone: telephone.identifiant)
        let zone = VignetteZmanim.fuseau(lieu: lieu, fuseauTelephone: telephone)
        let millis = WidgetsHorloge.millis(maintenant)
        let chronologie = Chronologies.chronologie(famille: famille, lieu: lieu, maintenant: millis,
                                                   fuseauTelephone: telephone, enIsrael: enIsrael)
        var bruts: [(instant: Int64, affichage: Chronologies.Affichage)] = chronologie.entrees.map {
            (instant: $0.instant, affichage: $0.affichage)
        }
        let minuitTelephone = telephone.millis(DateHeure(telephone.jour(millis: millis).plus(jours: 1)))
        if minuitTelephone > millis, minuitTelephone < chronologie.recharge,
           !bruts.contains(where: { $0.instant == minuitTelephone }) {
            let affichage = Chronologies.affichage(famille: famille, lieu: lieu, maintenant: minuitTelephone,
                                                   fuseauTelephone: telephone, enIsrael: enIsrael)
            bruts.append((instant: minuitTelephone, affichage: affichage))
            bruts.sort { $0.instant < $1.instant }
        }
        var entrees: [EntreeZmanim] = []
        for brut in bruts {
            let jour = telephone.jour(millis: brut.instant)
            let serie = Store.streak(journal: depot.journal, reglages: reglages, aujourdhui: jour,
                                     fuseauTelephone: telephone.identifiant)
            let affichage = VignetteZmanim.affichage(brut.affichage, famille: famille, maintenant: brut.instant,
                                                     fuseau: zone, serie: serie)
            entrees.append(EntreeZmanim(date: WidgetsHorloge.date(brut.instant), affichage: affichage,
                                        traducteur: traducteur))
        }
        return (entrees, WidgetsHorloge.date(chronologie.recharge))
    }
}

// MARK: - Les vues

struct VueZmanim: View {
    let entree: EntreeZmanim

    @Environment(\.widgetFamily) private var famille

    var body: some View {
        contenu
            .containerBackground(for: .widget) {
                if VueSerie.estSurEcranAccueil(famille) {
                    WidgetsFondNuit()
                } else {
                    Color.clear
                }
            }
            .widgetURL(WidgetsLiens.zmanim)
    }

    @ViewBuilder
    private var contenu: some View {
        switch famille {
        case .systemSmall:
            ZmanimPetite(entree: entree)
        case .systemLarge:
            ZmanimGrande(entree: entree)
        case .accessoryCircular:
            ZmanimRond(entree: entree)
        case .accessoryRectangular:
            ZmanimRectangle(entree: entree)
        case .accessoryInline:
            Text(verbatim: entree.texte(entree.affichage.ligne))
        default:
            ZmanimMoyenne(entree: entree)
        }
    }
}

/// La date hébraïque, et la fête ou la paracha dans sa pastille.
private struct ZmanimTete: View {
    let entree: EntreeZmanim
    let taille: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            Text(verbatim: entree.affichage.date)
                .font(.system(size: taille, design: .serif))
                .tracking(0.5)
                .foregroundStyle(WidgetsNuit.menthe)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let pastille = entree.affichage.pastille {
                Text(verbatim: entree.texte(pastille))
                    .font(.system(size: 11))
                    .foregroundStyle(WidgetsNuit.menthe)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
            }
        }
    }
}

/// La prière du moment et l'heure où elle se ferme.
private struct ZmanimPriere: View {
    let entree: EntreeZmanim
    let tailleLimite: CGFloat

    var body: some View {
        let a = entree.affichage
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: entree.texte(a.titre))
                .font(.system(size: 15, design: .serif))
                .foregroundStyle(WidgetsNuit.fort)
                .lineLimit(1)
            if let jusqua = a.jusqua {
                Text(verbatim: entree.texte(jusqua))
                    .font(.system(size: tailleLimite, weight: .light).monospacedDigit())
                    .foregroundStyle(WidgetsNuit.fort)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// « encore 1:23:45 » : le temps qui reste avant la limite, qui défile seul.
private struct ZmanimReste: View {
    let entree: EntreeZmanim

    var body: some View {
        if let limite = entree.affichage.limite {
            WidgetsPhraseMinutee(traducteur: entree.traducteur, cle: "widget_reste",
                                 jusqua: WidgetsHorloge.date(limite))
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(WidgetsNuit.doux)
                .lineLimit(1)
        }
    }
}

/// La part écoulée de la fenêtre de la prière (ZmanimVignette.ecoule), qui avance seule ; rien sans limite.
private struct ZmanimJauge: View {
    let entree: EntreeZmanim

    var body: some View {
        if let debut = entree.affichage.debut, let limite = entree.affichage.limite, limite > debut {
            ProgressView(timerInterval: WidgetsHorloge.date(debut)...WidgetsHorloge.date(limite), countsDown: false)
                .progressViewStyle(.linear)
                .labelsHidden()
                .tint(WidgetsNuit.menthe)
        }
    }
}

/// widget_zmanim_petit.
private struct ZmanimPetite: View {
    let entree: EntreeZmanim

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZmanimTete(entree: entree, taille: 12)
            Spacer(minLength: 0)
            ZmanimPriere(entree: entree, tailleLimite: 26)
            ZmanimJauge(entree: entree)
            ZmanimReste(entree: entree)
        }
        .padding(14)
    }
}

/// widget_zmanim : la prière et sa limite, le temps qui reste et la série, la jauge, les trois zmanim à venir.
private struct ZmanimMoyenne: View {
    let entree: EntreeZmanim

    var body: some View {
        let a = entree.affichage
        VStack(alignment: .leading, spacing: 8) {
            ZmanimTete(entree: entree, taille: 13)
            HStack(spacing: 12) {
                ZmanimPriere(entree: entree, tailleLimite: 30)
                    .layoutPriority(1.2)
                Rectangle()
                    .fill(Color.white.opacity(0x26 / 255))
                    .frame(width: 1, height: 44)
                VStack(alignment: .leading, spacing: 4) {
                    ZmanimReste(entree: entree)
                    if let serie = a.serie {
                        Text(verbatim: entree.texte(serie))
                            .font(.system(size: 11))
                            .foregroundStyle(WidgetsNuit.doux)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
            ZmanimJauge(entree: entree)
            if a.aLieu {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(0..<a.prochains.count, id: \.self) { k in
                        VStack(alignment: .leading, spacing: 1) {
                            if let ligne = a.prochains[k] {
                                Text(verbatim: entree.texte(ligne.nom))
                                    .font(.system(size: 10))
                                    .foregroundStyle(WidgetsNuit.pale)
                                    .lineLimit(1)
                                Text(verbatim: ligne.heure)
                                    .font(.system(size: 15).monospacedDigit())
                                    .foregroundStyle(ligne.etat == .prochain ? WidgetsNuit.menthe : WidgetsNuit.fort)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(16)
    }
}

/// widget_zmanim_grand : la même et la journée entière, le prochain zman sur un bandeau.
private struct ZmanimGrande: View {
    let entree: EntreeZmanim

    var body: some View {
        let a = entree.affichage
        VStack(alignment: .leading, spacing: 8) {
            ZmanimTete(entree: entree, taille: 13)
            ZmanimPriere(entree: entree, tailleLimite: 30)
            HStack(spacing: 12) {
                ZmanimReste(entree: entree)
                if let serie = a.serie {
                    Text(verbatim: entree.texte(serie))
                        .font(.system(size: 11))
                        .foregroundStyle(WidgetsNuit.doux)
                        .lineLimit(1)
                }
            }
            ZmanimJauge(entree: entree)
            VStack(spacing: 0) {
                ForEach(0..<a.journee.count, id: \.self) { k in
                    let ligne = a.journee[k]
                    HStack {
                        Text(verbatim: entree.texte(ligne.nom))
                            .font(.system(size: 13))
                            .foregroundStyle(ZmanimGrande.couleurNom(ligne.etat))
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(verbatim: ligne.heure)
                            .font(.system(size: 13).monospacedDigit())
                            .foregroundStyle(ZmanimGrande.couleurHeure(ligne.etat))
                    }
                    .padding(.horizontal, 8)
                    .frame(maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(ligne.etat == .prochain ? 0.10 : 0)))
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(16)
    }

    static func couleurNom(_ etat: VignetteZmanim.EtatLigne) -> Color {
        switch etat {
        case .prochain: WidgetsNuit.menthe
        case .passe: WidgetsNuit.passe
        case .avenir: WidgetsNuit.doux
        }
    }

    static func couleurHeure(_ etat: VignetteZmanim.EtatLigne) -> Color {
        switch etat {
        case .prochain: WidgetsNuit.menthe
        case .passe: WidgetsNuit.passe
        case .avenir: WidgetsNuit.fort
        }
    }
}

// MARK: - L'écran verrouillé

/// La jauge de la prière autour de l'heure où elle se ferme ; sans limite, la prière seule.
private struct ZmanimRond: View {
    let entree: EntreeZmanim

    var body: some View {
        let a = entree.affichage
        if let debut = a.debut, let limite = a.limite, limite > debut, let heure = a.heureLimite {
            ProgressView(timerInterval: WidgetsHorloge.date(debut)...WidgetsHorloge.date(limite), countsDown: false) {
                Text(verbatim: entree.texte(a.titre))
            } currentValueLabel: {
                Text(verbatim: heure)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .minimumScaleFactor(0.6)
            }
            .progressViewStyle(.circular)
            .widgetAccentable()
            .accessibilityLabel(Text(verbatim: entree.texte(a.ligne)))
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Text(verbatim: entree.texte(a.titre))
                    .font(.system(size: 11, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .padding(4)
            }
        }
    }
}

/// La prière et sa limite, le prochain zman.
private struct ZmanimRectangle: View {
    let entree: EntreeZmanim

    var body: some View {
        let a = entree.affichage
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: entree.texte(a.titre))
                .font(.headline)
                .widgetAccentable()
                .lineLimit(1)
            if let jusqua = a.jusqua {
                Text(verbatim: entree.texte(jusqua))
                    .font(.caption.monospacedDigit())
                    .lineLimit(1)
            }
            if let prochain = a.prochainZman {
                Text(verbatim: entree.texte(prochain.nom) + " " + prochain.heure)
                    .font(.caption.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else if a.aLieu == false {
                Text(verbatim: a.date)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
