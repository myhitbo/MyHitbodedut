import Foundation
import Coeur

// La version Instant (InstantActivity.kt, 17/11, d'après une image de tableau de bord de bien-être fournie par le
// propriétaire) : fond sombre, cartes arrondies, une grande carte en tête puis des mesures lisibles d'un coup d'œil.
// Dans la carte de tête, à la place de la photo, le ciel réel du moment (le paysage de Sérénité, sans arc ni nuage)
// avec les zmanim en petit. Dessous : la jauge de la semaine en demi-cercle, la série, les minutes des sept derniers
// jours en barres avec leur moyenne, le 'hizouk sur une carte vert olive, la dernière note. Titres en Bellefair.

/// Les zmanim de la carte du ciel, en petit : le prochain (le soir, le dernier du jour ; sans lieu, l'invite), puis
/// les repères du jour sur une ligne.
public struct InstantZmanim: Sendable, Hashable {
    /// « Prochain : Chki'a · 16:42 · dans 1 h 12 », le soir « Sortie des étoiles · 17:59 », ou « Choisir un lieu »,
    /// que la vue joint par « · ».
    public let ligne: [VersionTexte]
    /// Les repères du jour, chacun en nom court et heure (« Netz 06:32 ») ; vide sans lieu.
    public let reperes: [InstantRepere]
    /// Ce que VoiceOver lit de la carte des zmanim, joint par « , ».
    public let accessibilite: [VersionTexte]
}

/// Un repère de la ligne discrète de la carte du ciel : son nom court (instant_z_*) et son heure.
public struct InstantRepere: Sendable, Hashable, Identifiable {
    public let cle: String
    public let nom: Libelle
    public let heure: String

    public var id: String { cle }
}

/// La carte des sept derniers jours : leurs minutes, d'avant-hier… à aujourd'hui (le dernier, en vert olive), et la
/// moyenne des jours faits, en pointillé.
public struct InstantMinutes: Sendable, Hashable {
    /// Les sept jours, le plus ancien d'abord ; la vue écrit leur initiale (TextStyle.NARROW).
    public let jours: [JourCivil]
    public let minutes: [Int]
    /// La moyenne des jours faits (entière, tronquée) ; 0 sans jour fait.
    public let moyenne: Int
    /// « 1 h 05 » : la somme des sept jours.
    public let total: Libelle
    /// « Moyenne des jours faits : 20 min ».
    public let libelleMoyenne: Libelle

    /// La hauteur d'échelle des barres : la plus longue journée, la moyenne, au moins 15 minutes.
    public var echelle: Int {
        max(minutes.max() ?? 0, moyenne, 15)
    }
}

/// La carte du journal : « Aujourd'hui · 20 min », et « Une note, à lire dans le journal » s'il y en a une (décision
/// du 24/11 : le texte de la note reste dans le journal).
public struct InstantJournal: Sendable, Hashable {
    /// Le jour et la durée de la dernière journée, que la vue joint par « · » ; nil : « Rien d'écrit encore… ».
    public let jour: VersionTexte?
    public let duree: Libelle?
    public let noteEcrite: Bool
}

/// Ce que montre l'accueil Instant.
public struct InstantEcran: Sendable, Hashable {
    /// La date civile, au milieu de l'en-tête.
    public let dateCivile: VersionTexte
    /// « Faite aujourd'hui » ou « Votre hitbodedout du jour » (30 pt, Bellefair, blanc).
    public let titre: Libelle
    /// La date hébraïque, sous le titre ; nil : rien.
    public let dateHebraique: String?
    /// « Revenir à la hitbodedout », « Encore une hitbodedout » ou « Commencer · 15 min » : le bouton blanc.
    public let bouton: Libelle
    /// Une séance court : le bouton y ramène sans en lancer une autre.
    public let enCours: Bool
    public let zmanim: InstantZmanim
    /// La jauge de la semaine : « 4 / 6 », la part faite (0 à 1 ; 0 sans jour dû).
    public let semaineFaits: Int
    public let semaineDus: Int
    public let fraction: Double
    /// « 4 sur 6 cette semaine », lu sur la jauge.
    public let accessibiliteSemaine: Libelle
    /// La série : le nombre, « jours d'affilée » (pluriel de bento_jours), « 12 h 30 au total ».
    public let serie: Int
    public let joursSerie: Libelle
    public let total: Libelle
    public let minutes: InstantMinutes
    /// Le texte du jour ; nil : « Chargement du texte du jour… ».
    public let pensee: VersionPensee?
    public let journal: InstantJournal
}

