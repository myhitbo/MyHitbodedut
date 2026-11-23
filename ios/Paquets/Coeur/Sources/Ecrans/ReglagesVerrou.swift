import Foundation
import Coeur

// Ce que les réglages font du verrou du journal (SettingsActivity.renderVerrou, l'export) et de la minuterie système
// (propre à iOS) : les deux modèles sont tenus à part (VerrouJournal.swift, MinuterieSeance.swift), l'écran des
// réglages les reçoit de l'app.

extension ReglagesModele {

    /// « Exporter » emporte tout le journal : le verrou le garde aussi (revue du 15/11). Vrai si l'export peut partir ;
    /// sans verrou actif, tout de suite.
    public func exportAutorise() async -> Bool {
        guard let verrouJournal else { return true }
        return await verrouJournal.exiger()
    }

    /// L'interrupteur du verrou du journal posé par la vue : le message éventuel (« Réglez d'abord un verrouillage
    /// d'écran sur ce téléphone. ») passe par celui de l'écran.
    public func poserVerrouJournal(_ actif: Bool) async {
        // Une écriture refusée ne dit rien, comme les autres interrupteurs : il reste où il était.
        guard let verrouJournal, let dire = try? await verrouJournal.basculer(actif) else { return }
        annoncer(dire)
    }

    /// L'interrupteur de la minuterie système posé par la vue.
    public func poserMinuterie(_ actif: Bool) async {
        guard let minuterie, let dire = try? await minuterie.basculer(actif) else { return }
        annoncer(dire)
    }
}
