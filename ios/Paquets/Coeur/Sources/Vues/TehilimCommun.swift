import Accessibility
import Foundation
import SwiftUI
import Coeur
import Ecrans

// Ce que partagent les écrans des Tehilim, du Tikoun et des Tfilot : le bandeau (drawable/bg_hero.xml), les couleurs
// de la lecture de nuit, le bouton de lecture (ReglagesLecture.kt : la pastille « Aa » et sa barre), les messages
// brefs (Toast, Snackbar) et les gestes sur le texte. Aucune décision ici : tout se lit dans les modèles d'Ecrans
// (TehilimBarreLecture, TehilimLectureModele, TikkunModele).

// MARK: Les actions qui écrivent

/// Lance une action du modèle qui écrit dans le `Magasin`. Android écrit ses préférences sans échec possible et ne
/// montre rien : une écriture qui échoue ne montre rien ici non plus (le `Magasin` garde le changement en mémoire).
enum TehilimTache {
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

// MARK: Les couleurs de la lecture

/// Les couleurs de la lecture de nuit (values/colors.xml d'Android : lecture_nuit_fond, lecture_nuit_texte,
/// lecture_nuit_discret, lecture_nuit_titre). Android les écrit en dur : elles ne suivent pas la palette.
enum TehilimNuit {
    static let fond = TehilimNuit.couleur(0x00, 0x00, 0x00)
    static let texte = TehilimNuit.couleur(0xF2, 0xF0, 0xEA)
    static let discret = TehilimNuit.couleur(0xA3, 0xA8, 0xA5)
    static let titre = TehilimNuit.couleur(0xD6, 0xC2, 0x8C)

    private static func couleur(_ rouge: Int, _ vert: Int, _ bleu: Int) -> Color {
        Color(.sRGB, red: Double(rouge) / 255, green: Double(vert) / 255, blue: Double(bleu) / 255, opacity: 1)
    }
}

/// Les couleurs du texte lu (ReglagesLecture.Rendu) : celles de la palette le jour, celles de la nuit si la lune
/// est allumée (`TehilimBarreLecture.sombre`).
struct TehilimRendu {
    let sombre: Bool

    /// Le fond de la zone qui défile : papier, ou noir.
    var fond: AnyShapeStyle {
        sombre ? AnyShapeStyle(TehilimNuit.fond) : AnyShapeStyle(Teinte(.paper))
    }

    /// Le texte : encre, ou blanc cassé.
    var texte: AnyShapeStyle {
        sombre ? AnyShapeStyle(TehilimNuit.texte) : AnyShapeStyle(Teinte(.ink))
    }

    /// Le discret (numéros, arrêts, traductions sous l'hébreu) : gris `muted`, ou gris clair.
    var discret: AnyShapeStyle {
        sombre ? AnyShapeStyle(TehilimNuit.discret) : AnyShapeStyle(Teinte(.muted))
    }

    /// Les titres et les marques : couleur de l'accent, ou doré.
    var titre: AnyShapeStyle {
        sombre ? AnyShapeStyle(TehilimNuit.titre) : AnyShapeStyle(Teinte(.brand))
    }
}

// MARK: Le bandeau

/// Le fond du bandeau (bg_hero.xml) : un dégradé à 225° de l'accent (en haut, du côté de l'illustration) vers le vert
/// sombre (dès 55 %), les coins du bas arrondis de 20, et un filet de lumière de 1 en bas, rentré de 36 de chaque côté.
struct TehilimFondBandeau: View {
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
    }
}

/// Le bandeau d'un écran : le titre en blanc, le sous-titre en menthe dessous, et l'illustration dans son cadre
/// (bg_stage) du côté de la fin. Les écrans de lecture n'ont pas d'image (pas d'image pendant une prière).
struct TehilimBandeau: View {

    /// Les mesures d'Android : celles des Tehilim, de la lecture et du Tikoun (hero_pad_top, hero_art…, plus
    /// grandes sur un écran haut : values-h640dp), ou celles des Tfilot (24 et 16, image de 78 × 96).
    enum Mesure {
        case livre
        case tefilot
    }

    let titre: Text
    let sousTitre: Text?
    let image: String?
    let mesure: Mesure

    /// Un téléphone en portrait a toujours plus de 640 points de haut : les mesures des grands écrans d'Android ;
    /// en paysage, les petites.
    @Environment(\.verticalSizeClass) private var classeVerticale

