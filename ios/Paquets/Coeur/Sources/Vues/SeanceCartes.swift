import Foundation
import SwiftUI
import Coeur
import Ecrans

// Les cartes et les pièces de l'écran de séance (activity_session.xml) et du bravo (activity_celebration.xml) : la
// carte de 'hizouk (view_chizuk.xml, et sa forme compacte view_chizuk_compact.xml), la hitbodedout guidée
// (view_hitbodedut.xml), la carte « une question à la fois » (bg_question_carte.xml), « Je n'arrive pas à
// parler », la lueur du souffle (SouffleView.kt) et le bouton à contour menthe. Aucune décision ici : tout se lit
// dans SeanceModele et CelebrationModele.

// MARK: Les couleurs écrites en dur par Android

/// Les couleurs qu'Android écrit en dur sur le fond sombre de la séance (values/colors.xml) : le blanc du grand
/// chiffre et de la question, et les blancs translucides de la carte des questions.
enum SeanceBlanc {
    static let plein = Color.white
    /// Le haut du dégradé de la carte des questions (#17FFFFFF : 9 %).
    static let carteHaut = Color.white.opacity(0x17 / 255.0)
    /// Le bas du dégradé (#0AFFFFFF : 4 %).
    static let carteBas = Color.white.opacity(0x0A / 255.0)
    /// Le filet de la carte (#24FFFFFF : 14 %).
    static let filet = Color.white.opacity(0x24 / 255.0)
    /// La piste de la jauge (#1FFFFFFF : 12 %).
    static let piste = Color.white.opacity(0x1F / 255.0)
}

/// Les millisecondes Unix d'une date de `TimelineView`, l'unité des modèles.
enum SeanceTemps {
    static func millis(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }
}

// MARK: Le bouton à contour menthe

/// Le bouton à contour de la séance (Widget.Material3.Button.OutlinedButton, DurationButton) : une pilule cerclée
/// de `contour_menthe` (la menthe à 40 %), texte menthe ; 48 de haut au moins (44 pour « Question suivante »).
struct SeanceBoutonContour: ButtonStyle {
    let hauteurMin: CGFloat
    let margeLaterale: CGFloat

    init(hauteurMin: CGFloat = 48, margeLaterale: CGFloat = 16) {
        self.hauteurMin = hauteurMin
        self.margeLaterale = margeLaterale
    }

    func makeBody(configuration: Configuration) -> some View {
        SeanceCorpsContour(configuration: configuration, hauteurMin: hauteurMin, margeLaterale: margeLaterale)
    }
}

private struct SeanceCorpsContour: View {
    let configuration: ButtonStyleConfiguration
    let hauteurMin: CGFloat
    let margeLaterale: CGFloat
    @Environment(\.isEnabled) private var actif

    init(configuration: ButtonStyleConfiguration, hauteurMin: CGFloat, margeLaterale: CGFloat) {
        self.configuration = configuration
        self.hauteurMin = hauteurMin
        self.margeLaterale = margeLaterale
    }

    var body: some View {
        configuration.label
            .foregroundStyle(Teinte(.mint))
            .padding(.horizontal, margeLaterale)
            .frame(minHeight: hauteurMin)
            .overlay {
                Capsule().strokeBorder(Teinte(.mint).opacity(0.4), lineWidth: 1)
            }
            .contentShape(Capsule())
            .opacity(actif ? (configuration.isPressed ? 0.6 : 1) : 0.38)
    }
}

/// Un bouton texte de la séance (Widget.Material3.Button.TextButton) : texte medium de la couleur donnée, 48 de
/// haut au moins, toute sa largeur se touche.
struct SeanceBoutonTexte: ButtonStyle {
    let couleur: Jeton

    init(couleur: Jeton = .mint) {
        self.couleur = couleur
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Font.subheadline.weight(.medium))
            .foregroundStyle(Teinte(couleur))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: La carte de 'hizouk

/// La carte de 'hizouk (view_chizuk.xml ; `compacte` : view_chizuk_compact.xml, sous le bravo) : l'illustration du
/// moment et son nom, le badge « à relire », le texte (hébreu ou traduction seule) dans sa hauteur fixe, un filet,
/// la traduction, la source. VoiceOver la lit d'un trait.
struct SeanceCarteChizukVue: View {
    let carte: SeanceCarteChizuk
    let compacte: Bool
    @Environment(\.traducteur) private var traducteur
    /// Un téléphone en portrait a toujours plus de 480 points de haut : les hauteurs de values-h480dp.
    @Environment(\.verticalSizeClass) private var classeVerticale

    init(carte: SeanceCarteChizuk, compacte: Bool = false) {
        self.carte = carte
        self.compacte = compacte
    }

    private var haut: Bool {
        classeVerticale != .compact
    }

