import Foundation
import SwiftUI
import Coeur
import Ecrans

/// L'accueil Instant (InstantActivity.kt, 17/11, d'après une image de tableau de bord de bien-être fournie par le
/// propriétaire) : fond sombre, cartes arrondies. En tête, les réglages à gauche, la date au milieu, les textes à
/// droite ; puis la grande carte du ciel réel du moment (le paysage de Sérénité, sans arc ni nuage), avec le titre, la
/// date hébraïque, le bouton blanc et, en bas, les zmanim en petit. Dessous : la jauge de la semaine en demi-cercle et
/// la série côte à côte, les minutes des sept derniers jours en barres, le 'hizouk sur une carte vert olive, la
/// dernière note. Titres en Bellefair. La vue lit `AccueilVersionModele.instant`.
struct InstantVue: View {
    let modele: AccueilVersionModele
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        let e = modele.instant
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                entete(e)
                InstantCarteCiel(modele: modele, ecran: e)
                    .padding(.top, -8)
                // Sur l'iPad, deux colonnes (DeuxColonnes) sous le ciel : les mesures, puis le 'hizouk et le journal.
                DeuxColonnes(espacement: 12) {
                    VStack(spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            carteJauge(e)
                            carteSerie(e)
                        }
                        carteMinutes(e.minutes)
                    }
                } seconde: {
                    VStack(spacing: 12) {
                        carteHizouk(e.pensee)
                        carteJournal(e.journal)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Instant.fond.ignoresSafeArea())
    }

    // MARK: En-tête : réglages à gauche, la date, les textes à droite, comme l'image

    private func entete(_ e: InstantEcran) -> some View {
        HStack(spacing: 8) {
            rond("gearshape", Libelle("version_reglages")) { modele.ouvrirReglages() }
            Text(verbatim: VersionEcrit.chaine(e.dateCivile, traducteur))
                .tailleSp(14, relativeA: VersionPolice.style(14))
                .foregroundStyle(Instant.doux)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            rond(Onglet.textes.symbole, Libelle("version_textes")) { modele.ouvrirTextes() }
        }
        .padding(.bottom, 8)
    }

    /// Une icône dans un rond gris de 48 pt (VueVersion.icone sur fond de carte).
    private func rond(_ symbole: String, _ description: Libelle, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbole)
                .font(.title3)
                .foregroundStyle(Instant.encre)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Instant.carte))
                .contentShape(Circle())
        }
        .buttonStyle(VersionPression())
        .accessibilityLabel(Text(description, traducteur: traducteur))
    }

    // MARK: Les cartes

    private func carte<Contenu: View>(_ fond: Color = Instant.carte, @ViewBuilder contenu: () -> Contenu) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            contenu()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 18)
        .background(fond, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    /// Une carte qu'on touche pour ouvrir un écran ; elle s'enfonce un peu sous le doigt.
    private func carteTouchable<Contenu: View>(action: @escaping @MainActor () -> Void,
                                               @ViewBuilder contenu: () -> Contenu) -> some View {
        Button(action: action) {
            carte(contenu: contenu)
                .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(VersionPression())
    }

    private func titre(_ texte: Libelle, couleur: Color = Instant.encre) -> some View {
        Text(texte, traducteur: traducteur)
            .tailleSp(15, poids: .bold, relativeA: VersionPolice.style(15))
            .foregroundStyle(couleur)
            .accessibilityAddTraits(.isHeader)
    }

    private func carteJauge(_ e: InstantEcran) -> some View {
        carte {
            titre(Libelle("instant_semaine"))
            ZStack(alignment: .bottom) {
                InstantJauge(fraction: e.fraction)
                    .frame(height: 96)
                    .accessibilityHidden(true)
                Text(verbatim: "\(e.semaineFaits) / \(e.semaineDus)")
                    .font(VersionPolice.bellefair(22))
                    .foregroundStyle(Instant.encre)
                    .monospacedDigit()
                    .uneLigne(retrecie: 0.7)
                    .accessibilityHidden(true)
            }
            .padding(.top, 10)
            Text(Libelle("instant_cette_semaine"), traducteur: traducteur)
                .tailleSp(12, relativeA: VersionPolice.style(12))
                .foregroundStyle(Instant.doux)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: traducteur.texte(Libelle("instant_semaine")) + ", "
            + traducteur.texte(e.accessibiliteSemaine)))
    }

    private func carteSerie(_ e: InstantEcran) -> some View {
        carteTouchable(action: { modele.ouvrirParcours() }) {
            titre(Libelle("instant_serie"))
            Text(verbatim: "\(e.serie)")
                .font(VersionPolice.bellefair(44))
                .foregroundStyle(Instant.encre)
                .monospacedDigit()
                .padding(.top, 8)
            Text(e.joursSerie, traducteur: traducteur)
                .tailleSp(12, relativeA: VersionPolice.style(12))
                .foregroundStyle(Instant.doux)
            Text(e.total, traducteur: traducteur)
                .tailleSp(12, relativeA: VersionPolice.style(12))
                .foregroundStyle(Instant.olive)
                .padding(.top, 12)
        }
        .accessibilityElement(children: .combine)
    }

    private func carteMinutes(_ m: InstantMinutes) -> some View {
        carteTouchable(action: { modele.ouvrirJournal() }) {
            titre(Libelle("instant_minutes"))
            Text(m.total, traducteur: traducteur)
                .font(VersionPolice.bellefair(26))
                .foregroundStyle(Instant.encre)
                .padding(.top, 6)
            Text(m.libelleMoyenne, traducteur: traducteur)
                .tailleSp(12, relativeA: VersionPolice.style(12))
                .foregroundStyle(Instant.doux)
            InstantBarres(minutes: m, initiales: m.jours.map { AccueilDate.texte($0, langue: traducteur.langue,
                                                                                   motif: "EEEEE") })
                .frame(height: 130)
                .padding(.top, 10)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: traducteur.texte(Libelle("instant_minutes")) + " : "
                    + m.minutes.map(String.init).joined(separator: ", ")))
        }
    }

    private func carteHizouk(_ pensee: VersionPensee?) -> some View {
        Button {
            modele.ouvrirChizuk()
        } label: {
            carte(Instant.olive) {
                Text(Libelle("pile_hizouk"), traducteur: traducteur)
                    .tailleSp(11, poids: .bold, relativeA: VersionPolice.style(11))
                    .textCase(.uppercase)
                    .tracking(1.3)
                    .foregroundStyle(Instant.oliveEncre)
                if let pensee {
                    VersionHebreu(texte: pensee.hebreu, taille: 18, couleur: Instant.oliveEncre, police: modele.police,
                                  lignes: 3)
                        .padding(.top, 6)
                    Text(verbatim: pensee.reference)
                        .tailleSp(12, relativeA: VersionPolice.style(12))
                        .foregroundStyle(Instant.oliveDoux)
                        .padding(.top, 6)
                } else {
                    Text(Libelle("version_chargement"), traducteur: traducteur)
                        .tailleSp(15, relativeA: VersionPolice.style(15))
                        .foregroundStyle(Instant.oliveEncre)
                        .padding(.top, 6)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(VersionPression())
        .accessibilityElement(children: .combine)
    }

    private func carteJournal(_ j: InstantJournal) -> some View {
        carte {
            titre(Libelle("pile_journal"))
            Group {
                if let jour = j.jour, let duree = j.duree {
                    Text(verbatim: VersionEcrit.chaine(jour, traducteur) + " · " + traducteur.texte(duree))
                } else {
                    Text(Libelle("version_journal_vide"), traducteur: traducteur)
                }
            }
            .tailleSp(13, relativeA: VersionPolice.style(13))
            .foregroundStyle(Instant.doux)
            .padding(.top, 4)
            // Le texte de la note reste dans le journal (décision du 24/11).
            if j.noteEcrite {
                Text(Libelle("version_note_ecrite"), traducteur: traducteur)
                    .tailleSp(15, relativeA: VersionPolice.style(15))
                    .foregroundStyle(Instant.doux)
                    .padding(.top, 6)
            }
            VersionBouton(libelle: Text(Libelle("version_ecrire_note"), traducteur: traducteur), fond: Instant.olive,
                          encre: Instant.oliveEncre, police: .subheadline.weight(.semibold)) {
                modele.ecrireNote()
            }
            .padding(.top, 14)
        }
    }
}

/// Les couleurs de l'image : noir doux, cartes grises, vert olive, orangé (InstantActivity.FOND…).
enum Instant {
    static let fond = VersionCouleur.argb(0xFF141414)
    static let carte = VersionCouleur.argb(0xFF232323)
    static let encre = VersionCouleur.argb(0xFFF2F2F2)
    static let doux = VersionCouleur.argb(0xFF9A9A9A)
    static let noir = VersionCouleur.argb(0xFF141414)
    static let olive = VersionCouleur.argb(0xFFC2D67A)
    static let oliveEncre = VersionCouleur.argb(0xFF1E2410)
    static let oliveDoux = VersionCouleur.argb(0xFF46512A)
    static let orange = VersionCouleur.argb(0xFFE8865A)
    static let graduation = VersionCouleur.argb(0xFF3A3A3A)
    static let barre = VersionCouleur.argb(0xFF5C5C5C)
}

// MARK: - La carte du ciel

/// La grande carte du ciel (au moins 300 pt, coins de 28) : le paysage du ciel réel du moment, un voile en haut et en
/// bas pour que le texte reste lisible sur un ciel clair ; en haut le titre, la date hébraïque et le bouton blanc (la
/// séance d'un seul geste, ou y revenir) ; en bas les zmanim en petit, qui ouvrent l'écran des zmanim. Elle grandit
/// avec son contenu (texte agrandi, écran étroit) au lieu de faire chevaucher le titre et les zmanim (17/11).
private struct InstantCarteCiel: View {
    let modele: AccueilVersionModele
    let ecran: InstantEcran
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(ecran.titre, traducteur: traducteur)
                    .font(VersionPolice.bellefair(30))
                    .foregroundStyle(Color.white)
                    .accessibilityAddTraits(.isHeader)
                if let hebraique = ecran.dateHebraique {
                    Text(verbatim: hebraique)
                        .tailleSp(14, relativeA: VersionPolice.style(14))
                        .foregroundStyle(Color.white)
                        .padding(.top, 2)
                }
                Button {
                    modele.commencerSeance()
                } label: {
                    Text(ecran.bouton, traducteur: traducteur)
                        .tailleSp(15, poids: .bold, relativeA: VersionPolice.style(15))
                        .foregroundStyle(Instant.noir)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(Color.white))
                        .contentShape(Capsule())
                }
                .buttonStyle(VersionPression(echelle: 0.98))
                .padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Sous le titre et la date, un voile de plus que celui de la carte, sur toute sa largeur : sur le ciel clair
            // de midi, le petit texte blanc garde 4,5:1 (le voile d'Android seul s'éclaircit vers le milieu de la carte).
            .background(alignment: .top) { InstantCarteCiel.voile(haut: true) }
            Spacer(minLength: 20)
            Button {
                modele.ouvrirZmanim()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: VersionEcrit.ligne(ecran.zmanim.ligne, traducteur))
                        .tailleSp(13, relativeA: VersionPolice.style(13))
                        .foregroundStyle(Color.white)
                        .monospacedDigit()
                        .lignesAuPlus(2)
                    if !ecran.zmanim.reperes.isEmpty {
                        Text(verbatim: ecran.zmanim.reperes.map { traducteur.texte($0.nom) + " " + $0.heure }
                            .joined(separator: "   "))
                            .tailleSp(12, poids: .medium, relativeA: VersionPolice.style(12))
                            // Blanc, un point plus grand et un peu plus gras que le blanc à 70 % en 11 d'Android :
                            // l'audit d'accessibilité mesurait ce petit texte clair, tout en finesse, sous 4,5:1.
                            .foregroundStyle(Color.white)
                            .monospacedDigit()
                            .lignesAuPlus(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                // Le même voile sous les zmanim, quand le texte agrandi les fait monter sur le ciel.
                .background(alignment: .bottom) { InstantCarteCiel.voile(haut: false) }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: ecran.zmanim.accessibilite.map { VersionEcrit.chaine($0, traducteur) }
                .joined(separator: ", ")))
            .accessibilityAddTraits(.isButton)
        }
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
        .clipped()
        .background {
            ZStack {
                // Le ciel continu suit le vrai soleil : revu chaque minute (AccueilVersion.veilleCiel).
                TimelineView(.everyMinute) { _ in
                    SereniteCiel(ciel: modele.etatCiel, nuages: false, arc: false)
                }
                LinearGradient(colors: [VersionCouleur.argb(0x8C000000), VersionCouleur.argb(0x10000000),
                                        VersionCouleur.argb(0x99000000)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    /// Un voile noir à 40 % sous un bloc de texte, qui s'efface sur 32 points au-delà de lui (vers le milieu de la
    /// carte), par-dessus celui de toute la carte.
    static func voile(haut: Bool) -> some View {
        LinearGradient(stops: [Gradient.Stop(color: Color.black.opacity(0.4), location: 0),
                               Gradient.Stop(color: Color.black.opacity(0.4), location: 0.7),
                               Gradient.Stop(color: Color.black.opacity(0), location: 1)],
                       startPoint: haut ? .top : .bottom, endPoint: haut ? .bottom : .top)
            .padding(haut ? .bottom : .top, -32)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Les dessins

/// La jauge en demi-cercle de l'image : 37 graduations, les faites en orangé. Elle se remplit en 900 ms à l'arrivée
/// (sauf « Réduire les animations »).
private struct InstantJauge: View {
    let fraction: Double
    @Environment(\.accessibilityReduceMotion) private var reduire
    @State private var part: Double = 0

    var body: some View {
        InstantGraduations(fraction: fraction, part: reduire ? 1 : part)
            .environment(\.layoutDirection, .leftToRight)
            .onAppear {
                guard !reduire else { return }
                withAnimation(.easeInOut(duration: Double(AccueilVersionModele.dureeJauge) / 1000)) { part = 1 }
            }
    }
}

/// Les graduations de la jauge, à une part de leur remplissage (`part` s'anime de 0 à 1) : les faites (orangé)
/// par-dessus toutes les autres (gris).
private struct InstantGraduations: View {
    let fraction: Double
    let part: Double

    var body: some View {
        let trait = StrokeStyle(lineWidth: 3, lineCap: .round)
        ZStack {
            InstantTraits(fraction: fraction, part: part, faites: false)
                .stroke(Instant.graduation, style: trait)
            InstantTraits(fraction: fraction, part: part, faites: true)
                .stroke(Instant.orange, style: trait)
        }
    }
}

/// Les 37 traits de la jauge en demi-cercle : ceux qui sont faits à cette part du remplissage, ou les autres.
private struct InstantTraits: Shape {
    var fraction: Double
    var part: Double
    let faites: Bool

    nonisolated var animatableData: Double {
        get { part }
        set { part = newValue }
    }

    nonisolated func path(in r: CGRect) -> Path {
        var traits = Path()
        let n = 36
        let cx = Double(r.midX)
        let cy = Double(r.maxY) - 4
        let r1 = min(Double(r.width) / 2, Double(r.height)) - 6
        let r2 = r1 - 14
        for i in 0...n {
            let faite = fraction > 0 && Double(i) / Double(n) <= fraction * part
            guard faite == faites else { continue }
            let a = Double.pi * (1 - Double(i) / Double(n))
            traits.move(to: CGPoint(x: cx + r2 * cos(a), y: cy - r2 * sin(a)))
            traits.addLine(to: CGPoint(x: cx + r1 * cos(a), y: cy - r1 * sin(a)))
        }
        return traits
    }
}

/// Les minutes des sept derniers jours, du plus ancien au plus récent de la gauche à la droite comme sur Android ;
/// aujourd'hui en vert olive, les jours faits en gris clair, les autres à peine ; la moyenne en pointillé. Les barres
/// poussent en 700 ms à l'arrivée (sauf « Réduire les animations »).
private struct InstantBarres: View {
    let minutes: InstantMinutes
    let initiales: [String]
    @Environment(\.accessibilityReduceMotion) private var reduire
    @State private var pousse: Double = 0

    var body: some View {
        GeometryReader { geo in
            let bas = Double(max(geo.size.height - 18, 0))
            let largeur = Double(geo.size.width)
            let echelle = Double(minutes.echelle)
            ZStack(alignment: .topLeading) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(minutes.minutes.enumerated()), id: \.offset) { i, m in
                        VStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(couleur(i, m))
                                .frame(height: CGFloat(max(4, bas * Double(m) / echelle) * (reduire ? 1 : pousse)))
                                .frame(height: CGFloat(bas), alignment: .bottom)
                            Text(verbatim: i < initiales.count ? initiales[i] : "")
                                .font(.system(size: 11))
                                .foregroundStyle(Instant.doux)
                                .lineLimit(1)
                                .frame(height: 18)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                if minutes.moyenne > 0 {
                    Path { ligne in
                        let y = bas - bas * Double(minutes.moyenne) / echelle
                        ligne.move(to: CGPoint(x: 0.0, y: y))
                        ligne.addLine(to: CGPoint(x: largeur, y: y))
                    }
                    .stroke(VersionCouleur.argb(0x99FFFFFF), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .onAppear {
            guard !reduire else { return }
            withAnimation(.easeInOut(duration: Double(AccueilVersionModele.dureeBarres) / 1000)) { pousse = 1 }
        }
    }

    private func couleur(_ i: Int, _ m: Int) -> Color {
        if i == minutes.minutes.count - 1 { return Instant.olive }
        return m > 0 ? Instant.barre : Instant.graduation
    }
}
