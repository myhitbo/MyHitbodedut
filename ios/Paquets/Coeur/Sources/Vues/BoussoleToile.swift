import Foundation
import SwiftUI
import UIKit
import Coeur
import Ecrans

/// Le dessin de la boussole (BoussoleDessin.kt, BoussoleView.onDraw) : la scène que le modèle a choisie
/// (BoussoleScene), tracée dans un Canvas sur le carré de 320 unités centré sur (0, 0) de la maquette (112 pour
/// la rose fixe). Les angles, les positions et les textes viennent de la scène ; ce fichier ne fait que les
/// poser, avec les couleurs fixes de la scène, de jour comme de nuit (une illustration, comme bg_stage).
///
/// Le dessin ne se retourne pas en hébreu : l'est reste à droite. Les ordonnées des textes sont leurs lignes de
/// base, comme `Canvas.drawText` d'Android. Aucune animation : la scène se redessine à chaque mesure, déjà lissée
/// par le modèle.
struct BoussoleToile: View {
    let scene: BoussoleScene
    /// Le « N » de la rose fixe.
    let nord: Libelle
    /// N, E, S, O dans la langue, pour la rose vivante.
    let cardinaux: [String]
    /// Le nom de l'image du hassid de dos (déjà au féminin pour צדקת).
    let imageHassid: String

    @Environment(\.traducteur) private var traducteur
    /// L'image du hassid, lue une fois par nom (et non à chaque mesure du capteur).
    @State private var image: BoussoleImageChargee? = nil

    init(scene: BoussoleScene, nord: Libelle, cardinaux: [String], imageHassid: String) {
        self.scene = scene
        self.nord = nord
        self.cardinaux = cardinaux
        self.imageHassid = imageHassid
    }

    var body: some View {
        Canvas { context, taille in
            dessiner(context, taille)
        }
        .task(id: imageHassid) {
            image = BoussoleImageChargee(nom: imageHassid)
        }
    }

    // MARK: Les trois scènes

    private func dessiner(_ context: GraphicsContext, _ taille: CGSize) {
        switch scene {
        case .roseFixe(let rose):
            dessinerRoseFixe(context, taille, rose)
        case .hassid(let hassid):
            dessinerHassid(context, taille, hassid)
        case .roseVivante(let rose):
            dessinerRoseVivante(context, taille, rose)
        }
    }

    /// BoussoleDessin.rose : le nord en haut, le triangle d'or vers la direction principale, le hassid au
    /// centre, « N » en haut, les degrés en bas à droite, « ירושלים » en bas à gauche.
    private func dessinerRoseFixe(_ context: GraphicsContext, _ taille: CGSize, _ rose: BoussoleRoseFixe) {
        let c = cadrer(context, taille, cote: 112)
        c.fill(Path(roundedRect: CGRect(x: -56, y: -56, width: 112, height: 112), cornerRadius: 12, style: .circular),
               with: .color(BoussoleCouleursScene.ciel))
        c.stroke(cercle(CGPoint(x: 0, y: 0), 44), with: .color(BoussoleCouleursScene.horizon), lineWidth: 1.2)
        poserHassid(c, CGRect(x: -12, y: -33, width: 26, height: 81))
        let tournee = tourner(c, rose.principale, autour: CGPoint(x: 0, y: 0))
        tournee.fill(polygone([CGPoint(x: 0, y: -53), CGPoint(x: 5, y: -37), CGPoint(x: 0, y: -40),
                               CGPoint(x: -5, y: -37)]),
                     with: .color(BoussoleCouleursScene.or))
        ecrire(c, Text(nord, traducteur: traducteur), taille: 9, gras: true,
               couleur: BoussoleCouleursScene.encre, a: CGPoint(x: 0, y: -42))
        ecrire(c, Text(verbatim: String(rose.degres) + "°"), taille: 10,
               couleur: BoussoleCouleursScene.encre, a: CGPoint(x: 38, y: 51))
        ecrire(c, Text(verbatim: BoussoleScene.jerusalem), taille: 9, gras: true, serif: true,
               couleur: BoussoleCouleursScene.marque, a: CGPoint(x: -36, y: 51))
    }

