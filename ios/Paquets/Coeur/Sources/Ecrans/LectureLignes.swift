import Foundation
import Coeur

// Les lignes du lecteur (SiddurLectureActivity.afficher et son Adaptateur) : les notes de tête, puis les lignes
// du jour de SiddurJour.lignes, avec le pied « Replier » de chaque ajout déplié (19/10). Une ligne ici est une
// ligne de la RecyclerView d'Android : son rang (`position`) est celui que la reprise enregistre
// (`position:<clé>`), si bien qu'une place gardée sur un téléphone vaut sur l'autre.
//
// Android retrouve la place (section, paragraphe) d'un bloc par identité (IdentityHashMap) ; Swift n'a pas
// d'identité pour un `SiddurBloc`, la place est donc refaite en suivant les lignes dans l'ordre du texte, ce que
// SiddurJour.lignes garantit (les blocs sortent dans l'ordre ; un repli fermé saute sa section ou son groupe).

/// Une ligne de la liste du lecteur.
public struct LectureLigne: Sendable, Equatable, Identifiable {
    /// Stable d'un affichage à l'autre (« bloc:3:12 », « titre:4 », « replie:§2 »…) : la vue s'en sert pour le
    /// défilement et les animations.
    public let id: String
    /// Le rang dans la liste (la position de la RecyclerView d'Android, celle de la reprise).
    public let position: Int
    public let contenu: LectureContenu
}

/// Ce que montre une ligne (les branches de onBindViewHolder).
public enum LectureContenu: Sendable, Equatable {
    /// Une note en tête, petite et discrète, dans le sens de la langue de l'app.
    case note(Libelle)
    /// Le titre d'une section : un signet de la bande.
    case titre(LectureTitre)
    /// Un paragraphe de prière, une consigne, ou un paragraphe de livre.
    case bloc(LectureBloc)
    /// « Aujourd'hui · <nom> » au-dessus d'un ajout du jour : la vue écrit `siddur_aujourdhui`, « · », puis ce nom.
    case etiquette(Libelle)
    /// « Aujourd'hui : המלך הקדוש » sous un bloc : la vue écrit `siddur_aujourdhui`, « : », puis ce texte hébreu ;
    /// une indication fixe du siddour (`fixe`, audit du 16/11) s'écrit telle quelle.
    case indice(String, fixe: Bool)
    /// « Aujourd'hui · הַלֵּל › » : le texte de ce jour à cet endroit, ouvert d'un geste.
    case renvoi(LectureRenvoi)
    /// « Aujourd'hui · <nom> » : ce que le jour change ici sans texte dans le siddour (audit du 16/11) ; 13 ×
    /// échelle, couleur des titres, fond teinté, dans le sens de la langue de l'app.
    case rappel(Libelle)
    /// Le bandeau d'un ajout replié (ou déplié) : un toucher l'ouvre ou le referme.
    case replie(LectureRepli)
    /// Qui prie seul : une carte à part, jamais repliée.
    case seul(LectureSeul)
    /// Le pied d'un ajout déplié : « Replier », pour ne pas remonter le chercher. `cle` : celle du repli.
    case pied(cle: String)
}

/// Le titre d'une section (SiddurJour.Ligne.Titre).
public struct LectureTitre: Sendable, Equatable {
    /// L'hébreu et/ou sa traduction selon les langues de lecture (LectureBalisage.titre) : le premier en taille 1,
    /// le second à 0,72 ; tous en gras, couleur des titres.
    public let paragraphes: [LectureParagraphe]
    /// Le titre hébreu, masqué pour la police : le texte du signet.
    public let hebreu: String
    /// La section du texte.
    public let section: Int
}

/// Un paragraphe (SiddurJour.Ligne.Bloc).
public struct LectureBloc: Sendable, Equatable {
    /// Sa place dans le texte : la clé des marque-pages.
    public let place: LecturePlace
    /// Le bloc tel qu'il se lit aujourd'hui (une variante hors du jour retirée).
    public let bloc: SiddurBloc
    public let style: SiddurJour.Style
    /// Déplié depuis un repli : dans le panneau de son repli (voile de la couleur des titres), lisible.
    public let dansPanneau: Bool
    /// Un marque-page y est posé : un trait de 4 points au début du paragraphe et l'icône du marque-page au bout.
    public let marque: Bool
    let langues: LanguesTexte.Mode
    let police: PoliceHebraique.Police

