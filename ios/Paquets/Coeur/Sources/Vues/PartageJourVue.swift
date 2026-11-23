import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Coeur
import Ecrans

/// « Partager ce jour ↗ » (PartageJour.kt, 14/10), au bas de la carte du jour de Zmanim et du calendrier : une image
/// de 1080 × 1350 — la date hébraïque et la date civile, les fêtes, la hilloula et le début de la halakha du jour — sur
/// la couleur sombre de l'accent choisi, signée du nom de l'app. Les blocs et leurs mesures viennent d'`PartageImage`
/// (Ecrans, testé sous Linux) ; l'image n'est dessinée qu'au moment de partager.
struct PartageJourLien: View {
    let contenu: PartageContenu
    let libelle: Libelle
    @Environment(\.traducteur) private var traducteur
    @Environment(\.paletteApp) private var palette

    init(contenu: PartageContenu, libelle: Libelle) {
        self.contenu = contenu
        self.libelle = libelle
    }

    var body: some View {
        let partage = PartageJourImage(contenu: contenu, traducteur: traducteur,
                                       fond: palette.couleur(PartageImage.fond, nuit: false))
        let titre = LocalizedStringResource(String.LocalizationValue(contenu.dateHebraique))
        ShareLink(item: partage, preview: SharePreview(titre)) {
            Text(verbatim: traducteur.texte(libelle) + " ↗")
                .font(Font.subheadline.weight(.semibold))
                .foregroundStyle(Teinte(.brand))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }
}

/// L'image à partager, rendue en PNG quand l'app qui la reçoit la demande.
struct PartageJourImage: Transferable {
    let contenu: PartageContenu
    let traducteur: Traducteur
    let fond: Couleur

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { partage in
            try await partage.png()
        }
    }

    enum Erreur: Error {
        case rendu
    }

    @MainActor
    func png() throws -> Data {
        let rendu = ImageRenderer(content: PartageJourDessin(contenu: contenu, traducteur: traducteur, fond: fond))
        rendu.scale = 1
        guard let image = rendu.uiImage, let donnees = image.pngData() else { throw Erreur.rendu }
        return donnees
    }
}

/// Le dessin de l'image (PartageJour.image), en pixels : un point vaut un pixel au rendu.
private struct PartageJourDessin: View {
    let contenu: PartageContenu
    let traducteur: Traducteur
    let fond: Couleur

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(fond)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(PartageImage.blocs(contenu).enumerated()), id: \.offset) { _, bloc in
                    texte(bloc)
                        .padding(.bottom, bloc.apres)
                }
            }
            .frame(width: PartageImage.largeurTexte, alignment: .leading)
            .padding(.leading, PartageImage.marge)
            .padding(.top, PartageImage.haut)
        }
        .frame(width: CGFloat(PartageImage.largeur), height: CGFloat(PartageImage.hauteur), alignment: .topLeading)
        .overlay(alignment: .bottomLeading) {
            // La signature, sa ligne de base à `marge / 2` du bas.
            Text(verbatim: traducteur.texte(PartageImage.signature))
                .font(.system(size: PartageImage.signatureTaille, weight: .bold))
                .foregroundStyle(Color.white.opacity(PartageImage.opaciteDouce))
                .padding(.leading, PartageImage.marge)
                .padding(.bottom, CGFloat(PartageImage.hauteur) - PartageImage.signatureLigneDeBase - 6)
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    @ViewBuilder
    private func texte(_ bloc: PartageBloc) -> some View {
        let chaine: String = {
            switch bloc.texte {
            case .brut(let texte): return texte
            case .libelles(let libelles, let separateur): return libelles.map { traducteur.texte($0) }.joined(separator: separateur)
            case .dateCivile(let jour): return HalakhaDateCivile.texte(jour, langue: Traducteur.identifiantLocale(traducteur.langue))
            }
        }()
        let police: Font = bloc.police == .hebraique
            ? Font.hebreu(.frank, taille: bloc.taille)
            : Font.system(size: bloc.taille)
        Text(verbatim: chaine)
            .font(police)
            .bold(bloc.gras)
            .foregroundStyle(Color.white.opacity(bloc.teinte == .douce ? PartageImage.opaciteDouce : 1))
            .lineSpacing(bloc.taille * (PartageImage.interligne - 1))
            .multilineTextAlignment(bloc.sens == .droiteAGauche ? .trailing : .leading)
            .frame(width: PartageImage.largeurTexte, alignment: bloc.sens == .droiteAGauche ? .trailing : .leading)
            .environment(\.layoutDirection, bloc.sens == .droiteAGauche ? .rightToLeft : .leftToRight)
    }
}
