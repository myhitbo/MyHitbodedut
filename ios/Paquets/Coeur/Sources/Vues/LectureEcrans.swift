import Foundation
import SwiftUI
import Coeur
import Ecrans

// Les écrans du siddour et du lecteur avec leur modèle, gardé le temps de l'écran (`@State`) : de quoi les poser
// tels quels dans une `navigationDestination` ou une `.sheet`, où l'app ne garde pas le modèle elle-même. Le
// modèle se construit à la première apparition de l'écran ; les constructions suivantes (l'écran parent qui se
// redessine) sont laissées, sans rien lire.

/// La liste du siddour (l'entrée Siddour de l'onglet Textes).
public struct SiddourEcran: View {
    @State private var modele: SiddourModele
    private let ouvrir: @MainActor (LectureRoute) -> Void

    public init(magasin: Magasin, contenus: ContenusApp, horloge: any Horloge, langue: String,
                ouvrir: @escaping @MainActor (LectureRoute) -> Void) {
        _modele = State(initialValue: SiddourModele(magasin: magasin, contenus: contenus, horloge: horloge,
                                                    langue: langue))
        self.ouvrir = ouvrir
    }

    public var body: some View {
        SiddourVue(modele: modele, ouvrir: ouvrir)
    }
}

/// Le lecteur d'un texte : `LectureRoute.lecture(cible)`.
public struct LectureEcran: View {
    @State private var modele: LectureModele
    private let ouvrir: @MainActor (LectureRoute) -> Void

    public init(magasin: Magasin, contenus: ContenusApp, horloge: any Horloge, langue: String, cible: LectureCible,
                ouvrir: @escaping @MainActor (LectureRoute) -> Void) {
        _modele = State(initialValue: LectureModele(magasin: magasin, contenus: contenus, horloge: horloge,
                                                    langue: langue, cible: cible))
        self.ouvrir = ouvrir
    }

    public var body: some View {
        LectureVue(modele: modele, ouvrir: ouvrir)
    }
}

/// La feuille des marque-pages : `LectureRoute.marquesPages(recueil:)`, à présenter en `.sheet`.
public struct LectureMarquesEcran: View {
    @State private var modele: LectureMarquesModele
    private let magasin: Magasin
    private let ouvrir: @MainActor (LectureRoute) -> Void

    public init(magasin: Magasin, contenus: ContenusApp, recueil: String?,
                ouvrir: @escaping @MainActor (LectureRoute) -> Void) {
        _modele = State(initialValue: LectureMarquesModele(magasin: magasin, contenus: contenus, recueil: recueil))
        self.magasin = magasin
        self.ouvrir = ouvrir
    }

    public var body: some View {
        LectureMarquesVue(modele: modele, police: LecturePreferences.police(magasin.reglages), ouvrir: ouvrir)
    }
}
