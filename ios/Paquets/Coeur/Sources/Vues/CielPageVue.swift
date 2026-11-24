import Foundation
import SwiftUI
import Coeur

/// Le ciel du moment en fond de tout le Jour (CielPage.kt, 24/11). Le propriétaire : « Fais en sorte que le mode jour
/// nuit au coucher du soleil ou lever du soleil s'affiche dans l'arrière-plan de la première page sur toute la page,
/// pas dans le logo dans les anneaux » ; puis un ciel continu, qui suit le vrai soleil du lieu, illustré à plat
/// (`CielContinu`). La plaque du hassid garde son disque clair.
///
/// Posé en fond du contenu du Jour, il en couvre toute la largeur et monte avec la page : le dégradé (`TeintesCiel`)
/// va du haut du contenu jusqu'au bas du premier écran (`hauteurVue`), où deux collines lointaines ferment
/// l'horizon ; leur couleur (le sol) continue au-delà et sous la barre de départ, qui la reprend (`BarreDepart`).
/// Par-dessus :
///  - le soleil suit un arc de la gauche (lever) à la droite (coucher), à côté des anneaux et derrière eux vers midi,
///    sa hauteur selon celle du vrai soleil (`PlanCiel.arc`) ; sous l'horizon, rien ; la nuit, la lune fait de même,
///    sa phase selon le jour du mois hébreu ; autour, une couronne vive et une lueur large ; à l'heure dorée, des
///    rayons doux ;
///  - les étoiles s'allument avec la profondeur du crépuscule ;
///  - trois nuages prennent la lumière du moment (bord éclairé dessous, corps par-dessus).
/// Les étoiles, le disque, la couronne et les rayons ne tombent jamais sous un texte (`PlanCiel`) ; la lueur, les
/// nuages et les collines gardent tout texte lisible (`TeintesCiel`). Le soleil se lève à gauche en hébreu et en
/// arabe aussi, comme sur Android : le ciel est dessiné de gauche à droite quelle que soit la langue.
///
/// Les mouvements sont ceux de `CielVivant`, au rythme de `CielVivantHorloge` ; à l'arrêt, le ciel prend sa pose de
/// repos. Seule la couche du milieu (étoiles, astre, nuages) est redessinée à chaque image ; le dégradé et les
/// collines ne le sont que quand le ciel change (au plus chaque minute). Décoratif : VoiceOver ne le voit pas.
struct CielPageVue: View {
    let etat: EtatCiel
    let teintes: TeintesCiel.Page
    let sombre: Bool
    /// Le carré des anneaux et ce qui porte du texte, en points dans le contenu (haut du contenu = 0).
    let jauge: PlanCiel.Zone?
    let zones: [PlanCiel.Zone]
    /// La largeur et la hauteur du contenu, et celle du premier écran.
    let largeur: Double
    let hauteur: Double
    let hauteurVue: Double

