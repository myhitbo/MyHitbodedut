import Foundation
import SwiftUI
import Coeur
import Ecrans

/// « J'ai besoin de 'hizouk » (ChizukActivity.kt, activity_chizuk.xml, view_chizuk.xml) : le bandeau, la carte du
/// texte tiré, les boutons « Un autre », « Garder », « Partager », « Commencer une hitbodedout », puis les textes
/// gardés. Tout se lit dans `ChizukModele`.
///
/// La séance est un autre écran : `ouvrir` reçoit `ChizukRoute.seance`. Le texte de la carte est gardé pour la
/// scène (`@SceneStorage`, l'`onSaveInstanceState` d'Android) et rendu au modèle s'il recrée l'écran.
public struct ChizukVue: View {
    let modele: ChizukModele
    private let ouvrir: @MainActor (ChizukRoute) -> Void

    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var reduireAnimations
    /// L'identifiant du texte sur la carte (`courantId`), vide sans texte.
    @SceneStorage("chizuk_courant") private var idGarde: String = ""
    /// La cascade d'entrée est jouée (une fois, à la première apparition).
    @State private var entreeJouee = false

    /// L'ancre du haut du défilement : on y revient quand la carte change.
    private static let haut = "chizuk:haut"

    /// - Parameters:
    ///   - modele: `ChizukModele(magasin:contenus:langue:debug:)`.
    ///   - ouvrir: l'écran de séance (SessionActivity), pour `ChizukRoute.seance`.
    public init(modele: ChizukModele, ouvrir: @escaping @MainActor (ChizukRoute) -> Void) {
        self.modele = modele
        self.ouvrir = ouvrir
    }

