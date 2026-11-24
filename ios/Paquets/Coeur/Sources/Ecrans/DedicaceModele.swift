import Foundation
import Observation
import Coeur

// La dédicace (Dedicace.kt, ouverte par le bouton « Dédicacer » de SettingsActivity) : un utilisateur ne dédie pas
// lui-même sa hitbodedout ou son étude dans l'app ; la demande passe par l'équipe. Elle s'écrit dans la messagerie
// de l'utilisateur, adressée à l'équipe, prête à partir : rien n'est envoyé sans lui, rien n'est gardé sur le
// téléphone. Ce fichier compose le sujet, le corps et le lien mailto: ; la vue (DedicaceVue) ouvre le lien.

/// Ce que l'on dédie (Dedicace.Objet), dans l'ordre des boutons radio d'Android.
public enum DedicaceObjet: String, CaseIterable, Sendable, Hashable, Identifiable {
    case hitbodedut
    case etude

    public var id: Self { self }

    /// « Ma hitbodedout », « Mon étude ».
    public var libelle: Libelle {
        switch self {
        case .hitbodedut: Libelle("dedicace_hitbodedut")
        case .etude: Libelle("dedicace_etude")
        }
    }
}

/// L'intention de la dédicace (Dedicace.Intention), dans l'ordre des boutons radio d'Android.
public enum DedicaceIntention: String, CaseIterable, Sendable, Hashable, Identifiable {
    case leilouy
    case refoua
    case hatslaha
    case zivoug
    case autre

    public var id: Self { self }

    /// « Léïlouy nichmat (לעילוי נשמת) »…
    public var libelle: Libelle {
        switch self {
        case .leilouy: Libelle("dedicace_leilouy")
        case .refoua: Libelle("dedicace_refoua")
        case .hatslaha: Libelle("dedicace_hatslaha")
        case .zivoug: Libelle("dedicace_zivoug")
        case .autre: Libelle("dedicace_autre")
        }
    }

    /// La formule qui précède le nom dans l'e-mail : elle reste en hébreu quelle que soit la langue, c'est elle qui
    /// s'affichera (recopiée de Dedicace.kt). Aucune pour « Autre intention ».
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

/// L'e-mail de la dédicace, sans état : l'adresse de l'équipe, le corps (Dedicace.corps) et le lien (Dedicace.lien).
public enum DedicaceCourriel {

    /// Dedicace.ADRESSE.
    public static let adresse = "myhitbodedut26@gmail.com"

    /// Le corps de l'e-mail (Dedicace.corps) : la salutation, une ligne vide, la demande, la ligne de la dédicace
    /// (la formule puis le nom rogné, séparés d'une espace), le mot rogné précédé d'une ligne vide s'il n'est pas
    /// blanc, une ligne vide, la signature ; lignes jointes par « \n ».
    public static func corps(intro: String, demande: String, formule: String?, nom: String, mot: String,
                             fin: String) -> String {
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

    /// Le lien mailto: avec le sujet et le corps encodés (Dedicace.lien) : espaces en %20, pas en +, que certaines
    /// messageries gardent.
    public static func lien(sujet: String, corps: String) -> String {
        "mailto:" + adresse + "?subject=" + encoder(sujet) + "&body=" + encoder(corps)
    }

    /// `URLEncoder.encode(s, "UTF-8").replace("+", "%20")` de Java : les lettres et chiffres ASCII et « . - * _ »
    /// restent tels quels, l'espace devient %20, tout autre octet de l'UTF-8 s'écrit %XX en hexadécimal majuscule
    /// (un « + » du texte devient donc %2B, comme chez Java avant le remplacement).
    public static func encoder(_ texte: String) -> String {
        let chiffres = Array("0123456789ABCDEF".utf8)
        var octets: [UInt8] = []
        octets.reserveCapacity(texte.utf8.count * 3)
        for octet in texte.utf8 {
            switch octet {
            case UInt8(ascii: "a")...UInt8(ascii: "z"), UInt8(ascii: "A")...UInt8(ascii: "Z"),
                 UInt8(ascii: "0")...UInt8(ascii: "9"),
                 UInt8(ascii: "."), UInt8(ascii: "-"), UInt8(ascii: "*"), UInt8(ascii: "_"):
                octets.append(octet)
            case UInt8(ascii: " "):
                octets.append(contentsOf: Array("%20".utf8))
            default:
                octets.append(UInt8(ascii: "%"))
                octets.append(chiffres[Int(octet >> 4)])
                octets.append(chiffres[Int(octet & 0x0F)])
            }
        }
        return String(decoding: octets, as: UTF8.self)
    }

    /// `replaceFirstChar { it.lowercase() }` de Kotlin : la première lettre en minuscule (« Ma hitbodedout » →
    /// « ma hitbodedout » ; l'hébreu, sans casse, ne change pas).
    static func premiereEnMinuscule(_ texte: String) -> String {
        guard let premiere = texte.first else { return texte }
        return String(premiere).lowercased() + texte.dropFirst()
    }
}

/// La boîte de la dédicace (Dedicace.ouvrir) : le texte d'aide, « Que dédiez-vous ? » (hitbodedout ou étude),
/// « Pour » (cinq intentions), le nom (obligatoire), un mot facultatif ; « Écrire l'e-mail » rend le lien mailto:
/// que la vue ouvre dans la messagerie, « Retour » ferme.
///
/// Le sujet et le corps sont écrits dans la langue de l'app (`getString` d'Android), d'où le `Traducteur` : seule
/// la formule hébraïque y reste en hébreu. Rien n'est gardé : le modèle vit le temps de la feuille.
@MainActor
@Observable
public final class DedicaceModele {
    private let traducteur: Traducteur

