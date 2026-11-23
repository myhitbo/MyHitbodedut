import Foundation
import Observation
import Coeur

// La dédicace (Dedicace.kt, 04/11) : un utilisateur ne dédie pas lui-même sa hitbodedout ou son étude dans l'application ;
// la demande passe par l'équipe. Elle s'écrit dans la messagerie de l'utilisateur, adressée à l'équipe, prête à partir :
// rien n'est envoyé sans lui, rien n'est gardé sur le téléphone. Android l'ouvre dans une boîte de dialogue des
// réglages ; iOS, dans un écran de la pile des réglages, avec les mêmes champs, les mêmes refus et le même repli sans
// messagerie (le message copié, l'adresse affichée).

/// Ce qu'on dédie (Dedicace.Objet).
public enum DedicaceObjet: String, Sendable, CaseIterable, Identifiable {
    case hitbodedut, etude

    public var id: String { rawValue }

    public var libelle: Libelle {
        switch self {
        case .hitbodedut: Libelle("dedicace_hitbodedut")
        case .etude: Libelle("dedicace_etude")
        }
    }
}

/// L'intention (Dedicace.Intention) : la formule hébraïque reste en hébreu dans l'e-mail, quelle que soit la langue,
/// c'est elle qui s'affichera.
public enum DedicaceIntention: String, Sendable, CaseIterable, Identifiable {
    case leilouy, refoua, hatslaha, zivoug, autre

    public var id: String { rawValue }

    public var libelle: Libelle {
        switch self {
        case .leilouy: Libelle("dedicace_leilouy")
        case .refoua: Libelle("dedicace_refoua")
        case .hatslaha: Libelle("dedicace_hatslaha")
        case .zivoug: Libelle("dedicace_zivoug")
        case .autre: Libelle("dedicace_autre")
        }
    }

    /// nil pour « Autre intention » : le mot devient l'intention elle-même.
    public var formule: String? {
        switch self {
        case .leilouy: "לעילוי נשמת"
        case .refoua: "לרפואה שלמה"
        case .hatslaha: "להצלחה"
        case .zivoug: "לזיווג הגון"
        case .autre: nil
        }
    }
}

/// Le message prêt à partir : le lien `mailto:` et, pour le repli, le sujet et le corps en clair.
public struct DedicaceMessage: Sendable, Equatable {
    public let sujet: String
    public let corps: String
    public let lien: String
}

/// L'écran de la dédicace.
@MainActor
@Observable
public final class DedicaceModele {

    /// L'adresse de l'équipe (Dedicace.ADRESSE), la même que celle du site.
    public static let adresse = "myhitbodedut26@gmail.com"

    private let traducteur: Traducteur

    public var objet: DedicaceObjet = .hitbodedut
    public var intention: DedicaceIntention = .leilouy {
        didSet {
            // « Autre intention » : le mot devient l'intention, et l'indice le dit ; sinon l'erreur du mot s'efface.
            if intention != .autre { erreurMot = nil }
        }
    }
    public var nom = "" {
        didSet { if !nom.estBlanc { erreurNom = nil } }
    }
    public var mot = "" {
        didSet { if !mot.estBlanc { erreurMot = nil } }
    }
    /// « Indiquez le nom. » sous le champ du nom (nom.error).
    public private(set) var erreurNom: Libelle? = nil
    /// « Précisez l'intention. » sous le champ du mot (FLECTURE-18).
    public private(set) var erreurMot: Libelle? = nil
    /// Sans messagerie : l'adresse, et que le message a été copié (avis, rendu visible) ; vide sinon.
    public private(set) var avis: [Libelle] = []

    public init(traducteur: Traducteur) {
        self.traducteur = traducteur
    }

    // MARK: Ce que l'écran montre

    public var titre: Libelle { Libelle("section_dedicace") }
    public var explication: Libelle { Libelle("section_dedicace_hint") }

