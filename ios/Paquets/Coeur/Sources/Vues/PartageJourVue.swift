import Foundation
import SwiftUI
import UIKit
import Coeur
import Ecrans

// Partager un jour (PartageJour.kt, 14/10) : le lien « Partager ce jour ↗ » de la carte du jour, et l'image de
// 1080 × 1350 qu'il envoie par la feuille de partage du système (le createChooser d'Android). Le contenu et la
// mise en page bloc par bloc viennent d'Ecrans (PartageContenu, PartageImage.blocs) ; ici, le dessin. Rien ne
// part sans le geste ; l'image reste dans le dossier temporaire de l'app, sous son nom (`jour-2026-10-12.png`).

/// Le lien de partage de la carte du jour : « Partager ce jour ↗ », au style LIEN. L'image est dessinée dès que le
/// jour, la palette, le mode ou la langue changent ; tant qu'elle ne l'est pas, le lien attend, inerte.
struct PartageJourLien: View {
    let contenu: PartageContenu
    let libelle: Libelle

    @Environment(\.traducteur) private var traducteur
    @Environment(\.paletteApp) private var palette
    @Environment(\.colorScheme) private var schema

    @State private var rendu: PartageJourRendu?

    init(contenu: PartageContenu, libelle: Libelle) {
        self.contenu = contenu
        self.libelle = libelle
    }

    var body: some View {
        let titre = traducteur.texte(libelle)
        let etiquette = ZmanimEtiquetteLien(texte: Text(verbatim: titre + " ↗"))
        Group {
            if let rendu {
                ShareLink(item: rendu.fichier, preview: SharePreview(Text(verbatim: titre), image: rendu.apercu)) {
                    etiquette
                }
                .buttonStyle(.plain)
            } else {
                etiquette
            }
        }
        .padding(.top, 4)
        .task(id: PartageJourCle(contenu: contenu, palette: palette, nuit: schema == .dark,
                                 langue: traducteur.langue)) {
            rendu = dessiner()
        }
    }

    /// L'image du jour (PartageJour.image), écrite en PNG sous son nom ; nil si elle n'a pu l'être.
    private func dessiner() -> PartageJourRendu? {
        let lignes = PartageImage.blocs(contenu).map { bloc in
            PartageJourLigne(bloc: bloc, texte: texte(bloc.texte))
        }
        let vue = PartageJourImage(lignes: lignes,
                                   fond: palette.couleur(PartageImage.fond, schema: schema),
                                   signature: traducteur.texte(PartageImage.signature))
        let rendeur = ImageRenderer(content: vue)
        // Un point de la vue pour un pixel de l'image : 1080 × 1350 px, comme le Bitmap d'Android.
        rendeur.scale = 1
        guard let image = rendeur.uiImage, let donnees = image.pngData() else { return nil }
        let fichier = FileManager.default.temporaryDirectory.appending(path: contenu.nomFichier)
        do {
            try donnees.write(to: fichier, options: .atomic)
        } catch {
            return nil
        }
        return PartageJourRendu(fichier: fichier, apercu: Image(uiImage: image))
    }

    /// Le texte d'un bloc dans la langue de l'app.
    private func texte(_ texte: PartageBloc.Texte) -> String {
        switch texte {
        case .brut(let brut):
            return brut
        case .libelles(let libelles, let separateur):
            return libelles.map { traducteur.texte($0) }.joined(separator: separateur)
        case .dateCivile(let jour):
            return ZmanimFormat.dateCivile(jour, langue: traducteur.langue)
        }
    }
}

/// L'image dessinée et son aperçu pour la feuille de partage.
private struct PartageJourRendu {
    let fichier: URL
    let apercu: Image
}

/// Ce dont dépend l'image : le jour et ses textes, la palette et le mode de l'écran, la langue.
private struct PartageJourCle: Equatable {
    let contenu: PartageContenu
    let palette: PaletteApp
    let nuit: Bool
    let langue: String
}

/// Un bloc et son texte résolu.
struct PartageJourLigne {
    let bloc: PartageBloc
    let texte: String

    init(bloc: PartageBloc, texte: String) {
        self.bloc = bloc
        self.texte = texte
    }
}

