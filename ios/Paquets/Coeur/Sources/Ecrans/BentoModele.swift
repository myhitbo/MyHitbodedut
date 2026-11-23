import Foundation
import Coeur

// La version Bento (BentoActivity.kt, maquette « E · Bento — tuiles qui s'ouvrent ») : un tableau de bord en
// tuiles, sans barre d'onglets. Chaque tuile est un aperçu vivant — l'anneau de la semaine, les barres de la
// série, le prochain zman, le 'hizouk, l'égaliseur de l'ambiance, la dernière note — et s'ouvre en plein écran.
// La recherche reste en bas, sous le pouce. Police : Heebo.

/// La grande tuile de la hitbodedout : l'anneau de la semaine, le titre, le bouton.
public struct BentoHitbodedout: Sendable, Hashable {
    /// « Votre hitbodedout du jour », ou « Faite aujourd'hui · 20 min ».
    public let titre: Libelle
    /// « Commencer · 15 min », « Encore une hitbodedout », « Revenir à la hitbodedout ».
    public let bouton: Libelle
    /// L'anneau : « 4/6 » au centre, l'arc de 0 à 1 (0 sans jour dû).
    public let faits: Int
    public let dus: Int
    public let fraction: Double
    /// « 4 sur 6 cette semaine », lu sur l'anneau.
    public let accessibiliteAnneau: Libelle
    /// Lu sur la tuile : « Hitbodedout ».
    public let accessibilite: Libelle
}

/// La tuile de la série : le nombre, « jours d'affilée », les sept jours en barres.
public struct BentoSerie: Sendable, Hashable {
    public let nombre: Int
    public let jours: Libelle
    /// Un jour fait monte haut, un jour vide reste bas, du dimanche au samedi.
    public let barres: [Bool]
    /// « 12 jours d'affilée ».
    public let accessibilite: Libelle
}

/// La tuile des zmanim : le prochain et le temps qui reste, ou « Choisir un lieu » ; en bas, la chki'a.
public struct BentoZmanim: Sendable, Hashable {
    /// Le nom du prochain zman, ou « Zmanim ».
    public let etiquette: Libelle
    /// « dans 1 h 12 », ou « Choisir un lieu ».
    public let valeur: Libelle
    /// Le temps qui reste (26 pt) plutôt que l'invite (20 pt).
    public let compte: Bool
    /// « Coucher du soleil 16:42 » en bas de la tuile ; nil sans lieu.
    public let chkia: VersionZman?
    /// « Prochain : Min'ha ketana, dans 1 h 12 », ou « Zmanim ».
    public let accessibilite: [Libelle]
}

/// La tuile de l'ambiance : « Ambiance » ou « Musique », le nom, l'égaliseur qui danse s'il y a de quoi.
public struct BentoAmbiance: Sendable, Hashable {
    public let etiquette: Libelle
    public let nom: VersionTexte
    /// Une ambiance ou un morceau est choisi : les barres dansent (sauf « Réduire les animations »).
    public let joue: Bool
}

/// La tuile du journal : « Journal · hier, 20 min » et la dernière note, ou l'invite à l'écrire.
public struct BentoJournal: Sendable, Hashable {
    /// Le jour de la dernière note (la vue l'écrit en minuscules dans « Journal · %1$s, %2$s ») et sa durée ; nil :
    /// « Journal ».
    public let quand: VersionTexte?
    public let duree: Libelle?
    /// La note, ou « Écrire la note du jour ».
    public let texte: VersionTexte
    /// Une note est écrite (encre) ; sinon l'invite est atténuée.
    public let ecrite: Bool
}

/// Ce que montre l'accueil Bento.
public struct BentoEcran: Sendable, Hashable {
    /// La date civile et la date hébraïque, jointes par « · ».
    public let ligneDate: [VersionTexte]
    /// « Bonjour, Avraham » ou « Votre journée » (28 pt, Heebo noir).
    public let titre: Libelle
    public let hitbodedout: BentoHitbodedout
    public let serie: BentoSerie
    public let zmanim: BentoZmanim
    /// Le texte du jour (deux lignes d'hébreu) ; nil : « Chargement du texte du jour… ».
    public let pensee: VersionPensee?
    public let ambiance: BentoAmbiance
    public let journal: BentoJournal
}

extension AccueilVersionModele {

    /// L'accueil Bento, lu maintenant (BentoActivity.dessiner).
    public var bento: BentoEcran {
        let d = donnees
        let fraction = d.semaineDus > 0 ? min(max(Double(d.semaineFaits) / Double(d.semaineDus), 0), 1) : 0
        let hitbo = BentoHitbodedout(
            titre: d.faite ? Libelle("bento_faite", .libelle(DonneesAccueil.duree(d.minutesAujourdhui)))
                : Libelle("bento_hitbo_titre"),
            bouton: d.libelleCommencer, faits: d.semaineFaits, dus: d.semaineDus, fraction: fraction,
            accessibiliteAnneau: d.libelleSemaine, accessibilite: Libelle("pile_hitbodedout"))
        let serie = BentoSerie(nombre: d.serie, jours: Libelle.pluriel("bento_jours", quantite: d.serie),
                               barres: d.semaine.map(\.done), accessibilite: d.libelleSerie)
        let zmanim: BentoZmanim
        let chkia = d.zmanim.last { $0.cle == "chkia" }
        if let z = d.prochain {
            zmanim = BentoZmanim(etiquette: z.nom, valeur: d.dans(z), compte: true, chkia: chkia,
                                 accessibilite: [Libelle("version_prochain", .libelle(z.nom)), d.dans(z)])
        } else {
            zmanim = BentoZmanim(etiquette: Libelle("pile_zmanim"), valeur: Libelle("version_choisir_lieu"),
                                 compte: false, chkia: chkia, accessibilite: [Libelle("pile_zmanim")])
        }
        let (ambiance, morceau) = ambianceEtMorceau
        let nom: VersionTexte = ambiance != .silence ? .libelle(Libelle(ambiance.titre))
            : (morceau ?? .libelle(Libelle(ambiance.titre)))
        let tuileAmbiance = BentoAmbiance(etiquette: Libelle(ambiance != .silence ? "bento_ambiance" : "bento_musique"),
                                          nom: nom, joue: ambiance != .silence || morceau != nil)
        let journal: BentoJournal
        if let n = d.derniereNote {
            journal = BentoJournal(quand: d.jour(n.date), duree: DonneesAccueil.duree(n.minutes),
                                   texte: n.texte.map { .brut($0) } ?? .libelle(Libelle("version_ecrire_note")),
                                   ecrite: n.texte != nil)
        } else {
            journal = BentoJournal(quand: nil, duree: nil, texte: .libelle(Libelle("version_ecrire_note")), ecrite: false)
        }
        return BentoEcran(ligneDate: d.ligneDate, titre: d.salutation, hitbodedout: hitbo, serie: serie,
                          zmanim: zmanim, pensee: d.pensee, ambiance: tuileAmbiance, journal: journal)
    }
}
