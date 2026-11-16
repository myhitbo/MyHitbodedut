import Foundation
import Observation
import Coeur

/// L'onglet Zmanim (ZmanimActivity.kt) : le lieu, le jour montré et ses horaires.
///
/// Un modèle d'écran n'affiche rien : la vue SwiftUI de l'app le lit et appelle ses actions. Toute sa
/// logique passe par les règles de Coeur ; lui se compile et se teste sous Linux, la vue non.
///
/// Le lieu, Israël ou diaspora et l'allumage sont les réglages du `Magasin`, lus à chaque fois (un lieu choisi
/// ailleurs se voit ici) et écrits par ses actions ; le jour montré part d'aujourd'hui, dans le fuseau du
/// téléphone (`LocalDate.now()` d'Android), et se déplace sur place.
///
/// L'écran, dans l'ordre d'Android (14/10, « trop de choses avant les זמנים ») : le bandeau (titre, lieu), la
/// carte du jour (`carte`), trois boutons (halakha, hilloulot, calendrier), deux autres (vol, boussole), les
/// horaires (`lignes`, ou l'invitation à choisir un lieu), puis Birkat haLevana, la hilloula et la halakha du jour,
/// chacune dans sa carte et masquable dans les réglages, l'allumage des bougies, Ta'hanoun de fin de Tichri (en
/// Sfard seulement), le pied.
@MainActor
@Observable
public final class ZmanimModele {
    private let magasin: Magasin
    private let horloge: any Horloge
    private let contenus: ContenusApp?
    private let tableHilloulot: ZmanimHilloulotTable?

    /// Le jour montré.
    public var jour: JourCivil

    /// Le choix du lieu (ChoixLieu) : le dialogue, la position. nil sans traducteur (un aperçu) : le bandeau et la
    /// carte « Choisir le lieu » ne s'ouvrent alors sur rien.
    public let choixLieu: LieuModele?

    /// « fr », « en » ou « he » : celle du traducteur, le français sans lui.
    public let langue: String

    /// Les villes, les livres de la halakha, la table des hilloulot ; vides tant que `apparaitre()` ne les a pas
    /// lus.
    public private(set) var sources: ZmanimSources = .vide
    /// Les contenus ont été lus (une fois pour toutes).
    public private(set) var charge = false

    /// Le jour où l'écran a été quitté (`disparaitre()`).
    @ObservationIgnored private var quitteLe: JourCivil?

    /// `contenus`, `hilloulot` : ce qu'il faut pour la halakha, la hilloula et la liste des villes ; `localisation`
    /// et `autorisation` : la position du téléphone ; `traducteur` : la langue de l'app, et le nom du lieu écrit
    /// dans les réglages. Sans eux (un aperçu), l'écran montre la carte du jour, les horaires et Levana.
    public init(magasin: Magasin, horloge: any Horloge, contenus: ContenusApp? = nil,
                hilloulot: ZmanimHilloulotTable? = nil, localisation: (any Localisation)? = nil,
                autorisation: (any LieuAutorisation)? = nil, traducteur: Traducteur? = nil) {
        self.magasin = magasin
        self.horloge = horloge
        self.contenus = contenus
        tableHilloulot = hilloulot
        jour = horloge.aujourdhui
        langue = traducteur?.langue ?? Traducteur.repli
        if let traducteur {
            choixLieu = LieuModele(magasin: magasin, contenus: contenus, localisation: localisation,
                                   autorisation: autorisation, horloge: horloge, traducteur: traducteur)
        } else {
            choixLieu = nil
        }
    }

    /// Un lieu, un jour et des réglages donnés d'avance, dans un magasin en mémoire, l'horloge arrêtée à midi
    /// de ce jour : pour les tests et les aperçus.
    public convenience init(lieu: Zmanim.Lieu?, jour: JourCivil, enIsrael: Bool, allumage: Int = Zmanim.allumageDefaut) {
        var reglages = Reglages()
        if let lieu {
            reglages.setLieuZmanim(lieu, ville: nil, maintenant: 0)
        }
        reglages.setInIsrael(enIsrael)
        reglages.setAllumage(allumage)
        let fuseau = lieu.flatMap { Fuseau($0.fuseau) } ?? .utc
        self.init(magasin: Magasin.enMemoire(Enregistrement(reglages: reglages)),
                  horloge: HorlogeFixe(DateHeure(jour, heure: 12), fuseau: fuseau))
    }

