import Coeur
import Ecrans
import Foundation
import SwiftUI
import Vues

/// Le point d'entrée de l'app (MyHitbodedutApp.kt, PORTAGE.md § 1.1) : il lit ce qui se lit d'un coup dans le paquet de
/// l'app (le traducteur, la palette, les formes des trophées), puis le journal et les réglages sur les fichiers du
/// dossier de l'app (`ModelesApp.charger`), et montre les trois onglets (Racine.swift). Ce point d'entrée lit le
/// paquet de l'app (`Bundle.main`), et seule `Illustration` de Vues y prend encore ses images : les modèles d'écran
/// reçoivent ce qu'il en tire.
@main
struct MyHitbodedutApp: App {
    /// Le délégué des notifications, posé dès le lancement : une notification touchée qui lance l'app ne se perd pas.
    @UIApplicationDelegateAdaptor(DelegueApp.self) private var delegue
    @State private var modeles: ModelesApp? = nil
    private let paquet: URL
    private let traducteur: Traducteur
    private let palettes: Palettes?
    private let formes: TropheeFormes?

    init() {
        let paquet = Bundle.main.bundleURL
        self.paquet = paquet
        // UIAppFonts les a déjà fait connaître du système ; l'enregistrement explicite couvre le reste (un
        // Info.plist incomplet) et dit ce qui manque. Un échec n'arrête rien : le texte prend alors la police du
        // téléphone.
        Polices.enregistrer(dossier: paquet.appending(path: "Polices"))
        let lecteur = ContenusApp.lecteur(dossier: paquet.appending(path: "Contenu"))
        // La palette est lue dès le lancement, d'un seul fichier, pour que le premier écran ait déjà ses couleurs ; les
        // formes des trophées aussi, que toutes les vues d'un trophée dessinent.
        palettes = (try? lecteur("palettes.json")).flatMap { try? Palettes.lire($0) }
        formes = try? TropheeFormes.lire(lecteur)
        traducteur = MyHitbodedutApp.traducteur(paquet: paquet)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let modeles {
                    Racine(app: modeles, palettes: palettes)
                } else {
                    // Le temps de lire deux petits fichiers : la couleur de fond d'origine, sans rien faire semblant.
                    Color(PaletteApp.origine.couleur(.paper, nuit: false))
                        .ignoresSafeArea()
                }
            }
            .task {
                if modeles == nil {
                    modeles = await ModelesApp.charger(paquet: paquet, traducteur: traducteur)
                }
            }
            .environment(\.traducteur, traducteur)
            .environment(\.tropheeFormes, formes)
            // La langue de l'app pour les Text(« clé ») du catalogue compilé, et son sens d'écriture : l'hébreu
            // et l'arabe de Tunisie se lisent de droite à gauche.
            .environment(\.locale, Locale(identifier: Traducteur.identifiantLocale(traducteur.langue)))
            .environment(\.layoutDirection,
                         Traducteur.deDroiteAGauche(traducteur.langue) ? .rightToLeft : .leftToRight)
        }
        // Le rafraîchissement que iOS accorde en arrière-plan, sans garantie : les notifications des dix jours
        // suivants et les widgets (PORTAGE.md § 2.2.2, BootReceiver).
        .backgroundTask(.appRefresh(ReplanificationFond.identifiant)) { [modeles, paquet, traducteur] in
            await ReplanificationFond.executer(modeles: modeles, paquet: paquet, traducteur: traducteur)
        }
    }

    /// Le traducteur des `Libelle`, dans la langue de l'app : la première des langues préférées que l'app livre (la
    /// langue choisie pour l'app dans les Réglages d'iOS vient en tête, PORTAGE.md § 2.2.7), parmi fr, en, he, es
    /// et l'arabe de Tunisie seulement ; sinon l'anglais (Traducteur.langueDuTelephone, LangueApp d'Android). Il
    /// lit les catalogues copiés tels quels sous Chaines/ : celui d'Android, puis celui des chaînes propres à iOS.
    /// Sans catalogue lisible, chaque libellé montre sa clé : ce qui se voit, au lieu de se taire.
    static func traducteur(paquet: URL) -> Traducteur {
        let langue = Traducteur.langueDuTelephone(Locale.preferredLanguages)
        let chaines = paquet.appending(path: "Chaines")
        let catalogues = ["Localizable.xcstrings", "ios.xcstrings"].compactMap { nom in
            try? Data(contentsOf: chaines.appending(path: nom))
        }
        if let traducteur = try? Traducteur(catalogues: catalogues, langue: langue) {
            return traducteur
        }
        return Traducteur(langue: langue, simples: [:])
    }
}
