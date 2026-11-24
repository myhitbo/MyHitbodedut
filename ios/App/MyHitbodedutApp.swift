import Coeur
import Ecrans
import Foundation
import SwiftUI
import Vues

/// Le point d'entrée de l'app (MyHitbodedutApp.kt, PORTAGE.md § 1.1). Il lit ce qui ne dépend pas du journal (le
/// traducteur, la palette, les contenus, les polices) et se pose en délégué des notifications dès le lancement ;
/// le magasin du journal et des réglages se lit ensuite sur ses fichiers (`Lancement.charger`), une vue d'attente
/// à l'écran le temps de cette lecture. Tout ce que les écrans partagent est construit une fois, dans
/// `PartageApp`, et la racine (Racine.swift) montre les cinq onglets.
@main
struct MyHitbodedutApp: App {
    @State private var lancement: Lancement

    init() {
        _lancement = State(initialValue: Lancement(paquet: Bundle.main.bundleURL))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let app = lancement.app {
                    Racine(app: app)
                } else {
                    Attente()
                }
            }
            .environment(\.traducteur, lancement.traducteur)
            .onOpenURL { url in lancement.recevoir(url) }
            .task { await lancement.charger() }
        }
    }
}

/// Ce que l'app sait avant d'avoir lu le journal, puis, une fois lu, tous les objets partagés (`app`).
///
/// Ce point d'entrée lit le paquet de l'app (`Bundle.main`) ; les modèles d'écran reçoivent ce qu'il en tire.
@MainActor
@Observable
final class Lancement {

    /// Le traducteur des `Libelle`, posé dans l'environnement dès la vue d'attente.
    let traducteur: Traducteur
    /// Les objets partagés de l'app, nil tant que le magasin n'est pas lu.
    private(set) var app: PartageApp?

    private let paquet: URL
    private let palettes: Palettes?
    private let lecteur: ContenusApp.Lecteur
    private let contenus: ContenusApp
    /// Le délégué du centre de notifications : posé avant tout, iOS pouvant rendre le toucher qui a lancé l'app
    /// avant que l'interface soit prête ; il garde les réponses jusqu'au branchement (`PartageApp.demarrer`).
    private let reponses: SystemeReponsesNotifications
    @ObservationIgnored private var enCours = false
    /// Un lien reçu avant que le magasin soit lu (le toucher du widget qui lance l'app) : ouvert dès qu'il l'est.
    @ObservationIgnored private var lienEnAttente: LienApp?

    init(paquet: URL) {
        self.paquet = paquet
        // UIAppFonts les a déjà fait connaître du système ; l'enregistrement explicite couvre le reste (un
        // Info.plist incomplet) et dit ce qui manque. Un échec n'arrête rien : le texte prend alors la police du
        // téléphone.
        Polices.enregistrer(dossier: paquet.appending(path: "Polices"))
        reponses = SystemeReponsesNotifications()
        let lecteur = ContenusApp.lecteur(dossier: paquet.appending(path: "Contenu"))
        self.lecteur = lecteur
        contenus = ContenusApp(lecteur: lecteur)
        // La palette est lue dès le lancement, d'un seul fichier, pour que le premier écran ait déjà ses couleurs.
        palettes = (try? lecteur("palettes.json")).flatMap { try? Palettes.lire($0) }
        traducteur = Lancement.traducteur(paquet: paquet)
    }

    /// Lit le magasin sur ses fichiers (`ServicesApp.chargerMagasin`), puis construit les objets partagés et
    /// branche ce qui tourne en fond. Une seule fois, même si la scène se recrée.
    func charger() async {
        guard app == nil, !enCours else { return }
        enCours = true
        let charge = await ServicesApp.chargerMagasin()
        let partage = PartageApp(magasin: charge.magasin, enMemoire: charge.enMemoire, traducteur: traducteur,
                                 palettes: palettes, contenus: contenus, lecteur: lecteur, paquet: paquet)
        app = partage
        // Le filtre de mode de concentration écrit son choix dans ce magasin (App/ConcentrationFiltreIntention.swift).
        ConcentrationRelais.magasin = charge.magasin
        partage.demarrer(reponses: reponses)
        if let lien = lienEnAttente {
            lienEnAttente = nil
            partage.ouvrir(lien)
        }
    }

    /// Un lien profond (`myhitbodedut://…`, LienApp) : ouvert tout de suite, ou dès que l'app est prête.
    func recevoir(_ url: URL) {
        guard let lien = LienApp(url) else { return }
        if let app {
            app.ouvrir(lien)
        } else {
            lienEnAttente = lien
        }
    }

    /// Le traducteur des `Libelle`, dans la langue que iOS a choisie pour l'app parmi fr, en et he (réglage de
    /// langue par app, PORTAGE.md § 2.2.7). Il lit le catalogue d'Android copié tel quel sous Chaines/, et y
    /// ajoute les chaînes propres à iOS (Chaines/ios.xcstrings) : les modèles en nomment quelques-unes
    /// (action_ok, reglages_icone…). En cas de doublon, la chaîne d'Android l'emporte. Sans catalogue lisible,
    /// chaque libellé montre sa clé : ce qui se voit, au lieu de se taire.
    private static func traducteur(paquet: URL) -> Traducteur {
        let langue = Bundle.main.preferredLocalizations.first ?? "en"
        let chaines = paquet.appending(path: "Chaines")
        let fichiers = [chaines.appending(path: "Localizable.xcstrings"), chaines.appending(path: "ios.xcstrings")]
        if let catalogue = catalogueFusionne(fichiers),
           let traducteur = try? Traducteur(catalogue: catalogue, langue: langue) {
            return traducteur
        }
        return Traducteur(langue: langue, simples: [:])
    }

    /// Les entrées `strings` de plusieurs catalogues réunies en un seul JSON de catalogue ; la première
    /// occurrence d'une clé l'emporte. nil si aucun ne se lit.
    private static func catalogueFusionne(_ fichiers: [URL]) -> Data? {
        var entrees: [String: Any] = [:]
        for fichier in fichiers {
            guard let donnees = try? Data(contentsOf: fichier),
                  let objet = try? JSONSerialization.jsonObject(with: donnees) as? [String: Any],
                  let chaines = objet["strings"] as? [String: Any] else { continue }
            entrees.merge(chaines) { premiere, _ in premiere }
        }
        guard !entrees.isEmpty else { return nil }
        return try? JSONSerialization.data(withJSONObject: ["strings": entrees])
    }
}

/// L'écran du lancement, le temps de lire le journal et les réglages : le fond de l'app et une roue.
struct Attente: View {
    var body: some View {
        ProgressView()
            .accessibilityLabel(Text("ios_chargement", tableName: "ios"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Teinte(.paper))
    }
}
