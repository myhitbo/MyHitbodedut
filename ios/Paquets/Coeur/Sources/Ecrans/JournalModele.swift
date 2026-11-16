import Foundation
import Observation
import Coeur

// Le journal (JournalActivity.kt d'Android) : l'historique des séances, avec les notes laissées après chacune,
// et le journal enrichi (JournalPlus.kt : sujets, humeur, gratitude, chose à travailler). Un bandeau dit
// combien de hitbodedout et combien de temps, et montre le graphique du mois ; la liste suit, du jour le plus
// récent au plus ancien ; toucher une ligne ouvre la note de ce jour (NoteDialog.kt). Sans aucune journée,
// l'écran dit quoi faire : commencer une première hitbodedout.
//
// Tout est lu du Magasin à chaque fois (Android recharge à `onResume`) : une séance faite ailleurs, une note
// enregistrée ici, se voient tout de suite. Les notes sont ce qu'il y a de plus intime : sur Android, ni capture
// d'écran ni aperçu dans les applications récentes (FLAG_SECURE, revue du 01/10) ; voir `capturesMasquees`.
//
// Le texte d'une ligne est écrit dans la langue de l'app par le `Traducteur` (les noms des sujets, « Gratitude :
// … »), comme Android l'assemble avec `getString` : c'est une seule chaîne de plusieurs lignes, l'humeur isolée
// de gauche à droite (JournalPlus.resume).

/// Une ligne du journal : un jour, sa durée et sa note.
public struct JournalLigne: Sendable, Hashable, Identifiable {
    /// Le jour : la vue l'écrit en entier dans la langue de l'app (« Mardi 29 septembre 2026 », « EEEE d MMMM
    /// yyyy », première lettre en capitale).
    public let date: JourCivil
    /// À droite de la date : « Note seule », la durée (« 1 h 05 »), ou « Validée sans minuteur » (0 minute).
    public let duree: Libelle
    /// La note, puis le sujet, l'humeur, la gratitude et la chose à travailler, une par ligne ; nil s'il n'y a
    /// rien (le texte est alors caché).
    public let note: String?
    /// Une note laissée un jour sans hitbodedout.
    public let noteSeule: Bool

    public var id: JourCivil { date }

    public init(date: JourCivil, duree: Libelle, note: String?, noteSeule: Bool) {
        self.date = date
        self.duree = duree
        self.note = note
        self.noteSeule = noteSeule
    }
}

/// Les écrans que le journal ouvre.
public enum JournalRoute: Sendable, Hashable {
    /// L'écran de la séance (SessionActivity), depuis le bouton de l'écran vide.
    case seance
}

/// L'écran du journal.
@MainActor
@Observable
public final class JournalModele {

    // Les textes et l'image fixes (activity_journal.xml).
    public let titre = Libelle("journal_title")
    public let texteVide = Libelle("journal_empty")
    public let boutonVide = Libelle("journal_empty_action")
    /// Le hassid qui écrit, au-dessus du texte de l'écran vide (180 × 130 pt, ajusté sans rogner, décoratif).
    public let imageVide = "char_writing"
    /// Les notes ne se montrent ni dans l'aperçu du sélecteur d'apps ni sur une capture (FLAG_SECURE d'Android) :
    /// la vue les couvre dès que la scène n'est plus active.
    public let capturesMasquees = true

    private let magasin: Magasin
    private let horloge: any Horloge
    /// La langue de l'app : elle écrit le texte des lignes. L'app la remplace quand la langue change.
    public var traducteur: Traducteur

    /// La note ouverte (la fenêtre de NoteDialog) ; nil quand aucune ne l'est.
    public private(set) var note: JournalNoteModele? = nil
    /// Une note est ouverte : la feuille est présentée (`.sheet(isPresented:)`, `fermerNote` au retour).
    public var noteOuverte: Bool {
        note != nil
    }
    /// L'écran à ouvrir ; la vue le remet à nil une fois parti.
    public var route: JournalRoute? = nil