    /// Une consigne : petite (12 × échelle), discrète, collée au texte qu'elle annonce.
    public var consigne: Bool {
        bloc.consigne
    }

    /// Un ajout du jour : fond teinté de la couleur des titres (alpha 0x1C).
    public var duJour: Bool {
        style == .duJour
    }

    /// Une variante d'un autre jour au milieu d'un ajout du jour : estompée (opacité 0,55). Jamais dans un panneau.
    public var estompe: Bool {
        !dansPanneau && style == .hors
    }

    /// Les paragraphes à montrer, calculés à la demande (la liste est paresseuse : Likoutei Moharan compte plus
    /// de 7 000 blocs) : aéré, premier mot agrandi, masqué pour la police, traductions selon les langues.
    public var paragraphes: [LectureParagraphe] {
        LectureBalisage.paragraphes(texte: bloc.texte, consigne: bloc.consigne, fr: bloc.fr, en: bloc.en,
                                    langues: langues, police: police)
    }

    /// Les premiers mots, pour la lecture d'écran et la liste des marque-pages.
    public var apercu: String {
        MarquesPages.apercu(bloc.texte)
    }
}

/// Un renvoi du jour (SiddurJour.Ligne.Renvoi).
public struct LectureRenvoi: Sendable, Equatable {
    /// Le titre hébreu du texte renvoyé (masqué pour la police), ou son identifiant s'il n'existe pas.
    public let titre: String
    /// Ce qu'ouvre le toucher ; nil si le texte n'existe pas dans ce siddour (la ligne ne s'ouvre pas).
    public let route: LectureRoute?
}

/// Un ajout replié ou déplié (SiddurJour.Ligne.Replie).
public struct LectureRepli: Sendable, Equatable {
    public let cle: String
    /// Son nom (« Ya'alé véyavo »), en gras.
    public let nom: Libelle
    /// Dessous, à 0,82 et discret : « Replier » ouvert, « Toucher pour lire » pour ce qui n'est jamais du jour,
    /// « Pas aujourd'hui · toucher pour lire » sinon.
    public let etat: Libelle
    /// Déplié : le chevron tourné d'un quart de tour, le panneau ouvert vers le bas.
    public let ouvert: Bool
}

/// La carte de qui prie seul (SiddurJour.Ligne.Seul).
public struct LectureSeul: Sendable, Equatable {
    /// « Si l'on prie seul » (siddur_seul), en gras, couleur des titres, à 0,68.
    public let etiquette: Libelle
    /// La consigne qui précède, à 0,68 et discrète ; nil sans consigne.
    public let consigne: String?
    /// Le texte : en grand avec une consigne ; sans consigne, à 0,75 et discret (c'est alors une consigne).
    public let texte: String

    /// Le texte est-il le petit mot discret d'une carte sans consigne ?
    public var texteDiscret: Bool {
        consigne == nil
    }
}

/// La construction des lignes, sans état : jugée par les tests sur les siddourim exportés.
enum LectureLignes {

    /// Les conditions qui ne sont jamais « du jour » : on dit « toucher pour lire », pas « pas aujourd'hui ».
    static let jamaisDuJour: [String] = [
        CalendrierJuif.C.minyan, CalendrierJuif.C.beitAvel, CalendrierJuif.C.oubli,
        CalendrierJuif.C.chevaBerakhot, CalendrierJuif.C.zimun, CalendrierJuif.C.facultatif,
    ]

    /// La place (section, paragraphe) de chaque ligne `.bloc`, nil pour les autres : son origine dans le texte,
    /// que SiddurJour.lignes donne (FLECTURE-08 ; Android la retrouve par l'identité du paragraphe).
    static func places(_ texte: SiddurTexte, _ annotations: [SiddurJour.Annotation],
                       _ lignes: [SiddurJour.Ligne]) -> [LecturePlace?] {
        lignes.map { ligne in
            if case .bloc(_, _, let origine) = ligne { return LecturePlace(section: origine.section, bloc: origine.bloc) }
            return nil
        }
    }

