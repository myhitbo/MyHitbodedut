import Ecrans
import Foundation

/// La musique et l'ambiance de la séance (le `MusicPlayer` et l'`AmbiancePlayer` du service d'Android) : le
/// `MusiqueLecteur` partagé de l'app a déjà les trois membres que `SeanceEnCours` demande (SeanceEnCours.swift).
/// `@retroactive` : le type et le protocole sont tous deux d'Ecrans, la conformité est posée par l'app.
extension MusiqueLecteur: @retroactive SeanceMusique {}

/// Ce que fait `SessionService.musicChanged` quand l'interrupteur de la musique bouge sur le panneau des textes :
/// la séance en cours suit le réglage, par le `MusiqueLecteur` partagé (`musiqueChangee`, qui ne fait rien hors
/// séance).
@MainActor
final class SystemeSignalMusique: TextesSignalMusique {

    private let lecteur: MusiqueLecteur

    init(lecteur: MusiqueLecteur) {
        self.lecteur = lecteur
    }

    func musiqueChangee() async {
        await lecteur.musiqueChangee()
    }
}
