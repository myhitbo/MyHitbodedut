import Foundation
import Coeur

// La version Pile (PileActivity.kt, maquette « C · Pile — l'app en cartes du jour ») : plus d'onglets, la journée
// se lit comme une pile de quatre cartes qu'on fait glisser du doigt — hitbodedout, 'hizouk, zmanim, journal. Le
// 'hizouk se retourne pour la traduction. Polices : Secular One pour les titres, Rubik pour le reste.

/// Les quatre cartes, dans l'ordre de la pile.
public enum PileCarte: Int, Sendable, CaseIterable, Identifiable {
    case hitbodedout, hizouk, zmanim, journal

    public var id: Int { rawValue }
}

/// La carte de la hitbodedout.
public struct PileHitbodedout: Sendable, Hashable {
    /// « Avraham, votre hitbodedout du jour », « Votre hitbodedout du jour » ou « Faite aujourd'hui · 20 min ».
    public let titre: Libelle
    /// « 12 jours d'affilée ».
    public let serie: Libelle
    /// « 4 sur 6 cette semaine ».
    public let semaine: Libelle
    /// Les jours de la semaine en pastilles, du dimanche au samedi : faits pleins, les autres creux.
    public let jours: [Bool]
    /// Le hassid au milieu de la carte : il accueille, ou se réjouit quand c'est fait (Character.greeting).
    public let image: String
    /// « Commencer · 15 min », « Encore une hitbodedout », « Revenir à la hitbodedout ».
    public let bouton: Libelle
}

/// La carte du 'hizouk : l'hébreu au recto, la traduction au verso.
public struct PileHizouk: Sendable, Hashable {
    /// Le texte du jour ; nil : « Chargement du texte du jour… ».
    public let pensee: VersionPensee?
    /// La traduction est montrée (le verso) : seulement s'il y en a une.
    public let verso: Bool
    /// « Voir la traduction » ou « Revoir l'hébreu » ; nil sans traduction.
    public let bouton: Libelle?
}

/// Un zman de la carte des zmanim : passé, il est atténué.
public struct PileZman: Sendable, Hashable, Identifiable {
    public let zman: VersionZman
    public let passe: Bool

    public var id: String { zman.cle }
}

/// La carte des zmanim.
public struct PileZmanim: Sendable, Hashable {
    /// « Zmanim · Jérusalem », ou « Zmanim ».
    public let etiquette: Libelle
    /// « Prochain : Chki'a » et « dans 1 h 12 » ; nil s'il n'y en a plus aujourd'hui.
    public let prochain: Libelle?
    public let dans: Libelle?
    /// Les repères du jour ; vide sans lieu : « Choisissez un lieu… » et « Choisir un lieu ».
    public let zmanim: [PileZman]
}

/// La carte du journal.
public struct PileJournal: Sendable, Hashable {
    /// Le jour de la dernière note et sa durée, que la vue joint par « , » ; nil : « Rien d'écrit encore… ».
    public let jour: VersionTexte?
    public let duree: Libelle?
    /// La note, ou « Sans note. » (atténué).
    public let texte: VersionTexte?
    public let ecrite: Bool
}

/// Ce que montre l'accueil Pile.
public struct PileEcran: Sendable, Hashable {
    /// La date civile et la date hébraïque, jointes par « · ».
    public let ligneDate: [VersionTexte]
    /// « 2 / 4 » : la carte montrée.
    public let position: Libelle
    public let hitbodedout: PileHitbodedout
    public let hizouk: PileHizouk
    public let zmanim: PileZmanim
    public let journal: PileJournal
}

extension AccueilVersionModele {

    /// L'accueil Pile, lu maintenant (PileActivity.dessiner et ses cartes).
    public var pile: PileEcran {
        let d = donnees
        let titre: Libelle
        if d.faite {
            titre = Libelle("pile_hitbo_faite", .libelle(DonneesAccueil.duree(d.minutesAujourdhui)))
        } else if !d.prenom.estBlanc {
            titre = Libelle("pile_hitbo_titre_prenom", .texte(d.prenom))
        } else {
            titre = Libelle("pile_hitbo_titre")
        }
        let hitbo = PileHitbodedout(titre: titre, serie: d.libelleSerie, semaine: d.libelleSemaine,
                                    jours: d.semaine.map(\.done), image: Poses.greeting(d.faite, jour: d.aujourdhui),
                                    bouton: d.libelleCommencer)
        let traduction = d.pensee?.traduction != nil
        let verso = traductionVisible && traduction
        let hizouk = PileHizouk(pensee: d.pensee, verso: verso,
                                bouton: traduction ? Libelle(verso ? "pile_revoir_hebreu" : "pile_voir_traduction") : nil)
        let zmanim = PileZmanim(
            etiquette: d.lieu.map { Libelle("pile_zmanim_lieu", .texte($0)) } ?? Libelle("pile_zmanim"),
            prochain: d.prochain.map { Libelle("version_prochain", .libelle($0.nom)) },
            dans: d.prochain.map { d.dans($0) },
            zmanim: d.zmanim.map { z in
                PileZman(zman: z, passe: d.prochain.map { z.instant < $0.instant } ?? true)
            })
        let journal: PileJournal
        if let n = d.derniereNote {
            journal = PileJournal(jour: d.jour(n.date), duree: DonneesAccueil.duree(n.minutes),
                                  texte: n.texte.map { .brut($0) } ?? .libelle(Libelle("version_note_sans_texte")),
                                  ecrite: n.texte != nil)
        } else {
            journal = PileJournal(jour: nil, duree: nil, texte: nil, ecrite: false)
        }
        return PileEcran(ligneDate: d.ligneDate,
                         position: Libelle("pile_position", .entier(page + 1), .entier(AccueilVersionModele.nombreDeCartes)),
                         hitbodedout: hitbo, hizouk: hizouk, zmanim: zmanim, journal: journal)
    }
}
