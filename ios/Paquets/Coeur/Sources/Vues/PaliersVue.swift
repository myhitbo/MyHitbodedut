import Foundation
import SwiftUI
import UIKit
import Coeur
import Ecrans

/// L'écran « Trophées et paliers » (PaliersActivity.kt, activity_paliers.xml) : le bandeau fixe, puis ce qui
/// défile, la carte du grade (la médaille, la barre vers le suivant, les plus proches, le partage), le filtre par
/// famille, la ligne des trophées (gagnés, « Vous êtes ici », à venir) et les records. Tout se lit dans
/// `PaliersModele` ; la vue ne décide rien.
///
/// À chaque apparition (onResume d'Android) le modèle s'ouvre (`ouvrir()`), puis l'écran se place sur « Vous êtes
/// ici », le haut de sa carte au tiers de la hauteur. Un trophée touché ouvre sa fiche sur place
/// (`TropheeFicheVue`) ; un nouveau grade se fête en dialogue (`PaliersFeteGradeVue`) ; le partage du grade passe
/// par la feuille du système, avec l'image carrée de PaliersActivity.partager. L'écran n'ouvre aucun autre écran.
///
/// Le filtre choisi est gardé pour la scène (`@SceneStorage`, l'`onSaveInstanceState` d'Android) et rendu au
/// modèle à la première apparition si l'app ne l'a pas déjà construit avec.
public struct PaliersVue: View {
    private let modele: PaliersModele
    private let formes: TropheeFormes

