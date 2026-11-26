import Foundation
import SwiftUI
import Coeur
import Ecrans

/// L'accueil Pile (PileActivity.kt, maquette « C · Pile — l'app en cartes du jour ») : plus d'onglets, la journée se
/// lit comme une pile de quatre cartes qu'on fait glisser du doigt — hitbodedout, 'hizouk, zmanim, journal. Les
/// cartes voisines dépassent, un peu plus petites et plus sombres : on voit qu'il y a une pile. Le 'hizouk se
/// retourne pour la traduction. En tête, la date, « Votre journée », la position dans la pile ; Textes et
/// Réglages. Polices : Secular One pour les titres, Rubik pour le reste. La vue lit `AccueilVersionModele.pile`.
struct PileVue: View {
    let modele: AccueilVersionModele
    @Environment(\.traducteur) private var traducteur
    @Environment(\.dynamicTypeSize) private var tailleTexte
    /// La hauteur de l'écran de l'accueil : un petit écran (ou un texte agrandi qui le rend aussi serré) prend des
    /// titres plus petits et laisse le hassid (PileActivity.petit, 17/11).
    @State private var hauteur: CGFloat = 0

    private var petit: Bool { VersionEchelle.petit(hauteur: hauteur, tailleTexte) }

    var body: some View {
        let e = modele.pile
        VStack(alignment: .leading, spacing: 0) {
            // L'en-tête garde sa hauteur : c'est la pile qui cède la place quand le texte grandit.
            entete(e)
                .fixedSize(horizontal: false, vertical: true)
            Text(e.position, traducteur: traducteur)
                .font(VersionPolice.rubik(13, .semibold))
                .tracking(1)
                .foregroundStyle(Pile.encreDouce)
                .monospacedDigit()
                .padding(.top, 6)
                .padding(.horizontal, 24)
            cartes(e)
                .padding(.top, 12)
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Pile.fond.ignoresSafeArea())
        .onGeometryChange(for: CGFloat.self) { geometrie in
            geometrie.size.height
        } action: { valeur in
            hauteur = valeur
        }
    }

    // MARK: L'en-tête

