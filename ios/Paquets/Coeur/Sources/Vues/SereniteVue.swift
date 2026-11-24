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
    @Environment(\.dynamicTypeSize) private var tailleTexte

    var body: some View {
        let e = modele.serenite
        let k = SerenitePalette(nuit: e.nuit)
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    entete(e, k)
                    SereniteCartePaysage(modele: modele, ecran: e)
                        .padding(.top, 18)
                    // Sur l'iPad, deux colonnes (DeuxColonnes) sous le paysage : le hizouk et le zman, les derniers
                    // jours à côté.
                    DeuxColonnes(espacement: 14) {
                        carteHizouk(e, k)
                        carteZman(e, k)
                    } seconde: {
                        semaine(e, k)
                    }
                    .padding(.top, 18)
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
                        .tailleSp(16, poids: .bold, relativeA: VersionPolice.style(16))
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
                .tailleSp(14, relativeA: VersionPolice.style(14))
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
                .tailleSp(13, poids: .bold, relativeA: VersionPolice.style(13))
                .textCase(.uppercase)
                .tracking(1.3)
                .foregroundStyle(k.texte2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            Button(action: ouvrir) {
                Text(action, traducteur: traducteur)
                    .tailleSp(14, poids: .bold, relativeA: VersionPolice.style(14))
                    .foregroundStyle(k.accent)
                    .frame(minHeight: 44)
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
                    // Un extrait coupé aux mots (environ trois lignes), pas un texte tronqué.
                    Text(verbatim: VersionHebreu.extrait(traduction, mots: 20))
                        .font(VersionPolice.bellefair(17))
                        .foregroundStyle(k.texte)
                        .lineSpacing(3)
                        .padding(.top, 8)
                }
                Text(verbatim: p.reference)
                    .tailleSp(13, relativeA: VersionPolice.style(13))
                    .foregroundStyle(k.texte2)
                    .padding(.top, 8)
            } else {
                Text(Libelle("version_chargement"), traducteur: traducteur)
                    .tailleSp(15, relativeA: VersionPolice.style(15))
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
                    .tailleSp(15, relativeA: VersionPolice.style(15))
                    .monospacedDigit()
                    .foregroundStyle(k.texte2)
                    .padding(.top, 2)
            } else {
                Text(Libelle("version_sans_lieu"), traducteur: traducteur)
                    .tailleSp(15, relativeA: VersionPolice.style(15))
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
                    .tailleSp(15, relativeA: VersionPolice.style(15))
                    .foregroundStyle(k.texte2)
                    .padding(.top, 6)
            }
            ForEach(Array(e.jours.enumerated()), id: \.element.id) { rang, jour in
                VStack(alignment: .leading, spacing: 2) {
                    RangeeAdaptable {
                        Text(verbatim: VersionEcrit.chaine(jour.jour, traducteur))
                            .tailleSp(15, relativeA: VersionPolice.style(15))
                            .foregroundStyle(k.texte)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(jour.duree, traducteur: traducteur)
                            .tailleSp(15, relativeA: VersionPolice.style(15))
                            .foregroundStyle(k.texte2)
                    }
                    if let note = jour.note {
                        Text(verbatim: note)
                            .tailleSp(14, relativeA: VersionPolice.style(14))
                            .foregroundStyle(k.texte2)
                            .lignesAuPlus(1)
                    }
                }
                .accessibilityElement(children: .combine)
                .padding(.top, rang == 0 ? 6 : 12)
            }
            VersionBouton(libelle: Text(Libelle("version_ecrire_note"), traducteur: traducteur), fond: k.accent,
                          encre: k.accent, police: .subheadline, trait: true) {
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
                            .font(.title3)
                            .frame(minWidth: 24, minHeight: 24)
                            .accessibilityHidden(true)
                        // Aux tailles d'accessibilité, l'onglet ne montre que son image, et son nom en grand sous
                        // un appui long (comme la barre d'onglets d'iOS).
                        if !tailleTexte.isAccessibilitySize {
                            Text(onglet.titre, traducteur: traducteur)
                                .tailleSp(12, poids: onglet.actif ? .bold : .regular, relativeA: VersionPolice.style(12))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .foregroundStyle(onglet.actif ? k.accent : k.texte2)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(onglet.titre, traducteur: traducteur))
                .accessibilityAddTraits(onglet.actif ? .isSelected : [])
                .accessibilityShowsLargeContentViewer {
                    Label {
                        Text(onglet.titre, traducteur: traducteur)
                    } icon: {
                        Image(systemName: SereniteVue.symbole(onglet))
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(k.fond.ignoresSafeArea(edges: .bottom))
        .accessibilityIdentifier("barre-bas")
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
    /// La hauteur du bloc de texte, qui grandit avec Dynamic Type : elle décide du voile et de la silhouette.
    @State private var hauteurTexte: CGFloat = 0

    /// Du bas de la carte au haut du texte (le texte, sa marge du bas).
    private var basTexte: CGFloat { hauteurTexte + 22 }

    /// Les pieds de la silhouette, à 112 pt du bas : sur la colline.
    private static let piedsSilhouette: CGFloat = 112

    /// La silhouette tient au-dessus du texte à la taille de la maquette ; quand le texte grandit jusqu'à elle, elle
    /// s'efface plutôt que de passer sous le titre (elle est décorative, la colline ne monte pas avec le texte).
    private var silhouetteVisible: Bool { basTexte <= SereniteCartePaysage.piedsSilhouette + 4 }

    /// Le voile du bas : 190 pt à la taille de la maquette ; plus haut quand le texte grandit, pour que l'étiquette du
    /// haut reste sur du sombre et pas sur le ciel clair du jour, sans jamais agrandir la carte à lui seul.
    private var hauteurVoile: CGFloat {
        min(max(190, basTexte + 91), max(380, basTexte))
    }

    /// Le fondu du voile, du transparent au sombre : 190 pt quand le voile garde sa hauteur ; quand il monte, assez
    /// court pour que le haut du texte soit au moins aussi sombre qu'à la taille de la maquette.
    private var fonduVoile: CGFloat {
        let voile = hauteurVoile
        return voile <= 190 ? voile : min(190, 2 * (voile - basTexte))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                modele.commencerSeance()
            } label: {
                ZStack(alignment: .bottomLeading) {
                    // Le ciel continu suit le vrai soleil : revu chaque minute (AccueilVersion.veilleCiel).
                    TimelineView(.everyMinute) { _ in
                        SereniteCiel(ciel: modele.etatCiel)
                    }
                    // La silhouette du hassid, posée sur la colline.
                    if silhouetteVisible {
                        Illustration(decorative: "char_debout")
                            .colorMultiply(.black)
                            .opacity(0.88)
                            .frame(width: 56, height: 84, alignment: .bottom)
                            .padding(.trailing, 96)
                            .padding(.bottom, SereniteCartePaysage.piedsSilhouette)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    }
                    // Le voile du bas, sous le texte.
                    LinearGradient(stops: [
                        Gradient.Stop(color: .clear, location: 0),
                        Gradient.Stop(color: VersionCouleur.argb(0xE614111F), location: fonduVoile / hauteurVoile),
                    ], startPoint: .top, endPoint: .bottom)
                        .frame(height: hauteurVoile)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    texte
                        .onGeometryChange(for: CGFloat.self) { geometrie in
                            geometrie.size.height
                        } action: { hauteur in
                            hauteurTexte = hauteur
                        }
                        .padding(.leading, 20)
                        .padding(.trailing, 92)
                        .padding(.bottom, 22)
                    // Le bouton rond : commencer, ou revenir à la hitbodedout en cours.
                    Image(systemName: "play.fill")
                        .font(.title3)
                        .foregroundStyle(SerenitePalette.violet)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(SerenitePalette.peche))
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .accessibilityHidden(true)
                }
                // 380 de haut ; plus haute si le texte grandit (Dynamic Type), pour ne pas le couper.
                .frame(minHeight: 380)
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
                    .tailleSp(14, poids: .bold, relativeA: VersionPolice.style(14))
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
                .tailleSp(12, poids: .bold, relativeA: VersionPolice.style(12))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(SerenitePalette.pecheClair)
            Text(ecran.titreCarte, traducteur: traducteur)
                .font(VersionPolice.bellefair(30))
                .foregroundStyle(Color.white)
                .padding(.top, 4)
            Text(verbatim: VersionEcrit.ligne(ecran.reglage, traducteur))
                .tailleSp(14, relativeA: VersionPolice.style(14))
                .foregroundStyle(VersionCouleur.argb(0xFFD9D0E6))
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Le paysage de la carte (PaysageCiel.kt, avec son nuage et son arc) : le ciel du moment en dégradé, l'astre dans
/// son halo, les étoiles la nuit, deux collines et une brume. Peint, pas une image : il suit la taille de la carte et
/// le ciel continu (24/11, `PaysageCiel`) — ses couleurs passent sans à-coup entre les quatre ciels peints d'avant
/// selon la hauteur du vrai soleil, le soleil puis la lune traversent le haut du ciel de la gauche à la droite (la
/// lune avec sa phase du mois hébreu), les étoiles s'allument avec le crépuscule.
///
/// Animé (`CielVivantHorloge`) : les étoiles scintillent et dérivent d'un rien, le halo respire, un nuage qui prend
/// la lumière du moment passe dans le haut du ciel, loin du texte. Immobile (« Réduire les animations », Économie
/// d'énergie, écran quitté) : la peinture d'avant ces animations, sans nuage. Il ne se retourne pas en hébreu, comme
/// le dessin d'Android ; décoratif, VoiceOver ne le voit pas.
struct SereniteCiel: View {
    let ciel: EtatCiel

    var body: some View {
        let paysage = PaysageCiel(etat: ciel, nuages: true, arc: true)
        CielVivantHorloge { secondes in
            Canvas { c, taille in
                peindre(c, taille, paysage, secondes)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
    }

    private func couleur(_ argb: UInt32, _ opacite: Double = 1) -> Color {
        CielCouleur.couleur(argb, opacite: opacite)
    }

    /// Le paysage, immobile (`secondes` nil) ou à un instant de son animation.
    private func peindre(_ c: GraphicsContext, _ taille: CGSize, _ p: PaysageCiel, _ secondes: Double?) {
        let w = taille.width
        let h = taille.height
        let marche = secondes != nil
        let s = secondes ?? 0
        c.fill(Path(CGRect(origin: .zero, size: taille)), with: .linearGradient(
            Gradient(colors: p.couleurs.map { couleur($0) }), startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.85)))
        // Les étoiles : toutes la nuit, s'allumant avec le crépuscule ; animées, chacune scintille à son rythme et le
        // champ dérive d'un rien.
        let lueur = p.eclatEtoiles
        if lueur > 0 {
            let dx = marche ? Double(CielVivant.deriveX(s)) : 0
            let dy = marche ? Double(CielVivant.deriveY(s)) : 0
            for (i, etoile) in PaysageCiel.etoiles.enumerated() {
                let r = Double(etoile.taille) * 0.8
                let x = Double(etoile.x) * w + dx
                let y = Double(etoile.y) * h + dy
                let vif = marche
                    ? Double(CielVivant.scintillement(s, periode: Double(PaysageCiel.rythmes[i * CielVivant.champs + 3]),
                                                      phase: Double(PaysageCiel.rythmes[i * CielVivant.champs + 4])))
                    : 1
                c.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                       with: .color(couleur(PaysageCiel.etoile, min(lueur * vif, 1))))
            }
        }
        // L'astre dans son halo, qui paraît et s'efface à l'horizon ; animé, le halo respire.
        let (cx, cy, rayon) = p.astrePlace(largeur: w, hauteur: h)
        let visible = p.astreVisible
        if visible > 0 {
            let k = marche ? Double(CielVivant.tailleHalo(s)) : 1
            var halo = c
            halo.opacity = min(max((marche ? Double(CielVivant.eclatHalo(s)) : 1) * visible, 0), 1)
            let grand = rayon * PaysageCiel.halo * k
            halo.fill(Path(ellipseIn: CGRect(x: cx - grand, y: cy - grand, width: 2 * grand, height: 2 * grand)),
                      with: .radialGradient(Gradient(stops: PaysageCiel.haloArrets.map {
                          Gradient.Stop(color: couleur($0.couleur), location: $0.position)
                      }), center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: grand))
            var astre = c
            astre.opacity = min(visible, 1)
            if p.estSoleil {
                astre.fill(Path(ellipseIn: CGRect(x: cx - rayon, y: cy - rayon, width: 2 * rayon, height: 2 * rayon)),
                           with: .color(couleur(p.astreCouleur)))
            } else {
                CielDessin.lune(astre, cx, cy, rayon, couleur: couleur(PaysageCiel.lune),
                                CielContinu.lune(p.etat.jourHebreu))
            }
        }
        // Le nuage, animé seulement : il prend la lumière du moment et passe dans le haut du ciel, loin du texte.
        if marche && p.avecNuage {
            let lw = PlanCiel.tailles[0].largeur
            let lh = PlanCiel.tailles[0].hauteur
            let x = CielVivant.nuageX(depart: 0.18 * w, vitesse: Double(CielVivant.nuageDpS), secondes: s,
                                      largeurCiel: w, largeurNuage: lw)
            let y = h * 0.24
            CielDessin.nuage(c, forme: 0, CGRect(x: x, y: y + PlanCiel.bordNuage, width: lw, height: lh),
                             couleur: couleur(p.nuageBord), opacite: 110.0 / 255 * p.presenceNuage)
            CielDessin.nuage(c, forme: 0, CGRect(x: x, y: y, width: lw, height: lh),
                             couleur: couleur(p.nuageCorps), opacite: 90.0 / 255 * p.presenceNuage)
        }
        // Deux collines : la plus lointaine plus claire, et la brume entre elles, du jour à la nuit.
        var loin = Path()
        loin.move(to: CGPoint(x: 0, y: h * 0.7))
        loin.addCurve(to: CGPoint(x: w * 0.62, y: h * 0.62), control1: CGPoint(x: w * 0.25, y: h * 0.6),
                      control2: CGPoint(x: w * 0.45, y: h * 0.66))
        loin.addCurve(to: CGPoint(x: w, y: h * 0.63), control1: CGPoint(x: w * 0.8, y: h * 0.58),
                      control2: CGPoint(x: w * 0.92, y: h * 0.64))
        loin.addLine(to: CGPoint(x: w, y: h))
        loin.addLine(to: CGPoint(x: 0, y: h))
        loin.closeSubpath()
        c.fill(loin, with: .color(couleur(p.collineLoin)))
        let brume = CGRect(x: -w * 0.2, y: h * 0.7, width: w * 1.4, height: h * 0.14)
        c.fill(Path(ellipseIn: brume), with: .radialGradient(
            Gradient(colors: [couleur(p.brume), couleur(0x00FF_FFFF)]),
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
        c.fill(pres, with: .color(couleur(p.collinePres)))
    }
}