    @Environment(\.traducteur) private var traducteur
    @Environment(\.paletteApp) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.scenePhase) private var phaseScene

    /// La clé de la famille montrée seule (`PaliersModele.filtreCle`), vide pour toutes.
    @SceneStorage("paliers_filtre") private var filtreGarde: String = ""
    /// La place de l'écran, pour les marges qui suivent sa largeur et sa hauteur (values-w600dp, values-h640dp…).
    @State private var taille: CGSize = .zero
    /// La première ouverture est faite : revenir d'une fiche plein écran ne rouvre pas l'écran (un dialogue
    /// d'Android ne relance pas onResume).
    @State private var ouvert = false
    /// L'app est passée au second plan : son retour rouvre l'écran (onPause puis onResume).
    @State private var auFond = false
    /// Chaque hausse fait défiler jusqu'à « Vous êtes ici » (`defile.post { scrollTo }` d'Android).
    @State private var demandeDefilement = 0
    /// L'image carrée du grade à partager, dessinée d'avance pour la feuille de partage.
    @State private var imagePartage: Image?

    /// - Parameters:
    ///   - modele: `PaliersModele(magasin:horloge:filtre:)`.
    ///   - formes: les formes des trophées (`TropheeFormes.lire`), lues une fois par l'app.
    public init(modele: PaliersModele, formes: TropheeFormes) {
        self.modele = modele
        self.formes = formes
    }

    public var body: some View {
        let mesures = PaliersMesures(taille: taille)
        VStack(spacing: 0) {
            PaliersBandeau(titre: Text(PaliersModele.titre, traducteur: traducteur),
                           image: modele.imageBandeau, mesures: mesures)
            defilement(mesures)
        }
        .background(Teinte(.paper))
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { nouvelle in
            taille = nouvelle
        }
        // Le titre nomme l'écran (le retour, VoiceOver) ; le bandeau le montre déjà : la barre ne le répète pas.
        .navigationTitle(Text(PaliersModele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(removing: .title)
        .tropheeFiche(modele.fiche, formes: formes, fermer: fermerFiche)
        .fullScreenCover(isPresented: feteOuverte) {
            if let fete = modele.feteGrade {
                PaliersFeteGradeVue(fete: fete, formes: formes, fermer: fermerFete)
                    .presentationBackground(.clear)
            }
        }
        .task {
            await premiereOuverture()
        }
        .task(id: PaliersCleImage(partage: modele.partage, palette: palette, nuit: schema == .dark,
                                  langue: traducteur.langue)) {
            imagePartage = dessinerImagePartage()
        }
        .onChange(of: modele.filtreCle) { _, cle in
            filtreGarde = cle ?? ""
            // Android redessine la ligne et se replace sur « Vous êtes ici ».
            demandeDefilement += 1
        }
        .onChange(of: phaseScene) { _, phase in
            switch phase {
            case .background:
                auFond = true
            case .active:
                if auFond {
                    auFond = false
                    Task { await ouvrir() }
                }
            default:
                break
            }
        }
    }

    // MARK: Ce qui défile

    private func defilement(_ mesures: PaliersMesures) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    enTete
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    filtres
                    ligne
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    records
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, mesures.gouttiere)
                .padding(.bottom, 24)
            }
            .onChange(of: demandeDefilement) { _, _ in
                // Le haut de la carte « Vous êtes ici » au tiers de la hauteur, sans animation ; rien sans elle.
                proxy.scrollTo(PaliersAncre.ici, anchor: UnitPoint(x: 0.5, y: 1.0 / 3.0))
            }
        }
    }

    // MARK: La carte du grade

    private var enTete: some View {
        let tete = modele.enTete
        return Carte {
            HStack(alignment: .center, spacing: 0) {
                TropheeObjet(formes.medaille(tete.grade))
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 0) {
                    Text(tete.titre, traducteur: traducteur)
                        .tropheeTexte(18, gras: true)
                        .foregroundStyle(Teinte(.ink))
                    Text(tete.sous, traducteur: traducteur)
                        .tropheeTexte(13)
                        .foregroundStyle(Teinte(.muted))
                        .padding(.top, 4)
                    if let barre = tete.barre {
                        TropheeBarre(fraction: Double(barre), hauteur: 6, couleur: tete.couleurBarre.couleurSwiftUI,
                                     monte: true)
                            // Android redessine tout à chaque filtre : la barre remonte de zéro.
                            .id(modele.filtreCle ?? "")
                            .padding(.top, 4)
                    }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
            }
            if let titre = tete.prochesTitre {
                Text(titre, traducteur: traducteur)
                    .tropheeTexte(13, gras: true, interlettrage: 0.04)
                    .foregroundStyle(Teinte(.muted))
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 12)
            }
            ForEach(tete.proches) { proche in
                ligneProche(proche)
            }
            if let partager = tete.partager {
                boutonPartage(partager)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
    }

    /// Un des plus proches : l'objet gris, ce qu'il demande, où l'on en est ; toucher ouvre sa fiche. VoiceOver
    /// le lit d'un trait, comme la `contentDescription` d'Android.
    private func ligneProche(_ proche: PaliersProche) -> some View {
        Button {
            ouvrirFiche(proche.niveau)
        } label: {
            HStack(alignment: .center, spacing: 0) {
                TropheeObjet(formes.dessin(proche.niveau, metal: nil))
                    .frame(width: 30, height: 30)
                    .opacity(0.85)
                Text(proche.description, traducteur: traducteur)
                    .tropheeTexte(14)
                    .foregroundStyle(Teinte(.ink))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 8)
                Text(proche.progres, traducteur: traducteur)
                    .tropheeTexte(13, gras: true)
                    .foregroundStyle(Teinte(.brand))
                    .fixedSize()
                    .padding(.leading, 8)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(TropheeAccessibilite.texte(proche.accessibilite, traducteur))
    }

    /// « Partager mon grade » : l'image du grade et sa phrase, par la feuille de partage du système (le
    /// createChooser d'Android). Tant que l'image n'est pas dessinée, la phrase seule.
    @ViewBuilder
    private func boutonPartage(_ libelle: Libelle) -> some View {
        let etiquette = Text(libelle, traducteur: traducteur)
            .tropheeTexte(15, gras: true)
            .foregroundStyle(Teinte(.brand))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        if let partage = modele.partage {
            if let image = imagePartage {
                ShareLink(item: image,
                          message: Text(partage.texte, traducteur: traducteur),
                          preview: SharePreview(Text(partage.titreChoix, traducteur: traducteur), image: image)) {
                    etiquette
                }
                .buttonStyle(.plain)
            } else {
                ShareLink(item: traducteur.texte(partage.texte)) {
                    etiquette
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Le filtre

    /// Les puces : « Tous », puis chaque famille ; la choisie pleine de l'accent, les autres cerclées.
    private var filtres: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(modele.filtres) { filtre in
                    puce(filtre)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
    }

    private func puce(_ filtre: PaliersFiltre) -> some View {
        Button {
            modele.choisirFiltre(filtre.famille)
        } label: {
            Text(filtre.titre, traducteur: traducteur)
                .tropheeTexte(14)
                .foregroundStyle(Teinte(filtre.choisi ? .onBrand : .ink))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .background {
                    PaliersFondPuce(choisi: filtre.choisi)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(filtre.accessibilite, traducteur: traducteur))
        .accessibilityAddTraits(filtre.choisi ? .isSelected : [])
    }

    // MARK: La ligne

    private var ligne: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(modele.lignes) { ligne in
                PaliersLigneVue(ligne: ligne, formes: formes, animer: modele.animer,
                                cleBarres: modele.filtreCle ?? "", ouvrirFiche: ouvrirFiche)
            }
        }
    }

    // MARK: Les records

    private var records: some View {
        let r = modele.records
        return Carte {
            Text(r.titre, traducteur: traducteur)
                .tropheeTexte(17, gras: true)
                .foregroundStyle(Teinte(.ink))
                .accessibilityAddTraits(.isHeader)
            ForEach(r.lignes.indices, id: \.self) { i in
                Text(r.lignes[i], traducteur: traducteur)
                    .tropheeTexte(15)
                    .foregroundStyle(Teinte(.ink))
                    .padding(.top, 4)
            }
        }
    }

    // MARK: Les actions

    /// La première apparition : le filtre gardé revient (s'il n'est pas déjà celui du modèle), puis l'écran
    /// s'ouvre.
    private func premiereOuverture() async {
        guard !ouvert else { return }
        ouvert = true
        if !filtreGarde.isEmpty && modele.filtreCle == nil {
            modele.choisirFiltre(PaliersModele.famille(cle: filtreGarde))
        }
        await ouvrir()
    }

    /// onResume : le modèle recalcule, repère les nouveaux et retient ce qui est vu ; puis l'écran se place sur
    /// « Vous êtes ici ».
    private func ouvrir() async {
        do {
            try await modele.ouvrir()
        } catch {
            // Comme Android : rien ne se montre, l'écran reste préparé.
        }
        demandeDefilement += 1
    }

    /// Une fiche paraît et part d'un coup, comme un dialogue d'Android.
    private var ouvrirFiche: @MainActor (Trophees.Niveau) -> Void {
        let modele = self.modele
        return { niveau in
            TropheeTransaction.sansAnimation {
                modele.ouvrirFiche(niveau)
            }
        }
    }

    private var fermerFiche: @MainActor () -> Void {
        let modele = self.modele
        return {
            TropheeTransaction.sansAnimation {
                modele.fermerFiche()
            }
        }
    }

    private var fermerFete: @MainActor () -> Void {
        let modele = self.modele
        return {
            TropheeTransaction.sansAnimation {
                modele.fermerFeteGrade()
            }
        }
    }

    /// La fête suit le modèle ; la fermer passe par `fermerFeteGrade()`.
    private var feteOuverte: Binding<Bool> {
        let modele = self.modele
        return Binding.passerelle({ @MainActor in modele.feteGrade != nil },
                       { @MainActor ouverte in
                           if !ouverte { modele.fermerFeteGrade() }
                       })
    }

    // MARK: L'image du partage

    /// L'image carrée de 1080 px (PaliersActivity.partager), aux couleurs de la palette de l'écran et dans la
    /// langue de l'app ; nil sans trophée.
    private func dessinerImagePartage() -> Image? {
        guard let partage = modele.partage else { return nil }
        let vue = PaliersImagePartage(dessin: formes.medaille(partage.grade),
                                      fond: palette.couleur(.brandDark, schema: schema),
                                      encre: palette.couleur(.mint, schema: schema),
                                      titre: traducteur.texte(partage.titreImage),
                                      sous: traducteur.texte(partage.sousImage),
                                      marque: traducteur.texte(partage.marque))
        let rendu = ImageRenderer(content: vue)
        // Un point de la vue pour un pixel de l'image : 1080 × 1080 px, comme le Bitmap d'Android.
        rendu.scale = 1
        guard let image = rendu.uiImage else { return nil }
        return Image(uiImage: image)
    }
}

/// Ce dont dépend l'image du partage : le grade et le compte, la palette et le mode de l'écran, la langue.
private struct PaliersCleImage: Equatable {
    let partage: PaliersPartage?
    let palette: PaletteApp
    let nuit: Bool
    let langue: String
}

// MARK: Les mesures

/// Les dimensions d'Android qui suivent la place de l'écran (values-w360dp … values-w1200dp, values-h640dp).
struct PaliersMesures {
    let largeur: CGFloat
    let hauteur: CGFloat

    init(taille: CGSize) {
        largeur = taille.width
        hauteur = taille.height
    }

    /// values-h640dp : un bandeau plus haut, un titre plus grand, une illustration plus grande.
    var haut: Bool { hauteur >= 640 }

    /// `@dimen/edge`, la marge intérieure du bandeau sur les côtés.
    var marge: CGFloat {
        if largeur >= 1200 { return 320 }
        if largeur >= 840 { return 120 }
        if largeur >= 600 { return 48 }
        if largeur >= 360 { return 24 }
        return 16
    }

    /// `@dimen/wide_gutter`, la marge du défilement sur les côtés.
    var gouttiere: CGFloat {
        if largeur >= 1200 { return 304 }
        if largeur >= 840 { return 104 }
        if largeur >= 600 { return 32 }
        return 0
    }
}

// MARK: Le bandeau

/// Le bandeau (bg_hero) : le titre en blanc, l'illustration des bras ouverts sur la menthe (bg_stage), sur le
/// dégradé de l'accent vers le vert sombre, coins bas arrondis et filet de lumière en bas. Il ne défile pas.
struct PaliersBandeau: View {
    let titre: Text
    let image: String
    let mesures: PaliersMesures

    @Environment(\.paletteApp) private var palette
    @Environment(\.colorScheme) private var schema

    init(titre: Text, image: String, mesures: PaliersMesures) {
        self.titre = titre
        self.image = image
        self.mesures = mesures
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            titre
                .tropheeTexte(mesures.haut ? 24 : 21, gras: true)
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.leading)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
            Illustration(decorative: image)
                .padding(4)
                .frame(width: mesures.haut ? 64 : 50, height: mesures.haut ? 78 : 60)
                .background(Teinte(.mint), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.leading, 12)
        }
        .padding(.horizontal, mesures.marge)
        .padding(.top, mesures.haut ? 22 : 12)
        .padding(.bottom, mesures.haut ? 18 : 10)
        .background {
            fond
        }
    }

    /// L'angle 225 d'Android va du coin haut droit au coin bas gauche (centre à 55 %) ; le dessin ne se retourne
    /// pas en hébreu.
    private var fond: some View {
        UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20, style: .continuous)
            .fill(LinearGradient(stops: [
                Gradient.Stop(color: palette.couleur(.brand, schema: schema), location: 0),
                Gradient.Stop(color: palette.couleur(.brandDark, schema: schema), location: 0.55),
                Gradient.Stop(color: palette.couleur(.brandDark, schema: schema), location: 1),
            ], startPoint: UnitPoint(x: 1, y: 0), endPoint: UnitPoint(x: 0, y: 1)))
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.25), Color.white.opacity(0)],
                               startPoint: UnitPoint(x: 0, y: 0.5), endPoint: UnitPoint(x: 1, y: 0.5))
                    .frame(height: 1)
                    .padding(.horizontal, 36)
            }
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityHidden(true)
    }
}

