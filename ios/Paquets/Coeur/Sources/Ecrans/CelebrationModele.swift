import Foundation
import Observation
import Coeur

// Le bravo de fin de séance (CelebrationActivity.kt, activity_celebration.xml) : le hassid danse, et l'app dit
// bravo ; puis « Continuer » propose la note de la séance (NoteModele), dans cet ordre (revue du 29/09).
//
// Il s'ouvre une fois par séance close, où qu'on soit au retour : sur l'écran de séance s'il était resté
// ouvert, sur l'accueil si la séance s'est achevée téléphone posé (`CelebrationDemande.prendre`, que l'accueil
// appelle aussi). Une séance abandonnée ouvre le même écran, sans danse : « ’Hazak », et un mot de 'hizouk du
// moment « relance » (demande du 28/09).
//
// La danse (DanseMesure de Coeur) et les notes qui montent sont l'affaire de la vue ; le modèle dit les
// poses, si l'on danse, et la mesure. Rien ne danse sous « Réduire les animations » : la pose fixe reste.

/// Ce qui ouvre le bravo : les minutes inscrites et le jour de la note qu'il proposera, ou un abandon.
public struct CelebrationDemande: Sendable, Hashable {
    /// Les minutes inscrites ; 0 après un abandon.
    public let minutes: Int
    /// Une séance abandonnée : « ’Hazak », sans danse ni note ni partage.
    public let annulee: Bool
    /// Le jour de la séance, dont « Continuer » ouvre la note ; nil : pas de note.
    public let dateNote: JourCivil?

    public init(minutes: Int, dateNote: JourCivil?) {
        self.init(minutes: minutes, annulee: false, dateNote: dateNote)
    }

    private init(minutes: Int, annulee: Bool, dateNote: JourCivil?) {
        self.minutes = minutes
        self.annulee = annulee
        self.dateNote = dateNote
    }

    /// Le bravo en attente dans les réglages (`Store.takePendingCelebration`) ; une date de note qui n'est pas
    /// une vraie date ne propose pas de note.
    public init(_ celebration: Reglages.Celebration) {
        self.init(minutes: celebration.minutes, annulee: false,
                  dateNote: celebration.dateNote.flatMap { Journal.dateValide($0) })
    }

    /// Après une séance abandonnée (`CelebrationActivity.annulation`).
    public static let annulation = CelebrationDemande(minutes: 0, annulee: true, dateNote: nil)

    /// `showIfPending` : le bravo en attente, retiré avant d'être ouvert (deux écrans qui reprennent la main
    /// l'un après l'autre ne l'ouvriraient pas deux fois) ; nil s'il n'y en a pas. Le retrait se voit tout de
    /// suite ; une écriture refusée n'empêche pas le bravo (la prochaine écriture des réglages emportera le
    /// retrait).
    @MainActor
    public static func prendre(_ magasin: Magasin) async -> CelebrationDemande? {
        var reglages = magasin.reglages
        guard let celebration = Store.takePendingCelebration(reglages: &reglages) else { return nil }
        do {
            try await magasin.modifierReglages { $0 = reglages }
        } catch {
            // Le retrait reste en mémoire.
        }
        return CelebrationDemande(celebration)
    }
}

/// Ce que fait « Continuer ».
public enum CelebrationSuite: Sendable, Hashable {
    /// L'écran se ferme.
    case fermer
    /// La note de ce jour s'ouvre (NoteModele) ; le bravo se ferme quand elle se ferme, enregistrée ou non.
    case note(JourCivil)
}

/// Le bravo, ou « ’Hazak ».
@MainActor
@Observable
public final class CelebrationModele {

    /// La version web, jointe à chaque partage (CelebrationActivity.LIEN_WEB).
    public static let lienWeb = "https://hil123.github.io/myhitbodedut-web/"
    /// Les notes et l'étoile qui montent de la scène, tirées au hasard, une par temps et 180 ms.
    public static let signes = ["\u{266A}", "\u{266B}", "\u{266A}", "\u{2726}"]
    public static let intervalleNotes: Int64 = DanseMesure.tempsMs + 180
    /// La hauteur du saut, en points.
    public static let saut = 16.0
    /// Sous 720 points de haut, la scène prend 42 % de la hauteur de l'écran, pour que « Bravo » et
    /// « Continuer » se voient sans défiler (15/10).
    public static let petitEcran = 720.0
    public static let partScenePetitEcran = 0.42

    public let demande: CelebrationDemande
    private let magasin: Magasin
    private let contenus: ContenusApp
    private let horloge: any Horloge
    /// « fr », « en » ou « he ».
    public let langue: String
    public let debug: Bool
    private let melange: @Sendable ([String]) -> [String]

    /// Le texte de 'hizouk « relance » après un abandon ; nil : la carte est cachée.
    public private(set) var carteId: String? = nil
    private var chizuk: Chizuk? = nil
    private var charge = false

    public init(demande: CelebrationDemande, magasin: Magasin, contenus: ContenusApp, horloge: any Horloge,
                langue: String, debug: Bool,
                melange: @escaping @Sendable ([String]) -> [String] = { $0.shuffled() }) {
        self.demande = demande
        self.magasin = magasin
        self.contenus = contenus
        self.horloge = horloge
        self.langue = ChizukCard.language(langue)
        self.debug = debug
        self.melange = melange
    }