    /// Les lignes du lecteur. `notes` : celles de tête ; `marques` : les places marquées de ce texte ;
    /// `titreDe` : le titre hébreu d'un texte du recueil, pour les renvois (nil s'il n'existe pas).
    static func lignes(texte: SiddurTexte, annotations: [SiddurJour.Annotation], jour: [SiddurJour.Ligne],
                       notes: [(id: String, libelle: Libelle)], marques: Set<LecturePlace>,
                       langues: LanguesTexte.Mode, police: PoliceHebraique.Police,
                       titreDe: (String) -> String?) -> [LectureLigne] {
        let lesPlaces = LectureLignes.places(texte, annotations, jour)
        let plusieurs = texte.sections.count > 1
        var sectionsTitrees: [Int] = []
        for (si, s) in texte.sections.enumerated() where plusieurs && !s.titre.estBlanc {
            sectionsTitrees.append(si)
        }
        var sortie: [LectureLigne] = []
        sortie.reserveCapacity(jour.count + notes.count + 8)
        func ajouter(_ id: String, _ contenu: LectureContenu) {
            sortie.append(LectureLigne(id: id, position: sortie.count, contenu: contenu))
        }
        for note in notes {
            ajouter("note:" + note.id, .note(note.libelle))
        }
        // Les lignes sans place propre prennent celle de la dernière ligne ancrée, et un rang.
        var ancre = "debut"
        var rangs: [String: Int] = [:]
        func idRelatif(_ sorte: String) -> String {
            let base = sorte + "@" + ancre
            let rang = rangs[base, default: 0]
            rangs[base] = rang + 1
            return base + "#" + String(rang)
        }
        var titres = 0
        // Un ajout déplié se lit dans un panneau, fermé par un pied « Replier » à la fin du repli (Ligne.fin), après
        // tous ses membres, même quand un repli s'ouvre dedans (audit du 16/11).
        let dansUnPanneau = SiddurJour.panneaux(jour)
        for (k, ligne) in jour.enumerated() {
            let panneau = dansUnPanneau.contains(k)
            switch ligne {
            case .titre(let he, let fr, let en):
                let section = titres < sectionsTitrees.count ? sectionsTitrees[titres] : titres
                titres += 1
                ancre = "titre:" + String(section)
                ajouter(ancre, .titre(LectureTitre(
                    paragraphes: LectureBalisage.titre(he, fr: fr, en: en, langues: langues, police: police),
                    hebreu: PoliceHebraique.masque(he, police: police), section: section)))
            case .bloc(let bloc, let style, _):
                let place = lesPlaces[k] ?? LecturePlace(section: 0, bloc: 0)
                ancre = "bloc:" + String(place.section) + ":" + String(place.bloc)
                ajouter(ancre, .bloc(LectureBloc(place: place, bloc: bloc, style: style, dansPanneau: panneau,
                                                 marque: marques.contains(place), langues: langues, police: police)))
            case .etiquette(_, let libelle):
                ajouter(idRelatif("etiquette"), .etiquette(Libelle(libelle)))
            case .indice(let variante, let fixe):
                ajouter(idRelatif("indice"), .indice(PoliceHebraique.masque(variante, police: police), fixe: fixe))
            case .renvoi(_, let cible):
                let titre = titreDe(cible)
                ajouter(idRelatif("renvoi"), .renvoi(LectureRenvoi(
                    titre: PoliceHebraique.masque(titre ?? cible, police: police),
                    route: titre == nil ? nil : .lecture(.siddour(cible)))))
            case .rappel(_, let libelle):
                ajouter(idRelatif("rappel"), .rappel(Libelle(libelle)))
            case .seul(let texteSeul, let consigne, let note):
                // Une note de l'application (audit du 16/11) : même carte, son étiquette propre.
                ajouter(idRelatif("seul"), .seul(LectureSeul(
                    etiquette: Libelle(note ? "siddur_note" : "siddur_seul"),
                    consigne: consigne.map { PoliceHebraique.masque($0, police: police) },
                    texte: PoliceHebraique.masque(texteSeul, police: police))))
            case .replie(let cle, let condition, let estOuvert, let libelle):
                ajouter("replie:" + cle, .replie(LectureRepli(cle: cle, nom: Libelle(libelle),
                                                              etat: etat(condition: condition, ouvert: estOuvert),
                                                              ouvert: estOuvert)))
            case .fin(let cle):
                ajouter("pied:" + cle, .pied(cle: cle))
            }
        }
        return sortie
    }

    /// Ce qu'un toucher fait au bandeau d'un ajout : le replier, le lire (jamais du jour), ou le lire bien qu'il
    /// ne soit pas d'aujourd'hui.
    static func etat(condition: String, ouvert: Bool) -> Libelle {
        if ouvert { return Libelle("siddur_replier") }
        if jamaisDuJour.contains(where: { $0.egalUnites(condition) }) { return Libelle("siddur_toucher_lire") }
        return Libelle("siddur_pas_aujourdhui")
    }
}