    // MARK: Les réglages

    /// nil tant qu'aucun lieu n'est choisi : l'écran propose alors d'en choisir un.
    public var lieu: Zmanim.Lieu? {
        magasin.reglages.lieuZmanim
    }

    /// Israël ou diaspora (Store.inIsrael) : le réglage, sinon ce que dit le fuseau du téléphone.
    public var enIsrael: Bool {
        magasin.reglages.inIsrael(fuseauTelephone: horloge.fuseau.identifiant)
    }

    /// Les minutes d'allumage avant la chki'a, parmi Zmanim.allumages.
    public var allumage: Int {
        magasin.reglages.allumage
    }

    /// Le jour montré est-il aujourd'hui ?
    public var estAujourdhui: Bool {
        jour == horloge.aujourdhui
    }

    /// Ce dont dépend ce qu'on montre du jour.
    public var contexte: ZmanimContexte {
        ZmanimContexte(reglages: magasin.reglages, fuseauTelephone: horloge.fuseau, langue: langue, sources: sources)
    }

    // MARK: Le bandeau

    /// « Zmanim du jour » : 21 pt, gras, blanc.
    public var titre: Libelle {
        Libelle("zmanim_title")
    }

    /// L'illustration du bandeau, sur sa plaque claire : l'étude de la Torah.
    public var image: String {
        "char_torah"
    }

    /// La pastille du lieu : « Jérusalem · Israël ». nil sans lieu : la grande carte « Choisir le lieu » suffit,
    /// pas de seconde pastille dans le bandeau (29/10). Touchée, elle ouvre le choix du lieu.
    public var lieuTexte: Libelle? {
        guard let lieu else { return nil }
        let region = Libelle(enIsrael ? "region_israel" : "region_diaspora")
        return Libelle("zmanim_lieu_detail", .texte(lieu.nom), .libelle(region))
    }

    // MARK: La carte du jour et les boutons

    /// La carte du jour montré : date hébraïque, date civile, fêtes, ajouts, partage.
    public var carte: ZmanimCarteJour {
        ZmanimVueJour.carte(jour, contexte)
    }

    /// Le jour hébraïque du jour montré.
    public var jourHebreu: CalendrierJuif.Jour {
        CalendrierJuif.jour(jour, enIsrael: enIsrael)
    }

    /// Sous la carte : « Halakha yomit », « Hilloulot », « Calendrier », de même largeur.
    public var boutons: [ZmanimBouton] {
        [ZmanimBouton(id: "halakha", libelle: Libelle("zmanim_bouton_halakha"), icone: nil, route: .halakha(jour)),
         ZmanimBouton(id: "hilloulot", libelle: Libelle("zmanim_bouton_hilloulot"), icone: nil, route: .hilloulot(jour)),
         ZmanimBouton(id: "calendrier", libelle: Libelle("zmanim_calendrier"), icone: nil, route: .calendrier)]
    }

    /// La seconde rangée (29/10) : « ✈ En vol », « 🧭 Boussole prière ».
    public var boutonsBas: [ZmanimBouton] {
        [ZmanimBouton(id: "vol", libelle: Libelle("zmanim_bouton_vol"), icone: "✈", route: .vol),
         ZmanimBouton(id: "boussole", libelle: Libelle("zmanim_bouton_boussole"), icone: "🧭", route: .boussole)]
    }

    // MARK: Les horaires

    /// Les horaires du jour montré (JourAffiche.horaires), allumage et sortie compris ; vide sans lieu.
    public var horaires: [Zmanim.Zman] {
        guard let lieu else { return [] }
        return JourAffiche.horaires(lieu: lieu, date: jour, enIsrael: enIsrael, minutes: allumage)
    }

