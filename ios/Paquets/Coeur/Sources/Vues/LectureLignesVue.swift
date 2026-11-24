import Foundation
import SwiftUI
import Coeur
import Ecrans

// Les lignes du lecteur (l'Adaptateur de SiddurLectureActivity.kt, onBindViewHolder) : une vue par sorte de
// ligne (`LectureContenu`). Les lignes du texte sont de droite à gauche (LAYOUT_DIRECTION_RTL d'Android) ; les
// notes, les étiquettes, les replis et les pieds suivent la langue de l'app. Aucune image : seulement des icônes.

/// Les couleurs du rendu (ReglagesLecture.rendu) : la nuit, les quatre couleurs fixes d'Android
/// (lecture_nuit_*) ; sinon le papier, l'encre, le gris et l'accent de la palette.
struct LectureRendu {
    let fond: Color
    let texte: Color
    let discret: Color
    let titre: Color

    init(sombre: Bool, palette: PaletteApp, schema: ColorScheme) {
        if sombre {
            fond = LectureRendu.fixe(0x00, 0x00, 0x00)
            texte = LectureRendu.fixe(0xF2, 0xF0, 0xEA)
            discret = LectureRendu.fixe(0xA3, 0xA8, 0xA5)
            titre = LectureRendu.fixe(0xD6, 0xC2, 0x8C)
        } else {
            fond = palette.couleur(.paper, schema: schema)
            texte = palette.couleur(.ink, schema: schema)
            discret = palette.couleur(.muted, schema: schema)
            titre = palette.couleur(.brand, schema: schema)
        }
    }

    /// La couleur des titres à l'alpha d'Android (`setAlphaComponent(titre, 0x1C)`).
    func teinte(_ alpha: Int) -> Color {
        titre.opacity(Double(alpha) / 255)
    }

    private static func fixe(_ rouge: Int, _ vert: Int, _ bleu: Int) -> Color {
        Color(.sRGB, red: Double(rouge) / 255, green: Double(vert) / 255, blue: Double(bleu) / 255, opacity: 1)
    }
}

/// Le texte d'un paragraphe balisé : ses morceaux, chacun en gras ou non, à sa taille (`base` × taille du
/// paragraphe × taille du morceau), dans la police hébraïque choisie ou la police à empattements du système.
enum LectureTexte {
    static func texte(_ paragraphe: LectureParagraphe, base: CGFloat, police: PoliceHebraique.Police,
                      toutGras: Bool = false) -> Text {
        var tout = AttributedString()
        for segment in paragraphe.segments {
            var morceau = AttributedString(segment.texte)
            let taille = base * CGFloat(paragraphe.taille) * CGFloat(segment.taille)
            let fonte: Font = paragraphe.policeHebraique
                ? Font.hebreu(police, taille: taille)
                : Font.system(size: taille, design: .serif)
            morceau.font = (segment.gras || toutGras) ? fonte.bold() : fonte
            tout.append(morceau)
        }
        return Text(tout)
    }
}

/// Une ligne du lecteur.
struct LectureLigneVue: View {
    let ligne: LectureLigne
    let modele: LectureModele
    let rendu: LectureRendu
    let ouvrir: @MainActor (LectureRoute) -> Void

    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var sansAnimation
    /// Les tailles d'Android sont en sp : elles suivent la taille du texte du téléphone, comme Dynamic Type.
    @ScaledMetric(relativeTo: .body) private var unite: CGFloat = 100

    /// L'échelle de lecture (A−, A+) et celle du téléphone.
    private var e: CGFloat {
        CGFloat(modele.echelle) * unite / 100
    }

    var body: some View {
        switch ligne.contenu {
        case .note(let libelle):
            note(libelle)
        case .titre(let titre):
            titreVue(titre)
        case .bloc(let bloc):
            LectureBlocVue(bloc: bloc, modele: modele, rendu: rendu, e: e)
        case .etiquette(let nom):
            etiquette(nom)
        case .indice(let texte):
            indice(texte)
        case .renvoi(let renvoi):
            renvoiVue(renvoi)
        case .replie(let repli):
            LectureRepliVue(repli: repli, modele: modele, rendu: rendu)
        case .seul(let seul):
            seulVue(seul)
        case .pied(let cle):
            pied(cle)
        }
    }

    private var aujourdhui: String {
        traducteur.texte(cle: "siddur_aujourdhui")
    }

    // MARK: Les lignes simples

    /// Une note de tête : petite, discrète, dans le sens de la langue de l'app.
    private func note(_ libelle: Libelle) -> some View {
        Text(libelle, traducteur: traducteur)
            .font(.caption)
            .foregroundStyle(rendu.discret)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
    }