    public init(magasin: Magasin, horloge: any Horloge, traducteur: Traducteur) {
        self.magasin = magasin
        self.horloge = horloge
        self.traducteur = traducteur
    }

    // MARK: Ce qui s'affiche

    /// Les journées, de la plus récente à la plus ancienne (`sortedByDescending { it.date }` sur la date ISO).
    public var lignes: [JournalLigne] {
        let journal = magasin.journal
        let dates = journal.dates.sorted { a, b in
            b.iso.utf16.lexicographicallyPrecedes(a.iso.utf16)
        }
        var lignes: [JournalLigne] = []
        for date in dates {
            guard let journee = journal.jours[date] else { continue }
            lignes.append(ligne(date, journee, journal))
        }
        return lignes
    }

    /// Aucune journée : l'écran vide (l'image, le texte, le bouton) à la place de la liste.
    public var vide: Bool {
        magasin.journal.jours.isEmpty
    }

    /// Sous le titre du bandeau : « 12 hitbodedout, 4 h 30 au total ». Les journées faites seulement (une note
    /// seule n'en est pas une) ; le temps, de toutes les journées.
    public var resume: Libelle {
        let journal = magasin.journal
        var faites = 0
        for journee in journal.jours.values where journee.faite {
            faites += 1
        }
        return Libelle.pluriel("journal_summary", quantite: faites, .entier(faites),
                               .libelle(Store.formatDuration(journal.totalMinutes)))
    }

    /// Le graphique du mois en cours, sous le résumé, dans le bandeau.
    public var graphique: JournalGraphique {
        JournalGraphique(journal: magasin.journal, aujourdhui: horloge.aujourdhui)
    }

    // MARK: Les actions

    /// Toucher une ligne : la note de ce jour s'ouvre.
    public func ouvrirNote(_ date: JourCivil) {
        note = JournalNoteModele(magasin: magasin, date: date)
    }

    /// La note se ferme sans rien enregistrer (« Plus tard », « Ne pas enregistrer », ou le geste de retour
    /// quand `note.fermableParGeste`).
    public func fermerNote() {
        note = nil
    }

    /// « Enregistrer » : la note s'écrit, la fenêtre se ferme, la liste la montre. Si l'écriture échoue, la
    /// fenêtre reste ouverte et l'erreur remonte (le changement reste en mémoire, Magasin).
    public func enregistrerNote() async throws {
        guard let ouverte = note else { return }
        try await ouverte.enregistrer()
        if note === ouverte {
            note = nil
        }
    }

    /// Le bouton de l'écran vide : commencer une première hitbodedout.
    public func commencer() {
        route = .seance
    }

    // MARK: Une ligne

    private func ligne(_ date: JourCivil, _ journee: Journee, _ journal: Journal) -> JournalLigne {
        let duree: Libelle
        if journee.noteSeule {
            duree = Libelle("journal_note_only")
        } else if journee.minutes > 0 {
            duree = Store.formatDuration(journee.minutes)
        } else {
            duree = Libelle("today_declared")
        }
        // Le sujet du jour (19/10), puis l'humeur, la gratitude et la chose à travailler (14/10).
        var vus: [Theme] = []
        for cle in journee.themes {
            if let theme = ThemeRules.parse(cle), !vus.contains(theme) {
                vus.append(theme)
            }
        }
        let noms = vus.map { traducteur.texte(cle: $0.titre) }.joined(separator: " \u{00B7} ")
        let sujets = noms.estBlanc ? "" : traducteur.texte(Libelle("journal_sujets", .texte(noms)))
        let plus = JournalPlus.resume(journal.lirePlus(date),
                                      gratitude: traducteur.texte(cle: "journal_gratitude"),
                                      travail: traducteur.texte(cle: "journal_travail"),
                                      sujets: sujets)
        var morceaux: [String] = []
        for morceau in [journee.note, plus] where !morceau.estBlanc {
            morceaux.append(morceau)
        }
        let texte = morceaux.joined(separator: "\n")
        return JournalLigne(date: date, duree: duree, note: texte.estBlanc ? nil : texte, noteSeule: journee.noteSeule)
    }
}
