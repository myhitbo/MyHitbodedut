import Foundation
import SwiftUI
import Coeur
import Ecrans

// La jauge de l'accueil (AnneauxView.kt, AnneauxDessin.kt ; hero_rings et hero_plate d'activity_main.xml) : les
// trois anneaux qui se remplissent, la plaque ronde au centre (le hassid, ou un chiffre et ce qu'il compte), qui
// tourne comme une pièce d'une face à l'autre, et le saut du hassid. Le modèle dit quoi et quand (`remplissage`,
// `retournements`, `saut`, `feteAnneau`, `retourHassidPrevu`) ; la vue joue les mouvements et rend la main au
// modèle à la fin (`remplissageFini`, `finFeteAnneau`, `retourHassid`). Avec « Réduire les animations », le modèle
// ne demande rien : tout est à sa place d'emblée.

/// La jauge : un carré de `cote`, les anneaux sur tout le carré, la plaque rentrée de `retraitPlaque`.
struct AccueilJaugeVue: View {
    let modele: AccueilModele
    let cote: CGFloat
    let retraitPlaque: CGFloat

    init(modele: AccueilModele, cote: CGFloat, retraitPlaque: CGFloat) {
        self.modele = modele
        self.cote = cote
        self.retraitPlaque = retraitPlaque
    }

    var body: some View {
        ZStack {
            AccueilAnneauxVue(modele: modele, cote: cote)
            AccueilPlaqueVue(modele: modele)
                .padding(retraitPlaque)
        }
        .frame(width: cote, height: cote)
        // Un toucher sur la plaque ou sur un anneau : un léger retour (CONTEXT_CLICK).
        .sensoryFeedback(.impact(weight: .light), trigger: modele.touches)
        // Un anneau qui se ferme : le retour de confirmation (CONFIRM).
        .sensoryFeedback(.success, trigger: modele.feteAnneau)
    }
}

// MARK: Les anneaux

/// Les trois anneaux, leur remplissage de `avanceDepart` à 1 en `dureeRemplissage` (en ralentissant fort,
/// DecelerateInterpolator(1,6)), leur battement quand l'un se ferme, et le toucher qui en met un en avant.
private struct AccueilAnneauxVue: View {
    let modele: AccueilModele
    let cote: CGFloat

    @Environment(\.traducteur) private var traducteur
    @Environment(\.paletteApp) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.layoutDirection) private var sens
    @Environment(\.accessibilityReduceMotion) private var reduire

    /// Le remplissage en cours de jeu, et quand il a commencé.
    @State private var numeroAnime: Int? = nil
    @State private var debut: Date? = nil
    /// Le battement d'une fête (×1,07, deux fois).
    @State private var echelle: CGFloat = 1
    /// La dernière fête jouée : un retour sur l'onglet ne la rejoue pas.
    @State private var feteJouee = 0

    init(modele: AccueilModele, cote: CGFloat) {
        self.modele = modele
        self.cote = cote
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: enPause)) { contexte in
            AccueilAnneauxToile(traits: modele.traits(avance: avance(contexte.date)), palette: palette,
                                nuit: schema == .dark, sensInverse: sens == .rightToLeft)
        }
        .frame(width: cote, height: cote)
        .scaleEffect(echelle)
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { point in
            // Le creux est couvert par la plaque ; entre deux anneaux ou dehors, rien.
            if let quel = AccueilAnneaux.sousLePoint(cote: Double(cote), x: Double(point.x), y: Double(point.y)) {
                modele.toucherAnneau(quel)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(modele.descriptionAnneaux, traducteur: traducteur))
        .task(id: modele.remplissage) {
            await remplir()
        }
        .task(id: modele.feteAnneau) {
            await feter()
        }
    }

    private var enPause: Bool {
        modele.remplissage == nil || debut == nil
    }

    /// La part du remplissage dessinée à cet instant.
    private func avance(_ maintenant: Date) -> Double {
        guard let numero = modele.remplissage else { return 1 }
        guard let debut, numeroAnime == numero else { return modele.avanceDepart }
        let duree = Double(AccueilModele.dureeRemplissage) / 1000
        let t = min(max(maintenant.timeIntervalSince(debut) / duree, 0), 1)
        return 1 - pow(1 - t, 3.2)
    }

    private func remplir() async {
        guard let numero = modele.remplissage else {
            debut = nil
            numeroAnime = nil
            return
        }
        numeroAnime = numero
        debut = Date()
        guard await TropheeAttente.ms(AccueilModele.dureeRemplissage) else { return }
        do {
            try await modele.remplissageFini(numero)
        } catch {
            // Android écrit ses préférences sans échec possible et ne montre rien : rien de plus ici.
        }
    }

    /// AnneauxView.feter : deux battements, puis l'anneau rend la place après `dureeFeteAnneau`.
    private func feter() async {
        guard let fete = modele.feteAnneau, fete.numero != feteJouee else { return }
        feteJouee = fete.numero
        var ecoule = 0
        if !reduire {
            for _ in 0..<2 {
                withAnimation(.easeOut(duration: 0.18)) {
                    echelle = 1.07
                }
                guard await TropheeAttente.ms(180) else { return }
                withAnimation(.spring(duration: 0.26, bounce: 0.45)) {
                    echelle = 1
                }
                guard await TropheeAttente.ms(260) else { return }
                ecoule += 440
            }
        }
        guard await TropheeAttente.ms(max(AccueilModele.dureeFeteAnneau - ecoule, 0)) else { return }
        modele.finFeteAnneau(fete.numero)
    }
}

