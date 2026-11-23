import Foundation
import Observation
import Coeur

// La note d'un jour (NoteDialog.kt d'Android), telle que le journal l'ouvre en touchant une ligne : la note
// libre, l'humeur avant et après (1 à 5), une gratitude et une chose à travailler (le journal enrichi,
// JournalPlus, 14/10 et 19/10). Ce qu'on a écrit ne se perd pas d'un geste (revue du 29/09) : un toucher à
// côté ne ferme jamais la fenêtre, et dès que la note change, le geste de retour ne la ferme plus et le bouton
// de renoncement dit « Ne pas enregistrer » au lieu de « Plus tard ».
//
// La même fenêtre suit la séance (le bravo propose la note du jour) : ce modèle ne dépend que du Magasin et du
// jour, pour servir aux deux.

/// Une des cinq humeurs proposées (JournalPlus.HUMEURS).
public struct JournalHumeur: Sendable, Hashable, Identifiable {
    /// De 1 (la plus lourde) à 5 (la plus légère).
    public let rang: Int
    /// L'émoji, en 26 pt.
    public let emoji: String
    /// Ce que dit le lecteur d'écran : « Humeur 3 sur 5 » (`contentDescription` de NoteDialog.kt,
    /// `journal_humeur_n`).
    public let accessibilite: Libelle

    public var id: Int { rang }

    public init(rang: Int, emoji: String) {
        self.rang = rang
        self.emoji = emoji
        accessibilite = Libelle("journal_humeur_n", .entier(rang))
    }
}

/// La fenêtre de la note d'un jour.
@MainActor
@Observable
public final class JournalNoteModele {

    /// Les cinq humeurs, de la plus lourde à la plus légère.
    public static let humeurs: [JournalHumeur] = JournalPlus.humeurs.enumerated().map { paire in
        JournalHumeur(rang: paire.offset + 1, emoji: paire.element)
    }

    /// L'opacité d'une humeur choisie, et d'une humeur qui ne l'est pas.
    public static let opaciteChoisie: Double = 1
    public static let opaciteAutre: Double = 0.35

    // Les textes de la fenêtre (NoteDialog.kt).
    public let titre = Libelle("note_title")
    public let indicationNote = Libelle("note_hint")
    public let titreAvant = Libelle("journal_humeur_avant")
    public let titreApres = Libelle("journal_humeur_apres")
    public let indicationGratitude = Libelle("journal_gratitude_hint")
    public let indicationTravail = Libelle("journal_travail_hint")
    public let boutonEnregistrer = Libelle("action_save")
    /// Le hassid qui écrit, au-dessus du champ (120 pt de haut, ajusté sans rogner).
    public let image = "char_writing"

    private let magasin: Magasin

    /// Le jour de la note.
    public let date: JourCivil
    /// La note telle qu'elle était à l'ouverture.
    public let initiale: String
    /// La note en cours d'écriture : `modifierNote` la change.
    public private(set) var note: String
    /// L'humeur avant et après, de 1 à 5 ; 0 si elle n'est pas dite.
    public private(set) var avant: Int
    public private(set) var apres: Int
    /// La gratitude et la chose à travailler, en cours d'écriture (une ligne chacune).
    public private(set) var gratitude: String
    public private(set) var travail: String

    /// La note du jour `date`, et son journal enrichi, tels que le magasin les garde.
    public init(magasin: Magasin, date: JourCivil) {
        self.magasin = magasin
        self.date = date
        let journal = magasin.journal
        initiale = journal.record(date)?.note ?? ""
        note = initiale
        let plus = journal.lirePlus(date)
        avant = plus.avant
        apres = plus.apres
        gratitude = plus.gratitude
        travail = plus.travail
    }

    // MARK: Ce qui s'affiche

    /// La note a changé depuis l'ouverture, blancs des bouts mis à part (`trim()`) : seule la note compte, ni
    /// l'humeur ni la gratitude, comme sur Android.
    public var change: Bool {
        !note.rogne.egalUnites(initiale.rogne)
    }

    /// Le geste de retour (glisser vers le bas, bouton retour) ferme-t-il la fenêtre ? Pas quand la note a
    /// changé. Un toucher à côté ne la ferme jamais (`interactiveDismissDisabled`).
    public var fermableParGeste: Bool {
        !change
    }

    /// Le bouton qui ferme sans enregistrer : « Plus tard », ou « Ne pas enregistrer » quand la note a changé.
    public var boutonRenoncer: Libelle {
        change ? Libelle("note_discard") : Libelle("action_later")
    }

    /// Cette humeur est-elle choisie, avant ou après ?
    public func avantChoisi(_ rang: Int) -> Bool { avant == rang }
    public func apresChoisi(_ rang: Int) -> Bool { apres == rang }

    // MARK: Les actions

    /// Le texte de la note, coupé à 4 000 unités UTF-16 (`LengthFilter(Store.NOTE_MAX)`).
    public func modifierNote(_ texte: String) {
        note = texte.premieresUnites(Journal.noteMax)
    }

    /// La gratitude, coupée à 200 unités UTF-16 (`LengthFilter(GRATITUDE_MAX)`).
    public func modifierGratitude(_ texte: String) {
        gratitude = texte.premieresUnites(JournalPlus.gratitudeMax)
    }

    /// La chose à travailler, coupée à 200 unités UTF-16.
    public func modifierTravail(_ texte: String) {
        travail = texte.premieresUnites(JournalPlus.gratitudeMax)
    }

    /// Touche l'humeur avant `rang` : la choisit, ou la retire si elle l'était déjà.
    public func toucherAvant(_ rang: Int) {
        avant = JournalNoteModele.bascule(avant, rang)
    }

    /// Touche l'humeur après `rang` : la choisit, ou la retire si elle l'était déjà.
    public func toucherApres(_ rang: Int) {
        apres = JournalNoteModele.bascule(apres, rang)
    }

    /// « Enregistrer » : la note sans ses blancs des bouts (Store.setNote : sur un jour sans hitbodedout elle ne
    /// le valide pas, une note seule effacée retire la ligne), puis le journal enrichi (un jour vide est
    /// retiré). Une seule écriture du journal.
    public func enregistrer() async throws {
        let date = self.date
        let texte = note.rogne
        let plus = JournalPlus.Plus(avant: avant, apres: apres, gratitude: gratitude.rogne, travail: travail.rogne)
        try await magasin.modifierJournal { journal in
            // Le journal enrichi d'abord (NoteDialog) : il garde la ligne d'une note effacée (FDONNEES-14).
            journal.ecrirePlus(plus, pour: date)
            Store.setNote(journal: &journal, date: date, note: texte)
        }
    }

    private static func bascule(_ actuel: Int, _ rang: Int) -> Int {
        actuel == rang ? 0 : rang
    }
}