    /// L'écran paraît : après un abandon, un mot du moment « relance » est tiré, une fois.
    public func charger() async {
        guard !charge else { return }
        charge = true
        guard demande.annulee else { return }
        guard let lu = try? await contenus.chizuk() else { return }
        chizuk = lu
        var reglages = magasin.reglages
        carteId = SeanceTirage.tirer(lu, moment: .relance, debug: debug, reglages: &reglages, melange: melange)
        do {
            try await magasin.modifierReglages { $0 = reglages }
        } catch {
            // Le sac reste en mémoire.
        }
    }

    // MARK: Ce qui s'affiche

    /// « Bravo ! », « Bravo, Tsadik ! » ou « Bravo, Tsadeket ! » ; après un abandon, « Courage ! », « ’Hazak ! »
    /// ou « ’Hizki ! ». Sans adresse choisie, le neutre.
    public var titre: Libelle {
        Libelle(demande.annulee ? Adresse.hazak(adresse) : Adresse.bravo(adresse))
    }

    /// « 20 minutes de hitbodedout » (pluriel) ; après un abandon, l'encouragement ; nil (caché) pour une
    /// séance de 0 minute.
    public var sousTitre: Libelle? {
        if demande.annulee { return Libelle("annulation_subtitle") }
        guard demande.minutes > 0 else { return nil }
        return Libelle.pluriel("celebration_minutes", quantite: demande.minutes, .entier(demande.minutes))
    }

    /// La pose A, toujours montrée : la danse (jambe droite levée) ; un jour sur trois la guitare, un autre le
    /// pouce levé (12/10, 13/10) ; après un abandon, le personnage qui marche. Au féminin s'il le faut.
    public var poseA: String {
        if demande.annulee { return Personnage.pour(adresse, "char_walking") }
        return Personnage.pour(adresse, poseDuJour ?? "char_dancing")
    }

    /// La pose B, superposée à la pose A et invisible au repos (opacité 0), que la danse fait paraître à chaque
    /// réception : la jambe gauche levée ; la même image les jours de guitare et de pouce levé. nil après un
    /// abandon.
    public var poseB: String? {
        if demande.annulee { return nil }
        return Personnage.pour(adresse, poseDuJour ?? "char_dancing_joy")
    }

    /// Le personnage danse (sauf après un abandon, et sauf sous « Réduire les animations », que la vue lit).
    public var danse: Bool {
        !demande.annulee
    }

    /// Où en est le danseur `millis` après le début de la danse : une mesure de deux temps de 480 ms. La vue
    /// applique : décalage vertical −saut × hauteur, échelle (1 + 0,04 × flexion ; 1 − 0,05 × flexion) depuis
    /// le bas au centre, rotation 6° × balance, opacité de la pose A 1 − poseB, de la pose B poseB.
    public static func pas(_ millis: Int64) -> DanseMesure.Pas {
        let mesure = 2 * DanseMesure.tempsMs
        let dans = Kotlin.floorMod(Int(millis % mesure), Int(mesure))
        return DanseMesure.pas(Float(dans) / Float(mesure))
    }

    /// Après un abandon, la carte compacte du moment « relance » ; nil sinon, ou sans texte affichable.
    public var carte: SeanceCarteChizuk? {
        guard demande.annulee, let chizuk, let id = carteId, let item = chizuk.item(id) else { return nil }
        return SeanceCarteChizuk(item: item, chizuk: chizuk, moment: .relance,
                                 mode: SeanceCarteChizuk.mode(magasin.reglages, langue: langue), langue: langue,
                                 adresse: adresse)
    }

    public var libelleContinuer: Libelle { Libelle("celebration_continue") }

    /// « Partager ma hitbodedout » : une séance faite, d'au moins une minute.
    public var partageVisible: Bool {
        !demande.annulee && demande.minutes > 0
    }

    public var libellePartager: Libelle { Libelle("partage_action") }
    /// Le titre de la feuille de partage.
    public var titrePartage: Libelle { Libelle("partage_choix") }

    // MARK: Les gestes

    /// « Continuer » : la note du jour de la séance, s'il y en a une à proposer ; sinon l'écran se ferme.
    public func continuer() -> CelebrationSuite {
        guard !demande.annulee, let date = demande.dateNote else { return .fermer }
        return .note(date)
    }

    /// Les lignes du texte partagé : la séance faite, la série si elle a au moins deux jours, le lien.
    public var lignesPartage: [Libelle] {
        let minutes = demande.minutes
        var lignes = [Libelle("partage_texte",
                              .libelle(Libelle.pluriel("partage_minutes", quantite: minutes, .entier(minutes))))]
        let serie = Store.streak(journal: magasin.journal, reglages: magasin.reglages, aujourdhui: horloge.aujourdhui,
                                 fuseauTelephone: horloge.fuseau.identifiant)
        if serie >= 2 {
            lignes.append(Libelle("partage_serie", .entier(serie)))
        }
        lignes.append(Libelle("partage_lien", .texte(CelebrationModele.lienWeb)))
        return lignes
    }

    /// Le texte que la feuille de partage envoie, ses lignes résolues dans la langue de l'app
    /// (`Traducteur.texte`) et jointes d'un saut de ligne.
    public func textePartage(_ resoudre: (Libelle) -> String) -> String {
        lignesPartage.map(resoudre).joined(separator: "\n")
    }

    // MARK: Aides

    private var adresse: Adresse? {
        Adresse.parse(magasin.reglages.adresse)
    }

    /// `floorMod(LocalDate.now().toEpochDay(), 3)` : 1, la guitare ; 2, le pouce levé ; sinon la danse.
    private var poseDuJour: String? {
        switch Kotlin.floorMod(horloge.aujourdhui.jourJulien - 2_440_588, 3) {
        case 1: return "char_guitar"
        case 2: return "char_thumbs_up"
        default: return nil
        }
    }
}
