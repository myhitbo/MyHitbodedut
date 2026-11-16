import Coeur
import Ecrans
import Foundation
import SwiftUI
import Vues

/// Le point d'entrée de l'app (MyHitbodedutApp.kt, PORTAGE.md § 1.1) : il construit ce que les écrans reçoivent
/// (le magasin du journal et des réglages, l'horloge, le traducteur, les contenus, la palette) et montre les cinq
/// onglets (Racine.swift). Seul ce point d'entrée lit le paquet de l'app (`Bundle.main`) : les modèles d'écran
/// reçoivent ce qu'il en tire.
@main
struct MyHitbodedutApp: App {
    @State private var magasin: Magasin
    @State private var zmanim: ZmanimModele
    @State private var onglet: Onglet
    private let traducteur: Traducteur
    private let palettes: Palettes?
    /// Les contenus exportés (Contenu/ du paquet), lus à la demande : les écrans à venir le recevront.
    private let contenus: ContenusApp

    init() {
        let paquet = Bundle.main.bundleURL
        // UIAppFonts les a déjà fait connaître du système ; l'enregistrement explicite couvre le reste (un
        // Info.plist incomplet) et dit ce qui manque. Un échec n'arrête rien : le texte prend alors la police du
        // téléphone.
        Polices.enregistrer(dossier: paquet.appending(path: "Polices"))

        // POUR L'INSTANT, une persistance en mémoire : le journal et les réglages ne survivent pas à la fermeture
        // de l'app. Les fichiers du groupe d'apps (l'acteur Depot de Coeur, PORTAGE.md § 3.2) la remplaceront
        // quand leur adaptateur sera écrit.
        let magasin = Magasin.enMemoire()
        let horloge = HorlogeSysteme()

        let lecteur = ContenusApp.lecteur(dossier: paquet.appending(path: "Contenu"))
        contenus = ContenusApp(lecteur: lecteur)
        // La palette est lue dès le lancement, d'un seul fichier, pour que le premier écran ait déjà ses couleurs.
        palettes = (try? lecteur("palettes.json")).flatMap { try? Palettes.lire($0) }
        traducteur = MyHitbodedutApp.traducteur(paquet: paquet)

        _magasin = State(initialValue: magasin)
        _zmanim = State(initialValue: ZmanimModele(magasin: magasin, horloge: horloge))
        _onglet = State(initialValue: Onglet.initial(magasin.reglages))
    }

    var body: some Scene {
        WindowGroup {
            Racine(magasin: magasin, palettes: palettes, zmanim: zmanim, onglet: $onglet)
                .environment(\.traducteur, traducteur)
        }
    }

    /// Le traducteur des `Libelle`, dans la langue que iOS a choisie pour l'app parmi fr, en et he (réglage de
    /// langue par app, PORTAGE.md § 2.2.7) ; il lit le catalogue copié tel quel sous Chaines/. Sans catalogue
    /// lisible, chaque libellé montre sa clé : ce qui se voit, au lieu de se taire.
    private static func traducteur(paquet: URL) -> Traducteur {
        let langue = Bundle.main.preferredLocalizations.first ?? "en"
        let fichier = paquet.appending(path: "Chaines/Localizable.xcstrings")
        if let catalogue = try? Data(contentsOf: fichier),
           let traducteur = try? Traducteur(catalogue: catalogue, langue: langue) {
            return traducteur
        }
        return Traducteur(langue: langue, simples: [:])
    }
}
