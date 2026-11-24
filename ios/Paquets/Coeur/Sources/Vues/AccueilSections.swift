import Foundation
import SwiftUI
import Coeur
import Ecrans

// Les sections de l'accueil autour de la jauge (activity_main.xml, main_scroll ; MainActivity.renderToday,
// renderPaliers, renderWeek) : l'en-tête, la ligne du trophée, les pastilles de départ, la bande de la semaine.
// Elles lisent ce que le modèle a préparé et rendent les gestes au modèle.

// MARK: L'en-tête

/// Le nom de l'app, la salutation, l'état du jour, la série et le total, le détail d'une journée faite.
struct AccueilEnteteVue: View {
    let modele: AccueilModele

    @Environment(\.traducteur) private var traducteur

    init(modele: AccueilModele) {
        self.modele = modele
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(modele.nomApp, traducteur: traducteur)
                .tropheeTexte(13, interlettrage: 0.08)
                .foregroundStyle(Teinte(.muted))
            if let salutation = modele.salutation {
                Text(salutation, traducteur: traducteur)
                    .tropheeTexte(26, gras: true)
                    .foregroundStyle(Teinte(.ink))
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)
            }
            etat
                .padding(.top, 8)
            ligneSerie
                .padding(.top, 8)
            if let detail = modele.detailDuJour {
                Text(detail, traducteur: traducteur)
                    .policeHebraique(.arrondie, taille: 16, relativeA: .body)
                    .foregroundStyle(Teinte(.brand))
                    .padding(.top, 8)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Sans prénom, l'état est le titre (20 pt, gras, police du système) ; sinon une ligne de Varela Round.
    @ViewBuilder
    private var etat: some View {
        if modele.etatEstTitre {
            Text(modele.titreEtat, traducteur: traducteur)
                .tropheeTexte(20, gras: true)
                .lineSpacing(4)
                .foregroundStyle(Teinte(.ink))
                .accessibilityAddTraits(.isHeader)
        } else {
            Text(modele.titreEtat, traducteur: traducteur)
                .policeHebraique(.arrondie, taille: 15, relativeA: .subheadline)
                .lineSpacing(3)
                .foregroundStyle(Teinte(.muted))
        }
    }

    /// La série, puis « · » et le total (le point est passé par VoiceOver).
    private var ligneSerie: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(modele.ligneSerie, traducteur: traducteur)
                .policeHebraique(.arrondie, taille: 15, relativeA: .subheadline)
                .monospacedDigit()
                .foregroundStyle(Teinte(.muted))
                .fixedSize(horizontal: false, vertical: true)
            if let total = modele.ligneTotal {
                Text(modele.separateur, traducteur: traducteur)
                    .policeHebraique(.arrondie, taille: 15, relativeA: .subheadline)
                    .foregroundStyle(Teinte(.muted))
                    .padding(.horizontal, 8)
                    .accessibilityHidden(true)
                Text(total, traducteur: traducteur)
                    .policeHebraique(.arrondie, taille: 15, relativeA: .subheadline)
                    .monospacedDigit()
                    .foregroundStyle(Teinte(.muted))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: La ligne du trophée

/// Le grade et le prochain trophée (paliers_line) : la médaille du grade, le texte suivi de « › » ; un toucher
/// ouvre les paliers. Les étincelles d'un palier neuf éclatent autour de la médaille.
struct AccueilLigneTropheeVue: View {
    let ligne: AccueilLigneTrophee
    let fete: TropheeFeteModele
    let formes: TropheeFormes
    let ouvrir: @MainActor () -> Void

    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var reduire
    @State private var etincelles = false
    @State private var feteJouee = 0

    init(ligne: AccueilLigneTrophee, fete: TropheeFeteModele, formes: TropheeFormes,
         ouvrir: @escaping @MainActor () -> Void) {
        self.ligne = ligne
        self.fete = fete
        self.formes = formes
        self.ouvrir = ouvrir
    }

    var body: some View {
        Button(action: ouvrir) {
            HStack(spacing: 8) {
                TropheeObjet(formes.medaille(ligne.grade))
                    .frame(width: 26, height: 26)
                    .overlay {
                        if etincelles, let metal = fete.etincelles {
                            TropheeEtincelles(teintes: TropheeTeintes.de(metal))
                        }
                    }
                // Deux espaces et « › » (U+203A), comme Android.
                Text(verbatim: traducteur.texte(ligne.texte) + "  \u{203A}")
                    .font(Font.subheadline.bold())
                    .foregroundStyle(Teinte(.brand))
                    .multilineTextAlignment(.center)
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text(verbatim: AccueilEcriture.joints(ligne.accessibilite, traducteur, separateur: ". ")))
        .task(id: fete.fetesPalier) {
            await eclater()
        }
    }

    /// Les étincelles du grade, `retardEtincelles` après l'accueil, le temps qu'elles durent.
    private func eclater() async {
        guard fete.fetesPalier != feteJouee else { return }
        feteJouee = fete.fetesPalier
        guard fete.etincelles != nil, !reduire else { return }
        guard await TropheeAttente.ms(TropheeFeteModele.retardEtincelles) else { return }
        etincelles = true
        guard await TropheeAttente.ms(1150) else { return }
        etincelles = false
    }
}

// MARK: Les pastilles

/// Les pastilles sous « Commencer » (start_chips) : une rangée qui défile de côté, sans indicateur, ses bords
/// fondus sur 28 pt quand il reste des pastilles de ce côté.
struct AccueilPastillesVue: View {
    let pastilles: [AccueilPastille]
    let toucher: @MainActor (AccueilPastilleGenre) -> Void

    @State private var bords = AccueilBords(debut: false, fin: false)

    init(pastilles: [AccueilPastille], toucher: @escaping @MainActor (AccueilPastilleGenre) -> Void) {
        self.pastilles = pastilles
        self.toucher = toucher
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(pastilles) { pastille in
                    AccueilPastilleVue(pastille: pastille) {
                        toucher(pastille.genre)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: AccueilBords.self) { geometrie in
            AccueilBords(geometrie)
        } action: { _, nouveaux in
            bords = nouveaux
        }
        .mask {
            HStack(spacing: 0) {
                LinearGradient(colors: [bords.debut ? Color.clear : Color.black, Color.black],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: 28)
                Rectangle()
                LinearGradient(colors: [Color.black, bords.fin ? Color.clear : Color.black],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: 28)
            }
        }
    }
}

/// Ce qui reste à faire défiler de chaque côté de la rangée.
struct AccueilBords: Equatable {
    let debut: Bool
    let fin: Bool

    init(debut: Bool, fin: Bool) {
        self.debut = debut
        self.fin = fin
    }

    init(_ geometrie: ScrollGeometry) {
        let x = geometrie.contentOffset.x + geometrie.contentInsets.leading
        debut = x > 0.5
        fin = geometrie.contentOffset.x + geometrie.containerSize.width
            < geometrie.contentSize.width + geometrie.contentInsets.trailing - 0.5
    }
}

/// Une pastille (StartChip) : l'étiquette atténuée, puis la valeur en gras à la couleur de l'accent, sur une ligne
/// de 160 pt au plus ; VoiceOver la lit d'un trait.
private struct AccueilPastilleVue: View {
    let pastille: AccueilPastille
    let action: @MainActor () -> Void

    @Environment(\.traducteur) private var traducteur

    init(pastille: AccueilPastille, action: @escaping @MainActor () -> Void) {
        self.pastille = pastille
        self.action = action
    }

    var body: some View {
        let auPlus160 = AccueilLargeurMax(largeur: 160)
        Button(action: action) {
            HStack(spacing: 6) {
                Text(pastille.etiquette, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
                    .lineLimit(1)
                auPlus160 {
                    Text(verbatim: AccueilEcriture.texte(pastille.valeur, traducteur))
                        .font(Font.footnote.bold())
                        .foregroundStyle(Teinte(.brand))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .background(Teinte(.card), in: Capsule())
            .overlay {
                Capsule().strokeBorder(Teinte(.line), lineWidth: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

/// Un enfant unique, jamais plus large que `largeur`, même quand on ne lui propose aucune largeur (une rangée qui
/// défile) : un texte trop long s'y coupe d'une ellipse (maxWidth="160dp" d'Android).
private struct AccueilLargeurMax: Layout {
    let largeur: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let vue = subviews.first else { return .zero }
        let offerte = min(proposal.width ?? largeur, largeur)
        return vue.sizeThatFits(ProposedViewSize(width: offerte, height: proposal.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let vue = subviews.first else { return }
        vue.place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading,
                  proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}

// MARK: La bande de la semaine

/// Les sept cases, du dimanche au samedi, jointives et de même largeur (week_strip, item_day.xml).
struct AccueilSemaineVue: View {
    let jours: [AccueilJourSemaine]
    let langue: String
    let ouvrir: @MainActor (JourCivil) -> Void

    init(jours: [AccueilJourSemaine], langue: String, ouvrir: @escaping @MainActor (JourCivil) -> Void) {
        self.jours = jours
        self.langue = langue
        self.ouvrir = ouvrir
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(jours) { jour in
                AccueilCaseJourVue(jour: jour, langue: langue, ouvrir: ouvrir)
            }
        }
    }
}

/// Une case : le jour en abrégé, sa marque, son fond ; un jour jusqu'à aujourd'hui s'ouvre d'un toucher.
private struct AccueilCaseJourVue: View {
    let jour: AccueilJourSemaine
    let langue: String
    let ouvrir: @MainActor (JourCivil) -> Void

    @Environment(\.traducteur) private var traducteur

    init(jour: AccueilJourSemaine, langue: String, ouvrir: @escaping @MainActor (JourCivil) -> Void) {
        self.jour = jour
        self.langue = langue
        self.ouvrir = ouvrir
    }

    private var lecture: Text {
        Text(verbatim: AccueilEcriture.joints(jour.accessibilite, traducteur, separateur: " · "))
    }

    var body: some View {
        if jour.ouvrable {
            Button {
                ouvrir(jour.date)
            } label: {
                cellule
            }
            .buttonStyle(AccueilBoutonCreux())
            .accessibilityLabel(lecture)
        } else {
            cellule
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(lecture)
        }
    }

    private var cellule: some View {
        VStack(spacing: 2) {
            Text(verbatim: AccueilDates.jourAbrege(jour.date, langue: langue))
                .font(.caption2)
                .foregroundStyle(AccueilTeinte(jour.couleurEtiquette))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(verbatim: AccueilEcriture.texte(jour.marque, traducteur))
                .tropheeTexte(jour.marqueReduite ? 12 : 16, gras: true)
                .monospacedDigit()
                .foregroundStyle(AccueilTeinte(jour.couleurMarque))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(fond, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            if jour.fond == .aujourdhui {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Teinte(.brand), lineWidth: 1.5)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// bg_day_done, bg_day_exempt, bg_day_today, bg_day_todo.
    private var fond: AnyShapeStyle {
        switch jour.fond {
        case .faite: return AnyShapeStyle(Teinte(.dayDone))
        case .exempte: return AnyShapeStyle(AccueilTeinteExempte())
        case .aujourdhui, .aFaire: return AnyShapeStyle(Teinte(.dayTodo))
        }
    }
}

// MARK: Les boutons texte

/// Un bouton texte sur toute la largeur (TextButton de Material) : « Écrire une note », « Je l'ai faite sans le
/// téléphone ».
struct AccueilBoutonTexte: View {
    let libelle: Libelle
    let action: @MainActor () -> Void

    @Environment(\.traducteur) private var traducteur

    init(libelle: Libelle, action: @escaping @MainActor () -> Void) {
        self.libelle = libelle
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(libelle, traducteur: traducteur)
                .font(Font.subheadline.weight(.medium))
                .foregroundStyle(Teinte(.brand))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
