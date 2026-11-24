import Foundation
import SwiftUI
import Coeur
import Ecrans

// Les cartes de l'accueil : le mot de relance après une série rompue (view_chizuk), les cartes du moment
// (accueil_moment : RappelsTefilaVue.cartes, AccueilMoment.carte, SourceDuJour.carte) et le bilan de la semaine
// (MainActivity.bilanDeLaSemaine). Tout leur texte vient du modèle.

// MARK: Les cartes du moment

/// Une carte du moment, selon son genre.
struct AccueilCarteVue: View {
    let carte: AccueilCarte
    let police: PoliceHebraique.Police
    let langue: String
    let ouvrir: @MainActor (AccueilRoute) -> Void

    init(carte: AccueilCarte, police: PoliceHebraique.Police, langue: String,
         ouvrir: @escaping @MainActor (AccueilRoute) -> Void) {
        self.carte = carte
        self.police = police
        self.langue = langue
        self.ouvrir = ouvrir
    }

    var body: some View {
        switch carte {
        case .rappel(let rappel):
            AccueilRappelVue(rappel: rappel, langue: langue)
        case .priere(let priere):
            AccueilPriereVue(priere: priere, police: police, langue: langue, ouvrir: ouvrir)
        case .source(let source):
            AccueilSourceVue(source: source, police: police, langue: langue, ouvrir: ouvrir)
        }
    }
}

/// Un changement dans la tefila (VueJour.carte : 16 de marge intérieure, 16 de marge sur les côtés) : le titre, la
/// phrase, la source, centrés.
private struct AccueilRappelVue: View {
    let rappel: AccueilRappel
    let langue: String

    @Environment(\.traducteur) private var traducteur

    init(rappel: AccueilRappel, langue: String) {
        self.rappel = rappel
        self.langue = langue
    }

    var body: some View {
        let langue = self.langue
        VStack(spacing: 0) {
            Text(rappel.titre, traducteur: traducteur)
                .tropheeTexte(19, gras: true)
                .foregroundStyle(Teinte(.ink))
            Text(rappel.corps(jourSemaine: { AccueilDates.jourEnLettres($0, langue: langue) }), traducteur: traducteur)
                .tropheeTexte(16)
                .lineSpacing(4)
                .foregroundStyle(Teinte(.ink))
                .padding(.top, 8)
            Text(rappel.source, traducteur: traducteur)
                .tropheeTexte(12)
                .foregroundStyle(Teinte(.muted))
                .padding(.top, 8)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(16)
        .fondCarteBibliotheque()
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }
}

/// La prière de l'heure, ou Birkat haLevana (AccueilMoment.carte) : le personnage, l'étiquette, le titre hébreu
/// et le mot du moment, le chevron ; toute la carte se touche et se creuse sous le doigt.
private struct AccueilPriereVue: View {
    let priere: AccueilPriere
    let police: PoliceHebraique.Police
    let langue: String
    let ouvrir: @MainActor (AccueilRoute) -> Void

    @Environment(\.traducteur) private var traducteur

    init(priere: AccueilPriere, police: PoliceHebraique.Police, langue: String,
         ouvrir: @escaping @MainActor (AccueilRoute) -> Void) {
        self.priere = priere
        self.police = police
        self.langue = langue
        self.ouvrir = ouvrir
    }

    var body: some View {
        Button {
            ouvrir(priere.route)
        } label: {
            HStack(spacing: 12) {
                Illustration(decorative: priere.image)
                    .frame(width: 48, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: traducteur.texte(priere.etiquette).uppercased(with: Locale(identifier: langue)))
                        .tropheeTexte(12, interlettrage: 0.06)
                        .foregroundStyle(Teinte(.brand))
                    Text(verbatim: priere.hebreu)
                        .bold()
                        .policeHebraique(police, taille: 21)
                        .foregroundStyle(Teinte(.ink))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.layoutDirection, .rightToLeft)
                    if let mot = priere.mot {
                        Text(mot, traducteur: traducteur)
                            .tropheeTexte(13)
                            .foregroundStyle(Teinte(.muted))
                    }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward")
                    .font(.title2)
                    .foregroundStyle(Teinte(.brand))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .fondCarteBibliotheque()
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(AccueilBoutonCreux())
        .accessibilityElement(children: .combine)
    }
}

/// La source du jour (SourceDuJour.carte) : le titre, l'extrait hébreu, la référence, « Lire la suite ».
private struct AccueilSourceVue: View {
    let source: AccueilSource
    let police: PoliceHebraique.Police
    let langue: String
    let ouvrir: @MainActor (AccueilRoute) -> Void

    @Environment(\.traducteur) private var traducteur

    init(source: AccueilSource, police: PoliceHebraique.Police, langue: String,
         ouvrir: @escaping @MainActor (AccueilRoute) -> Void) {
        self.source = source
        self.police = police
        self.langue = langue
        self.ouvrir = ouvrir
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: traducteur.texte(source.titre).uppercased(with: Locale(identifier: langue)))
                    .tropheeTexte(12, interlettrage: 0.06)
                    .foregroundStyle(Teinte(.brand))
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: source.texte)
                    .policeHebraique(police, taille: 18)
                    .lineSpacing(4)
                    .foregroundStyle(Teinte(.ink))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .rightToLeft)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                Text(verbatim: source.reference)
                    .italic()
                    .tropheeTexte(13)
                    .foregroundStyle(Teinte(.muted))
            }
            .accessibilityElement(children: .combine)
            Button {
                ouvrir(source.route)
            } label: {
                Text(source.bouton, traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondaire)
            .padding(.top, 8)
        }
        .multilineTextAlignment(.leading)
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .fondCarteBibliotheque()
    }
}