/// Le fond d'une puce du filtre : pleine de l'accent si elle est choisie, sinon cerclée du filet.
struct PaliersFondPuce: View {
    let choisi: Bool

    init(choisi: Bool) {
        self.choisi = choisi
    }

    var body: some View {
        if choisi {
            Capsule().fill(Teinte(.brand))
        } else {
            Capsule().strokeBorder(Teinte(.line), lineWidth: 1)
        }
    }
}

// MARK: L'image du partage

/// L'image du grade à partager (PaliersActivity.partager), en points égaux aux pixels : 1080 × 1080, le fond vert
/// sombre, la médaille du grade dans le carré (280, 130)–(800, 650), puis trois lignes centrées en menthe, posées
/// sur leurs lignes de base (790, 860 et 990). Les textes arrivent déjà traduits : le rendu hors écran n'a pas
/// l'environnement de l'app.
struct PaliersImagePartage: View {
    let dessin: TropheeDessin?
    let fond: Color
    let encre: Color
    let titre: String
    let sous: String
    let marque: String

    init(dessin: TropheeDessin?, fond: Color, encre: Color, titre: String, sous: String, marque: String) {
        self.dessin = dessin
        self.fond = fond
        self.encre = encre
        self.titre = titre
        self.sous = sous
        self.marque = marque
    }

    var body: some View {
        ZStack {
            fond
            TropheeObjet(dessin)
                .frame(width: 520, height: 520)
                .position(x: 540, y: 390)
            ligne(titre, taille: 76, gras: true, base: 790, opacite: 1)
            ligne(sous, taille: 46, gras: false, base: 860, opacite: 1)
            ligne(marque, taille: 38, gras: true, base: 990, opacite: 180.0 / 255.0)
        }
        .frame(width: 1080, height: 1080)
        .environment(\.layoutDirection, .leftToRight)
        .environment(\.dynamicTypeSize, .large)
    }

    /// Une ligne centrée ; le milieu des capitales (environ 0,35 em au-dessus de la base) sur `base − 0,35 em`.
    private func ligne(_ texte: String, taille: CGFloat, gras: Bool, base: CGFloat, opacite: Double) -> some View {
        Text(verbatim: texte)
            .font(.system(size: taille, weight: gras ? .bold : .regular))
            .foregroundStyle(encre.opacity(opacite))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .multilineTextAlignment(.center)
            .frame(width: 1040)
            .position(x: 540, y: base - taille * 0.35)
    }
}
