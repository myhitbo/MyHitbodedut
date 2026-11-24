import Foundation
import SwiftUI
import Coeur
import Ecrans

/// La lecture des Tehilim (TehilimLectureActivity.kt, activity_tehilim_lecture.xml) : un psaume, ou une portion
/// d'un seul trait, avec le bouton de lecture (taille, nuit, police, langues). Un appui long sur un verset le marque
/// ou le démarque ; un psaume seul a ses boutons précédent et suivant. Pas d'image pendant une prière.
///
/// Tout se lit dans `TehilimLectureModele` ; la vue suit ses demandes de défilement (`defilement`) et lui signale
/// l'élément en haut de l'écran (`teteVisible`), pour qu'il garde la place quand la taille ou les langues changent.
public struct TehilimLectureVue: View {
    let modele: TehilimLectureModele

    @Environment(\.traducteur) private var traducteur
    /// Les tailles d'Android, en sp, suivent la taille du texte du téléphone (Dynamic Type) comme le corps du texte.
    @ScaledMetric(relativeTo: .body) private var dynamique: CGFloat = 1

    /// La place dans le texte : les demandes de défilement du modèle y passent.
    @State private var position = ScrollPosition(idType: String.self)

    public init(modele: TehilimLectureModele) {
        self.modele = modele
    }

    public var body: some View {
        VStack(spacing: 0) {
            TehilimBandeau(titre: Text(modele.titre, traducteur: traducteur),
                           sousTitre: modele.sousTitre.map { Text($0, traducteur: traducteur) },
                           image: nil)
            texte
            if modele.navigationVisible {
                pied
            }
        }
        .background(Teinte(.paper))
        .overlay(alignment: .bottom) {
            annonces
        }
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .task { await modele.charger() }
    }

    // MARK: Les mesures

    private var rendu: TehilimRendu {
        TehilimRendu(sombre: modele.barre.sombre)
    }

    /// L'échelle du texte : celle du bouton de lecture, par celle du téléphone.
    private var echelle: CGFloat {
        CGFloat(modele.barre.echelle) * dynamique
    }

    private var police: PoliceHebraique.Police {
        modele.barre.police
    }

    // MARK: Le texte

    private var texte: some View {
        ScrollView {
            contenu
                .padding(.top, 12)
                // 88 sous le texte, et 72 pour lire au-dessus de la barre de lecture.
                .padding(.bottom, 160)
        }
        .scrollPosition($position, anchor: .top)
        .scrollIndicators(.visible)
        .background(rendu.fond)
        .onScrollTargetVisibilityChange(idType: String.self) { visibles in
            if let premier = visibles.first {
                modele.teteVisible(premier)
            }
        }
        .onScrollGeometryChange(for: Double.self, of: { geometrie in
            Double(geometrie.contentOffset.y)
        }, action: { ancien, nouveau in
            modele.barre.defilementVertical(nouveau - ancien)
        })
        .onChange(of: modele.defilement) { _, demande in
            guard let demande else { return }
            if let cible = demande.cible {
                position.scrollTo(id: cible, anchor: .top)
            } else {
                position.scrollTo(edge: .top)
            }
        }
        .overlay(alignment: .bottom) {
            TehilimBarreVue(barre: modele.barre)
                .padding(.bottom, 16)
        }
    }

    @ViewBuilder
    private var contenu: some View {
        switch modele.etat {
        case .erreur:
            Text("contenu_illisible", tableName: "ios")
                .font(.subheadline)
                .foregroundStyle(rendu.discret)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
        case .chargement, .pret:
            psaumes
        }
    }

