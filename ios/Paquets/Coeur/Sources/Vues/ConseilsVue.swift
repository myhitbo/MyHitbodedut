import Foundation
import SwiftUI
import Coeur
import Ecrans

/// Les conseils pour la hitbodedout (TipsActivity.kt, activity_tips.xml, item_tip.xml) : dix cartes, en lecture
/// seule. La vue lit `ConseilsModele` (Ecrans) ; elle est poussée sur la pile de navigation de l'onglet
/// Aujourd'hui et n'en ouvre pas d'autre.
///
/// Le bandeau d'Android (bg_hero), qui s'efface au défilement (BandeauDefilant), devient la barre de navigation
/// d'iOS en grand titre, qui se réduit d'elle-même (PORTAGE.md) ; sa ligne d'indication ouvre la liste.
public struct ConseilsVue: View {
    private let modele: ConseilsModele
    @Environment(\.traducteur) private var traducteur

    public init(modele: ConseilsModele) {
        self.modele = modele
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text(modele.indication, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.muted))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                ForEach(modele.lignes) { ligne in
                    ConseilsCarte(ligne: ligne)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Teinte(.paper))
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.large)
    }
}

/// Une carte (item_tip.xml) : la pastille ronde du rang, le titre, l'image sur sa scène discrète, puis le texte.
/// Fond `card`, filet `line`, coins de 20, 16 de marge intérieure. VoiceOver la lit d'un trait ; l'image est
/// décorative (contentDescription null).
private struct ConseilsCarte: View {
    let ligne: ConseilsLigne
    @Environment(\.traducteur) private var traducteur
    /// bg_tip_number : 34 de diamètre, qui grandit avec la taille du texte.
    @ScaledMetric(relativeTo: .subheadline) private var diametre: CGFloat = 34

    // Écrit : la propriété privée `diametre` rendrait privé l'initialiseur par membres, hors de portée de
    // ConseilsVue.
    init(ligne: ConseilsLigne) {
        self.ligne = ligne
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            entete
            Text(ligne.corps, traducteur: traducteur)
                .font(.subheadline)
                .foregroundStyle(Teinte(.muted))
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .background(Teinte(.card), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Teinte(.line), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var entete: some View {
        HStack(spacing: 0) {
            Text(verbatim: ligne.numeroTexte)
                .font(Font.subheadline.bold())
                .foregroundStyle(Teinte(.onPlate))
                .frame(width: diametre, height: diametre)
                .background(Teinte(.mint), in: Circle())
            Text(ligne.titre, traducteur: traducteur)
                .font(Font.body.bold())
                .foregroundStyle(Teinte(.ink))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
            Illustration(decorative: ligne.illustration)
                .padding(4)
                .frame(width: 60, height: 70)
                .background(Teinte(.stageSoft), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.leading, 8)
        }
    }
}
