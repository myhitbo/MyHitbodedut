import Accessibility
import Foundation
import SwiftUI
import Coeur
import Ecrans

// Ce que partagent les écrans de la bibliothèque et du 'hizouk (LibraryActivity.kt, LibrarySubSectionActivity.kt,
// LibraryEntryActivity.kt, ChizukActivity.kt) : le bandeau (drawable/bg_hero.xml), le cadre des illustrations
// (bg_stage, bg_stage_soft), le fond des cartes (bg_card), les couleurs de la lecture de nuit, le bouton de lecture
// (ReglagesLecture.kt) et les messages brefs (Toast, Snackbar). Aucune décision ici : tout se lit dans les modèles
// d'Ecrans (BibliothequeModele.swift, ChizukModele.swift).

// MARK: Les actions qui écrivent

/// Lance une action du modèle qui écrit dans le `Magasin`. Android écrit ses préférences sans échec possible et ne
/// montre rien : une écriture qui échoue ne montre rien ici non plus (le `Magasin` garde le changement en mémoire).
enum BibliothequeTache {
    @MainActor
    static func lancer(_ action: @escaping @MainActor () async throws -> Void) {
        Task {
            do {
                try await action()
            } catch {
                // Rien de plus qu'Android : pas de message.
            }
        }
    }
}

// MARK: Les couleurs écrites en dur par Android

/// Les couleurs de la lecture de nuit (values/colors.xml : lecture_nuit_fond, lecture_nuit_texte,
/// lecture_nuit_discret). Android les écrit en dur : elles ne suivent pas la palette.
enum BibliothequeNuit {
    static let fond = BibliothequeNuit.couleur(0x00, 0x00, 0x00)
    static let texte = BibliothequeNuit.couleur(0xF2, 0xF0, 0xEA)
    static let discret = BibliothequeNuit.couleur(0xA3, 0xA8, 0xA5)

    static func couleur(_ rouge: Int, _ vert: Int, _ bleu: Int, opacite: Double = 1) -> Color {
        Color(.sRGB, red: Double(rouge) / 255, green: Double(vert) / 255, blue: Double(bleu) / 255, opacity: opacite)
    }
}

/// Les couleurs du texte d'une source (ReglagesLecture.Rendu) : celles de la palette le jour, celles de la nuit si
/// la lune est allumée (`BibliothequeEntreeModele.lectureSombre`).
struct BibliothequeRendu {
    let sombre: Bool

    /// Le fond de la carte des paragraphes : `card`, ou noir.
    var fond: AnyShapeStyle {
        sombre ? AnyShapeStyle(BibliothequeNuit.fond) : AnyShapeStyle(Teinte(.card))
    }

    /// Le texte : encre, ou blanc cassé.
    var texte: AnyShapeStyle {
        sombre ? AnyShapeStyle(BibliothequeNuit.texte) : AnyShapeStyle(Teinte(.ink))
    }

    /// Le discret (les traductions sous l'hébreu) : `muted`, ou gris clair.
    var discret: AnyShapeStyle {
        sombre ? AnyShapeStyle(BibliothequeNuit.discret) : AnyShapeStyle(Teinte(.muted))
    }
}

// MARK: Le bandeau

/// Le fond du bandeau (bg_hero.xml) : un dégradé à 225° de l'accent (en haut, du côté de l'illustration) vers le
/// vert sombre (dès 55 %), les coins du bas arrondis de 20, et un filet de lumière de 1 en bas, blanc à 25 % au
/// milieu et fondu aux bords, rentré de 36 de chaque côté.
struct BibliothequeFondBandeau: View {
    @Environment(\.paletteApp) private var palette
    @Environment(\.colorScheme) private var schema

    init() {}

    var body: some View {
        let forme = UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20, style: .continuous)
        let marque = palette.couleur(.brand, schema: schema)
        let sombre = palette.couleur(.brandDark, schema: schema)
        forme
            .fill(LinearGradient(stops: [Gradient.Stop(color: marque, location: 0),
                                         Gradient.Stop(color: sombre, location: 0.55),
                                         Gradient.Stop(color: sombre, location: 1)],
                                 startPoint: UnitPoint(x: 1, y: 0), endPoint: UnitPoint(x: 0, y: 1)))
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0x40 / 255.0), Color.white.opacity(0)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(height: 1)
                    .padding(.horizontal, 36)
            }
            .accessibilityHidden(true)
    }
}