    public var body: some View {
        Group {
            if modele.etat == .pret {
                defilement
            } else {
                VStack(spacing: 0) {
                    bandeau
                    Spacer(minLength: 0)
                }
            }
        }
        .background(Teinte(.paper))
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await modele.charger(restaurer: idGarde.isEmpty ? nil : idGarde)
        }
        .onChange(of: modele.courantId) { _, id in
            idGarde = id ?? ""
        }
    }

    // MARK: Le défilement

    /// Le bandeau : il défile avec la carte (fixe, il en prenait toute la place aux grandes tailles du texte).
    private var bandeau: some View {
        BibliothequeBandeau(titre: Text(modele.titre, traducteur: traducteur),
                            sousTitre: Text(modele.sousTitre, traducteur: traducteur),
                            image: modele.image, mesure: .hero)
    }

    private var defilement: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 0)
                        .id(ChizukVue.haut)
                    bandeau
                    VStack(alignment: .leading, spacing: 0) {
                        carte
                            .cascadeChizuk(rang: 0, jouee: entreeJouee)
                        boutons
                            .padding(.top, 12)
                            .cascadeChizuk(rang: 1, jouee: entreeJouee)
                        commencer
                            .padding(.top, 8)
                            .cascadeChizuk(rang: 2, jouee: entreeJouee)
                        if !modele.gardes.isEmpty {
                            titreGardes
                                .padding(.top, 24)
                                .cascadeChizuk(rang: 3, jouee: entreeJouee)
                            listeGardes
                                .padding(.top, 8)
                                .cascadeChizuk(rang: 4, jouee: entreeJouee)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .onChange(of: modele.changements) { _, _ in
                // La carte a changé sous le doigt : on revient en haut (scrollTo(0, 0) d'Android).
                proxy.scrollTo(ChizukVue.haut, anchor: .top)
            }
            .onAppear {
                // Les blocs entrent en cascade à la première apparition ; tout de suite sans animation.
                if !entreeJouee {
                    entreeJouee = true
                }
            }
        }
    }

    // MARK: La carte

    @ViewBuilder
    private var carte: some View {
        if let carte = modele.carte {
            if reduireAnimations {
                ChizukCarteVue(carte: carte)
            } else {
                // Le fondu de la carte qui change (Effets.fondu) : effacée 6 points plus bas, puis en place en 320 ms.
                ChizukCarteVue(carte: carte)
                    .phaseAnimator([true, false], trigger: modele.changements) { contenu, enPlace in
                        contenu
                            .opacity(enPlace ? 1 : 0)
                            .offset(y: enPlace ? 0 : 6)
                    } animation: { enPlace in
                        enPlace ? Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.32) : Animation.linear(duration: 0.01)
                    }
            }
        }
    }

    // MARK: Les boutons

    private var boutons: some View {
        HStack(spacing: 8) {
            Button {
                BibliothequeTache.lancer { try await modele.unAutre() }
            } label: {
                Text(modele.libelleAutre, traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            Button {
                BibliothequeTache.lancer { try await modele.garder() }
            } label: {
                Text(modele.libelleGarder, traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .disabled(!modele.actionsActives)
            ShareLink(item: modele.textePartage { traducteur.texte($0) } ?? "",
                      subject: Text(modele.libellePartager, traducteur: traducteur)) {
                Text(modele.libellePartager, traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .disabled(!modele.actionsActives)
        }
        .buttonStyle(.secondaire)
    }

    private var commencer: some View {
        Button {
            ouvrir(modele.routeCommencer)
        } label: {
            Text(modele.libelleCommencer, traducteur: traducteur)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.principal)
    }

    // MARK: Les textes gardés

    private var titreGardes: some View {
        Text(modele.titreGardes, traducteur: traducteur)
            .font(.caption)
            .textCase(.uppercase)
            .tracking(12 * 0.08)
            .foregroundStyle(Teinte(.muted))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .accessibilityAddTraits(.isHeader)
    }

    private var listeGardes: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(modele.gardes.enumerated()), id: \.element.id) { rang, garde in
                if rang > 0 {
                    Rectangle()
                        .fill(Teinte(.line))
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }
                Button {
                    modele.montrer(garde.id)
                } label: {
                    Text(verbatim: garde.ligne)
                        .font(.subheadline)
                        .foregroundStyle(Teinte(.ink))
                        .lignesAuPlus(3)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ChizukBoutonCreux())
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
        .fondCarteBibliotheque()
    }
}

// MARK: - La carte de 'hizouk

/// La carte (view_chizuk.xml, ChizukCard.bind) : l'illustration du moment et son nom, le badge « à relire », le
/// texte (hébreu ou traduction seule), un filet, la traduction, la source. VoiceOver la lit d'un trait.
struct ChizukCarteVue: View {
    let carte: ChizukCarte
    @Environment(\.traducteur) private var traducteur
    /// Un téléphone en portrait a toujours plus de 480 points de haut : les hauteurs de values-h480dp.
    @Environment(\.verticalSizeClass) private var classeVerticale

    init(carte: ChizukCarte) {
        self.carte = carte
    }

    private var haut: Bool {
        classeVerticale != .compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            entete
                .padding(.bottom, 12)
            premierTexte
            Rectangle()
                .fill(Teinte(.line))
                .frame(height: 1)
                .padding(.vertical, 8)
                .accessibilityHidden(true)
            if let second = carte.second {
                ChizukTexteAjuste(texte: second, police: nil, tailleMax: 15, tailleMin: 12,
                                  hauteur: haut ? 116 : 84, style: .muted)
            }
            Text(verbatim: carte.reference)
                .font(.caption2)
                .foregroundStyle(Teinte(.muted))
                .lignesAuPlus(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .fondCarteBibliotheque()
        .accessibilityElement(children: .combine)
    }

    private var entete: some View {
        HStack(spacing: 12) {
            BibliothequeCadre(image: carte.image, largeur: 54, hauteur: 64, fond: .stageSoft)
            VStack(alignment: .leading, spacing: 4) {
                Text(carte.moment, traducteur: traducteur)
                    .font(Font.subheadline.bold())
                    .foregroundStyle(Teinte(.brand))
                    .lignesAuPlus(2)
                    .multilineTextAlignment(.leading)
                if carte.aRelire {
                    ChizukBadgeARelire()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// L'hébreu de droite à gauche, aligné au début, quelle que soit la langue ; une traduction seule, de gauche à
    /// droite. Toujours en Noto Serif Hebrew (la police de lecture ne s'applique pas ici, sur Android).
    @ViewBuilder
    private var premierTexte: some View {
        let texte = ChizukTexteAjuste(texte: carte.texte, police: .serif, tailleMax: 19, tailleMin: 12,
                                      hauteur: haut ? 150 : 108, style: .ink)
        if carte.texteDroiteAGauche {
            texte.environment(\.layoutDirection, .rightToLeft)
        } else {
            texte.environment(\.layoutDirection, .leftToRight)
        }
    }
}

/// Le badge « à relire » (bg_badge_warning.xml) : 11 sp, couleur `warning` sur `warning_wash`, cerclé de `warning`.
/// Android écrit ces couleurs en dur (values/colors.xml et values-night).
private struct ChizukBadgeARelire: View {
    @Environment(\.colorScheme) private var schema
    @Environment(\.traducteur) private var traducteur

    init() {}

    private var nuit: Bool {
        schema == .dark
    }

    private var avertissement: Color {
        nuit ? BibliothequeNuit.couleur(0xE8, 0xA0, 0x62) : BibliothequeNuit.couleur(0xA8, 0x56, 0x1F)
    }

    private var lavis: Color {
        nuit ? BibliothequeNuit.couleur(0xE8, 0xA0, 0x62, opacite: 0x33 / 255.0)
            : BibliothequeNuit.couleur(0xC6, 0x6B, 0x2D, opacite: 0x1F / 255.0)
    }

    var body: some View {
        Text(Libelle("chizuk_badge_to_proofread"), traducteur: traducteur)
            .font(.caption2)
            .foregroundStyle(avertissement)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(lavis, in: Capsule())
            .overlay {
                Capsule().strokeBorder(avertissement, lineWidth: 1)
            }
    }
}

/// Un texte de la carte dans sa hauteur fixe, au corps automatique (autoSizeTextType="uniform") : il rétrécit de
/// `tailleMax` à `tailleMin` pour tenir dans `hauteur`. Un texte qui ne tient pas même au plus petit corps (une
/// grande taille du texte du téléphone) fait grandir le bloc plutôt que d'être coupé : la place est mesurée par une
/// copie invisible au plus petit corps.
private struct ChizukTexteAjuste: View {
    let texte: String
    /// La police des textes saints ; nil pour celle du téléphone.
    let police: PoliceHebraique.Police?
    let tailleMax: CGFloat
    let tailleMin: CGFloat
    let hauteur: CGFloat
    let style: Jeton
    @ScaledMetric(relativeTo: .body) private var dynamique: CGFloat = 1

    init(texte: String, police: PoliceHebraique.Police?, tailleMax: CGFloat, tailleMin: CGFloat, hauteur: CGFloat,
         style: Jeton) {
        self.texte = texte
        self.police = police
        self.tailleMax = tailleMax
        self.tailleMin = tailleMin
        self.hauteur = hauteur
        self.style = style
    }

    private func corps(_ taille: CGFloat) -> Font {
        if let police {
            return Font.hebreu(police, taille: taille * dynamique)
        }
        return Font.system(size: taille * dynamique)
    }

    var body: some View {
        Text(verbatim: texte)
            .font(corps(tailleMin))
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: hauteur * dynamique, alignment: .topLeading)
            .hidden()
            .accessibilityHidden(true)
            .overlay(alignment: .topLeading) {
                Text(verbatim: texte)
                    .font(corps(tailleMax))
                    .lineSpacing(2)
                    .minimumScaleFactor(tailleMin / tailleMax)
                    .foregroundStyle(Teinte(style))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
    }
}

// MARK: - Les effets

/// Une ligne des textes gardés qui « se creuse » sous le doigt (Effets.presse) : 98 % en 110 ms, retour en 160 ms.
/// Rien quand on réduit les animations.
private struct ChizukBoutonCreux: ButtonStyle {
    init() {}

    func makeBody(configuration: Configuration) -> some View {
        ChizukCorpsCreux(configuration: configuration)
    }
}

private struct ChizukCorpsCreux: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.accessibilityReduceMotion) private var reduireAnimations

    init(configuration: ButtonStyleConfiguration) {
        self.configuration = configuration
    }

    private var creuse: Bool {
        configuration.isPressed && !reduireAnimations
    }

    var body: some View {
        configuration.label
            .scaleEffect(creuse ? 0.98 : 1)
            .animation(reduireAnimations ? nil : .easeOut(duration: creuse ? 0.11 : 0.16), value: creuse)
    }
}

/// L'entrée en cascade (Effets.enfants) : chaque bloc part 14 points plus bas, effacé, et arrive en 420 ms, après
/// 60 ms et 45 ms de plus par rang (au plus 8 rangs). Tout de suite en place quand on réduit les animations.
private struct ChizukCascade: ViewModifier {
    let rang: Int
    let jouee: Bool
    @Environment(\.accessibilityReduceMotion) private var reduireAnimations

    init(rang: Int, jouee: Bool) {
        self.rang = rang
        self.jouee = jouee
    }

    private var visible: Bool {
        jouee || reduireAnimations
    }

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 14)
            .animation(reduireAnimations ? nil
                       : Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.42)
                           .delay(0.06 + 0.045 * Double(min(rang, 8))),
                       value: visible)
    }
}

extension View {
    fileprivate func cascadeChizuk(rang: Int, jouee: Bool) -> some View {
        modifier(ChizukCascade(rang: rang, jouee: jouee))
    }
}