    /// « Que dédiez-vous ? » : la hitbodedout d'abord cochée, comme sur Android.
    public var objet: DedicaceObjet = .hitbodedut
    /// « Pour » : Léïlouy nichmat d'abord cochée, comme sur Android.
    public var intention: DedicaceIntention = .leilouy
    /// Le nom, tel que saisi (rogné dans l'e-mail).
    public var nom = ""
    /// Le mot facultatif pour l'équipe, tel que saisi.
    public var mot = ""

    /// « Écrire » touché alors que le nom manquait : le champ montre son erreur tant qu'il reste blanc.
    private var nomReclame = false
    /// Aucune messagerie n'a pris le lien : le message (le Toast d'Android) est à montrer.
    public private(set) var sansMessagerie = false
    /// La boîte a fini son travail (le lien ouvert, ou le message lu) : la vue se ferme (`dialogue.dismiss()`).
    public private(set) var termine = false

    public init(traducteur: Traducteur) {
        self.traducteur = traducteur
    }

    // MARK: Ce qui s'affiche

    /// Le titre de la boîte, « Dédicace » (section_dedicace).
    public var titre: Libelle { Libelle("section_dedicace") }
    /// Le texte d'aide en tête (section_dedicace_hint).
    public var aide: Libelle { Libelle("section_dedicace_hint") }
    /// « Que dédiez-vous ? » (dedicace_quoi).
    public var legendeObjet: Libelle { Libelle("dedicace_quoi") }
    /// « Pour » (dedicace_pour).
    public var legendeIntention: Libelle { Libelle("dedicace_pour") }
    /// L'indication du champ du nom (dedicace_nom).
    public var indicationNom: Libelle { Libelle("dedicace_nom") }
    /// L'indication du champ du mot (dedicace_mot).
    public var indicationMot: Libelle { Libelle("dedicace_mot") }
    /// Le bouton qui compose l'e-mail (dedicace_ecrire).
    public var libelleEcrire: Libelle { Libelle("dedicace_ecrire") }
    /// Le bouton qui ferme sans rien écrire (action_back).
    public var libelleRetour: Libelle { Libelle("action_back") }
    /// Le message quand aucune messagerie ne s'ouvre (dedicace_sans_messagerie).
    public var messageSansMessagerie: Libelle { Libelle("dedicace_sans_messagerie") }

    /// Les deux choix de « Que dédiez-vous ? », dans l'ordre.
    public var objets: [DedicaceObjet] { DedicaceObjet.allCases }
    /// Les cinq intentions, dans l'ordre.
    public var intentions: [DedicaceIntention] { DedicaceIntention.allCases }

    /// L'erreur du champ du nom (`nom.error`), « Indiquez le nom. » : seulement après « Écrire » avec un nom blanc,
    /// et effacée dès qu'un nom est saisi (comme l'erreur d'un EditText qui change).
    public var erreurNom: Libelle? {
        nomReclame && nom.estBlanc ? Libelle("dedicace_nom_manque") : nil
    }

    // MARK: L'e-mail

    /// Ce que l'on dédie, dans la langue de l'app : « Ma hitbodedout ».
    private var quoi: String {
        traducteur.texte(objet.libelle)
    }

    /// Le sujet, « Dédicace – Ma hitbodedout » (dedicace_sujet).
    public var sujet: String {
        traducteur.texte(Libelle("dedicace_sujet", .texte(quoi)))
    }

    /// Le corps de l'e-mail, comme Dedicace.corps l'écrit dans la langue de l'app ; la demande porte ce que l'on
    /// dédie, la première lettre en minuscule (« Je souhaite dédier ma hitbodedout : »).
    public var corps: String {
        let demande = Libelle("dedicace_corps_demande", .texte(DedicaceCourriel.premiereEnMinuscule(quoi)))
        return DedicaceCourriel.corps(intro: traducteur.texte(cle: "dedicace_corps_intro"),
                                      demande: traducteur.texte(demande),
                                      formule: intention.formule,
                                      nom: nom,
                                      mot: mot,
                                      fin: traducteur.texte(cle: "dedicace_corps_fin"))
    }

    /// Le lien mailto: complet, adressé à l'équipe (Dedicace.lien).
    public var lien: String {
        DedicaceCourriel.lien(sujet: sujet, corps: corps)
    }

    // MARK: Les actions

    /// « Écrire l'e-mail » : tant que le nom est blanc, rien ne s'ouvre et le champ montre son erreur (la boîte reste
    /// ouverte) ; sinon le lien mailto: à ouvrir dans la messagerie.
    public func ecrire() -> URL? {
        guard !nom.estBlanc else {
            nomReclame = true
            return nil
        }
        guard let url = URL(string: lien) else {
            // Un lien que l'URL refuserait ne s'ouvre dans aucune messagerie : on le dit de même.
            sansMessagerie = true
            return nil
        }
        return url
    }

    /// Ce que le système a fait du lien : pris par une messagerie, la boîte se ferme ; refusé, le message s'affiche
    /// (le Toast d'Android), et la boîte se fermera une fois le message lu.
    public func ouverture(reussie: Bool) {
        if reussie {
            termine = true
        } else {
            sansMessagerie = true
        }
    }

    /// Le message « Aucune messagerie trouvée » refermé : la boîte se ferme, comme sur Android après le Toast.
    public func messageLu() {
        sansMessagerie = false
        termine = true
    }
}