    /// BoussoleDessin.ecran, le design C : le hassid de dos, Jérusalem qui glisse sur l'horizon, l'autre
    /// direction en petit rond pointillé bleu.
    private func dessinerHassid(_ context: GraphicsContext, _ taille: CGSize, _ scene: BoussoleHassid) {
        let c = cadrer(context, taille, cote: 320)
        c.fill(Path(CGRect(x: -160, y: -160, width: 320, height: 320)), with: .color(BoussoleCouleursScene.ciel))
        var sol = Path()
        sol.move(to: CGPoint(x: -160, y: 40))
        sol.addQuadCurve(to: CGPoint(x: 160, y: 40), control: CGPoint(x: 0, y: 10))
        sol.addLine(to: CGPoint(x: 160, y: 160))
        sol.addLine(to: CGPoint(x: -160, y: 160))
        sol.closeSubpath()
        c.fill(sol, with: .color(BoussoleCouleursScene.sol))
        c.stroke(trait(CGPoint(x: -150, y: -90), CGPoint(x: 150, y: -90)),
                 with: .color(BoussoleCouleursScene.horizon), lineWidth: 2)

        // L'autre direction : un petit rond pointillé.
        c.stroke(cercle(CGPoint(x: scene.xAutre, y: -90), 7), with: .color(BoussoleCouleursScene.bleu),
                 style: StrokeStyle(lineWidth: 2.5, dash: [3, 3]))

        // Jérusalem : l'étiquette, entière dans le cadre, et son point.
        let etiquette = CGRect(x: scene.xEtiquette - 34, y: -124, width: 68, height: 22)
        c.fill(Path(roundedRect: etiquette, cornerRadius: 11, style: .circular),
               with: .color(scene.face ? BoussoleCouleursScene.marque : BoussoleCouleursScene.blanc))
        ecrire(c, Text(verbatim: BoussoleScene.jerusalem), taille: 15, gras: true, serif: true,
               couleur: scene.face ? BoussoleCouleursScene.blanc : BoussoleCouleursScene.marque,
               a: CGPoint(x: scene.xEtiquette, y: -108))
        c.fill(cercle(CGPoint(x: scene.xJerusalem, y: -90), 8),
               with: .color(scene.face ? BoussoleCouleursScene.marque : BoussoleCouleursScene.or))

        // Face à Jérusalem, il se hausse un peu (yHassid).
        poserHassid(c, CGRect(x: -28, y: scene.yHassid, width: 56, height: 176))
        ecrire(c, Text(scene.consigne, traducteur: traducteur), taille: 14,
               couleur: BoussoleCouleursScene.encre, a: CGPoint(x: 0, y: -132))
    }