    init(titre: Text, sousTitre: Text?, image: String?, mesure: Mesure = .livre) {
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
        case .livre: haut ? 22 : 12
        case .tefilot: 24
        }
    }

    private var margeBas: CGFloat {
        switch mesure {
        case .livre: haut ? 18 : 10
        case .tefilot: 16
        }
    }

    private var cadre: CGSize {
        switch mesure {
        case .livre: haut ? CGSize(width: 64, height: 78) : CGSize(width: 50, height: 60)
        case .tefilot: CGSize(width: 78, height: 96)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            colonne
            if let image {
                Illustration(decorative: image)
                    .padding(4)
                    .frame(width: cadre.width, height: cadre.height)
                    .background(Teinte(.mint), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, margeHaut)
        .padding(.bottom, margeBas)
        .frame(maxWidth: .infinity)
        .background { TehilimFondBandeau() }
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

// MARK: Les gestes sur le texte

/// Les gestes du texte lu (ReglagesLecture.toucher) : un toucher rend la pastille effacée par le défilement, deux
/// touchers font revenir le bouton masqué. L'action d'accessibilité « Réglages de lecture » fait de même que les
/// deux touchers (l'action que ReglagesLecture ajoute au défilement).
struct TehilimGestesTexte: ViewModifier {
    let barre: TehilimBarreLecture
    @Environment(\.traducteur) private var traducteur

    init(barre: TehilimBarreLecture) {
        self.barre = barre
    }

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                TehilimTache.lancer { try await barre.retrouver() }
            }
            .onTapGesture {
                barre.toucherTexte()
            }
            .accessibilityAction {
                TehilimTache.lancer { try await barre.retrouver() }
            } label: {
                Text(Libelle("lecture_reglages"), traducteur: traducteur)
            }
    }
}

extension View {
    /// Les gestes du texte lu, sur toute la largeur de l'élément.
    func gestesTehilim(_ barre: TehilimBarreLecture) -> some View {
        modifier(TehilimGestesTexte(barre: barre))
    }
}

// MARK: Le bouton de lecture

/// La pastille « Aa » et, dépliée, la barre de lecture (ReglagesLecture.kt), centrées en bas de la zone de texte ;
/// au-dessus, la commande du défilement automatique tant qu'il défile. La barre se lit toujours de gauche à
/// droite : A− à gauche, A+ à droite, quelle que soit la langue.
struct TehilimBarreVue: View {
    let barre: TehilimBarreLecture
    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var reduireAnimations

    init(barre: TehilimBarreLecture) {
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
            barre.deplierBarre(true)
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
        // Effacée en descendant dans le texte : un fondu et 24 points vers le bas en 180 ms ; sans glissement ni
        // animation quand on réduit les animations.
        .opacity(barre.pastilleEffacee ? 0 : 1)
        .offset(y: barre.pastilleEffacee && !reduireAnimations ? 24 : 0)
        .animation(reduireAnimations ? nil : .easeOut(duration: 0.18), value: barre.pastilleEffacee)
        .allowsHitTesting(!barre.pastilleEffacee)
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
            TehilimTache.lancer { try await barre.changerTaille(plus: false) }
        }) {
            Text(verbatim: "A−").font(Font.footnote.bold())
        }
    }

    private var boutonPourcent: some View {
        Button {
            TehilimTache.lancer { try await barre.tailleNormale() }
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
        .accessibilityLabel(Text(barre.descriptionPourcent, traducteur: traducteur))
    }

    private var boutonPlus: some View {
        touche("lecture_plus", action: {
            TehilimTache.lancer { try await barre.changerTaille(plus: true) }
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
            TehilimTache.lancer { try await barre.basculerNuit() }
        }) {
            Image(systemName: "moon")
                .font(Font.body.weight(.medium))
                .frame(width: 34, height: 34)
                .background {
                    // La nuit, la lune est cerclée (l'état coché d'Android).
                    Circle().fill(Teinte(.onBrand).opacity(barre.sombre ? 0.25 : 0))
                }
        }
        .accessibilityValue(Text(barre.etatNuit, traducteur: traducteur))
    }

    private var menuPolice: some View {
        Menu {
            ForEach(barre.optionsPolice) { option in
                Button {
                    TehilimTache.lancer { try await barre.choisirPolice(option.valeur) }
                } label: {
                    etiquette(option.nom, choisi: option.choisi)
                }
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
            ForEach(barre.optionsLangues) { option in
                Button {
                    TehilimTache.lancer { try await barre.choisirLangues(option.valeur) }
                } label: {
                    etiquette(option.nom, choisi: option.choisi)
                }
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

    /// Un choix d'un menu, coché s'il est le choix actuel.
    @ViewBuilder
    private func etiquette(_ nom: Libelle, choisi: Bool) -> some View {
        if choisi {
            Label {
                Text(nom, traducteur: traducteur)
            } icon: {
                Image(systemName: "checkmark")
            }
        } else {
            Text(nom, traducteur: traducteur)
        }
    }

    private var boutonMasquer: some View {
        touche("lecture_masquer", action: {
            TehilimTache.lancer { try await barre.masquer() }
        }) {
            Image(systemName: "eye.slash").font(Font.body.weight(.medium))
        }
    }

    private var boutonReplier: some View {
        touche("lecture_replier", action: {
            barre.deplierBarre(false)
        }) {
            Image(systemName: "chevron.down").font(Font.body.weight(.semibold))
        }
    }
}

// MARK: Les messages brefs

/// La barre du bas qui suit le masquage (Snackbar.LENGTH_LONG) : « Bouton masqué… », et « Annuler », qui fait
/// revenir le bouton. Elle s'efface d'elle-même au bout de 2,75 s.
struct TehilimAnnonceMasque: View {
    let barre: TehilimBarreLecture
    @Environment(\.traducteur) private var traducteur

    init(barre: TehilimBarreLecture) {
        self.barre = barre
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(Libelle("lecture_masque_info"), traducteur: traducteur)
                .font(.subheadline)
                .foregroundStyle(Teinte(.paper))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                TehilimTache.lancer { try await barre.retrouver() }
            } label: {
                Text(Libelle("lecture_annuler_masque"), traducteur: traducteur)
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
        .task {
            AccessibilityNotification.Announcement(traducteur.texte(Libelle("lecture_masque_info"))).post()
            do {
                try await Task.sleep(for: .milliseconds(2750))
                barre.finAnnonceMasque()
            } catch {
                // Effacée avant la fin (l'écran s'en va, ou « Annuler ») : rien à faire.
            }
        }
    }
}

/// Un message bref (Toast.LENGTH_SHORT) : « Marque-page posé », « Marque-page retiré ». Il s'efface au bout de 2 s
/// (`fin`), et VoiceOver l'annonce.
struct TehilimMessageBref: View {
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