/// L'image de partage (PartageJour.image) : un aplat de la couleur sombre de l'accent, les blocs de haut en bas
/// à partir de y = 124, chacun à x = 84 sur 912 de large, puis la signature, sa ligne de base à (84 ; 1308).
/// Les mesures sont celles d'Android en pixels de l'image, dessinée à l'échelle 1.
struct PartageJourImage: View {
    let lignes: [PartageJourLigne]
    let fond: Color
    let signature: String

    init(lignes: [PartageJourLigne], fond: Color, signature: String) {
        self.lignes = lignes
        self.fond = fond
        self.signature = signature
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            fond
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lignes.enumerated()), id: \.offset) { _, ligne in
                    bloc(ligne)
                        .padding(.bottom, CGFloat(ligne.bloc.apres))
                }
            }
            .padding(.leading, CGFloat(PartageImage.marge))
            .padding(.top, CGFloat(PartageImage.haut))
        }
        .overlay(alignment: .topLeading) {
            // Un cadre haut de 1308 : la ligne de base de la signature, et non le bas de ses lettres, en est le bas.
            Color.clear
                .frame(width: CGFloat(PartageImage.largeur), height: CGFloat(PartageImage.signatureLigneDeBase))
                .overlay(alignment: .bottomLeading) {
                    Text(verbatim: signature)
                        .font(.system(size: CGFloat(PartageImage.signatureTaille), weight: .bold))
                        .foregroundStyle(Color.white.opacity(PartageImage.opaciteDouce))
                        .lineLimit(1)
                        .alignmentGuide(.bottom) { dimensions in dimensions[.lastTextBaseline] }
                        .alignmentGuide(.leading) { dimensions in
                            dimensions[.leading] - CGFloat(PartageImage.marge)
                        }
                }
        }
        .frame(width: CGFloat(PartageImage.largeur), height: CGFloat(PartageImage.hauteur))
        .clipped()
        .environment(\.layoutDirection, .leftToRight)
    }

    /// Un bloc : sa police, sa teinte, son interligne, son sens et son alignement.
    private func bloc(_ ligne: PartageJourLigne) -> some View {
        let bloc = ligne.bloc
        let taille = CGFloat(bloc.taille)
        let rtl = bloc.sens == .droiteAGauche || PartageJourImage.commenceDeDroiteAGauche(ligne.texte)
        // droiteAGauche : calé contre la marge gauche (ALIGN_OPPOSITE), soit la fin d'un paragraphe de droite à
        // gauche ; premierFort : calé au début de son sens.
        let fin = bloc.sens == .droiteAGauche
        return Text(verbatim: ligne.texte)
            .bold(bloc.gras)
            .font(police(bloc, taille: taille))
            .foregroundStyle(Color.white.opacity(bloc.teinte == .douce ? PartageImage.opaciteDouce : 1))
            // `setLineSpacing(0f, 1.25f)` : un quart de la hauteur de ligne en plus.
            .lineSpacing(taille * 1.2 * (CGFloat(PartageImage.interligne) - 1))
            .multilineTextAlignment(fin ? .trailing : .leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: CGFloat(PartageImage.largeurTexte), alignment: fin ? .trailing : .leading)
            .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
    }

    /// Frank Ruhl Libre pour l'hébreu (la police d'Android, `R.font.frank_ruhl`), la police du système sinon.
    private func police(_ bloc: PartageBloc, taille: CGFloat) -> Font {
        switch bloc.police {
        case .hebraique:
            return .hebreu(.frank, taille: taille)
        case .systeme:
            return .system(size: taille)
        }
    }

    /// `FIRSTSTRONG_LTR` : le sens de la première lettre forte, de gauche à droite à défaut.
    static func commenceDeDroiteAGauche(_ texte: String) -> Bool {
        for scalaire in texte.unicodeScalars where scalaire.properties.isAlphabetic {
            let v = scalaire.value
            return (0x0590...0x08FF).contains(v) || (0xFB1D...0xFDFF).contains(v) || (0xFE70...0xFEFF).contains(v)
        }
        return false
    }
}
