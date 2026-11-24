import Foundation
import SwiftUI
import Coeur
import Ecrans

/// La carte de la source du jour (SourceDuJour.carte d'Android) : « Source du jour », un paragraphe des sources de
/// la bibliothèque, sa référence, et « Lire la suite ». Sur Android, elle n'est pas dans l'onglet Textes : c'est la
/// dernière carte de `accueil_moment`, sur l'onglet Aujourd'hui, qui peut la poser telle quelle
/// (`TextesSourceDuJour.choisir(bibliotheque, jour:, langue:, police:)` ou `TextesModele.sourceDuJour`).
///
/// La marge extérieure (12 au-dessus sur Android) revient à la pile qui pose la carte. « Lire la suite » ouvre
/// l'entrée de la bibliothèque (`TextesRoute.entreeBibliotheque`), un autre écran : `ouvrir` la reçoit.
public struct TextesSourceDuJourVue: View {
    private let carte: TextesSourceDuJour
    private let police: PoliceHebraique.Police
    private let ouvrir: @MainActor (TextesRoute) -> Void

    @Environment(\.traducteur) private var traducteur

    /// - Parameters:
    ///   - carte: la source du jour, son extrait déjà masqué pour `police`.
    ///   - police: la police hébraïque choisie (`TextesModele.police`).
    ///   - ouvrir: l'entrée de la bibliothèque (LibraryEntryActivity).
    public init(carte: TextesSourceDuJour, police: PoliceHebraique.Police,
                ouvrir: @escaping @MainActor (TextesRoute) -> Void) {
        self.carte = carte
        self.police = police
        self.ouvrir = ouvrir
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 12 sp, capitales, espacement 0,06 em, couleur de marque.
            Text(carte.entete, traducteur: traducteur)
                .font(.caption)
                .textCase(.uppercase)
                .tracking(0.7)
                .foregroundStyle(Teinte(.brand))
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            // 18 sp, interligne + 4, encre ; de droite à gauche, aligné à droite (layoutDirection RTL et VIEW_START).
            Text(verbatim: carte.extrait)
                .policeHebraique(police, taille: 18)
                .lineSpacing(4)
                .foregroundStyle(Teinte(.ink))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .rightToLeft)
                .padding(.top, 8)
                .padding(.bottom, 4)
            // 13 sp, italique, discret.
            Text(verbatim: carte.reference)
                .font(Font.footnote.italic())
                .foregroundStyle(Teinte(.muted))
                .frame(maxWidth: .infinity, alignment: .leading)
            // Le bouton à contour, toute la largeur, 8 plus bas.
            Button {
                ouvrir(carte.route)
            } label: {
                Text(carte.bouton, traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondaire)
            .padding(.top, 8)
        }
        // bg_card, avec les marges intérieures de SourceDuJour.carte : 16, 12, 16, 8.
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Teinte(.card), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Teinte(.line), lineWidth: 1)
        }
    }
}