    /// Le titre d'une section : 20 × échelle, gras, couleur des titres ; la traduction dessous à 0,72.
    private func titreVue(_ titre: LectureTitre) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(titre.paragraphes.enumerated()), id: \.offset) { _, paragraphe in
                LectureTexte.texte(paragraphe, base: 20 * e, police: modele.police, toutGras: true)
                    .foregroundStyle(rendu.titre)
                    .lectureSens(droiteAGauche: paragraphe.droiteAGauche)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, ligne.position == 0 ? 8 : 32)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .environment(\.layoutDirection, .rightToLeft)
    }

    /// « Aujourd'hui · <nom> » au-dessus d'un ajout du jour.
    private func etiquette(_ nom: Libelle) -> some View {
        Text(verbatim: aujourdhui + " \u{00B7} " + traducteur.texte(nom))
            .font(Font.caption.bold())
            .foregroundStyle(rendu.titre)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .background(rendu.teinte(0x1C))
    }

    /// « Aujourd'hui : המלך הקדוש » sous un bloc.
    private func indice(_ texte: String) -> some View {
        Text(verbatim: aujourdhui + " : " + texte)
            .font(.hebreu(modele.police, taille: 12 * e))
            .foregroundStyle(rendu.titre)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .environment(\.layoutDirection, .rightToLeft)
    }

    /// « Aujourd'hui · הַלֵּל › » : le texte de ce jour, ouvert d'un toucher (inerte s'il n'existe pas).
    @ViewBuilder
    private func renvoiVue(_ renvoi: LectureRenvoi) -> some View {
        let libelle = aujourdhui + " \u{00B7} " + renvoi.titre + "  \u{203A}"
        let corps = Text(verbatim: libelle)
            .font(Font.hebreu(modele.police, taille: 15 * e).bold())
            .foregroundStyle(rendu.titre)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(rendu.teinte(0x1C))
            .environment(\.layoutDirection, .rightToLeft)
        if let route = renvoi.route {
            Button {
                ouvrir(route)
            } label: {
                corps.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: libelle))
        } else {
            corps
        }
    }

    /// Qui prie seul : une carte à part, l'étiquette petite, la consigne discrète, le texte en grand.
    private func seulVue(_ seul: LectureSeul) -> some View {
        let base = 19 * e
        return VStack(alignment: .leading, spacing: 6 * e) {
            Text(seul.etiquette, traducteur: traducteur)
                .font(Font.hebreu(modele.police, taille: base * 0.68).bold())
                .foregroundStyle(rendu.titre)
            if let consigne = seul.consigne {
                Text(verbatim: consigne)
                    .font(.hebreu(modele.police, taille: base * 0.68))
                    .foregroundStyle(rendu.discret)
            }
            Text(verbatim: seul.texte)
                .font(.hebreu(modele.police, taille: seul.texteDiscret ? base * 0.75 : base))
                .foregroundStyle(seul.texteDiscret ? rendu.discret : rendu.texte)
                .lineSpacing(6 * e)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background {
            LecturePanneau(couleur: rendu.teinte(0x10), haut: true, bas: true, trait: rendu.teinte(0x38))
                .padding(8)
        }
        .accessibilityElement(children: .combine)
        .environment(\.layoutDirection, .rightToLeft)
    }

    /// Le pied d'un ajout déplié : « Replier », un chevron vers le haut ; le toucher le referme.
    private func pied(_ cle: String) -> some View {
        Button {
            if sansAnimation {
                modele.replierDepuisLePied(cle)
            } else {
                withAnimation(.easeOut(duration: 0.18)) {
                    modele.replierDepuisLePied(cle)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.up")
                    .font(Font.subheadline.weight(.semibold))
                    .accessibilityHidden(true)
                Text(Libelle("siddur_replier"), traducteur: traducteur)
                    .font(Font.subheadline.bold())
            }
            .foregroundStyle(rendu.titre)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 18)
            // minHeight d'Android : marges comprises.
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                LecturePanneau(couleur: rendu.teinte(0x10), haut: false, bas: true, trait: nil)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 10)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: Le paragraphe

/// Un paragraphe de prière, une consigne, ou un paragraphe de livre ; un appui long le marque ou le démarque.
struct LectureBlocVue: View {
    let bloc: LectureBloc
    let modele: LectureModele
    let rendu: LectureRendu
    let e: CGFloat

    @Environment(\.traducteur) private var traducteur
    /// Change à chaque appui long : le retour haptique d'Android (performLongClick).
    @State private var appuis = 0

    var body: some View {
        // Calculés à la demande : la liste est paresseuse, et un livre compte des milliers de paragraphes.
        let paragraphes = bloc.paragraphes
        let consigne = bloc.consigne
        let base = (consigne ? 12 : 19) * e
        let couleur = consigne ? rendu.discret : rendu.texte
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: (consigne ? 3 : 8) * e) {
                ForEach(Array(paragraphes.enumerated()), id: \.offset) { _, paragraphe in
                    LectureTexte.texte(paragraphe, base: base, police: modele.police)
                        .foregroundStyle(paragraphe.discret ? rendu.discret : couleur)
                        .lineSpacing((consigne ? 3 : 8) * e)
                        .lectureSens(droiteAGauche: paragraphe.droiteAGauche)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if bloc.marque {
                SiddourIcone(modele.iconeMarques, taille: 16)
                    .foregroundStyle(rendu.titre)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, consigne ? 24 : 14)
        .padding(.bottom, consigne ? 4 : 26)
        .background { fond }
        .overlay(alignment: .leading) {
            if bloc.marque {
                // Le marque-page : un trait de la couleur des titres au début du paragraphe.
                Rectangle()
                    .fill(rendu.titre)
                    .frame(width: 4)
                    .accessibilityHidden(true)
            }
        }
        .opacity(bloc.estompe ? 0.55 : 1)
        .contentShape(Rectangle())
        .onLongPressGesture {
            appuis += 1
            basculerMarque()
        }
        .sensoryFeedback(.impact, trigger: appuis)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text(Libelle("marques_titre"), traducteur: traducteur)) {
            basculerMarque()
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    /// Un ajout du jour : teinté ; déplié depuis un repli : dans le voile de son panneau.
    @ViewBuilder
    private var fond: some View {
        if bloc.dansPanneau {
            LecturePanneau(couleur: rendu.teinte(0x10), haut: false, bas: false, trait: nil)
                .padding(.horizontal, 8)
        } else if bloc.duJour {
            rendu.teinte(0x1C)
        }
    }

    private func basculerMarque() {
        let bloc = self.bloc
        let modele = self.modele
        SiddourTache.lancer { try await modele.basculerMarque(bloc) }
    }
}

// MARK: Le repli

/// Le bandeau d'un ajout replié ou déplié : le chevron, le nom en gras, et dessous ce que fait un toucher.
struct LectureRepliVue: View {
    let repli: LectureRepli
    let modele: LectureModele
    let rendu: LectureRendu

    @Environment(\.traducteur) private var traducteur
    @Environment(\.layoutDirection) private var sens
    @Environment(\.accessibilityReduceMotion) private var sansAnimation

    var body: some View {
        Button {
            basculer()
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "chevron.forward")
                    .font(Font.body.weight(.semibold))
                    .foregroundStyle(rendu.titre)
                    .frame(width: 22, height: 22)
                    // Un quart de tour vers le bas une fois ouvert (le chevron d'hébreu pointe à gauche).
                    .rotationEffect(.degrees(repli.ouvert ? (sens == .rightToLeft ? -90 : 90) : 0))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(repli.nom, traducteur: traducteur)
                        .font(Font.subheadline.bold())
                        .foregroundStyle(rendu.texte)
                    Text(repli.etat, traducteur: traducteur)
                        .font(.caption)
                        .foregroundStyle(rendu.discret)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, repli.ouvert ? 12 : 18)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background {
                LecturePanneau(couleur: rendu.teinte(repli.ouvert ? 0x1E : 0x12), haut: true, bas: !repli.ouvert,
                               trait: repli.ouvert ? nil : rendu.teinte(0x38))
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                    .padding(.bottom, repli.ouvert ? 0 : 6)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: traducteur.texte(repli.nom) + ", " + traducteur.texte(repli.etat)))
    }

    /// Le chevron tourne et les lignes glissent en place (260 ms) ; sans animation si « Réduire les animations ».
    private func basculer() {
        if sansAnimation {
            modele.basculer(repli.cle)
        } else {
            withAnimation(.easeOut(duration: 0.26)) {
                modele.basculer(repli.cle)
            }
        }
    }
}

// MARK: Les aides

/// Un fond en panneau (SiddurLectureActivity.panneau) : coins de 16 en haut et/ou en bas, un filet d'un point
/// s'il y en a un. Le retrait des bords revient à qui le pose.
struct LecturePanneau: View {
    let couleur: Color
    let haut: Bool
    let bas: Bool
    let trait: Color?

    var body: some View {
        let r: CGFloat = 16
        let forme = UnevenRoundedRectangle(topLeadingRadius: haut ? r : 0, bottomLeadingRadius: bas ? r : 0,
                                           bottomTrailingRadius: bas ? r : 0, topTrailingRadius: haut ? r : 0,
                                           style: .continuous)
        forme
            .fill(couleur)
            .overlay {
                if let trait {
                    forme.strokeBorder(trait, lineWidth: 1)
                }
            }
            .accessibilityHidden(true)
    }
}

extension View {
    /// Un paragraphe dans le sens de sa langue, calé sur son début (TEXT_DIRECTION_FIRST_STRONG,
    /// TEXT_ALIGNMENT_TEXT_START d'Android).
    func lectureSens(droiteAGauche: Bool) -> some View {
        multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, droiteAGauche ? .rightToLeft : .leftToRight)
    }
}
