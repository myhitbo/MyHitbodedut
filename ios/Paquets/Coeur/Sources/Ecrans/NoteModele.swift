import Foundation
import Observation
import Coeur

// La note de la hitbodedout (NoteDialog.kt) : une petite note libre, l'humeur avant et après, une gratitude et une
// chose à travailler (le journal enrichi, JournalPlus, 14/10 et 19/10). Le bravo la propose après une séance ;
// « Écrire » de l'écran de séance l'ouvre aussi, pour le jour même.
//
// Ce qu'on a écrit ne se perd plus d'un geste (revue du 29/09) : un toucher à côté ne ferme pas la fenêtre, et
// dès que la note change, le geste qui ferme non plus (`fermableParGeste`) ; le bouton dit alors « Ne pas
// enregistrer » au lieu de « Plus tard ».

/// La note d'un jour.
@MainActor
@Observable
public final class NoteModele {

    /// Le jour de la note (le jour de la séance, ou aujourd'hui).
    public let date: JourCivil
    private let magasin: Magasin
    /// La note du jour telle qu'elle était à l'ouverture.
    public let initiale: String

    /// La note, au plus `Journal.noteMax` unités (InputFilter.LengthFilter).
    public private(set) var texte: String
    /// L'humeur avant et après, de 1 à 5 ; 0 : aucune.
    public private(set) var avant: Int
    public private(set) var apres: Int
    /// Une gratitude et une chose à travailler, sur une ligne, au plus `JournalPlus.gratitudeMax` unités.
    public private(set) var gratitude: String
    public private(set) var travail: String

    public init(date: JourCivil, magasin: Magasin) {
        self.date = date
        self.magasin = magasin
        let note = magasin.journal.record(date)?.note ?? ""
        initiale = note
        texte = note
        let plus = magasin.journal.lirePlus(date)
        avant = plus.avant
        apres = plus.apres
        gratitude = plus.gratitude
        travail = plus.travail
    }

    // MARK: Ce qui s'affiche

    /// « Note de la hitbodedout ».
    public var titre: Libelle { Libelle("note_title") }

    /// Le hassid qui écrit, au féminin s'il le faut (120 points de haut).
    public var image: String {
        Personnage.pour(Adresse.parse(magasin.reglages.adresse), "char_writing")
    }

    /// L'indication du champ de la note (quatre lignes, aligné en haut au début).
    public var indicationNote: Libelle { Libelle("note_hint") }
    public var titreAvant: Libelle { Libelle("journal_humeur_avant") }
    public var titreApres: Libelle { Libelle("journal_humeur_apres") }
    public var indicationGratitude: Libelle { Libelle("journal_gratitude_hint") }
    public var indicationTravail: Libelle { Libelle("journal_travail_hint") }

    /// Les cinq visages, du plus sombre au plus clair.
    public var humeurs: [String] { JournalPlus.humeurs }

    /// L'opacité d'un visage : 1 s'il est choisi, 0,35 sinon. `humeur` : `avant` ou `apres` ; `rang` de 0 à 4.
    public static func opacite(humeur: Int, rang: Int) -> Double {
        humeur == rang + 1 ? 1 : 0.35
    }

    /// Ce que VoiceOver dit d'un visage : « 3/5 ».
    public static func etiquette(rang: Int) -> String {
        "\(rang + 1)/5"
    }

    /// La note a changé (blancs du début et de la fin mis à part) : seule la note compte, comme sur Android.
    public var modifiee: Bool {
        !texte.rogne.egalUnites(initiale.rogne)
    }

    /// Le geste qui ferme (glisser la feuille vers le bas) n'est permis que tant que la note n'a pas changé ;
    /// un toucher à côté ne ferme jamais.
    public var fermableParGeste: Bool {
        !modifiee
    }

    public var libelleEnregistrer: Libelle { Libelle("action_save") }

    /// « Plus tard », ou « Ne pas enregistrer » une fois la note changée.
    public var libelleFermer: Libelle {
        Libelle(modifiee ? "note_discard" : "action_later")
    }

    // MARK: Les gestes

    /// La note tapée, coupée à `Journal.noteMax` unités.
    public func ecrire(_ nouveau: String) {
        texte = nouveau.premieresUnites(Journal.noteMax)
    }

    /// La gratitude tapée, coupée à `JournalPlus.gratitudeMax` unités.
    public func ecrireGratitude(_ nouveau: String) {
        gratitude = nouveau.premieresUnites(JournalPlus.gratitudeMax)
    }

    /// La chose à travailler, coupée de même.
    public func ecrireTravail(_ nouveau: String) {
        travail = nouveau.premieresUnites(JournalPlus.gratitudeMax)
    }

    /// Un visage touché : choisi, ou retiré s'il l'était (rang de 0 à 4).
    public func choisirAvant(_ rang: Int) {
        avant = avant == rang + 1 ? 0 : rang + 1
    }

    public func choisirApres(_ rang: Int) {
        apres = apres == rang + 1 ? 0 : rang + 1
    }

    /// « Enregistrer » : la note, rognée (sur un jour sans hitbodedout, elle ne le valide pas ; une note seule
    /// effacée retire la ligne), puis l'humeur, la gratitude et la chose à travailler, rognées (un jour vide est
    /// retiré du journal enrichi). La fenêtre se ferme ensuite, enregistrée ou non.
    public func enregistrer() async throws {
        let note = texte.rogne
        let plus = JournalPlus.Plus(avant: avant, apres: apres, gratitude: gratitude.rogne, travail: travail.rogne)
        let date = self.date
        try await magasin.modifierJournal { journal in
            // Le journal enrichi d'abord (NoteDialog) : il garde la ligne d'une note effacée (FDONNEES-14).
            journal.ecrirePlus(plus, pour: date)
            journal.setNote(date: date, note: note)
        }
    }
}