/// L'entrée en cascade des cartes du moment (Effets.enfants) : chaque carte part 14 pt plus bas, effacée, et
/// arrive en 420 ms, 45 ms après la précédente (8 écarts au plus). Le modèle ne la demande pas quand les
/// animations sont réduites.
struct AccueilCascade: ViewModifier {
    let rang: Int
    let visible: Bool

    init(rang: Int, visible: Bool) {
        self.rang = rang
        self.visible = visible
    }

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 14)
            .animation(Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.42).delay(0.045 * Double(min(rang, 8))),
                       value: visible)
    }
}

// MARK: Le mot de relance

/// Le mot de relance (view_chizuk.xml, ChizukCard.bind), comme sur l'écran 'Hizouk : l'illustration du moment et
/// son nom, le badge « à relire » en debug, le texte, un filet, la traduction, la source. VoiceOver la lit d'un
/// trait.
struct AccueilRelanceVue: View {
    let carte: ChizukCarte

    @Environment(\.traducteur) private var traducteur

    init(carte: ChizukCarte) {
        self.carte = carte
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                BibliothequeCadre(image: carte.image, largeur: 54, hauteur: 64, fond: .stageSoft)
                VStack(alignment: .leading, spacing: 4) {
                    Text(carte.moment, traducteur: traducteur)
                        .font(Font.subheadline.bold())
                        .foregroundStyle(Teinte(.brand))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if carte.aRelire {
                        AccueilBadgeARelire()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, 12)
            premierTexte
            Rectangle()
                .fill(Teinte(.line))
                .frame(height: 1)
                .padding(.vertical, 8)
                .accessibilityHidden(true)
            if let second = carte.second {
                Text(verbatim: second)
                    .tropheeTexte(15)
                    .lineSpacing(2)
                    .foregroundStyle(Teinte(.muted))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
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

    /// L'hébreu de droite à gauche en Noto Serif Hebrew ; une traduction seule, de gauche à droite.
    @ViewBuilder
    private var premierTexte: some View {
        if carte.texteDroiteAGauche {
            Text(verbatim: carte.texte)
                .policeHebraique(.serif, taille: 19)
                .lineSpacing(2)
                .foregroundStyle(Teinte(.ink))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .rightToLeft)
        } else {
            Text(verbatim: carte.texte)
                .tropheeTexte(19)
                .lineSpacing(2)
                .foregroundStyle(Teinte(.ink))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .leftToRight)
        }
    }
}

/// Le badge « à relire » (bg_badge_warning.xml) : `warning` sur `warning_wash`, couleurs qu'Android écrit en dur.
private struct AccueilBadgeARelire: View {
    @Environment(\.colorScheme) private var schema
    @Environment(\.traducteur) private var traducteur

    init() {}

    var body: some View {
        let nuit = schema == .dark
        let avertissement = nuit ? BibliothequeNuit.couleur(0xE8, 0xA0, 0x62) : BibliothequeNuit.couleur(0xA8, 0x56, 0x1F)
        let lavis = nuit ? BibliothequeNuit.couleur(0xE8, 0xA0, 0x62, opacite: 0x33 / 255.0)
            : BibliothequeNuit.couleur(0xC6, 0x6B, 0x2D, opacite: 0x1F / 255.0)
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

// MARK: Le bilan de la semaine

/// La boîte du bilan (MainActivity.bilanDeLaSemaine) : le titre, les minutes, l'écart à la semaine d'avant, le
/// record, les trophées gagnés en médailles, « Continuer ».
struct AccueilBilanVue: View {
    let bilan: AccueilBilan
    let formes: TropheeFormes
    let fermer: @MainActor () -> Void

    @Environment(\.traducteur) private var traducteur

    init(bilan: AccueilBilan, formes: TropheeFormes, fermer: @escaping @MainActor () -> Void) {
        self.bilan = bilan
        self.formes = formes
        self.fermer = fermer
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(bilan.titre, traducteur: traducteur)
                    .tropheeTexte(20, gras: true)
                    .foregroundStyle(Teinte(.ink))
                    .accessibilityAddTraits(.isHeader)
                Text(bilan.minutes, traducteur: traducteur)
                    .tropheeTexte(17, gras: true)
                    .foregroundStyle(Teinte(.ink))
                    .padding(.top, 16)
                if let plus = bilan.plus {
                    Text(plus, traducteur: traducteur)
                        .tropheeTexte(15)
                        .foregroundStyle(Teinte(.muted))
                        .padding(.top, 6)
                }
                if let record = bilan.record {
                    Text(record, traducteur: traducteur)
                        .tropheeTexte(15, gras: true)
                        .foregroundStyle(Teinte(.brand))
                        .padding(.top, 6)
                }
                if let titreTrophees = bilan.titreTrophees {
                    Text(titreTrophees, traducteur: traducteur)
                        .tropheeTexte(15)
                        .foregroundStyle(Teinte(.muted))
                        .padding(.top, 10)
                    medailles
                        .padding(.top, 8)
                }
                Button {
                    fermer()
                } label: {
                    Text(bilan.bouton, traducteur: traducteur)
                        .tropheeTexte(14, gras: true)
                        .foregroundStyle(Teinte(.brand))
                        .padding(.horizontal, 12)
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 16)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 8)
        }
        .background(Teinte(.card))
    }

    private var medailles: some View {
        HStack(spacing: 6) {
            ForEach(bilan.trophees) { trophee in
                TropheeObjet(formes.dessin(trophee.forme, metal: trophee.metal, icone: trophee.icone))
                    .frame(width: 40, height: 40)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(trophee.description, traducteur: traducteur))
            }
        }
    }
}
