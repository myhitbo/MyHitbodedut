import Foundation
import SwiftUI
import Coeur
import Ecrans

// Les liaisons des champs, interrupteurs, curseurs et feuilles vers les modèles d'écran : une propriété calculée
// que l'on lit et écrit, prise par `Bindable(modele).propriete`. Elles remplacent `Binding(get:set:)` avec des
// fermetures `@MainActor` : Swift 6.3.3 (Xcode 26.6) plante en produisant le code de leur conversion vers les
// paramètres `@isolated(any) @Sendable` de `Binding` (IRGen, « report_size_overflow »). Ici, aucune fermeture : un
// chemin de clé vers une propriété du modèle, comme `$modele.nom` avec `@Bindable`.
//
// La lecture passe par ce que le modèle montre ; l'écriture, par son action, jamais par son état directement.

// MARK: Les champs de recherche

extension RechercheModele {
    /// Le champ de la recherche : chaque frappe relance la recherche.
    var texteSaisi: String {
        get { texte }
        set { chercher(newValue) }
    }
}

extension HalakhaModele {
    /// Le champ : chaque frappe passe au modèle, qui cherche ou revient au jour.
    var rechercheSaisie: String {
        get { recherche }
        set { chercher(newValue) }
    }

    /// L'interrupteur, lu dans les réglages. Une écriture qui échoue ne dit rien, comme Store.setHalakhaAffichee :
    /// l'interrupteur revient alors à ce que gardent les réglages.
    var interrupteurCarteDuJour: Bool {
        get { afficheeSurLaCarteDuJour }
        set {
            let oui = newValue
            Task { try? await self.afficherSurLaCarteDuJour(oui) }
        }
    }
}

extension HilloulotModele {
    var rechercheSaisie: String {
        get { recherche }
        set { chercher(newValue) }
    }

    /// Une écriture qui échoue ne dit rien, comme Store.setHilloulotAffichees.
    var interrupteurCarteDuJour: Bool {
        get { afficheesSurLaCarteDuJour }
        set {
            let oui = newValue
            Task { try? await self.afficherSurLaCarteDuJour(oui) }
        }
    }
}

// MARK: Les feuilles des marque-pages

extension BibliothequeModele {
    /// La feuille suit le modèle ; la fermer d'un geste passe par `fermerSignets()`.
    var feuilleSignetsLiee: Bool {
        get { feuilleSignetsOuverte }
        set { if !newValue { fermerSignets() } }
    }
}

extension TehilimModele {
    /// La feuille suit le modèle ; la fermer d'un geste passe par `fermerSignets()`.
    var feuilleSignetsLiee: Bool {
        get { feuilleSignetsOuverte }
        set { if !newValue { fermerSignets() } }
    }
}

// MARK: La barre de lecture de la bibliothèque

extension BibliothequeBarreLecture {
    /// Le choix de la police : un sélecteur dans un menu, qui coche la police choisie.
    var policeChoisie: PoliceHebraique.Police {
        get { police }
        set {
            let police = newValue
            BibliothequeTache.lancer { [self] in try await choisirPolice(police) }
        }
    }

    /// Le choix des langues du texte, de même.
    var languesChoisies: LanguesTexte.Mode {
        get { mode }
        set {
            let mode = newValue
            BibliothequeTache.lancer { [self] in try await choisirLangues(mode) }
        }
    }
}

// MARK: La musique

extension MusiqueMiniLecteurModele {
    /// La barre de position : elle suit le doigt pendant qu'il glisse.
    var positionGlissee: Double {
        get { Double(position) }
        set { glisser(a: Int(newValue)) }
    }
}

extension MusiqueModele {
    /// L'interrupteur de la musique : la séance en cours suit (le modèle le fait).
    var musiqueLiee: Bool {
        get { musiqueActive }
        set {
            let oui = newValue
            Task.immediate { await self.activerMusique(oui) }
        }
    }

    /// L'interrupteur de la lecture aléatoire.
    var aleatoireLie: Bool {
        get { aleatoire }
        set {
            let oui = newValue
            Task.immediate { await self.activerAleatoire(oui) }
        }
    }

    /// La barre du volume, de 0 à 100 par pas de 1 : chaque pas est enregistré (onProgressChanged).
    var volumeLie: Double {
        get { Double(volume) }
        set {
            let valeur = Int(newValue)
            Task.immediate { await self.choisirVolume(valeur) }
        }
    }

    /// Le dialogue des ambiances : fermé par « Retour », par le geste qui baisse la feuille, ou par un choix.
    var choixAmbianceLie: Bool {
        get { choixAmbianceOuvert }
        set { if !newValue { fermerChoixAmbiance() } }
    }

    /// Le dialogue « Renommer ». Chaque bouton ferme le dialogue par le modèle lui-même : la fermeture que SwiftUI
    /// écrit ici n'a rien à faire, et surtout pas « Retour », qui effacerait le dialogue avant que « Enregistrer »
    /// ne le lise.
    var renommageLie: MusiqueRenommage? {
        get { renommage }
        set {}
    }
}

// MARK: La présentation

extension PresentationModele {
    /// L'interrupteur lit le réglage du modèle et l'écrit par son action.
    var rappelLie: Bool {
        get { rappelActif }
        set {
            let actif = newValue
            Task { try? await self.basculerRappel(actif) }
        }
    }

    /// La feuille de l'heure suit `choixHeureOuvert` ; glissée vers le bas, elle se ferme sans rien choisir.
    var choixHeureLie: Bool {
        get { choixHeureOuvert }
        set { if !newValue { fermerChoixHeure() } }
    }
}