    /// Les titres et les versets, chacun cible de défilement (son id).
    private var psaumes: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(modele.psaumes) { psaume in
                titre(psaume)
                    .id(psaume.id)
                ForEach(psaume.versets) { verset in
                    versetVue(verset, premier: psaume.versets.first?.id == verset.id)
                        .id(verset.id)
                }
            }
        }
        .scrollTargetLayout()
    }

    private func titre(_ psaume: TehilimPsaume) -> some View {
        Text(psaume.titre, traducteur: traducteur)
            .font(Font.hebreu(police, taille: 20 * echelle).bold())
            .foregroundStyle(rendu.titre)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, psaume.premier ? 0 : 24)
            .padding(.bottom, 12)
            .padding(.horizontal, 16)
            .environment(\.layoutDirection, .rightToLeft)
            .gestesTehilim(modele.barre)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func versetVue(_ verset: TehilimVerset, premier: Bool) -> some View {
        if modele.hebreuSeul {
            versetContinu(verset, premier: premier)
        } else {
            versetTraduit(verset)
        }
    }

    // MARK: L'hébreu seul

    /// Un verset du bloc d'hébreu seul : son numéro petit et discret, puis le verset ; une demi-ligne vide le sépare
    /// du précédent. Marqué, son numéro prend la couleur des titres et un trait de cette couleur borde son début
    /// (le QuoteSpan d'Android, à droite en hébreu).
    private func versetContinu(_ verset: TehilimVerset, premier: Bool) -> some View {
        let taille = 19 * echelle
        return hebreu(verset, taille: taille)
            .padding(.leading, verset.marque ? 6 : 0)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(rendu.titre)
                    .frame(width: 2)
                    .opacity(verset.marque ? 1 : 0)
                    .accessibilityHidden(true)
            }
            // 4 au-dessus du bloc ; entre deux versets, la demi-ligne (0,4 ligne et son interligne).
            .padding(.top, premier ? 4 : taille * 0.5 + 8 * echelle)
            .padding(.horizontal, 16)
            .environment(\.layoutDirection, .rightToLeft)
            .gestesTehilim(modele.barre)
            .modifier(TehilimMarqueVerset(modele: modele, verset: verset))
    }

    /// L'hébreu d'un verset, précédé de son numéro en lettres à 70 % de la taille.
    private func hebreu(_ verset: TehilimVerset, taille: CGFloat) -> some View {
        let numero = Text(verbatim: verset.numero + " ")
            .font(Font.hebreu(police, taille: taille * 0.7))
            .foregroundStyle(verset.marque ? rendu.titre : rendu.discret)
        let corps = Text(verbatim: verset.hebreu ?? "")
        return Text("\(numero)\(corps)")
            .font(Font.hebreu(police, taille: taille))
            .foregroundStyle(rendu.texte)
            .lineSpacing(8 * echelle)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Avec une traduction

    /// Un bloc par verset : l'hébreu s'il est lu, puis ses traductions l'une sous l'autre. Marqué, le bloc a un fond
    /// arrondi de la couleur des titres, à 13 %.
    private func versetTraduit(_ verset: TehilimVerset) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if verset.hebreu != nil {
                hebreu(verset, taille: 19 * echelle)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            ForEach(Array(verset.traductions.enumerated()), id: \.element.id) { rang, traduction in
                traductionVue(traduction, verset: verset, rang: rang)
            }
        }
        .padding(EdgeInsets(top: 4, leading: 8, bottom: 6, trailing: 8))
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(rendu.titre.opacity(verset.marque ? 0x22 / 255.0 : 0))
        }
        .padding(.top, 12)
        .padding(.horizontal, 16)
        .gestesTehilim(modele.barre)
        .modifier(TehilimMarqueVerset(modele: modele, verset: verset))
    }

    /// Une traduction (LanguesTexte.vueTraduction) : de gauche à droite, police à empattements du système. Seule
    /// (sans l'hébreu), 18 pt et encre, son numéro en chiffres devant ; sous l'hébreu, 16 pt et discrète.
    private func traductionVue(_ traduction: TehilimTraduction, verset: TehilimVerset, rang: Int) -> some View {
        let seule = verset.hebreu == nil
        let taille = (seule ? 18 : 16) * echelle
        let corps = Text(verbatim: traduction.texte)
        let numero = Text(verbatim: rang == 0 ? (verset.numeroLatin.map { $0 + " " } ?? "") : "")
            .font(Font.system(size: taille * 0.75, design: .serif))
            .foregroundStyle(verset.marque ? rendu.titre : rendu.discret)
        return Text("\(numero)\(corps)")
            .font(Font.system(size: taille, design: .serif))
            .foregroundStyle(seule ? rendu.texte : rendu.discret)
            .lineSpacing(4 * echelle)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, verset.hebreu != nil || rang > 0 ? 4 : 0)
            .environment(\.layoutDirection, .leftToRight)
    }

    // MARK: Précédent, suivant

    private var pied: some View {
        HStack(spacing: 8) {
            Button {
                modele.precedent()
            } label: {
                Text(Libelle("tehilim_previous"), traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondaire)
            .opacity(modele.precedentVisible ? 1 : 0)
            .disabled(!modele.precedentVisible)
            .accessibilityHidden(!modele.precedentVisible)
            Button {
                modele.suivant()
            } label: {
                Text(Libelle("tehilim_next"), traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principal)
            .opacity(modele.suivantVisible ? 1 : 0)
            .disabled(!modele.suivantVisible)
            .accessibilityHidden(!modele.suivantVisible)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: Les messages

    private var annonces: some View {
        VStack(spacing: 8) {
            if let message = modele.message {
                TehilimMessageBref(message: message) {
                    modele.finMessage()
                }
            }
            if modele.barre.annonceMasque {
                TehilimAnnonceMasque(barre: modele.barre)
            }
        }
    }
}

/// Le marque-page d'un verset : un appui long le pose ou le retire (un message bref le dit), et VoiceOver a l'action
/// correspondante, Android n'ayant que l'appui long.
struct TehilimMarqueVerset: ViewModifier {
    let modele: TehilimLectureModele
    let verset: TehilimVerset
    @Environment(\.traducteur) private var traducteur

    init(modele: TehilimLectureModele, verset: TehilimVerset) {
        self.modele = modele
        self.verset = verset
    }

    func body(content: Content) -> some View {
        content
            .onLongPressGesture {
                basculer()
            }
            .accessibilityAction {
                basculer()
            } label: {
                Text(Libelle("lecture_marque_basculer"), traducteur: traducteur)
            }
    }

    private func basculer() {
        let psaume = verset.psaume
        let numero = verset.verset
        TehilimTache.lancer { _ = try await modele.basculerMarque(psaume: psaume, verset: numero) }
    }
}