    /// Les lignes de la carte des horaires : nom, heure, méthode ; vide sans lieu.
    public var lignes: [ZmanimLigne] {
        ZmanimVueJour.lignes(jour, contexte)
    }

    /// Sans lieu, la carte des horaires dit « Choisissez une ville, ou votre position… » et montre le lien
    /// « Choisir le lieu » (16 pt, gras, couleur de la marque), qui ouvre le choix du lieu.
    public var sansLieu: Bool {
        lieu == nil
    }

    public var invitationLieu: Libelle {
        Libelle("zmanim_sans_lieu")
    }

    public var choisirLieuLibelle: Libelle {
        Libelle("zmanim_choisir_lieu")
    }

    // MARK: Sous les horaires

    /// Birkat haLevana du jour montré ; nil si elle est masquée dans les réglages.
    public var levana: ZmanimLevana? {
        ZmanimVueJour.levana(jour, contexte)
    }

    /// La hilloula du jour montré ; nil si elle est masquée, illisible ou vide.
    public var hilloula: ZmanimHilloula? {
        ZmanimVueJour.hilloula(jour, contexte)
    }

    /// La halakha du jour montré ; nil si elle est masquée ou absente.
    public var halakha: ZmanimHalakha? {
        ZmanimVueJour.halakha(jour, contexte)
    }

    /// La carte de l'allumage des bougies, touchée : le dialogue des minutes.
    public var allumageCarte: ZmanimReglage {
        let minutes = allumage
        let mukafChoma = magasin.reglages.mukafChoma
        var options: [ZmanimOption] = []
        for m in Zmanim.allumages {
            options.append(ZmanimOption(id: m, libelle: ZmanimModele.libelleAllumage(m, mukafChoma: mukafChoma),
                                        choisie: m == minutes))
        }
        // À Jérusalem, l'usage est d'allumer 40 minutes avant : proposé, jamais imposé.
        var proposition: Libelle?
        if mukafChoma && minutes != ZmanimModele.allumageJerusalem {
            proposition = Libelle("reglage_allumage_proposition")
        }
        return ZmanimReglage(titre: Libelle("reglage_allumage"),
                             valeur: ZmanimModele.libelleAllumage(minutes, mukafChoma: mukafChoma),
                             proposition: proposition, options: options)
    }

    /// La carte de Ta'hanoun en fin de Tichri : au choix en Sfard seulement ; nil sinon. Ses options : « Dit
    /// après Isrou 'hag » (id 0), « Pas dit jusqu'à Roch 'Hodech 'Hechvan » (id 1).
    public var tahanounCarte: ZmanimReglage? {
        let reglages = magasin.reglages
        guard reglages.siddurNusah == .sefard else { return nil }
        let sans = reglages.sansTahanounFinTichri
        return ZmanimReglage(titre: Libelle("reglage_tahanoun_tichri"),
                             valeur: Libelle(sans ? "reglage_tahanoun_tichri_sans" : "reglage_tahanoun_tichri_dit"),
                             proposition: nil,
                             options: [ZmanimOption(id: 0, libelle: Libelle("reglage_tahanoun_tichri_dit"), choisie: !sans),
                                       ZmanimOption(id: 1, libelle: Libelle("reglage_tahanoun_tichri_sans"), choisie: sans)])
    }

    /// Le pied : la méthode, la source des villes.
    public var pied: [Libelle] {
        ZmanimVueJour.pied
    }

    /// Le contenu de l'image de partage du jour montré (« Partager ce jour ↗ » de la carte).
    public var partage: PartageContenu {
        PartageContenu.pour(jour, contexte)
    }

    // MARK: Les actions

    /// À chaque apparition de l'écran (onResume) : lit les contenus la première fois ; laissé ouvert jusqu'au
    /// lendemain, l'écran qui montrait le jour d'alors passe à aujourd'hui (un autre jour choisi exprès reste) ;
    /// la position du téléphone se reprend sans bruit (28/10), si elle est le lieu et si elle est déjà permise.
    public func apparaitre() async {
        if !charge {
            sources = await ZmanimSources.lire(contenus: contenus, hilloulot: tableHilloulot)
            charge = true
        }
        let aujourdhui = horloge.aujourdhui
        if let avant = quitteLe, avant != aujourdhui, jour == avant {
            jour = aujourdhui
        }
        quitteLe = nil
        if let choixLieu {
            await choixLieu.charger()
            do {
                try await choixLieu.rafraichir()
            } catch {
                // Une reprise silencieuse qui n'a pu s'écrire : le lieu d'avant reste, rien n'est dit.
            }
        }
    }