/// Le dessin des anneaux (AnneauxDessin.dessiner) d'après les traits du modèle : la piste pâle entière, le premier
/// tour plein, puis le tour en cours depuis le haut dans le sens de lecture, plus sombre s'il repasse.
private struct AccueilAnneauxToile: View {
    let traits: [AccueilTrait]
    let palette: PaletteApp
    let nuit: Bool
    let sensInverse: Bool

    init(traits: [AccueilTrait], palette: PaletteApp, nuit: Bool, sensInverse: Bool) {
        self.traits = traits
        self.palette = palette
        self.nuit = nuit
        self.sensInverse = sensInverse
    }

    var body: some View {
        let traits = self.traits
        let piste = palette.couleur(.dayTodo, nuit: nuit)
        let couleurs = Anneaux.Quel.allCases.map { ($0, AccueilCouleurs.anneau($0, palette: palette, nuit: nuit)) }
        let inverse = sensInverse
        Canvas { contexte, taille in
            let cote = min(taille.width, taille.height)
            let gauche = (taille.width - cote) / 2
            let haut = (taille.height - cote) / 2
            for trait in traits {
                let retrait = CGFloat(trait.retrait)
                let cadre = CGRect(x: gauche + retrait, y: haut + retrait,
                                   width: cote - 2 * retrait, height: cote - 2 * retrait)
                guard cadre.width > 0 else { continue }
                let couleur = couleurs.first(where: { $0.0 == trait.quel })?.1 ?? .noir
                let largeur = CGFloat(trait.epaisseur)
                let ovale = Path(ellipseIn: cadre)
                let teintePiste = AccueilCouleurs.melange(piste, couleur, part: trait.teintePiste)
                contexte.stroke(ovale, with: .color(Color(teintePiste).opacity(trait.opacite)), lineWidth: largeur)
                if trait.tourPlein {
                    contexte.stroke(ovale, with: .color(Color(couleur).opacity(trait.opacite)),
                                    style: StrokeStyle(lineWidth: largeur, lineCap: .round))
                }
                if trait.reste > 0 {
                    let teinte = trait.assombri
                        ? AccueilCouleurs.melange(couleur, .noir, part: AccueilAnneaux.assombrissement) : couleur
                    // Depuis le haut (−90°) ; les angles croissent dans le sens des aiguilles d'une montre à l'écran
                    // (l'axe y descend), d'où `clockwise: false` pour le sens de lecture de gauche à droite.
                    let balayage = 360 * trait.reste * (inverse ? -1 : 1)
                    var arc = Path()
                    arc.addArc(center: CGPoint(x: cadre.midX, y: cadre.midY), radius: cadre.width / 2,
                               startAngle: .degrees(-90), endAngle: .degrees(-90 + balayage), clockwise: inverse)
                    contexte.stroke(arc, with: .color(Color(teinte).opacity(trait.opacite)),
                                    style: StrokeStyle(lineWidth: largeur, lineCap: .round))
                }
            }
        }
        // Le sens est déjà dans les angles : la toile ne se retourne pas en hébreu.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
    }
}

// MARK: La plaque

/// Ce que montre la plaque : le hassid, ou une face chiffrée.
private enum AccueilFacePlaque: Equatable {
    case hassid
    case face(AccueilFace)

    init(_ plaque: AccueilFace?) {
        if let plaque {
            self = .face(plaque)
        } else {
            self = .hassid
        }
    }
}

/// Ce que la plaque observe pour savoir qu'elle doit tourner, et ce qu'elle montrait avant.
private struct AccueilEtatPlaque: Equatable {
    let plaque: AccueilFace?
    let retournements: Int
}

/// La plaque ronde au centre (bg_gauge_plate : `stageSoft`), un bouton : la face suivante.
private struct AccueilPlaqueVue: View {
    let modele: AccueilModele

    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var reduire

    /// La face d'avant, montrée pendant la première moitié du retournement.
    @State private var faceFigee: AccueilFacePlaque? = nil
    @State private var angle: Double = 0
    @State private var numeroRetournement = 0
    @State private var enRetournement = false
    /// Le saut du hassid (pivot en bas au milieu, comme Android).
    @State private var sautHauteur: CGFloat = 0
    @State private var sautLargeur: CGFloat = 1
    @State private var sautEtirement: CGFloat = 1
    @State private var sautAngle: Double = 0
    @State private var sautJoue = 0

    init(modele: AccueilModele) {
        self.modele = modele
    }

    private var faceAffichee: AccueilFacePlaque {
        faceFigee ?? AccueilFacePlaque(modele.plaque)
    }