    /// BoussoleDessin.roseVivante : le cadran tourne avec le téléphone, le repère fixe du haut est le cap ;
    /// l'aiguille d'or va vers la direction principale, le trait bleu pointillé vers l'autre ; face à
    /// Jérusalem, un anneau d'or. Dessinée sur une grille de 240 unités (centre 120, rayon 104).
    private func dessinerRoseVivante(_ context: GraphicsContext, _ taille: CGSize, _ rose: BoussoleRoseVivante) {
        var c = cadrer(context, taille, cote: 320)
        c.fill(Path(CGRect(x: -160, y: -160, width: 320, height: 320)), with: .color(BoussoleCouleursScene.ciel))
        ecrire(c, Text(rose.consigne, traducteur: traducteur), taille: 14,
               couleur: BoussoleCouleursScene.encre, a: CGPoint(x: 0, y: -142))
        c.translateBy(x: 0, y: 12)
        c.scaleBy(x: 1.15, y: 1.15)
        c.translateBy(x: -120, y: -120)
        let ce: CGFloat = 120
        let r: CGFloat = 104
        let centre = CGPoint(x: ce, y: ce)
        let encre = BoussoleCouleursScene.encre
        let or = BoussoleCouleursScene.or

        if rose.face {
            for i in stride(from: 6, through: 1, by: -1) {
                c.stroke(cercle(centre, r + 12), with: .color(or.opacity(14.0 / 255)),
                         style: StrokeStyle(lineWidth: 4 + CGFloat(i) * 3, lineCap: .round))
            }
            c.stroke(cercle(centre, r + 13), with: .color(or), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
        c.fill(cercle(centre, r + 10),
               with: .color(rose.face ? BoussoleCouleursScene.fondFace : BoussoleCouleursScene.fondCadran))
        c.stroke(cercle(centre, r + 10), with: .color(encre.opacity(30.0 / 255)),
                 style: StrokeStyle(lineWidth: 1, lineCap: .round))

        // Le cadran, tourné du cap : le nord du cadran reste au nord.
        let cadran = tourner(c, -rose.cap, autour: centre)
        cadran.stroke(cercle(centre, r), with: .color(encre.opacity(77.0 / 255)),
                      style: StrokeStyle(lineWidth: 1, lineCap: .round))
        cadran.stroke(arc(centre, rayon: r - 6, debut: rose.principale - 90 - rose.tolerance,
                          etendue: 2 * rose.tolerance),
                      with: .color(or.opacity(90.0 / 255)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
        graduations(cadran, centre, r)
        degres(cadran, centre, r)
        lettres(cadran, centre, r)

        // L'autre direction, en pointillé bleu.
        tourner(cadran, rose.autre, autour: centre)
            .stroke(trait(centre, CGPoint(x: ce, y: ce - r + 20)), with: .color(BoussoleCouleursScene.bleu),
                    style: StrokeStyle(lineWidth: 2.5, dash: [6, 6]))

        // L'aiguille d'or vers la direction principale.
        let aiguille = tourner(cadran, rose.principale, autour: centre)
        aiguille.stroke(trait(CGPoint(x: ce, y: ce + 8), CGPoint(x: ce, y: ce + 34)),
                        with: .color(encre.opacity(90.0 / 255)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        aiguille.fill(polygone([CGPoint(x: ce, y: ce - r + 16), CGPoint(x: ce - 9, y: ce + 2),
                                CGPoint(x: ce, y: ce - 6), CGPoint(x: ce + 9, y: ce + 2)]),
                      with: .color(or))

        // Le repère fixe du haut, où pointe le téléphone ; le moyeu.
        c.fill(polygone([CGPoint(x: ce, y: 4), CGPoint(x: ce - 7, y: 16), CGPoint(x: ce + 7, y: 16)]),
               with: .color(rose.face ? or : BoussoleCouleursScene.marque))
        c.fill(cercle(centre, 6), with: .color(or))
        c.fill(cercle(centre, 2.5), with: .color(BoussoleCouleursScene.blanc))
    }

    // MARK: Le cadran de la rose vivante

    /// Graduations tous les 5° : longues et fortes aux 30°, moyennes aux 10°, courtes sinon.
    private func graduations(_ c: GraphicsContext, _ centre: CGPoint, _ r: CGFloat) {
        let encre = BoussoleCouleursScene.encre
        for g in stride(from: 0, to: 360, by: 5) {
            let fort = g % 30 == 0
            let longueur: CGFloat = fort ? 12 : (g % 10 == 0 ? 7 : 4)
            let couleur = fort ? encre : encre.opacity(102.0 / 255)
            c.stroke(trait(point(centre, Double(g), r), point(centre, Double(g), r - longueur)),
                     with: .color(couleur), style: StrokeStyle(lineWidth: fort ? 1.6 : 0.8, lineCap: .round))
        }
    }

    /// « 30 », « 60 »… (pas aux points cardinaux), chacun tourné de son angle.
    private func degres(_ c: GraphicsContext, _ centre: CGPoint, _ r: CGFloat) {
        let couleur = BoussoleCouleursScene.encre.opacity(170.0 / 255)
        for g in stride(from: 30, to: 360, by: 30) where g % 90 != 0 {
            let p = point(centre, Double(g), r - 24)
            ecrire(tourner(c, Double(g), autour: p), Text(verbatim: String(g)), taille: 8.5, couleur: couleur,
                   a: CGPoint(x: p.x, y: p.y + 3))
        }
    }

    /// N, E, S, O dans la langue, le nord à la couleur de la marque.
    private func lettres(_ c: GraphicsContext, _ centre: CGPoint, _ r: CGFloat) {
        for (i, lettre) in cardinaux.prefix(4).enumerated() {
            let g = Double(i) * 90
            let p = point(centre, g, r - 30)
            ecrire(tourner(c, g, autour: p), Text(verbatim: lettre), taille: 16, gras: true,
                   couleur: i == 0 ? BoussoleCouleursScene.marque : BoussoleCouleursScene.encre,
                   a: CGPoint(x: p.x, y: p.y + 6))
        }
    }

    // MARK: Les outils du dessin

    /// BoussoleDessin.cadrer : le carré de `cote` unités, centré, à la plus grande taille qui tient.
    private func cadrer(_ context: GraphicsContext, _ taille: CGSize, cote: CGFloat) -> GraphicsContext {
        var c = context
        let echelle = min(taille.width, taille.height) / cote
        c.translateBy(x: taille.width / 2, y: taille.height / 2)
        c.scaleBy(x: echelle, y: echelle)
        return c
    }

    /// `Canvas.rotate(degres, px, py)` d'Android : dans le sens des aiguilles d'une montre, autour d'un point.
    private func tourner(_ context: GraphicsContext, _ degres: Double, autour p: CGPoint) -> GraphicsContext {
        var c = context
        c.translateBy(x: p.x, y: p.y)
        c.rotate(by: .degrees(degres))
        c.translateBy(x: -p.x, y: -p.y)
        return c
    }

    /// Le point à `degres` du nord (sens des aiguilles), à `rayon` du centre : x(g, r), y(g, r) d'Android.
    private func point(_ centre: CGPoint, _ degres: Double, _ rayon: CGFloat) -> CGPoint {
        let a = degres * .pi / 180
        return CGPoint(x: centre.x + rayon * CGFloat(sin(a)), y: centre.y - rayon * CGFloat(cos(a)))
    }

    private func cercle(_ centre: CGPoint, _ rayon: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: centre.x - rayon, y: centre.y - rayon, width: 2 * rayon, height: 2 * rayon))
    }

    private func trait(_ a: CGPoint, _ b: CGPoint) -> Path {
        var p = Path()
        p.move(to: a)
        p.addLine(to: b)
        return p
    }

    private func polygone(_ sommets: [CGPoint]) -> Path {
        var p = Path()
        p.addLines(sommets)
        p.closeSubpath()
        return p
    }

    /// `drawArc` d'Android : les angles partent de l'est (3 h) et tournent dans le sens des aiguilles. Tracé
    /// en segments courts, pour ne pas dépendre du sens de `addArc` dans un repère dont l'axe y descend.
    private func arc(_ centre: CGPoint, rayon: CGFloat, debut: Double, etendue: Double) -> Path {
        var p = Path()
        let pas = 24
        for i in 0...pas {
            let a = (debut + etendue * Double(i) / Double(pas)) * .pi / 180
            let sommet = CGPoint(x: centre.x + rayon * CGFloat(cos(a)), y: centre.y + rayon * CGFloat(sin(a)))
            if i == 0 {
                p.move(to: sommet)
            } else {
                p.addLine(to: sommet)
            }
        }
        return p
    }

    /// Le hassid de dos dans le rectangle donné (étiré comme `drawBitmap` d'Android) ; rien s'il manque.
    private func poserHassid(_ c: GraphicsContext, _ cadre: CGRect) {
        guard let chargee = image, chargee.nom == imageHassid, let dessin = chargee.image else { return }
        c.draw(dessin, in: cadre)
    }

    /// Un texte centré sur `a`, dont l'ordonnée est la ligne de base (`drawText` d'Android, Align.CENTER), à
    /// une taille fixe en unités de la scène : la scène entière suit la largeur de l'écran.
    private func ecrire(_ c: GraphicsContext, _ texte: Text, taille: CGFloat, gras: Bool = false,
                        serif: Bool = false, couleur: Color, a: CGPoint) {
        let police = Font.system(size: taille, weight: gras ? .bold : .regular, design: serif ? .serif : .default)
        let resolu = c.resolve(texte.font(police).foregroundStyle(couleur))
        let mesure = resolu.measure(in: CGSize(width: 2000, height: 2000))
        let base = resolu.firstBaseline(in: mesure)
        c.draw(resolu, at: CGPoint(x: a.x, y: a.y - base), anchor: .top)
    }
}

/// L'image du hassid lue dans le paquet de l'app (`Images/<nom>.webp`, comme Illustration), gardée avec son nom.
struct BoussoleImageChargee {
    let nom: String
    let image: Image?

    init(nom: String) {
        self.nom = nom
        if let chemin = Bundle.main.path(forResource: nom, ofType: "webp", inDirectory: "Images"),
           let ui = UIImage(contentsOfFile: chemin) {
            image = Image(uiImage: ui)
        } else {
            image = nil
        }
    }
}

/// Les couleurs de la scène (BoussoleDessin.CIEL…), fixes comme une illustration, de jour comme de nuit :
/// Android les écrit en dur, ce ne sont pas des jetons de la palette.
enum BoussoleCouleursScene {
    static let ciel = rgb(0xDF, 0xF5, 0xE8)
    static let sol = rgb(0xCB, 0xEB, 0xD8)
    static let horizon = rgb(0x9C, 0xC9, 0xB0)
    static let encre = rgb(0x17, 0x3C, 0x32)
    static let marque = rgb(0x16, 0x77, 0x5A)
    static let or = rgb(0xB8, 0x78, 0x0F)
    static let bleu = rgb(0x2E, 0x7D, 0xB3)
    static let blanc = rgb(0xFF, 0xFF, 0xFF)
    /// Le fond du cadran face à Jérusalem : blendARGB(BLANC, OR, 0,14).
    static let fondFace = melange(0xB8, 0x78, 0x0F, 0.14)
    /// Le fond du cadran sinon : blendARGB(BLANC, ENCRE, 0,04).
    static let fondCadran = melange(0x17, 0x3C, 0x32, 0.04)

    private static func rgb(_ rouge: Double, _ vert: Double, _ bleu: Double) -> Color {
        Color(.sRGB, red: rouge / 255, green: vert / 255, blue: bleu / 255, opacity: 1)
    }

    /// Le blanc mêlé d'une couleur dans la proportion `part` (ColorUtils.blendARGB).
    private static func melange(_ rouge: Double, _ vert: Double, _ bleu: Double, _ part: Double) -> Color {
        rgb(255 * (1 - part) + rouge * part, 255 * (1 - part) + vert * part, 255 * (1 - part) + bleu * part)
    }
}
