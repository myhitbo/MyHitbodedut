import Foundation
import Testing
@testable import Coeur

/// PaysageCielTest d'Android, porté pour ce qui n'est pas du dessin : le paysage de la carte de Sérénité suit le ciel
/// continu (24/11, `PaysageCiel`) — les quatre ciels peints d'avant mêlés sans à-coup selon la hauteur du soleil,
/// l'astre sur son arc, les étoiles du crépuscule, le nuage seulement quand le ciel en porte.
@Suite("Paysage du ciel")
struct PaysageCielTests {

    @Test func lesQuatreCielsDAvantSeMelentSansACoup() {
        for matin in [true, false] {
            var avant = PaysageCiel.poidsDesCiels(-30, matin: matin)
            var e = -30.0
            while e <= 60 {
                let p = PaysageCiel.poidsDesCiels(e, matin: matin)
                #expect(abs(p.reduce(0, +) - 1) < 1e-9)
                #expect(p.indices.allSatisfy { abs(p[$0] - avant[$0]) <= 0.03 }, "saut à \(e)° : \(avant) → \(p)")
                avant = p
                e += 0.25
            }
        }
        // Le matin passe par l'aube, le soir par le coucher.
        #expect(abs(PaysageCiel.poidsDesCiels(0, matin: true)[1] - 1) < 1e-9)
        #expect(abs(PaysageCiel.poidsDesCiels(0, matin: false)[3] - 1) < 1e-9)
        #expect(abs(PaysageCiel.poidsDesCiels(-20, matin: true)[0] - 1) < 1e-9)
        #expect(abs(PaysageCiel.poidsDesCiels(30, matin: false)[2] - 1) < 1e-9)
        // Autour de midi, le matin et le soir mêlés.
        let midi = PaysageCiel.poidsDesCiels(5, matin: 0.5)
        #expect(abs(midi.reduce(0, +) - 1) < 1e-9 && midi[1] > 0 && midi[3] > 0)
    }

    @Test func lesCouleursDAvantAuxQuatreMoments() {
        // En plein jour, le ciel peint du jour, au pixel près ; en pleine nuit, celui de la nuit.
        let jour = PaysageCiel(etat: CielDuJour.etat(heure: 12.5))
        #expect(jour.couleurs.first == 0xFF4F86C6 && jour.couleurs.last == 0xFFF4E6CB)
        #expect(jour.nuit == 0 && jour.estSoleil && jour.eclatEtoiles == 0)
        let nuit = PaysageCiel(etat: CielDuJour.etat(heure: 0.5))
        #expect(nuit.couleurs.first == 0xFF0B0A1F && nuit.couleurs.last == 0xFF4E3486)
        #expect(nuit.nuit == 1 && !nuit.estSoleil && nuit.eclatEtoiles == 1)
        // Sans arc (l'astre aux places d'avant), toujours là ; avec, il paraît et s'efface à l'horizon.
        #expect(nuit.astreVisible == 1)
        let aube = PaysageCiel(etat: CielDuJour.etat(heure: 6.3), arc: true)
        #expect(aube.astreVisible < 1)
    }

    @Test func lAstreSuitSonArcDeGaucheADroite() {
        var x = -1.0
        for m in stride(from: 6 * 60 + 40, through: 18 * 60 + 20, by: 10) {
            let p = PaysageCiel(etat: CielDuJour.etat(heure: Double(m) / 60), nuages: true, arc: true)
            let place = p.astrePlace(largeur: 360, hauteur: 380)
            #expect(place.x >= x && place.x >= 0.12 * 360 - 1e-9 && place.x <= 0.88 * 360 + 1e-9)
            #expect(place.y >= 0.24 * 380 - 1e-9 && place.y <= 0.56 * 380 + 1e-9 && place.rayon <= 26)
            x = place.x
        }
        // Le nuage de Sérénité : le jour, pas en pleine nuit, et jamais sans `nuages`.
        #expect(PaysageCiel(etat: CielDuJour.etat(heure: 12), nuages: true, arc: true).avecNuage)
        #expect(!PaysageCiel(etat: CielDuJour.etat(heure: 0.5), nuages: true, arc: true).avecNuage)
        #expect(!PaysageCiel(etat: CielDuJour.etat(heure: 12)).avecNuage)
    }

    @Test func quaranteEtoilesToujoursLesMemes() {
        #expect(PaysageCiel.etoiles.count == 40 && PaysageCiel.rythmes.count == 40 * CielVivant.champs)
        #expect(PaysageCiel.etoiles.allSatisfy { $0.y <= 0.55 && $0.taille >= 1 && $0.taille <= 2.6 })
        // java.util.Random(29), comme Android : la première étoile.
        #expect(PaysageCiel.etoiles[0].x == 0.7312365)
    }
}
