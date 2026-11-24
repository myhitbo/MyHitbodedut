import Foundation
import Coeur

// La version Sérénité (SereniteActivity.kt, maquette « P2 · Sérénité pro — la carte du soir s'ouvre en paysage ») :
// une grande carte-paysage qui suit le ciel du moment (étoiles la nuit, soleil couchant, matin bleu) avec la
// silhouette du hassid ; dessous, le 'hizouk, le prochain zman et les derniers jours. Quatre onglets en bas :
// Aujourd'hui, Zmanim, Textes, Journal. Titres en Bellefair.

/// Une ligne de « Vos derniers jours » : le jour, sa durée, sa note (une ligne).
public struct SereniteJour: Sendable, Hashable, Identifiable {
    public let date: JourCivil
    public let jour: VersionTexte
    public let duree: Libelle
    public let note: String?

    public var id: JourCivil { date }
}

/// Le prochain zman de la carte des zmanim : son nom, puis « 16:42 · dans 1 h 12 ».
public struct SereniteZman: Sendable, Hashable {
    public let nom: Libelle
    public let heure: String
    public let dans: Libelle
}

/// Les quatre onglets du bas (SereniteActivity.dessinerOnglets) : Aujourd'hui est l'écran même.
public enum SereniteOnglet: String, Sendable, CaseIterable, Identifiable {
    case aujourdhui, zmanim, textes, journal

    public var id: String { rawValue }

    public var titre: Libelle {
        switch self {
        case .aujourdhui: Libelle("version_aujourdhui")
        case .zmanim: Libelle("pile_zmanim")
        case .textes: Libelle("version_textes")
        case .journal: Libelle("pile_journal")
        }
    }

    /// L'onglet actif (accent, gras) : celui de l'accueil.
    public var actif: Bool { self == .aujourdhui }
}

/// Ce que montre l'accueil Sérénité.
public struct SereniteEcran: Sendable, Hashable {
    /// Le ciel du moment : sa phase (l'étiquette, la palette de nuit).
    public let phase: CielDuJour.Phase
    /// Le ciel continu, que la carte-paysage peint (24/11).
    public let ciel: EtatCiel
    /// La palette de nuit (la nuit et le soir) ; celle du jour le jour et à l'aube.
    public let nuit: Bool
    /// « Bonjour, Avraham » ou « Votre journée » (32 pt, Bellefair).
    public let titre: Libelle
    /// L'initiale du prénom, dans le rond qui ouvre les réglages ; nil : la roue (⚙).
    public let initiale: String?
    /// La date civile, la date hébraïque et la série, que la vue joint par « · ».
    public let ligne: [VersionTexte]
    /// « En cours », « Faite aujourd'hui », « Ce soir » ou « Aujourd'hui », en capitales, au-dessus du titre.
    public let etiquette: Libelle
    /// « Hitbodedout · 20 min » : la durée faite, ou celle de la prochaine.
    public let titreCarte: Libelle
    /// « Commencer : Hitbodedout · 15 min », lu par VoiceOver sur la carte.
    public let accessibiliteCarte: Libelle
    /// « Pluie · Le niggoun du Yanuka », « Silence » : l'ambiance et le morceau de la séance.
    public let reglage: [VersionTexte]
    /// Le texte du jour ; nil tant qu'il n'est pas lu (« Chargement du texte du jour… »).
    public let pensee: VersionPensee?
    /// « Zmanim · Jérusalem », ou « Zmanim » sans lieu.
    public let titreZmanim: Libelle
    /// Le prochain zman ; nil : « Choisissez un lieu… ».
    public let prochain: SereniteZman?
    /// Les trois dernières journées faites ; vide : « Rien d'écrit encore… ».
    public let jours: [SereniteJour]
}

extension AccueilVersionModele {

    /// L'accueil Sérénité, lu maintenant (SereniteActivity.dessiner).
    public var serenite: SereniteEcran {
        let d = donnees
        let phase = ciel
        let nuit = !(phase == .jour || phase == .aube)
        let etiquette: Libelle
        if d.enCours {
            etiquette = Libelle("serenite_en_cours")
        } else if d.faite {
            etiquette = Libelle("serenite_faite")
        } else if phase == .nuit || phase == .coucher {
            etiquette = Libelle("serenite_ce_soir")
        } else {
            etiquette = Libelle("serenite_aujourdhui")
        }
        let objectif = Libelle("serenite_titre", .libelle(DonneesAccueil.duree(d.objectifMinutes)))
        let titreCarte = d.faite && !d.enCours
            ? Libelle("serenite_titre", .libelle(DonneesAccueil.duree(d.minutesAujourdhui))) : objectif
        let prochain = d.prochain.map { z in SereniteZman(nom: z.nom, heure: z.heure, dans: d.dans(z)) }
        let jours = derniersJours(3).map { (date, r) in
            SereniteJour(date: date, jour: d.jour(date), duree: DonneesAccueil.duree(r.minutes),
                         note: r.note.estBlanc || journalCache ? nil : r.note)
        }
        let initiale = d.prenom.first.map { String($0).uppercased() }
        return SereniteEcran(
            phase: phase, ciel: etatCiel, nuit: nuit, titre: d.salutation, initiale: initiale,
            ligne: d.ligneDate + [.libelle(d.libelleSerie)],
            etiquette: etiquette, titreCarte: titreCarte,
            accessibiliteCarte: Libelle("serenite_ouvrir", .libelle(objectif)),
            reglage: reglageSerenite,
            pensee: d.pensee,
            titreZmanim: d.lieu.map { Libelle("pile_zmanim_lieu", .texte($0)) } ?? Libelle("pile_zmanim"),
            prochain: prochain, jours: jours)
    }

    /// Un onglet du bas touché : Aujourd'hui ne fait rien, les autres ouvrent leur écran.
    public func toucherOnglet(_ onglet: SereniteOnglet) {
        switch onglet {
        case .aujourdhui: break
        case .zmanim: ouvrirZmanim()
        case .textes: ouvrirTextes()
        case .journal: ouvrirJournal()
        }
    }

    /// SereniteActivity.reglage : l'ambiance, sauf le silence quand un morceau est choisi, puis le morceau.
    private var reglageSerenite: [VersionTexte] {
        let (ambiance, morceau) = ambianceEtMorceau
        var ligne: [VersionTexte] = []
        if ambiance != .silence || morceau == nil { ligne.append(.libelle(Libelle(ambiance.titre))) }
        if let morceau { ligne.append(morceau) }
        return ligne
    }
}
