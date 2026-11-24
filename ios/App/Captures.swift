import Coeur
import Ecrans
import Foundation
import SwiftUI
import UIKit

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
        "presentation", "jour", "depart", "seance", "bravo", "note", "livres", "siddour", "lecteur", "livre",
        "chapitres", "tehilim", "tikkun", "tefilot", "bibliotheque", "source", "halakha", "hilloulot", "recherche",
        "chizuk", "conseils", "chemin", "journal", "parcours", "trophees", "reglages", "version", "zmanim", "vol",
        "musique", "apercu", "applications", "dedicace", "journal-barriere", "serenite", "bento", "pile", "fete",
        "bilan", "calendrier", "boussole", "rappels", "ajout-temps",
    ]

    /// Un écran de lecture suivi de « -barre » (« halakha-barre », « source-barre », « lecteur-barre »…) : le même,
    /// sa barre de lecture dépliée (A−, %, A+, …, le défilement automatique) au lieu de la pastille « Aa ». Pas dans
    /// `ecrans` : à demander à la main (ios-captures.yml, l'entrée « ecrans »).
    static let suffixeBarre = "-barre"

    /// Le ciel du Jour à heure fixe (24/11, CielPageVue) : « ciel-m+03 » ouvre le Jour, « serenite-m+03 » l'accueil
    /// Sérénité, le soleil à la hauteur que nomme la clé, sans lieu (le soleil moyen de `Soleil.parHeure`, levé à
    /// 6 h 30, couché à 18 h 30) — les heures des captures d'Android (captures.py, étape 35) : le matin (m) puis le
    /// soir (s), de −20° à +40°. « ciel-0644 » : une heure quelconque, en quatre chiffres. Pas dans `ecrans` : à
    /// demander à la main (ios-captures.yml, l'entrée « ecrans »).
    static let heuresDuCiel: [String: String] = [
        "m-20": "0456", "m-12": "0534", "m-04": "0612", "m+00": "0630", "m+03": "0644", "m+10": "0716",
        "m+40": "1002", "s+40": "1458", "s+10": "1744", "s+03": "1816", "s+00": "1830", "s-04": "1848",
        "s-12": "1926", "s-20": "2004",
    ]

    /// L'écran d'une capture du ciel (« ciel-m+03 » : le Jour, « serenite-m+03 » : Sérénité) et l'heure décimale de
    /// son soleil ; nil pour les autres.
    static func cielAHeure(_ demande: String) -> (ecran: String, heure: Double)? {
        for (prefixe, ecran) in [("ciel-", "jour"), ("serenite-", "serenite")] where demande.hasPrefix(prefixe) {
            let cle = String(demande.dropFirst(prefixe.count))
            let chiffres = heuresDuCiel[cle] ?? cle
            guard chiffres.count == 4, let hhmm = Int(chiffres) else { return nil }
            return (ecran, Double(hhmm / 100) + Double(hhmm % 100) / 60)
        }
        return nil
    }

    /// Le plus long livre que le lecteur ouvre : le Kitsour Yalkout Yossef, 1 048 chapitres, 14 390 blocs, 11,5 Mo
    /// de JSON (le Likoutei Moharan : 411 chapitres, 7 057 blocs ; PORTAGE.md § 2.2.9), d'une seule liste paresseuse.
    static let plusLongLivre = "yalkut_yosef_kitsour"

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
        var enregistrement = Demonstration.enregistrement(aujourdhui: horloge.aujourdhui, maintenant: horloge.maintenant,
                                                          fuseau: horloge.fuseau.identifiant, langue: langue,
                                                          villes: villes)
        switch ecran {
        case "fete":
            // La fête des trophées neufs au Jour : le dernier trophée gagné n'a pas encore été vu.
            enregistrement = Demonstration.avecTropheeNeuf(enregistrement, aujourdhui: horloge.aujourdhui,
                                                           fuseau: horloge.fuseau.identifiant)
        case "bilan":
            // Le bilan de la semaine passée, pas encore lu.
            enregistrement.reglages.setBilanVu("")
        case let autre?:
            // Les autres accueils (Sérénité, Bento, Pile) : la version choisie ; Sérénité aussi pour son ciel à heure
            // fixe (« serenite-m+03 »).
            let version = cielAHeure(autre)?.ecran ?? autre
            if let version = VersionApp(rawValue: version) { enregistrement.reglages.setVersionApp(version) }
        case nil:
            break
        }
        return Magasin.enMemoire(enregistrement)
    }

    /// Ouvre l'écran demandé, une fois la racine posée : l'onglet, puis la pile, puis la feuille par-dessus, sans
    /// animation (l'écran est photographié tel qu'il est, pas au milieu d'une transition). Les pauses laissent à
    /// SwiftUI le temps de montrer l'onglet avant d'y pousser un écran. Puis l'app écrit « CAPTURE PRETE » sur sa
    /// sortie d'erreur, que le script attend avant de photographier. Sans « -capture », rien.
    @MainActor
    static func ouvrir(_ app: ModelesApp, onglet: Binding<Onglet>, jour: Binding<NavigationPath>,
                       livres: Binding<NavigationPath>, chemin: Binding<NavigationPath>,
                       feuille: Binding<Pardessus?>, plein: Binding<Pardessus?>) async {
        // Les mesures du lancement (« -mesures », Mesures.swift), dès l'apparition de la racine ; sans, rien.
        Mesures.lancement(app)
        guard let demande = Captures.ecran else { return }
        UIView.setAnimationsEnabled(false)
        // « -barre » : la barre de lecture dépliée dès l'ouverture (LectureCaptures).
        var ecran = demande.hasSuffix(suffixeBarre) ? String(demande.dropLast(suffixeBarre.count)) : demande
        // Le ciel à heure fixe : le Jour ou Sérénité, le soleil moyen de l'heure de la clé.
        if let ciel = cielAHeure(ecran) {
            ecran = ciel.ecran
            app.accueil.heureDuCiel = ciel.heure
            app.accueilVersion.heureDuCiel = ciel.heure
        }
        LectureCaptures.barreDepliee = demande.hasSuffix(suffixeBarre)
        // La liste des chapitres du plus long livre, ouverte (FLECTURE-03).
        LectureCaptures.chapitresOuverts = ecran == "chapitres"
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
        // La liste filtrable des 1 048 chapitres du plus long livre, ouverte par-dessus le livre.
        case "chapitres": depart = (.textes, [.lecture(.livre(plusLongLivre))], nil, nil)
        // Le défilement mesuré du plus long livre (MesuresTests, tâche 29) ; pas dans `ecrans` : rien à photographier
        // de plus que « livre ».
        case "plus-long-livre": depart = (.textes, [.lecture(.livre(plusLongLivre))], nil, nil)
        case "tehilim": depart = (.textes, [.tehilim], nil, nil)
        case "tikkun": depart = (.textes, [.tikkun], nil, nil)
        case "tefilot": depart = (.textes, [.tefilot], nil, nil)
        case "bibliotheque": depart = (.textes, [.bibliotheque(livresSeuls: false)], nil, nil)
        // Une source de la bibliothèque (Likoutei Moharan II, 25), son texte et son bouton de lecture.
        case "source": depart = (.textes, [.bibliotheque(livresSeuls: false), .entree("src-lm2-25")], nil, nil)
        case "halakha": depart = (.textes, [.halakha(recherche: nil)], nil, nil)
        case "hilloulot": depart = (.textes, [.hilloulot(recherche: nil)], nil, nil)
        case "recherche": depart = (.textes, [.recherche], nil, nil)
        case "chizuk": depart = (.textes, [.chizuk], nil, nil)
        case "conseils": depart = (.textes, [.conseils], nil, nil)
        case "chemin": depart = (.chemin, [], nil, nil)
        case "journal": depart = (.chemin, [.journal], nil, nil)
        case "parcours": depart = (.chemin, [.parcours], nil, nil)
        case "trophees": depart = (.chemin, [.paliers], nil, nil)
        // Le ciel (tâches 24 et 25) : le calendrier et la boussole depuis Zmanim, les rappels depuis les Livres, l'ajout
        // de temps à un jour (la feuille du journal).
        case "calendrier": depart = (.aujourdhui, [.zmanim, .calendrier], nil, nil)
        case "boussole": depart = (.aujourdhui, [.zmanim, .boussole], nil, nil)
        case "rappels": depart = (.textes, [.rappels], nil, nil)
        case "ajout-temps": depart = (.chemin, [.journal], .ajoutTemps(aujourdhui.plus(jours: -1)), nil)
        // La barrière (tâches 27 et 28), depuis les réglages.
        case "apercu": depart = (.aujourdhui, [.reglages(carteBarriere: true), .barriere(.apercu)], nil, nil)
        case "applications":
            depart = (.aujourdhui, [.reglages(carteBarriere: true), .barriere(.choixApplications)], nil, nil)
        case "dedicace": depart = (.aujourdhui, [.reglages(carteBarriere: false), .barriere(.dedicace)], nil, nil)
        case "journal-barriere":
            depart = (.aujourdhui, [.reglages(carteBarriere: true), .barriere(.journal)], nil, nil)
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
        // Le temps que l'écran lise ses contenus et que la fête d'un trophée paraisse (500 ms après l'accueil).
        try? await Task.sleep(for: .milliseconds(1_200))
        FileHandle.standardError.write(Data("CAPTURE PRETE\n".utf8))
    }
}
