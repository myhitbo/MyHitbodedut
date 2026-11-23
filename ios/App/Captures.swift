import Coeur
import Ecrans
import Foundation
import SwiftUI

/// Les captures d'écran de la CI (`.github/workflows/ios-captures.yml`, ECRANS.md « Les captures ») : lancée avec
/// « -capture <écran> », l'app s'ouvre d'elle-même sur cet écran ; avec « -captureDemo », sur le journal de
/// démonstration (`Demonstration` d'Ecrans), tenu en mémoire, sans rien lire ni écrire dans les fichiers de l'app.
/// Sans ces arguments de lancement, rien ne change : l'app ne passe ici que par deux crochets, l'un dans
/// `ModelesApp.charger` (le magasin), l'autre dans `Racine` (l'écran ouvert au lancement).
enum Captures {

    /// L'écran demandé par « -capture <écran> » ; nil sans l'argument.
    static let ecran: String? = valeur(apres: "-capture")
    /// « -captureDemo » : le journal et les réglages de démonstration.
    static let demo = ProcessInfo.processInfo.arguments.contains("-captureDemo")

    /// Les écrans que la CI sait demander, dans l'ordre de ses captures (ios-captures.yml les reprend).
    static let ecrans = [
        "presentation", "jour", "depart", "seance", "bravo", "note", "livres", "siddour", "lecteur", "livre", "tehilim",
        "tikkun", "tefilot", "bibliotheque", "halakha", "hilloulot", "recherche", "chizuk", "conseils", "chemin",
        "journal", "parcours", "trophees", "reglages", "version", "zmanim", "vol", "musique",
    ]

    private static func valeur(apres argument: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let i = arguments.firstIndex(of: argument), arguments.indices.contains(i + 1) else { return nil }
        return arguments[i + 1]
    }

    /// Le magasin de démonstration, en mémoire ; nil hors des captures (l'app lit alors ses fichiers).
    @MainActor
    static func magasinDemo(paquet: URL, langue: String) async -> Magasin? {
        guard demo else { return nil }
        let horloge = HorlogeSysteme()
        let contenus = ContenusApp(lecteur: ContenusApp.lecteur(dossier: paquet.appending(path: "Contenu")))
        let villes = (try? await contenus.villes()) ?? []
        let enregistrement = Demonstration.enregistrement(aujourdhui: horloge.aujourdhui, maintenant: horloge.maintenant,
                                                          fuseau: horloge.fuseau.identifiant, langue: langue,
                                                          villes: villes)
        return Magasin.enMemoire(enregistrement)
    }

    /// Ouvre l'écran demandé, une fois la racine posée : l'onglet, puis la pile, puis la feuille par-dessus. Les
    /// pauses laissent à SwiftUI le temps de montrer l'onglet avant d'y pousser un écran. Sans « -capture », rien.
    @MainActor
    static func ouvrir(_ app: ModelesApp, onglet: Binding<Onglet>, jour: Binding<NavigationPath>,
                       livres: Binding<NavigationPath>, chemin: Binding<NavigationPath>,
                       feuille: Binding<Pardessus?>, plein: Binding<Pardessus?>) async {
        guard let ecran else { return }
        let aujourdhui = app.horloge.aujourdhui
        // L'onglet, et ce qui s'ouvre au-dessus de lui.
        let depart: (Onglet, [Ecran], Pardessus?, Pardessus?)
        switch ecran {
        case "presentation": depart = (.aujourdhui, [], nil, .presentation)
        case "depart": depart = (.aujourdhui, [], nil, nil)
        case "seance": depart = (.aujourdhui, [.seance(demarrer: true)], nil, nil)
        case "bravo":
            depart = (.aujourdhui, [], nil, .celebration(CelebrationDemande(minutes: 20, dateNote: aujourdhui)))
        case "note": depart = (.aujourdhui, [], .note(aujourdhui.plus(jours: -1)), nil)
        case "reglages": depart = (.aujourdhui, [.reglages(carteBarriere: false)], nil, nil)
        case "version": depart = (.aujourdhui, [.reglages(carteBarriere: false), .choixVersion], nil, nil)
        case "zmanim": depart = (.aujourdhui, [.zmanim], nil, nil)
        case "vol": depart = (.aujourdhui, [.zmanim, .vol], nil, nil)
        case "musique": depart = (.aujourdhui, [.musique], nil, nil)
        case "livres": depart = (.textes, [], nil, nil)
        case "siddour": depart = (.textes, [.siddour], nil, nil)
        case "lecteur": depart = (.textes, [.siddour, .lecture(.siddour("chaharit"))], nil, nil)
        case "livre": depart = (.textes, [.lecture(.livre("likoutei_moharan"))], nil, nil)
        case "tehilim": depart = (.textes, [.tehilim], nil, nil)
        case "tikkun": depart = (.textes, [.tikkun], nil, nil)
        case "tefilot": depart = (.textes, [.tefilot], nil, nil)
        case "bibliotheque": depart = (.textes, [.bibliotheque(livresSeuls: false)], nil, nil)
        case "halakha": depart = (.textes, [.halakha(recherche: nil)], nil, nil)
        case "hilloulot": depart = (.textes, [.hilloulot(recherche: nil)], nil, nil)
        case "recherche": depart = (.textes, [.recherche], nil, nil)
        case "chizuk": depart = (.textes, [.chizuk], nil, nil)
        case "conseils": depart = (.textes, [.conseils], nil, nil)
        case "chemin": depart = (.chemin, [], nil, nil)
        case "journal": depart = (.chemin, [.journal], nil, nil)
        case "parcours": depart = (.chemin, [.parcours], nil, nil)
        case "trophees": depart = (.chemin, [.paliers], nil, nil)
        default: depart = (.aujourdhui, [], nil, nil)
        }
        let (quel, ecrans, enFeuille, enPlein) = depart
        onglet.wrappedValue = quel
        try? await Task.sleep(for: .milliseconds(400))
        for suivant in ecrans {
            switch quel {
            case .aujourdhui: jour.wrappedValue.append(suivant)
            case .textes: livres.wrappedValue.append(suivant)
            case .chemin: chemin.wrappedValue.append(suivant)
            }
            try? await Task.sleep(for: .milliseconds(300))
        }
        if ecran == "depart" { app.accueil.basculerVolet() }
        if let enFeuille { feuille.wrappedValue = enFeuille }
        if let enPlein { plein.wrappedValue = enPlein }
    }
}