/// L'illustration d'un écran ou d'une carte dans son cadre arrondi (bg_stage : menthe ; bg_stage_soft : `stageSoft`),
/// 4 de marge intérieure. Toutes les illustrations de ces écrans sont des ornements : VoiceOver les passe.
struct BibliothequeCadre: View {
    let image: String
    let largeur: CGFloat
    let hauteur: CGFloat
    let fond: Jeton

    init(image: String, largeur: CGFloat, hauteur: CGFloat, fond: Jeton) {
        self.image = image
        self.largeur = largeur
        self.hauteur = hauteur
        self.fond = fond
    }

    var body: some View {
        Illustration(decorative: image)
            .padding(4)
            .frame(width: largeur, height: hauteur)
            .background(Teinte(fond), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Le bandeau d'un écran de la liste ou du 'hizouk : le titre en blanc, le sous-titre en menthe dessous, et
/// l'illustration dans son cadre menthe du côté de la fin.
struct BibliothequeBandeau: View {

    /// Les mesures d'Android : celles d'activity_library.xml (24 et 16, image de 78 × 96), ou celles du 'hizouk
    /// (hero_pad_top, hero_art… : plus grandes sur un écran haut, values-h640dp).
    enum Mesure {
        case liste
        case hero
    }

    let titre: Text
    let sousTitre: Text?
    let image: String?
    let mesure: Mesure

    /// Un téléphone en portrait a toujours plus de 640 points de haut : les mesures des grands écrans d'Android ;
    /// en paysage, les petites.
    @Environment(\.verticalSizeClass) private var classeVerticale

    init(titre: Text, sousTitre: Text?, image: String?, mesure: Mesure) {
        self.titre = titre
        self.sousTitre = sousTitre
        self.image = image
        self.mesure = mesure
    }

    private var haut: Bool {
        classeVerticale != .compact
    }

    private var margeHaut: CGFloat {
        switch mesure {
        case .liste: 24
        case .hero: haut ? 22 : 12
        }
    }

    private var margeBas: CGFloat {
        switch mesure {
        case .liste: 16
        case .hero: haut ? 18 : 10
        }
    }

    private var cadre: CGSize {
        switch mesure {
        case .liste: CGSize(width: 78, height: 96)
        case .hero: haut ? CGSize(width: 64, height: 78) : CGSize(width: 50, height: 60)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            colonne
            if let image {
                BibliothequeCadre(image: image, largeur: cadre.width, hauteur: cadre.height, fond: .mint)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, margeHaut)
        .padding(.bottom, margeBas)
        .frame(maxWidth: .infinity)
        .background { BibliothequeFondBandeau() }
    }

    private var colonne: some View {
        VStack(alignment: .leading, spacing: 4) {
            titre
                .font(Font.title2.bold())
                .foregroundStyle(Color.white)
            if let sousTitre {
                sousTitre
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.mint))
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: Les cartes

/// Le fond d'une carte (bg_card.xml) : `card`, filet `line` de 1, coins de 20. La marge intérieure est celle de
/// chaque layout d'Android, posée avant.
struct BibliothequeFondCarte: ViewModifier {
    let fond: AnyShapeStyle

    init(fond: AnyShapeStyle) {
        self.fond = fond
    }

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fond, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Teinte(.line), lineWidth: 1)
            }
    }
}

extension View {
    /// Le fond de carte d'Android (`card`), ou un autre fond (la lecture de nuit).
    func fondCarteBibliotheque(_ fond: AnyShapeStyle = AnyShapeStyle(Teinte(.card))) -> some View {
        modifier(BibliothequeFondCarte(fond: fond))
    }
}

// MARK: Les icônes

/// Les icônes vectorielles d'Android que nomment les modèles, en symboles du système : `ic_marque_etude` (un livre
/// ouvert et son ruban) devient le livre ouvert.
enum BibliothequeIcone {
    static func symbole(_ nom: String) -> String {
        switch nom {
        case "ic_marque_priere": "bookmark"
        default: "book"
        }
    }
}

// MARK: Le bouton de lecture

/// La pastille « Aa » et, dépliée, la barre de lecture (ReglagesLecture.kt), centrées en bas de la page d'une
/// source ; au-dessus, la commande du défilement automatique tant qu'il défile. La barre se lit toujours de gauche
/// à droite : A− à gauche, A+ à droite, quelle que soit la langue.
struct BibliothequeBarreVue: View {
    let barre: BibliothequeBarreLecture
    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var reduireAnimations

    init(barre: BibliothequeBarreLecture) {
        self.barre = barre
    }

    var body: some View {
        VStack(spacing: 12) {
            // Tant que le texte défile tout seul : [−] [N] [+] [❚❚] (DefilementAutoVue.swift).
            if barre.defilementAuto.commandeVisible {
                DefilementCommande(defilement: barre.defilementAuto)
                    .transition(.opacity)
            }
            ZStack(alignment: .bottom) {
                if barre.pastilleVisible {
                    pastille
                }
                if barre.barreVisible {
                    barreDepliee
                }
            }
        }
        .animation(reduireAnimations ? nil : .easeOut(duration: 0.18), value: barre.defilementAuto.commandeVisible)
    }

    // MARK: La pastille

    private var pastille: some View {
        Button {
            barre.deplier(true)
        } label: {
            Text(verbatim: "Aa")
                .font(Font.subheadline.bold())
                .foregroundStyle(Teinte(.onBrand))
                .padding(.horizontal, 12)
                .frame(minWidth: 56, minHeight: 44)
                .background(Teinte(.brand).opacity(0xF2 / 255.0), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(Libelle("lecture_reglages"), traducteur: traducteur))
    }

    // MARK: La barre

    private var barreDepliee: some View {
        HStack(spacing: 0) {
            boutonMoins
            boutonPourcent
            boutonPlus
            filet
            boutonNuit
            menuPolice
            menuLangues
            DefilementBouton(defilement: barre.defilementAuto, cote: nil)
            filet
            boutonMasquer
            boutonReplier
        }
        .padding(.horizontal, 4)
        .frame(height: 52)
        .background(Teinte(.brand).opacity(0xF2 / 255.0), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 12)
    }

    /// Un bouton de la barre : 44 de haut, de 30 à 44 de large selon la place (la barre tient toujours entière).
    private func touche<Contenu: View>(_ cle: String, action: @escaping @MainActor () -> Void,
                                       @ViewBuilder contenu: () -> Contenu) -> some View {
        Button(action: action) {
            contenu()
                .foregroundStyle(Teinte(.onBrand))
                .frame(minWidth: 30, maxWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(Libelle(cle), traducteur: traducteur))
    }

    private var boutonMoins: some View {
        touche("lecture_moins", action: {
            BibliothequeTache.lancer { try await barre.rapetisser() }
        }) {
            Text(verbatim: "A−").font(Font.footnote.bold())
        }
    }

    private var boutonPourcent: some View {
        Button {
            BibliothequeTache.lancer { try await barre.tailleNormale() }
        } label: {
            Text(barre.libellePourcent, traducteur: traducteur)
                .font(Font.footnote.bold())
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(Teinte(.onBrand))
                .frame(minWidth: 48, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(barre.descriptionTaille, traducteur: traducteur))
    }

    private var boutonPlus: some View {
        touche("lecture_plus", action: {
            BibliothequeTache.lancer { try await barre.agrandir() }
        }) {
            Text(verbatim: "A+").font(Font.body.bold())
        }
    }

    private var filet: some View {
        Rectangle()
            .fill(Teinte(.onBrand).opacity(0x55 / 255.0))
            .frame(width: 1, height: 22)
            .padding(.horizontal, 4)
            .accessibilityHidden(true)
    }

    private var boutonNuit: some View {
        touche("lecture_nuit", action: {
            BibliothequeTache.lancer { try await barre.basculerSombre() }
        }) {
            // ic_lecture_lune.
            Image(systemName: "moon")
                .font(Font.body.weight(.medium))
                .frame(width: 34, height: 34)
                .background {
                    // La nuit, la lune est cerclée (l'état coché d'Android).
                    Ellipse().fill(Teinte(.onBrand).opacity(barre.sombre ? 0.25 : 0))
                }
        }
        .accessibilityValue(Text(barre.etatSombre, traducteur: traducteur))
    }

    /// Le choix de la police : un sélecteur dans un menu, qui coche la police choisie.
    private var choixPolice: Binding<PoliceHebraique.Police> {
        Bindable(barre).policeChoisie
    }

    /// Le choix des langues du texte, de même.
    private var choixLangues: Binding<LanguesTexte.Mode> {
        Bindable(barre).languesChoisies
    }

    private var menuPolice: some View {
        Menu {
            Picker(selection: choixPolice) {
                ForEach(barre.polices, id: \.self) { police in
                    Text(Libelle(police.libelle), traducteur: traducteur)
                        .tag(police)
                }
            } label: {
                Text(Libelle("lecture_police"), traducteur: traducteur)
            }
        } label: {
            // « אב » : le choix de la police, en lettres hébraïques puisque c'est elles qu'il change.
            Text(verbatim: "אב")
                .font(.body)
                .foregroundStyle(Teinte(.onBrand))
                .frame(minWidth: 30, maxWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(Libelle("lecture_police"), traducteur: traducteur))
    }

    private var menuLangues: some View {
        Menu {
            Picker(selection: choixLangues) {
                ForEach(barre.modes, id: \.self) { mode in
                    Text(Libelle(mode.libelle), traducteur: traducteur)
                        .tag(mode)
                }
            } label: {
                Text(Libelle("lecture_langues"), traducteur: traducteur)
            }
        } label: {
            // « אA » : les langues du texte.
            Text(verbatim: "אA")
                .font(Font.subheadline.bold())
                .foregroundStyle(Teinte(.onBrand))
                .frame(minWidth: 30, maxWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(Libelle("lecture_langues"), traducteur: traducteur))
    }

    private var boutonMasquer: some View {
        touche("lecture_masquer", action: {
            BibliothequeTache.lancer { try await barre.masquer() }
        }) {
            // ic_lecture_masquer.
            Image(systemName: "eye.slash").font(Font.body.weight(.medium))
        }
    }

    private var boutonReplier: some View {
        touche("lecture_replier", action: {
            barre.deplier(false)
        }) {
            // ic_lecture_replier.
            Image(systemName: "chevron.down").font(Font.body.weight(.semibold))
        }
    }
}

// MARK: Les messages brefs

/// La barre du bas qui suit le masquage (Snackbar.LENGTH_LONG) : le message, et « Annuler », qui fait revenir le
/// bouton. Elle s'efface d'elle-même au bout de 2,75 s ; VoiceOver l'annonce.
struct BibliothequeAnnonceMasque: View {
    let barre: BibliothequeBarreLecture
    let message: Libelle
    @Environment(\.traducteur) private var traducteur

    init(barre: BibliothequeBarreLecture, message: Libelle) {
        self.barre = barre
        self.message = message
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(message, traducteur: traducteur)
                .font(.subheadline)
                .foregroundStyle(Teinte(.paper))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                BibliothequeTache.lancer { try await barre.retrouver() }
            } label: {
                Text(barre.libelleAnnulerMasque, traducteur: traducteur)
                    .font(Font.subheadline.bold())
                    .foregroundStyle(Teinte(.mint))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Teinte(.ink), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .task(id: message) {
            AccessibilityNotification.Announcement(traducteur.texte(message)).post()
            do {
                try await Task.sleep(for: .milliseconds(2750))
                barre.fermerMessage()
            } catch {
                // Effacée avant la fin (l'écran s'en va, ou « Annuler ») : rien à faire.
            }
        }
    }
}

/// Un message bref (Toast.LENGTH_SHORT) : « Cet écran n'existe pas sur ce téléphone ». Il s'efface au bout de 2 s
/// (`fin`), et VoiceOver l'annonce.
struct BibliothequeMessageBref: View {
    let message: Libelle
    let fin: @MainActor () -> Void
    @Environment(\.traducteur) private var traducteur

    init(message: Libelle, fin: @escaping @MainActor () -> Void) {
        self.message = message
        self.fin = fin
    }

    var body: some View {
        Text(message, traducteur: traducteur)
            .font(.subheadline)
            .foregroundStyle(Teinte(.paper))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Teinte(.ink).opacity(0.9), in: Capsule())
            .padding(.horizontal, 24)
            .padding(.bottom, 72)
            .allowsHitTesting(false)
            .task(id: message) {
                AccessibilityNotification.Announcement(traducteur.texte(message)).post()
                do {
                    try await Task.sleep(for: .seconds(2))
                    fin()
                } catch {
                    // Un autre message l'a remplacé : c'est lui qui s'effacera.
                }
            }
    }
}