extension AccueilVersionModele {

    /// Le nombre de jours de la carte des minutes.
    nonisolated public static let joursInstant = 7

    /// L'accueil Instant, lu maintenant (InstantActivity.dessiner).
    public var instant: InstantEcran {
        let d = donnees
        let fraction = d.semaineDus > 0 ? min(max(Double(d.semaineFaits) / Double(d.semaineDus), 0), 1) : 0
        // Les zmanim, en petit : le prochain, puis les repères du jour sur une ligne.
        let ligne: [VersionTexte]
        let accessibilite: [VersionTexte]
        if let z = d.prochain {
            ligne = [.libelle(Libelle("version_prochain", .libelle(z.nom))), .brut(z.heure), .libelle(d.dans(z))]
            accessibilite = [.libelle(Libelle("version_prochain", .libelle(z.nom))), .brut(z.heure)]
        } else if let soir = d.dernierDuJour {
            // Le soir, zmanim du jour passés : le dernier repère et son heure (DonneesAccueil.dernierDuJour).
            ligne = [.libelle(soir.nom), .brut(soir.heure)]
            accessibilite = [.libelle(soir.nom), .brut(soir.heure)]
        } else {
            ligne = [.libelle(Libelle("version_choisir_lieu"))]
            accessibilite = [.libelle(Libelle("version_sans_lieu"))]
        }
        let reperes = d.zmanim.map { InstantRepere(cle: $0.cle, nom: AccueilVersionModele.court($0.cle), heure: $0.heure) }
        let journal: InstantJournal
        if let n = d.derniereNote {
            journal = InstantJournal(jour: d.jour(n.date), duree: DonneesAccueil.duree(n.minutes), noteEcrite: n.ecrite)
        } else {
            journal = InstantJournal(jour: nil, duree: nil, noteEcrite: false)
        }
        return InstantEcran(
            dateCivile: .date(d.aujourdhui),
            titre: Libelle(d.faite ? "serenite_faite" : "instant_titre"),
            dateHebraique: d.dateHebraique,
            bouton: d.libelleCommencer,
            enCours: d.enCours,
            zmanim: InstantZmanim(ligne: ligne, reperes: reperes, accessibilite: accessibilite),
            semaineFaits: d.semaineFaits, semaineDus: d.semaineDus, fraction: fraction,
            accessibiliteSemaine: d.libelleSemaine,
            serie: d.serie,
            joursSerie: Libelle.pluriel("bento_jours", quantite: d.serie),
            total: Libelle("instant_total", .libelle(DonneesAccueil.duree(d.totalMinutes))),
            minutes: minutesInstant(d.aujourdhui),
            pensee: d.pensee,
            journal: journal)
    }

    /// Les minutes des sept derniers jours, aujourd'hui compris, et la moyenne des jours faits (InstantActivity
    /// .carteMinutes) : `average()` de Kotlin tronqué par `toInt()`.
    func minutesInstant(_ aujourdhui: JourCivil) -> InstantMinutes {
        let n = AccueilVersionModele.joursInstant
        let jours = (0..<n).map { aujourdhui.plus(jours: $0 - (n - 1)) }
        let journal = self.journal
        let minutes = jours.map { journal.record($0)?.minutes ?? 0 }
        let faits = minutes.filter { $0 > 0 }
        let moyenne = faits.isEmpty ? 0 : Int(Double(faits.reduce(0, +)) / Double(faits.count))
        return InstantMinutes(
            jours: jours, minutes: minutes, moyenne: moyenne,
            total: DonneesAccueil.duree(minutes.reduce(0, +)),
            libelleMoyenne: Libelle("instant_moyenne", .libelle(DonneesAccueil.duree(moyenne))))
    }

    /// Le nom court d'un zman pour la ligne discrète de la carte du ciel (InstantActivity.court).
    nonisolated static func court(_ cle: String) -> Libelle {
        switch cle {
        case "netz": Libelle("instant_z_netz")
        case "chatsot": Libelle("instant_z_chatsot")
        case "minha_ketana": Libelle("instant_z_minha")
        case "chkia": Libelle("instant_z_chkia")
        default: Libelle("instant_z_tset")
        }
    }
}