    private func entete(_ e: PileEcran) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: VersionEcrit.ligne(e.ligneDate, traducteur))
                    .font(VersionPolice.rubik(14))
                    .foregroundStyle(Pile.encreDouce)
                Text(Libelle("pile_titre"), traducteur: traducteur)
                    .font(VersionPolice.secular(petit ? 24 : 30))
                    .foregroundStyle(Pile.encre)
                    .accessibilityAddTraits(.isHeader)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            icone(Onglet.textes.symbole, Libelle("version_textes")) { modele.ouvrirTextes() }
            icone("gearshape", Libelle("version_reglages")) { modele.ouvrirReglages() }
        }
        .padding(.leading, 24)
        .padding(.trailing, 8)
    }

    /// Une icône touchable de 48 pt, teintée, avec sa description pour VoiceOver (VueVersion.icone).
    private func icone(_ symbole: String, _ description: Libelle, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbole)
                .font(.title3)
                .foregroundStyle(Pile.encreDouce)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(description, traducteur: traducteur))
    }

    // MARK: La pile

    private func cartes(_ e: PileEcran) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(PileCarte.allCases) { carte in
                    Group {
                        switch carte {
                        case .hitbodedout: carteHitbodedout(e.hitbodedout)
                        case .hizouk: PileHizoukCarte(modele: modele, hizouk: e.hizouk)
                        case .zmanim: carteZmanim(e.zmanim)
                        case .journal: carteJournal(e.journal)
                        }
                    }
                    .padding(.horizontal, 4)
                    .containerRelativeFrame(.horizontal)
                    // La carte suivante attend derrière, un peu plus petite et plus sombre : assombrie, pas
                    // transparente (alpha 0,65 sur Android), pour que son texte reste lisible sur son fond
                    // (contraste relevé par l'audit d'accessibilité).
                    .scrollTransition(axis: .horizontal) { contenu, phase in
                        contenu
                            .scaleEffect(x: 1, y: 1 - 0.06 * min(abs(phase.value), 1), anchor: UnitPoint.center)
                            .brightness(-0.2 * min(abs(phase.value), 1))
                    }
                    .id(carte.rawValue)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.leading, 24, for: .scrollContent)
        .contentMargins(.trailing, 40, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: Bindable(modele).pageLiee)
    }

    /// Le corps d'une carte : un dégradé, arrondi, qui défile si le texte agrandi déborde ; le bas (les boutons) contre
    /// son bord.
    private func carte<Contenu: View>(_ haut: UInt32, _ bas: UInt32, @ViewBuilder contenu: () -> Contenu) -> some View {
        PileCorps(haut: haut, bas: bas, contenu: contenu())
    }

    private func etiquette(_ texte: Libelle, _ couleur: Color) -> some View {
        Text(texte, traducteur: traducteur)
            .font(VersionPolice.rubik(13, .semibold))
            .textCase(.uppercase)
            .tracking(1.5)
            .foregroundStyle(couleur)
    }

    private func carteHitbodedout(_ h: PileHitbodedout) -> some View {
        carte(0xFF136067, 0xFF0B3236) {
            etiquette(Libelle("pile_hitbodedout"), Pile.hitboAccent)
            // Plus petit sur un petit écran : en 28 le titre prenait trois lignes et poussait « Commencer » sous le bord
            // de la carte (480x854, 17/11).
            Text(h.titre, traducteur: traducteur)
                .font(VersionPolice.secular(petit ? 22 : 28))
                .foregroundStyle(Pile.hitboEncre)
                .padding(.top, 14)
            Text(h.serie, traducteur: traducteur)
                .font(VersionPolice.rubik(17, .semibold))
                .foregroundStyle(Pile.hitboEncre)
                .padding(.top, 22)
            Text(h.semaine, traducteur: traducteur)
                .font(VersionPolice.rubik(15))
                .foregroundStyle(Pile.hitboDouce)
                .padding(.top, 4)
            // Les jours de la semaine en pastilles : faits pleins, à venir creux.
            HStack(spacing: 8) {
                ForEach(Array(h.jours.enumerated()), id: \.offset) { _, fait in
                    Circle()
                        .fill(fait ? Pile.hitboAccent : Color.clear)
                        .overlay(Circle().strokeBorder(fait ? Color.clear : Pile.hitboDouce, lineWidth: 1))
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.top, 14)
            .accessibilityHidden(true)
            // Le hassid occupe le milieu de la carte : il accueille, ou se réjouit quand c'est fait. Borné en hauteur, et
            // absent sur un petit écran, où il poussait « Commencer » hors de vue (480x854, 17/11).
            if !petit {
                Illustration(decorative: h.image)
                    .frame(maxWidth: .infinity, minHeight: 90, maxHeight: 200)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 12)
            }
            VersionBouton(libelle: Text(h.bouton, traducteur: traducteur), fond: Pile.hitboAccent,
                          encre: Pile.hitboBoutonEncre, police: VersionPolice.rubik(16, .semibold)) {
                modele.commencerSeance()
            }
            .padding(.top, 24)
            VersionBouton(libelle: Text(Libelle("version_preparer"), traducteur: traducteur), fond: Pile.hitboDouce,
                          encre: Pile.hitboEncre, police: VersionPolice.rubik(16), trait: true) {
                modele.preparerSeance()
            }
            .padding(.top, 10)
        }
    }

    private func carteZmanim(_ z: PileZmanim) -> some View {
        carte(0xFF9E4A22, 0xFF3B1F14) {
            etiquette(z.etiquette, Pile.zmAccent)
            if z.zmanim.isEmpty {
                Text(Libelle("version_sans_lieu"), traducteur: traducteur)
                    .font(VersionPolice.rubik(16))
                    .foregroundStyle(Pile.zmEncre)
                    .padding(.top, 16)
                Spacer(minLength: 20)
                VersionBouton(libelle: Text(Libelle("version_choisir_lieu"), traducteur: traducteur), fond: Pile.zmAccent,
                              encre: Pile.zmBoutonEncre, police: VersionPolice.rubik(16, .semibold)) {
                    modele.ouvrirZmanim()
                }
            } else {
                if let prochain = z.prochain, let dans = z.dans {
                    Text(prochain, traducteur: traducteur)
                        .font(VersionPolice.secular(22))
                        .foregroundStyle(Pile.zmEncre)
                        .padding(.top, 14)
                    Text(dans, traducteur: traducteur)
                        .font(VersionPolice.rubik(16))
                        .foregroundStyle(Pile.zmDouce)
                        .padding(.top, 2)
                }
                Color.clear.frame(height: 10)
                ForEach(z.zmanim) { ligne in
                    let couleur = ligne.passe ? Pile.zmDouce : Pile.zmEncre
                    HStack {
                        Text(ligne.zman.nom, traducteur: traducteur)
                            .font(VersionPolice.rubik(16))
                            .foregroundStyle(couleur)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(verbatim: ligne.zman.heure)
                            .font(VersionPolice.rubik(17, .semibold))
                            .monospacedDigit()
                            .foregroundStyle(couleur)
                    }
                    .accessibilityElement(children: .combine)
                    .padding(.top, 12)
                }
                Spacer(minLength: 20)
                VersionBouton(libelle: Text(Libelle("version_tous_zmanim"), traducteur: traducteur), fond: Pile.zmAccent,
                              encre: Pile.zmBoutonEncre, police: VersionPolice.rubik(16, .semibold)) {
                    modele.ouvrirZmanim()
                }
            }
        }
    }

    private func carteJournal(_ j: PileJournal) -> some View {
        carte(0xFF574634, 0xFF2B2118) {
            etiquette(Libelle("pile_journal"), Pile.jrAccent)
            if let jour = j.jour, let duree = j.duree {
                Text(verbatim: VersionEcrit.chaine(jour, traducteur) + ", " + traducteur.texte(duree))
                    .font(VersionPolice.secular(20))
                    .foregroundStyle(Pile.jrEncre)
                    .padding(.top, 14)
                if let texte = j.texte {
                    // Le texte de la note reste dans le journal (décision du 24/11).
                    Text(texte, traducteur: traducteur)
                        .font(VersionPolice.rubik(16))
                        .foregroundStyle(Pile.jrDouce)
                        .padding(.top, 10)
                }
            } else {
                Text(Libelle("version_journal_vide"), traducteur: traducteur)
                    .font(VersionPolice.rubik(17))
                    .foregroundStyle(Pile.jrEncre)
                    .padding(.top, 14)
            }
            Spacer(minLength: 20)
            VersionBouton(libelle: Text(Libelle("version_ecrire_note"), traducteur: traducteur), fond: Pile.jrAccent,
                          encre: Pile.jrBoutonEncre, police: VersionPolice.rubik(16, .semibold)) {
                modele.ecrireNote()
            }
            VersionBouton(libelle: Text(Libelle("version_tout_journal"), traducteur: traducteur), fond: Pile.jrAccent,
                          encre: Pile.jrEncre, police: VersionPolice.rubik(16), trait: true) {
                modele.ouvrirJournal()
            }
            .padding(.top, 10)
            VersionBouton(libelle: Text(Libelle("version_parcours"), traducteur: traducteur), fond: Pile.jrAccent,
                          encre: Pile.jrEncre, police: VersionPolice.rubik(16), trait: true) {
                modele.ouvrirParcours()
            }
            .padding(.top, 10)
        }
    }
}