    var body: some View {
        Button {
            modele.toucherPlaque()
        } label: {
            contenu
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Teinte(.stageSoft), in: Circle())
                .clipShape(Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0))
        .accessibilityLabel(Text(verbatim: AccueilEcriture.joints(modele.accessibilitePlaque, traducteur,
                                                                   separateur: " ")))
        .onChange(of: AccueilEtatPlaque(plaque: modele.plaque, retournements: modele.retournements)) { ancien, nouveau in
            guard nouveau.retournements != ancien.retournements, !reduire else { return }
            // Un retournement déjà commencé garde la face qu'il montre encore.
            faceFigee = faceFigee ?? AccueilFacePlaque(ancien.plaque)
            numeroRetournement += 1
        }
        .task(id: numeroRetournement) {
            await retourner()
        }
        .task(id: modele.saut) {
            await sauter()
        }
        .task(id: modele.retourHassidPrevu) {
            guard let numero = modele.retourHassidPrevu else { return }
            guard await TropheeAttente.ms(AccueilModele.dureeRetourHassid) else { return }
            modele.retourHassid(numero)
        }
    }

    @ViewBuilder
    private var contenu: some View {
        switch faceAffichee {
        case .hassid:
            Illustration(decorative: modele.imageHassid)
                .scaleEffect(x: sautLargeur, y: sautEtirement, anchor: .bottom)
                .rotationEffect(.degrees(sautAngle), anchor: .bottom)
                .offset(y: sautHauteur)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .face(let face):
            AccueilFaceVue(face: face)
                .id(face.face)
        }
    }

    /// MainActivity.retourner : 0 → 90° en 140 ms (en accélérant), la face change, −90° → 0 en 200 ms (en
    /// ralentissant).
    private func retourner() async {
        guard faceFigee != nil else { return }
        enRetournement = true
        withAnimation(.easeIn(duration: 0.14)) {
            angle = 90
        }
        guard await TropheeAttente.ms(140) else { return }
        TropheeTransaction.sansAnimation {
            faceFigee = nil
            angle = -90
        }
        withAnimation(.easeOut(duration: 0.2)) {
            angle = 0
        }
        guard await TropheeAttente.ms(200) else { return }
        enRetournement = false
    }

    /// MainActivity.sautiller, `fois` de suite, une fois le retournement fini.
    private func sauter() async {
        guard let saut = modele.saut, saut.numero != sautJoue, !reduire else { return }
        sautJoue = saut.numero
        if enRetournement {
            guard await TropheeAttente.ms(340) else { return }
        }
        for _ in 0..<max(saut.fois, 0) {
            withAnimation(.easeOut(duration: 0.22)) {
                sautHauteur = -10
                sautLargeur = 1.04
                sautEtirement = 1.06
                sautAngle = -3
            }
            guard await TropheeAttente.ms(220) else { return }
            withAnimation(.spring(duration: 0.26, bounce: 0.5)) {
                sautHauteur = 0
                sautLargeur = 1
                sautEtirement = 1
                sautAngle = 3
            }
            guard await TropheeAttente.ms(260) else { return }
            withAnimation(.easeInOut(duration: 0.16)) {
                sautAngle = 0
            }
            guard await TropheeAttente.ms(160) else { return }
        }
    }
}

/// Une face chiffrée (hero_face) : le chiffre, qui monte de 0 à sa cible en `dureeCompteur` s'il le doit, et ce
/// qu'il compte dessous.
private struct AccueilFaceVue: View {
    let face: AccueilFace

    @Environment(\.traducteur) private var traducteur
    @State private var debut = Date()
    @State private var fini = false
    @ScaledMetric(relativeTo: .largeTitle) private var hauteurChiffre: CGFloat = 44

    init(face: AccueilFace) {
        self.face = face
    }

    var body: some View {
        VStack(spacing: 0) {
            TimelineView(.animation(minimumInterval: nil, paused: !face.compte || fini)) { contexte in
                Text(verbatim: chiffre(contexte.date))
                    .font(.system(size: 34, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(16.0 / 34.0)
                    .foregroundStyle(AccueilTeinte(face.couleur))
            }
            .frame(maxWidth: .infinity)
            .frame(height: hauteurChiffre)
            Text(face.legende, traducteur: traducteur)
                .font(.caption)
                .foregroundStyle(Teinte(.muted))
                .lineLimit(3)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            guard face.compte else { return }
            if await TropheeAttente.ms(AccueilModele.dureeCompteur) {
                fini = true
            }
        }
    }

    /// Le chiffre à cet instant : DecelerateInterpolator() d'Android sur `ofInt(0, cible)`.
    private func chiffre(_ maintenant: Date) -> String {
        guard face.compte, !fini else { return AccueilEcriture.texte(face.texte, traducteur) }
        let duree = Double(AccueilModele.dureeCompteur) / 1000
        let t = min(max(maintenant.timeIntervalSince(debut) / duree, 0), 1)
        let e = 1 - (1 - t) * (1 - t)
        return AccueilEcriture.texte(face.valeur(Int(Double(face.cible) * e)), traducteur)
    }
}