    var body: some View {
        let hv = max(hauteurVue, PlanCiel.collines)
        let trace = PlanCiel.tracer(etat: etat, sombre: sombre, jauge: jauge, zones: zones, largeur: largeur,
                                    hauteurVue: hv)
        // La couche animée ne couvre que le premier écran et la bande des anneaux, même si la page est longue.
        let hauteurAnimee = min(max(hauteur, hv), max(hv, (jauge?.bas ?? 0) + 60))
        ZStack(alignment: .topLeading) {
            Canvas { contexte, taille in
                peindreFond(contexte, taille, hv)
            }
            CielVivantHorloge { secondes in
                Canvas { contexte, taille in
                    peindreMotifs(contexte, taille, hv, trace, secondes)
                }
            }
            .frame(height: hauteurAnimee)
            Canvas { contexte, taille in
                peindreCollines(contexte, taille)
            }
            .frame(height: PlanCiel.collines)
            .offset(y: hv - PlanCiel.collines)
        }
        .frame(width: max(largeur, 1), height: max(hauteur, hv), alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func couleur(_ argb: UInt32, _ opacite: Double = 1) -> Color {
        CielCouleur.couleur(argb, opacite: opacite)
    }

    // MARK: Ce qui ne bouge pas

    /// Le dégradé sur le premier écran, puis le sol.
    private func peindreFond(_ c: GraphicsContext, _ taille: CGSize, _ hv: Double) {
        let t = teintes
        let w = taille.width
        let milieu = Double(TeintesCiel.milieuDegrade)
        c.fill(Path(CGRect(x: 0, y: 0, width: w, height: hv)), with: .linearGradient(
            Gradient(stops: [Gradient.Stop(color: couleur(t.haut), location: 0),
                             Gradient.Stop(color: couleur(t.milieu), location: milieu),
                             Gradient.Stop(color: couleur(t.bas), location: 1)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: hv)))
        if taille.height > hv {
            c.fill(Path(CGRect(x: 0, y: hv, width: w, height: taille.height - hv)), with: .color(couleur(t.collinePres)))
        }
    }

    /// Les deux collines lointaines du bas du premier écran, en aplats : la plus lointaine plus claire.
    private func peindreCollines(_ c: GraphicsContext, _ taille: CGSize) {
        let w = taille.width
        let h = taille.height
        var loin = Path()
        loin.move(to: CGPoint(x: 0, y: h * 0.55))
        loin.addCurve(to: CGPoint(x: w * 0.6, y: h * 0.3), control1: CGPoint(x: w * 0.22, y: h * 0.18),
                      control2: CGPoint(x: w * 0.42, y: h * 0.42))
        loin.addCurve(to: CGPoint(x: w, y: h * 0.3), control1: CGPoint(x: w * 0.78, y: h * 0.16),
                      control2: CGPoint(x: w * 0.9, y: h * 0.34))
        loin.addLine(to: CGPoint(x: w, y: h))
        loin.addLine(to: CGPoint(x: 0, y: h))
        loin.closeSubpath()
        c.fill(loin, with: .color(couleur(teintes.collineLoin)))
        var pres = Path()
        pres.move(to: CGPoint(x: 0, y: h * 0.78))
        pres.addCurve(to: CGPoint(x: w * 0.76, y: h * 0.6), control1: CGPoint(x: w * 0.3, y: h * 0.5),
                      control2: CGPoint(x: w * 0.55, y: h * 0.72))
        pres.addCurve(to: CGPoint(x: w, y: h * 0.6), control1: CGPoint(x: w * 0.88, y: h * 0.54),
                      control2: CGPoint(x: w * 0.95, y: h * 0.62))
        pres.addLine(to: CGPoint(x: w, y: h))
        pres.addLine(to: CGPoint(x: 0, y: h))
        pres.closeSubpath()
        c.fill(pres, with: .color(couleur(teintes.collinePres)))
    }

    // MARK: Chaque image

    /// Les étoiles, puis, derrière les anneaux (le cercle qu'ils occupent ne laisse rien passer), l'astre et les
    /// nuages qui passent devant lui. `secondes` : nil au repos.
    private func peindreMotifs(_ c: GraphicsContext, _ taille: CGSize, _ hv: Double, _ trace: PlanCiel.Trace,
                               _ secondes: Double?) {
        let t = teintes
        let w = taille.width
        let e = etat.hauteur
        let marche = secondes != nil
        let s = secondes ?? 0

        // Les étoiles s'allument avec le crépuscule, chacune à son rythme ; le champ dérive d'un rien.
        let lueurEtoiles = CielContinu.etoiles(e)
        if lueurEtoiles > 0 {
            let dx = marche ? Double(CielVivant.deriveX(s)) : 0
            let dy = marche ? Double(CielVivant.deriveY(s)) : 0
            let zone = hv * trace.limite
            let etoile = couleur(t.etoile)
            let degrade = Gradient(stops: [Gradient.Stop(color: etoile, location: 0),
                                           Gradient.Stop(color: etoile, location: 0.5),
                                           Gradient.Stop(color: etoile.opacity(0), location: 1)])
            for i in trace.libres.indices where trace.libres[i] {
                let o = i * CielVivant.champs
                let x = Double(trace.etoiles[o]) * w + dx
                let y = Double(trace.etoiles[o + 1]) * zone + dy
                let r = Double(trace.etoiles[o + 2]) * 1.6
                let vif = marche
                    ? Double(CielVivant.scintillement(s, periode: Double(trace.etoiles[o + 3]),
                                                      phase: Double(trace.etoiles[o + 4])))
                    : 1
                let pale = 1 - 0.6 * min(max(y / zone, 0), 1)
                var k = c
                k.opacity = min(max(Double(t.etoileAlpha) * lueurEtoiles * pale * vif, 0), 1)
                k.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                       with: .radialGradient(degrade, center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
            }
        }

        var dedans = c
        if let a = trace.anneaux {
            dedans.clip(to: Path(ellipseIn: CGRect(x: a.cx - a.r, y: a.cy - a.r, width: 2 * a.r, height: 2 * a.r)),
                        options: .inverse)
        }

        // L'astre, sa lueur et sa couronne qui respirent, les rayons de l'heure dorée qui tournent lentement, le
        // disque.
        if let place = trace.astre, trace.lueurAlpha > 0 {
            let x = place.x
            let y = place.y
            let r = trace.rayon
            let k = marche ? Double(CielVivant.tailleHalo(s)) : 1
            var halo = dedans
            halo.opacity = min(max((marche ? Double(CielVivant.eclatHalo(s)) : 1) * trace.lueurAlpha, 0), 1)
            halo.drawLayer { couche in
                peindreHalo(couche, x, y, r, k, trace.estSoleil)
            }
            let doux = trace.estSoleil ? CielContinu.rayons(e) : 0
            if doux > 0 {
                peindreRayons(dedans, x, y, r, angle: marche ? (s * CielVivant.rayonsDegS).truncatingRemainder(dividingBy: 360) : 0,
                              opacite: doux * trace.astreAlpha)
            }
            var disque = dedans
            disque.opacity = min(max(trace.astreAlpha, 0), 1)
            if trace.estSoleil {
                disque.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                            with: .color(couleur(t.astre)))
            } else {
                CielDessin.lune(disque, x, y, r, couleur: couleur(t.lune), CielContinu.lune(etat.jourHebreu))
            }
        }

        // Les nuages prennent la lumière du moment et passent de gauche à droite : le bord éclairé dessous, le corps
        // dessus. Vifs dans la bande des anneaux, loin de tout texte ; bornés sinon.
        let presence = CielContinu.nuages(e)
        if presence > 0 {
            for (i, n) in PlanCiel.nuages.enumerated() {
                let vif = trace.nuagesVifs[i]
                let lw = PlanCiel.tailles[n.forme].largeur * n.echelle
                let lh = PlanCiel.tailles[n.forme].hauteur * n.echelle
                let x0 = n.depart * w
                let vitesse = Double(CielVivant.nuageDpS) * (n.forme == 1 ? 0.7 : 1)
                let x = marche
                    ? CielVivant.nuageX(depart: x0, vitesse: vitesse, secondes: s, largeurCiel: w, largeurNuage: lw)
                    : x0
                let y = trace.nuagesY[i]
                CielDessin.nuage(dedans, forme: n.forme, CGRect(x: x, y: y + PlanCiel.bordNuage, width: lw, height: lh),
                                 couleur: couleur(vif ? t.bordVif : t.bord),
                                 opacite: (vif ? PlanCiel.nuageVif : Double(t.bordAlpha)) * presence)
                CielDessin.nuage(dedans, forme: n.forme, CGRect(x: x, y: y, width: lw, height: lh),
                                 couleur: couleur(vif ? t.corpsVif : t.corps),
                                 opacite: (vif ? PlanCiel.nuageVif : Double(t.corpsAlpha)) * presence)
            }
        }
    }

    /// La lueur large (opacité bornée, `TeintesCiel`) et la couronne vive, dans une même couche ; `k` : le souffle.
    private func peindreHalo(_ c: GraphicsContext, _ x: Double, _ y: Double, _ r: Double, _ k: Double,
                             _ jour: Bool) {
        let t = teintes
        let centre = CGPoint(x: x, y: y)
        let grand = r * PlanCiel.lueur * k
        let a = Double(t.lueurAlpha)
        c.fill(Path(ellipseIn: CGRect(x: x - grand, y: y - grand, width: 2 * grand, height: 2 * grand)),
               with: .radialGradient(Gradient(stops: [
                   Gradient.Stop(color: couleur(t.lueur, a), location: 0),
                   Gradient.Stop(color: couleur(t.lueur, a * 0.55), location: 0.35),
                   Gradient.Stop(color: couleur(t.lueur, a * 0.18), location: 0.7),
                   Gradient.Stop(color: couleur(t.lueur, 0), location: 1),
               ]), center: centre, startRadius: 0, endRadius: grand))
        let couronne = r * PlanCiel.couronne * k
        let bord = 1 / PlanCiel.couronne
        let teinte = jour ? t.couronne : t.lune
        let fort = (jour ? 140.0 : 80.0) / 255
        c.fill(Path(ellipseIn: CGRect(x: x - couronne, y: y - couronne, width: 2 * couronne, height: 2 * couronne)),
               with: .radialGradient(Gradient(stops: [
                   Gradient.Stop(color: couleur(teinte, fort), location: 0),
                   Gradient.Stop(color: couleur(teinte, fort), location: bord),
                   Gradient.Stop(color: couleur(teinte, fort / 3), location: bord + (1 - bord) * 0.45),
                   Gradient.Stop(color: couleur(teinte, 0), location: 1),
               ]), center: centre, startRadius: 0, endRadius: couronne))
    }

    /// Les rayons doux de l'heure dorée : douze pointes floues, dans la couronne, tournées de `angle` degrés.
    private func peindreRayons(_ c: GraphicsContext, _ x: Double, _ y: Double, _ r: Double, angle: Double,
                               opacite: Double) {
        let couronne = r * PlanCiel.couronne
        var k = c
        k.clip(to: Path(CGRect(x: x - couronne - 4, y: y - couronne - 4, width: 2 * couronne + 8,
                               height: 2 * couronne + 8)))
        k.opacity = min(max(opacite, 0), 1)
        k.translateBy(x: x, y: y)
        k.rotate(by: .degrees(angle))
        let teinte = couleur(teintes.couronne, 120.0 / 255)
        k.drawLayer { couche in
            couche.addFilter(.blur(radius: 1))
            var pointes = Path()
            for i in 0..<PlanCiel.rayons {
                let a = 2 * Double.pi * Double(i) / Double(PlanCiel.rayons)
                let l = i % 2 == 0 ? couronne * 0.96 : couronne * 0.78
                let large = 0.09
                pointes.move(to: CGPoint(x: r * 1.05 * cos(a - large), y: r * 1.05 * sin(a - large)))
                pointes.addLine(to: CGPoint(x: l * cos(a), y: l * sin(a)))
                pointes.addLine(to: CGPoint(x: r * 1.05 * cos(a + large), y: r * 1.05 * sin(a + large)))
                pointes.closeSubpath()
            }
            couche.fill(pointes, with: .color(teinte))
        }
    }
}

/// Ce que dessinent les deux ciels (le Jour et la carte de Sérénité) : la lune de son jour du mois, et un nuage.
enum CielDessin {

    /// La lune d'un jour du mois, à plat (PlanCiel.peindreLune) : le disque entier à peine (14 %), puis sa part
    /// éclairée, à droite quand elle croît, à gauche quand elle décroît ; le terminateur est une demi-ellipse.
    static func lune(_ c: GraphicsContext, _ cx: Double, _ cy: Double, _ r: Double, couleur: Color,
                     _ l: CielContinu.Lune) {
        let disque = CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)
        c.fill(Path(ellipseIn: disque), with: .color(couleur.opacity(PlanCiel.luneDisque)))
        guard let terminateur = PlanCiel.terminateur(l) else { return }
        let rx = r * terminateur.demiLargeur
        // Le bord éclairé, du haut au bas par la droite ; puis le terminateur, du bas au haut, bombé vers la droite
        // (croissant) ou vers la gauche (gibbeuse). Décroissante, la lune entière est retournée.
        let sens: Double = l.croissante ? 1 : -1
        var p = Path()
        let pas = 24
        for i in 0...pas {
            let a = -Double.pi / 2 + Double.pi * Double(i) / Double(pas)
            let point = CGPoint(x: cx + sens * r * cos(a), y: cy + r * sin(a))
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        for i in 0...pas {
            let a = Double.pi / 2 - Double.pi * Double(i) / Double(pas)
            let dx = terminateur.versLumiere ? rx * cos(a) : -rx * cos(a)
            p.addLine(to: CGPoint(x: cx + sens * dx, y: cy + r * sin(a)))
        }
        p.closeSubpath()
        c.fill(p, with: .color(couleur))
    }

    /// Un nuage (`forme` 0 : bombé ; 1 : long) dans `cadre`, flou, d'une seule couche à l'opacité `opacite`.
    static func nuage(_ c: GraphicsContext, forme: Int, _ cadre: CGRect, couleur: Color, opacite: Double) {
        guard opacite > 0, cadre.width > 0, cadre.height > 0 else { return }
        var k = c
        k.clip(to: Path(cadre.insetBy(dx: -12, dy: -12)))
        k.opacity = min(opacite, 1)
        k.drawLayer { couche in
            couche.addFilter(.blur(radius: flou))
            var p = Path()
            for o in (forme == 0 ? PlanCiel.formeNuage : PlanCiel.formeVoile) {
                p.addEllipse(in: CGRect(x: cadre.minX + (o.cx - o.rx) * cadre.width,
                                        y: cadre.minY + (o.cy - o.ry) * cadre.height,
                                        width: 2 * o.rx * cadre.width, height: 2 * o.ry * cadre.height))
            }
            couche.fill(p, with: .color(couleur))
        }
    }

    /// Le flou des nuages, en points : celui du masque d'Android (5 dp de rayon, soit un écart type de 3 dp environ).
    static let flou = 3.3
}
