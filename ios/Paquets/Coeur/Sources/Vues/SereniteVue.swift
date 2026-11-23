import Foundation
import SwiftUI
import Coeur
import Ecrans

/// L'accueil Sérénité (SereniteActivity.kt, maquette « P2 · Sérénité pro ») : en tête, la salutation en Bellefair et
/// le rond de l'initiale (les réglages) ; la grande carte-paysage qui suit le ciel du moment, la silhouette du hassid
/// sur la colline, l'état du jour, la durée, l'ambiance et le bouton rond (commencer, ou revenir à la séance), et
/// « Modifier » ; puis le 'hizouk, le prochain zman et les derniers jours. Quatre onglets en bas : Aujourd'hui,
/// Zmanim, Textes, Journal. La vue lit `AccueilVersionModele.serenite`.
struct SereniteVue: View {
    let modele: AccueilVersionModele
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        let e = modele.serenite
        let k = SerenitePalette(nuit: e.nuit)
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    entete(e, k)
                    SereniteCartePaysage(modele: modele, ecran: e)
                        .padding(.top, 18)
                    carteHizouk(e, k)
                        .padding(.top, 18)
                    carteZman(e, k)
                        .padding(.top, 14)
                    semaine(e, k)
                        .padding(.top, 14)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            onglets(k)
        }
        .background(k.fond.ignoresSafeArea())
    }

    // MARK: En-tête

    private func entete(_ e: SereniteEcran, _ k: SerenitePalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 12) {
                Text(e.titre, traducteur: traducteur)
                    .font(VersionPolice.bellefair(32))
                    .foregroundStyle(k.texte)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                // L'initiale du prénom ouvre le profil, c'est-à-dire les réglages.
                Button {
                    modele.ouvrirReglages()
                } label: {
                    Text(verbatim: e.initiale ?? "⚙")
                        .font(VersionPolice.systeme(16, .bold))
                        .foregroundStyle(k.texte)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(k.bouton))
                        .overlay(Circle().strokeBorder(k.boutonBord, lineWidth: 1))
                        .contentShape(Circle())
                }
                .buttonStyle(VersionPression())
                .accessibilityLabel(Text(Libelle("version_reglages"), traducteur: traducteur))
            }
            Text(verbatim: VersionEcrit.ligne(e.ligne, traducteur))
                .font(VersionPolice.systeme(14))
                .foregroundStyle(k.texte2)
        }
    }

    // MARK: Les cartes du dessous

    private func carte<Contenu: View>(_ k: SerenitePalette, @ViewBuilder contenu: () -> Contenu) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            contenu()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(k.carte, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(k.ligne, lineWidth: 1))
    }

    /// Le titre d'une carte, en petites capitales, et son lien (« Lire », « Tout voir »).
    private func titreSection(_ titre: Libelle, _ action: Libelle, _ k: SerenitePalette,
                              ouvrir: @escaping @MainActor () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(titre, traducteur: traducteur)
                .font(VersionPolice.systeme(13, .bold))
                .textCase(.uppercase)
                .tracking(1.3)
                .foregroundStyle(k.texte2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            Button(action: ouvrir) {
                Text(action, traducteur: traducteur)
                    .font(VersionPolice.systeme(14, .bold))
                    .foregroundStyle(k.accent)
                    .frame(minHeight: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func carteHizouk(_ e: SereniteEcran, _ k: SerenitePalette) -> some View {
        carte(k) {
            titreSection(Libelle("pile_hizouk"), Libelle("serenite_lire"), k) { modele.ouvrirChizuk() }
            if let p = e.pensee {
                VersionHebreu(texte: p.hebreu, taille: 20, couleur: k.texte, police: modele.police, lignes: 3)
                    .padding(.top, 6)
                if let traduction = p.traduction {
                    Text(verbatim: traduction)
                        .font(VersionPolice.bellefair(17))
                        .foregroundStyle(k.texte)
                        .lineSpacing(3)
                        .lineLimit(3)
                        .padding(.top, 8)
                }
                Text(verbatim: p.reference)
                    .font(VersionPolice.systeme(13))
                    .foregroundStyle(k.texte2)
                    .padding(.top, 8)
            } else {
                Text(Libelle("version_chargement"), traducteur: traducteur)
                    .font(VersionPolice.systeme(15))
                    .foregroundStyle(k.texte2)
                    .padding(.top, 6)
            }
        }
    }

    private func carteZman(_ e: SereniteEcran, _ k: SerenitePalette) -> some View {
        carte(k) {
            titreSection(e.titreZmanim, Libelle("serenite_tout_voir"), k) { modele.ouvrirZmanim() }
            if let z = e.prochain {
                Text(z.nom, traducteur: traducteur)
                    .font(VersionPolice.bellefair(24))
                    .foregroundStyle(k.texte)
                    .padding(.top, 4)
                Text(verbatim: z.heure + " · " + traducteur.texte(z.dans))
                    .font(VersionPolice.systeme(15))
                    .monospacedDigit()
                    .foregroundStyle(k.texte2)
                    .padding(.top, 2)
            } else {
                Text(Libelle("version_sans_lieu"), traducteur: traducteur)
                    .font(VersionPolice.systeme(15))
                    .foregroundStyle(k.texte2)
                    .padding(.top, 6)
            }
        }
    }

    private func semaine(_ e: SereniteEcran, _ k: SerenitePalette) -> some View {
        carte(k) {
            titreSection(Libelle("serenite_cette_semaine"), Libelle("serenite_tout_voir"), k) { modele.ouvrirJournal() }
            if e.jours.isEmpty {
                Text(Libelle("version_journal_vide"), traducteur: traducteur)
                    .font(VersionPolice.systeme(15))
                    .foregroundStyle(k.texte2)
                    .padding(.top, 6)
            }
            ForEach(Array(e.jours.enumerated()), id: \.element.id) { rang, jour in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(verbatim: VersionEcrit.chaine(jour.jour, traducteur))
                            .font(VersionPolice.systeme(15))
                            .foregroundStyle(k.texte)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(jour.duree, traducteur: traducteur)
                            .font(VersionPolice.systeme(15))
                            .foregroundStyle(k.texte2)
                    }
                    if let note = jour.note {
                        Text(verbatim: note)
                            .font(VersionPolice.systeme(14))
                            .foregroundStyle(k.texte2)
                            .lineLimit(1)
                    }
                }
                .accessibilityElement(children: .combine)
                .padding(.top, rang == 0 ? 6 : 12)
            }
            VersionBouton(libelle: Text(Libelle("version_ecrire_note"), traducteur: traducteur), fond: k.accent,
                          encre: k.accent, police: VersionPolice.systeme(15), trait: true) {
                modele.ecrireNote()
            }
            .padding(.top, 16)
        }
    }

    // MARK: Les onglets

    private func onglets(_ k: SerenitePalette) -> some View {
        HStack(spacing: 0) {
            ForEach(SereniteOnglet.allCases) { onglet in
                Button {
                    modele.toucherOnglet(onglet)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: SereniteVue.symbole(onglet))
                            .font(.system(size: 20))
                            .frame(width: 24, height: 24)
                            .accessibilityHidden(true)
                        Text(onglet.titre, traducteur: traducteur)
                            .font(VersionPolice.systeme(12, onglet.actif ? .bold : .regular))
                    }
                    .foregroundStyle(onglet.actif ? k.accent : k.texte2)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(onglet.actif ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(k.fond.ignoresSafeArea(edges: .bottom))
    }

    /// ic_nav_today, ic_ciel, ic_nav_texts, ic_marque_etude.
    private static func symbole(_ onglet: SereniteOnglet) -> String {
        switch onglet {
        case .aujourdhui: Onglet.aujourdhui.symbole
        case .zmanim: CielDuJour.symbole(.nuit)
        case .textes: Onglet.textes.symbole
        case .journal: "bookmark"
        }
    }
}

/// Les deux palettes de la maquette : la nuit (et le soir), le jour (et l'aube).
struct SerenitePalette {
    let fond: Color
    let texte: Color
    let texte2: Color
    let carte: Color
    let ligne: Color
    let bouton: Color
    let boutonBord: Color
    let accent: Color

    init(nuit: Bool) {
        let c = VersionCouleur.argb
        if nuit {
            fond = c(0xFF14111F); texte = c(0xFFF4EEF8); texte2 = c(0xFFB3A9C4); carte = c(0xFF1F1A2E)
            ligne = c(0xFF2C2545); bouton = c(0xFF1F1A2E); boutonBord = c(0xFF2E2742); accent = c(0xFFF2C6A0)
        } else {
            fond = c(0xFFF7F2EA); texte = c(0xFF231C33); texte2 = c(0xFF5F566E); carte = c(0xFFFFFFFF)
            ligne = c(0xFFEEE6F3); bouton = c(0xFFFFFFFF); boutonBord = c(0xFFDCD2C6); accent = c(0xFF5B3FA0)
        }
    }

    static let peche = VersionCouleur.argb(0xFFF2C6A0)
    static let pecheClair = VersionCouleur.argb(0xFFF7CDA8)
    static let violet = VersionCouleur.argb(0xFF2E2366)
}

// MARK: - La carte-paysage

/// La grande carte (380 pt, coins de 32) : le paysage du ciel du moment, la silhouette du hassid, le voile du bas
/// sous le texte, le bouton rond ; « Modifier » en haut, du côté de la fin de ligne. Toucher la carte commence la
/// séance (ou y revient) ; « Modifier » ouvre la préparation.
private struct SereniteCartePaysage: View {
    let modele: AccueilVersionModele
    let ecran: SereniteEcran
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                modele.commencerSeance()
            } label: {
                ZStack(alignment: .bottomLeading) {
                    SereniteCiel(phase: ecran.phase)
                    // La silhouette du hassid, posée sur la colline.
                    Illustration(decorative: "char_debout")
                        .colorMultiply(.black)
                        .opacity(0.88)
                        .frame(width: 56, height: 84, alignment: .bottom)
                        .padding(.trailing, 96)
                        .padding(.bottom, 112)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    // Le voile du bas, sous le texte.
                    LinearGradient(colors: [.clear, VersionCouleur.argb(0xE614111F)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 190)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    texte
                        .padding(.leading, 20)
                        .padding(.trailing, 92)
                        .padding(.bottom, 22)
                    // Le bouton rond : commencer, ou revenir à la hitbodedout en cours.
                    Text(verbatim: "▶")
                        .font(.system(size: 20))
                        .foregroundStyle(SerenitePalette.violet)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(SerenitePalette.peche))
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .accessibilityHidden(true)
                }
                .frame(height: 380)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            }
            .buttonStyle(VersionPression(echelle: 0.98))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(ecran.accessibiliteCarte, traducteur: traducteur))
            .accessibilityAddTraits(.isButton)
            // « Modifier » : durée, sujet, musique.
            Button {
                modele.preparerSeance()
            } label: {
                Text(Libelle("serenite_modifier"), traducteur: traducteur)
                    .font(VersionPolice.systeme(14, .bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(Color.white.opacity(Double(0x40) / 255)))
                    .contentShape(Capsule())
            }
            .buttonStyle(VersionPression())
            .padding(.top, 14)
            .padding(.trailing, 14)
            .accessibilityLabel(Text(Libelle("version_preparer"), traducteur: traducteur))
        }
    }

    private var texte: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(ecran.etiquette, traducteur: traducteur)
                .font(VersionPolice.systeme(12, .bold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(SerenitePalette.pecheClair)
            Text(ecran.titreCarte, traducteur: traducteur)
                .font(VersionPolice.bellefair(30))
                .foregroundStyle(Color.white)
                .padding(.top, 4)
            Text(verbatim: VersionEcrit.ligne(ecran.reglage, traducteur))
                .font(VersionPolice.systeme(14))
                .foregroundStyle(VersionCouleur.argb(0xFFD9D0E6))
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Le paysage de la carte (SereniteActivity.Paysage) : le ciel du moment en dégradé, l'astre dans son halo, les
/// étoiles la nuit, deux collines et une brume. Peint, pas une image : il suit la taille de la carte et la phase du
/// ciel. Il ne se retourne pas en hébreu, comme le dessin d'Android.
struct SereniteCiel: View {
    let phase: CielDuJour.Phase

    /// Quarante étoiles tirées une fois, toujours les mêmes (java.util.Random(29) d'Android en tient lieu) : x, y
    /// (sur le haut du ciel), taille.
    private static let etoiles: [(Double, Double, Double)] = {
        var graine: UInt64 = 29
        func suivant() -> Double {
            graine = graine &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(graine >> 11) / Double(UInt64(1) << 53)
        }
        return (0..<40).map { _ in (suivant(), suivant() * 0.55, 1 + suivant() * 1.6) }
    }()

    var body: some View {
        Canvas { c, taille in
            peindre(c, taille)
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
    }

    private var couleurs: [Color] {
        let c = VersionCouleur.argb
        switch phase {
        case .nuit: return [c(0xFF0B0A1F), c(0xFF1D1838), c(0xFF2E2366), c(0xFF4E3486)]
        case .coucher: return [c(0xFF0E0B1D), c(0xFF241C52), c(0xFF4E3486), c(0xFF9A5C97), c(0xFFE3957A), c(0xFFF7CDA8)]
        case .aube: return [c(0xFF2A2357), c(0xFF6A4C9C), c(0xFFC98AA0), c(0xFFF2C6A0), c(0xFFFBE3C8)]
        case .jour: return [c(0xFF4F86C6), c(0xFF7FAEDC), c(0xFFB3D2EA), c(0xFFDCE9EC), c(0xFFF4E6CB)]
        }
    }

    private func peindre(_ c: GraphicsContext, _ taille: CGSize) {
        let w = taille.width
        let h = taille.height
        let toile = CGRect(origin: .zero, size: taille)
        c.fill(Path(toile), with: .linearGradient(Gradient(colors: couleurs), startPoint: .zero,
                                                   endPoint: CGPoint(x: 0, y: h * 0.85)))
        let nuit = phase == .nuit || phase == .coucher
        if nuit {
            let visibles = phase == .nuit ? SereniteCiel.etoiles : Array(SereniteCiel.etoiles.prefix(18))
            for (x, y, t) in visibles {
                let r = t * 0.8
                c.fill(Path(ellipseIn: CGRect(x: x * w - r, y: y * h - r, width: r * 2, height: r * 2)),
                       with: .color(VersionCouleur.argb(0xFFFFF6EC)))
            }
        }
        // L'astre : la lune haut dans la nuit, le soleil bas au couchant et à l'aube, haut le jour.
        let (cx, cy, rayon, couleur): (CGFloat, CGFloat, CGFloat, UInt32) = {
            switch phase {
            case .nuit: return (w * 0.72, h * 0.2, 22, 0xFFF3EBD2)
            case .coucher: return (w * 0.4, h * 0.62, 34, 0xFFFFE6CC)
            case .aube: return (w * 0.6, h * 0.6, 30, 0xFFFFF1DC)
            case .jour: return (w * 0.3, h * 0.24, 30, 0xFFFFF8E6)
            }
        }()
        let halo = rayon * 3.6
        c.fill(Path(ellipseIn: CGRect(x: cx - halo, y: cy - halo, width: halo * 2, height: halo * 2)),
               with: .radialGradient(Gradient(stops: [
                   Gradient.Stop(color: VersionCouleur.argb(0xB0FFD6AA), location: 0),
                   Gradient.Stop(color: VersionCouleur.argb(0x47FFBE96), location: 0.32),
                   Gradient.Stop(color: VersionCouleur.argb(0x00FFBE96), location: 0.64),
               ]), center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: halo))
        c.fill(Path(ellipseIn: CGRect(x: cx - rayon, y: cy - rayon, width: rayon * 2, height: rayon * 2)),
               with: .color(VersionCouleur.argb(couleur)))
        // Deux collines : la plus lointaine plus claire, et la brume entre elles.
        var loin = Path()
        loin.move(to: CGPoint(x: 0, y: h * 0.7))
        loin.addCurve(to: CGPoint(x: w * 0.62, y: h * 0.62), control1: CGPoint(x: w * 0.25, y: h * 0.6),
                      control2: CGPoint(x: w * 0.45, y: h * 0.66))
        loin.addCurve(to: CGPoint(x: w, y: h * 0.63), control1: CGPoint(x: w * 0.8, y: h * 0.58),
                      control2: CGPoint(x: w * 0.92, y: h * 0.64))
        loin.addLine(to: CGPoint(x: w, y: h))
        loin.addLine(to: CGPoint(x: 0, y: h))
        loin.closeSubpath()
        c.fill(loin, with: .color(VersionCouleur.argb(nuit ? 0xFF2A2350 : 0xFF8FA9C4)))
        let brume = CGRect(x: -w * 0.2, y: h * 0.7, width: w * 1.4, height: h * 0.14)
        c.fill(Path(ellipseIn: brume), with: .radialGradient(
            Gradient(colors: [VersionCouleur.argb(nuit ? 0x80F7CDA8 : 0x99FFFFFF), VersionCouleur.argb(0x00FFFFFF)]),
            center: CGPoint(x: w / 2, y: h * 0.76), startRadius: 0, endRadius: w * 0.7))
        var pres = Path()
        pres.move(to: CGPoint(x: 0, y: h * 0.8))
        pres.addCurve(to: CGPoint(x: w * 0.75, y: h * 0.74), control1: CGPoint(x: w * 0.3, y: h * 0.72),
                      control2: CGPoint(x: w * 0.55, y: h * 0.78))
        pres.addCurve(to: CGPoint(x: w, y: h * 0.74), control1: CGPoint(x: w * 0.88, y: h * 0.72),
                      control2: CGPoint(x: w * 0.95, y: h * 0.75))
        pres.addLine(to: CGPoint(x: w, y: h))
        pres.addLine(to: CGPoint(x: 0, y: h))
        pres.closeSubpath()
        c.fill(pres, with: .color(VersionCouleur.argb(nuit ? 0xFF151026 : 0xFF4D6B5C)))
    }
}