    private var hauteurTexte: CGFloat {
        if compacte { return 78 }
        return haut ? 150 : 108
    }

    private var hauteurSecond: CGFloat {
        if compacte { return 62 }
        return haut ? 116 : 84
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
                SeanceTexteAjuste(texte: second, police: nil, tailleMax: compacte ? 14 : 15, tailleMin: 12,
                                  hauteur: hauteurSecond, style: .muted)
            }
            Text(verbatim: carte.reference)
                .font(.caption2)
                .foregroundStyle(Teinte(.muted))
                .lineLimit(1)
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
            BibliothequeCadre(image: carte.image, largeur: compacte ? 44 : 54, hauteur: compacte ? 52 : 64,
                              fond: .stageSoft)
            VStack(alignment: .leading, spacing: 4) {
                Text(carte.titre, traducteur: traducteur)
                    .font(compacte ? Font.footnote.bold() : Font.subheadline.bold())
                    .foregroundStyle(Teinte(.brand))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                if carte.aRelire {
                    SeanceBadgeARelire()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// L'hébreu de droite à gauche, aligné au début ; une traduction seule, de gauche à droite. Toujours en Noto
    /// Serif Hebrew, comme sur Android.
    @ViewBuilder
    private var premierTexte: some View {
        let texte = SeanceTexteAjuste(texte: carte.texte, police: .serif, tailleMax: compacte ? 17 : 19, tailleMin: 12,
                                      hauteur: hauteurTexte, style: .ink)
        if carte.texteDroiteAGauche {
            texte.environment(\.layoutDirection, .rightToLeft)
        } else {
            texte.environment(\.layoutDirection, .leftToRight)
        }
    }
}

/// Le badge « à relire » (bg_badge_warning.xml) : 11 sp, couleur `warning` sur `warning_wash`, cerclé de `warning`.
/// Android écrit ces couleurs en dur (values/colors.xml et values-night).
private struct SeanceBadgeARelire: View {
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
private struct SeanceTexteAjuste: View {
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

// MARK: La hitbodedout guidée

/// La carte de la hitbodedout guidée (view_hitbodedut.xml, HitbodedutCard.bind) : l'illustration du temps, sa
/// pastille « 2 / 5 » et son intitulé hébreu, puis le titre, l'invitation, l'invitation du sujet, la source, et
/// « Précédent » / « Suivant », dont la place reste quand ils sont cachés.
struct SeanceGuideVue: View {
    let guide: SeanceGuide
    let libellePrecedent: Libelle
    let libelleSuivant: Libelle
    let precedent: @MainActor () -> Void
    let suivant: @MainActor () -> Void
    @Environment(\.traducteur) private var traducteur

    init(guide: SeanceGuide, libellePrecedent: Libelle, libelleSuivant: Libelle,
         precedent: @escaping @MainActor () -> Void, suivant: @escaping @MainActor () -> Void) {
        self.guide = guide
        self.libellePrecedent = libellePrecedent
        self.libelleSuivant = libelleSuivant
        self.precedent = precedent
        self.suivant = suivant
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            entete
            Text(guide.titre, traducteur: traducteur)
                .font(Font.subheadline.bold())
                .foregroundStyle(Teinte(.brand))
                .multilineTextAlignment(.leading)
                .padding(.top, 12)
            Text(guide.invitation, traducteur: traducteur)
                .font(.subheadline)
                .foregroundStyle(Teinte(.muted))
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .padding(.top, 4)
            if let sujet = guide.sujet {
                Text(verbatim: sujet)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
                    .multilineTextAlignment(.leading)
                    .padding(.top, 6)
            }
            Text(verbatim: guide.source)
                .font(.caption2)
                .foregroundStyle(Teinte(.muted))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .rightToLeft)
                .padding(.top, 8)
            boutons
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .fondCarteBibliotheque()
    }

    private var entete: some View {
        HStack(alignment: .top, spacing: 12) {
            BibliothequeCadre(image: guide.image, largeur: 54, hauteur: 64, fond: .stageSoft)
            VStack(alignment: .leading, spacing: 4) {
                Etiquette(Text(guide.rang, traducteur: traducteur))
                Text(verbatim: guide.hebreu)
                    .bold()
                    .policeHebraique(.serif, taille: 17)
                    .foregroundStyle(Teinte(.ink))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var boutons: some View {
        HStack(spacing: 8) {
            Button {
                precedent()
            } label: {
                Text(libellePrecedent, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.brand))
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(guide.precedentVisible ? 1 : 0)
            .disabled(!guide.precedentVisible)
            .accessibilityHidden(!guide.precedentVisible)
            Spacer(minLength: 0)
            Button {
                suivant()
            } label: {
                Text(libelleSuivant, traducteur: traducteur)
                    .font(Font.subheadline.bold())
                    .foregroundStyle(Teinte(.brand))
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(guide.suivantVisible ? 1 : 0)
            .disabled(!guide.suivantVisible)
            .accessibilityHidden(!guide.suivantVisible)
        }
    }
}

// MARK: Une question à la fois

/// La carte « une question à la fois » (session_questions, bg_question_carte.xml) : le rang, petit et espacé, la jauge fine, la question en blanc, et « Question suivante » en fin de ligne. Le contenu fond à
/// chaque question (Effets.fondu), sauf sous « Réduire les animations ».
struct SeanceQuestionVue: View {
    let question: SeanceQuestion
    let libelleSuivante: Libelle
    let changements: Int
    let suivante: @MainActor () -> Void
    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var reduireAnimations

    init(question: SeanceQuestion, libelleSuivante: Libelle, changements: Int,
         suivante: @escaping @MainActor () -> Void) {
        self.question = question
        self.libelleSuivante = libelleSuivante
        self.changements = changements
        self.suivante = suivante
    }

    var body: some View {
        contenuFondu
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 12)
            .background(LinearGradient(colors: [SeanceBlanc.carteHaut, SeanceBlanc.carteBas],
                                       startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(SeanceBlanc.filet, lineWidth: 1)
            }
    }

    @ViewBuilder
    private var contenuFondu: some View {
        if reduireAnimations {
            contenu
        } else {
            contenu
                .phaseAnimator([true, false], trigger: changements) { vue, enPlace in
                    vue.opacity(enPlace ? 1 : 0)
                } animation: { enPlace in
                    enPlace ? Animation.easeOut(duration: 0.32) : Animation.linear(duration: 0.01)
                }
        }
    }

    private var contenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(question.position, traducteur: traducteur)
                .font(Font.caption2.bold())
                .tracking(11 * 0.12)
                .foregroundStyle(Teinte(.mint))
                .opacity(0.85)
            jauge
                .padding(.top, 8)
            Text(question.texte, traducteur: traducteur)
                .font(.title3)
                .foregroundStyle(SeanceBlanc.plein)
                .lineSpacing(6)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Button {
                    suivante()
                } label: {
                    HStack(spacing: 4) {
                        Text(libelleSuivante, traducteur: traducteur)
                            .font(.subheadline)
                        Image(systemName: "arrow.forward")
                            .font(.system(size: 15, weight: .medium))
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(SeanceBoutonContour(hauteurMin: 44))
            }
            .padding(.top, 10)
        }
    }

    /// La jauge fine (LinearProgressIndicator) : menthe sur une piste blanche à 12 %, de 2 de haut ; elle avance du
    /// côté de la fin de ligne, et se remplit en douceur. VoiceOver la passe : le rang dit déjà où l'on en est.
    private var jauge: some View {
        Capsule()
            .fill(SeanceBlanc.piste)
            .frame(height: 2)
            .overlay {
                GeometryReader { geometrie in
                    Capsule()
                        .fill(Teinte(.mint))
                        .frame(width: geometrie.size.width * CGFloat(question.progression) / 100, height: 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .animation(reduireAnimations ? nil : .easeInOut(duration: 0.3), value: question.progression)
            .accessibilityHidden(true)
    }
}

// MARK: La lueur du souffle

/// La lueur du souffle (SouffleView.kt) : un disque de menthe en dégradé radial, qui grandit en quatre secondes et
/// décroît en six, sans fin ; immobile sous « Réduire les animations ». Elle ne compte rien : VoiceOver la passe, et
/// elle ne prend aucun toucher.
struct SeanceSouffleVue: View {
    let rayon: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduireAnimations
    @Environment(\.paletteApp) private var palette
    @Environment(\.colorScheme) private var schema

    init(rayon: CGFloat) {
        self.rayon = rayon
    }

    var body: some View {
        Group {
            if reduireAnimations {
                disque(SeanceSouffle.phaseImmobile)
            } else {
                TimelineView(.animation) { contexte in
                    disque(SeanceSouffle.phase(SeanceTemps.millis(contexte.date)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var arrets: [Gradient.Stop] {
        let menthe = palette.couleur(.mint, schema: schema)
        return SeanceSouffle.degrade.map { arret in
            Gradient.Stop(color: menthe.opacity(arret.opacite), location: CGFloat(arret.position))
        }
    }

    private func disque(_ phase: Double) -> some View {
        Circle()
            .fill(RadialGradient(stops: arrets, center: .center, startRadius: 0, endRadius: max(rayon, 1)))
            .frame(width: 2 * rayon, height: 2 * rayon)
            .scaleEffect(SeanceSouffle.echelle(phase))
            .opacity(SeanceSouffle.opacite(phase))
    }
}