    /// L'écran est quitté (onPause) : retient le jour, pour `apparaitre()`.
    public func disparaitre() {
        quitteLe = horloge.aujourdhui
    }

    public func jourSuivant() {
        jour = jour.plus(jours: 1)
    }

    public func jourPrecedent() {
        jour = jour.plus(jours: -1)
    }

    public func revenirAujourdhui() {
        jour = horloge.aujourdhui
    }

    /// Le bandeau ou la carte « Choisir le lieu » : le dialogue du choix du lieu.
    public func montrerChoixLieu() {
        choixLieu?.montrer()
    }

    /// L'allumage choisi (ZmanimActivity.choisirAllumage), parmi Zmanim.allumages.
    public func choisirAllumage(_ minutes: Int) async throws {
        try await magasin.modifierReglages { $0.setAllumage(minutes) }
    }

    /// Ta'hanoun en fin de Tichri, en Sfard (ZmanimActivity.choisirTahanounTichri) : vrai, pas dit jusqu'à Roch
    /// 'Hodech 'Hechvan.
    public func choisirTahanounTichri(sans: Bool) async throws {
        try await magasin.modifierReglages { $0.setSansTahanounFinTichriSfard(sans) }
    }

    /// Le lieu choisi, une ville ou une position (ChoixLieu.kt) : il règle aussi Israël ou diaspora, et retient
    /// l'instant du choix.
    public func choisirLieu(_ lieu: Zmanim.Lieu, ville: Ville?) async throws {
        let maintenant = horloge.maintenant
        try await magasin.modifierReglages { $0.setLieuZmanim(lieu, ville: ville, maintenant: maintenant) }
    }

    // MARK: Les règles

    /// À Jérusalem, l'usage d'allumer 40 minutes avant la chki'a.
    public static let allumageJerusalem = 40

    /// « 18 min avant la chki'a » ; « 40 min avant la chki'a · coutume de Jérusalem » quand Jérusalem est choisie.
    public static func libelleAllumage(_ minutes: Int, mukafChoma: Bool) -> Libelle {
        if minutes == allumageJerusalem && mukafChoma {
            return Libelle("reglage_allumage_jerusalem", .entier(minutes))
        }
        return Libelle("reglage_allumage_valeur", .entier(minutes))
    }
}

/// Un des boutons sous la carte du jour (ZmanimActivity.bouton) : contour (style secondaire), même largeur que ses
/// voisins (8 pt entre eux), texte de 9 à 14 pt réduit pour tenir ; une icône devant, au choix, sur une ligne.
public struct ZmanimBouton: Sendable, Equatable, Identifiable {
    public let id: String
    public let libelle: Libelle
    /// « ✈ » ou « 🧭 », posé devant le texte avec deux espaces ; nil sinon.
    public let icone: String?
    public let route: ZmanimRoute
}

/// Une option d'un dialogue à choix unique (minutes d'allumage, Ta'hanoun).
public struct ZmanimOption: Sendable, Equatable, Identifiable {
    /// Les minutes d'allumage ; 0 ou 1 pour Ta'hanoun.
    public let id: Int
    public let libelle: Libelle
    public let choisie: Bool
}

/// Une carte de réglage touchable (allumage, Ta'hanoun) : le titre (15 pt, encre), la valeur (13 pt, atténuée), la
/// proposition (13 pt, couleur de la marque) ; touchée, un dialogue à choix unique titré comme elle, qui se ferme
/// au choix.
public struct ZmanimReglage: Sendable, Equatable {
    public let titre: Libelle
    public let valeur: Libelle
    public let proposition: Libelle?
    public let options: [ZmanimOption]
}