/// Le corps d'une carte de la pile : le dégradé (du coin du haut au coin du bas, GradientDrawable TL_BR), coins de
/// 28 ; le contenu défile si le texte agrandi déborde, et remplit au moins la hauteur de la carte (fillViewport).
private struct PileCorps<Contenu: View>: View {
    let haut: UInt32
    let bas: UInt32
    let contenu: Contenu

    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    contenu
                }
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .topLeading)
            }
        }
        .background(LinearGradient(colors: [VersionCouleur.argb(haut), VersionCouleur.argb(bas)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

/// La carte du 'hizouk : l'hébreu au recto, la traduction au verso ; elle se retourne sur elle-même (deux demi-tours
/// de 160 ms), ou change d'un coup avec « Réduire les animations ».
private struct PileHizoukCarte: View {
    let modele: AccueilVersionModele
    let hizouk: PileHizouk
    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var reduire
    @State private var versoMontre: Bool
    @State private var angle: Double = 0

    init(modele: AccueilVersionModele, hizouk: PileHizouk) {
        self.modele = modele
        self.hizouk = hizouk
        _versoMontre = State(initialValue: hizouk.verso)
    }

    var body: some View {
        PileCorps(haut: 0xFF34307A, bas: 0xFF1B1940, contenu: contenu)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.3)
            .onChange(of: hizouk.verso) { _, verso in
                // Sans animations, la carte change d'un coup ; sinon `retourner` la change à mi-tour.
                if reduire || modele.reduireAnimations { versoMontre = verso }
            }
            .onChange(of: modele.retournements) { _, _ in
                Task { @MainActor in await retourner() }
            }
    }

    @ViewBuilder
    private var contenu: some View {
        Text(Libelle("pile_hizouk"), traducteur: traducteur)
            .font(VersionPolice.rubik(13, .semibold))
            .textCase(.uppercase)
            .tracking(1.5)
            .foregroundStyle(Pile.hizAccent)
        if let p = hizouk.pensee {
            if versoMontre, let traduction = p.traduction {
                Text(Libelle("pile_traduction"), traducteur: traducteur)
                    .font(VersionPolice.rubik(13, .semibold))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundStyle(Pile.hizDouce)
                Text(verbatim: traduction)
                    .font(VersionPolice.rubik(18))
                    .foregroundStyle(Pile.hizEncre)
                    .lineSpacing(4)
                    .padding(.top, 10)
            } else {
                VersionHebreu(texte: p.hebreu, taille: 22, couleur: Pile.hizEncre, police: modele.police)
                    .padding(.top, 14)
            }
            Text(verbatim: p.reference)
                .font(VersionPolice.rubik(14))
                .italic()
                .foregroundStyle(Pile.hizDouce)
                .padding(.top, 14)
            Spacer(minLength: 20)
            if let bouton = hizouk.bouton {
                VersionBouton(libelle: Text(bouton, traducteur: traducteur), fond: Pile.hizAccent, encre: Pile.hizEncre,
                              police: VersionPolice.rubik(16, .semibold), trait: true) {
                    modele.basculerTraduction()
                }
            }
            VersionBouton(libelle: Text(Libelle("version_plus_de_textes"), traducteur: traducteur), fond: Pile.hizAccent,
                          encre: Pile.hizBoutonEncre, police: VersionPolice.rubik(16, .semibold)) {
                modele.ouvrirChizuk()
            }
            .padding(.top, 10)
        } else {
            Text(Libelle("version_chargement"), traducteur: traducteur)
                .font(VersionPolice.rubik(16))
                .foregroundStyle(Pile.hizEncre)
                .padding(.top, 16)
        }
    }

    /// Le retournement (PileActivity.retourner) : un quart de tour, la face change, puis l'autre quart.
    private func retourner() async {
        let demi = Double(AccueilVersionModele.dureeDemiTour) / 1000
        withAnimation(.easeIn(duration: demi)) { angle = 90 }
        guard await AccueilAttente.ms(AccueilVersionModele.dureeDemiTour) else {
            versoMontre = modele.pile.hizouk.verso
            angle = 0
            return
        }
        versoMontre = modele.pile.hizouk.verso
        angle = -90
        withAnimation(.easeOut(duration: demi)) { angle = 0 }
    }
}

/// Les couleurs de la maquette Pile.
enum Pile {
    static let fond = VersionCouleur.argb(0xFF15131F)
    static let encre = VersionCouleur.argb(0xFFF1EEF8)
    static let encreDouce = VersionCouleur.argb(0xFFA9A4BE)

    static let hitboAccent = VersionCouleur.argb(0xFF7FE7D9)
    static let hitboEncre = VersionCouleur.argb(0xFFEAFBF8)
    static let hitboDouce = VersionCouleur.argb(0xFFA9E3DC)
    static let hitboBoutonEncre = VersionCouleur.argb(0xFF07302F)

    static let hizAccent = VersionCouleur.argb(0xFFC9C6F0)
    static let hizEncre = VersionCouleur.argb(0xFFF3F2FF)
    static let hizDouce = VersionCouleur.argb(0xFFB4B0E2)
    static let hizBoutonEncre = VersionCouleur.argb(0xFF1B1940)

    static let zmAccent = VersionCouleur.argb(0xFFF5C9A8)
    static let zmEncre = VersionCouleur.argb(0xFFFFF1E6)
    static let zmDouce = VersionCouleur.argb(0xFFE0B49A)
    static let zmBoutonEncre = VersionCouleur.argb(0xFF3B1F14)

    static let jrAccent = VersionCouleur.argb(0xFFE9D9C3)
    static let jrEncre = VersionCouleur.argb(0xFFF8F0E4)
    static let jrDouce = VersionCouleur.argb(0xFFCFC0AB)
    static let jrBoutonEncre = VersionCouleur.argb(0xFF2B2118)
}

extension AccueilVersionModele {
    /// La carte montrée de la pile, suivie par le défilement (`scrollPosition`).
    var pageLiee: Int? {
        get { page }
        set { if let p = newValue { choisirPage(p) } }
    }
}