    /// L'indice du champ du mot : l'intention elle-même pour « Autre intention ».
    public var indiceMot: Libelle {
        Libelle(intention == .autre ? "dedicace_intention_manque" : "dedicace_mot")
    }

    // MARK: Écrire

    /// « Écrire l'e-mail » : le message, ou nil si un champ manque (la boîte reste ouverte et le dit sous le champ).
    public func ecrire() -> DedicaceMessage? {
        avis = []
        guard !nom.estBlanc else {
            erreurNom = Libelle("dedicace_nom_manque")
            return nil
        }
        // « Autre intention » n'a pas de formule : sans le mot, l'e-mail partirait sans intention (FLECTURE-18).
        if intention == .autre && mot.estBlanc {
            erreurMot = Libelle("dedicace_intention_manque")
            return nil
        }
        erreurNom = nil
        erreurMot = nil
        let quoi = traducteur.texte(objet.libelle)
        let texte = DedicaceModele.corps(intro: traducteur.texte(Libelle("dedicace_corps_intro")),
                                         demande: traducteur.texte(Libelle("dedicace_corps_demande",
                                                                           .texte(DedicaceModele.minusculeInitiale(quoi)))),
                                         formule: intention.formule, nom: nom, mot: mot,
                                         fin: traducteur.texte(Libelle("dedicace_corps_fin")))
        let sujet = traducteur.texte(Libelle("dedicace_sujet", .texte(quoi)))
        return DedicaceMessage(sujet: sujet, corps: texte, lien: DedicaceModele.lien(sujet: sujet, corps: texte))
    }

    /// La messagerie n'a pu s'ouvrir : l'écran reste (le nom et le mot ne sont pas perdus), le message est copié par la
    /// vue s'il a pu l'être, et l'adresse s'affiche.
    public func sansMessagerie(copie: Bool) {
        avis = [Libelle("dedicace_sans_messagerie")] + (copie ? [Libelle("dedicace_copie")] : [])
    }

    // MARK: Les règles de Dedicace.kt

    /// Le corps de l'e-mail : la salutation, la demande, la ligne de la dédicace, le mot éventuel, la signature.
    public static func corps(intro: String, demande: String, formule: String?, nom: String, mot: String, fin: String) -> String {
        var lignes = [intro, "", demande]
        lignes.append([formule, nom.rogne].compactMap { $0 }.joined(separator: " "))
        if !mot.estBlanc {
            lignes.append("")
            lignes.append(mot.rogne)
        }
        lignes.append("")
        lignes.append(fin)
        return lignes.joined(separator: "\n")
    }

    /// `mailto:` avec le sujet et le corps encodés comme `URLEncoder.encode(s, "UTF-8")`, les espaces en %20 (pas en +,
    /// que certaines messageries gardent).
    public static func lien(sujet: String, corps: String) -> String {
        "mailto:" + adresse + "?subject=" + encoder(sujet) + "&body=" + encoder(corps)
    }

    /// URLEncoder.encode : seuls les lettres et chiffres ASCII et « . - * _ » restent ; tout le reste en %XX de l'UTF-8.
    static func encoder(_ texte: String) -> String {
        var resultat = ""
        for octet in texte.utf8 {
            switch octet {
            case 0x30...0x39, 0x41...0x5A, 0x61...0x7A, 0x2E, 0x2D, 0x2A, 0x5F:
                resultat.unicodeScalars.append(Unicode.Scalar(octet))
            default:
                let chiffres = Array("0123456789ABCDEF")
                resultat += "%" + String(chiffres[Int(octet >> 4)]) + String(chiffres[Int(octet & 0x0F)])
            }
        }
        return resultat
    }

    /// `replaceFirstChar { it.lowercase() }` : « Ma hitbodedout » → « ma hitbodedout ».
    static func minusculeInitiale(_ texte: String) -> String {
        guard let premier = texte.first else { return texte }
        return premier.lowercased() + texte.dropFirst()
    }
}
